# Pocket Hoops

Pocket Hoops is a clean-room Godot 4.6.x portrait basketball prototype built for a class demo. The game is offense-only: you control the current ballhandler with a lower-third joystick, tap teammates to pass, hold on the ballhandler to bring up a slow-motion shot meter plus a live arc preview, and jump-cut through opponent possessions with a ratings-driven sim.

## Status

- The project now boots directly into a playable match for faster gameplay and layout validation.
- Live offense, passing, shot aim, scoring, rebounds, pause, game over, and opponent sim are implemented.
- Shot aim now uses a hold-to-shoot timing meter instead of drag aiming, paired with a visible release preview.
- Human shots now use an apex-driven launch solver with above-floor release height, longer airtime, and more dramatic on-screen arc lift.
- Green makes now use a staged guided-make profile: the ballistic arc ends on the rim plane inside the legal front-half mouth, then the live simulator immediately drives the downward descent through the cylinder and net before the score resolves.
- The terminal green-make path now applies a visual-only screen drop of about 60px so the final approach and descent read lower on screen without changing solver output, score legality, or hoop geometry.
- Made baskets now use a three-piece hoop stack so the handoff can read at the rim, slip behind the hanging net during the swish, and only render behind the board when the path actually goes over it.
- Rendering now uses a flat top-down rectangular projection: gameplay stays on a flat court plane while players, ball, hoop, preview dots, shadows, and debug geometry stay screen-faithful without the stretched trapezoid look.
- Action input is projection-aware, so teammate taps and shot holds target the projected screen positions the player actually sees.
- The floor now renders from the blue second-court atlas variant as a rotated vertical half-court, and the layered hoop sprites stay aligned to the live rim anchor.
- Player presentation is intentionally oversized for mobile readability, with a slightly closer default framing than the earlier build.
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
- Shot feel: the meter is mostly red with a smaller green chunk; releasing on green always scores through a planned downward swish path and cannot be blocked, while releasing on red causes a miss or a block if the contest wins.
- Shot preview: aim mode now shows preview dots for the release path. Green preview dots show the guaranteed-make arc, and red preview dots show the deterministic miss path that would be launched if released immediately.
- Made shots now hold on-screen briefly after the simulator-owned descent so the ball can fully clear the net before the possession resets.
- Made shot visuals now use explicit hoop depth phases so the ball can read in front of the backboard, at the rim-plane handoff, behind the hanging net, or behind the board only when it truly goes over it.
- The final green-make approach and descent now render about 60px lower on screen as a visual-only terminal drop, but the legal score corridor and hoop geometry are unchanged.
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
