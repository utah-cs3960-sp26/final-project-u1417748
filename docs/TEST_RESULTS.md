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

- Pure logic: 37 / 37
- Scenarios: 10 / 10
- Balance: 4 / 4
- Failures: 0

Balance metrics from the final run:

- `difficulty_order`: easy `0.96`, normal `1.05`, hard `1.27`
- `pass_risk`: short `0.10`, long `0.46`
- `rebound_distribution`: offense `0.32`, defense `0.68`
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
- a non-headless gameplay capture confirmed the blue half-court floor renders vertically and the front net hangs over the painted top-rim area

Additional pure-logic coverage now includes:

- meter green-window sizing
- meter green-window stability under contest and ratings
- meter red/green classification
- ping-pong meter motion
- deterministic made-shot launch scoring through the hoop
- deterministic miss launch staying outside the score region
- forced green-launch scoring from a contested lane
- green release producing a make outcome
- contested green release still producing a make outcome
- red release producing a miss outcome
- projected ground-depth monotonicity
- projected z-lift from a stable ground anchor
- actor scale and draw-order depth behavior
- projected teammate tap hit testing
- projection-aware shot-hold targeting
- gameplay boot scene selection
- textured court smoke instantiation
- hoop sprite smoke instantiation
- ball sprite smoke instantiation
- player sprite smoke instantiation

## Notes

- Godot emitted the known macOS `get_system_ca_certificates` warning in headless mode. It did not block import, tests, or smoke validation.
- The initial in-sandbox Godot validation crashed while opening its runtime log path. Rerunning the suite outside the sandbox resolved that environment issue and the suite passed.
- The current headless test run exits with non-failing Godot leak/resource warnings after the suite summary. Gameplay and assertions still pass; the warning is tracked as a non-blocking issue.
