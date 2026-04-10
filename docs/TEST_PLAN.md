# Test Plan

## Automated Layers

### Pure Logic

Covered by `tests/TestRunner.gd`:

- invisible movement-zone dead-zone behavior
- invisible-stick direction and magnitude normalization
- flick pass gating on both distance and release speed
- directional-cone pass-preview selection and deterministic tie-breaking
- non-qualifying release arming shot mode instead of forcing a pass
- meter green-window sizing stays fixed under contest and ratings
- red/yellow/green timing classification on the one-way shot bar
- `SHOT_AIM` running at normal gameplay speed
- decision-window meter timing against the committed shot row
- late-miss timeout when the bar ends without a tap
- committed shot timing profiles deriving from a unified 15 FPS cadence across rows 4, 8, 10, 13, 14, 15, 16, and 17
- flat rectangular court width consistency
- full-height court crop preserving art ratio without stretch
- offensive-biased court crop revealing partial opposite-side floor coverage
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
- late miss timeout
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

### Animation Coverage

`tests/TestRunner.gd` now uses stable `PlayerController` / `PlayerVisual` debug hooks to assert:

- home players binding to `Character1_NEW.png`
- away players binding to `Character2_NEW.png`
- possessed players keeping the standalone world ball hidden until a pass or the correct shot-release frame reveals it
- controlled-player-only outline rendering and outline transfer when control changes
- stationary no-ball idle
- stationary with-ball idle versus pressured idle
- small-move dribble versus run dribble
- off-ball run
- guard idle versus shuffle versus run
- westward mirroring
- set-shot row selection when the defender is far and the shooter is below the finish-momentum threshold
- staged shot-release gating from `SHOT_RELEASE` into `SHOT_IN_FLIGHT`
- jumper-release variant locking
- early release locking while the committed row continues to the authored release frame
- late-miss timeout forcing a miss once the decision window ends without a timing tap
- committed shot rows keeping the same 15 FPS cadence through aim-to-release continuation instead of accelerating between phases
- deterministic row-8-vs-10 jumper selection by seed once the set-shot gate is denied
- straight-vs-side layup selection inside the close-finish radius
- straight-dunk random row selection plus side-dunk row selection inside the closer finish radius
- jump-contest row selection for the actual blocking defender

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
- move the ballhandler by dragging in the lower touch zone and confirm no visible joystick is present
- confirm a faint thumb anchor appears on touch-down and disappears cleanly on release
- confirm tiny thumb movements inside the dead zone do not move the ballhandler
- pass to at least one teammate with a flick and confirm the ball visibly travels between players instead of teleporting
- confirm the teammate preview ring locks under the intended target before lift-off on a valid flick
- confirm a clean pass transfers control only after the live ball reaches the receiver
- confirm a safe short pass usually reaches the target even if a defender was lane-eligible
- confirm a steal attempt only shows a defender stepping into the lane when that defender actually committed
- confirm a steal shows the defender securing the ball before the possession jump-cut
- release a non-pass gesture and confirm shot mode arms at normal speed with a bottom red/green meter + visible preview dots
- confirm the committed shot row starts playing immediately during armed shot mode and the meter advances in one direction only
- confirm committed shot rows keep a stable 15 FPS cadence instead of visibly speeding up between aim and release
- confirm the tail-end green window ends exactly on the authored release frame for the selected row
- confirm tapping anywhere locks shot quality immediately while the animation continues to the release frame before launch
- confirm failing to tap before the bar ends produces a late miss
- confirm the standalone ball is hidden while a player sprite owns possession and only appears on pass start or once a shot animation reaches its authored release frame
- tap once in green and confirm the ball visibly climbs into a dramatic arc and finishes through the hoop
- tap once in red and confirm a miss or block
- score at least one basket
- confirm the blue second-court art is visible, vertically oriented, full-height, and not stretched
- confirm the court is a perfect rectangle with parallel sidelines and no trapezoid stretch
- confirm the hoop body plus rear/full hoop, front rim lip, and front net body all stay aligned on the painted top-rim area
- confirm normal makes render in front of the backboard, meet the rim plane, immediately turn downward into the hanging net during the guided descent, and only go behind the board when thrown over it
- confirm the score text does not appear while the ball is still above the rim or behind the backboard on a made shot
- confirm only the currently controlled player shows the outline sheet
- confirm westward dribble/run movement mirrors the player sprite along X
- confirm a stationary ballhandler can show open dribble or pressured dribble idles while off-ball teammates stay on the no-ball idle/run rows
- confirm a stationary ballhandler with clear defender space can use the row-4 set shot, while non-set jumpers use the randomized row-8/row-10 release rows
- confirm close shots near the rim can show straight layups, side layups, straight dunks, or side dunks depending on approach and momentum
- confirm players are dramatically larger and easier to read than the earlier build
- confirm the live ball shadow shrinks and the ball sprite grows as height increases
- on a physical mobile device, confirm pass-lock and green-timing haptics fire when supported
- force a miss and observe rebound resolution
- pause and resume
- reach game over and restart
- verify `user://logs/` contains fresh files
