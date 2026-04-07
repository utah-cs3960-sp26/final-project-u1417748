# Gameplay Spec Snapshot

## Intended Match Loop

1. Boot to main menu.
2. Start a 3-minute portrait match.
3. Human controls the current offensive ballhandler.
4. Move with a virtual joystick, tap to pass, hold-drag to shoot.
5. Resolve live shots with 2D court motion plus simulated ball z-height.
6. Run a live rebound phase on misses.
7. Simulate opponent possessions off-screen after makes, turnovers, and defensive rebounds.
8. End cleanly at `0:00` and allow restart.

## Presentation Scaffold Added In This Session

The current project now visually represents:
- top-center hoop placement
- black top HUD banner
- lower-third joystick comfort zone
- a readable half-court with key spacing landmarks
- sample 5-on-5 default formation silhouettes
- placeholder pause, game-over, and debug overlays

## Deliberately Deferred

- live input and multitouch
- ball ownership and control transfer
- passing, shot arbitration, release timing, and trajectory dots
- contests, steals, blocks, rebounds, and opponent sim logic
- deterministic tests and replay scenarios
