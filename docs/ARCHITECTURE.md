# Architecture

## Scene Tree

- `scenes/GameRoot.tscn`
  - `CourtView`
  - `Entities`
  - `Systems/InputController`
  - `UIRoot/HUD`
  - `UIRoot/OpponentSimBanner`
  - `UIRoot/PauseOverlay`
  - `UIRoot/GameOverOverlay`
  - `UIRoot/FeedbackText`
  - `DebugOverlay`
  - `GameCoordinator`
- `scenes/entities/`
  - `Player.tscn`
  - `Ball.tscn`
  - `Hoop.tscn`
  - `OpponentSimPresentation.tscn`

## Runtime Ownership

`GameCoordinator` is the single authoritative runtime owner. It:

- loads config and team resources
- loads the projection config and owns the shared `CourtProjection`
- spawns players, hoop, and ball
- wires input and HUD
- owns state transitions
- runs possession resets
- drives ball flight, rebound resolution, and opponent sim
- owns the brief `STEAL_RESOLVE` handoff so steals read on screen before the opponent sim action banner takes over
- owns staged opponent-sim presentation: the sim result is generated and logged immediately, while score, clock, and possession reset are deferred until the final visible action beat completes
- owns the transient opponent-sim match-UI hide flag so the scoreboard and bottom control panel disappear while action text is visible and restore only when human offense resumes
- owns the opponent-sim presentation layer lifecycle, hiding live players and live ball while AWY/HOM ghost tableaux play on the bottom half of the court, then restoring live entities on completion, game over, restart, or test reset
- snaps the close camera to the current opponent-sim actor or tableau center during `OPPONENT_SIM` so static jump cuts are readable immediately
- owns the responsive layout metrics contract for `viewport_rect`, `safe_rect`, `banner_rect`, `pause_button_rect`, `available_play_rect`, `court_screen_rect`, `control_panel_rect`, `control_zone_rects`, `presentation_scale`, and `ui_scale`, refreshing it from the live viewport and device safe area before resyncing presentation
- defines `banner_rect` as the compact scoreboard-card bounds anchored above the control panel's left `SHOOT` half rather than as a top banner strip
- defines `pause_button_rect` as the standalone mirrored pause-button bounds anchored above the control panel's right `DUNK` half
- keeps gameplay coordinates in flat world space, then maps players, ball, hoop, preview points, and debug geometry into a flat rectangular screen-space court each frame
- resolves the active close-camera target each frame, following the controlled ballhandler during owned possession and the rendered live ball during passes, shots, rebounds, and score follow-through
- owns the made-shot render handoff that keeps the ball in a single contiguous `front_of_net` timing window after `net_exit`, activates the lower `NetCleanBottomHalf` and `NetBody` masks only for through-net follow-through, freezes the guided terminal presentation drop through the full explicit hoop follow-through, clamps pre-bounce rendered anchors so `guided_descent -> net_exit -> floor_drop` never step upward on screen, and only releases back to plain world rendering after the ball has visibly cleared the hoop's front-net exit threshold
- commits any staged shot release before final projection sync so the first visible launched-ball frame already hands camera ownership from the player to the live ball
- owns the explicit hoop render-phase contract so shot balls render in front of `NetClean`, and only behind `NetCleanBottomHalf` and `NetBody` while they are actually in the net channel or the contiguous made-shot net-exit follow-through
- resolves sprite-facing and animation state for the player presentation layer without letting art drive gameplay logic
- owns the full-sheet animation classifier, including family selection, deterministic variant locking, close-finish layup/dunk routing, westward mirroring, and controlled-player outline visibility
- owns the `SHOT_RELEASE` staging state, the pending shot-release snapshot, and the presentation-only ball visibility mode that keeps the rendered world ball hidden while a player-held sprite already includes the ball
- polls `PlayerVisual` after each animation advance so the actual shot launch and ball reveal happen only after the configured release frame for the committed row
- exposes deterministic hooks used only by the automated harness

## Core Systems

- `InputController`
  - visible-panel live-offense input with center-lane movement drags, direct left/right focused-pass button taps, direct top-left `SHOOT` taps, direct top-right `DUNK` taps, release classification for drag-based actions, second-finger action-button taps during movement, short-lived pressed-zone highlight feedback for direct taps, tap-to-time input, UI-safe unhandled touch routing, and debug mouse/keyboard support
- `CourtProjection`
  - render-only world/screen mapping with a two-stage projection: a stable base court layout plus a close-camera zoom/translation transform that hard-centers the tracked subject on the visible viewport midpoint
  - removes the same camera transform before inverse ground-plane mapping so touch, bot gestures, and other screen-driven input still round-trip back into unchanged world coordinates
  - derives depth sort keys from base projection space while actor/shadow scale, hoop scale, ball size, and amplified z-lift presentation all use the zoomed close-camera view
  - applies a runtime screen-layout override so the same gameplay court can be centered inside a banner-safe play rect without changing `CourtConfig`
- `CourtView`
  - draws the rotated blue second-court atlas slice as a textured projected floor surface, using the active `court_screen_rect` for ratio-aware cropping and keeping the active offensive hoop anchored inside the centered mobile play area
  - owns a high-z `Sprite2D` child for the normalized opposite-side bottom hoop, anchored at `CourtConfig.opposite_hoop_position`, scaled through `CourtProjection`, and multiplied by `CourtConfig.opposite_hoop_visual_scale_multiplier`
  - keeps the bottom hoop on an absolute z index above entity sprites so live and opponent-sim players/balls layer behind the back-of-hoop art
  - exposes a bottom-hoop snapshot so smoke tests can verify visibility, `144x170` texture size, projected rect, doubled scale multiplier, z order, and bottom-court anchor
  - also renders gameplay-only overlays like the light-blue focused-pass ring and trajectory dots while leaving joystick art and shot-meter rendering to the dedicated control panel
- `HUD`
  - renders the cropped textured scoreboard as a compact bottom-left card above the `SHOOT` half of the control panel, maps the live home score, clock, and away score into authored art zones, renders a separate square pause icon button above the `DUNK` half, and exposes a layout snapshot used by smoke tests to verify both HUD elements stay inside the safe area
- `OpponentSimBanner`
  - captures taps only while `OPPONENT_SIM` is presenting, renders a centered full-width black action banner at `80%` opacity, exposes layout/text snapshots for smoke coverage, and emits advance requests that move one visual step at a time
- `OpponentSimPresentation`
  - dedicated `Entities` child used only during `OPPONENT_SIM`
  - owns five AWY ghost players, five passive HOM defender ghosts, and a ghost ball using the same player/ball scene visuals as live play
  - maps each opponent visual step into a static bottom-half formation, including setup spacing, wing/corner jumpers, lane finishes, loose-ball misses, steals, blocks, and defensive boards
  - keeps positions in court world space and resyncs projection each frame, but does not interpolate movement between steps
  - exposes a snapshot with current kind, actor role/team, ghost positions, ball owner/visibility, and camera anchor for deterministic smoke coverage
- `ControlPanel`
  - renders the visible compact bottom-quarter control panel, keeping every button on a shared dark neutral idle base until the active drag or a direct press swaps that zone into its action color, while also drawing the joystick art, pass badges, small capped labels, and the widened shot meter that spans the combined `SHOOT | DUNK` top row during `SHOT_AIM`
- `ShotController`
  - one-way shot-mode timing, decision-duration-vs-full-animation timing separation, tail-end green-window classification, stable aim-time miss variants, apex-driven launch profile generation, staged guided-make solve generation, and preview sampling
- `PassController`
  - straight-line pass travel, fixed release-time catch points, eligible interceptor selection, a ratings-and-risk commit roll, rating-scaled claim radii, and live catch-vs-steal resolution after commitment
- `BallSimulator`
  - pure `RefCounted` 2D + z-height motion with explicit above-floor shot release height
  - guided makes switch from free flight to a rim-plane handoff and then into `guided_descent -> net_exit -> floor_drop -> floor_settle`, holding the terminal presentation drop at full strength through `net_exit`, then using a longer constant-acceleration floor drop that carries the outgoing net-exit velocity instead of spiking into a short ease-down
  - only allows the visible upward bounce once `floor_settle` begins after floor contact
- `HoopResolver`
  - score-plane, rim, and backboard resolution
  - guided makes may still collide during approach, but only score once the simulator reports the planned guided-descent score gate crossing
- `HoopView`
  - composes the hoop body plus a four-layer hoop stack around the gameplay rim anchor: `Net`, `NetClean`, `NetCleanBottomHalf`, and `NetBody`, with the four net textures sharing the same 30x28 registration transform
  - exposes render-phase z-order helpers, through-net mask flags, and a layering snapshot so inactive `NetCleanBottomHalf` and `NetBody` sit below airborne, rim-mouth, and generic front-net ball phases, then rise above only `net_channel` and through-net `front_of_net` phases
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
  - returns log-oriented `events` plus presentation-oriented `visual_steps`; each possession has `1..4` visible steps, and the final step matches `points_scored`
  - includes stable actor metadata on each visual step (`player_id`, `player_role`, and `actor_team`) so the presentation layer can place the correct ghost actor without changing the resolved sim result

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
