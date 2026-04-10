# Test Results

## Environment

- Date: 2026-04-09
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

Final passing rerun:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd
```

Smoke:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --quit-after 3
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . res://scenes/GameRoot.tscn --quit-after 3
```

## Automated Result

Final headless suite status: pass

- Pure logic: 374 / 374
- Scenarios: 11 / 11
- Balance: 4 / 4
- Failures: 0

Balance metrics from the final run:

- `difficulty_order`: easy `0.97`, normal `1.04`, hard `1.27`
- `pass_risk`: short `0.00`, long `0.23`
- `rebound_distribution`: offense `0.37`, defense `0.63`
- `shot_quality`: green `1.0`, red `0.0`, contested green `1.0`, contested green window width `0.180`

## Scenario Result

Passed scenarios:

- Bad Cross Court Pass Steal
- Buzzer Shot Completion
- Clean Pass And Shoot Make
- Contested Green Release Scores
- Contested Miss With Defensive Rebound
- Late Miss Timeout
- Long Run No Softlock
- Offensive Rebound Continuation
- Out Of Bounds Turnover
- Pause Resume Safety
- Stationary Pressure Turnover

## Smoke Result

- default boot scene (`GameRoot.tscn`) booted headless without script/runtime errors
- `GameRoot.tscn` booted headless without script/runtime errors
- headless validation kept the gameplay scene stable after the cinematic arc refactor and restored aim-preview path
- the projected court now maps into a centered responsive play rect below the banner instead of assuming the full viewport is playable court space
- the hoop still clears the responsive HUD banner, all HUD child rects stayed fully inside the banner, the world ball stays hidden while a player-held sprite owns possession, and pass-flight ball anchors stay aligned with projection
- the deterministic smoke pass stayed visible for 30 frames and advanced about 473 px on screen before the catch resolved

Additional pure-logic coverage now includes:

- meter green-window sizing
- meter green-window stability under contest and ratings
- meter red/green classification
- one-way shot bar timing against the committed windup row
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
- projected z-lift from a stable ground anchor
- cinematic-strength projected z-lift
- preview lift exceeding live-ball lift
- actor scale and draw-order depth behavior
- projected lower-zone gesture mapping
- projection-aware shot-mode arming input
- gameplay boot scene selection
- textured court smoke instantiation
- hoop sprite smoke instantiation
- ball sprite smoke instantiation
- player sprite smoke instantiation
- court mapping to the centered responsive play rect in a booted `GameRoot`
- ratio-preserving full-height court crop with offensive-side bias
- hoop art clearing the responsive HUD banner after the centered-court relayout
- responsive HUD child-rect containment for score, timer, and pause controls
- readable player presentation under the centered court framing
- hidden-held-ball presentation on the first rendered possession frame
- in-flight ball/projection alignment during the smoke pass
- invisible lower-zone movement dead zone and full-magnitude thumb radius
- flick distance and release-speed pass gating
- directional pass-preview cone selection and deterministic tie-breaking
- non-pass gesture release arming shot mode instead of forcing a pass
- shot timing running at normal speed after arm
- tap-to-time decision locking and late-miss timeout behavior
- home player fill textures binding to `Character1_NEW.png`
- away player fill textures binding to `Character2_NEW.png`
- controlled-player-only outline rendering plus outline transfer when control changes
- exact row assertions for no-ball idle, open dribble idle, pressured dribble idle, small dribble move, run dribble, off-ball run, guard idle, guard shuffle, guard run, and jump contest
- westward mirroring assertions for run dribbles and close-finish dunks
- staged `SHOT_RELEASE` entry before the world ball becomes visible
- row-4 set-shot selection when the defender-space gate is satisfied
- committed shot timing profiles resolving to 15 FPS for rows 4, 8, 10, 13, 14, 15, 16, and 17
- deterministic jumper-release variant locking across repeated syncs
- deterministic row-8-vs-10 jumper selection by seed once the set-shot gate is denied
- straight-vs-side layup row selection inside the close-finish radius
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

## 2026-04-09 One-Thumb Control And Full-Height Court Validation

- Commands run:
  - `'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd`
- Result:
  - Pure logic: 369
  - Scenarios: 11
  - Balance: 4
  - Failures: 0
- Notes:
  - The suite now validates the invisible lower-screen movement zone, pass-preview cone selection, flick distance and release-speed gating, and the tap-to-time shot flow.
  - Deterministic coverage now includes the full-height court crop behavior, the normal-speed armed `SHOT_AIM` phase, and the new `Late Miss Timeout` scenario.
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
