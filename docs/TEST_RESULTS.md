# Test Results

## Environment

- Date: 2026-04-08
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

- Pure logic: 65 / 65
- Scenarios: 10 / 10
- Balance: 4 / 4
- Failures: 0

Balance metrics from the final run:

- `difficulty_order`: easy `0.92`, normal `1.05`, hard `1.24`
- `pass_risk`: short `0.10`, long `0.46`
- `rebound_distribution`: offense `0.35`, defense `0.65`
- `shot_quality`: green `1.0`, red `0.0`, contested green `1.0`, contested green window width `0.180`

## Scenario Result

Passed scenarios:

- Bad Cross Court Pass Steal
- Buzzer Shot Completion
- Clean Pass And Shoot Make
- Contested Green Release Scores
- Contested Miss With Defensive Rebound
- Long Run No Softlock
- Offensive Rebound Continuation
- Out Of Bounds Turnover
- Pause Resume Safety
- Stationary Pressure Turnover

## Smoke Result

- default boot scene (`GameRoot.tscn`) booted headless without script/runtime errors
- `GameRoot.tscn` booted headless without script/runtime errors
- headless validation kept the gameplay scene stable after the cinematic arc refactor and restored aim-preview path

Additional pure-logic coverage now includes:

- meter green-window sizing
- meter green-window stability under contest and ratings
- meter red/green classification
- ping-pong meter motion
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
- flat rectangular court width consistency
- flat projection linear depth mapping
- flat projection ground-coordinate round trip
- projected z-lift from a stable ground anchor
- cinematic-strength projected z-lift
- preview lift exceeding live-ball lift
- actor scale and draw-order depth behavior
- projected teammate tap hit testing
- projection-aware shot-hold targeting
- gameplay boot scene selection
- textured court smoke instantiation
- hoop sprite smoke instantiation
- ball sprite smoke instantiation
- player sprite smoke instantiation
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

## Notes

- Godot emitted the known macOS `get_system_ca_certificates` warning in headless mode. It did not block import, tests, or smoke validation.
- The initial in-sandbox Godot validation crashed while opening its runtime log path. Rerunning the suite outside the sandbox resolved that environment issue and the suite passed.
- The current headless test run exits with non-failing Godot leak/resource warnings after the suite summary. Gameplay and assertions still pass; the warning is tracked as a non-blocking issue.

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
