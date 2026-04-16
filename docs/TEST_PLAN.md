# Test Plan

## Automated Layers

### Pure Logic

Covered by `tests/TestRunner.gd`:

- visible `MOVE`-zone dead-zone behavior
- visible-panel joystick direction and magnitude normalization
- left/right `PASS` release classification
- direct `PASS` button taps without movement
- top-left `SHOOT` release classification into `shot_layout`
- top-right `DUNK` release classification into `dunk`
- direct `SHOOT` / `DUNK` button taps without movement
- direct `SHOOT` button two-tap timing: first tap shows the meter and aim pose with no pending release, then a second tap at the `SHOOT` button position commits the release
- idle control-panel buttons sharing the neutral dark base color `#1b1d3a`
- hovered / pressed action buttons swapping from the neutral base into their authored action color
- compact control-panel height staying near `24%` of the safe viewport with bottom anchoring preserved
- compact control-panel font caps: main labels at or below `34px`, pass-focus labels at or below `16px`
- `MOVE`-lane release cancellation
- short-drag rejection for panel actions
- removed bottom dunk-strip rejection
- open-court release rejection outside the control panel
- both pass lanes routing to the single focused pass target
- second-finger action-button taps during an active move drag
- hidden-controls mode preserving the same active hitboxes
- teammate screen coordinates no longer bypassing the focused pass lanes
- old open-screen pass / shot gestures no longer firing in `LIVE_OFFENSE`
- non-action extra touches not stealing the live move pointer while dragging
- default pass-target ranking by commit chance, distance, and hoop proximity
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
- guided make post-score sequencing continuing through `net_exit -> floor_drop -> floor_settle`
- guided make `net_exit` holding the full terminal presentation drop instead of decaying mid-follow-through
- guided makes landing at the finish-radius center instead of dying under the net
- made-shot rendered anchors staying monotonic downward from `guided_descent` through the end of `floor_drop`
- made-shot landing-frame camera targeting using the same pre-release finish-marker screen sample the player saw before the shot
- landed made shots sharing the same visible finish-radius marker center instead of only matching the target in world space
- the first `floor_drop` velocity sample staying aligned with the outgoing `net_exit` motion instead of jumping into a faster post-net descent
- the first upward rendered-anchor motion being deferred until `floor_settle`
- a single contiguous `front_of_net` follow-through window before the forced hoop render clears
- four-layer top-hoop net registration and z ordering: all net textures `30x28`, `NetClean` below shot-ball phases, inactive `NetCleanBottomHalf` and `NetBody` below airborne/rim/generic-front ball phases, and active `NetCleanBottomHalf` plus `NetBody` above through-net ball phases
- non-descending airborne balls near the hoop can use the `front_of_net` render phase without activating the lower net masks
- forced hoop render clearing only after the rendered ball has crossed the front-net exit threshold
- cleared follow-through never re-entering `net_channel` or `front_of_net`
- made shots landing before opponent sim begins, and before buzzer-end game over
- misses staying in free flight and never entering guided make phases
- scoring plane crossing
- explicit hoop render-phase ordering
- rim-mouth then net-channel score sequencing
- through-net score follow-through flags
- score-triggered net swish activation
- dunk auto-makes sharing the same floor-finish target as jumper makes
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
- opponent sim visual-step count clamped to `1..4`
- opponent sim final visual action matching the resolved score/no-score result
- opponent sim display text staying banner-ready and free of internal clock/debug-only lines
- opponent sim visual steps carrying stable `player_id`, `player_role`, and `actor_team` metadata when applicable
- bottom-hoop snapshot reporting a loaded normalized `144x170` texture anchored on the bottom court side
- bottom-hoop snapshot reporting the doubled `2.0x` visual scale multiplier and an absolute z order above entity sprites
- opponent sim visual snapshot reporting active state, current kind, actor role/team, ghost positions, ball ownership/visibility, and camera anchor
- opponent sim presentation hiding the scoreboard and control panel while banner text is visible
- opponent sim presentation hiding live players and live ball while ghost tableaux are visible
- opponent sim tableaux keeping all ghost player positions in the bottom half of the court
- opponent sim presentation restoring the scoreboard and controls when `LIVE_OFFENSE` resumes
- opponent sim presentation restoring live players and live ball when `LIVE_OFFENSE` resumes
- deterministic opponent sim seeds covering one-step score, multi-step score, and no-score outcomes
- log file creation

### Deterministic Scenarios

Resource-backed scenarios under `data/scenarios/`:

- clean pass-and-shoot make
- contested green release scores
- contested miss with defensive rebound
- bad cross-court pass steal
- center release idle
- late miss timeout
- stationary pressure turnover
- out-of-bounds turnover
- offensive rebound continuation
- buzzer shot completion
- pause/resume safety
- tap red miss
- opponent banner one-step score
- opponent banner multi-step score
- opponent banner no-score turnover or steal
- opponent banner tap-skip
- opponent banner low-clock game-over
- opponent tableau bottom-half render smoke
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
- confirm the compact bottom-quarter control panel is visible on match start with a shorter `SHOOT | DUNK` row above a larger `PASS | MOVE | PASS` row and small capped labels
- confirm the center `MOVE` lane is visibly wider than either `PASS` lane
- confirm the scoreboard card sits at the bottom left just above the `SHOOT` half instead of spanning the top edge
- confirm a square pause button with a two-bar icon sits at the bottom right above the `DUNK` half and matches the scoreboard card height
- move the ballhandler by dragging inside the center `MOVE` zone and confirm the visible joystick knob tracks the thumb
- confirm tiny thumb movements inside the dead zone do not move the ballhandler
- confirm a persistent light-blue ring marks the default pass target during `LIVE_OFFENSE`
- tap either `PASS` button without moving first and confirm the marked teammate receives the pass
- release from `MOVE` into either `PASS` lane and confirm the marked teammate receives the pass
- confirm both `PASS` lanes route to the same highlighted receiver
- start moving in `MOVE`, then tap a `PASS`, `SHOOT`, or `DUNK` button with a second finger and confirm the action still fires
- confirm every control button is dark by default and only changes into its action color while hovered by the drag or pressed directly
- confirm a clean pass transfers control only after the live ball reaches the receiver
- confirm a safe short pass usually reaches the target even if a defender was lane-eligible
- confirm a steal attempt only shows a defender stepping into the lane when that defender actually committed
- confirm a steal shows the defender securing the ball before the opponent sim action banner takes over
- confirm opponent possessions show a centered black horizontal action banner at about `80%` opacity
- confirm the back of the opposite-side hoop is always visible at the bottom of the court behind players
- confirm opponent possessions show five AWY ghost players, five HOM ghost defenders, and a ghost ball on the bottom half of the court
- confirm live players and the live ball disappear while the opponent-sim tableaux are shown
- confirm each opponent action beat jump-cuts to a new static formation without interpolated movement
- confirm the camera snaps to the current opponent-sim actor or formation center on each action beat
- confirm the scoreboard card, pause button, and bottom controls disappear while opponent action text is displayed
- confirm the banner action text is short, readable, and uses basketball language such as pass, jumper, layup, alley-oop, dunk, turnover, steal, miss, block, or defensive rebound
- confirm each opponent action beat auto-advances after about one second
- confirm tapping the screen during the opponent banner advances one action beat, not the entire sequence
- confirm the final opponent action clearly explains whether AWY scored or failed to score
- confirm AWY score and clock changes apply after the final opponent action, not when the first banner text appears
- confirm the scoreboard, pause button, and controls reappear when the new human possession begins
- confirm live players and the live ball reappear when the new human possession begins
- release from `MOVE` into the top-left `SHOOT` half and confirm shot mode arms at normal speed with the timing meter spanning the full top row plus visible preview dots on court
- release from `MOVE` into the top-right `DUNK` half near the rim and confirm an eligible dunk skips the timing meter and enters the dunk finish flow
- release from `MOVE` into the top-right `DUNK` half near the rim with a non-dunk finisher and confirm it falls back to a layup instead of a jumper
- release from `MOVE` into the top-right `DUNK` half far from the rim and confirm it does not arm a shot
- tap `SHOOT` directly and confirm shot mode arms without needing a movement drag first
- tap `DUNK` directly near the rim and confirm it behaves the same as the release-based dunk input
- release toward the old bottom-center dunk-strip area and confirm it no longer triggers dunk intent
- release back into `MOVE` after dragging and confirm it cancels instead of arming a shot
- confirm the committed shot row starts playing immediately during armed shot mode and the meter advances in one direction only
- confirm committed shot rows keep a stable 15 FPS cadence instead of visibly speeding up between aim and release
- confirm the tail-end green window ends exactly on the authored release frame for the selected row
- confirm tapping anywhere locks shot quality immediately while the animation continues to the release frame before launch
- confirm the live timing meter spans across both the `SHOOT` and `DUNK` buttons so it is wider than the `SHOOT` half alone
- confirm failing to tap before the bar ends produces a late miss
- confirm the standalone ball is hidden while a player sprite owns possession and only appears on pass start or once a shot animation reaches its authored release frame
- tap once in green and confirm the ball visibly climbs into a dramatic arc and finishes through the hoop
- tap once in red and confirm a miss or block
- score at least one basket
- confirm the blue second-court art is visible, vertically oriented, full-height, and not stretched
- confirm the court is a perfect rectangle with parallel sidelines and no trapezoid stretch
- confirm the hoop body plus `Net`, `NetClean`, `NetCleanBottomHalf`, and `NetBody` all stay aligned on the painted top-rim area
- confirm airborne and rim-approach shots render in front of inactive `NetCleanBottomHalf` and `NetBody`, while normal makes activate both lower net masks only as they enter `net_channel` and the made-shot `front_of_net` exit
- confirm the scored ball stays in one continuous downward motion from the net through the floor drop, with no upward pop before the floor bounce begins
- confirm the score text does not appear while the ball is still above the rim or behind the backboard on a made shot
- confirm only the currently controlled player shows the outline sheet
- confirm westward dribble/run movement mirrors the player sprite along X
- confirm a stationary ballhandler can show open dribble or pressured dribble idles while off-ball teammates stay on the no-ball idle/run rows
- confirm a stationary ballhandler with clear defender space can use the row-4 set shot, while non-set jumpers use the randomized row-8/row-10 release rows
- confirm close shots near the rim can show straight layups, side layups, straight dunks, or side dunks depending on approach and momentum
- pause the match and confirm `Show Controls` hides the panel art while movement/pass/shoot/dunk hitboxes still work after resuming
- confirm `Show Controls` does not hide the relocated scoreboard card
- confirm `Show Controls` does not hide the relocated pause button
- confirm `Show Controls` is runtime-only and starts visible again on a fresh match
- confirm players are dramatically larger and easier to read than the earlier build
- confirm the live ball shadow shrinks and the ball sprite grows as height increases
- on a physical mobile device, confirm pass-lock and green-timing haptics fire when supported
- force a miss and observe rebound resolution
- pause and resume
- reach game over and restart
- verify `user://logs/` contains fresh files
