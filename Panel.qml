import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "doji.agents"
  ipcTarget: "doji.agents"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color surface: Color.popups.background
  readonly property color track: Style.selectedFillFor(foreground, Color.accent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // DOJI Neo-Tactile Brand Tokens
  readonly property color dojiKineticOrange: "#FF5500"
  readonly property color dojiHyperLime: "#D0FF00"
  readonly property color dojiTechnicalBlue: "#0066FF"
  readonly property color dojiSolarAmber: "#FFAE00"
  readonly property color dojiObsidian: "#0B0C0E"
  readonly property color dojiGraphite: "#14161A"

  readonly property var providers: usage.enabledProviders
  // The selection follows the unique account record, not the slot it happens
  // to sit in: a record whose first scan lands while the panel is open would
  // otherwise shift the list underneath you and swap out what you were reading.
  property string selectedProviderId: "__overview__"
  readonly property bool isOverview: selectedProviderId === "__overview__"

  readonly property var navigationTabs: {
    var tabs = [{
      providerId: "__overview__",
      providerName: "Overview",
      isOverview: true
    }]
    for (var i = 0; i < root.providers.length; i++) {
      tabs.push({
        providerId: root.recordKey(root.providers[i]),
        providerName: root.providerTabLabel(root.providers[i]),
        isOverview: false,
        rawIndex: i
      })
    }
    return tabs
  }

  readonly property int currentTabIndex: {
    for (var i = 0; i < navigationTabs.length; i++) {
      if (navigationTabs[i].providerId === selectedProviderId) return i
    }
    return 0
  }

  readonly property int providerIndex: {
    for (var i = 0; i < providers.length; i++)
      if (recordKey(providers[i]) === selectedProviderId) return i
    return 0
  }
  readonly property var provider: providers.length > 0 ? providers[providerIndex] : null

  property bool cursorActive: false
  property bool searchFocused: false

  property string overviewSortMode: "all" // "all", "session", "weekly"
  readonly property var overviewAgents: sortedAgentList()
  property string modelFilterText: ""
  property string modelScope: "agent" // "agent", "all"
  property var agentModelSelections: ({})

  function recordKey(p) {
    if (!p) return ""
    if (typeof p === "string") return p
    return String(p.agentId || p.accountId || p.providerId || "")
  }

  function selectedModelFor(providerOrId) {
    var key = recordKey(providerOrId)
    if (!key) return "__all__"
    var selected = (agentModelSelections && agentModelSelections[key]) ? agentModelSelections[key] : "__all__"
    if (selected === "__all__" || !providerOrId || typeof providerOrId !== "object") return selected

    // A collector can remove or rename a model while the panel is open. Do
    // not leave the dropdown pointing at a value that no longer scopes any
    // data; the next refresh should safely return to the account total.
    var rows = modelRows(providerOrId, true)
    for (var i = 0; i < rows.length; i++) {
      if (rowMatchesModel(rows[i], selected)) return selected
    }
    return "__all__"
  }

  function selectModelFor(providerOrId, modelId) {
    var key = recordKey(providerOrId)
    if (!key) return
    var copy = Object.assign({}, agentModelSelections)
    copy[key] = modelId
    agentModelSelections = copy
  }

  function accountOptionsFor(p) {
    if (!p) return []
    var options = []
    var family = String(p.providerId || p.agentId || "")
    for (var i = 0; i < providers.length; i++) {
      var candidate = providers[i]
      if (String(candidate.providerId || candidate.agentId || "") !== family) continue
      var key = recordKey(candidate)
      var label = String(candidate.accountName || candidate.providerName || key)
      if (candidate.accountEmail) label += " · " + candidate.accountEmail
      options.push({ value: key, label: label })
    }
    return options
  }

  function accountLabel(p) {
    if (!p) return ""
    var account = String(p.accountName || "")
    var providerName = String(p.providerName || "")
    return account !== "" && account !== providerName ? account : providerName
  }

  function providerTabLabel(p) {
    var label = accountLabel(p)
    if (label === "Claude Code") return "Claude"
    return label
  }

  // Countdowns and "updated" read this instead of Date.now() so the
  // panel keeps telling the truth while it sits open.
  property double nowMs: Date.now()

  readonly property string selectedModelId: provider ? selectedModelFor(provider) : "__all__"
  readonly property var limits: limitWindows(provider, selectedModelId)
  readonly property var models: filteredModelRows()
  readonly property var headline: bindingWindow(provider, selectedModelId)
  readonly property var balance: provider ? (provider.balance || null) : null
  // A prepaid account runs low the way a subscription window fills up: the
  // last 10% of the funded credits lights the same alarm.
  readonly property bool balanceAlarming: !!balance && balance.funded > 0
    && balance.remaining / balance.funded <= 0.1
  readonly property bool alarming: (!!headline && headline.percent >= 0.9) || balanceAlarming

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  function selectTab(index) {
    if (navigationTabs.length === 0) return
    var wrapped = ((index % navigationTabs.length) + navigationTabs.length) % navigationTabs.length
    selectedProviderId = navigationTabs[wrapped].providerId
  }

  function selectProvider(index) {
    if (providers.length === 0) return
    var wrapped = ((index % providers.length) + providers.length) % providers.length
    selectedProviderId = recordKey(providers[wrapped])
  }

  function selectRecord(value) {
    var target = String(value || "")
    if (target === "") return
    var fallbackKey = ""
    for (var i = 0; i < providers.length; i++) {
      var key = recordKey(providers[i])
      if (key === target) {
        selectedProviderId = target
        return
      }
      if (fallbackKey === "" && String(providers[i].providerId || "") === target) {
        fallbackKey = key
      }
    }
    selectedProviderId = fallbackKey !== "" ? fallbackKey : target
  }

  function refreshNow() {
    usage.refreshAll(true)
  }

  function launchAgent() {
    if (root.bar) root.bar.run("omarchy-agent --pick")
    root.close()
  }

  // ---------------------------------------------------------------- limits
  //
  // Providers report short rolling session windows, weekly windows, and in
  // some cases longer monthly windows. Everything below normalizes them into
  // one record so the meters and the hero speak a single language.

  // Claude spells its windows out ("Session (5-hour)"), while other
  // collectors abbreviate them ("5h window", "720h window"). They all land
  // on the same normalized record.
  function windowIsLong(text) {
    var hours = text.match(/(\d+)\s*-?\s*h(?:our)?\b/)
    var h = hours ? Number(hours[1]) : 0
    return text.indexOf("week") >= 0 || text.indexOf("7-day") >= 0 || text.indexOf("seven") >= 0
      || text.indexOf("month") >= 0 || text.indexOf("30-day") >= 0
      || h >= 48
  }

  function windowPeriod(text) {
    var value = String(text || "").toLowerCase()
    var hours = value.match(/(\d+)\s*-?\s*h(?:our)?\b/)
    var h = hours ? Number(hours[1]) : 0
    if (value.indexOf("month") >= 0 || value.indexOf("30-day") >= 0 || h >= 500) return "monthly"
    if (value.indexOf("week") >= 0 || value.indexOf("7-day") >= 0 || value.indexOf("seven") >= 0 || h >= 48)
      return "weekly"
    return "session"
  }

  function windowSpanMs(label) {
    var text = String(label || "").toLowerCase()
    if (text.indexOf("month") >= 0 || text.indexOf("30-day") >= 0) return 30 * 24 * 3600 * 1000
    if (windowIsLong(text)) return 7 * 24 * 3600 * 1000
    var hours = text.match(/(\d+)\s*-?\s*h(?:our)?\b/)
    if (hours) return Number(hours[1]) * 3600 * 1000
    var minutes = text.match(/(\d+)\s*-?\s*m(?:in(?:ute)?s?)?\b/)
    if (minutes) return Number(minutes[1]) * 60 * 1000
    return 0
  }

  function windowTitle(label) {
    var text = String(label || "").toLowerCase()
    var hours = text.match(/(\d+)\s*-?\s*h(?:our)?\b/)
    var h = hours ? Number(hours[1]) : 0
    if (text.indexOf("month") >= 0 || text.indexOf("30-day") >= 0 || h >= 500) return "Monthly"
    if (windowIsLong(text) || h >= 48) return "Weekly"
    if (text.indexOf("session") >= 0 || windowSpanMs(label) > 0) return "Session"
    var plain = String(label || "").replace(/\s*\(.*\)\s*/, "").trim()
    return plain === "" ? "Limit" : plain
  }

  // A collector that already knows which window a limit belongs to says so,
  // and that beats reading it back out of the label: a model-scoped limit is
  // titled after its model, and a name like "Opus 5 (1M context)" would parse
  // as a one-minute window.
  function limitWindow(label, percent, resetAt, title) {
    var windowText = String(label || "") + " " + String(title || "")
    return {
      title: String(title || "") !== "" ? String(title) : windowTitle(label),
      percent: normalizedPercent(percent),
      resetAt: String(resetAt || ""),
      kind: windowIsLong(windowText.toLowerCase()) ? "long" : "short",
      period: windowPeriod(windowText),
      modelId: "",
      modelScoped: false
    }
  }

  function normalizedPercent(value) {
    var n = Number(value)
    if (!isFinite(n) || n < 0) return -1
    if (n > 1 && n <= 100) n /= 100
    return clamp(n, 0, 1)
  }

  function selectedModelKeys(p, modelId) {
    var keys = [normalizeModelKey(modelId)]
    var rows = modelRows(p, true)
    for (var i = 0; i < rows.length; i++) {
      if (rowMatchesModel(rows[i], modelId)) {
        keys.push(normalizeModelKey(rows[i].id))
        keys.push(normalizeModelKey(rows[i].name))
      }
    }
    return keys
  }

  function limitModelId(entry, p, existingRows) {
    var explicit = entry && (entry.modelId || entry.model || entry.modelName)
    if (explicit && typeof explicit === "object")
      explicit = explicit.id || explicit.name || explicit.displayName
    if (explicit) return String(explicit)
    var scope = entry && entry.scope
    if (scope && typeof scope === "object") {
      var scopedModel = scope.model
      if (scopedModel && typeof scopedModel === "object")
        scopedModel = scopedModel.id || scopedModel.display_name || scopedModel.name
      if (scopedModel) return String(scopedModel)
    }

    // Some older Claude records only carry the model in the title. Match it
    // against known/advertised model names, but leave normal "Weekly" and
    // "Session" rows account-wide.
    var titleKey = normalizeModelKey(entry && (entry.title || entry.label))
    if (titleKey === "") return ""
    var rows = existingRows || []
    if (rows.length === 0 && p) {
      var avail = p.availableModels || []
      for (var a = 0; a < avail.length; a++) {
        var m = modelDescriptor(avail[a])
        var k = normalizeModelKey(m.name)
        if (k !== "" && titleKey.indexOf(k) >= 0) return m.id
      }
      return ""
    }
    for (var i = 0; i < rows.length; i++) {
      var modelKey = normalizeModelKey(rows[i].name)
      if (modelKey !== "" && titleKey.indexOf(modelKey) >= 0) return rows[i].id
    }
    return ""
  }

  function limitMatchesModel(modelId, selectedKeys) {
    if (!modelId) return true
    var key = normalizeModelKey(modelId)
    for (var i = 0; i < selectedKeys.length; i++) {
      if (key !== "" && (key === selectedKeys[i] || selectedKeys[i].indexOf(key) >= 0 || key.indexOf(selectedKeys[i]) >= 0)) return true
    }
    return false
  }

  function limitWindows(p, selectedModelId) {
    if (!p) return []
    var out = []
    var list = p.limits || []
    var selected = selectedModelId && selectedModelId !== "__all__" ? String(selectedModelId) : "__all__"
    var selectedKeys = selected === "__all__" ? [] : selectedModelKeys(p, selected)
    var decorated = []
    var hasModelScoped = false

    for (var i = 0; i < list.length; i++) {
      var entry = list[i] || {}
      var percent = Number(entry.percent)
      if (!isFinite(percent) || percent < 0) continue
      var modelId = limitModelId(entry, p)
      if (modelId !== "") hasModelScoped = true
      decorated.push({ entry: entry, modelId: modelId })
    }

    for (var d = 0; d < decorated.length; d++) {
      var item = decorated[d]
      // Keep account-wide windows with a model selection. If the provider has
      // no model-scoped limits at all, every window is necessarily the best
      // available answer for the selected model.
      if (selected !== "__all__" && hasModelScoped && item.modelId !== ""
          && !limitMatchesModel(item.modelId, selectedKeys)) continue
      var window = limitWindow(item.entry.label, item.entry.percent, item.entry.resetsAt, item.entry.title)
      window.modelId = item.modelId
      window.modelScoped = item.modelId !== ""
      out.push(window)
    }
    return out
  }

  // The window that decides how much room is left — the fullest one, since
  // that is what stops the next prompt.
  function bindingWindow(p, selectedModelId) {
    var windows = limitWindows(p, selectedModelId)
    var hasAccountWide = false
    if (selectedModelId === "__all__") {
      for (var a = 0; a < windows.length; a++) {
        if (!windows[a].modelScoped) { hasAccountWide = true; break }
      }
    }
    var best = null
    for (var i = 0; i < windows.length; i++) {
      if (selectedModelId === "__all__" && hasAccountWide && windows[i].modelScoped) continue
      if (!best || windows[i].percent > best.percent) best = windows[i]
    }
    return best
  }

  function resetMsFor(w) {
    if (!w || w.resetAt === "") return -1
    var ms = new Date(w.resetAt).getTime()
    return isFinite(ms) ? ms - root.nowMs : -1
  }

  function formatDuration(ms) {
    if (!(ms > 0)) return "now"
    var minutes = Math.floor(ms / 60000)
    var hours = Math.floor(minutes / 60)
    var days = Math.floor(hours / 24)
    if (days > 0) return days + "d " + (hours % 24) + "h"
    if (hours > 0) return hours + "h " + (minutes % 60) + "m"
    return Math.max(1, minutes) + "m"
  }

  // ---------------------------------------------------------------- balance
  //
  // Prepaid agents report a credit ledger instead of rate-limit windows: the
  // record's balance object carries remaining, funded, and spent amounts.

  function currencyPrefix(currency) {
    var code = String(currency || "USD").toUpperCase()
    if (code === "USD") return "$"
    if (code === "EUR") return "€"
    if (code === "GBP") return "£"
    return code + " "
  }

  function formatMoney(value, currency) {
    var amount = Number(value)
    if (!isFinite(amount)) amount = 0
    return currencyPrefix(currency) + amount.toFixed(2)
  }

  function balanceDetailText(b) {
    if (!b || !(b.funded > 0)) return ""
    var text = formatMoney(b.spent, b.currency) + " spent of " + formatMoney(b.funded, b.currency) + " funded"
    if (b.estimated) text += " · estimated"
    return text
  }

  // ---------------------------------------------------------------- content

  // The plan you pay for, under the name of the tool it pays for. Limits live
  // in their own section; the hero just says what this is.
  function heroMeta(p) {
    if (!p) return ""
    var parts = []
    if (String(p.usageStatusText || "") !== "") parts.push(String(p.usageStatusText))
    var account = String(p.accountName || "")
    if (account !== "" && account !== String(p.providerName || "")) parts.push(account)
    if (String(p.accountEmail || "") !== "") parts.push(String(p.accountEmail))
    var tier = String(p.tierLabel || "")
    if (tier !== "") parts.push(tier.charAt(0).toUpperCase() + tier.slice(1))
    if (parts.length === 0) parts.push("Subscription")
    return parts.join(" · ")
  }

  // Local calendar date, recomputed from nowMs so a panel left open across
  // midnight moves the "Today" row with the clock.
  function todayDate() {
    var now = new Date(root.nowMs)
    return now.getFullYear()
      + "-" + String(now.getMonth() + 1).padStart(2, "0")
      + "-" + String(now.getDate()).padStart(2, "0")
  }

  function dayName(date) {
    var parsed = new Date(String(date || "") + "T00:00:00")
    if (isNaN(parsed.getTime())) return String(date || "")
    return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][parsed.getDay()]
  }

  function dayLabel(date, today) {
    if (today) return "Today"
    return dayName(date)
  }

  function dayTooltip(day, today) {
    if (!day) return ""
    var parsed = new Date(String(day.date) + "T00:00:00")
    var label = isNaN(parsed.getTime())
      ? String(day.date)
      : dayName(day.date) + " " + (parsed.getMonth() + 1) + "/" + parsed.getDate()
    var text = label + " · " + usage.formatTokenCount(Number(day.messageCount || 0)) + " tokens"
    // Prompt and session counts only exist for today, so they ride along here
    // instead of taking a section of their own. Billing-API agents never
    // count prompts, and "0 prompts" would read as a quiet day, not a gap.
    if (today && provider && root.selectedModelId === "__all__" && provider.hasPromptStats !== false)
      text += " · " + Number(provider.todayPrompts || 0) + " prompts · "
        + Number(provider.todaySessions || 0) + " sessions"
    return text
  }

  function weekPeak(p) {
    var days = p ? (p.recentDays || []) : []
    var peak = 0
    for (var i = 0; i < days.length; i++) peak = Math.max(peak, Number(days[i].messageCount || 0))
    return peak
  }

  function tokenTotal(value) {
    if (value && typeof value === "object") {
      var total = Number(value.totalTokens || value.total || 0)
      if (total > 0) return total
      return Number(value.inputTokens || 0) + Number(value.outputTokens || 0)
        + Number(value.cacheReadInputTokens || 0) + Number(value.cacheCreationInputTokens || 0)
    }
    return Number(value || 0)
  }

  function daysFor(p, modelId) {
    var allDays = p ? (p.recentDays || []) : []
    if (!p || !modelId || modelId === "__all__") return { days: allDays, filtered: false }
    var byModel = p.recentDaysByModel || ({})
    var keys = selectedModelKeys(p, modelId)
    for (var key in byModel) {
      if (keys.indexOf(normalizeModelKey(key)) >= 0) {
        var selectedDays = byModel[key]
        if (Array.isArray(selectedDays)) return { days: selectedDays, filtered: true }
      }
    }
    return { days: allDays, filtered: false }
  }

  function agentWindows(p, modelId) {
    var wins = limitWindows(p, modelId)
    var sessionWin = null
    var weeklyWin = null
    var monthlyWin = null

    var hasAccountWideWeekly = false
    var hasAccountWideSession = false
    var hasAccountWideMonthly = false
    if (modelId === "__all__") {
      for (var a = 0; a < wins.length; a++) {
        if (!wins[a].modelScoped) {
          if (wins[a].period === "weekly") hasAccountWideWeekly = true
          else if (wins[a].period === "monthly") hasAccountWideMonthly = true
          else hasAccountWideSession = true
        }
      }
    }

    for (var i = 0; i < wins.length; i++) {
      var w = wins[i]
      if (modelId === "__all__") {
        if (w.period === "weekly" && hasAccountWideWeekly && w.modelScoped) continue
        if (w.period === "monthly" && hasAccountWideMonthly && w.modelScoped) continue
        if (w.period === "session" && hasAccountWideSession && w.modelScoped) continue
      }
      if (w.period === "monthly") {
        if (!monthlyWin || w.percent > monthlyWin.percent) monthlyWin = w
      } else if (w.period === "weekly") {
        if (!weeklyWin || w.percent > weeklyWin.percent) weeklyWin = w
      } else {
        if (!sessionWin || w.percent > sessionWin.percent) sessionWin = w
      }
    }

    return {
      session: sessionWin,
      weekly: weeklyWin,
      monthly: monthlyWin,
      hasWeeklyWindow: !!weeklyWin
    }
  }

  function primaryWindowFor(wins) {
    var candidates = []
    if (wins && wins.session) candidates.push({ kind: "session", window: wins.session })
    if (wins && wins.weekly) candidates.push({ kind: "weekly", window: wins.weekly })
    if (wins && wins.monthly) candidates.push({ kind: "monthly", window: wins.monthly })

    var primary = null
    for (var i = 0; i < candidates.length; i++) {
      if (!primary || candidates[i].window.percent > primary.window.percent) primary = candidates[i]
    }
    return primary
  }

  function agentSortLabel(agent) {
    if (!agent) return ""
    var providerName = String(agent.providerName || "")
    var accountName = String(agent.accountName || "")
    return accountName !== "" && accountName !== providerName
      ? providerName + " · " + accountName
      : providerName
  }

  function compareAgentLabels(a, b) {
    var labelDiff = agentSortLabel(a).localeCompare(agentSortLabel(b))
    if (labelDiff !== 0) return labelDiff
    return String(a && (a.agentId || a.providerId) || "")
      .localeCompare(String(b && (b.agentId || b.providerId) || ""))
  }

  function sortResetValue(value) {
    var reset = Number(value)
    return isFinite(reset) && reset >= 0 ? reset : 9999999999
  }

  function compareWindowUsage(a, b, percentKey, availableKey, resetKey) {
    var aAvailable = !!(a && a[availableKey])
    var bAvailable = !!(b && b[availableKey])
    if (aAvailable !== bAvailable) return aAvailable ? -1 : 1
    if (!aAvailable) return compareAgentLabels(a, b)

    var percentDiff = Number(b[percentKey] || 0) - Number(a[percentKey] || 0)
    if (percentDiff !== 0) return percentDiff

    var resetDiff = sortResetValue(a[resetKey]) - sortResetValue(b[resetKey])
    if (resetDiff !== 0) return resetDiff
    return compareAgentLabels(a, b)
  }

  function compareOverviewUrgency(a, b) {
    var aHasWindow = !!(a && a.primaryWindow)
    var bHasWindow = !!(b && b.primaryWindow)
    if (aHasWindow !== bHasWindow) return aHasWindow ? -1 : 1
    if (aHasWindow) {
      var percentDiff = Number(b.primaryPercent || 0) - Number(a.primaryPercent || 0)
      if (percentDiff !== 0) return percentDiff

      var resetDiff = sortResetValue(a.primaryResetMs) - sortResetValue(b.primaryResetMs)
      if (resetDiff !== 0) return resetDiff
    }

    var aHasBalance = !!(a && a.balance)
    var bHasBalance = !!(b && b.balance)
    if (aHasBalance !== bHasBalance) return aHasBalance ? -1 : 1
    return compareAgentLabels(a, b)
  }

  function sortAgentList(list, mode) {
    var sorted = (list || []).slice(0)
    sorted.sort(function(a, b) {
      if (mode === "session") return compareWindowUsage(a, b, "sessionPercent", "hasSessionWindow", "sessionResetMs")
      if (mode === "weekly") return compareWindowUsage(a, b, "weeklyPercent", "hasWeeklyWindow", "weeklyResetMs")
      return compareOverviewUrgency(a, b)
    })
    return sorted
  }

  function sortModeDescription(mode) {
    if (mode === "session") return "5-hour agents only · lowest remaining first"
    if (mode === "weekly") return "Weekly agents only · lowest remaining first"
    return "All agents · most constrained window first"
  }

  function sortModeTitle(mode) {
    if (mode === "all") return "ALL"
    if (mode === "session") return "5-HOUR"
    if (mode === "weekly") return "WEEKLY"
    return "ALL"
  }

  function setOverviewMode(mode) {
    var next = String(mode || "")
    overviewSortMode = next === "session" || next === "weekly" ? next : "all"
  }

  function filterAgentList(list, mode) {
    if (mode !== "session" && mode !== "weekly") return (list || []).slice(0)
    var filtered = []
    var availableKey = mode === "session" ? "hasSessionWindow" : "hasWeeklyWindow"
    for (var i = 0; i < (list || []).length; i++) {
      if (list[i] && list[i][availableKey]) filtered.push(list[i])
    }
    return filtered
  }

  function isAgentAuthed(p) {
    if (!p) return false
    // A record marked ready: false has no valid auth, limits, or synced activity
    if (p.ready === false) return false

    // Explicit auth failure, login required, or unavailable status
    var status = String(p.usageStatusText || "").toLowerCase()
    if (status.indexOf("auth") !== -1 ||
        status.indexOf("sign-in") !== -1 ||
        status.indexOf("login") !== -1 ||
        status.indexOf("expired") !== -1 ||
        status.indexOf("setup required") !== -1 ||
        status === "fireworks unavailable" ||
        status === "codex unavailable") {
      return false
    }

    // Must have active limits, a prepaid balance, or active usage stats
    var wins = agentWindows(p, "__all__")
    var hasWindows = !!wins.session || wins.hasWeeklyWindow
    var hasBalance = !!p.balance
    var hasStats = Number(p.todayTotalTokens || 0) > 0 || Number(p.totalPrompts || 0) > 0 || Number(p.totalSessions || 0) > 0 || Number(p.activeDays || 0) > 0

    return hasWindows || hasBalance || hasStats
  }

  function sortedAgentList() {
    var list = []
    for (var i = 0; i < root.providers.length; i++) {
      var p = root.providers[i]
      if (!isAgentAuthed(p)) continue
      var selectedModel = "__all__"
      var wins = agentWindows(p, selectedModel)
      var primary = primaryWindowFor(wins)
      var sessionPct = wins.session ? wins.session.percent : 0
      var weeklyPct = wins.weekly ? wins.weekly.percent : 0
      var sessionResetMs = wins.session ? resetMsFor(wins.session) : 9999999999
      var weeklyResetMs = wins.weekly ? resetMsFor(wins.weekly) : 9999999999
      list.push({
        provider: p,
        providerId: p.providerId,
        agentId: root.recordKey(p),
        providerName: p.providerName,
        accountName: p.accountName || "",
        tierLabel: p.tierLabel || "",
        hasSessionWindow: !!wins.session,
        hasWeeklyWindow: wins.hasWeeklyWindow,
        sessionPercent: sessionPct,
        weeklyPercent: weeklyPct,
        sessionResetMs: sessionResetMs,
        weeklyResetMs: weeklyResetMs,
        sessionWindow: wins.session,
        weeklyWindow: wins.weekly,
        sessionRemainingPercent: wins.session ? Math.max(0, 1.0 - wins.session.percent) : 0,
        weeklyRemainingPercent: wins.weekly ? Math.max(0, 1.0 - wins.weekly.percent) : 0,
        primaryWindow: primary ? primary.window : null,
        primaryWindowKind: primary ? primary.kind : "",
        primaryPercent: primary ? primary.window.percent : 0,
        primaryRemainingPercent: primary ? Math.max(0, 1.0 - primary.window.percent) : 0,
        primaryResetMs: primary ? resetMsFor(primary.window) : 9999999999,
        balance: p.balance || null
      })
    }

    return sortAgentList(filterAgentList(list, root.overviewSortMode), root.overviewSortMode)
  }

  function tokenBreakdown(bucket) {
    var b = bucket || {}
    var input = Number(b.inputTokens || 0)
    var output = Number(b.outputTokens || 0)
    var cacheRead = Number(b.cacheReadInputTokens || 0)
    var cacheWrite = Number(b.cacheCreationInputTokens || 0)
    return {
      input: input,
      output: output,
      cacheRead: cacheRead,
      cacheWrite: cacheWrite,
      total: input + output + cacheRead + cacheWrite
    }
  }

  function allModelRows() {
    var rows = []
    var provs = root.providers || []
    for (var i = 0; i < provs.length; i++) {
      var p = provs[i]
      var usageByModel = p.modelUsage || {}
      for (var id in usageByModel) {
        var tokens = tokenBreakdown(usageByModel[id])
        if (tokens.total > 0) {
          rows.push({
            id: String(id),
            name: usage.friendlyModelName(id),
            providerName: p.providerName,
            providerId: p.providerId,
            accountName: p.accountName || "",
            agentId: root.recordKey(p),
            total: tokens.total,
            input: tokens.input,
            output: tokens.output,
            cacheRead: tokens.cacheRead,
            cacheWrite: tokens.cacheWrite
          })
        }
      }
    }
    rows.sort(function(a, b) { return b.total - a.total })
    return rows
  }

  function normalizeModelKey(name) {
    return String(name || "").toLowerCase().replace(/[^a-z0-9]/g, "")
  }

  function rowMatchesModel(row, targetModel) {
    if (!row || !targetModel) return false
    if (row.id === targetModel || row.name === targetModel) return true
    var key = normalizeModelKey(targetModel)
    return key !== "" && (normalizeModelKey(row.id) === key || normalizeModelKey(row.name) === key)
  }

  function modelDescriptor(raw) {
    if (raw && typeof raw === "object") {
      var objectId = String(raw.id || raw.modelId || raw.value || raw.name || raw.displayName || "")
      var objectName = String(raw.name || raw.displayName || objectId)
      return { id: objectId, name: objectName }
    }
    var value = String(raw || "")
    return { id: value, name: value }
  }

  function modelRows(p, all) {
    if (!p) return []
    var usageByModel = p.modelUsage || {}
    var rows = []
    var seen = {}

    function addModel(rawId, rawName, total, input, output, cacheRead, cacheWrite) {
      var id = String(rawId || "")
      var name = String(rawName || id)
      var key = normalizeModelKey(id)
      var nameKey = normalizeModelKey(name)
      if (key === "" || seen[key] || (nameKey !== "" && seen[nameKey])) return
      rows.push({
        id: id,
        name: name,
        providerName: p.providerName || "",
        providerId: p.providerId || "",
        accountName: p.accountName || "",
        agentId: root.recordKey(p),
        total: Number(total || 0),
        input: Number(input || 0),
        output: Number(output || 0),
        cacheRead: Number(cacheRead || 0),
        cacheWrite: Number(cacheWrite || 0)
      })
      seen[key] = true
      if (nameKey !== "") seen[nameKey] = true
    }

    for (var id in usageByModel) {
      var tokens = tokenBreakdown(usageByModel[id])
      var friendly = (id.indexOf(" ") >= 0) ? id : usage.friendlyModelName(id)

      if (tokens.total > 0 || all)
        addModel(id, friendly, tokens.total, tokens.input, tokens.output, tokens.cacheRead, tokens.cacheWrite)
    }

    if (all) {
      // Some collectors publish today's model totals before they have enough
      // history to create a full modelUsage bucket.
      var todayByModel = p.todayTokensByModel || ({})
      for (var todayId in todayByModel) {
        var todayValue = todayByModel[todayId]
        var todayTotal = root.tokenTotal(todayValue)
        var todayName = todayId.indexOf(" ") >= 0 ? todayId : usage.friendlyModelName(todayId)
        addModel(todayId, todayName, todayTotal)
      }

      // Keep a model selectable when the collector has only supplied scoped
      // daily history or an explicit model-scoped allowance.
      var recentByModel = p.recentDaysByModel || ({})
      for (var recentId in recentByModel) {
        var recentName = recentId.indexOf(" ") >= 0 ? recentId : usage.friendlyModelName(recentId)
        addModel(recentId, recentName, 0)
      }

      var limitList = p.limits || []
      for (var limitIndex = 0; limitIndex < limitList.length; limitIndex++) {
        var limitModel = limitModelId(limitList[limitIndex], p, rows)
        if (limitModel) addModel(limitModel, limitModel, 0)
      }

      var avail = p.availableModels || []
      for (var a = 0; a < avail.length; a++) {
        var available = modelDescriptor(avail[a])
        addModel(available.id, available.name, 0)
      }

      if (p.currentModel) {
        var current = modelDescriptor(p.currentModel)
        addModel(current.id, current.name, 0)
      }
    }

    rows.sort(function(a, b) {
      if (b.total !== a.total) {
        return b.total - a.total
      }
      return a.name.localeCompare(b.name)
    })

    return all ? rows : rows.slice(0, 4)
  }

  function filteredModelRows() {
    var showAll = root.isOverview || root.modelScope === "all"
    var baseRows = showAll ? allModelRows() : modelRows(root.provider, true)
    var selected = showAll ? "__all__" : root.selectedModelId
    var query = (root.modelFilterText || "").trim().toLowerCase()
    var res = []
    var selectedKeys = selected === "__all__" ? [] : selectedModelKeys(root.provider, selected)
    for (var j = 0; j < baseRows.length; j++) {
      var base = baseRows[j]
      if (selected !== "__all__"
          && selectedKeys.indexOf(normalizeModelKey(base.id)) < 0
          && selectedKeys.indexOf(normalizeModelKey(base.name)) < 0) continue
      var matchName = query === "" || (base.name || "").toLowerCase().indexOf(query) >= 0
      var matchProv = query === "" || (base.providerName || "").toLowerCase().indexOf(query) >= 0
      if (matchName || matchProv) res.push(base)
    }
    return res
  }

  function modelTooltip(row) {
    if (!row) return ""
    var out = row.name
    if (row.providerName) out += " (" + row.providerName + ")"
    if (row.accountName && row.accountName !== row.providerName) out += " · " + row.accountName
    out += "\nTotal: " + (row.total > 0 ? usage.formatTokenCount(row.total) : "0 tokens")
    out += "\nIn: " + usage.formatTokenCount(row.input)
      + " · out: " + usage.formatTokenCount(row.output)
      + " · cache read: " + usage.formatTokenCount(row.cacheRead)
      + " · cache write: " + usage.formatTokenCount(row.cacheWrite)
    return out
  }

  function modelDisplayName(p, modelId) {
    if (!modelId || modelId === "__all__") return "All models"
    var rows = modelRows(p, true)
    for (var i = 0; i < rows.length; i++) {
      if (rowMatchesModel(rows[i], modelId)) return rows[i].name
    }
    return String(modelId)
  }

  // Only speaks up when the numbers cover more than this machine.
  function footerText() {
    var parts = []
    if (usage.syncStatusText !== "") parts.push(usage.syncStatusText)
    if (provider && provider.syncEnabled && provider.syncDeviceCount > 0)
      parts.push("Merged from " + provider.syncDeviceCount + " device" + (provider.syncDeviceCount === 1 ? "" : "s"))
    if (provider && provider.updatedAt) parts.push("Updated " + formatUpdatedAt(provider.updatedAt))
    return parts.join(" · ")
  }

  function formatUpdatedAt(value) {
    var parsed = new Date(String(value || "")).getTime()
    if (!isFinite(parsed)) return "time unavailable"
    var age = Math.max(0, root.nowMs - parsed)
    if (age < 60000) return "just now"
    if (age < 3600000) return Math.floor(age / 60000) + "m ago"
    if (age < 86400000) return Math.floor(age / 3600000) + "h ago"
    return Math.floor(age / 86400000) + "d ago"
  }

  // Agents that ship a white mark carry an `assets/<id>-light.svg` twin for
  // light surfaces; marks that work on both (Claude's brand-orange) ship one
  // file. The luminance check decides which candidate to try first.
  function colorChannelLuminance(value) {
    var channel = Number(value)
    if (!isFinite(channel)) return 0
    return channel <= 0.03928 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
  }

  function colorLuminance(color) {
    return 0.2126 * colorChannelLuminance(color.r)
      + 0.7152 * colorChannelLuminance(color.g)
      + 0.0722 * colorChannelLuminance(color.b)
  }

  // Marks resolve by convention, so a new agent's data file needs nothing
  // from this panel: assets/<id>.svg if it ships one, the module's bar glyph
  // if it doesn't.
  function iconCandidatesForProvider(p, surfaceColor) {
    if (!p) return []
    var candidates = []
    if (colorLuminance(surfaceColor || Color.background) >= 0.5)
      candidates.push(Qt.resolvedUrl("assets/" + p.providerId + "-light.svg"))
    candidates.push(Qt.resolvedUrl("assets/" + p.providerId + ".svg"))
    return candidates
  }

  // Official brand colors for coding agents.
  function providerBrandColor(p) {
    if (!p) return root.foreground
    var id = String(p.providerId || p.agentId || "").toLowerCase()
    if (id.indexOf("antigravity") >= 0) return "#4285f4" // Google Blue
    if (id.indexOf("claude") >= 0) return "#d97757"      // Claude Terracotta
    if (id.indexOf("codex") >= 0) return "#10a37f"       // OpenAI Green
    if (id.indexOf("fireworks") >= 0) return "#ff6b22"   // Fireworks Orange
    return root.foreground
  }

  readonly property color activeBrandColor: {
    if (root.alarming) return root.urgent
    if (!root.isOverview && root.provider) return root.providerBrandColor(root.provider)
    if (root.overviewAgents.length > 0) return root.providerBrandColor(root.overviewAgents[0].provider)
    return root.foreground
  }

  // Nothing to report, nothing in the bar: Bar.qml collapses a slot whose item
  // is invisible, so the icon appears the moment the first scan finds usage and
  // stays away entirely on a machine that has never run either CLI.
  visible: providers.length > 0
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onProviderIndexChanged: if (panelFlick) panelFlick.contentY = 0
  onOpenedChanged: if (opened) {
    cursorActive = false
    nowMs = Date.now()
    if (panelFlick) panelFlick.contentY = 0
    usage.refreshLimits()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Main {
    id: usage
    settings: root.settings
  }

  // Cheap enough to keep running: it only re-evaluates text bindings, and a
  // stale "resets in 2h" on a panel that is open is worse than a timer.
  Timer {
    interval: 30000
    running: root.opened
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  IpcHandler {
    target: "omarchy.agents"
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
    function show(): string { root.open(); return "ok" }
    function hide(): string { root.close(); return "ok" }
    function toggle(): string { root.toggle(); return "ok" }
    function refresh(): string { root.refreshNow(); return "ok" }
    function next(): string { root.selectTab(root.currentTabIndex + 1); return "ok" }
    function select(id: string): string { root.selectRecord(id); return "ok" }
    function sort(mode: string): string { root.setOverviewMode(mode); return "ok" }
    function filter(text: string): string { root.modelFilterText = text; return "ok" }
    function scope(mode: string): string { root.modelScope = mode; return "ok" }
  }

  IpcHandler {
    target: "doji.agents"
    function open(): string { root.open(); return "ok" }
    function close(): string { root.close(); return "ok" }
    function show(): string { root.open(); return "ok" }
    function hide(): string { root.close(); return "ok" }
    function toggle(): string { root.toggle(); return "ok" }
    function refresh(): string { root.refreshNow(); return "ok" }
    function next(): string { root.selectTab(root.currentTabIndex + 1); return "ok" }
    function select(id: string): string { root.selectRecord(id); return "ok" }
    function sort(mode: string): string { root.setOverviewMode(mode); return "ok" }
    function filter(text: string): string { root.modelFilterText = text; return "ok" }
    function scope(mode: string): string { root.modelScope = mode; return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󱚣"
    foreground: root.activeBrandColor
    active: root.alarming
    iconComponent: (!root.alarming && !root.isOverview && root.provider) ? barIconComponent : null
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.launchAgent()
      else if (buttonCode === Qt.MiddleButton) root.selectTab(root.currentTabIndex + 1)
      else root.toggle()
    }
  }

  Component {
    id: barIconComponent
    ProviderIcon {
      provider: root.provider
      iconSize: Style.bar.iconCanvas
      anchors.centerIn: parent
    }
  }


  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    // Taller than the control panels on purpose: this one is a dashboard, and
    // the whole point is reading limits and history without scrolling.
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.searchFocused

      onMoveRequested: function(dx, dy) {
        if (dx !== 0) {
          root.cursorActive = true
          root.selectTab(root.currentTabIndex + dx)
        }
        if (dy !== 0)
          panelFlick.contentY = root.clamp(panelFlick.contentY + dy * Style.space(56), 0,
                                           Math.max(0, panelFlick.contentHeight - panelFlick.height))
      }
      onActivateRequested: root.refreshNow()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refreshNow()
        else if (root.isOverview) {
          if (t === "5") root.setOverviewMode("session")
          else if (t === "w" || t === "W") root.setOverviewMode("weekly")
          else if (t === "a" || t === "A") root.setOverviewMode("all")
        }
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          // ---------- Hero: provider mark · name · plan ----------
          PanelHero {
            id: hero
            visible: root.isOverview || !!root.provider
            width: parent.width
            title: root.isOverview ? "All Agents" : (root.provider ? root.provider.providerName : "")
            meta: root.isOverview ? (root.overviewAgents.length === 1 ? "1 active agent · window status" : root.overviewAgents.length + " active agents · window status") : root.heroMeta(root.provider)
            foreground: root.foreground
            fontFamily: root.fontFamily

            iconComponent: Component {
              Item {
                id: heroMark
                property var candidates: root.iconCandidatesForProvider(root.provider, root.surface)
                // Provider objects are rebuilt on every refresh, which churns the
                // array's identity without changing its content. Restart the fallback
                // walk only when the URLs change: re-pointing source at a URL whose
                // load already failed emits no statusChanged, so an identity-only
                // reset would strand the walker on a missing -light twin.
                property string candidatesKey: candidates.join("\n")
                property int candidateIndex: 0
                onCandidatesKeyChanged: candidateIndex = 0

                width: Style.font.display
                height: Style.font.display

                Image {
                  id: heroMarkImage
                  visible: !root.isOverview
                  anchors.fill: parent
                  source: (!root.isOverview && heroMark.candidateIndex < heroMark.candidates.length) ? heroMark.candidates[heroMark.candidateIndex] : ""
                  sourceSize.width: Style.font.display * 2
                  sourceSize.height: Style.font.display * 2
                  fillMode: Image.PreserveAspectFit
                  // Advancing source from inside its own status change trips the
                  // binding-loop detector; defer the step one tick.
                  onStatusChanged: if (status === Image.Error && heroMark.candidateIndex < heroMark.candidates.length)
                    Qt.callLater(function() { heroMark.candidateIndex++ })
                }

                Text {
                  textFormat: Text.PlainText
                  anchors.centerIn: parent
                  visible: root.isOverview || heroMarkImage.status !== Image.Ready
                  text: button.text
                  color: root.activeBrandColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.display
                }
              }
            }
          }

          Text {
            visible: root.providers.length === 0
            width: parent.width
            topPadding: Style.space(24)
            text: "No AI coding subscriptions found.\nAgents show up here once you've used them."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }

          // ---------- Provider switch ----------
          Flickable {
            id: providerSwitch
            visible: root.providers.length > 1
            width: parent.width
            height: tabRow.implicitHeight
            contentWidth: tabRow.implicitWidth
            contentHeight: tabRow.implicitHeight
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }

            property int activeTab: root.currentTabIndex
            onActiveTabChanged: ensureVisible(activeTab)

            function ensureVisible(tabIndex) {
              if (tabIndex < 0 || tabIndex >= tabRepeater.count) return
              var item = tabRepeater.itemAt(tabIndex)
              if (!item) return
              if (item.x < contentX) contentX = item.x
              else if (item.x + item.width > contentX + width)
                contentX = item.x + item.width - width
            }

            Row {
              id: tabRow
              spacing: Style.space(4)

              Repeater {
                id: tabRepeater
                model: root.navigationTabs

                Button {
                  required property var modelData
                  required property int index

                  readonly property color tabBrandColor: modelData.isOverview
                    ? Color.accent
                    : root.providerBrandColor(root.providers[modelData.rawIndex])

                  text: modelData.providerName
                  tooltipText: modelData.providerName
                  selected: modelData.providerId === root.selectedProviderId
                  hasCursor: root.cursorActive && modelData.providerId === root.selectedProviderId
                  bordered: true
                  accent: tabBrandColor
                  foreground: (modelData.providerId === root.selectedProviderId && !modelData.isOverview)
                    ? tabBrandColor
                    : root.foreground
                  fontFamily: root.fontFamily
                  fontSize: Style.font.caption
                  verticalPadding: Style.space(3)
                  horizontalPadding: Style.space(7)
                  clip: true
                  onClicked: {
                    root.cursorActive = true
                    root.selectedProviderId = modelData.providerId
                  }
                  onHovered: function(isHovered) { if (isHovered) root.cursorActive = true }
                }
              }
            }
          }

          // ---------- Account switch ----------
          Column {
            id: accountSwitch
            visible: !root.isOverview && root.accountOptionsFor(root.provider).length > 1
            width: parent.width
            spacing: Style.space(5)

            Text {
              text: "ACCOUNT"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Dropdown {
              width: parent.width
              height: implicitHeight
              showLabel: false
              rowHeight: Style.space(26)
              options: root.accountOptionsFor(root.provider)
              value: root.selectedProviderId
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(value) {
                var selected = String(value || "")
                if (selected !== "") root.selectedProviderId = selected
              }
            }
          }

          // ---------- Overview: All Agents & Windows ----------
          Column {
            id: overviewSection
            visible: root.isOverview
            width: parent.width
            spacing: Style.space(8)

            // Header and window filters
            Column {
              width: parent.width
              spacing: Style.space(4)

              Item {
                width: parent.width
                implicitHeight: Math.max(filterHeaderTitle.implicitHeight, filterButtonsRow.implicitHeight)

                Text {
                  id: filterHeaderTitle
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.overviewSortMode === "session" ? "5-HOUR USAGE"
                    : (root.overviewSortMode === "weekly" ? "WEEKLY USAGE" : "ALL AGENTS")
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Row {
                  id: filterButtonsRow
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)

                  Button {
                    text: "5h"
                    selected: root.overviewSortMode === "session"
                    accent: root.dojiKineticOrange
                    bordered: true
                    fontSize: Style.font.caption
                    verticalPadding: Style.space(2)
                    horizontalPadding: Style.space(8)
                    onClicked: root.setOverviewMode("session")
                  }

                  Button {
                    text: "Weekly"
                    selected: root.overviewSortMode === "weekly"
                    accent: root.dojiKineticOrange
                    bordered: true
                    fontSize: Style.font.caption
                    verticalPadding: Style.space(2)
                    horizontalPadding: Style.space(8)
                    onClicked: root.setOverviewMode("weekly")
                  }

                  Button {
                    text: "All"
                    selected: root.overviewSortMode === "all"
                    accent: root.dojiKineticOrange
                    bordered: true
                    fontSize: Style.font.caption
                    verticalPadding: Style.space(2)
                    horizontalPadding: Style.space(8)
                    onClicked: root.setOverviewMode("all")
                  }
                }
              }

              Text {
                text: root.sortModeDescription(root.overviewSortMode)
                color: root.alpha(root.foreground, 0.45)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            // Cards for each agent
            Repeater {
              model: root.overviewAgents

              delegate: BorderSurface {
                id: agentCard
                required property var modelData
                required property int index
                readonly property color brandCol: root.providerBrandColor(modelData.provider)
                width: overviewSection.width
                implicitHeight: cardContent.implicitHeight + Style.space(16)
                radius: Style.cornerRadius + Style.space(2)
                color: cardMouse.containsMouse
                  ? Style.hoverFillFor(root.foreground, brandCol)
                  : root.alpha(root.surface, 0.6)
                borderSpec: cardMouse.containsMouse
                  ? Border.flat(root.alpha(brandCol, 0.5), 1)
                  : Border.flat(root.alpha(brandCol, 0.18), 1)

                Behavior on color { ColorAnimation { duration: 100 } }

                MouseArea {
                  id: cardMouse
                  anchors.fill: parent
                  z: 10
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.selectedProviderId = modelData.agentId
                    root.modelFilterText = ""
                  }
                }

                Column {
                  id: cardContent
                  width: parent.width - Style.space(18)
                  x: Style.space(9)
                  y: Style.space(8)
                  spacing: Style.space(7)

                  // Top row: Provider icon, names, tier, and Inspect action
                  Item {
                    width: parent.width
                    implicitHeight: Math.max(nameRow.implicitHeight, viewBtn.implicitHeight)

                    Row {
                      id: nameRow
                      anchors.left: parent.left
                      anchors.right: viewBtn.left
                      anchors.rightMargin: Style.space(6)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(7)

                      ProviderIcon {
                        provider: modelData.provider
                        iconSize: Style.space(18)
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      Text {
                        text: modelData.providerName
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                      }

                      Text {
                        visible: !!modelData.accountName && modelData.accountName !== modelData.providerName
                        text: modelData.accountName
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                      }

                      BorderSurface {
                        visible: !!modelData.tierLabel
                        implicitWidth: tierText.implicitWidth + Style.space(10)
                        implicitHeight: tierText.implicitHeight + Style.space(4)
                        anchors.verticalCenter: parent.verticalCenter
                        radius: height / 2
                        color: root.alpha(brandCol, 0.12)
                        borderSpec: Border.flat(root.alpha(brandCol, 0.3), 1)

                        Text {
                          id: tierText
                          anchors.centerIn: parent
                          text: (modelData.tierLabel || "").toUpperCase()
                          color: brandCol
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 1
                          font.bold: true
                        }
                      }
                    }

                    Button {
                      id: viewBtn
                      text: "Inspect →"
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      fontSize: Style.font.caption
                      verticalPadding: Style.space(2)
                      horizontalPadding: Style.space(6)
                      selected: cardMouse.containsMouse
                      accent: brandCol
                    }
                  }

                  // 5-Hour Usage Left
                  Column {
                    id: sessionStatus
                    width: parent.width
                    spacing: Style.space(3)
                    visible: (root.overviewSortMode === "session" && modelData.hasSessionWindow)
                      || (root.overviewSortMode === "all" && modelData.primaryWindowKind === "session")

                    Item {
                      width: parent.width
                      implicitHeight: Math.max(sessionLabelRow.implicitHeight, sessionPctBadge.implicitHeight)

                      Row {
                        id: sessionLabelRow
                        anchors.left: parent.left
                        anchors.right: sessionPctBadge.left
                        anchors.rightMargin: Style.space(8)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(6)

                        Text {
                          text: "5h"
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }

                        Text {
                          id: sessionTimer
                          visible: modelData.sessionWindow && !!modelData.sessionWindow.resetAt
                          text: "·  resets in " + root.formatDuration(modelData.sessionResetMs)
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          elide: Text.ElideRight
                        }
                      }

                      BorderSurface {
                        id: sessionPctBadge
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: sessionPctText.implicitWidth + Style.space(12)
                        implicitHeight: sessionPctText.implicitHeight + Style.space(4)
                        radius: height / 2
                        color: modelData.sessionPercent >= 0.9
                          ? root.alpha(root.urgent, 0.16)
                          : root.alpha(brandCol, 0.14)
                        borderSpec: Border.flat(
                          modelData.sessionPercent >= 0.9
                            ? root.alpha(root.urgent, 0.4)
                            : root.alpha(brandCol, 0.3),
                          1
                        )

                        Text {
                          id: sessionPctText
                          anchors.centerIn: parent
                          text: Math.round(modelData.sessionRemainingPercent * 100) + "% left"
                          color: modelData.sessionPercent >= 0.9 ? root.urgent : brandCol
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }
                      }
                    }

                    Meter {
                      width: parent.width
                      value: modelData.sessionPercent
                      alarming: modelData.sessionPercent >= 0.9
                      accentColor: brandCol
                    }
                  }

                  // Weekly Usage Left
                  Column {
                    id: weeklyStatus
                    width: parent.width
                    spacing: Style.space(3)
                    visible: (root.overviewSortMode === "weekly" && modelData.hasWeeklyWindow)
                      || (root.overviewSortMode === "all" && modelData.primaryWindowKind === "weekly")

                    Item {
                      width: parent.width
                      implicitHeight: Math.max(weeklyLabelRow.implicitHeight, weeklyPctBadge.implicitHeight)

                      Row {
                        id: weeklyLabelRow
                        anchors.left: parent.left
                        anchors.right: weeklyPctBadge.left
                        anchors.rightMargin: Style.space(8)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(6)

                        Text {
                          text: "Weekly"
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }

                        Text {
                          id: weeklyTimer
                          visible: modelData.weeklyWindow && !!modelData.weeklyWindow.resetAt
                          text: "·  resets in " + root.formatDuration(modelData.weeklyResetMs)
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          elide: Text.ElideRight
                        }
                      }

                      BorderSurface {
                        id: weeklyPctBadge
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: weeklyPctText.implicitWidth + Style.space(12)
                        implicitHeight: weeklyPctText.implicitHeight + Style.space(4)
                        radius: height / 2
                        color: modelData.weeklyPercent >= 0.9
                          ? root.alpha(root.urgent, 0.16)
                          : root.alpha(brandCol, 0.14)
                        borderSpec: Border.flat(
                          modelData.weeklyPercent >= 0.9
                            ? root.alpha(root.urgent, 0.4)
                            : root.alpha(brandCol, 0.3),
                          1
                        )

                        Text {
                          id: weeklyPctText
                          anchors.centerIn: parent
                          text: Math.round(modelData.weeklyRemainingPercent * 100) + "% left"
                          color: modelData.weeklyPercent >= 0.9 ? root.urgent : brandCol
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }
                      }
                    }

                    Meter {
                      width: parent.width
                      value: modelData.weeklyPercent
                      alarming: modelData.weeklyPercent >= 0.9
                      accentColor: brandCol
                    }
                  }

                  // Fallback when agent reports no 5h or Weekly windows
                  Column {
                    width: parent.width
                    spacing: Style.space(3)
                    visible: root.overviewSortMode === "all"
                      ? (!modelData.primaryWindow)
                      : (root.overviewSortMode === "session" ? !modelData.hasSessionWindow : !modelData.hasWeeklyWindow)

                    // Balance fallback
                    Item {
                      visible: !!modelData.balance
                      width: parent.width
                      implicitHeight: Math.max(balanceLabel.implicitHeight, balanceValue.implicitHeight)

                      Text {
                        id: balanceLabel
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Prepaid Balance" + (modelData.balance && modelData.balance.estimated ? " · estimated" : "")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }

                      Text {
                        id: balanceValue
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.balance
                          ? root.formatMoney(modelData.balance.remaining, modelData.balance.currency)
                          : ""
                        color: root.balanceAlarming ? root.urgent : root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                    }

                    // Auth / Setup needed fallback
                    Row {
                      visible: !modelData.balance && !!(modelData.provider && (modelData.provider.usageStatusText || modelData.provider.authHelpText))
                      spacing: Style.space(6)

                      BorderSurface {
                        radius: Style.cornerRadius
                        color: root.alpha(root.urgent, 0.12)
                        borderSpec: Border.flat(root.alpha(root.urgent, 0.3), 1)
                        implicitWidth: authBadgeText.implicitWidth + Style.space(8)
                        implicitHeight: authBadgeText.implicitHeight + Style.space(2)

                        Text {
                          id: authBadgeText
                          anchors.centerIn: parent
                          text: (modelData.provider && modelData.provider.usageStatusText)
                            ? modelData.provider.usageStatusText.toUpperCase()
                            : "NEEDS AUTH"
                          color: root.urgent
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 1
                          font.bold: true
                        }
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Setup required"
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }

                    Text {
                      width: parent.width
                      text: (modelData.provider && (modelData.provider.authHelpText || modelData.provider.usageStatusText)) || "No 5h or Weekly limits reported"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }
                }
              }
            }

            BorderSurface {
              visible: root.overviewAgents.length === 0
              width: parent.width
              implicitHeight: emptyText.implicitHeight + Style.space(24)
              radius: Style.cornerRadius
              color: root.alpha(root.surface, 0.4)
              borderSpec: Border.flat(root.alpha(root.foreground, 0.08), 1)

              Text {
                id: emptyText
                anchors.centerIn: parent
                text: root.overviewSortMode === "session"
                  ? "No agents with a 5-hour limit found"
                  : (root.overviewSortMode === "weekly" ? "No agents with a weekly limit found" : (root.providers.length > 0 ? "No authenticated agents found" : "No agents found"))
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
              }
            }
          }

          // ---------- Status ----------
          BorderSurface {
            visible: !root.isOverview && !!root.provider
              && (String(root.provider.usageStatusText || "") !== "" || String(root.provider.authHelpText || "") !== "")
            width: parent.width
            implicitHeight: statusText.implicitHeight + Style.spacing.xl * 2
            color: root.alpha(root.urgent, 0.10)
            borderSpec: Border.flat(root.alpha(root.urgent, 0.35), 1)
            radius: Style.cornerRadius

            Text {
              id: statusText
              textFormat: Text.PlainText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              text: root.provider
                ? String(root.provider.authHelpText || root.provider.usageStatusText || "")
                : ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          // ---------- Balance / limits ----------
          PanelSeparator {
            visible: !root.isOverview && (balanceSection.visible || limitsSection.visible)
            foreground: root.foreground
          }

          Column {
            id: balanceSection
            visible: !root.isOverview && !!root.balance
            width: parent.width
            spacing: Style.space(10)

            // The meter shows what is left, not what is used: a prepaid
            // account drains toward empty rather than filling toward a cap.
            readonly property real ratio: root.balance && root.balance.funded > 0
              ? root.clamp(root.balance.remaining / root.balance.funded, 0, 1)
              : -1

            PanelSectionHeader {
              width: parent.width
              text: "BALANCE"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Item {
              width: parent.width
              implicitHeight: Math.max(balanceLabel.implicitHeight, balanceValue.implicitHeight)

              Text {
                id: balanceLabel
                text: "Prepaid credits"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: balanceValue
                textFormat: Text.PlainText
                text: root.balance ? root.formatMoney(root.balance.remaining, root.balance.currency) : ""
                color: root.balanceAlarming ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Meter {
              visible: balanceSection.ratio >= 0
              width: parent.width
              value: balanceSection.ratio
              alarming: root.balanceAlarming
              accentColor: root.provider ? root.providerBrandColor(root.provider) : root.dojiKineticOrange
            }

            Text {
              textFormat: Text.PlainText
              visible: text !== ""
              width: parent.width
              text: root.balanceDetailText(root.balance)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Column {
            id: limitsSection
            visible: !root.isOverview && root.limits.length > 0
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: root.selectedModelId !== "__all__"
                ? "LIMITS · " + root.modelDisplayName(root.provider, root.selectedModelId)
                : "LIMITS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.limits

              LimitRow {
                required property var modelData
                width: limitsSection.width
                window: modelData
              }
            }
          }

          // ---------- Usage ----------
          PanelSeparator {
            visible: !root.isOverview && usageSection.visible
            foreground: root.foreground
          }

          Column {
            id: usageSection
            visible: !root.isOverview && !!root.provider
              && root.daysFor(root.provider, root.selectedModelId).days.length > 0
            width: parent.width
            spacing: Style.spacing.md

            readonly property var dayData: root.daysFor(root.provider, root.selectedModelId)
            readonly property var days: dayData.days || []
            readonly property real peak: Math.max(1, root.weekPeak({ recentDays: days }))

            PanelSectionHeader {
              width: parent.width
              text: usageSection.dayData.filtered
                ? "TOKENS BY DAY · " + root.modelDisplayName(root.provider, root.selectedModelId)
                : (root.selectedModelId !== "__all__" ? "TOKENS BY DAY · ACCOUNT TOTAL" : "TOKENS BY DAY")
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: usageSection.days

              DayRow {
                required property var modelData
                required property int index

                width: usageSection.width
                day: modelData
                ratio: Number(modelData.messageCount || 0) / usageSection.peak
                // By date, not by position: the Claude stats-cache fallback can
                // hand us a window that stops short of today.
                today: String(modelData.date || "") === root.todayDate()
              }
            }
          }

          // ---------- Models ----------
          PanelSeparator {
            visible: modelSection.visible
            foreground: root.foreground
          }

          Column {
            id: modelSection
            visible: !root.isOverview && (root.models.length > 0 || root.modelFilterText !== "")
            width: parent.width
            spacing: Style.spacing.md

            // Header + Scope toggle (Agent vs All Models)
            Row {
              width: parent.width

              Item {
                width: parent.width - (scopeToggleRow.visible ? scopeToggleRow.implicitWidth : 0)
                height: modelSectionHeader.implicitHeight

                PanelSectionHeader {
                  id: modelSectionHeader
                  text: "TOKENS BY MODEL"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                }
              }

              Row {
                id: scopeToggleRow
                visible: !root.isOverview
                spacing: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter

                Button {
                  text: "Agent"
                  selected: root.modelScope === "agent"
                  bordered: true
                  fontSize: Style.font.caption
                  verticalPadding: Style.space(2)
                  horizontalPadding: Style.space(6)
                  onClicked: root.modelScope = "agent"
                }

                Button {
                  text: "All Models"
                  selected: root.modelScope === "all"
                  bordered: true
                  fontSize: Style.font.caption
                  verticalPadding: Style.space(2)
                  horizontalPadding: Style.space(6)
                  onClicked: root.modelScope = "all"
                }
              }
            }

            // Model dropdown selector for the active agent
            Dropdown {
              id: activeAgentModelDropdown
              visible: !root.isOverview && root.provider && root.modelRows(root.provider, true).length > 0
              width: parent.width
              height: implicitHeight
              showLabel: false
              rowHeight: Style.space(26)
              options: {
                var baseRows = root.provider ? root.modelRows(root.provider, true) : []
                var activeCount = 0
                for (var j = 0; j < baseRows.length; j++) {
                  if (baseRows[j].total > 0) activeCount++
                }
                var opts = [{
                  value: "__all__",
                  label: "All Models (" + baseRows.length + ")" + (activeCount > 0 ? " · " + activeCount + " active" : "")
                }]
                for (var i = 0; i < baseRows.length; i++) {
                  opts.push({
                    value: baseRows[i].id,
                    label: baseRows[i].name + "  ·  " + (baseRows[i].total > 0 ? usage.formatTokenCount(baseRows[i].total) : "0 tok")
                  })
                }
                return opts
              }
              value: root.selectedModelId
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(val) {
                root.selectModelFor(root.provider, String(val || "__all__"))
              }
            }

            // Search filter field
            Row {
              width: parent.width
              spacing: Style.space(6)

              TextField {
                id: modelFilterField
                width: parent.width - (root.modelFilterText !== "" ? (clearFilterBtn.implicitWidth + Style.space(6)) : 0)
                placeholderText: (root.isOverview || root.modelScope === "all") ? "Search all models..." : "Filter models..."
                text: root.modelFilterText
                onTextChanged: root.modelFilterText = text
                verticalPadding: Style.space(3)
                horizontalPadding: Style.space(8)
                font.pixelSize: Style.font.caption
                onActiveFocusChanged: root.searchFocused = activeFocus
              }

              Button {
                id: clearFilterBtn
                visible: root.modelFilterText !== ""
                text: "✕"
                bordered: true
                fontSize: Style.font.caption
                verticalPadding: Style.space(3)
                horizontalPadding: Style.space(8)
                onClicked: {
                  root.modelFilterText = ""
                  modelFilterField.text = ""
                }
              }
            }

            Repeater {
              model: root.models

              ModelRow {
                required property var modelData
                width: modelSection.width
                row: modelData
                showProvider: root.isOverview || root.modelScope === "all"
                share: {
                  var rows = root.models
                  return rows.length > 0 ? (modelData.total / Math.max(1, rows[0].total)) : 0
                }
              }
            }

            Text {
              visible: root.models.length === 0 && root.modelFilterText !== ""
              text: "No models matching \"" + root.modelFilterText + "\""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
              topPadding: Style.space(4)
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: !root.isOverview && text !== ""
            width: parent.width
            topPadding: Style.space(2)
            text: root.footerText()
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
          }
        }
      }
    }
  }

  // Provider mark: resolves SVG asset or falls back to first letter glyph.
  component ProviderIcon: Item {
    id: iconComp
    property var provider: null
    property real iconSize: Style.space(18)

    width: iconSize
    height: iconSize

    readonly property var candidates: root.iconCandidatesForProvider(iconComp.provider, root.surface)
    property int candidateIndex: 0

    Image {
      id: iconImg
      anchors.fill: parent
      source: (iconComp.candidateIndex < iconComp.candidates.length) ? iconComp.candidates[iconComp.candidateIndex] : ""
      sourceSize.width: iconComp.iconSize * 2
      sourceSize.height: iconComp.iconSize * 2
      fillMode: Image.PreserveAspectFit
      visible: status === Image.Ready
      onStatusChanged: if (status === Image.Error && iconComp.candidateIndex < iconComp.candidates.length)
        Qt.callLater(function() { iconComp.candidateIndex++ })
    }

    Text {
      visible: iconImg.status !== Image.Ready
      anchors.centerIn: parent
      text: (iconComp.provider && iconComp.provider.providerName) ? iconComp.provider.providerName.charAt(0) : "󱚣"
      color: root.providerBrandColor(iconComp.provider)
      font.family: root.fontFamily
      font.pixelSize: iconComp.iconSize * 0.8
      font.bold: true
    }
  }

  // A limit window: label and percentage, meter, and reset countdown.
  component LimitRow: Column {
    id: limitRow
    property var window: null

    readonly property bool alarming: window && window.percent >= 0.9

    spacing: Style.space(6)

    Item {
      width: parent.width
      implicitHeight: Math.max(limitLabel.implicitHeight, limitValue.implicitHeight)

      Text {
        id: limitLabel
        textFormat: Text.PlainText
        // A model-scoped window is titled after its model, and those names run
        // long enough to reach the percentage, so the title gives way first.
        text: limitRow.window
          ? ((root.selectedModelId !== "__all__" && !limitRow.window.modelScoped ? "Account-wide · " : "")
            + limitRow.window.title)
          : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        anchors.left: parent.left
        anchors.right: limitValue.left
        anchors.rightMargin: Style.spacing.sm
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: limitValue
        textFormat: Text.PlainText
        text: limitRow.window && limitRow.window.percent >= 0
          ? Math.round((1 - limitRow.window.percent) * 100) + "% left"
          : "—"
        color: limitRow.alarming ? root.urgent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Meter {
      width: parent.width
      value: limitRow.window ? limitRow.window.percent : -1
      alarming: limitRow.alarming
      accentColor: root.provider ? root.providerBrandColor(root.provider) : root.foreground
    }

    Text {
      id: resetText
      textFormat: Text.PlainText
      width: parent.width
      text: {
        var remainingMs = root.resetMsFor(limitRow.window)
        return remainingMs > 0 ? "Resets in " + root.formatDuration(remainingMs) : ""
      }
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  // Rounded track showing the percentage of the allowance used.
  // Neo-tactile grooved bed, custom kinetic accent color, and leading-edge bead.
  component Meter: Item {
    id: meter
    property real value: -1
    property bool alarming: false
    property color accentColor: root.foreground
    property real thickness: Math.max(Style.space(5), Math.round(Style.spacing.controlHeight * 0.16))

    implicitHeight: thickness

    Rectangle {
      id: meterTrack
      anchors.fill: parent
      radius: height / 2
      color: root.alpha(root.surface, 0.85)
      border.color: root.alpha(root.foreground, 0.08)
      border.width: 1

      Rectangle {
        id: meterFill
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        radius: meterTrack.radius
        width: parent.width * root.clamp(meter.value, 0, 1)
        color: meter.alarming ? root.dojiKineticOrange : (meter.accentColor !== root.foreground ? meter.accentColor : root.foreground)

        Behavior on width {
          NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        // Tactile micro-indicator at leading edge
        Rectangle {
          visible: meterFill.width > parent.height
          anchors.right: parent.right
          anchors.rightMargin: 1
          anchors.verticalCenter: parent.verticalCenter
          width: Math.max(2, parent.height - 2)
          height: Math.max(2, parent.height - 2)
          radius: width / 2
          color: "#FFFFFF"
          opacity: 0.85
        }
      }
    }
  }

  // One row per day: label, bar, tokens. Today is picked out in full
  // foreground / hyper-lime so the week reads as a run-up to right now.
  component DayRow: Item {
    id: dayRow
    property var day: null
    property real ratio: 0
    property bool today: false

    implicitHeight: Math.max(dayLabel.implicitHeight, dayValue.implicitHeight) + Style.spacing.sm

    Text {
      id: dayLabel
      textFormat: Text.PlainText
      text: root.dayLabel(dayRow.day ? dayRow.day.date : "", dayRow.today)
      color: dayRow.today ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: dayRow.today
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(52)
    }

    Rectangle {
      id: dayTrack
      anchors.left: dayLabel.right
      anchors.right: dayValue.left
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      height: Math.max(Style.space(5), Math.round(Style.spacing.controlHeight * 0.16))
      radius: height / 2
      color: root.alpha(root.surface, 0.85)
      border.color: root.alpha(root.foreground, 0.08)
      border.width: 1

      Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        radius: parent.radius
        width: parent.width * root.clamp(dayRow.ratio, 0, 1)
        color: dayRow.today ? root.dojiHyperLime : root.alpha(root.foreground, 0.55)

        Behavior on width {
          NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
      }
    }

    Text {
      id: dayValue
      textFormat: Text.PlainText
      text: usage.formatTokenCount(dayRow.day ? Number(dayRow.day.messageCount || 0) : 0)
      color: dayRow.today ? (root.activeBrandColor !== root.foreground ? root.activeBrandColor : root.dojiHyperLime) : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      horizontalAlignment: Text.AlignRight
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(52)
    }

    MouseArea {
      id: dayHover
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
    }

    PanelToolTip {
      visible: dayHover.containsMouse
      text: root.dayTooltip(dayRow.day, dayRow.today)
      fontFamily: root.fontFamily
    }
  }

  // Model rows read as a table: the share bar fills the row behind the label
  // instead of stacking under it, which keeps the whole dashboard on one screen.
  component ModelRow: Item {
    id: modelRow
    property var row: null
    property real share: 0
    property bool showProvider: false

    implicitHeight: modelName.implicitHeight + Style.spacing.lg

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: root.alpha(root.foreground, 0.05)
    }

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: parent.width * root.clamp(modelRow.share, 0, 1)
      radius: Style.cornerRadius
      color: root.alpha(root.foreground, 0.14)

      Behavior on width {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }
    }

    Text {
      id: modelName
      textFormat: Text.PlainText
      text: {
        if (!modelRow.row) return ""
        var prefixParts = []
        if (modelRow.showProvider && modelRow.row.providerName) prefixParts.push(modelRow.row.providerName)
        if (modelRow.showProvider && modelRow.row.accountName
            && modelRow.row.accountName !== modelRow.row.providerName)
          prefixParts.push(modelRow.row.accountName)
        var prefix = prefixParts.length > 0 ? ("[" + prefixParts.join(" · ") + "] ") : ""
        return prefix + modelRow.row.name
      }
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
      anchors.left: parent.left
      anchors.leftMargin: Style.space(8)
      anchors.right: modelTokens.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      id: modelTokens
      textFormat: Text.PlainText
      text: modelRow.row ? (modelRow.row.total > 0 ? usage.formatTokenCount(modelRow.row.total) : "0 tok") : ""
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
    }

    MouseArea {
      id: modelHover
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
    }

    PanelToolTip {
      visible: modelHover.containsMouse
      text: root.modelTooltip(modelRow.row)
      fontFamily: root.fontFamily
    }
  }
}
