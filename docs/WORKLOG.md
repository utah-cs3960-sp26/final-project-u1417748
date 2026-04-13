# Worklog

## 2026-04-10

### Live dunks now auto-finish without the timing bar

- changed `GameCoordinator` so any shot that commits to a dunk family now skips `SHOT_AIM`, never shows the shot bar, never requires a green tap, and immediately queues a guaranteed `dunk_auto_make`
- kept the authored dunk release contract intact by still starting the hidden shot-timing controller for cleanup, preserving the rim-contact hold, hidden world-ball hang, and straight-through guided descent after release
- rewrote the dunk smoke coverage so straight and side dunks now assert immediate `SHOT_RELEASE`, hidden meter state, auto-make timing tags, and the same post-hold make-drop launch path
- reran the full headless suite after the dunk auto-finish change: Pure logic `693`, Scenarios `13`, Balance `4`, Failures `0`

### Hoop moved back to the top boundary

- moved the real hoop anchor to `Vector2(540, -50)` and the backboard collision plane to `y = -120` so the pole, board, rim, and net all sit farther back above the court instead of relying on a support-only visual offset
- removed the temporary split-support hoop art workaround and restored the single combined hoop-body atlas region
- widened the live `three_point_radius` to `840`, `close_finish_radius` to `550`, and `dunk_finish_radius` to `485` so shot-value boundaries and near-rim finish access stay aligned after the actual hoop geometry moved back
- removed the projection clamp that pinned negative hoop world Y to the court top, which is why earlier negative hoop values appeared not to move
- nudged `easy_sim_efficiency` down to `0.88` so the difficulty balance batch still orders Easy below Normal after the hoop-distance retune
- reran the full headless suite after the real negative-Y hoop move: Pure logic `641`, Scenarios `13`, Balance `4`, Failures `0`

### Pause-menu no-defenders toggle and forced close-range dunks

- added a `No Defenders` toggle to the pause overlay so debug sessions can hide all live defenders without leaving the match
- routed live defense, pass interception, and rebound candidate collection through an active-defenders filter so disabled defenders stop contesting, blocking, stealing, or rebounding while hidden
- added a defender-free close-range override to the finish chooser so any shot taken inside the normal close-finish radius commits to a dunk family even for low-dunk or stationary players
- added smoke coverage for the pause overlay toggle, defender visibility changes, and the forced close-range dunk override
- reran the full headless suite after the no-defenders debug toggle: Pure logic `638`, Scenarios `13`, Balance `4`, Failures `0`

### Dunk vs layup decision gates and explicit dunk ratings

- added an explicit `dunk` rating to `PlayerData`, exposed it through `get_rating()`, and seeded the current HOM and AWY rosters with role-specific dunk values
- rewrote close-finish selection into a deterministic two-stage chooser: players first qualify for the layup-or-dunk family by hoop distance, hoop-facing momentum, and the existing finish speed gate, then only qualify for dunk rows if they also meet the stricter dunk radius, dunk-speed, and dunk-rating gates
- kept straight-vs-side finish routing after the family choice, preserved the set-shot and jumper paths outside close-finish conditions, and limited straight-dunk row randomization to the already-committed dunk family
- extended `DefenseController` with a pure dunk-aware block-chance helper so committed dunks gain block resistance from the new `dunk` rating while layups and jumpers keep the existing block formula
- added deterministic coverage for dunk threshold metadata, roster dunk seeding, dunk-only block resistance, layup fallback on low dunk rating or low dunk speed, defender-independent family selection, and regression coverage proving LC archetypes still reach rows `13`, `15`, and `16`
- reran the full headless suite after the dunk-vs-layup chooser rewrite: Pure logic `629`, Scenarios `13`, Balance `4`, Failures `0`

### Dunk contact hold and straight-through finish

- added dunk-contact metadata for rows `13`, `15`, and `16`, including authored rim-contact frames, a shared `0.5` second hold, and per-row contact offsets so the dunk hand lands on the rim graphic during the freeze
- extended `SHOT_RELEASE` so unblocked dunk rows now wait for the authored contact frame, hang on the rim with the world ball hidden, then release only after the hold completes
- changed dunk makes to start directly at the rim entry point and drop straight through the hoop and net, while dunk misses now launch from that same point into a short upward-and-away bounce
- added deterministic coverage for dunk contact metadata, hold timing, hidden-ball behavior during the rim hang, straight-through make descent, upward-and-away miss bounce, and blocked-dunk bypass behavior
- reran the full headless suite after the dunk-specific release rewrite: Pure logic `598`, Scenarios `13`, Balance `4`, Failures `0`

### Stricter upward-only shot swipe gate

- tightened shot entry so `SHOT_AIM` now only arms from an upward swipe whose release lands in the top half of the screen
- removed downward swipe shot entry and rejected upward swipes that stay in the lower half, while keeping lower-zone movement active until a qualifying upward release wins on lift-off
- updated the bot pilot and smoke helpers so automated shot-entry gestures now intentionally finish above the halfway line instead of relying on a shorter upward flick
- reran the headless suite after the stricter gate: Pure logic `472`, Scenarios `13`, Balance `4`, Failures `0`

### Tap-pass and swipe-shot control swap

- swapped live-offense control arbitration so quick taps now request passes and strong upward swipes now arm `SHOT_AIM`
- added a coordinator-owned default pass target that stays marked with the light-blue ring during `LIVE_OFFENSE`, with empty taps passing to that ranked teammate and direct teammate taps overriding the marker
- kept lower-zone drags as movement while the finger is down, but made qualifying upward lower-zone releases arm shot mode instead of resolving as ordinary movement-stop releases
- added `PassController.evaluate_pass_target()` so the default pass marker, pass-risk ranking, and live pass start all share the same interception-commit, distance, and hoop-proximity evaluation
- rewired `InputController`, `BotPilot`, `ScenarioRunner`, and coordinator smoke hooks around `tap_pass` and `swipe_shot` semantics while keeping backward-compatible aliases for older scenario resources
- re-ran headless validation after the control swap: Pure logic `470`, Scenarios `13`, Balance `4`, Failures `0`

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

### Close-camera retune and player floor marker cleanup

- retuned the projection-layer close camera from `2.4x` down to `2.1x` so the court and players still read close, but with slightly more surrounding floor in frame
- removed the old black player ground shadow draw from `PlayerController` while leaving the live ball shadow and the rest of the projection math untouched
- replaced the controlled-player floor circle with a thin outlined oval positioned lower and wider so the player feet sit visually inside the marker instead of above its center
- added a `PlayerController` debug floor-marker snapshot so the headless suite can assert that player shadows stay disabled and the controlled marker remains an outlined oval with the expected feet-centered offset
- reran the headless suite after the visual cleanup; the latest pass landed at Pure logic `463`, Scenarios `13`, Balance `4`, Failures `0`

### Dynamic close camera

- added a projection-layer close camera with `2.4x` zoom that hard-centers the tracked subject on the visible viewport midpoint without changing gameplay-world coordinates
- extended `CourtProjection` into a base-layout-plus-camera pipeline so render zoom/translation apply after the responsive court mapping, while inverse touch mapping removes the same camera transform before converting back to world space
- switched possession tracking to the controlled player using an upper-body anchor offset, and switched pass, shot, rebound, and made-shot follow-through tracking to the live rendered ball anchor including its z-height presentation
- kept player-follow movement lightly smoothed, but snapped live-ball tracking so the launched ball stays centered from the first visible flight frame instead of easing behind fast passes or shots
- moved depth ordering onto base projection space and scaled hoop, actor, shadow, held-ball, live-ball, and guided-make presentation through the zoomed projection values so the full court presentation reads much closer on screen
- expanded deterministic coverage around centered opening possession framing, centered pass and shot flight, camera-aware inverse mapping, world-space pass travel under a centered camera, and HUD containment after the close-camera transform

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

### Full-sheet player animation overhaul

- added `PlayerAnimationConfig` plus a runtime `PlayerVisualRequest` contract so `GameCoordinator` now classifies player presentation into full-sheet animation families without moving gameplay ownership into the art layer
- replaced the old coarse `idle/move/aim/shoot/catch` player art pass with row-driven playback covering no-ball idle, multiple with-ball idle/dribble states, jumper releases, layups, dunks, side dunks, guard states, off-ball runs, and jump contests
- collapsed the facing model to east-facing sprite art plus westward X mirroring, and restricted outline rendering to the currently controlled player while leaving all other players fill-only
- added a short defender jump pose, hooked the block check to identify the actual blocker, and routed close-finish shots into layup, straight-dunk, or side-dunk presentation using hoop proximity and approach direction
- extended the headless suite with exact row, flip, outline, fill-texture, variant-lock, layup/dunk, and guard-state assertions so the full-sheet mapping now has deterministic regression coverage

### Release-synced shot staging and hidden held-ball presentation

- inserted a new `SHOT_RELEASE` coordinator state so releasing the meter now commits a locked shot family, row variant, and west-mirror flag before the ball is actually launched
- changed shot classification so row 4 is now a defender-space set shot, row 5 is the aim hold, rows 8 and 10 are randomized jumper releases, rows 14 and 17 split straight vs side layups, and rows 13, 15, and 16 cover straight and side dunks from movement snapshots taken at shot initiation
- hid the standalone `BallController` whenever a player-owned sprite already contains the ball, so the world ball now appears only on pass start, after the correct release frame of a committed shot, and during genuine loose/in-flight states
- added row-specific release-after-frame metadata plus lightweight debug accessors on `PlayerVisual` / `PlayerController`, then moved the coordinator launch trigger to the first tick after the authored release frame has finished displaying
- expanded the smoke suite with hidden-held-ball checks, staged shot-release timing, deterministic row-8-or-10 jumper selection, straight-vs-side layup routing, deterministic dunk row locks, steal/offensive-rebound hide-on-catch behavior, and delayed blocker jump-pose coverage

### Aim-synced shot windup and meter alignment

- switched shot aim to start the committed release row immediately so the hold bar and sprite animation advance from the same timing profile
- aligned the tail-end green window so the end of green lands on the authored release frame for the selected row
- kept early releases locked to the current quality while the animation continues through followthrough before launch
- added overhold auto-release at the authored release frame, with forced-miss behavior when the player keeps holding too long
- retained row 5 only as a fallback hold pose for non-committed or canceled cases, not as the main live shot-aim animation

### Unified 15 FPS shot cadence

- changed every committed shot family in `PlayerVisual` to a shared 15 FPS playback rate so set shots, jumpers, layups, and dunks no longer jump between mixed row speeds
- updated the coordinator fallback timing helpers so release-pose duration, release seconds, and full animation duration all derive from the same 15 FPS shot profile instead of old 16 FPS defaults
- extended the deterministic suite with exact 15 FPS timing-profile checks for rows 4, 8, 10, 13, 14, 15, 16, and 17 plus a no-restart continuation cadence check

### iOS test export setup

- added a local `export_presets.cfg` iOS preset for device testing with the existing Apple developer team configuration and an ignored `.godot/ios_export` Xcode-project target
- documented the Godot-to-Xcode install flow in `docs/IOS_TESTING.md` so local device testing does not depend on App Store publishing steps
- restored the missing `scripts/game/MainMenu.gd` stub referenced by `scenes/MainMenu.tscn` so export packing no longer trips over a stale scene script

### One-thumb control and full-height court rework

- added `InputConfig` as a dedicated resource for movement-zone height, invisible-stick radius, dead zone, pass-preview cone, tap thresholds, anchor visuals, and best-effort mobile haptics
- removed the runtime joystick scene and replaced movement with an invisible lower-screen drag zone that spawns a faint temporary thumb anchor
- changed passing from teammate taps to directional flicks, including live pre-release target preview and deterministic cone-based target selection
- changed shooting so releasing a non-pass gesture arms shot mode at normal speed, starts the committed shot animation immediately, and waits for a tap-anywhere timing lock instead of using a hold-to-release meter
- added late-miss timeout handling when the timing bar reaches the end without a tap, while preserving the existing authored release-frame launch gate after the timing decision is locked
- updated `CourtView` so the rotated court art keeps its source aspect ratio, fills the full screen height, crops excess width with an offensive bias, and renders transient movement-anchor and pass-preview overlays
- rewired the bot pilot, deterministic scenarios, and pure-logic coverage around `move_thumb`, `flick_pass`, `arm_shot`, and `tap_meter`, and added a dedicated late-miss timeout scenario

### Release-to-pass and tap-to-arm shot follow-up

- removed the release-speed and flick-distance pass dependency from the shipped mobile input path while keeping the existing live pass-preview lock and ring fill
- changed release arbitration so quick taps arm shot mode, center release after a real drag cancels, off-center release with a lock passes, and off-center release without a lock cancels
- replaced the swipe thresholds in `InputConfig` with quick-tap duration and excursion limits
- routed gameplay touch recognition through unhandled input so HUD controls keep precedence over shot-arm taps
- extended structured release logs with offset, distance, release reason, and tap metrics
- rewired the deterministic harness around `release_pass`, `tap_shot`, `release_center`, and `tap_meter`
- added deterministic coverage for upper-screen tap shot arming, lower-zone tap shot arming, center release idle, tap red miss, and pause/resume safety while armed in shot mode

### Responsive mobile court and HUD layout

- added a `GameCoordinator`-owned responsive layout contract that reads the visible viewport plus `DisplayServer.get_display_safe_area()`, then derives `banner_rect`, `available_play_rect`, `court_screen_rect`, `presentation_scale`, and `ui_scale`
- changed `CourtProjection` to accept runtime screen-layout overrides so world-space gameplay stays untouched while the rendered court now fits and centers below the live banner instead of assuming a fixed `1080x1920` frame
- scaled actor presentation, shadow offset, hoop offset/scale, live ball radii, held-ball radius, and guided-make screen-drop presentation from the centered court width so visuals stay proportional on narrower phones
- rebuilt `HUD` from responsive containers with a centered timer/pause stack and exposed a layout snapshot used by smoke tests to assert all banner controls stay fully inside the top bar
- updated smoke and pure-logic coverage around responsive court bounds, centered play-area placement, hoop-over-banner clearance, and HUD child-rect containment

### Smooth AI steering and blue pass preview cleanup

- replaced the AI’s snap-to-target corrections with eased arrival steering for off-ball offense, on-ball defense, rebound pursuit, pass receivers, and committed lane-cut defenders while leaving user-controlled movement unchanged
- added route side-switch hysteresis around the hoop centerline so strong-side and weak-side packages do not thrash when the ballhandler hovers near the middle of the floor
- added animation-family and facing hysteresis so off-ball runners and defenders stop chattering between idle, shuffle, run, and left/right mirror states during tiny corrective moves
- changed the shipped default presentation so the debug overlay no longer boots visible, teammate catch rings stay hidden in normal play, and the active pass-preview target now uses the light-blue ring style instead of the older yellow marker
- extended the deterministic suite with route hysteresis, smooth-settle steering, animation/facing hysteresis, and gameplay pass-preview feedback assertions; the latest headless run landed at Pure logic `434`, Scenarios `13`, Balance `4`, Failures `0`
