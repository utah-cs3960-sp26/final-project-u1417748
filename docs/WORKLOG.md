# Worklog

## 2026-04-07

### Clean-room scaffold

- created `project.godot`, portrait startup scene, directory layout, and base scene tree
- added resource scripts for game, court, ball, shot, pass, route, defense, rebound, sim, difficulty, and debug tuning
- authored default HOM/AWY teams as `TeamData` resources

### Gameplay runtime

- implemented `GameCoordinator` as the single state owner
- added joystick movement, tap passing, shot aim, pass conversion, pause, game over, and possession reset flow
- implemented pure gameplay controllers for passes, shots, ball flight, hoop resolution, rebounds, routes, defense, and opponent sim
- added procedural placeholder court, player, hoop, HUD, overlay, and feedback rendering

### Diagnostics and tests

- implemented `LogWriter`, deterministic RNG support, debug overlay, headless test runner, scenario runner, bot pilot, and balance runner
- authored nine scenario resources and four balance batch resources
- added deterministic coordinator hooks for brittle edge-case scenarios
- tuned rebound and balance fixtures until the full suite passed

### Documentation closeout

- replaced placeholder README content
- added project brief, gameplay spec, architecture, decisions, test plan, known issues, and test results docs

### High-arc shot rework

- replaced the flat single-power shot feel with separate forward and arc growth curves
- added a weak starter preview that appears immediately when shot aim begins
- reduced horizontal launch aggression and raised vertical lift for a slower, more casual arc
- densified preview dots, added apex emphasis, and moved the preview origin slightly in front of the shooter
- added pure-logic coverage for starter preview, arc growth, floatiness, preview/live launch consistency, tiny-drag cancel, and pass conversion override

### Low top-down projection refactor

- added `ProjectionConfig` and `CourtProjection` as a render-only view layer
- moved players to explicit `world_position` gameplay coordinates instead of treating `Node2D.position` as simulation truth
- projected players, shadows, held ball, live ball, hoop, debug geometry, and shot preview into screen space from `GameCoordinator`
- converted action input and scripted harness gestures to projected screen targeting with inverse ground-plane mapping back into world space
- updated pure-logic coverage for projection monotonicity, projected preview/live agreement, projected tap targeting, and screen-drag launch mapping

### Hold-to-shoot meter rework

- replaced drag-to-shoot with a touch-and-hold meter on the current ballhandler
- added a bottom rectangular timing bar with a mostly red lane, a smaller green make window, and a moving indicator block
- changed shot resolution so green releases deterministically launch a make path through the rim, while red releases launch misses or allow contest-driven blocks
- added a short post-score hold so made shots visibly finish through the hoop before the game transitions
- updated the harness and balance probe to validate the meter-driven mechanic instead of the old drag-preview flow

## 2026-04-08

### Fixed-green shot guarantee

- removed contest and release-consistency effects from the green meter geometry so the visible green chunk is always the actual guaranteed-make window
- enforced green releases through hoop resolution with a forced-make flight flag so guaranteed shots cannot rattle out on rim or backboard contact
- kept contest pressure only on red releases, where the miss path can still be blocked before rebound resolution
- added deterministic coverage for contested green makes, fixed-window snapshots, and a coordinator-level harness step that sets a precise meter quality before release
- replaced the flaky defensive-rebound scenario trigger with a deterministic defensive-rebound hook so the suite no longer depends on rebound RNG for that case

### Atlas art integration

- replaced the procedural placeholder court with a textured projected half-court sampled from the second court variant in the new atlas and rotated into the portrait offense-only presentation
- replaced procedural hoop and ball drawing with atlas-backed hoop/net layers and layered basketball sprites while keeping the existing resolver, projection, and ball-flight math intact
- added `PlayerVisual` as a sprite-only presentation child for each `PlayerController`, using Character1 for home, Character2 for away, and a focused first-pass set of idle, move, aim, shoot, and catch/rebound animations
- added coordinator-side facing and animation-state resolution so movement, aim, pass catches, offensive rebounds, and shot releases drive the new sprite presentation without moving gameplay rules into the art layer
- added smoke coverage that instantiates `GameRoot` and asserts the textured court plus hoop, ball, and player sprite visuals are present during the automated suite

### Gameplay-first boot and render calibration

- changed `project.godot` so the project boots directly into `GameRoot.tscn` and removed the dead `MainMenu` scene/script path
- replaced pause/game-over `Main Menu` actions with `Quit Game` so overlays still expose an exit path without referencing a removed scene
- corrected the second-court source bounds to the full 484x229 atlas region and made the active portrait floor an explicit left-half crop of that source
- switched court strip rendering to an `AtlasTexture`-backed sampling path with normalized UVs so the rotated floor art actually renders instead of sampling empty atlas space
- generated a clean transparent `NetClean.png` from the user-provided net screenshot and used it as the front hoop layer, then tuned the front-net anchor so it hangs below the backboard over the painted rim area

### Flat rectangular framing and larger players

- retuned `ProjectionConfig` so the court maps to a true rectangle with constant width, linear depth, and a slightly tighter on-screen framing
- kept the same `CourtProjection` and inverse input mapping APIs, but changed the authored defaults away from the old pseudo-perspective stretch
- substantially increased player sprite scale and raised the sprite offset so enlarged characters stay foot-anchored to the floor
- enlarged hit radii, screen anchors, held-ball anchors, and held/live ball render sizes so the bigger player presentation still aligns cleanly during input and possession
- added pure-logic coverage for constant court width, linear depth mapping, and exact ground-coordinate round-tripping under the flatter projection

### Cinematic shot arc refactor

- replaced the fixed-time make/miss shot builder with an apex-driven launch profile that enforces minimum airtime and minimum apex by distance
- changed shot launches to begin above the floor and updated `BallSimulator.launch` to accept full horizontal velocity plus launch z
- restored visible arc preview dots during aim, with green showing the make path and red showing the deterministic miss path stored from aim start
- raised live and preview z-lift, increased live ball size growth, and strengthened shadow shrink so the new arc reads clearly on screen
- expanded pure-logic coverage for cinematic airtime, apex height, preview/live launch agreement, and above-floor release behavior
- lengthened the contested green release scenario wait so the longer arc fully resolves back to live offense inside the harness
