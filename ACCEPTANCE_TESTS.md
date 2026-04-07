# ACCEPTANCE_TESTS.md

## Purpose

This document defines the pass/fail bar for the project.  
It exists to prevent ambiguity for autonomous coding loops and to make “done” measurable.

A build is **not accepted** unless every release-blocking test in this document passes, there are no critical soft-locks, and the game can be played from start to finish repeatedly without breaking.

---

## Test philosophy

This project is gameplay-heavy and should not rely on vague “it feels okay” judgments alone.

Testing must combine:
- objective functional checks
- deterministic scenario tests
- long-run stability tests
- broad balance sanity checks
- manual smoke verification

The goal is not perfect simulation realism. The goal is a stable, readable, fun arcade loop that matches the design brief.

---

## Acceptance gates

A build is accepted only when all of the following are true:

1. all **release-blocking functional tests** pass
2. all **release-blocking scenario tests** pass
3. all **release-blocking stability tests** pass
4. all **required logs** are written
5. no critical or high-severity soft-lock remains
6. no score duplication, null-control, or broken state transition bug remains
7. the game can be played through a full 3-minute match repeatedly
8. the manual smoke checklist passes

---

## Severity levels

### P0 — release blocking
The game cannot be accepted if any P0 issue remains.
Examples:
- crash on startup
- match cannot start
- no player control
- score cannot update
- game soft-locks
- game cannot end
- restart breaks the session

### P1 — acceptance blocking
The game technically runs, but a major designed feature is broken.
Examples:
- shot arc preview wrong enough to mislead the player
- passes cannot be intercepted
- rebounds never resolve
- pause corrupts timing
- opponent sim does not consume time or log outcomes

### P2 — non-blocking but must be logged
Examples:
- placeholder visuals are ugly but readable
- one route package spacing is imperfect
- rebound visuals are rough but functional

Only P0 and P1 block acceptance.

---

## Test environments

At minimum validate in these contexts:

1. **Editor/debug environment**
   - mouse emulating touch
   - optional keyboard fallback for movement
   - debug overlays available

2. **Mobile-style runtime layout**
   - portrait aspect
   - touch-oriented UI spacing
   - joystick usable in lower third

3. **Deterministic test mode**
   - fixed RNG seed
   - scripted bot pilot
   - reproducible outcomes

---

## Release-blocking functional tests

### AT-001 — Boot to menu
**Severity:** P0  
**Type:** Functional

**Preconditions**
- Fresh launch

**Steps**
1. Launch the project.
2. Wait for the first interactive screen.

**Expected result**
- The game opens without crashing.
- A start/menu screen appears.
- The screen includes a clear **Start Game** button.

**Fail if**
- the project crashes
- the menu does not appear
- Start Game is missing or non-interactive

---

### AT-002 — Start game enters live match
**Severity:** P0  
**Type:** Functional

**Steps**
1. From the menu, press **Start Game**.

**Expected result**
- A live match scene loads.
- The court is visible.
- 5 offensive players and 5 defensive players are present.
- The point guard begins with the ball in the default start/reset formation.

**Fail if**
- the game remains on menu
- the match scene loads incompletely
- player counts are wrong
- no ballhandler is assigned

---

### AT-003 — Portrait-only HUD layout
**Severity:** P1  
**Type:** Functional/UI

**Steps**
1. Start a match.
2. Inspect the top of the screen.

**Expected result**
- A black top banner is visible.
- Left side shows `HOM` and home score.
- Center shows countdown timer and pause button.
- Right side shows `AWY` and away score.
- Layout is readable in portrait orientation.

**Fail if**
- any required element is missing
- scores or timer overlap
- pause button is inaccessible
- the layout assumes landscape

---

### AT-004 — Ballhandler movement via joystick
**Severity:** P0  
**Type:** Functional/Input

**Steps**
1. Start a match.
2. Drag the virtual joystick in each cardinal and diagonal direction.

**Expected result**
- The current offensive ballhandler moves in the corresponding direction.
- Movement is responsive.
- Releasing the joystick stops intentional movement.

**Fail if**
- joystick does nothing
- wrong player moves
- movement direction is inverted or severely inconsistent
- movement continues uncontrollably after release

---

### AT-005 — Multitouch movement plus action
**Severity:** P1  
**Type:** Functional/Input

**Steps**
1. Hold the joystick with one touch.
2. While moving, use another touch to interact with a teammate or begin a shot.
3. Repeat in debug mode using the available desktop fallback if necessary.

**Expected result**
- The input system supports movement and action without losing control.
- The match remains stable.
- Inputs do not corrupt state ownership.

**Fail if**
- second touch is ignored in a way that breaks core play
- movement freezes incorrectly
- action input causes a soft-lock

---

### AT-006 — Tap teammate to pass
**Severity:** P0  
**Type:** Functional/Gameplay

**Steps**
1. Start a match.
2. Tap a valid offensive teammate.

**Expected result**
- A straight-line pass is initiated immediately.
- The tapped teammate is the target.
- If the pass succeeds, that teammate catches the ball.
- Human control transfers to the receiver.

**Fail if**
- no pass occurs
- wrong target receives the pass
- control does not transfer after a clean catch

---

### AT-007 — Shot aim entry from ballhandler hold-drag
**Severity:** P0  
**Type:** Functional/Gameplay

**Steps**
1. Press and hold on the current ballhandler.
2. Drag away from the player.

**Expected result**
- The game enters shot aim mode.
- The ballhandler stops moving.
- Time slows to 0.5x.
- Trajectory dots appear.
- Timing color feedback becomes visible.

**Fail if**
- shot aim does not activate
- the player continues moving while aiming
- slow motion does not apply
- no trajectory preview appears

---

### AT-008 — Invalid tiny drag cancels cleanly
**Severity:** P1  
**Type:** Functional/Gameplay

**Steps**
1. Enter shot aim.
2. Release with drag distance below the minimum threshold and not inside any teammate catch radius.

**Expected result**
- The action cancels.
- No shot launches.
- No pass launches.
- Time scale returns to normal.
- The state returns to live offense.

**Fail if**
- a ghost shot or ghost pass occurs
- time remains slowed
- the game becomes stuck

---

### AT-009 — Shot release launches opposite the drag direction
**Severity:** P1  
**Type:** Functional/Math

**Steps**
1. Enter shot aim.
2. Drag clearly down-right from the ballhandler.
3. Release.

**Expected result**
- The launched shot travels generally up-left, consistent with the pull-back rule.
- The outcome is directionally opposite the drag.

**Fail if**
- the ball launches with the drag rather than against it
- direction is inconsistent enough to mislead the player

---

### AT-010 — Trajectory dots track actual shot path
**Severity:** P1  
**Type:** Functional/Physics

**Steps**
1. Enter shot aim.
2. Note the trajectory dots.
3. Release immediately without moving the drag further.
4. Compare the actual path to the preview.

**Expected result**
- The actual shot path closely matches the preview within an agreed tolerance.
- Minor divergence caused by dynamic defender blocks is acceptable.
- The raw projectile shape should not visibly contradict the preview.

**Fail if**
- preview and live shot path differ enough to mislead aiming
- dot arc is clearly using different physics from the actual shot

---

### AT-011 — Shot timing colors update live
**Severity:** P1  
**Type:** Functional/Gameplay

**Steps**
1. Enter shot aim in an open look.
2. Continue holding through the timing window.
3. Observe the line color over time.
4. Repeat with a nearby defender.

**Expected result**
- The preview color updates over time during the hold.
- Green, yellow, and red are all reachable under appropriate timing.
- A nearby defender makes the forgiving window tighter or briefer.

**Fail if**
- the color never changes
- contest proximity has no effect
- colors do not correspond to current release quality

---

### AT-012 — 2-point basket scoring
**Severity:** P0  
**Type:** Functional/Scoring

**Steps**
1. Release a shot from inside the 3-point line.
2. Ensure it scores.

**Expected result**
- Exactly 2 points are awarded to HOM.
- Score changes only once.

**Fail if**
- score adds the wrong value
- the basket counts twice
- no score change occurs despite a valid make

---

### AT-013 — 3-point basket scoring
**Severity:** P0  
**Type:** Functional/Scoring

**Steps**
1. Release a shot from outside the 3-point line.
2. Ensure it scores.

**Expected result**
- Exactly 3 points are awarded to HOM.
- Score changes only once.

**Fail if**
- wrong point value is awarded
- the shot is misclassified
- the score increments multiple times

---

### AT-014 — Rim and backboard collisions
**Severity:** P1  
**Type:** Functional/Physics

**Steps**
1. Launch multiple shots aimed to hit the rim and backboard.
2. Observe collision responses.

**Expected result**
- The ball can visibly collide with the rim.
- The ball can visibly collide with the backboard.
- Collisions produce believable, readable bounce responses.
- The game remains stable after repeated collisions.

**Fail if**
- the ball tunnels through the rim/backboard
- collisions are absent or catastrophically unstable
- repeated impacts break scoring or state flow

---

### AT-015 — Missed shot enters rebound mode
**Severity:** P0  
**Type:** Functional/Gameplay

**Steps**
1. Miss a shot that remains live.
2. Observe the next state.

**Expected result**
- The game enters rebound mode.
- Nearby players stop ordinary route-running and pursue the rebound area.

**Fail if**
- the ball misses and possession immediately disappears with no rebound logic
- players continue route-running as if the miss never happened
- the ball becomes unrecoverable

---

### AT-016 — Offensive rebound continues possession
**Severity:** P0  
**Type:** Functional/Gameplay

**Steps**
1. Force or script a missed shot.
2. Ensure the offense wins the rebound.

**Expected result**
- The offense regains the ball live.
- Human control transfers to the rebounder.
- The possession continues without an opponent sim or hard full-possession reset.

**Fail if**
- offense rebounds but play cuts to opponent sim anyway
- no player gains control
- the game state becomes inconsistent

---

### AT-017 — Defensive rebound triggers opponent sim
**Severity:** P0  
**Type:** Functional/Gameplay

**Steps**
1. Force or script a missed shot.
2. Ensure the defense wins the rebound.

**Expected result**
- Live play ends.
- Opponent possession sim runs.
- The clock is reduced appropriately.
- Score may change based on sim outcome.
- A new human possession resets cleanly.

**Fail if**
- defense rebounds but the game stays stuck in rebound mode
- no sim occurs
- the clock does not update
- reset fails

---

### AT-018 — Pass interception on risky lane
**Severity:** P0  
**Type:** Functional/Gameplay

**Steps**
1. Attempt a long or lane-obstructed pass through a defender.
2. Repeat under deterministic test conditions if needed.

**Expected result**
- The defender can intercept the pass.
- Possession changes.
- `STEAL!` appears.
- Opponent sim follows.

**Fail if**
- risky passes are never interceptable
- the ball passes through defenders unrealistically every time
- turnover feedback or state transition is missing

---

### AT-019 — Stationary pressure turnover
**Severity:** P1  
**Type:** Functional/Gameplay

**Steps**
1. Keep the ballhandler mostly stationary while the on-ball defender remains within the pressure radius.
2. Wait beyond the configured threshold.

**Expected result**
- A turnover/steal chance resolves.
- A turnover can occur under the intended conditions.
- The event is logged.
- Possession transitions to opponent sim if the turnover occurs.

**Fail if**
- the system never checks stationary pressure
- standing still forever is always safe under close pressure
- turnover occurs without logs or coherent transition

---

### AT-020 — Out-of-bounds turnover
**Severity:** P1  
**Type:** Functional/Gameplay

**Steps**
1. Move the ballhandler out of bounds.
2. Separately, send a pass out of bounds.

**Expected result**
- Each event is treated as a turnover.
- Opponent sim runs.
- The game resets to a new human possession afterward.

**Fail if**
- out-of-bounds is ignored
- the game soft-locks
- reset does not occur

---

### AT-021 — Offensive route packages run continuously
**Severity:** P1  
**Type:** Functional/AI

**Steps**
1. Start a possession and allow play to continue without shooting.
2. Observe off-ball teammates for an extended interval.
3. Trigger different route packages if selectable or wait for system cycling.

**Expected result**
- Off-ball teammates continuously move through simple route logic.
- At least three distinct route package behaviors exist.
- Players preserve spacing and avoid excessive crowding.

**Fail if**
- teammates mostly stand still
- only one route pattern exists
- players stack on top of each other repeatedly outside rebound situations

---

### AT-022 — Man-to-man defenders stay assigned
**Severity:** P1  
**Type:** Functional/AI

**Steps**
1. Start a live possession.
2. Move the ball and observe defenders across passes and route motion.

**Expected result**
- Each defender remains assigned to one offensive player for the possession.
- Defenders follow and contest their own matchup.
- No unintended switching occurs in normal play.

**Fail if**
- defenders abandon assignments without reason
- frequent accidental switching occurs
- guard logic becomes chaotic or detached

---

### AT-023 — Shot contest and block behavior
**Severity:** P1  
**Type:** Functional/AI/Gameplay

**Steps**
1. Take an open shot.
2. Take a closely contested shot.
3. Attempt a shot near a defender with possible block opportunity.

**Expected result**
- Contested shots have a tighter or harsher timing window than open shots.
- Defenders can affect the shot by contesting.
- Under valid conditions, a defender can block or significantly disrupt a shot.

**Fail if**
- open and contested shots behave identically
- defenders never influence shot quality
- block-capable situations never resolve as blocks or disruptions

---

### AT-024 — Opponent sim produces legal outcomes and logs
**Severity:** P0  
**Type:** Functional/Simulation

**Steps**
1. Trigger opponent sim from a made shot, defensive rebound, or turnover.
2. Observe logs and resulting score/time changes.

**Expected result**
- The sim consumes a plausible amount of time.
- The sim can produce only legal outcomes for v1:
  - 2 points
  - 3 points
  - miss
  - turnover
  - offensive rebound
  - second-chance points
- Logs show what happened in readable form.
- Control returns to a new human offensive possession if time remains.

**Fail if**
- the sim changes score silently
- the sim produces illegal events like free throws
- no logs exist
- the sim does not reduce time
- the game fails to return to offense

---

### AT-025 — Pause/resume integrity
**Severity:** P0  
**Type:** Functional/System

**Steps**
1. Pause during live offense.
2. Resume.
3. Pause during shot aim if supported in that state.
4. Resume again.

**Expected result**
- Clock stops completely while paused.
- Gameplay stops while paused.
- Resume returns to the correct prior state.
- Time scale is correct after resume.

**Fail if**
- the clock continues during pause
- physics or AI continue during pause
- resume returns to the wrong state
- slow motion state breaks after unpausing

---

### AT-026 — Game end at zero
**Severity:** P0  
**Type:** Functional/System

**Steps**
1. Allow the timer to reach 0:00.
2. Also test a shot released just before 0:00.

**Expected result**
- The game ends cleanly.
- If a shot is already in flight at the buzzer, it is allowed to resolve along with any immediate rebound resolution.
- Then the final score screen appears.
- Restart is offered.

**Fail if**
- the match never ends
- the buzzer cancels an in-flight ball incorrectly
- the final score screen fails to appear
- the game becomes stuck between live play and game-over

---

### AT-027 — Restart resets cleanly
**Severity:** P0  
**Type:** Functional/System

**Steps**
1. Finish a game or pause mid-game.
2. Press Restart Match.

**Expected result**
- A fresh match starts.
- Scores reset.
- Timer resets to 3:00.
- Players reset to the correct opening formation.
- No old state leaks into the new session.

**Fail if**
- any previous score, state, or ownership leaks through
- the timer remains wrong
- duplicate entities remain
- restart causes a soft-lock

---

### AT-028 — Required logs written
**Severity:** P1  
**Type:** Functional/Diagnostics

**Steps**
1. Play through a short scripted or manual session with passes, at least one shot, at least one state transition, and at least one opponent sim.
2. Inspect `user://logs/`.

**Expected result**
- Logs are written successfully.
- They include at least state transitions, shots, passes, scoring, and sim events.
- Logs are readable enough to support debugging.

**Fail if**
- no logs are produced
- logs are empty or corrupted
- major event classes are missing

---

## Release-blocking deterministic scenario tests

These scenario tests must exist in the automated suite and must pass in seeded mode.

### SCN-001 — Clean pass-and-shoot make
**Severity:** P0

**Setup**
- default possession reset formation
- neutral score
- fixed seed
- open right wing target

**Script**
1. PG dribbles slightly right.
2. PG taps right wing.
3. Right wing catches and becomes controlled.
4. Right wing enters shot aim in low contest conditions.
5. Release occurs during green timing.
6. Shot follows predicted arc and scores.
7. Opponent sim runs.
8. New offense possession resets.

**Assertions**
- pass target was correct
- control transferred to right wing
- preview roughly matched live flight
- score increased by 2 or 3 as appropriate
- sim consumed time
- reset returned to live offense

---

### SCN-002 — Contested miss with defensive rebound
**Severity:** P0

**Setup**
- default formation
- fixed seed
- defender inside contest radius

**Script**
1. PG dribbles into tighter coverage.
2. PG enters shot aim.
3. Release occurs at poor timing.
4. Shot misses after believable collision.
5. Rebound mode activates.
6. Defense wins rebound.
7. Opponent sim runs.
8. New offense possession resets.

**Assertions**
- contested timing window is tighter than open window
- shot misses legally
- rebound mode activates
- defense can secure rebound
- sim runs and logs outcome
- game returns to live offense

---

### SCN-003 — Bad cross-court pass steal
**Severity:** P0

**Setup**
- default formation
- fixed seed
- pass lane intentionally covered

**Script**
1. PG attempts a long diagonal pass to the opposite corner.
2. Defender intercepts.
3. `STEAL!` text appears.
4. Opponent sim runs.
5. New offense possession resets.

**Assertions**
- interception is credited to defense
- steal feedback is shown
- possession state changes correctly
- sim consumes time
- reset succeeds

---

### SCN-004 — Stationary pressure turnover
**Severity:** P1

**Setup**
- ballhandler and on-ball defender placed within pressure radius
- fixed seed allowing turnover

**Script**
1. Ballhandler remains stationary beyond the threshold.
2. Pressure turnover roll resolves.

**Assertions**
- turnover can occur
- turnover is logged
- possession transitions coherently to opponent sim

---

### SCN-005 — Out-of-bounds turnover
**Severity:** P1

**Setup**
- default possession
- fixed seed

**Script**
1. Ballhandler crosses court boundary.
2. Separate run: a pass is thrown out of bounds.

**Assertions**
- both are treated as turnovers
- both lead to opponent sim
- both reset correctly afterward

---

### SCN-006 — Offensive rebound continuation
**Severity:** P0

**Setup**
- fixed seed
- missed shot arranged with favorable offensive rebound conditions

**Script**
1. Live shot misses.
2. Rebound mode activates.
3. Offense wins rebound.

**Assertions**
- no opponent sim occurs immediately
- control transfers to rebounder
- possession continues live
- score remains unchanged unless a later legal shot scores

---

### SCN-007 — Buzzer shot completion
**Severity:** P1

**Setup**
- clock nearly at 0:00
- live shot opportunity

**Script**
1. Shot is released just before expiration.
2. The ball remains in flight as the timer reaches zero.

**Assertions**
- in-flight shot resolves legally
- any immediate rebound resolution completes
- only after that does the game enter game over
- final score is correct

---

### SCN-008 — Pause/resume state safety
**Severity:** P1

**Setup**
- deterministic seed
- test both live offense and shot aim

**Script**
1. Pause.
2. Wait in paused state.
3. Resume.

**Assertions**
- no hidden clock progression occurs while paused
- previous gameplay state restores cleanly
- time scale is correct after resuming

---

### SCN-009 — Long-run stability
**Severity:** P0

**Setup**
- deterministic batch of many possessions or a whole match loop
- automated bot pilot

**Script**
1. Run repeated possessions including passes, shots, rebounds, sims, steals, and restarts.
2. Optionally run multiple seeded matches.

**Assertions**
- no soft-lock
- no duplicate score counting
- no missing controlled player
- no unrecoverable state transition
- no runaway timer error
- no hard crash

---

## Release-blocking pure logic tests

The following logic checks must exist and pass.  
These do not all need separate files, but they must be covered.

### Input and control
- joystick deadzone behavior
- joystick normalization/clamping
- correct player ownership transfer on pass catch
- shot aim entered only from the current ballhandler
- tap-on-teammate pass selection
- release-endpoint pass conversion
- invalid drag cancel behavior

### Shot and preview math
- drag vector to launch vector inversion
- drag distance to power mapping
- green/yellow/red timing classification
- defender proximity shrinks timing forgiveness
- release consistency widens or stabilizes forgiveness
- launch error injection modifies initial conditions
- trajectory preview approximates actual simulator path within tolerance

### Hoop and scoring
- rim collision response
- backboard collision response
- made-basket detection on descending ball only
- one-score-per-shot lockout
- 2pt/3pt classification from release position

### Gameplay logic
- out-of-bounds detection
- pass interception feasibility
- defender assignment persistence
- route package progression
- spacing reduces overlap/crowding
- contested shot detection
- block opportunity detection
- rebound candidate ranking
- rebound winner selection
- stationary pressure turnover checks

### System logic
- opponent sim legal outcome tree
- second-chance sim handling
- opponent sim time consumption
- pause halts time
- game-over trigger
- restart state reset
- log writing path and file creation

---

## Balance and sanity tests

Balance is not judged against real basketball statistics.  
It is judged against arcade readability and fairness.

Run batch tests in deterministic mode and log results.

### BAL-001 — Open green shots are meaningfully rewarded
**Severity:** P1

**Method**
- Run repeated uncontested, inside-arc green releases with an average shooter.

**Pass if**
- make rate falls in a broad fun arcade band, roughly 60%–80%

**Fail if**
- green releases barely matter
- open green shots almost always miss
- green shots are nearly automatic regardless of ratings

---

### BAL-002 — Yellow and red are meaningfully worse than green
**Severity:** P1

**Method**
- Compare open green, yellow, and red releases across repeated trials.

**Pass if**
- green > yellow > red in make rate
- bands are meaningfully separated

**Suggested broad sanity bands**
- yellow roughly 35%–60%
- red roughly 5%–25%

**Fail if**
- timing color has little practical effect
- red releases succeed too often relative to green

---

### BAL-003 — Contest matters
**Severity:** P1

**Method**
- Compare open vs contested attempts with similar shooter ratings and release quality.

**Pass if**
- contested shots are less forgiving and less successful than open shots
- blocks or strong disruptions occur under valid conditions

**Fail if**
- contest has negligible gameplay effect

---

### BAL-004 — Safe passes are safer than risky cross-court passes
**Severity:** P1

**Method**
- Compare short, unobstructed passes against long lane-covered passes.

**Pass if**
- short safe passes have a low interception rate
- risky long passes have a noticeably higher interception rate

**Fail if**
- the rates are reversed
- no real risk distinction exists

---

### BAL-005 — Rebounds occur in a believable arcade band
**Severity:** P1

**Method**
- Run repeated missed-shot scenarios.

**Pass if**
- offensive rebounds happen sometimes but not almost always
- defensive rebounds happen often enough to move the game forward
- outcomes vary by position and ratings

**Fail if**
- one side almost always gets every rebound
- rebounds nearly never occur
- rebound selection ignores obvious positional/rating factors

---

### BAL-006 — Opponent sim difficulty separation
**Severity:** P1

**Method**
- Run repeated sim-only possessions or whole seeded matches on Easy, Normal, Hard.

**Pass if**
- Easy < Normal < Hard in overall opponent pressure/efficiency
- Normal remains beatable
- Hard feels tougher without feeling blatantly unfair

**Fail if**
- all difficulties feel identical
- Normal is effectively unwinnable
- Easy and Hard do not meaningfully diverge

---

## Manual smoke checklist

These manual checks must pass before calling the build demo-ready.

1. Launch the project.
2. See a readable start screen.
3. Press Start Game and enter a match.
4. Confirm portrait layout readability.
5. Confirm HOM score, timer + pause, and AWY score are visible.
6. Move the ballhandler in all directions with the joystick.
7. Pass to multiple teammates.
8. Verify control changes to the receiver.
9. Enter shot aim from the ballhandler.
10. Verify time slows.
11. Verify the player cannot move while aiming.
12. Verify trajectory dots appear.
13. Watch line color change over hold time.
14. Make an inside shot and confirm +2.
15. Make an outside shot and confirm +3.
16. Miss a shot and confirm live rebound mode.
17. Get an offensive rebound and confirm the possession continues.
18. Lose a defensive rebound and confirm opponent sim runs.
19. Force or observe a pass interception and confirm `STEAL!`.
20. Force out-of-bounds and confirm turnover.
21. Pause and resume.
22. Reach 0:00 and confirm clean game over.
23. Restart and confirm the full reset.
24. Inspect logs and confirm useful events were written.
25. Play another full game and confirm no obvious degradation or lingering state corruption.

---

## Exit condition

The project is accepted only when:

- every P0 test passes
- every P1 acceptance test in this document passes
- the long-run stability scenario passes
- the manual smoke checklist passes
- known remaining issues are only P2 or lower
- the build is playable, understandable, and stable enough for a class demo

If any release-blocking test fails, the build is not done.
