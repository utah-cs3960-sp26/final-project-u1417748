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

### Hoop depth-visual contract

- added deterministic test coverage for explicit hoop render phases and the through-net score follow-through contract
- documented the layered hoop visual model so normal makes stay in front of the backboard, pass behind the front net on score, and only render behind the board on true over-the-top paths
- recorded the through-net score visual behavior in the gameplay spec, architecture notes, test plan, and acceptance checklist without changing score legality
- switched coordinator test mode to a fixed 60 Hz simulation step so made-shot follow-through timing, scenario waits, and clock assertions stay stable in headless deterministic runs

### Front-half net-entry score fix

- moved green make trajectories off raw hoop center and onto a dedicated front-half net-entry target so guaranteed makes visibly enter the mouth of the net
- tightened `HoopResolver` so both forced and normal scores must cross the rim plane inside the inner cylinder and on the front side of the hoop
- clamped score follow-through start positions into the legal net channel so a scored frame cannot begin above or behind the backboard
- added pure-logic regressions for the screenshot case where a backboard-side descending crossing used to score despite missing the net

### Three-piece hoop pass-through refactor

- split the old single front hoop overlay into a three-piece render stack: a rear/full hoop silhouette, a front rim lip, and a hanging front net body
- converted `Net.png` into a transparent combined rear hoop layer and regenerated `NetClean.png` as a rim-only layer, then authored a matching `NetBody.png` for the swishable lower net
- added explicit `rim_mouth` and `net_channel` ball render phases so a made shot now spends a readable frame inside the rim before dropping behind the front net
- added a small `HoopView`-owned net swish animation that stretches and sways the front net body on scored follow-through without touching score legality
- extended deterministic smoke coverage so the harness now checks three-piece hoop availability, rim-mouth first-frame rendering, net-channel progression, front-of-net emergence, and score-triggered swish activation

### Guided make descent rewrite

- replaced the old green-shot forced-score contract with a staged guided-make profile that solves a legal front-half rim entry and then hands off to simulator-owned downward descent
- extended `BallSimulator` so made shots move from free flight into a rim-plane handoff and then through `guided_descent` and `net_exit` before the score resolves
- changed `HoopResolver` so guided makes can still collide during approach, but only score from the simulator-reported guided-descent gate instead of any arbitrary early crossing
- removed the coordinator-owned render-only score rescue from the live scoring path and reduced it to phase/state tracking plus net-swish triggering
- retimed deterministic `force_scoring_shot` scenarios so they now launch a real guided make instead of fabricating an instant scored frame

### Rim-plane handoff rewrite

- moved the end of the green make arc from an above-rim entry point down to the rim plane at the legal front-half handoff point
- removed the authored above-rim linger from the live solver and kept any `rim_mouth` read to at most a transient transition frame
- pushed the score gate slightly below the rim so feedback appears only after the ball has visibly started descending into the net
- updated smoke coverage so made shots no longer require a sustained rim-mouth phase and explicitly fail if score feedback appears while the ball is above the rim

### Terminal made-shot screen drop

- reduced the render-only terminal drop for guided makes from 65px to about 60px so the final approach and descent sit slightly higher while keeping the same terminal path behavior
- kept the solver, score legality, and hoop geometry unchanged; the drop is purely a presentation offset in the terminal guided-make path
- applied the same visual-only lowering to the terminal guided-make preview samples so the last green preview segment stays aligned with the live finish without affecting miss paths

## 2026-04-09

### Visible pass flight and steal resolve

- rewrote `PassController` so passes now keep a full active-flight snapshot with a fixed release-time endpoint, an active interceptor, a live chase point, rating-scaled claim radii, and explicit `complete_offense` / `complete_steal` outcomes
- made pass flight authoritative for the live ball render path so the ball stays visibly in motion through `PASS_IN_FLIGHT` instead of snapping back to the handler at the end of the frame
- added coordinator-side receiver and defender pass-flight movement overrides plus a short `STEAL_RESOLVE` state that pins the ball to the stealing defender before the opponent sim starts
- extended pass logging and debug overlay snapshots with pass target, chase, and resolution markers so deterministic runs explain why a pass succeeded, was stolen, or went out of bounds
- updated deterministic scenarios, bot assertions, and balance probes so the harness now validates real visible catches and steals instead of the old instant-turnover shortcut

### Probabilistic pass steal tuning

- changed pass defense from automatic lane commitment to a hybrid model: one best eligible defender is still selected by ETA, but that defender only cuts the lane after a seeded commit roll using pass geometry, defender pressure, passer accuracy, receiver catch security, and the difficulty defense multiplier
- kept the visible live-ball race intact after commitment, so the ball path, receiver break, and defender cut all still read honestly on screen
- extended the debug snapshot and pass-start logs with eligible defender, committed defender, and commit-chance data so tuning is visible during desktop runs
- retuned the pass-risk batch around the new commit gate; the latest headless run landed at short steals `0.00` and long steals `0.23` on Normal difficulty
- fixed the scripted cross-court steal scenario so it explicitly uses `force_pass_interception` before asserting the visible `STEAL_RESOLVE` path

### Full-screen court rescale

- retuned `ProjectionConfig` so the projected court now fills the full `1080x1920` viewport behind the HUD, with the top sideline at screen top, the bottom sideline at screen bottom, and both sidelines landing flush on the left and right screen edges
- increased actor presentation scale by the same court-fill ratio so players stay proportionate to the larger floor without changing `CourtConfig`, route anchors, or other gameplay-world coordinates
- moved held-ball radius, live-ball min/max radius, and hoop visual scale into `ProjectionConfig` so the court, ball, and hoop all scale from one presentation resource instead of mixed hardcoded render constants
- retuned the hoop screen offset so the larger backboard and rim art still clear the 128 px HUD banner while the court art continues rendering behind it
- extended pure-logic and smoke validation with fullscreen court bounds, hoop-over-HUD clearance, larger player presentation, held-ball hand alignment, and in-flight ball/projection alignment coverage
