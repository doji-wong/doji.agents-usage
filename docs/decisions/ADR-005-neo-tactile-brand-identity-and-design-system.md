# ADR-005: Neo-Tactile Brand Identity and Design System

## Status
Accepted

## Date
2026-10-19

## Context
The `doji.agents` widget monitors rate limits, session consumption, and token volume across diverse AI coding agent subscriptions (Antigravity, Claude Code, Codex, Fireworks). As agent activity has grown, the interface required a distinctive, coherent visual language that balances high information density with intuitive, glanceable sensory affordances.

Generic flat design lacks physical weight, making critical rate limit alarms and rapid token velocity blends into standard desktop noise. The design needed to reflect modern cyber-physical telemetry—drawing inspiration from industrial hardware craftsmanship (Braun, Teenage Engineering, aerospace cockpits) and modern mobile Live Activities / Dynamic Island micro-widgets.

## Decision
We established and integrated the **DOJI Neo-Tactile Telemetry** design system into `doji.agents`:

1. **Continuous Curvature ($G^2$ Squircles)**:
   Containers and cards utilize continuous curvature radii rather than simple circular fillets, providing a tactile, pebble-like chassis.
2. **Atmospheric Polarity**:
   - *Obsidian Void* (`#0B0C0E` / `#14161A`): Deep base grounding providing battery conservation and high contrast.
   - *Alabaster Bone* (`#F5F4EE` / `#FFFFFF`): Swiss modernist light substrate with soft physical drop shadows.
3. **High-Voltage Kinetic Accents**:
   - *Safety Kinetic Orange* (`#FF5500`): Primary alarm state (usage $\ge 90\%$) and active filter badges.
   - *Telemetry Hyper Lime* (`#D0FF00`): Live token velocity, active throughput, and today's volume indicator.
   - *Technical Blue* (`#0066FF`): System navigation, sync, and logic flows.
4. **Physical Affordances in QML Components**:
   - `Meter`: Refactored to feature recessed grooved beds (`root.alpha(surface, 0.85)` with hairline borders) and a white kinetic indicator bead at the leading progress edge.
   - `DayRow`: Highlights current day activity with high-voltage Hyper Lime, creating an immediate visual run-up to the current session.
   - `overviewSection`: Interactive filter pills (`5h`, `Weekly`, `All`) highlight with Safety Kinetic Orange accents.
5. **Brand Mark Asset**:
   Introduced official vector SVG marks (`assets/doji.svg` and `assets/doji-light.svg`) representing the squircle chassis, segmented phosphor columns, and kinetic aperture.

## Consequences
- **Positive**:
  - The widget possesses a premium, cohesive brand identity with instant recognition.
  - Alarming states and rate limit exhaustion are immediately perceptible from peripheral vision without scanning text.
  - Telemetry and history data read with tabular clarity and tactile responsiveness.
- **Negative / Constraints**:
  - Requires maintaining color token consistency across custom provider color bridges.
  - QML animations must remain lightweight to ensure smooth 60fps rendering in Wayland desktop sessions.
