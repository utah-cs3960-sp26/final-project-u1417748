# Gameplay Spec

## Match Loop

1. Boot directly into a 3:00 offense-only match.
2. Control the offensive ballhandler.
3. Use one-thumb movement, tap passing, and an upward swipe-to-arm shot timing flow to create a shot.
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

- During `LIVE_OFFENSE`, one eligible off-ball teammate is marked as the default pass target with a persistent light-blue ring.
- An empty quick tap on the gameplay surface passes immediately to that marked teammate.
- A quick tap directly on a teammate passes immediately to that teammate, even if they are not the marked default target.
- Lower-zone touches still count as pass taps if they stay inside the tap time and excursion limits instead of becoming a real drag.
- If no valid default target exists, an empty tap does nothing and live offense continues.
- A pass starts as an immediate straight-line live-ball pass to the chosen teammate.
- The ball stays visible during `PASS_IN_FLIGHT` and travels on a fixed straight segment toward the receiver's release-time catch point.
- The intended receiver breaks to that catch point while one eligible defender may commit to the lane based on pass geometry, ratings, and difficulty.
- Only a committed defender gets the visible lane-cut override. If no defender commits, the pass resolves only as a catch or out-of-bounds turnover.
- The first player to bring the live ball inside their claim radius wins the pass. If the receiver and defender arrive on the same frame, the offense keeps the ball.
- A successful catch transfers control to the receiver.
- Defenders can intercept long or cross-court lanes.
- A completed steal enters a short `STEAL_RESOLVE` beat so the defender visibly secures the ball before the opponent sim jump-cut.
- Out-of-bounds passes become turnovers.

### Shooting

- A strong upward swipe that finishes in the top half of the screen enters `SHOT_AIM`.
- Shot-swipe recognition applies everywhere on the gameplay surface, including the lower movement zone.
- Lower-zone drags still move the ballhandler while the finger is down, but a qualifying upward swipe into the top half on release arms the shot instead of resolving as a normal movement release.
- Upward swipes that stay in the lower half, downward swipes, short drags, and clearly horizontal drags do not arm a shot.
- `SHOT_AIM` is an armed timing phase, not a hold-and-drag phase.
- Gameplay stays at normal speed while the shot is armed.
- The ballhandler stops moving once shot mode is armed.
- The committed shot row starts immediately when shot mode is armed.
- If the committed family is a dunk, the game skips timed `SHOT_AIM` entirely for the current phase, never shows the shot bar, and immediately queues a guaranteed make while still waiting for the authored dunk contact and release beats.
- For non-dunk shots, a bottom timing meter appears as a long red rectangle with a smaller green rectangle inside it.
- For non-dunk shots, trajectory dots appear during shot mode and preview the current release path.
- For non-dunk shots, a rectangular indicator sweeps across the bar once from left to right.
- For non-dunk shots, the first tap anywhere on screen samples the current timing result.
- Shot entry only comes from the upward swipe path; downward swipes are ignored for shooting.
- For non-dunk shots, tapping inside the green window guarantees a made shot, even if the shooter is contested, and the release cannot be downgraded into a block.
- For non-dunk shots, tapping in the red causes a miss or a contest-driven block.
- For non-dunk shots, if the player never taps before the bar ends, the shot counts as a late miss.
- For non-dunk shots, green preview dots show the make path and red preview dots show the deterministic miss path tied to the current aim.
- Live shots launch from an above-floor release height and use a deliberately exaggerated cinematic arc with longer hang time.
- Green makes use a staged guided-make profile: free-flight approach into a legal front-half rim-plane handoff, then an immediate simulator-owned downward descent through the cylinder and net.
- The terminal green-make path also applies a render-only screen drop of about 60px so the last approach and descent read lower on screen without changing the solver, the score gate, or hoop geometry.
- Made shots stay on screen briefly so the ball can fully finish through the hoop before the game transitions.
- The score visual follows explicit hoop depth phases: normal makes appear in front of the backboard, may show at most a transient rim-plane handoff frame, then pass behind the hanging net body before emerging below it.
- Score resolution for a green make happens during the simulator-owned `guided_descent` phase, not from an arbitrary pre-score free-flight crossing and not from a render-only rescue path.
- After timing is locked, launch still waits for the committed animation row to cross its authored release frame before the world ball appears.
- Close-finish family selection is deterministic and ignores defender distance. A player only enters the layup-or-dunk family when the approach is inside `close_finish_radius`, moving toward the hoop above `toward_hoop_dot_threshold`, and carrying at least `finish_momentum_speed_threshold`.
- Once that close-finish gate is met, dunks require the stricter dunk-only gates: inside `dunk_finish_radius`, at or above `dunk_momentum_speed_threshold`, and at or above `dunk_rating_min`. If any dunk-only gate fails, the finish falls back to layup instead of spilling into a jumper.
- The pause menu also exposes a debug `No Defenders` toggle. While it is active, live defenders are hidden and removed from on-court defensive logic, and any shot started inside `close_finish_radius` commits to a dunk family even for low-dunk or stationary players.
- Straight-vs-side finish routing still happens after the family choice, using the same lateral offset threshold for layups and dunks.
- Dunk rows `13`, `15`, and `16` add a second staged beat after the dunk auto-commit: once the committed animation reaches its configured rim-contact frame, the sprite freezes on the rim for `0.5` seconds with the world ball still hidden.
- On those dunk rows, made finishes release straight down through the hoop and net from the rim-contact point instead of using a normal shot arc.
- In the current phase, live gameplay always auto-commits eligible dunks as makes, so the upward-and-away dunk miss path is retained only as an internal fallback/test profile.

## Scoring

- The hoop is fixed at top center.
- The live hoop, rim, backboard, and pole now sit farther back above the court, with the rim anchored at `Vector2(540, -50)` and the backboard plane at `y = -120`.
- The 3PT check is determined from shooter position at release.
- The 3PT radius is widened to `840` so the painted floor arc still matches scoring after the hoop anchor moved behind the court.
- A score only counts when the simulated ball is descending and crosses the scoring plane once.
- Green makes no longer rely on a widened forced-score loophole. They must still enter the front-half score corridor; the shot solver is responsible for producing that path.
- Rim and backboard collisions stay live.
- Rendering around the hoop is phase-aware so the ball can sit in the correct depth band against the rear hoop, front rim lip, and front net body instead of relying on one generic depth sort.

## Presentation

- The court renders as a flat top-down rectangle with parallel sidelines.
- The floor art keeps its original aspect ratio, scales to fill the full screen height, and crops extra width with an offensive-side bias instead of stretching.
- During `LIVE_OFFENSE`, the best pass target shows a persistent light-blue floor ring until a pass or shot begins.
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
- defender pressure only affects the resolved outcome after a shot family is committed; it does not change the layup-vs-dunk chooser near the rim

## Ratings

- Players now carry an explicit `dunk` rating on the same `0-100` scale as the other roster stats.
- `dunk` only affects two systems: whether a close finish qualifies for a dunk instead of a layup, and how much block resistance a committed dunk receives.
- `dunk` does not change meter timing, make probability outside the existing timing system, or layup and jumper behavior.

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
