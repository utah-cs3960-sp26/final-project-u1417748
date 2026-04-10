# Pocket Hoops

## Proposal (Week 12)

### What are you going to build? What are the features you intend to show off? What kind of agentic loop are you going to use to make this happen? What will be the feedback mechanisms that you will tell the agent to use, to ensure a quality product?


I want to build a retro, arcade style, basketball game. The core mechanic would be that you only play offense, you control the person with the ball every possession, you can swipe to pass to teammates (5v5) who dynamically move around based on the player with the balls position. You can shoot with a timing based swipe and release method. When you score or miss, the opponent's possession is simulated automatically based on their roster ratings and the ball comes right back to you on offense. This is to keep the pacing fast and gameplay focused solely on the offense mechanics, helping to lower the scope of this project to the time permitted. For the features I want to show off, I'd want to have a working shooting mechanic with a physics based ball arc and rim collisions, a working teammate movement system, and a working simulation for when the computer team has possession of the ball using ratings to determine outcomes. A stretch goal would be a fast break mechanic to give 2 on 1 opportunities.


For my agentic loop, I'll likely be using mostly AMP with possibly some Codex to generate the frame, the physics setup, and the UI while I will focus on tuning the gameplay to feel arcady and the logic that the AI probably won't get right on it's own. Before each task, I'll give AMP a structured checklist, what tasks to perform, what the expected behavior should look like, and what constraints to follow. For feedback, I'll have AMP run a build after every change to catch compile errors immediately and I'll maintain a testing.md or similar file that describes test cases to check for. 

## Proposal (Week 13)

### What's working so far on your project? What are your concrete plans for the next week? What are the smartest and dumbest thing your agent loop did this week? If you're using Amp, link to the relevant threads. What did you change to stop the agent from doing that dumb thing again?


So far, the gameplay and visual aspect of my project is working somewhat well. The user can pass the ball, shoot it based off a timer, and miss the shot if it's bad. There were a lot of troubles visually for AMP because it seemed a lot more reluctant to run the code and use visuals to help itself debug, so instead, I switched to Codex. I would instruct Codex to run the game and to see its placements of visuals to make sure they align with the details I was describing. 

The dumbest things my agent loop did this week were assuming it knows the details of how items were drawn and the placements inside of those drawings. For example, if a player shot the ball, it would count as a score even if the ball didn't visually go through the hoop and instead was above it. To prevent codex from doing this again, I told it to place it as close as it could predict accurately and then to wait for me to help give it fine details on the placements such as: "lower the end point of the shot by 100 pixels" which worked well and was suprisingly faster then letting Codex try to figure it out itself. 

The smartest thing its done is get the arch for a more arcadic style shot right while still being accurate. Since it's a top down view, a shot would likely just look like a straight line, but I wanted to dramaticize the effect so adding a big arch and curve to the shot which AMP/Codex were able to achieve very well through creating a physics based environment. 


------


## Status

- The project now boots directly into a playable match for faster gameplay and layout validation.
- Live offense, flick passing, armed shot timing, scoring, rebounds, pause, game over, and opponent sim are implemented.
- Mobile controls now use a one-thumb lower-zone gesture model: drag to move, flick to pass, release to arm the shot meter, then tap anywhere to lock timing.
- Human shots now use an apex-driven launch solver with above-floor release height, longer airtime, and more dramatic on-screen arc lift.
- Green makes now use a staged guided-make profile: the ballistic arc ends on the rim plane inside the legal front-half mouth, then the live simulator immediately drives the downward descent through the cylinder and net before the score resolves.
- The terminal green-make path now applies a visual-only screen drop of about 60px so the final approach and descent read lower on screen without changing solver output, score legality, or hoop geometry.
- Made baskets now use a three-piece hoop stack so the handoff can read at the rim, slip behind the hanging net during the swish, and only render behind the board when the path actually goes over it.
- Rendering now uses a flat top-down rectangular projection: gameplay stays on a flat court plane while players, ball, hoop, preview dots, shadows, and debug geometry stay screen-faithful without the stretched trapezoid look.
- Action input is projection-aware, so the invisible movement zone, flick-pass preview, and tap-to-time shot flow all line up with the projected screen positions the player actually sees.
- The floor now renders from the blue second-court atlas variant as a rotated full-height crop that preserves the source art ratio, fills the screen vertically, and reveals part of the opposite side without stretching.
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

- Move: drag anywhere in the lower `35%` of the screen; a faint temporary anchor appears under the thumb. `WASD` / arrow keys still work in debug.
- Pass: flick and lift. Before release, the best teammate inside the directional cone gets a filled preview ring under their feet.
- Shoot: release a non-pass gesture to arm shot mode. The shot row starts immediately, the timing bar sweeps left to right once, and a tap anywhere on screen locks the result.
- Shot feel: the meter is mostly red with a smaller green chunk; tapping on green always scores through a planned downward swish path and cannot be blocked, tapping on red causes a miss or a block if the contest wins, and failing to tap before the bar ends counts as a late miss.
- Shot preview: armed shot mode shows preview dots for the release path. Green preview dots show the guaranteed-make arc, and red preview dots show the deterministic miss path that would be launched if tapped immediately.
- Made shots now hold on-screen briefly after the simulator-owned descent so the ball can fully clear the net before the possession resets.
- Made shot visuals now use explicit hoop depth phases so the ball can read in front of the backboard, at the rim-plane handoff, behind the hanging net, or behind the board only when it truly goes over it.
- The final green-make approach and descent now render about 60px lower on screen as a visual-only terminal drop, but the legal score corridor and hoop geometry are unchanged.
- Pause: HUD pause button or `P` / `Esc`.
- Debug overlay: `F3`.

## Layout

- `scenes/`: game root, entity scenes, UI scenes, debug scenes
- `scripts/game/`: coordinator, HUD, overlays, court view
- `scripts/input/`: invisible-zone gesture input and debug input
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
