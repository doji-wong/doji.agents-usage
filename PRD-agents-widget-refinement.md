# PRD: Agents Bar Widget Refinement

**Status:** Implemented; graphical verification pending  
**Owner:** Doji  
**Product:** `doji.agents` Omarchy bar widget

## 1. Summary

Improve the Agents bar widget so people can quickly understand which provider,
account, and model its usage information describes. The widget must remain a
read-only display of usage records, but it should make scope, freshness, limits,
balances, and collection/auth status unambiguous.

## 2. Problem

The widget can display usage from several AI coding providers, accounts, and
models. Without clear scope, a user may:

- mistake one account's allowance for another account's allowance;
- read an account-wide limit as if it were model-specific;
- assume a model filter changed metrics that cannot actually be filtered;
- misunderstand missing usage as zero usage;
- misread balances, currencies, estimated values, or stale/synced data.

These are trust failures: a compact widget is useful only when its numbers are
honest about what they represent.

## 3. Objective

Give an Omarchy user a reliable at-a-glance view of AI-agent usage that:

1. keeps separate accounts separate;
2. lets the user scope supported metrics to a model;
3. labels account-wide or estimated data instead of fabricating precision;
4. communicates auth, collection, freshness, and empty states; and
5. continues to display older usage records without requiring a migration.

## 4. Target users

Omarchy users who run more than one AI coding provider, use multiple accounts
or models, or work across multiple machines whose usage records may be synced.

## 5. User stories

- As a user with work and personal accounts for one provider, I can tell which
  account is selected and switch accounts without mixing their limits or
  balances.
- As a user who works with several models, I can choose a model and see the
  model-scoped usage that the provider actually supplies.
- As a user viewing a model, I can tell when a displayed limit or history is
  account-wide rather than model-specific.
- As a user whose provider is not authenticated or has not collected data yet,
  I see an explanatory status instead of an empty or misleading zero state.
- As a user checking a prepaid provider, I can distinguish a real balance from
  an estimate and see its currency.
- As a user with older records, I can continue using the widget with sensible
  legacy fallbacks.

## 6. Product requirements

### 6.1 Account identity and separation

- Each usage record represents one independently viewable account record.
- Records from the same provider must never be merged for limits, balances, or
  account-scoped usage.
- When multiple accounts belong to one provider, the UI exposes a clear account
  selector and identifies the active account by name and/or email when present.
- When only one account exists, the compact single-account layout is retained.
- Account identity may be unavailable in legacy records; those records remain
  separate and use their existing record identity as a fallback.

### 6.2 Model scope

- The default scope is **All models**.
- When model information is available, the user can select a model using a
  human-readable label backed by a stable model id.
- The selected model affects every metric that the record can reliably scope,
  including model rows, today's total, daily history, and model-specific
  limits.
- Account-wide limits remain visible when relevant and are labeled
  **Account-wide** rather than being presented as model-specific.
- If a metric has no reliable model breakdown, it remains visible with an
  explicit account-wide explanation; the UI does not invent a filtered value.
- If no model metadata exists, the widget keeps the existing all-data view.

### 6.3 Status and data honesty

- Auth or collection failures are shown as status information, even when no
  usage numbers exist yet.
- Providers that do not support prompt statistics do not show prompt metrics.
- Monetary values use the record's currency.
- Estimated balances are visibly marked as estimated.
- Limit percentages are constrained to a valid display range.
- The UI shows when data was last updated and distinguishes local data from
  synced data where that distinction affects interpretation.

### 6.4 Compatibility and scope boundaries

- Existing records without the new optional metadata continue to render.
- The widget remains read-only: credentials, provider API calls, account
  creation, and collector behavior remain outside this product.
- New record metadata is additive and optional; no existing usage/history data
  is deleted or rewritten by the widget.
- Keyboard navigation and existing bar/panel interactions remain available.

### 6.5 Overview simplification

- The overview is a status board, not a second detail panel.
- The overview filter row contains only **All**, **5h**, and **Weekly**.
- **5h** shows only records with a recognized 5-hour/session window.
- **Weekly** shows only records with a recognized weekly window; monthly-only
  records do not appear in this filter.
- **All** shows one primary status per agent: the most constrained available
  rate-limit window. Secondary windows remain available through **Inspect**.
- Filtered results rank the lowest remaining allowance first.
- Each overview card shows provider/account identity, one relevant remaining
  allowance, its reset time, and a meter when applicable.
- Balance-only records show remaining balance and estimate/currency qualifiers.
- Auth/collection-only records show their status instead of an empty usage
  card.
- Model selectors, token totals, prompt counts, and model rows are removed
  from the overview and remain available in the provider detail view.
- Overview status is always calculated from all models; a model selected in a
  detail view must not silently change the overview.

## 7. Out of scope

- Adding or changing provider collectors.
- Managing credentials, login, or account creation.
- Editing usage history or correcting provider-reported values.
- Merging rate limits across accounts or devices.
- Building a separate web dashboard or mobile interface.
- Adding new providers as part of this refinement.

## 8. UX outline

The panel retains its existing overview and provider navigation. Within a
provider view:

1. The active provider and account are visible near the top of the panel.
2. An account selector appears only when the provider has multiple accounts.
3. A model selector defaults to **All models** and appears when model choices
   are available.
4. The overview shows one compact status card per agent, while **Inspect**
   opens the existing detailed limits, usage, and model view.
5. Limits, today's usage, and model history reflect the selected scope when
   supported in the detail view.
6. Unsupported or account-wide data includes a short scope label.
7. Status, freshness, sync origin, and balance qualifiers appear close to the
   data they qualify.

## 9. Acceptance criteria

The refinement is complete when all of the following are true:

- A user can distinguish two accounts from the same provider and switch
  between them without any limit, balance, or usage leakage.
- The overview exposes only All, 5h, and Weekly filters; Name and Tokens are
  not primary overview controls.
- 5h and Weekly views exclude agents without the selected window.
- All view shows one most-constrained window per agent and ranks urgent
  allowances first.
- Overview cards do not render model selectors, token totals, prompt counts, or
  model rows.
- Selecting a model changes every supported model-scoped display and leaves
  unsupported account-wide data explicitly labeled.
- Account-wide limits are never described as model-specific.
- Auth-only, collection-error, empty, stale, local, and synced states are
  understandable without inspecting the underlying JSON.
- Currency and estimated-balance indicators are accurate for prepaid records.
- Invalid limit values cannot produce misleading meters or percentages.
- Legacy records with no account/model metadata remain usable.
- Existing keyboard, refresh, navigation, and self-hiding behavior continues
  to work.
- The widget loads without QML errors and the manifest remains valid.

## 10. Success measures

For representative records covering legacy, multi-account, model-scoped,
account-wide, auth-error, balance, and synced states:

- 100% of displayed limits and balances identify the correct account record.
- 100% of model-filtered metrics are either actually model-scoped or labeled
  account-wide.
- 0 regressions in rendering legacy records.
- 0 unqualified estimated balances or non-native currencies.

These are correctness gates for the widget, not analytics instrumentation.

## 11. Dependencies and risks

| Item | Risk | Mitigation |
|---|---|---|
| Collectors may omit account ids | Accounts cannot be grouped by a stable provider identity | Keep records independent and fall back to record id/name |
| Records may lack model breakdowns | A model selector could imply precision the data does not support | Preserve the account total and label it account-wide |
| Synced snapshots may be older | Remote records may lose identity or freshness context | Keep metadata additive and preserve legacy defaults |
| Quickshell has limited local linting | UI errors may be discovered only at runtime | Validate representative states and load the widget in a graphical session |

## 12. Decisions requested

Please review these product decisions before implementation proceeds:

1. Is the primary goal correctly stated as **trustworthy account/model scope**
   rather than adding new providers or collector capabilities?
2. Should **All models** remain the default whenever a model selector exists?
3. Is labeling unsupported metrics as **Account-wide** preferable to hiding
   them when a model is selected?
4. Are the listed out-of-scope boundaries correct, especially keeping collector
   and credential changes separate?

Once these decisions are approved, the technical implementation plan and task
breakdown can follow from this PRD.
