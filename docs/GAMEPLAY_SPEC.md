# Gameplay Spec

## Match Loop

1. Boot directly into a 3:00 offense-only match.
2. Control the offensive ballhandler.
3. Use movement, passing, and shot aim to create a shot.
4. Resolve score, miss, steal, out-of-bounds, or rebound.
5. If defense gains possession, run the opponent sim and reset to a new offensive possession.
6. Finish the current live shot or rebound at the buzzer, then end the game.

## Controls

### Movement

- The joystick sits in the lower third.
- Touch input is primary.
- `WASD` / arrow keys mirror the joystick in debug.

### Passing

- Tapping a teammate starts an immediate straight-line pass.
- The ball stays visible during `PASS_IN_FLIGHT` and travels on a fixed straight segment toward the receiver's release-time catch point.
- The intended receiver breaks to that catch point while one eligible defender may commit to the lane based on pass geometry, ratings, and difficulty.
- Only a committed defender gets the visible lane-cut override. If no defender commits, the pass resolves only as a catch or out-of-bounds turnover.
- The first player to bring the live ball inside their claim radius wins the pass. If the receiver and defender arrive on the same frame, the offense keeps the ball.
- A successful catch transfers control to the receiver.
- Defenders can intercept long or cross-court lanes.
- A completed steal enters a short `STEAL_RESOLVE` beat so the defender visibly secures the ball before the opponent sim jump-cut.
- Out-of-bounds passes become turnovers.

### Shooting

- Holding on the ballhandler enters `SHOT_AIM`.
- Gameplay time scales to `0.5x`.
- The ballhandler stops moving while aiming.
- A bottom timing meter appears as a long red rectangle with a smaller green rectangle inside it.
- Trajectory dots appear during aim and preview the current release path.
- A rectangular indicator sweeps across the bar continuously while the player holds.
- Releasing inside the green window guarantees a made shot, even if the shooter is contested, and the release cannot be downgraded into a block.
- Releasing in the red causes a miss or a contest-driven block.
- Green preview dots show the make path; red preview dots show the deterministic miss path tied to the current aim.
- Live shots launch from an above-floor release height and use a deliberately exaggerated cinematic arc with longer hang time.
- Green makes use a staged guided-make profile: free-flight approach into a legal front-half rim-plane handoff, then an immediate simulator-owned downward descent through the cylinder and net.
- The terminal green-make path also applies a render-only screen drop of about 60px so the last approach and descent read lower on screen without changing the solver, the score gate, or hoop geometry.
- Made shots stay on screen briefly so the ball can fully finish through the hoop before the game transitions.
- The score visual follows explicit hoop depth phases: normal makes appear in front of the backboard, may show at most a transient rim-plane handoff frame, then pass behind the hanging net body before emerging below it.
- Score resolution for a green make happens during the simulator-owned `guided_descent` phase, not from an arbitrary pre-score free-flight crossing and not from a render-only rescue path.

## Scoring

- The hoop is fixed at top center.
- The 3PT check is determined from shooter position at release.
- A score only counts when the simulated ball is descending and crosses the scoring plane once.
- Green makes no longer rely on a widened forced-score loophole. They must still enter the front-half score corridor; the shot solver is responsible for producing that path.
- Rim and backboard collisions stay live.
- Rendering around the hoop is phase-aware so the ball can sit in the correct depth band against the rear hoop, front rim lip, and front net body instead of relying on one generic depth sort.

## Presentation

- The court renders as a flat top-down rectangle with parallel sidelines.
- Player sprites are intentionally enlarged so the ballhandler and nearby defenders are easy to read in portrait play.

## Rebounds

- Misses enter `REBOUND_LIVE`.
- Normal route running pauses.
- Offense and defense chase the rebound zone.
- Offensive rebounds continue live offense.
- Defensive rebounds trigger opponent sim and a possession reset.

## AI

### Offense

Exactly three route packages run continuously:

- wing swap
- strong-side slash
- weak-side fill

Spacing nudges keep off-ball players from collapsing on the ballhandler.

### Defense

- pure man-to-man
- assignments locked for the possession
- contests, blocks, pressure turnovers, interceptions, and rebounds supported

## Opponent Sim

- consumes plausible clock
- uses player ratings and difficulty multipliers
- can produce turnover, miss, 2PT, 3PT, offensive rebound, and second-chance points
- logs each possession sequence to `user://logs/`

## State Machine

Global states:

- `BOOT`
- `MATCH_SETUP`
- `LIVE_OFFENSE`
- `PASS_IN_FLIGHT`
- `STEAL_RESOLVE`
- `SHOT_AIM`
- `SHOT_IN_FLIGHT`
- `REBOUND_LIVE`
- `OPPONENT_SIM`
- `PAUSED`
- `GAME_OVER`

Only `GameCoordinator.change_state()` is allowed to mutate the global match state.
