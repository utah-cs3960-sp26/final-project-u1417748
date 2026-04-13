# Test Results

## Environment

- Date: 2026-04-10
- Workspace: `/Users/teeds/Desktop/Programming/RetroBasketball/PocketHoops/final-project-u1417748`
- Engine used for validation: Godot 4.6.1 stable

## Commands Run

Parse / load:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --quit
```

Automated suite:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd
```

## Automated Result

Final headless suite status: pass

- Pure logic: 693 / 693
- Scenarios: 13 / 13
- Balance: 4 / 4
- Failures: 0

Balance metrics from the final run:

- `difficulty_order`: easy `0.89`, normal `1.12`, hard `1.28`
- `pass_risk`: short `0.00`, long `0.23`
- `rebound_distribution`: offense `0.34`, defense `0.66`
- `shot_quality`: green `1.0`, red `0.0`, contested green `1.0`, contested green window width `0.180000007152557`

## Scenario Result

Passed scenarios:

- Bad Cross Court Pass Steal
- Buzzer Shot Completion
- Center Release Idle
- Clean Pass And Shoot Make
- Contested Green Release Scores
- Contested Miss With Defensive Rebound
- Late Miss Timeout
- Long Run No Softlock
- Offensive Rebound Continuation
- Out Of Bounds Turnover
- Pause Resume Safety
- Stationary Pressure Turnover
- Tap Red Miss

## Smoke Result

- parse/load validation and the full headless suite both completed without script/runtime failures
- headless validation kept the gameplay scene stable after the close-camera projection refactor and the control-scheme swap
- opening possession now centers the controlled ballhandler on the visible viewport midpoint and shows a persistent light-blue pass marker on the coordinator-ranked default receiver
- empty-space taps now pass to that marked teammate, while direct teammate taps override the marker and still preserve live ball flight, catch transfer, held-ball hiding, and ball-tracking camera handoff
- only upward swipes that finish in the top half now arm `SHOT_AIM`, including qualifying releases that begin in the lower movement zone and still win over normal movement-stop behavior
- downward swipes and upward swipes that stay in the lower half no longer enter shot mode
- non-vertical lower-zone drags still behave as movement, not as shot entry
- eligible live dunks now skip `SHOT_AIM` completely, never show the shot meter, and stage a guaranteed `dunk_auto_make` immediately off the swipe gesture
- shot meter taps still lock quality immediately while the authored release-frame launch gate and projection-aware camera handoff remain unchanged
- near-rim finish family selection now uses deterministic close-finish and dunk-only gates based on hoop distance, hoop-facing momentum, speed, and the shooter's explicit `dunk` rating
- close-finish attempts that fail a dunk-only gate now fall back to layup rows `14` or `17` instead of leaking into jumper rows, while LC archetypes still reach dunk rows `13`, `15`, and `16`
- defender distance no longer changes the layup-vs-dunk family choice; it only affects the later contest and block outcome after the family is already committed
- the pause overlay now exposes a `No Defenders` toggle that hides all live defenders, strips them from on-court defense logic, and forces close-range shots into dunk families while it is active
- dunk rows `13`, `15`, and `16` now freeze on their authored rim-contact frame for about `0.5` seconds with the world ball still hidden before release
- live straight and side dunks now go straight from swipe entry into staged release, keep the meter hidden, and always finish through the make-drop guided descent for this phase
- blocked close-finish attempts still bypass the dunk contact-hold path and resolve through the existing block flow
- the live hoop, rim, backboard, and pole now all sit farther back above the court together at a real `Vector2(540, -50)` hoop anchor, and negative hoop depth now renders correctly because projection no longer clamps above-court world Y to the court top
- the retuned `840` three-point radius plus the larger `550` layup radius and `485` dunk radius keep shot-value classification and close-finish access stable after the hoop geometry moved behind the court
- pass flight and launched-shot flight now hand camera ownership to the rendered live ball on the first visible frame and keep that ball centered across subsequent smoke frames
- controlled-player floor feedback now renders as a white outlined oval under the feet, and player ground shadows stay disabled without affecting the live ball shadow
- the responsive HUD still stays inside the banner while the court, hoop, players, preview dots, and live ball move underneath the projection-layer camera transform
- the world ball stays hidden while a player-held sprite owns possession, and visible pass-flight alignment is now validated against world-space travel plus projection correctness rather than raw screen-distance travel

Additional pure-logic coverage now includes:

- meter green-window sizing
- meter green-window stability under contest and ratings
- meter red/green classification
- one-way shot bar timing against the committed windup row
- coordinator-driven dunk auto-finish staging with hidden meter state and `dunk_auto_make` timing tags
- explicit roster dunk ratings for the default HOM and AWY teams
- dunk momentum and minimum-rating thresholds for the stricter dunk gate
- dunk-only block resistance scaling and layup block-chance invariance
- pause-menu defender disabling plus forced no-defender close-range dunk selection
- dunk contact-frame metadata for rows `13`, `15`, and `16`
- dunk world-ball release gating after the authored rim-contact hold
- dunk make release profiles starting directly in guided descent from the rim
- dunk miss release profiles starting at the rim and moving upward and away
- relocated hoop anchor, backboard plane, and preserved three-point arc geometry
- retuned 2.1x close-camera zoom
- cinematic near-shot airtime band
- cinematic far-shot airtime band
- cinematic far-shot apex band
- far-shot preview staying close to solved apex
- deterministic made-shot launch scoring through the hoop
- deterministic miss launch staying outside the score region
- forced green-launch scoring from a contested lane
- green release producing a make outcome
- contested green release still producing a make outcome
- red release producing a miss outcome
- red preview matching the released miss path
- green preview matching the released make path
- preview samples mirroring live simulation deltas
- above-floor launch height
- projected ground-depth ordering
- responsive court top-edge mapping
- responsive court bottom-edge mapping
- left sideline mapping to the active play-rect edge
- right sideline mapping to the active play-rect edge
- flat rectangular court width consistency
- flat projection linear depth mapping inside the centered play rect
- flat projection ground-coordinate round trip
- close-camera inverse ground-coordinate round trip after zoom and tracking offset removal
- projected z-lift from a stable ground anchor
- cinematic-strength projected z-lift
- preview lift exceeding live-ball lift
- actor scale and draw-order depth behavior
- controlled-player tracking anchor landing on the visible viewport midpoint
- in-flight live-ball tracking anchor landing on the visible viewport midpoint
- close-camera actor, hoop, and guided terminal presentation scaling
- player ground shadows disabled in presentation
- controlled-player floor marker outline style
- controlled-player floor marker oval geometry and feet-centered offset
- projected lower-zone gesture mapping
- projection-aware shot-mode arming input
- gameplay boot scene selection
- textured court smoke instantiation
- hoop sprite smoke instantiation
- ball sprite smoke instantiation
- player sprite smoke instantiation
- court mapping to the centered responsive play rect in a booted `GameRoot`
- ratio-preserving full-height court crop with offensive-side bias
- responsive HUD child-rect containment for score, timer, and pause controls
- readable player presentation under the centered court framing
- hidden-held-ball presentation on the first rendered possession frame
- opening-possession floor marker using the outlined oval without player shadows
- in-flight ball/projection alignment during the smoke pass
- opening possession camera centering on the active ballhandler
- pass-flight camera centering on the traveling ball
- shot-flight camera centering on the launched ball from the first visible frame
- invisible lower-zone movement dead zone and full-magnitude thumb radius
- quick pass-tap qualification by duration and movement
- empty quick tap outside the movement zone emitting the default pass request
- empty quick tap inside the movement zone still emitting the default pass request when no real drag occurred
- direct teammate tap hit testing and explicit pass-target emission
- extra touches being ignored while dragging
- upward swipe shot qualification only when the release reaches the top half
- upward swipe rejection when the release stays in the lower half
- downward swipe rejection for shot entry
- qualifying upward swipe from the movement zone winning over normal movement release
- default pass-target ranking by interception commit chance, pass distance, and hoop proximity
- empty tap-to-pass default-target resolution inside the coordinator smoke flow
- direct teammate tap overriding the default target in coordinator smoke flow
- shot timing running at normal speed after swipe arm
- tap-to-time decision locking and late-miss timeout behavior
- home player fill textures binding to `Character1_NEW.png`
- away player fill textures binding to `Character2_NEW.png`
- controlled-player-only outline rendering plus outline transfer when control changes
- floor-marker visibility transfer with control changes
- exact row assertions for no-ball idle, open dribble idle, pressured dribble idle, small dribble move, run dribble, off-ball run, guard idle, guard shuffle, guard run, and jump contest
- westward mirroring assertions for run dribbles and close-finish dunks
- staged `SHOT_RELEASE` entry before the world ball becomes visible
- row-4 set-shot selection when the defender-space gate is satisfied
- committed shot timing profiles resolving to 15 FPS for rows 4, 8, 10, 13, 14, 15, 16, and 17
- deterministic jumper-release variant locking across repeated syncs
- deterministic row-8-vs-10 jumper selection by seed once the set-shot gate is denied
- straight-vs-side layup row selection inside the close-finish radius
- low-dunk and low-speed close finishes falling back to layup while high-dunk finishers in the same geometry still commit dunk families
- defender-distance invariance for close-finish family selection
- pause-menu no-defenders toggling, defender hiding, and forced close-range dunk selection for low-dunk guards
- straight-dunk row selection inside the stricter dunk gate
- side-dunk row selection when the approach stays close and lateral
- committed shot continuation keeping the same 15 FPS cadence instead of accelerating between aim and release
- delayed blocker jump-contest activation on the actual release frame of a blocked shot
- ball hiding again on catches, offensive rebounds, and steal resolves
- hoop render-phase z-band ordering
- coordinator ball render-phase accessors
- score follow-through remaining active immediately after a made basket
- through-net made-shot flagging during the guided net descent
- optional rim-plane handoff rendering before the hanging-net channel
- made-shot progression from the handoff into the hanging-net channel and back out in front
- score-triggered net swish activation on the front net body
- green make trajectories targeting a front-half net entry point
- counted makes proving their score sample is in the legal front-half corridor
- descending backboard-side crossings no longer scoring even when they fall inside the old widened make radius
- forced-make regressions rejecting invalid back-half rim-plane crossings
- eligible short-lane defenders failing the commit roll and leaving the pass untouched
- risky long/cross-court passes finding a deterministic commit seed and then stealing through the visible live-ball path
- committed defenders still being able to lose the live race to the intended receiver
- receiver-first pass claims completing live passes
- defender-first lane cuts completing live steals
- late defenders failing to steal safe passes
- out-of-bounds passes resolving before any later claim
- multi-frame pass flight staying visible through coordinator projection sync

## 2026-04-10 No Defenders Pause Toggle Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd`
- Result:
  - Pure logic: 638
  - Scenarios: 13
  - Balance: 4
  - Failures: 0
- Notes:
  - `PauseOverlay` now exposes a `No Defenders` toggle and `GameCoordinator` now hides disabled defenders and removes them from pass, contest, block, and rebound logic.
  - Close-range shots now force dunk families whenever no live defenders are active, even for low-dunk or stationary players inside the normal close-finish radius.
  - Godot still emits the existing non-blocking CanvasItem/object/resource warnings on exit after the passing summary.

## 2026-04-10 Dunk Vs Layup Decision Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd`
- Result:
  - Pure logic: 629
  - Scenarios: 13
  - Balance: 4
  - Failures: 0
- Notes:
  - `PlayerData`, the default team resources, and `PlayerAnimationConfig` now expose an explicit `dunk` stat plus stricter dunk-speed and dunk-rating gates.
  - `GameCoordinator` now commits close finishes through a deterministic two-stage chooser that falls back to layup when the dunk-only gates fail and logs the committed finish decision.
  - `DefenseController` now exposes `get_block_chance()` and applies dunk-only block resistance from the committed shooter's `dunk` rating without changing layup or jumper block math.
  - Godot still emits the existing non-blocking CanvasItem/object/resource warnings on exit after the passing summary.

## 2026-04-10 Dunk Contact Hold Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd`
- Result:
  - Pure logic: 598
  - Scenarios: 13
  - Balance: 4
  - Failures: 0
- Notes:
  - `PlayerAnimationConfig`, `PlayerVisual`, and `GameCoordinator` now hold rows `13`, `15`, and `16` on authored rim-contact frames before the world ball is allowed to release.
  - `ShotController` and `BallSimulator` now validate dunk-specific make and miss release profiles, including direct guided descent for makes and upward-and-away bounce flight for misses.
  - The overhold smoke reset now clears score-followthrough state between cases so through-net assertions do not leak across deterministic runs.

## 2026-04-10 Tap Pass And Swipe Shot Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --quit`
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd`
- Result:
  - Pure logic: 470
  - Scenarios: 13
  - Balance: 4
  - Failures: 0
- Notes:
  - `InputController` now classifies quick taps as pass requests and upward shot swipes as shot-arm gestures, with movement-zone releases still able to win over the normal movement-stop path when they satisfy the swipe gate.
  - `GameCoordinator` now maintains a persistent default pass target highlighted with the light-blue ring, resolves empty tap passes through that target, and still lets direct teammate taps override it.
  - Godot still emits the existing non-blocking CanvasItem/object/resource warnings on exit after the passing summary.

## 2026-04-10 Upward Top-Half Shot Swipe Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --quit`
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd`
- Result:
  - Pure logic: 472
  - Scenarios: 13
  - Balance: 4
  - Failures: 0
- Notes:
  - `InputController` now only arms `SHOT_AIM` for upward swipes whose release finishes in the top half of the visible screen.
  - The suite now rejects downward swipes and upward swipes that stay in the lower half, while still proving that a qualifying upward swipe from the movement zone wins over normal movement release.
  - Godot still emits the existing non-blocking CanvasItem/object/resource warnings on exit after the passing summary.

## 2026-04-09 Dynamic Close Camera Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --quit`
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd`
- Result:
  - Pure logic: 441
  - Scenarios: 13
  - Balance: 4
  - Failures: 0
- Notes:
  - `CourtProjection` now validates a base responsive court layout plus a second-stage close-camera transform, including inverse touch round-tripping after camera zoom and tracking offset removal.
  - Smoke coverage now checks player-centered opening possession framing, ball-centered pass flight, first-frame shot-flight tracking handoff, hidden-held-ball presentation, and HUD containment while world presentation moves under the camera.
  - The suite still exits with the existing non-blocking Godot CanvasItem/object/resource leak warnings after the passing summary.

## 2026-04-09 Close-Camera Retune And Floor Marker Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --quit`
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd`
- Result:
  - Pure logic: 463
  - Scenarios: 13
  - Balance: 4
  - Failures: 0
- Notes:
  - The close camera now validates against the retuned `2.1x` zoom while keeping the same player-vs-ball tracking handoff and inverse input mapping behavior.
  - `PlayerController` presentation now exposes a debug floor-marker snapshot so smoke coverage can assert that player shadows remain disabled and the controlled-player marker stays a white outlined oval with the expected feet-centered placement.
  - Godot still emits the existing non-blocking CanvasItem/object/resource warnings on exit after the passing summary.

## Notes

- Godot emitted the known macOS `get_system_ca_certificates` warning in headless mode. It did not block import, tests, or smoke validation.
- The final rerun used the approved headless Godot command and still wrote fresh `user://logs` output successfully.
- The current headless test run exits with non-failing Godot leak/resource warnings after the suite summary. Gameplay and assertions still pass; the warning is tracked as a non-blocking issue.

## 2026-04-09 Responsive Mobile Court And HUD Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd`
- Result:
  - Pure logic: 374
  - Scenarios: 11
  - Balance: 4
  - Failures: 0
- Notes:
  - The responsive layout pass now proves that `CourtProjection` can remap the fixed gameplay court into a centered `court_screen_rect` below the live HUD banner without changing `CourtConfig` world coordinates.
  - Smoke validation now checks the centered play-rect placement, hoop-over-banner clearance, HUD child-rect containment for the home score, timer, pause button, and away score, plus readable player scale under the narrower framed court.
  - Manual on-device screenshot revalidation was not run in this session; the responsive layout change was validated through the passing headless suite and smoke assertions.

## 2026-04-09 Release-To-Pass And Tap-To-Arm Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd`
- Result:
  - Pure logic: 381
  - Scenarios: 13
  - Balance: 4
  - Failures: 0
- Notes:
  - The suite now validates quick-tap shot qualification, upper-screen and lower-zone tap shot arming, center-release cancel behavior, and release-to-pass locking.
  - Deterministic coverage now includes `Center Release Idle`, `Tap Red Miss`, and pause/resume safety while already armed in `SHOT_AIM`.
  - Godot still emits the existing non-blocking CanvasItem/object/resource warnings on exit after the passing summary.

## 2026-04-09 Release-Synced Shot Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd`
- Result:
  - Pure logic: 248
  - Scenarios: 10
  - Balance: 4
  - Failures: 0
- Notes:
  - The suite now validates the hidden-held-ball contract, immediate pass-flight visibility, the staged `SHOT_RELEASE` state, and row-specific launch timing after the authored release frame finishes displaying.
  - Deterministic coverage now includes row-4 set shots, seed-stable row-8-vs-10 jumper selection, straight-vs-side layups, deterministic straight-dunk row locks, side dunks, and delayed blocker jump-contest activation on blocked releases.
  - Godot still emits the existing non-blocking object/resource warnings on exit after the passing summary.

## 2026-04-09 Aim-Synced Shot Windup Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd'`
- Result:
  - Pure logic: 248
  - Scenarios: 10
  - Balance: 4
  - Failures: 0
- Notes:
  - The suite now validates the one-way shot bar, the synced committed windup row, the tail-end green window, and the authored release-frame launch gate.
  - Early timing taps lock the current quality and still play through followthrough, while letting the decision bar expire forces the late-miss path.
  - Row 5 remains a fallback hold pose, not the main live shot-aim row.

## 2026-04-09 Unified 15 FPS Shot Cadence Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd`
- Result:
  - Pure logic: 411
  - Scenarios: 10
  - Balance: 4
  - Failures: 0
- Notes:
  - The suite now proves rows 4, 8, 10, 13, 14, 15, 16, and 17 all derive `fps`, `release_time_seconds`, and `full_animation_duration_seconds` from the same 15 FPS source of truth.
  - The smoke pass now also checks that a committed shot row continues through the staged release path without picking up a faster cadence, and that blocked-shot waits track the real row release timing instead of an old fixed faster assumption.
  - Godot still emits the existing non-blocking CanvasItem/object/resource warnings on exit after the passing summary.

## 2026-04-09 Full-Sheet Animation Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd`
- Result:
  - Pure logic: 176
  - Scenarios: 10
  - Balance: 4
  - Failures: 0
- Notes:
  - The suite now validates exact animation families, resolved rows, variant locking, X-flip state, outline visibility, and fill-sheet selection through the new player visual debug accessors.
  - Close-finish presentation is covered with deterministic layup, straight-dunk, and side-dunk assertions.
  - Godot still emits the existing non-blocking object/resource warnings on exit after the passing summary.

## 2026-04-09 Pass Flight And Steal Resolve Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd`
- Result:
  - Pure logic: 95
  - Scenarios: 10
  - Balance: 4
  - Failures: 0
- Notes:
  - Passes now stay visible as authoritative in-flight ball motion instead of being overwritten by the held-ball sync path at the end of the frame.
  - The deterministic harness now proves both the clean receiver catch path and the defender lane-cut steal path, including the short `STEAL_RESOLVE` beat before opponent sim.
  - Godot still emits the existing non-blocking object/resource warnings on exit after the passing summary.

## 2026-04-09 Full-Screen Court Rescale Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd`
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --quit`
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . res://scenes/GameRoot.tscn --quit-after 3`
- Result:
  - Pure logic: 113
  - Scenarios: 10
  - Balance: 4
  - Failures: 0
- Notes:
  - The fullscreen projection retune now proves full-screen court bounds in pure logic and smoke validation without changing `CourtConfig` world dimensions.
  - Smoke validation confirms the hoop remains below the HUD banner, the enlarged players stay readable, the possessed world ball can stay hidden until release, and pass-flight rendering stays aligned with projection.
  - Godot still emits the existing non-blocking object/resource warnings on exit after the passing summary.

## 2026-04-09 Probabilistic Pass Commit Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd`
- Result:
  - Pure logic: 104
  - Scenarios: 10
  - Balance: 4
  - Failures: 0
- Notes:
  - Pass steals now gate the visible lane cut behind a seeded commit roll, but once committed the play still resolves as an honest live-ball race.
  - The deterministic harness now covers commit-fail, commit-steal, committed-but-late offense catches, and the forced interception hook.
  - The latest Normal-difficulty pass-risk batch landed at short steals `0.00` and long steals `0.23`, which is safely below the earlier always-commit behavior.

## 2026-04-08 Three-Piece Hoop Pass-Through Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd`
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --quit-after 3`
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . res://scenes/GameRoot.tscn --quit-after 3`
- Result:
  - Pure logic: 71
  - Scenarios: 10
  - Balance: 4
  - Failures: 0
- Notes:
  - The three-piece hoop assets loaded cleanly through the headless suite after the new front-net body file was added.
  - Godot still emits the existing non-blocking object/resource warnings on exit after the passing summary.

## 2026-04-08 Guided Make Descent Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd`
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --quit-after 3`
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . res://scenes/GameRoot.tscn --quit-after 3`
- Result:
  - Pure logic: 83
  - Scenarios: 10
  - Balance: 4
  - Failures: 0
- Notes:
  - Guided green makes now prove a legal front-half score gate, a guided descent, and a below-net exit in the pure-logic harness.
  - Deterministic scoring hooks now launch a real guided make, so the smoke and scenario suite validate the live down-through-the-net behavior instead of a fabricated instant score frame.
  - Godot still emits the existing non-blocking object/resource warnings on exit after the passing summary.

## 2026-04-08 Rim-Plane Handoff Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd`
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --quit-after 3`
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . res://scenes/GameRoot.tscn --quit-after 3`
- Result:
  - Pure logic: 87
  - Scenarios: 10
  - Balance: 4
  - Failures: 0
- Notes:
  - Guided make profiles now prove a rim-plane handoff, a below-rim score gate, and a first visible descent sample that is already moving downward.
  - Smoke validation now checks that the score cannot appear while the ball is still above the rim.
  - Godot still emits the existing non-blocking object/resource warnings on exit after the passing summary.

## 2026-04-08 Terminal Screen Drop Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd`
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --quit-after 3`
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . res://scenes/GameRoot.tscn --quit-after 3`
- Result:
  - Pure logic: 90
  - Scenarios: 10
  - Balance: 4
  - Failures: 0
- Notes:
- Guided makes now apply a render-only terminal drop of 60px that ramps in during the last 20% of free flight, holds through guided descent, and fades out during `net_exit`.
  - Green preview sampling now applies the same terminal drop so the last preview segment stays aligned with the live finish.
  - Solver output, score legality, and hoop geometry remain unchanged.
  - Godot still emits the existing non-blocking object/resource warnings on exit after the passing summary.

## 2026-04-09 Smooth AI Steering And Pass Preview Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd`
- Result:
  - Pure logic: 434
  - Scenarios: 13
  - Balance: 4
  - Failures: 0
- Notes:
  - The suite now proves AI-only arrival steering settles inside the configured stop band without oscillating while still preserving long-run travel pace.
  - Route-package coverage now locks strong-side and weak-side targets through centerline deadband moves before allowing a side flip once the ballhandler meaningfully crosses the switch threshold.
  - Smoke validation now confirms normal boot hides teammate catch rings, and gameplay reuses the light-blue ring only for the currently locked pass-preview target.
  - Godot still emits the existing non-blocking object/resource warnings on exit after the passing summary.
