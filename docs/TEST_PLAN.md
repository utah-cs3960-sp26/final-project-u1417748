# Test Plan

## Automated Layers

### Pure Logic

Covered by `tests/TestRunner.gd`:

- joystick normalization
- meter green-window sizing stays fixed under contest and ratings
- red/green meter classification
- meter ping-pong movement
- flat rectangular court width consistency
- flat projection linear depth mapping
- flat projection ground-coordinate round trip
- cinematic near/far shot airtime thresholds
- cinematic near/far shot apex thresholds
- preview samples stay close to the solved apex
- deterministic make / miss launch paths
- preview/release launch-profile agreement
- preview/live simulation agreement for released paths
- above-floor launch height
- ball gravity and z-height
- guided make handoff staying exactly on the rim plane
- guided make score gate starting below the rim so the score cannot appear at the handoff frame
- guided make approach never going board-side before score
- guided make score-gate crossing occurring during `guided_descent`
- guided make descent staying centered inside the hoop cylinder
- misses staying in free flight and never entering guided make phases
- scoring plane crossing
- explicit hoop render-phase ordering
- rim-mouth then net-channel score sequencing
- through-net score follow-through flags
- score-triggered net swish activation
- 2PT / 3PT classification
- pass commit-roll failure on an otherwise eligible short lane
- pass commit-roll success on a risky long/cross-court lane
- committed defenders still being able to lose the live race
- pass outcome race separation between receiver-first and defender-first cases
- out-of-bounds pass resolution happening before later claims
- multi-frame pass flight visual progression surviving coordinator projection sync
- route target generation
- rebound fallback generation
- opponent sim validity
- log file creation

### Deterministic Scenarios

Resource-backed scenarios under `data/scenarios/`:

- clean pass-and-shoot make
- contested green release scores
- contested miss with defensive rebound
- bad cross-court pass steal
- stationary pressure turnover
- out-of-bounds turnover
- offensive rebound continuation
- buzzer shot completion
- pause/resume safety
- long-run no-softlock

### Balance Batches

Resource-backed batches under `data/balance/`:

- shot quality bands
- pass risk separation
- difficulty ordering
- rebound distribution

## Commands

Import / script registration:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --editor --path . --quit
```

Headless suite:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd
```

Smoke boot:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --quit-after 5
```

Smoke game scene:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . res://scenes/GameRoot.tscn --quit-after 5
```

## Manual Smoke Checklist

- run the project and confirm live gameplay appears immediately
- move the ballhandler
- pass to at least one teammate and confirm the ball visibly travels between players instead of teleporting
- confirm a clean pass transfers control only after the live ball reaches the receiver
- confirm a safe short pass usually reaches the target even if a defender was lane-eligible
- confirm a steal attempt only shows a defender stepping into the lane when that defender actually committed
- confirm a steal shows the defender securing the ball before the possession jump-cut
- enter shot aim and confirm slow-motion + bottom red/green meter + visible preview dots
- release once in green and confirm the ball visibly climbs into a dramatic arc and finishes through the hoop
- release once in red and confirm a miss or block
- score at least one basket
- confirm the blue second-court half is visible and vertically oriented
- confirm the court is a perfect rectangle with parallel sidelines and no trapezoid stretch
- confirm the hoop body plus rear/full hoop, front rim lip, and front net body all stay aligned on the painted top-rim area
- confirm normal makes render in front of the backboard, meet the rim plane, immediately turn downward into the hanging net during the guided descent, and only go behind the board when thrown over it
- confirm the score text does not appear while the ball is still above the rim or behind the backboard on a made shot
- confirm players are dramatically larger and easier to read than the earlier build
- confirm the live ball shadow shrinks and the ball sprite grows as height increases
- force a miss and observe rebound resolution
- pause and resume
- reach game over and restart
- verify `user://logs/` contains fresh files
