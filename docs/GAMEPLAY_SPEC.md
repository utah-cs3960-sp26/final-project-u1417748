# Gameplay Spec

## Match Loop

1. Boot directly into a 3:00 offense-only match.
2. Control the offensive ballhandler.
3. Use one-thumb movement, release-to-pass control, and tap-to-arm shot timing to create a shot.
4. Resolve score, miss, steal, out-of-bounds, or rebound.
5. If defense gains possession, run the opponent sim and reset to a new offensive possession.
6. Finish the current live shot or rebound at the buzzer, then end the game.

## Controls

### Movement

- The lower `35%` of the screen is an invisible movement zone.
- Touch-down in that zone creates a faint temporary anchor under the thumb.
- Movement direction is the vector from the anchor to the current thumb position.
- Tiny thumb shifts inside the dead zone do not move the ballhandler.
- Touch input is primary.
- `WASD` / arrow keys mirror the movement vector in debug.

### Passing

- While the thumb is moving, the game previews the best eligible teammate inside a directional cone around the current gesture vector.
- The preview fills the ring under the locked teammate before lift-off.
- Releasing becomes a pass only when the release is outside the movement dead zone and a teammate is currently preview-locked.
- Releasing back near the anchor center does nothing except stop movement.
- Releasing off-center without a locked target also does nothing except stop movement.
- A pass starts as an immediate straight-line live-ball pass to the locked teammate.
- The ball stays visible during `PASS_IN_FLIGHT` and travels on a fixed straight segment toward the receiver's release-time catch point.
- The intended receiver breaks to that catch point while one eligible defender may commit to the lane based on pass geometry, ratings, and difficulty.
- Only a committed defender gets the visible lane-cut override. If no defender commits, the pass resolves only as a catch or out-of-bounds turnover.
- The first player to bring the live ball inside their claim radius wins the pass. If the receiver and defender arrive on the same frame, the offense keeps the ball.
- A successful catch transfers control to the receiver.
- Defenders can intercept long or cross-court lanes.
- A completed steal enters a short `STEAL_RESOLVE` beat so the defender visibly secures the ball before the opponent sim jump-cut.
- Out-of-bounds passes become turnovers.

### Shooting

- A quick tap-release on the gameplay surface enters `SHOT_AIM`.
- Lower-zone taps only arm a shot if they never become a real drag and stay inside the tap time and excursion limits.
- `SHOT_AIM` is an armed timing phase, not a hold-and-drag phase.
- Gameplay stays at normal speed while the shot is armed.
- The ballhandler stops moving once shot mode is armed.
- The committed shot row starts immediately when shot mode is armed.
- A bottom timing meter appears as a long red rectangle with a smaller green rectangle inside it.
- Trajectory dots appear during shot mode and preview the current release path.
- A rectangular indicator sweeps across the bar once from left to right.
- The first tap anywhere on screen samples the current timing result.
- Releasing an actual drag back near the anchor center does not arm a shot.
- Tapping inside the green window guarantees a made shot, even if the shooter is contested, and the release cannot be downgraded into a block.
- Tapping in the red causes a miss or a contest-driven block.
- If the player never taps before the bar ends, the shot counts as a late miss.
- Green preview dots show the make path; red preview dots show the deterministic miss path tied to the current aim.
- Live shots launch from an above-floor release height and use a deliberately exaggerated cinematic arc with longer hang time.
- Green makes use a staged guided-make profile: free-flight approach into a legal front-half rim-plane handoff, then an immediate simulator-owned downward descent through the cylinder and net.
- The terminal green-make path also applies a render-only screen drop of about 60px so the last approach and descent read lower on screen without changing the solver, the score gate, or hoop geometry.
- Made shots stay on screen briefly so the ball can fully finish through the hoop before the game transitions.
- The score visual follows explicit hoop depth phases: normal makes appear in front of the backboard, may show at most a transient rim-plane handoff frame, then pass behind the hanging net body before emerging below it.
- Score resolution for a green make happens during the simulator-owned `guided_descent` phase, not from an arbitrary pre-score free-flight crossing and not from a render-only rescue path.
- After timing is locked, launch still waits for the committed animation row to cross its authored release frame before the world ball appears.

## Scoring

- The hoop is fixed at top center.
- The 3PT check is determined from shooter position at release.
- A score only counts when the simulated ball is descending and crosses the scoring plane once.
- Green makes no longer rely on a widened forced-score loophole. They must still enter the front-half score corridor; the shot solver is responsible for producing that path.
- Rim and backboard collisions stay live.
- Rendering around the hoop is phase-aware so the ball can sit in the correct depth band against the rear hoop, front rim lip, and front net body instead of relying on one generic depth sort.

## Presentation

- The court renders as a flat top-down rectangle with parallel sidelines.
- The floor art keeps its original aspect ratio, scales to fill the full screen height, and crops extra width with an offensive-side bias instead of stretching.
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
