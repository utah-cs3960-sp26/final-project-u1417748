# Architecture

## Scene Tree

- `scenes/GameRoot.tscn`
  - `CourtView`
  - `Entities`
  - `Systems/InputController`
  - `UIRoot/HUD`
  - `UIRoot/Joystick`
  - `UIRoot/PauseOverlay`
  - `UIRoot/GameOverOverlay`
  - `UIRoot/FeedbackText`
  - `DebugOverlay`
  - `GameCoordinator`
- `scenes/entities/`
  - `Player.tscn`
  - `Ball.tscn`
  - `Hoop.tscn`

## Runtime Ownership

`GameCoordinator` is the single authoritative runtime owner. It:

- loads config and team resources
- loads the projection config and owns the shared `CourtProjection`
- spawns players, hoop, and ball
- wires input and HUD
- owns state transitions
- runs possession resets
- drives ball flight, rebound resolution, and opponent sim
- keeps gameplay coordinates in flat world space, then maps players, ball, hoop, preview points, and debug geometry into a flat rectangular screen-space court each frame
- resolves sprite-facing and animation state for the player presentation layer without letting art drive gameplay logic
- exposes deterministic hooks used only by the automated harness

## Core Systems

- `InputController`
  - joystick movement, projection-aware tap-pass, projection-aware hold-to-shoot meter input, debug mouse/keyboard support
- `CourtProjection`
  - render-only world/screen mapping, inverse ground-plane mapping for action input, depth sort keys, actor/shadow scale, and amplified z-lift projection for a flat rectangular court view
- `CourtView`
  - draws the rotated blue second-court atlas slice as a textured projected floor surface, using an explicit left-half crop so the active offensive hoop lines up with the live rim anchor
- `ShotController`
  - hold meter timing, green-window classification, stable aim-time miss variants, apex-driven launch profile generation, and preview sampling
- `PassController`
  - straight-line pass travel and interception corridor checks
- `BallSimulator`
  - pure `RefCounted` 2D + z-height motion with explicit above-floor shot release height
- `HoopResolver`
  - score-plane, rim, and backboard resolution
- `HoopView`
  - composes the hoop body plus a separate front-net texture around the existing gameplay rim anchor, letting the visible net hang in front of the board without changing hoop physics
- `PlayerController` + `PlayerVisual`
  - keep simulation and presentation separate by letting the controller own gameplay state while a child visual node manages character-sheet selection, facing, animation playback, and the intentionally oversized mobile-readable sprite presentation
- `ReboundController`
  - rebound candidate scoring and winner selection
- `RouteController` + `SpacingSolver`
  - three offensive route packages plus spacing cleanup
- `DefenseController`
  - man assignments, contests, blocks, stationary pressure turnovers
- `OpponentSimController`
  - ratings-driven off-screen possession resolution

## Data

Authored resources live under `data/`:

- `data/config/*.tres`
- `data/teams/HOM.tres`
- `data/teams/AWY.tres`
- `data/scenarios/*.tres`
- `data/balance/*.tres`

All feel-sensitive values are loaded from config resources rather than scattered literals.

## Logging and Diagnostics

Logs are written to `user://logs/` by `LogWriter`:

- match log
- structured event log
- scenario log
- sim log
- test log

`DebugOverlay` renders:

- current state
- clock and score
- deterministic seed
- projected route segments
- projected defender assignment lines
- projected contest radii
- projected catch radii
- projected intercept corridor
- projected rebound zone
- projected shot preview samples

## Test Harness

The harness lives under `tests/` and is wrapped by thin files in `scripts/debug/` to keep the requested architecture present in the repo.

- `RunTests.gd`: headless entrypoint
- `TestRunner.gd`: suite coordinator and summary writer
- `ScenarioRunner.gd`: deterministic scenario executor
- `BotPilot.gd`: scripted action driver
- `BalanceRunner.gd`: repeated seeded tuning probes
