# Pocket Hoops

Pocket Hoops is a clean-room Godot 4.6.x portrait basketball prototype built for a class demo. The game is offense-only: you control the current ballhandler with a lower-third joystick, tap teammates to pass, hold on the ballhandler to bring up a slow-motion shot meter, and jump-cut through opponent possessions with a ratings-driven sim.

## Status

- The project now boots directly into a playable match for faster gameplay and layout validation.
- Live offense, passing, shot aim, scoring, rebounds, pause, game over, and opponent sim are implemented.
- Shot aim now uses a hold-to-shoot timing meter instead of drag aiming.
- Rendering now uses a low top-down projection layer: gameplay stays on a flat court plane while players, ball, hoop, preview dots, shadows, and debug geometry are projected for a stronger camera angle.
- Action input is projection-aware, so teammate taps and shot holds target the projected screen positions the player actually sees.
- The floor now renders from the blue second-court atlas variant as a rotated vertical half-court, and the visible front net layer is aligned to the live rim anchor.
- Gameplay tuning is resource-backed under `data/config/`.
- Deterministic pure-logic, scenario, and balance tests are implemented under `tests/`.

## Run

Open the project in Godot 4.6.x or run:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --path .
```

Headless automated tests:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd
```

## Controls

- Move: touch joystick in the lower third, or `WASD` / arrow keys in debug.
- Pass: tap a teammate.
- Shoot: touch and hold on the ballhandler until the bottom timing meter appears, then release.
- Shot feel: the meter is mostly red with a smaller green chunk; releasing on green always scores and cannot be blocked, while releasing on red causes a miss or a block if the contest wins.
- Made shots now hold on-screen briefly so the ball can finish through the hoop before the possession resets.
- Pause: HUD pause button or `P` / `Esc`.
- Debug overlay: `F3`.

## Layout

- `scenes/`: game root, entity scenes, UI scenes, debug scenes
- `scripts/game/`: coordinator, HUD, overlays, court view
- `scripts/input/`: joystick and action input
- `scripts/gameplay/`: shot, pass, ball, hoop, rebound systems
- `scripts/ai/`: routes, spacing, defense, opponent sim
- `scripts/entities/`: player and team resources/controllers
- `scripts/debug/`: debug overlay plus wrappers for harness utilities
- `data/`: config resources, teams, scenario resources, balance resources
- `tests/`: headless harness, scenario runner, balance batches
- `docs/`: brief, spec, architecture, decisions, worklog, test plan, results

## Docs

- `docs/PROJECT_BRIEF.md`
- `docs/GAMEPLAY_SPEC.md`
- `docs/ARCHITECTURE.md`
- `docs/DECISIONS.md`
- `docs/TEST_PLAN.md`
- `docs/KNOWN_ISSUES.md`
- `docs/WORKLOG.md`
- `docs/TEST_RESULTS.md`
