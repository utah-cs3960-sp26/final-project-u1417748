# Gameplay Spec

## Match Loop

1. Boot directly into a 3:00 offense-only match.
2. Control the offensive ballhandler.
3. Use the visible bottom-third control panel for movement, passes, shots, and dunks.
4. Resolve score, miss, steal, out-of-bounds, or rebound.
5. If defense gains possession, run the opponent sim, present its visible action beats, then reset to a new offensive possession.
6. Finish the current live shot or rebound at the buzzer, then end the game.

## Controls

### Movement

- The bottom third of the screen is a visible control panel with a shorter top `SHOOT | DUNK` split row and a larger bottom `PASS | MOVE | PASS` row.
- The center `MOVE` lane is intentionally wider than either `PASS` lane so movement has the largest touch target.
- All four visible button zones use a shared dark neutral base color `#1b1d3a` while idle.
- A button swaps into its action color only while a drag is hovering over that zone or while that button is being pressed directly.
- Live-offense gestures must start in the center `MOVE` zone.
- Touch-down in `MOVE` creates the active joystick anchor and knob inside the visible panel.
- Tapping `PASS`, `SHOOT`, or `DUNK` directly works even if no movement gesture is active.
- While one finger is dragging in `MOVE`, a second finger can still tap any action button directly.
- Movement direction is the vector from the `MOVE` anchor to the current thumb position.
- Tiny thumb shifts inside the dead zone do not move the ballhandler.
- Touch input is primary.
- `WASD` / arrow keys mirror the movement vector in debug.

### Passing

- During `LIVE_OFFENSE`, one eligible off-ball teammate is marked as the default pass target with a persistent light-blue ring.
- Tapping either visible `PASS` button passes immediately to that focused teammate.
- Releasing a live gesture into either visible `PASS` lane passes immediately to that focused teammate.
- Both `PASS` lanes route to the same focused receiver. There is no direct teammate tap override in the current control layout.
- If no valid default target exists, both `PASS` lanes are inert and live offense continues.
- A pass starts as an immediate straight-line live-ball pass to the chosen teammate.
- The ball stays visible during `PASS_IN_FLIGHT` and travels on a fixed straight segment toward the receiver's release-time catch point.
- The intended receiver breaks to that catch point while one eligible defender may commit to the lane based on pass geometry, ratings, and difficulty.
- Only a committed defender gets the visible lane-cut override. If no defender commits, the pass resolves only as a catch or out-of-bounds turnover.
- The first player to bring the live ball inside their claim radius wins the pass. If the receiver and defender arrive on the same frame, the offense keeps the ball.
- A successful catch transfers control to the receiver.
- Defenders can intercept long or cross-court lanes.
- A completed steal enters a short `STEAL_RESOLVE` beat so the defender visibly secures the ball before the opponent sim action banner takes over.
- Out-of-bounds passes become turnovers.

### Shooting

- Tapping the top-left `SHOOT` button directly requests the `shot_layout` intent.
- Tapping the top-right `DUNK` button directly requests the `dunk` intent.
- Releasing a live gesture into the top-left `SHOOT` zone requests the `shot_layout` intent.
- Releasing a live gesture into the top-right `DUNK` zone requests the `dunk` intent.
- Releasing back into `MOVE`, outside the panel, or on a drag shorter than the action threshold just stops movement.
- `SHOT_AIM` is an armed timing phase, not a hold-and-drag phase.
- Gameplay stays at normal speed while the shot is armed.
- The ballhandler stops moving once shot mode is armed.
- Drag-release `shot_layout` entries start the committed shot row immediately when shot mode is armed.
- A direct tap on the top-left `SHOOT` button uses an isolated two-tap timing mode: the first tap enters `SHOT_AIM`, shows the timing meter and preview dots, and holds the ballhandler in the aim pose instead of starting the release row.
- In direct `SHOOT` button timing mode, the next tap starts the selected release row and samples the timing result; this includes tapping the `SHOOT` button again. If the bar finishes before that second tap, the shot resolves as a late miss.
- Direct `SHOOT` button timing mode does not change the drag-release shot path, the `DUNK` button path, pass inputs, or movement input.
- `shot_layout` keeps normal jumper / set-shot behavior outside the rim, and forces close finishes to resolve as layups instead of auto-promoting to dunks.
- `dunk` commits a dunk only when the stricter dunk gates pass. If the player is close enough for a finish but not dunk-eligible, the request falls back to a layup. If the player is too far for any finish, the request is ignored and offense stays live.
- If the committed family is a dunk, the game skips timed `SHOT_AIM`, never shows the shot meter, and immediately queues the authored dunk make flow.
- For non-dunk shots, the timing meter renders across the full top `SHOOT | DUNK` row as a long red rectangle with a smaller green rectangle inside it.
- For non-dunk shots, trajectory dots appear during shot mode and preview the current release path.
- For non-dunk shots, a rectangular indicator sweeps across the bar once from left to right.
- For non-dunk shots, the first tap anywhere on screen samples the current timing result.
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
- The pause menu exposes a `Show Controls` toggle that hides or shows the control-panel art without changing the underlying hitboxes or restoring the legacy gesture model.
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
- Rendering around the hoop is phase-aware so the ball sits in front of `NetClean`, always behind `NetBody`, and behind `NetCleanBottomHalf` only while it is actively traveling through the net.

## Presentation

- The court renders as a flat top-down rectangle with parallel sidelines.
- The floor art keeps its original aspect ratio, scales to fill the full screen height, and crops extra width with an offensive-side bias instead of stretching.
- The opposite-side bottom hoop is always visible at the bottom of the court using the normalized back-of-hoop art, rendered at `2.0x` the base hoop projection scale and layered in front of gameplay/presentation sprites so players and balls pass behind it.
- The live top hoop uses four registered net layers, `Net`, `NetClean`, `NetCleanBottomHalf`, and `NetBody`, all aligned on the same 30x28 transparent canvas. `NetCleanBottomHalf` is a phase-gated lower mask: inactive below normal airborne/rim-approach balls, active above the ball during `net_channel` and the made-shot net-exit follow-through.
- The textured scoreboard sits in a compact bottom-left card just above the `SHOOT` half of the control panel instead of occupying the top edge of the screen.
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
- presents `1..4` short action beats before the possession resolves on screen
- each action beat appears in a centered horizontal black banner at `80%` opacity
- each action beat also jump-cuts a static bottom-half court tableau around the opposite-side hoop
- the tableau layer shows five AWY ghost players, five passive HOM defender ghosts, and a ghost ball, separate from live gameplay entities
- live players and the live ball are hidden during `OPPONENT_SIM`, then restored when the next human offense begins
- all opponent-sim tableau positions stay in the bottom half of the court; setup actions use guard, wing, and corner spacing, while finishes place the actor near the bottom lane and rim
- movement between opponent actions is not animated; each beat deliberately snaps to the next static formation while lightweight in-place sprite frames may continue
- during `OPPONENT_SIM`, camera tracking snaps to the current presentation actor or tableau center so each jump cut is immediately readable
- the live scoreboard card and bottom control panel are hidden while opponent action text is visible
- each action beat auto-advances after `1.0` second, and a screen press during `OPPONENT_SIM` advances to the next beat immediately
- the final visible action is the outcome beat and must match the resolved score result
- scoring outcome beats include short basketball descriptions such as `Jump shot from {player}`, `Corner three from {player}`, `Layup from {player}`, `Alley-oop from {player}`, `Dunk from {player}`, `Putback from {player}`, and `Breakaway layup from {player}`
- no-score outcome beats include short descriptions such as `Turnover from {player}`, `Steal from {player}`, `Missed jumper from {player}`, `Blocked shot from {player}`, and `Defensive board by HOM`
- setup beats may include actions such as `Pass to {player}`, `Drive by {player}`, `Crossover from {player}`, `Kickout to {player}`, and `Pick-and-roll to {player}`
- score and clock changes apply only after the final action beat completes or is skipped
- the scoreboard and controls reappear only after the game resets into `LIVE_OFFENSE` with a human ballhandler
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
