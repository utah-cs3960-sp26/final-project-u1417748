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
- scoring plane crossing
- 2PT / 3PT classification
- pass interception separation
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
- pass to at least one teammate
- enter shot aim and confirm slow-motion + bottom red/green meter + visible preview dots
- release once in green and confirm the ball visibly climbs into a dramatic arc and finishes through the hoop
- release once in red and confirm a miss or block
- score at least one basket
- confirm the blue second-court half is visible and vertically oriented
- confirm the court is a perfect rectangle with parallel sidelines and no trapezoid stretch
- confirm the hoop body and front net sit on the painted top-rim area
- confirm players are dramatically larger and easier to read than the earlier build
- confirm the live ball shadow shrinks and the ball sprite grows as height increases
- force a miss and observe rebound resolution
- pause and resume
- reach game over and restart
- verify `user://logs/` contains fresh files
