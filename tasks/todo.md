# Agents Widget Refinement

- [x] Task 1: Preserve account, model, and freshness metadata through `Main.qml`
- [x] Task 2: Make model selection affect usage and limits consistently
- [x] Task 3: Add account identity and switching
- [x] Task 4: Correct misleading details and document the additive contract
- [x] Follow-up: Improve overview sorting for 5-hour and weekly windows

## Checkpoint: Complete

- [x] Manifest and static/runtime-loader verification pass
- [x] No unrelated files changed

## Approved follow-up: Simplify overview status board

- [x] Task 5: Filter 5h and Weekly views to matching windows and sort urgent
  allowances first; make All select the most-constrained window.
- [x] Task 6: Remove model/token detail from overview cards while preserving it
  behind Inspect.
- [x] Task 7: Simplify overview tab to focus exclusively on 5-hour and Weekly usage left, removing filter modes and displaying dual allowance meters per agent card.
- [x] Task 8: Fix tab bar overflow and collisions — convert provider switch to Flickable with natural button widths and auto-scroll, eliminating text overflow.
- [x] Task 9: Optimize overview tab to only display authenticated agents with active usage/windows, keeping unauthenticated agents accessible in the top tab navigation for setup.
- [x] Task 10: Separate the view for Weekly and 5-hour into dedicated views with interactive view switching (5h, Weekly, All), isolated allowance meters, and keyboard shortcuts (5, W, A).
- [x] Checkpoint: Contract tests pass and the manifest validates.
- [x] Live Quickshell verification — hot reload and IPC calls verified in the running Wayland session without errors.
