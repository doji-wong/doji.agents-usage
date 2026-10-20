# ADR-001: File-Based State Discovery via Modular External Collectors

## Status
Accepted

## Date
2026-10-19

## Context
`doji.agents` is a native Quickshell / QML status bar widget and dashboard for Omarchy on Wayland. It monitors AI coding agent subscriptions, rate limits, token consumption, and model telemetry across heterogeneous tools including Google Antigravity, Anthropic Claude Code, OpenAI Codex, and Fireworks AI.

These providers have vastly different authentication models, data formats, and collection requirements:
- Some expose local JSON transcripts (`~/.claude/projects`, `~/.codex/sessions`).
- Some require OAuth credential refreshes, internal app-server RPCs, or web API calls.
- Some maintain SQLite or key-value caches.
- Some providers may crash, hang, rate-limit, or require network access.

We needed an architecture that keeps the Wayland desktop environment performant, secure, and resilient while allowing new agent integrations to be added seamlessly.

## Decision
Decouple the display layer completely from data collection and credential handling:

1. **Strict Display-Only Responsibility**: The QML widget (`Main.qml`, `Panel.qml`, `Agent.qml`) performs **zero** network requests, credential storage, or process scraping. It acts purely as a presentation and state-aggregation engine.
2. **Standardized Directory of Independent Records**: External collectors (driven by `omarchy-agent-usage-update`) write atomic JSON records to `~/.local/state/omarchy/agents/usage/` (e.g. `antigravity.json`, `claude.json`, `codex.json`).
3. **Reactive Inotify Watching**: `Agent.qml` uses Quickshell's reactive `FileView` to watch its assigned record file. When any collector writes a record, inotify triggers an instant, event-driven UI update without polling.
4. **Independent Modular Collector Scripts**: Collectors run out-of-process on background timers or manual trigger. Each provider has its own collector logic.

## Alternatives Considered

### In-Process QML / JavaScript HTTP Requests
- **Pros**: All logic contained within the plugin repository; no external collector dependency.
- **Cons**: QML's embedded JavaScript engine is single-threaded with the UI render loop; network latency, DNS timeouts, or parsing large transcript files would stutter or freeze the entire desktop status bar. Furthermore, QML has no secure credential storage (keyring) integration, and requires exposing API keys and tokens in widget memory or config.
- **Rejected**: Violates Wayland desktop smoothness and security isolation principles.

### Persistent D-Bus Daemon Service
- **Pros**: Clean IPC architecture; standard on Linux desktops.
- **Cons**: Requires creating, packaging, and maintaining a separate systemd daemon or D-Bus service; adds complex XML introspection interfaces, IPC lifecycle management, and failure recovery. Overkill for predominantly read-only status metrics.
- **Rejected**: Significant operational complexity with minimal benefit over standard POSIX file-watching.

### Monolithic State File (`agents.json`)
- **Pros**: Single file to read and parse.
- **Cons**: Write contention between concurrent collector processes; if one provider collector crashes mid-write or corrupts the JSON, all providers become unavailable; cannot independently add or remove providers via file deletion.
- **Rejected**: Lacks modular fault isolation.

## Consequences
- **Security**: The UI layer holds zero credentials, API tokens, or secrets. Authentication files remain restricted to user-level permissions.
- **Stability**: A hanging, failing, or unauthenticated collector never stalls or crashes the desktop status bar.
- **Extensibility**: Adding a new AI agent provider requires zero modifications to this QML plugin. Developers or users only need to drop a compliant JSON file into `~/.local/state/omarchy/agents/usage/`.
- **Performance**: Inotify-based `FileView` guarantees zero CPU utilization when idle, updating instantly only when data changes on disk.
- **Constraint**: Telemetry freshness depends on external collector invocation (managed by Omarchy cron/systemd service or `omarchy-shell doji.agents refresh`).
