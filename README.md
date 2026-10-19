<div align="center">

# 🤖 doji.agents

**A native Omarchy status bar widget and interactive dashboard for monitoring AI coding agent subscriptions, rate limits, and token usage.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Omarchy](https://img.shields.io/badge/Platform-Omarchy-1793d1.svg?logo=archlinux&logoColor=white)](https://github.com/doji-wong/doji.agents-usage)
[![Framework: Quickshell](https://img.shields.io/badge/Framework-Quickshell%20%2F%20QML-41cd52.svg?logo=qt&logoColor=white)](https://quickshell.outfoxxed.me/)
[![Display: Wayland](https://img.shields.io/badge/Display-Wayland-orange.svg)](https://wayland.freedesktop.org/)

<br />

<img src="assets/walkthrough.gif" alt="Agents Panel Walkthrough" width="460" />

<p><em>Live overview board, window filters, token telemetry, and provider detail inspector.</em></p>

> [!TIP]
> A full-fidelity high-resolution walkthrough is available at [**assets/walkthrough.mp4**](assets/walkthrough.mp4).

</div>

---

## 🌟 Key Features

- **Unified Status Bar Indicator**: Displays a clean, dynamic status icon that reveals aggregate active agent state at a glance.
- **Smart Self-Hiding**: Completely disappears when no AI coding activity or subscriptions are detected on the machine—never clutters your status bar with empty widgets.
- **Overview Board**:
  - **All Agents View**: Scan every enabled provider in one unified board.
  - **5-Hour & Weekly Scopes**: Instant filtering to see which subscriptions have active short-term (5-hour) or weekly allowances, ranked lowest-remaining first.
- **Detailed Provider Inspection**:
  - **Rate Limit Gauges**: Real-time meters tracking percentage of usage remaining alongside precise reset countdowns (`resets in 1h 24m`, `resets in 5d 3h`).
  - **Tokens by Day**: 7-day activity bar charts with hover metrics detailing session counts and daily consumption.
  - **Tokens by Model**: Granular model breakdown with visual load bars, filter search, and input/output/cache splits.
  - **Prepaid Balance Gauges**: Fuel-gauge meters for prepaid providers (such as Fireworks) draining toward empty with funded-vs-spent tracking.
- **Multi-Account & Multi-Device Sync**:
  - Independent account tracking within the same provider (e.g. personal vs. team accounts).
  - Cross-workstation aggregation: seamlessly merge snapshots across multiple laptops or desktops via Syncthing, Dropbox, or rsync.
- **First-Class Keyboard Navigation & IPC**: Full vim-style keyboard navigation (`h`/`l`, `j`/`k`, `r`, `Esc`) and complete shell IPC integration via `omarchy-shell`.

---

## 🚀 Installation

### 1. Using Omarchy Plugin Manager (Recommended)

Install and enable `doji.agents` directly via the official `omarchy` CLI:

```bash
omarchy plugin add https://github.com/doji-wong/doji.agents-usage --enable
```

If you previously had the stock built-in `omarchy.agents` widget enabled in your bar, disable it first:

```bash
omarchy plugin disable omarchy.agents
omarchy plugin enable doji.agents
```

#### Bar Placement

Place the widget in your preferred bar section (e.g. right):

```bash
omarchy bar move doji.agents --section right
```

---

### 2. Manual Installation (Git Clone)

Clone the repository directly into your local Omarchy plugins directory:

```bash
git clone https://github.com/doji-wong/doji.agents-usage.git ~/.config/omarchy/plugins/doji.agents
omarchy plugin enable doji.agents
```

---

### 🔄 Updating

Update to the latest release at any time:

```bash
omarchy plugin update doji.agents
```

Or pull the latest changes via Git:

```bash
cd ~/.config/omarchy/plugins/doji.agents && git pull
```

---

## 📊 Supported Providers & Collectors

`doji.agents` reads modular JSON records written to `~/.local/state/omarchy/agents/usage/` by `omarchy-agent-usage-update`.

| Provider | Tracked Limits & Quotas | Local Telemetry & Stats | Auth / Config Source |
|:---|:---|:---|:---|
| **Google Antigravity** | 5h session quota + weekly window | Transcripts grouped by model (Gemini 3.8 Flash, Gemini 4 Argon, Claude 3.5, etc.) | Local session state |
| **Anthropic Claude Code** | Anthropic OAuth limits (5h session + 7-day weekly) | Project transcripts (`~/.claude/projects`), opencode sessions, `stats-cache.json` | `CLAUDE_CONFIG_DIR`, OAuth credentials |
| **OpenAI Codex** | App-server RPC limits & tier status | Native Codex CLI session logs, pi, and opencode sessions | `CODEX_HOME`, `~/.codex` |
| **Fireworks AI** | Estimated prepaid ledger (funding minus rated costs) | Fireworks billing API, daily tokens & model usage (last 30 days) | `FIREWORKS_API_KEY`, `~/.fireworks/auth.ini`, `~/.config/omarchy/agents/fireworks.json` |

---

## 🎮 Navigation & Keyboard Shortcuts

The panel is optimized for seamless keyboard and pointer interaction:

### Mouse Controls
- **Left Click**: Open panel / Toggle dashboard.
- **Middle Click**: Cycle directly to the next subscription tab.
- **Right Click**: Launch default coding agent workspace.

### Keyboard Shortcuts (When Panel is Focused)
| Key | Action |
|:---|:---|
| <kbd>h</kbd> / <kbd>l</kbd> | Navigate to previous / next subscription tab |
| <kbd>j</kbd> / <kbd>k</kbd> | Scroll dashboard content up / down |
| <kbd>5</kbd> | In Overview: filter to **5-hour session** agents |
| <kbd>w</kbd> | In Overview: filter to **Weekly** window agents |
| <kbd>a</kbd> | In Overview: show **All** agents |
| <kbd>r</kbd> or <kbd>Enter</kbd> | Trigger instant telemetry refresh |
| <kbd>Tab</kbd> | Transfer focus to adjacent bar panel |
| <kbd>Esc</kbd> | Close panel |

---

## 💻 CLI & IPC Control

You can inspect, navigate, and control the widget programmatically from terminal commands, custom scripts, or Hyprland keybindings via `omarchy-shell`:

```bash
# Open, close, or toggle the panel
omarchy-shell doji.agents open
omarchy-shell doji.agents close
omarchy-shell doji.agents toggle

# Refresh telemetry records immediately
omarchy-shell doji.agents refresh

# Switch to the next subscription tab
omarchy-shell doji.agents next

# Select a specific provider or overview
omarchy-shell doji.agents select __overview__
omarchy-shell doji.agents select antigravity
omarchy-shell doji.agents select codex
omarchy-shell doji.agents select claude
omarchy-shell doji.agents select fireworks

# Set overview sort & filter mode
omarchy-shell doji.agents sort session   # 5-hour window view
omarchy-shell doji.agents sort weekly    # Weekly window view
omarchy-shell doji.agents sort all       # All agents view
```

*(The legacy alias `omarchy.agents` remains supported for compatibility).*

---

## ⚙️ Configuration & Settings

Settings are stored under the widget's configuration block in `~/.config/omarchy/shell.json` and can be adjusted with the `omarchy bar set` command.

| Configuration Key | Type | Default | Description |
|:---|:---:|:---:|:---|
| `refreshIntervalSec` | `number` | `900` (15m) | Telemetry regeneration interval in seconds |
| `syncMode` | `string` | `"Off"` | Set to `"On"` to export local snapshots and merge multi-machine metrics |
| `syncDir` | `string` | `""` | Synchronized folder path (e.g. `~/Sync/agent-usage`, Dropbox, Syncthing) |
| `syncFileName` | `string` | `<hostname>.json` | File name for this workstation's exported snapshot |
| `syncDeviceId` | `string` | `<hostname>` | Stable machine identifier recorded inside the snapshot |
| `providers` | `object` | *all enabled* | Per-agent enablement toggle map |

### Example Configuration Commands

```bash
# Set refresh interval to 5 minutes (300 seconds)
omarchy bar set doji.agents refreshIntervalSec 300 --json

# Set synchronized directory for cross-device metrics
omarchy bar set doji.agents syncDir '~/Sync/agent-usage'
omarchy bar set doji.agents syncMode 'On'

# Toggle individual providers
omarchy bar set doji.agents providers '{
  "antigravity": { "enabled": true },
  "claude": { "enabled": true },
  "codex": { "enabled": true },
  "fireworks": { "enabled": false }
}' --json
```

---

## 🗄️ Architecture & Data Contract

```
┌────────────────────────────────────────────────────────┐
│                   Omarchy Status Bar                   │
│         [  󱚣 doji.agents  ]  ◄── Panel.qml             │
└───────────────────────────┬────────────────────────────┘
                            │
               watches ~/.local/state/omarchy/agents/usage/
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
  antigravity.json     claude.json          codex.json ...
        ▲                   ▲                   ▲
        │                   │                   │
  ┌─────┴───────────────────┴───────────────────┴─────┐
  │         omarchy-agent-usage-update                │
  │   Runs independent modular collectors per agent   │
  └───────────────────────────────────────────────────┘
```

The panel treats each JSON file in the usage directory as one independent account record.

### Account and Model Records Contract

Collectors may supply these additive fields without breaking older versions:

| Field | Meaning |
|:---|:---|
| `providerId` | Stable service ID used to group accounts, such as `codex` |
| `accountId` | Stable account ID inside that service |
| `accountName` / `accountEmail` | Human-readable account identity shown in the panel |
| `currentModel` | The model currently selected by the provider |
| `availableModels` | Models the provider can currently expose |
| `limits[].modelId` | Optional model ID for a model-scoped allowance |
| `recentDaysByModel` | Optional per-model daily token history |

If the optional fields are absent, the panel falls back to the record's existing `id` and `name`. Separate records are never merged, preventing limits or balances from leaking between accounts.

### Authentication & Provider Details

- **Claude Code**: Needs a signed-in CLI; without credentials the panel falls back to local stats only. A non-default Claude directory is honored via `CLAUDE_CONFIG_DIR`, Codex via `CODEX_HOME`.
- **Fireworks AI**: Reads `FIREWORKS_API_KEY` and `FIREWORKS_ACCOUNT_ID` first, then `~/.fireworks/auth.ini`, then `~/.local/share/opencode/auth.json`. Fireworks balance can be tracked via `~/.config/omarchy/agents/fireworks.json`:

```json
{
  "accountId": "",
  "fundedAmount": 20,
  "fundedAt": "2026-07-01"
}
```

### Adding New Agent Collectors

Adding support for an entirely new AI agent requires **zero modifications** to this QML plugin. Simply add an executable collector script that writes a standard JSON record conforming to the contract:

```json
{
  "providerId": "myagent",
  "name": "My Agent",
  "accountName": "user@example.com",
  "limits": [
    {
      "label": "5h Session",
      "percentUsed": 42.5,
      "resetAt": "2026-10-19T21:00:00Z"
    }
  ],
  "recentDays": [
    { "date": "2026-10-19", "tokens": 1250000 }
  ],
  "models": [
    { "name": "custom-model", "tokens": 1250000 }
  ]
}
```

Once the JSON file lands in `~/.local/state/omarchy/agents/usage/`, the dashboard automatically discovers it, adds a dedicated tab, and binds its metrics in real time.

---

## 📄 License

Distributed under the [MIT License](LICENSE). Built for the Omarchy desktop ecosystem.
