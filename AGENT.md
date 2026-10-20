# Agent Instructions: `doji.agents`

This file is the operating contract for coding agents working in this
repository. Follow it together with the current product requirements and the
user's request. Keep the work small, explicit, and verifiable.

## Current product gate

The active product document is:

- [PRD-agents-widget-refinement.md](PRD-agents-widget-refinement.md)

It is approved for the current refinement. Do not expand its scope or treat
new product decisions as settled without updating the PRD and getting user
approval. The existing [SPEC-widget-refinement.md](SPEC-widget-refinement.md)
and `tasks/` documents describe the current implementation context and should
be updated when approved requirements change.

## Project mission

`doji.agents` is a native Quickshell/Omarchy bar widget that reads usage JSON
records and presents provider, account, model, limit, balance, history, and
collection-status information. It is a display layer, not a credential
manager or provider integration service.

The product standard is trustworthy scope: every number must be clear about
which record, account, model, time window, currency, and data origin it
describes.

## Repository map

- `Panel.qml` — bar button, popup layout, navigation, model/account scope, and
  display behavior.
- `Main.qml` — usage-record discovery, file watching, refresh processes,
  snapshots, and normalized provider data.
- `Agent.qml` — one JSON record watcher and parser.
- `README.md` — user-facing behavior, settings, and record contract.
- `manifest.json` — plugin metadata, entry point, defaults, and settings schema.
- `docs/decisions/` — Architecture Decision Records (ADRs) capturing design rationale, constraints, and trade-offs.
- `tests/test_widget_contract.py` — lightweight manifest and QML contract tests.
- `assets/` — provider marks and light/dark variants.
- `SPEC-widget-refinement.md` — technical specification for the current
  account/model refinement.
- `tasks/plan.md` and `tasks/todo.md` — implementation plan and task status.

## Required workflow

### 1. Understand the request

Before editing:

1. Read the relevant PRD section, existing ADRs in `docs/decisions/`, and the files named by the request.
2. Inspect the existing implementation and related tests.
3. State assumptions about scope, data shape, and behavior.
4. Check for contradictions between the PRD, technical spec, task files, and
   existing code.

If a requirement is missing or contradictory, stop and surface the exact
conflict. Do not silently invent product behavior.

### 2. Respect the gates

Use this sequence for non-trivial work:

1. PRD approval — agree on objective, boundaries, and acceptance criteria.
2. Technical plan — identify files, dependencies, risks, and checkpoints.
3. Task breakdown — define small tasks with acceptance and verification.
4. Implementation — make one focused, reversible slice at a time.
5. Verification — run automated checks and inspect runtime behavior where
   available.
6. Handoff — report changed files, verification results, and any remaining
   limitation.

Do not skip from a vague request directly to broad QML edits.

### 3. Implement in thin slices

- Read a file before changing it.
- Prefer the smallest change that satisfies the approved requirement.
- Preserve unrelated user changes and existing behavior.
- Add or update a contract test when behavior can be checked statically.
- Keep product decisions in the PRD, technical decisions in the spec/plan, and major architectural decisions recorded in `docs/decisions/`.
- Do not add speculative abstractions, providers, settings, or dependencies.

## Product and data boundaries

Always:

- Treat each usage record as an independent account record.
- Preserve backward compatibility with records lacking optional metadata.
- Keep account/model scope explicit in labels and summaries.
- Show account-wide data as account-wide; never fabricate model-level values.
- Preserve auth, collection, freshness, sync-origin, currency, and estimate
  qualifiers when they are available.
- Validate JSON shapes and handle missing, malformed, or partial records safely.
- Keep controls keyboard reachable through the existing panel flow.

Ask the user first before:

- changing provider collectors or credential behavior;
- changing the persisted Omarchy settings schema;
- adding a dependency or external service;
- changing the usage-record contract incompatibly;
- deleting or rewriting usage/history data;
- changing plugin activation, aliases, or public settings semantics.

Never:

- expose credentials, tokens, or secrets;
- merge limits or balances from separate accounts;
- hide an auth/collection failure as zero usage;
- remove or weaken a failing test to make a change pass;
- edit generated/vendor files without a clear project requirement;
- use destructive filesystem or git commands to resolve uncertainty.

## Quickshell/QML conventions

- Follow the import and component patterns already used in `Main.qml`,
  `Panel.qml`, and `Agent.qml`.
- Keep record normalization and file/process concerns in `Main.qml`; keep
  presentation and interaction concerns in `Panel.qml`.
- Use stable record keys for selection state so a refresh cannot switch the
  user's account or model implicitly.
- Treat optional fields as optional and use explicit fallbacks.
- Prefer small pure helper functions for normalization, filtering, sorting,
  and display formatting.
- Do not assume a provider supports a metric merely because another provider
  does.
- Avoid changing collector behavior from QML.

## Verification commands

Run the checks relevant to the changed files:

```bash
python3 -m unittest discover -s tests -v
python3 -m json.tool manifest.json
quickshell --version
```

When a graphical Quickshell session is available, load the widget and manually
check the affected states:

```bash
quickshell -p /home/doji/.config/omarchy/plugins/doji.agents/Panel.qml
```

For UI changes, verify at least the applicable legacy, empty, auth/error,
multi-account, model-scoped, account-wide, balance, local, synced, keyboard,
refresh, and self-hiding states. If graphical verification is unavailable,
say so explicitly rather than implying it passed.

## Definition of done

A task is complete only when:

- the requested behavior is implemented within the approved scope;
- relevant tests and syntax/manifest checks pass;
- the runtime behavior is verified or the limitation is documented;
- no unrelated files or behavior were changed;
- the PRD/spec/task documents reflect any changed decision;
- ADRs in `docs/decisions/` capture any new architectural decisions or trade-offs;
- the final report names changed files, checks run, and known follow-ups.

## Agent communication contract

At the start of substantial work, provide:

```text
ASSUMPTIONS:
1. ...
2. ...

PLAN:
1. ...
2. ...
```

During work, report meaningful discoveries, especially conflicts or missing
requirements. At the end, lead with the outcome and include concise evidence.
Ask before expanding scope; do not use confidence or speed as a substitute for
verification.

