# ADR-003: Overview Board Window Prioritization and Dual-Meter Display

## Status
Accepted

## Date
2026-10-19

## Context
When developers use AI coding assistants in high-intensity workflows, their primary question when opening the bar widget is:
> *"Can I continue coding right now, which of my subscriptions is nearest exhaustion, and what is my reset timeline?"*

Modern AI coding agents typically operate under two distinct tiers of rate limits:
1. **Short-Term Session Allowances**: Rapid sliding windows (e.g., a 5-hour quota reset cycle in Claude Code and Google Antigravity) that govern burst usage.
2. **Long-Term Weekly / Monthly Quotas**: Sustained volume limits (e.g., 7-day rolling allowances) that prevent excessive weekly consumption.

Previous dashboard revisions presented several UX challenges:
- Displaying only one progress meter per agent made it ambiguous whether a 70% meter reflected the 5-hour burst limit or the weekly cap.
- Embedding daily token tables and per-model token splits directly on the overview board caused visual clutter, vertical scrolling fatigue, and sluggish scanning.
- Inactive, unauthenticated, or placeholder agents took up space on the overview board alongside active working subscriptions.

## Decision

1. **Dual Allowance Meters on Agent Cards**:
   - Each active agent card on the Overview board displays side-by-side meters for **5-Hour Session** and **Weekly** allowances when both are available.
   - Meters clearly show percentage remaining, formatted time until reset (`resets in 2h 15m`), and status health coloring.

2. **Dedicated Window Scope Filtering**:
   - Users can toggle the Overview board between three distinct focus modes:
     - **All**: Displays all authenticated agents with dual meters; ranking prioritizes whichever window is most constrained.
     - **5h**: Isolates agents with active 5-hour session quotas, ranked strictly by lowest session quota remaining.
     - **Weekly**: Isolates agents with weekly allowances, ranked strictly by lowest weekly quota remaining.
   - Instant keyboard navigation: <kbd>5</kbd> for 5h view, <kbd>w</kbd> for Weekly view, <kbd>a</kbd> for All view.
   - Scriptable CLI / IPC control: `omarchy-shell doji.agents sort session|weekly|all`.

3. **Urgent-First Sorting Algorithm**:
   - In all views, agents nearest to rate limit exhaustion are surfaced at the top of the board, allowing developers to immediately decide whether to switch providers.

4. **Strict Separation of Overview vs. Detail**:
   - The Overview board is strictly optimized for **quota health and triage**.
   - Model-level breakdowns, token history bar charts, and cache split statistics are moved exclusively to the individual provider inspection tabs (accessible via tab header or clicking "Inspect" on an agent card).

5. **Authenticated-Only Overview Population**:
   - Only agents with active authentication and valid telemetry records are rendered on the Overview board.
   - Unauthenticated agents (e.g., missing API keys or CLI login) remain accessible in the top tab navigation with inline setup guides, preventing dead cards from polluting active quota monitoring.

## Alternatives Considered

### Full Token Telemetry on Overview Cards
- **Pros**: All numbers visible on a single screen without clicking into tabs.
- **Cons**: Massive cards requiring endless vertical scrolling; defeats the purpose of a quick status bar popover; information overload when running 4+ providers.
- **Rejected**: Violates minimal, scannable desktop widget principles.

### Separate "5-Hour" and "Weekly" Top Tabs
- **Pros**: Completely separate pages for each window type.
- **Cons**: Multiplies top-level tab count; fragments agent monitoring across multiple pages; complicates keyboard navigation (<kbd>h</kbd>/<kbd>l</kbd>).
- **Rejected**: A single unified Overview tab with in-page view toggle and hotkeys is significantly faster and cleaner.

## Consequences
- **Scannability**: Instant assessment of coding headroom across all tools in less than 2 seconds.
- **Speed**: Dedicated hotkeys (<kbd>5</kbd>, <kbd>w</kbd>, <kbd>a</kbd>) enable instant window filtering without mouse clicks.
- **Clean Layout**: Overview remains compact, focused, and free of redundant charts.
