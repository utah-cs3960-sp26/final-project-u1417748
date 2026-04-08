# AGENTS.md

## Purpose

This repository contains a mobile-first, portrait-only, retro arcade basketball game built in **Godot 4.6.2 stable** using **typed GDScript**.

This file is the standing operating manual for any autonomous coding loop, subagent, worker, or human contributor touching the repo. Treat it as binding project guidance. If a future prompt is vague, follow this file before improvising.

The target deliverable is a **class-demo-ready** game that is also structured cleanly enough to be extended toward eventual Android and iOS store release.

---

## Product summary

Build a fast, offense-only, vertical basketball game with the following identity:

- portrait orientation
- half-court view
- hoop fixed at the top of the screen
- player only controls offense
- 5 offensive players and 5 defensive players on court
- human controls whichever offensive player currently has the ball
- virtual joystick for movement
- tap teammate to pass
- hold and drag from ballhandler to shoot
- shot direction launches 180 degrees opposite the drag direction
- shot aim enters 0.5x slow motion
- trajectory dots preview the exact physics path as closely as practical
- ball uses 2D court position plus simulated z-height
- rim and backboard collisions are live and determine outcomes
- missed shots create a rebound phase
- defensive rebounds, steals, and most turnovers jump-cut to an opponent possession simulation
- match lasts 3 minutes
- top HUD banner shows HOM score, timer + pause, AWY score

The experience should feel quick, readable, arcade, mobile-friendly, and satisfying to replay.

---

## Locked decisions

These choices are already made. Do not reopen them without a documented reason in `docs/DECISIONS.md`.

### Tech stack
- Engine: **Godot 4.6.2 stable**
- Language: **typed GDScript**
- Gameplay rendering model: **2D court plus simulated z-height for the ball**
- Orientation: **portrait only**
- Initial target: **class demo**, structured for later Android/iOS publishing

### Core scope
- Human team plays offense only
- No live human-controlled defense sequence
- No fouls
- No free throws
- No travel
- No backcourt
- No goaltending
- No jump balls
- No overtime
- No audio required in v1
- No persistence required in v1
- No analytics, ads, sign-in, or online play

### Core interaction
- Ballhandler moves with a virtual joystick in the lower third
- Tap teammate to pass immediately
- Hold and drag from the current ballhandler to enter shot aim
- Releasing in shot aim:
  - if the release endpoint falls inside a teammate catch radius, convert the action to a pass
  - otherwise, launch a shot
- During shot aim:
  - ballhandler cannot move
  - gameplay runs at 0.5x time
  - trajectory dots are shown
  - shot timing quality is shown live through line color
- Color semantics:
  - green = great timing
  - yellow = okay timing
  - red = poor timing

### Match rules
- Match clock starts at 3:00 and counts down
- No shot clock
- Hoop is fixed at top center
- Half-court only
- 2-point and 3-point scoring both exist
- 3-point value is determined by shooter position at release
- After a made basket or any turnover that yields opponent possession, run opponent sim and then reset to new human offense
- After a missed shot:
  - live rebound phase occurs
  - offensive rebound continues possession live
  - defensive rebound triggers opponent sim then reset to human offense

### AI shape
- Offense runs three simple continuous route packages
- Defense is pure man-to-man
- Defenders stay assigned to one offensive player for the full possession
- Defenders can contest shots, intercept passes, attempt steals, attempt blocks, and rebound
- Opponent possessions are simulated off-screen using player ratings and randomness

### Testing philosophy
- Live matches may use non-deterministic randomness
- Automated tests must support deterministic seeded mode
- Testing is a first-class feature, not cleanup
- Debug logs must be written to `user://logs/`

---

## Project principles

1. **Make the shot mechanic feel good first.**  
   If priorities conflict, protect the quality of shot input, arc prediction, release timing, and hoop interaction before polishing secondary systems.

2. **Use explicit state, not hidden behavior.**  
   The game must have a clear state machine and logged transitions.

3. **Favor simple, testable systems over realism.**  
   This is an arcade game, not a simulation-heavy sports title.

4. **Make everything tunable.**  
   Gameplay constants belong in config `Resource` files, not scattered numeric literals.

5. **Prioritize observability.**  
   Future LLM loops must be able to understand what happened from logs, docs, and debug overlays.

6. **Prefer deterministic core math for ball flight.**  
   The ball simulator, shot preview, and hoop resolution should be controlled and reproducible.

7. **Build mobile-first, but keep desktop debug support.**  
   Mouse/touch emulation and optional keyboard movement are required in debug builds.

8. **Do not overengineer.**  
   Avoid deep abstraction, speculative systems, and large generic frameworks that slow iteration.

---

## Required worker model

Contributors must work in focused streams. If real subagents or workers are available, use them. If not, emulate them by splitting planning, implementation, and validation into discrete subsystem passes.

At minimum, maintain these workstreams:

### 1. Coordinator / Tech Lead
Own:
- architecture
- scope discipline
- integration cadence
- repo docs
- acceptance tracking
- final QA

Responsibilities:
- keep `docs/WORKLOG.md` updated
- keep `docs/DECISIONS.md` updated
- ensure subsystem interfaces remain consistent
- merge and verify worker outputs frequently

### 2. Gameplay/Input Worker
Own:
- virtual joystick
- touch and multitouch handling
- ballhandler movement
- tap pass input
- hold-drag shot input
- shot/pass arbitration
- control transfer on catch/rebound

### 3. Ball / Hoop Worker
Own:
- custom ball simulator
- z-height model
- gravity
- trajectory preview
- rim collisions
- backboard collisions
- basket detection
- 2pt/3pt classification

### 4. AI / Movement Worker
Own:
- offensive route packages
- off-ball spacing
- open-area logic
- defender assignment and follow behavior
- contests
- pass interception checks
- block attempts
- rebound pursuit

### 5. Game State / Sim / UI Worker
Own:
- state machine
- timer
- HUD
- pause
- game over
- opponent possession simulation
- possession reset rules
- scoreboard and event feedback text

### 6. Testing / Diagnostics Worker
Own:
- pure logic tests
- deterministic scenario runner
- bot pilot
- replay scenarios
- balance test batches
- log writing
- debug overlay
- test result reporting

### 7. Art / Polish Worker (optional)
Own:
- retro placeholder visuals
- readability improvements
- sprite consistency
- pixel-feel UI treatment
- shadows and scale polish that improve gameplay readability

No worker should disappear into a silo for too long. Integrate continuously.

---

## Required documentation

These files must exist and stay current:

- `README.md`
- `AGENTS.md`
- `docs/PROJECT_BRIEF.md`
- `docs/GAMEPLAY_SPEC.md`
- `docs/ARCHITECTURE.md`
- `docs/DECISIONS.md`
- `docs/TEST_PLAN.md`
- `docs/KNOWN_ISSUES.md`
- `docs/WORKLOG.md`
- `docs/TEST_RESULTS.md`
- `THIRD_PARTY.md` if any external assets, plugins, or libraries are used

### Documentation rules
- update docs in the same commit/session as meaningful code changes
- record tradeoffs, not just end results
- if a system is simplified, write down why
- if a bug is deferred, log it in `docs/KNOWN_ISSUES.md`
- if a tuning value changes materially, document the reason in either `docs/WORKLOG.md` or `docs/DECISIONS.md`

---

## Repo conventions

### Naming
Use consistent, descriptive names.

Recommended style:
- Scenes: `PascalCase.tscn`
- Scripts: `PascalCase.gd` or `snake_case.gd` consistently across folders; pick one and keep it repo-wide
- Signals: `snake_case`
- Methods/variables: `snake_case`
- Config resources: `SomethingConfig.tres` / `SomethingConfig.gd`

### Suggested directory layout
A clean structure similar to the following is expected:

- `scenes/`
  - `GameRoot.tscn`
  - `Court.tscn`
  - `entities/`
  - `ui/`
  - `debug/`
- `scripts/`
  - `game/`
  - `input/`
  - `gameplay/`
  - `ai/`
  - `entities/`
  - `debug/`
- `data/`
  - `config/`
  - `teams/`
  - `routes/`
  - `scenarios/`
- `tests/`
- `docs/`

Do not flatten everything into one folder.

### Code rules
- typed GDScript only for new gameplay code
- avoid magic numbers in logic; put them in config resources
- keep one clear responsibility per script
- use explicit enums/constants for game states
- avoid hidden singleton state unless a singleton is clearly justified
- if a singleton is used, document it in `docs/ARCHITECTURE.md`
- prefer composition over giant inheritance chains
- keep public interfaces small and readable
- log meaningful events, not noise-only spam

### State machine rule
All major transitions must go through a single authoritative game coordinator or state manager.  
Do not let random entities change global state independently without a documented interface.

---

## Required config resources

At minimum, create config resources for:

- `GameConfig`
- `CourtConfig`
- `BallPhysicsConfig`
- `ShotTimingConfig`
- `PassConfig`
- `RouteConfig`
- `DefenseConfig`
- `ReboundConfig`
- `OpponentSimConfig`
- `DifficultyConfig`
- `DebugConfig`

### Config rule
Any value that affects moment-to-moment feel, AI aggression, timings, radii, scoring thresholds, or probabilities must be editable without changing core code.

---

## Input implementation rules

### Joystick
- virtual joystick lives in lower third of screen
- supports deadzone and max radius
- controls current offensive ballhandler
- must be responsive, arcade, and predictable
- allow debug mouse/keyboard fallback in non-release builds

### Pass input
- tapping a teammate passes immediately to that teammate
- no auto-targeting in v1
- passes are straight-line passes
- successful catch transfers human control

### Shot input
- press/hold on ballhandler and drag to enter shot aim
- movement is disabled while aiming
- global gameplay time scale becomes 0.5x while aiming
- final shot launch direction is opposite the drag vector
- drag distance controls shot power
- releasing over a teammate catch radius converts to pass
- small invalid drag with no valid pass target cancels to live play

---

## Ball and hoop rules

### Ball simulation
Use a controlled ball simulator that tracks at least:
- x/y position
- x/y velocity
- z height
- z velocity
- ball radius
- gravity
- possession owner state
- scored-once flag

Do not reduce shot outcomes to a hidden post-release dice roll.

### Trajectory preview
Preview dots should use the same underlying launch math and trajectory logic as actual shots as closely as practical.

### Basket counting
A score only counts when:
- the ball is descending
- the ball crosses through the scoring region
- the shot has not already been counted

Prevent double counting on rim rattles or repeated overlap.

### Scoring value
- determine 2pt or 3pt from shooter position at release
- expose the 3pt line as tunable court data

---

## AI rules

### Offensive routes
Implement exactly three simple route packages:
1. wing swap
2. strong-side slash
3. weak-side fill

These routes should:
- run continuously
- preserve spacing
- react to ballhandler position
- avoid obvious crowding
- remain simple and readable

### Defensive style
- pure man-to-man only
- no switching in v1
- one defender stays matched to one offensive player for the possession
- defenders can contest, intercept, steal, block, and rebound

### Rebounds
When the ball becomes rebounding-live:
- suspend normal route-running
- nearest relevant players pursue the rebound area
- offensive rebound continues live offense
- defensive rebound ends the live possession and triggers opponent sim

---

## Opponent possession sim rules

The opponent possession sim exists to keep pacing fast and offense-focused.

### It must:
- use on-court player ratings
- consume game clock
- allow 2pt, 3pt, miss, turnover, offensive rebound, second-chance points
- produce readable logs
- support difficulty tuning

### It must not:
- require a full live defensive sequence
- silently change scores without logs
- ignore remaining clock

### Difficulty
At minimum:
- Easy
- Normal
- Hard

Default:
- Normal

Difficulty should modify:
- live defensive tightness
- steal/block/rebound pressure
- opponent sim efficiency

Do not cheat by overriding the human shot system.

---

## Ratings rules

Use a 0–100 scale for all ratings.

Each player must have at least:
- `speed`
- `acceleration`
- `handle`
- `pass_accuracy`
- `catch`
- `shooting`
- `release_consistency`
- `perimeter_defense`
- `steal`
- `block`
- `rebound`
- `sim_offense`

Default HOM and AWY teams should be balanced enough that the game is fun and winnable on Normal difficulty.

---

## Logging and debug rules

Write logs to `user://logs/`.

At minimum produce:
- match log
- structured event log
- test run log
- scenario run log
- opponent sim log

### Required log events
- state transitions
- possession resets
- pass start/catch/intercept/out-of-bounds
- shot aim start/update/release
- shot timing result
- launch parameters
- rim/backboard collisions
- score events
- rebound candidates and winner
- turnovers
- opponent sim event sequence
- pause/resume
- game over

### Debug overlay
A debug overlay toggle must support:
- current game state
- route anchors/paths
- defender assignment lines
- contest radii
- catch radii
- pass intercept corridor
- predicted rebound zone
- current seed in deterministic mode

---

## Testing rules

Testing is mandatory.

### Test layers
1. **Pure logic tests**
2. **Deterministic scenario tests**
3. **Balance batch tests**
4. **Long-run stability tests**
5. **Manual smoke checklist**

### Deterministic rule
Live gameplay may use random outcomes where appropriate, but tests must support a fixed seed mode.

### Minimum required automated coverage
Cover at least:
- joystick math
- pass target selection
- shot/pass arbitration
- time slow during aim
- launch vector math
- timing color classification
- trajectory preview accuracy
- rim/backboard collisions
- scoring once-only logic
- 2pt/3pt classification
- pass interception
- route progression
- spacing logic
- contest/block checks
- rebound selection
- pressure turnover
- opponent sim outcomes
- pause
- game over
- restart
- log writing

### Required scenario tests
At minimum implement:
- clean pass-and-shoot make
- contested miss with defensive rebound
- bad cross-court pass steal
- stationary pressure turnover
- out-of-bounds turnover
- offensive rebound continuation
- buzzer shot finishing correctly
- pause/resume safety
- long-run no-softlock scenario

### Balance requirement
Run repeated seeded trials and report broad metrics.  
Flag bad tuning if:
- open green shots rarely go in
- risky passes are safer than short safe passes
- defensive rebounds almost never happen
- opponent sim scores unrealistically high or low across all difficulties
- Normal difficulty feels unwinnable or trivial

---

## Working sequence

Use this dependency order unless a clearly better order is required:

1. scaffold project, docs, configs, and state machine
2. create court, hoop, ball, players, teams, reset flow
3. implement joystick and ballhandler ownership
4. implement tap pass and catch/control transfer
5. implement shot aim and release logic
6. implement ball simulator and trajectory preview
7. implement hoop collisions and score detection
8. implement HUD, timer, pause, and game over
9. implement routes and spacing
10. implement defenders and contests
11. implement steals/intercepts/blocks
12. implement rebounds
13. implement opponent sim
14. implement logs and debug overlay
15. implement automated test harness and scenarios
16. tune and stabilize

Do not postpone tests until the end.

---

## Acceptance bar

A contribution is not complete unless all of the following remain true:

- the game still boots directly into a playable match
- movement, pass, shot, scoring, rebound, and opponent sim still function
- the game state machine remains coherent
- no new major soft-lock appears
- logs still write
- relevant tests pass
- docs are updated

---

## Change control

If you change any of the following, you must document it explicitly:
- control scheme
- scoring rules
- possession reset rules
- route package behavior
- ratings schema
- difficulty behavior
- test harness format
- project folder structure

Record changes in:
- `docs/DECISIONS.md`
- `docs/WORKLOG.md`
- `docs/TEST_RESULTS.md` if behavior impact is test-visible

---

## Session-end checklist for agents

Before ending a work session, make sure all of the following are true:

1. code compiles/runs in the current environment
2. no obvious syntax errors remain
3. modified subsystem has at least smoke-level validation
4. relevant automated tests are updated or added
5. docs reflect the latest implementation
6. logs or debug output are still readable
7. any incomplete work is clearly recorded in `docs/KNOWN_ISSUES.md`

---

## Default tie-breaker rule

When there is ambiguity:
- choose the **simplest working implementation**
- keep it **data-driven**
- keep it **easy to test**
- keep it **consistent with the offense-only arcade vision**
- document the choice

That rule applies unless a higher-priority locked decision in this file says otherwise.
