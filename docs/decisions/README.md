# Architecture Decision Records (ADRs)

This directory documents the significant architectural and technical decisions made in `doji.agents`.

## Why ADRs?

Code shows *what* was built. ADRs capture the *why* — the context, constraints, trade-offs, and alternatives considered. Future maintainers and AI agents should consult these records before modifying foundational patterns or proposing architectural changes.

## Decision Log

| ID | Title | Status | Date |
|:---|:---|:---:|:---:|
| [ADR-001](ADR-001-file-based-state-and-modular-collectors.md) | File-Based State Discovery via Modular External Collectors | Accepted | 2026-10-19 |
| [ADR-002](ADR-002-multi-account-isolation-and-additive-schema.md) | Multi-Account Isolation and Additive Record Contract | Accepted | 2026-10-19 |
| [ADR-003](ADR-003-overview-board-window-prioritization.md) | Overview Board Window Prioritization and Dual-Meter Display | Accepted | 2026-10-19 |
| [ADR-004](ADR-004-cross-device-snapshot-synchronization.md) | Cross-Device Snapshot Synchronization via File Replication | Accepted | 2026-10-19 |
| [ADR-005](ADR-005-neo-tactile-brand-identity-and-design-system.md) | Neo-Tactile Brand Identity and Design System | Accepted | 2026-10-19 |

## ADR Lifecycle

```
PROPOSED → ACCEPTED → (SUPERSEDED by ADR-xxx or DEPRECATED)
```

1. **Proposed**: Under review and open for team/maintainer discussion.
2. **Accepted**: Approved and implemented in the codebase.
3. **Superseded**: Replaced by a newer decision (link to the replacing ADR).
4. **Deprecated**: No longer relevant or actively used.

Do not delete or overwrite historical ADRs when decisions change; write a new ADR referencing and superseding the prior one.
