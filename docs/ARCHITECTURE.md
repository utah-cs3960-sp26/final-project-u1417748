# Architecture

## Scene Tree

- `scenes/GameRoot.tscn`
  - `CourtView`
  - `Entities`
  - `Systems/InputController`
  - `UIRoot/HUD`
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
- owns the brief `STEAL_RESOLVE` handoff so steals read on screen before the opponent sim takes over
- owns the responsive layout metrics contract for `viewport_rect`, `safe_rect`, `banner_rect`, `available_play_rect`, `court_screen_rect`, `presentation_scale`, and `ui_scale`, refreshing it from the live viewport and device safe area before resyncing presentation
- keeps gameplay coordinates in flat world space, then maps players, ball, hoop, preview points, and debug geometry into a flat rectangular screen-space court each frame
- owns the explicit hoop render-phase contract so made shots can render in front of the backboard, inside the rim mouth, behind the hanging net body, or behind the board only when the path truly goes over it
- resolves sprite-facing and animation state for the player presentation layer without letting art drive gameplay logic
- owns the full-sheet animation classifier, including family selection, deterministic variant locking, close-finish layup/dunk routing, westward mirroring, and controlled-player outline visibility
- owns the `SHOT_RELEASE` staging state, the pending shot-release snapshot, and the presentation-only ball visibility mode that keeps the rendered world ball hidden while a player-held sprite already includes the ball
- polls `PlayerVisual` after each animation advance so the actual shot launch and ball reveal happen only after the configured release frame for the committed row
- exposes deterministic hooks used only by the automated harness

## Core Systems

- `InputController`
  - lower-zone invisible-stick movement, directional pass-preview selection, release-to-pass arbitration, quick-tap shot classification, shot-mode arm requests, tap-to-time input, UI-safe unhandled touch routing, and debug mouse/keyboard support
- `CourtProjection`
  - render-only world/screen mapping, inverse ground-plane mapping for action input, depth sort keys, actor/shadow scale, and amplified z-lift projection for a flat rectangular court view
  - applies a runtime screen-layout override so the same gameplay court can be centered inside a banner-safe play rect without changing `CourtConfig`
- `CourtView`
  - draws the rotated blue second-court atlas slice as a textured projected floor surface, using the active `court_screen_rect` for ratio-aware cropping and keeping the active offensive hoop anchored inside the centered mobile play area
  - also renders transient touch feedback like the movement anchor, the gameplay-only light-blue pass-preview ring, the shot meter, and trajectory dots
- `HUD`
  - builds the top banner from responsive containers instead of fixed coordinates, applies safe-area-aware sizing through `apply_layout()`, and exposes a layout snapshot used by smoke tests to verify score, timer, and pause controls stay inside the banner
- `ShotController`
  - one-way shot-mode timing, decision-duration-vs-full-animation timing separation, tail-end green-window classification, stable aim-time miss variants, apex-driven launch profile generation, staged guided-make solve generation, and preview sampling
- `PassController`
  - straight-line pass travel, fixed release-time catch points, eligible interceptor selection, a ratings-and-risk commit roll, rating-scaled claim radii, and live catch-vs-steal resolution after commitment
- `BallSimulator`
  - pure `RefCounted` 2D + z-height motion with explicit above-floor shot release height
  - guided makes switch from free flight to a rim-plane handoff and then into `guided_descent -> net_exit`, so the live simulator, not the coordinator, owns the downward swish path
- `HoopResolver`
  - score-plane, rim, and backboard resolution
  - guided makes may still collide during approach, but only score once the simulator reports the planned guided-descent score gate crossing
- `HoopView`
  - composes the hoop body plus a three-piece hoop stack around the gameplay rim anchor: a rear/full hoop silhouette, a front rim lip, and a front net body with a small swish animation
  - exposes render-phase z-order helpers so the ball can be layered in front of the backboard, inside the rim mouth, behind the hanging net, or behind the board only for true over-the-top paths
- `PlayerController` + `PlayerVisual`
  - keep simulation and presentation separate by letting the controller own gameplay state while a child visual node manages character-sheet selection, row playback, deterministic variant resolution, and the intentionally oversized mobile-readable sprite presentation
  - keep direct player input movement separate from AI steering so user-controlled motion can stay sharp while AI route, defense, rebound, and catch/intercept movement eases into short corrections
  - use a `PlayerVisualRequest` contract carrying animation family, variant index, westward mirroring, controlled-player outline visibility, and restart intent instead of the old plain string state
  - treat the sprite sheet as east-facing art by default and mirror westward motion in presentation only
  - keep outline rendering separate from fill playback so only the currently controlled player shows the matching outline sheet
  - expose lightweight debug/runtime frame accessors so the coordinator can sync the held bar, gate launch on row-specific thresholds, and keep the committed row playing through followthrough without moving shot logic into the art layer
  - use movement-family and facing hysteresis in `GameCoordinator` so AI actors do not chatter between idle, shuffle, run, or east/west mirror states on tiny corrective vectors
  - drive every committed shot family from the same 15 FPS playback table so aim, staged release, and followthrough keep one authored cadence while release timing still comes from per-row frame metadata
- `ReboundController`
  - rebound candidate scoring and winner selection
- `RouteController` + `SpacingSolver`
  - three offensive route packages plus spacing cleanup
  - keep strong-side and weak-side route selection stable through a configurable centerline deadband instead of flipping on every tiny ballhandler x change
- `DefenseController`
  - man assignments, arrival-steered guard recovery, contests, blocks, and stationary pressure turnovers
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
- projected pass target, active chase point, pass commit chance/outcome, and last pass-resolution marker
- projected rebound zone
- projected shot preview samples

## Test Harness

The harness lives under `tests/` and is wrapped by thin files in `scripts/debug/` to keep the requested architecture present in the repo.

- `RunTests.gd`: headless entrypoint
- `TestRunner.gd`: suite coordinator and summary writer
- `ScenarioRunner.gd`: deterministic scenario executor
- `BotPilot.gd`: scripted zone-drag, release-pass, swipe-shot, center-release, and tap-meter action driver
- `BalanceRunner.gd`: repeated seeded tuning probes
