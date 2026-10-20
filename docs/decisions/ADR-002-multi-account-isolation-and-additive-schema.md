# ADR-002: Multi-Account Isolation and Additive Record Contract

## Status
Accepted

## Date
2026-10-19

## Context
Developers commonly use multiple accounts within a single AI provider ecosystem — for example:
- A personal Anthropic or OpenAI subscription alongside a corporate enterprise seat.
- Multiple Antigravity profiles with differing quota tiers.
- Distinct API keys for testing or specialized workloads.

Earlier iterations identified records primarily by provider name or file basenames, introducing the risk of:
1. Merging limits or token counts across distinct accounts, presenting a false aggregate quota that does not exist in any single account.
2. Leaking prepaid balances or rate limits between separate billing entities.
3. Breaking existing collectors or custom user scripts if the schema required a breaking upgrade.

We needed a contract that supports first-class multi-account workflows, strictly preserves quota isolation, and guarantees backward compatibility.

## Decision

1. **Sovereign Account Records**:
   - Each JSON file in `~/.local/state/omarchy/agents/usage/` represents one distinct, sovereign account record.
   - Separate records are **never merged**; limits, balances, and token counters remain strictly isolated to that specific record.

2. **Stable Record Key Identification**:
   - A unique, stable `recordKey` is established per record:
     `recordKey = (providerId && accountId) ? (providerId + ":" + accountId) : (id || fileName)`
   - Navigation and UI selection bind to this stable key, ensuring that telemetry refreshes never unexpectedly switch the user's active account or model.

3. **Additive, Non-Breaking Schema**:
   - All new metadata fields are additive and optional:
     - `providerId`: Service identifier (e.g. `codex`, `claude`, `antigravity`).
     - `accountId`: Stable account identifier within the service.
     - `accountName` / `accountEmail`: Human-readable label displayed in UI.
     - `currentModel`: Currently active model selected in the agent CLI.
     - `availableModels`: List of model IDs available to the account.
     - `limits[].modelId`: Model identifier for model-scoped allowances.
     - `recentDaysByModel`: Per-model daily token breakdown.
   - When optional fields are omitted, the widget falls back gracefully to `id` and `name`, maintaining 100% backward compatibility with legacy collectors.

4. **Trustworthy Scope Qualification**:
   - If a metric is model-specific (e.g., a limit with `modelId`), it is presented when that model is selected.
   - If a metric is account-wide (such as provider tier allowances or balance), it is explicitly labeled as **Account-wide** rather than fabricating false model-level numbers.

## Alternatives Considered

### Provider-Level Account Aggregation
- **Pros**: Fewer tabs in the dashboard; single view per provider brand.
- **Cons**: Rate limits and allowances are strictly enforced by providers per token/account. If an agent has two accounts (one with 0% remaining and one with 100% remaining), showing an average (50%) or sum is deceptive and leads to unexpected rate-limiting errors during coding.
- **Rejected**: Deceptive metrics violate our core standard of trustworthy scope.

### Breaking Schema Versioning (v2 Specification)
- **Pros**: Clean slate; eliminates legacy field fallbacks in parser code.
- **Cons**: Breaks existing user installations, custom collectors, and external sync files; requires synchronized migrations across multiple independent repositories.
- **Rejected**: Unnecessary friction when additive fields achieve the exact same functionality without disruption.

## Consequences
- **Integrity**: Quota, allowance, and balance metrics are trustworthy; users always know exactly which account and model a number represents.
- **Compatibility**: Legacy collectors continue to function without changes.
- **Multi-Account UX**: Users can seamlessly switch between multiple accounts of the same provider via dedicated account selectors and tabs.
