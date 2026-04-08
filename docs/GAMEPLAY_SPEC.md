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
- A successful catch transfers control to the receiver.
- Defenders can intercept long or cross-court lanes.
- Out-of-bounds passes become turnovers.

### Shooting

- Holding on the ballhandler enters `SHOT_AIM`.
- Gameplay time scales to `0.5x`.
- The ballhandler stops moving while aiming.
- A bottom timing meter appears as a long red rectangle with a smaller green rectangle inside it.
- A rectangular indicator sweeps across the bar continuously while the player holds.
- Releasing inside the green window guarantees a made shot, even if the shooter is contested, and the release cannot be downgraded into a block.
- Releasing in the red causes a miss or a contest-driven block.
- Made shots stay on screen briefly so the ball can finish through the hoop before the game transitions.

## Scoring

- The hoop is fixed at top center.
- The 3PT check is determined from shooter position at release.
- A score only counts when the simulated ball is descending and crosses the scoring plane once.
- Rim and backboard collisions stay live.

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
- `SHOT_AIM`
- `SHOT_IN_FLIGHT`
- `REBOUND_LIVE`
- `OPPONENT_SIM`
- `PAUSED`
- `GAME_OVER`

Only `GameCoordinator.change_state()` is allowed to mutate the global match state.
