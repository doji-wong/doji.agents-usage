# Implementation Plan: Agents Widget Refinement

## Overview

Make the existing Omarchy agents widget account-aware and model-aware while
keeping the plugin read-only and compatible with the current usage-record
format. The implementation is limited to `Main.qml`, `Panel.qml`, and the
README's record contract documentation.

## Architecture decisions

1. Treat each usage JSON file as an independent account record. Never combine
   limits or balances across records.
2. Use optional `providerId`/`accountId` metadata to group accounts. Infer only
   a small set of known provider ids when older secondary records use ids such
   as `codex-work`; otherwise fall back to the record id.
3. Keep model selection state in the panel, keyed by the unique record id.
4. Preserve unknown fields at the record boundary only where they are needed by
   the UI; no collector or credential logic belongs in QML.
5. Apply model filtering only to data that can be scoped reliably. Explicitly
   label account-wide fallback data instead of fabricating model-level numbers.

## Task list

### Phase 1: Record contract

- [x] Task 1: Preserve account, model, and freshness metadata through `Main.qml`
  - Acceptance: optional metadata survives local and synced display objects;
    old records still render; auth-only records remain visible.
  - Verify: inspect representative local records and run manifest/syntax checks.
  - Files: `Main.qml`
  - Estimated scope: Medium

### Phase 2: Model filtering

- [x] Task 2: Make model selection affect usage and limits consistently
  - Acceptance: dropdown selection uses stable ids; model rows and today's
    totals follow it; matching model limits are shown with account-wide limits;
    unsupported daily history is labeled honestly.
  - Verify: exercise All/selected model states against local Antigravity and
    Codex records; check no-selection and missing-metadata fallbacks.
  - Files: `Panel.qml`, `Main.qml`
  - Estimated scope: Large

### Phase 3: Account selection

- [x] Task 3: Add account identity and switching
  - Acceptance: accounts sharing a provider are clearly labeled, selectable,
    and never blended; single-account providers retain the compact layout.
  - Verify: use default and secondary-style record ids plus explicit metadata.
  - Files: `Panel.qml`, `Main.qml`
  - Estimated scope: Medium

### Phase 4: Widget audit and documentation

- [x] Task 4: Correct misleading details and document the additive contract
  - Acceptance: currency, prompt availability, status, freshness, percentages,
    and sync labels are accurate; README documents account/model fields.
  - Verify: inspect Fireworks/auth-only/legacy record states and validate JSON.
  - Files: `Panel.qml`, `Main.qml`, `README.md`
  - Estimated scope: Medium

## Checkpoints

### After Task 1

- [x] Metadata is available to the panel without changing legacy behavior.
- [x] Manifest and QML structure remain valid.

### After Task 2–3

- [x] All-model and selected-model views remain usable.
- [x] Switching accounts never changes another account's limits or balance.

### Complete

- [x] Static verification passes; graphical verification requires the Omarchy display session.
- [x] No unrelated files were changed.
- [x] The README and implementation agree on the record contract.

## Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Existing collectors omit account ids | Accounts cannot be grouped reliably | Fall back to unique record ids and preserve separate tabs |
| Records lack per-day model totals | A model filter could mislead users | Keep daily history account-wide and label it explicitly |
| Synced snapshots omit new metadata | Remote accounts lose identity | Extend snapshot fields additively with legacy defaults |
| QML lacks a local linter | Syntax errors may surface only at runtime | Use small slices, `quickshell --version`, and a graphical load check |

## Open questions

- Collector changes for Antigravity and Claude multi-account discovery remain a
  separate follow-up because those collectors live outside this plugin.

## Extension: Approved Overview Simplification

The approved product direction makes the overview a compact status board. The
existing provider detail view keeps the full model and token information.

### Architecture decisions

1. Overview status is always computed with `__all__` model scope so a hidden
   detail selection cannot change the summary.
2. `5h` and `Weekly` are filters, not general sort modes: records without the
   selected window are excluded.
3. `All` selects one most-constrained rate-limit window per record. Balance-only
   and status-only records use their relevant fallback presentation.
4. The existing detail view remains the home for model selectors, token totals,
   prompt counts, and model rows.

### Task list

- [x] Task 5: Add tested overview filtering and urgency selection
  - Acceptance: only `all`, `session`, and `weekly` modes remain; 5h/Weekly
    exclude records without that window; All chooses the lowest remaining
    available window and uses all-model scope.
  - Verify: focused contract tests cover the mode list, all-model overview
    scope, and urgency markers.
  - Files: `Panel.qml`, `tests/test_widget_contract.py`
  - Estimated scope: Medium

- [x] Task 6: Replace overview cards with compact status summaries
  - Acceptance: cards show identity plus one relevant allowance/reset or a
    balance/status fallback; model/token details remain in Inspect only.
  - Verify: contract tests pass and the widget is loaded in Quickshell when a
    graphical session is available.
  - Files: `Panel.qml`, `tests/test_widget_contract.py`, `PRD-agents-widget-refinement.md`
  - Estimated scope: Medium

### Checkpoint: Overview simplification

- [x] All, 5h, and Weekly views show only relevant status cards.
- [x] Inspect still exposes detailed limits, usage, and model information.
- [x] Existing account/model compatibility behavior remains intact.
- [x] Tests and manifest checks pass.
