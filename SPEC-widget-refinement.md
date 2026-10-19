# Spec: Agents Bar Widget Refinement

## Capability map

| Module | Responsibility | Depends on |
|---|---|---|
| `record-contract` | Preserve account/model metadata and model-scoped limits from usage records | — |
| `model-filtering` | Make a selected model affect every metric the record can safely scope | `record-contract` |
| `account-selection` | Keep separate accounts identifiable and switchable without mixing limits | `record-contract` |
| `widget-audit` | Correct misleading labels, missing fields, freshness, and empty/error states | `model-filtering`, `account-selection` |

Build order: `record-contract` → `model-filtering` → `account-selection` → `widget-audit`.

## Objective

Refine the Omarchy agents bar widget so a user can distinguish accounts, select a
model, and trust that the displayed usage and allowance details describe the
selected scope. The widget remains a read-only consumer of JSON usage records;
credential handling and provider collection stay outside this plugin.

## Record contract

Existing fields remain valid. New fields are optional and additive:

```json
{
  "id": "codex-work",
  "name": "Codex (Work)",
  "providerId": "codex",
  "accountId": "work",
  "accountName": "Work",
  "accountEmail": "work@example.test",
  "currentModel": "gpt-5",
  "availableModels": ["gpt-5"],
  "limits": [
    {"modelId": "gpt-5", "title": "Weekly", "percent": 0.2, "resetsAt": "..."}
  ],
  "recentDaysByModel": {
    "gpt-5": [{"date": "2026-10-19", "messageCount": 1000}]
  }
}
```

The unique `id` identifies a usage record. `providerId` groups records that use
the same service. `accountId` identifies the account within that service. If
these fields are absent, the widget falls back to the existing record id/name
and continues rendering the record.

## User behavior

- The default model scope is **All models**.
- A model dropdown uses stable model ids internally and friendly names visually.
- Selecting a model filters model rows and today's token total.
- If model-specific limits exist, selected-model view shows matching model limits
  plus account-wide limits. If no model-specific limits exist, the account-wide
  limit remains visible and is explicitly labeled as account-wide.
- Daily history is filtered only when `recentDaysByModel` is present. Otherwise
  the section is labeled as account-wide rather than implying a model-specific
  history.
- Multiple records with the same `providerId` are never merged. The active
  account can be changed through an account selector and remains independently
  available in navigation.
- Older records without account/model metadata continue to render using the
  current behavior.

## Widget audit requirements

- Preserve `availableModels`, `currentModel`, account metadata, and timestamps
  while normalizing records and synced snapshots.
- Show auth/collection status records instead of hiding them when they contain
  no usage yet.
- Do not display prompts for providers that declare `hasPromptStats: false`.
- Use the record currency for balances and show when a balance is estimated.
- Clamp invalid limit percentages before rendering meters and percentages.
- Show the last update time and distinguish local from synced data.
- Keep all controls keyboard reachable through the existing QML panel focus flow.

## Tech stack and commands

- QML/QtQuick running in Quickshell.
- No repository test runner or QML linter is installed in this checkout.
- Verification commands:
  - `python3 -m json.tool manifest.json`
  - `quickshell --version`
  - `quickshell -p /home/doji/.config/omarchy/plugins/doji.agents/Panel.qml` when a
    graphical Quickshell session is available.

## Boundaries

- Always: preserve backward compatibility; keep credentials and provider I/O out
  of the widget; validate untrusted JSON shapes before rendering; verify syntax
  and runtime behavior after each slice.
- Ask first: changes to collectors outside this plugin, new dependencies, or
  changes to the persisted Omarchy settings schema.
- Never: expose credentials, merge separate accounts into one allowance, or
  delete existing usage/history data.

## Success criteria

- A selected model changes all available model-scoped displays without changing
  the underlying record.
- Account records remain separately navigable and an account selector appears
  when records share a provider.
- Legacy records still render.
- Auth errors, balance currency, prompt availability, and update freshness are
  communicated accurately.
- The manifest remains valid and the widget loads without QML errors.
