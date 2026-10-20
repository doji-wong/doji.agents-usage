# ADR-004: Cross-Device Snapshot Synchronization via File Replication

## Status
Accepted

## Date
2026-10-19

## Context
Many developers use multiple workstations (e.g., a high-powered desktop workstation and a portable laptop for travel or meetings).

While rate limit allowances and reset countdowns are tied to provider accounts, token consumption history, daily activity charts, and session logs are accumulated locally on the specific device where the coding agent was executed.

Users desire an aggregated picture of their daily token consumption and productivity across all workstations. However:
- Requiring a dedicated cloud backend introduces hosting costs, authentication complexity, and telemetry privacy concerns.
- Requiring real-time peer-to-peer network connections between machines fails when devices are offline, on different subnets, or behind corporate NATs.

## Decision

1. **Decoupled Snapshot Export**:
   - When `syncMode` is set to `"On"` in widget settings, the widget periodically exports a local machine snapshot to a user-designated directory (`syncDir`):
     - Default file name: `<hostname>.json` (configured via `syncFileName`).
     - Includes: `syncDeviceId` (hostname), daily token totals, model usage aggregates, and active date keys.

2. **Replication Agnostic**:
   - The synchronization transport is decoupled entirely from the widget. Users can use any standard local or cloud file replication tool they already trust:
     - Syncthing
     - Dropbox / Google Drive / Nextcloud
     - rsync / cron jobs
     - Git / shared NFS mount

3. **Deterministic Snapshot Aggregation in `Main.qml`**:
   - When `syncMode` is active, `Main.qml` discovers all snapshot files present in `syncDir`.
   - Aggregation merges token metrics by date key:
     `activeDates[date] = sum(device[date].tokens)`
   - Model usage buckets are combined additively.

4. **Quota Authority & Partitioning**:
   - **Rate limit allowances, reset countdowns, and active credentials remain strictly local** to the live collector on the active machine.
   - Remote snapshots never overwrite or blend active rate limit percentages or reset timers, preventing stale remote snapshot state from corrupting live quota tracking.

## Alternatives Considered

### Centralized Cloud Backend API
- **Pros**: Instantaneous push updates; central dashboard.
- **Cons**: Requires building, securing, hosting, and maintaining a server infrastructure; requires user accounts; creates data privacy risks by transmitting proprietary code token telemetry over third-party servers.
- **Rejected**: Antithetical to Omarchy's local-first, privacy-respecting desktop philosophy.

### Direct Peer-to-Peer Socket Synchronization (LAN / Tailscale)
- **Pros**: Direct transfer without intermediate folder.
- **Cons**: Both devices must be powered on and connected simultaneously; fails when working on a train/plane without LAN connectivity; requires socket listener and port management in QML/C++.
- **Rejected**: Far more fragile than asynchronous file synchronization.

## Consequences
- **Privacy & Ownership**: 100% local-first; telemetry never leaves the user's private hardware or encrypted sync folders.
- **Tooling Freedom**: Zero vendor lock-in; works with Syncthing, Dropbox, rsync, or Git without any special plugin logic.
- **Offline Tolerance**: Laptops can operate offline for days; when reconnected to the sync folder, historical token charts catch up automatically.
- **Integrity**: Live rate limit meters remain authoritative and uncorrupted by remote history.
