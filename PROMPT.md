You are an autonomous multi-agent game engineering team. Your job is to fully build a complete, playable, mobile-first Godot game project for a class demo, with code quality and structure strong enough to be publishable later on iOS and Android.

The game is a portrait, retro, arcade-style, offense-only basketball game inspired by the fast pacing of simple pocket sports games, but it must be its own original work with original naming, original placeholder art, and no copyrighted teams, players, logos, or branding.

The core fantasy is:

A quick-to-play casual pocket basketball game where the player only controls offense, every possession is fast, the game is vertical, and the focus is on satisfying shooting, passing, spacing, and replayable arcade flow.

Build the game now. Do not stop at planning.

---

# 1. Mandatory operating behavior

## 1.1 Use subagents/workers aggressively
You must use subagents/workers to split the build into focused streams. Do not try to implement this as one giant monolithic task.

Use real subagents/workers if the environment supports them. If literal workers are not available, emulate this by creating separate workstreams, separate planning sections, and separate implementation passes for each subsystem.

At minimum, split the work into these roles:

1. **Coordinator / Tech Lead**
   - Own the master plan, architecture, integration, progress tracking, and final QA.
   - Keep shared decisions synchronized.
   - Maintain persistent repo docs so future loops keep context.

2. **Gameplay/Input Worker**
   - Virtual joystick
   - Ballhandler movement
   - Touch and multitouch handling
   - Pass/shot arbitration
   - Control transfer between offensive players

3. **Ball Physics / Hoop Worker**
   - Ball x/y/z simulation
   - Shot arc prediction dots
   - Rim and backboard collisions
   - Score detection
   - Shot release error model

4. **AI / Movement Worker**
   - Offensive routes
   - Spacing and empty-space filling
   - Man-to-man defenders
   - Contests, steals, intercepts, blocks
   - Rebound pursuit

5. **Game State / Simulation / UI Worker**
   - Match timer
   - State machine
   - Opponent possession simulation
   - Top HUD banner
   - Pause and end-game flow

6. **Testing / Diagnostics Worker**
   - Scenario runner
   - Scripted bot pilot
   - Replay tests
   - Unit tests for pure logic
   - Integration tests
   - Balance tests
   - Text logs and debug overlays

7. **Art/Polish Worker** (optional but useful)
   - Retro-styled placeholder visuals
   - Pixel-feel UI
   - Readability polish
   - Animations and shadows that support gameplay clarity

Each worker must write code, tests, and clear documentation for its area. The Coordinator must integrate often, not only at the end.

## 1.2 Do not block on ambiguity
Do not ask clarifying questions unless there is a literal missing file or broken environment issue. When something is not fully specified, choose the simplest robust implementation that fits the spirit of this brief and expose the behavior as editable config instead of hard-coding it.

## 1.3 Prioritize an early playable vertical slice
Get to a playable vertical slice as early as possible, then refine:
- Start game button
- Live offense with joystick movement
- Tap pass
- Hold-drag shot
- Ball arc and hoop collisions
- Score updates
- Opponent sim
- Rebound loop
- Basic AI
- Tests and logs

## 1.4 All tuning must be data-driven
Do not hard-code gameplay constants directly in scattered scripts. Put all major gameplay tuning values into editable Godot `Resource` config files.

## 1.5 Mobile first, debug friendly
This game is mobile-first and portrait-only, but it must also be easy to debug in the editor. Add desktop debug controls and mouse emulation for touch in debug builds.

## 1.6 Keep the system simple, deterministic where needed, and testable
For live gameplay:
- Randomness is allowed where appropriate.
- Human shots must not use a hidden “made/missed” dice roll after release.
- Human shots should resolve from actual initial conditions, player ratings, release timing error, ball physics, and hoop collisions.

For testing:
- Add deterministic fixed-seed test/replay mode.
- Live gameplay may use non-deterministic RNG.
- Automated tests must be seedable and repeatable.

---

# 2. Deliverables

Produce all of the following:

1. A complete playable **Godot 4.6.2 stable** project.
2. Use **typed GDScript** as the primary language.
3. A working game scene with:
   - title/start screen
   - live match
   - pause overlay
   - end-of-game overlay
4. A playable offense-only 5v5 basketball loop with:
   - joystick movement
   - pass
   - shot aim and release
   - predicted trajectory dots
   - slow motion during shot aim
   - ball arc with z-height
   - rim and backboard collisions
   - scoring
   - rebounds
   - turnovers/intercepts/blocks
   - opponent possession simulation
5. Debug and testing infrastructure:
   - scenario runner
   - scripted bot pilot
   - deterministic replay mode
   - text logs
   - debug overlays
   - unit and integration tests
   - broad balance tests
6. Persistent repo documentation:
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
   - `THIRD_PARTY.md` if any external assets or add-ons are used

---

# 3. Technical foundation

## 3.1 Engine and language
- Engine: **Godot 4.6.2 stable**
- Language: **typed GDScript**
- Rendering/gameplay style: **2D court + simulated z-height for the ball**
- Orientation: **portrait only**
- Export target later: Android and iOS, but for now focus on a clean playable project

## 3.2 Physics approach
Do **not** rely on a generic physics-body-only solution for the ball flight. Use a **custom deterministic ball simulator** for:
- x position
- y position
- z height
- x/y velocity
- z velocity
- gravity
- collision checks against rim/backboard
- score detection
- rebound landing estimation

Reason:
- trajectory dots must match actual ball motion
- tests must be repeatable
- the shot mechanic must feel intentional and tunable

Players can use normal Godot 2D movement helpers, but the ball’s flight and hoop resolution should be custom and controlled.

## 3.3 Dependencies
Third-party assets and packages are allowed, but keep dependencies minimal and reliable. Prefer built-in Godot features unless a third-party addition clearly saves time without introducing fragility. Any external asset or code must be license-safe and documented.

---

# 4. Project summary and exact scope

## 4.1 The game
Build a vertical, portrait, half-court, offense-only basketball game.

When the app opens, it should show a minimal start screen with a **Start Game** button. Pressing Start Game enters directly into a 3-minute match.

The player only controls offense. The player always controls whichever offensive player currently has the ball. The hoop is always at the **top center** of the screen.

When the human team scores, misses and loses the rebound, turns the ball over, or sends the ball out of bounds, the opponent possession is simulated automatically off-screen using ratings and randomness, then the game jump cuts back to the human team on offense.

## 4.2 Hard MVP
The first fully acceptable MVP must include all of the following:
- 5 offensive players
- 5 defensive players
- human control of the current offensive ballhandler
- 3 off-ball offensive route packages
- defenders guarding a specific offensive player in pure man-to-man
- joystick movement
- tap-to-pass
- hold-drag-to-shoot
- shot release timing quality
- predicted shot dots
- time slow-down during shot aim
- ball arc with z-height
- working rim and backboard collisions
- basket detection and score recognition
- black top HUD banner with scores and timer
- rebounds
- steals/intercepts/turnovers
- opponent possession simulation
- pause
- end of game at 3:00 elapsed countdown

## 4.3 Explicitly out of scope for v1
Do not spend time on:
- live human-controlled defense sequences
- fouls
- free throws
- traveling
- backcourt violations
- goaltending
- jump balls
- overtime
- audio
- persistence/save system
- settings menus beyond what is minimally needed
- real teams, leagues, or licensing
- online multiplayer
- ads, analytics, monetization, accounts, or leaderboards

## 4.4 Stretch goal only after MVP is solid
Only after the full MVP works and the test suite is stable, consider a simple fast-break-style 2-on-1 transition chance as a stretch goal. This is not required.

---

# 5. Core game pillars

The game must feel:
- **fast**
- **clear**
- **arcade**
- **mobile-friendly**
- **replayable**
- **satisfying when shooting**
- **simple to understand**
- **not overloaded with systems**

The main thing that must feel good is:
- dragging back to shoot
- watching the arc
- seeing the dots
- releasing at the right time
- getting a satisfying make or believable miss
- using quick passes to hit open players

---

# 6. Exact court model, camera, and visual style

## 6.1 Camera and layout
- Portrait orientation only
- Fixed camera
- Half-court visible
- Hoop fixed at top center
- The top black HUD banner sits above the court
- The lower third of the screen is the joystick/input area, but part of the lower court may still be visible behind it
- No camera panning required for v1
- No camera zoom required for v1

Use a mobile reference layout roughly equivalent to **1080x1920 portrait**, but make the scene responsive to different phone aspect ratios.

## 6.2 World model
The game is fundamentally:
- 2D court movement for players
- simulated z-height for the ball
- simple shadows under players
- subtle ball sprite scaling by z
- subtle visual cheats to sell height

Do not build full 3D. Keep it 2D and controlled.

## 6.3 Court and formation anchors
Represent player positions in normalized half-court space so route logic is portable and easy to tune.

Use these normalized default anchors inside the playable court rectangle:

- Hoop center: `(0.50, 0.10)`
- Point guard start / possession reset: `(0.50, 0.78)`
- Left wing start: `(0.32, 0.52)`
- Right wing start: `(0.68, 0.52)`
- Left corner start: `(0.18, 0.26)`
- Right corner start: `(0.82, 0.26)`

These are starting defaults and may be slightly tuned, but keep the overall formation:
- one player bottom-middle with ball
- two wing players
- two corner-ish players near the top left/top right

## 6.4 Rim and backboard scale
The hoop should be intentionally generous and arcadey:
- visually larger than any single player sprite
- easy to read
- not tiny or realistic-scale

## 6.5 Art direction
Use a retro pixel-inspired presentation:
- chunky readable sprites
- limited palette
- strong outlines
- no smooth modern gradients as the dominant style
- blocky/retro font or license-safe equivalent
- sprite animations can be intentionally low-frame-feel while game logic runs at normal frame rate
- maintain visual clarity over visual complexity

Programmer art is acceptable as long as it is consistent, readable, and fits the retro direction.

---

# 7. Match rules and state machine

## 7.1 Match duration
- Match length: **3 minutes**
- No shot clock
- Timer counts down from `3:00` to `0:00`

## 7.2 Time behavior
- Normal gameplay time scale: `1.0`
- During shot aim hold: **global gameplay slow motion at `0.5x`**
- The game clock continues to tick during shot aim, but at the slowed gameplay rate
- During pause: clock and gameplay stop completely
- During opponent possession sim: consume simulated possession time from the game clock

## 7.3 End of game rule
When the timer reaches `0:00`:
- if a shot is currently in flight, allow the live shot and any immediate rebound resolution to finish
- then end the game cleanly
- show final score
- allow restart

## 7.4 Explicit game states
Use a clear explicit state machine. Suggested states:

- `BOOT`
- `MAIN_MENU`
- `MATCH_SETUP`
- `LIVE_OFFENSE`
- `PASS_IN_FLIGHT`
- `SHOT_AIM`
- `SHOT_IN_FLIGHT`
- `REBOUND_LIVE`
- `OPPONENT_SIM`
- `PAUSED`
- `GAME_OVER`

Every transition must be explicit and testable.

## 7.5 State transition rules
### Main flow
- `MAIN_MENU` -> `MATCH_SETUP` -> `LIVE_OFFENSE`

### From `LIVE_OFFENSE`
- tap teammate -> `PASS_IN_FLIGHT`
- hold and drag starting on current ballhandler -> `SHOT_AIM`
- ballhandler turnover from pressure -> `OPPONENT_SIM`
- ballhandler out of bounds -> `OPPONENT_SIM`
- timer expiration -> `GAME_OVER` or delayed game-over if shot is resolving

### From `PASS_IN_FLIGHT`
- caught by offense -> `LIVE_OFFENSE`
- intercepted by defense -> `OPPONENT_SIM`
- pass out of bounds -> `OPPONENT_SIM`

### From `SHOT_AIM`
- release with valid shot -> `SHOT_IN_FLIGHT`
- release while targeting teammate via the defined pass-conversion rule -> `PASS_IN_FLIGHT`
- release with invalid tiny drag and no pass target -> cancel back to `LIVE_OFFENSE`
- pause -> `PAUSED`

### From `SHOT_IN_FLIGHT`
- made basket -> update score -> `OPPONENT_SIM`
- blocked/deflected shot -> `REBOUND_LIVE`
- missed shot -> `REBOUND_LIVE`

### From `REBOUND_LIVE`
- offensive rebound -> `LIVE_OFFENSE`
- defensive rebound -> `OPPONENT_SIM`
- loose ball out of bounds -> `OPPONENT_SIM`

### From `OPPONENT_SIM`
- update score/time/logs
- if time remains -> reset positions -> `LIVE_OFFENSE`
- if time expired -> `GAME_OVER`

### Pause flow
- any live gameplay state can enter `PAUSED`
- resume returns to the prior state
- restart from pause is allowed

---

# 8. Input model and control scheme

## 8.1 Multitouch is required
This is a mobile-first game. Support multitouch:
- one touch can control the virtual joystick
- another touch can tap teammates or perform shot drag/release
- the player must be able to move with one thumb and act with another

In debug/editor mode, allow mouse emulation and optional keyboard fallback for movement.

## 8.2 Virtual joystick
- Place the joystick in the bottom third of the screen
- It controls the current offensive ballhandler
- Moving the joystick toward a direction moves the ballhandler in that direction
- Example: pushing toward the top-left moves the player up-left
- Use deadzone + normalized direction + capped magnitude
- Ballhandler movement should feel responsive but arcade, not slippery

## 8.3 Pass input
Pass rule:
- Tapping another offensive teammate passes directly to that teammate
- Pass target selection is manual, not automatic
- Passes are straight-line passes on the court plane
- No pass icons are required
- No lob pass required for v1

## 8.4 Shot input
Shot rule:
- The player must press/hold on the current ballhandler and drag
- Dragging away from the player charges/aims a shot
- The actual launch direction is **180 degrees opposite the drag direction**
- This is a pull-back shot mechanic
- The farther the drag, the greater the shot power
- The player cannot move during shot aim
- Slow motion begins immediately on entering shot aim

## 8.5 Shot/pass arbitration
Use this exact default rule:

1. **Tap on teammate** = immediate pass
2. **Hold and drag starting on current ballhandler** = enter shot aim
3. On release from shot aim:
   - if the **release endpoint** lands inside a teammate’s configurable catch radius, convert the action into a pass instead of a shot
   - otherwise, release a shot

Also expose a config flag that allows a later alternate rule based on the predicted initial path intersecting a teammate’s catch radius, but the default implementation must be the release-endpoint rule above.

## 8.6 Invalid shot cancel
If shot aim is entered but:
- drag length is below minimum shot threshold
- and release is not inside a teammate catch radius

then cancel the action, restore normal time, and return to `LIVE_OFFENSE`.

---

# 9. Live offense systems

## 9.1 Human control transfer
The human always controls the offensive player who currently has the ball.

Control must transfer:
- after a successful pass catch
- after an offensive rebound
- after any other offensive ball recovery

## 9.2 Ballhandler turnover from pressure
Implement an on-ball pressure turnover rule:
- if the on-ball defender is within a configurable pressure radius
- and the ballhandler is effectively stationary for longer than a configurable threshold
- roll periodic steal/turnover checks
- use defender steal/perimeter defense vs ballhandler handle
- successful turnover sends play to `OPPONENT_SIM`

This must be logged.

## 9.3 Out of bounds
Out of bounds exists in v1.
For simplicity:
- if the ballhandler crosses the court boundary with the ball, it is a turnover
- if a pass goes out of bounds before an offensive catch, it is a turnover
- if a loose or rebounding ball resolves out of bounds, treat it as defensive possession for the purpose of the opponent sim
- no inbound sequences are needed in v1

---

# 10. Shooting system

## 10.1 Core mechanic
The shot mechanic is the most important mechanic in the project. Prioritize it above everything else.

It must include:
- pull-back drag
- slow motion while aiming
- exact predicted trajectory dots
- timing-based release quality
- 2.5D ball arc via z-height
- rim and backboard interaction
- satisfying scoring and misses

## 10.2 Shot direction and power
- Use the **final drag vector** at release as the main aim input
- Launch direction is opposite the drag vector
- Drag distance maps to launch power
- Clamp minimum and maximum shot power
- Use a tunable power curve, not only linear mapping

## 10.3 Shot timing quality
While the player is holding the shot:
- start a shot timing timer
- the ideal release is the **middle** of the current timing window
- defender proximity makes the timing window tighter and less forgiving
- shooter release consistency widens or stabilizes the timing window
- line color reflects **current release timing quality if the shot were released now**
- the player must be able to read the timing quality live while holding

Required color behavior:
- green = great timing
- yellow = okay timing
- red = poor timing

The line color should not mean “guaranteed make chance.” It represents current release quality.

## 10.4 Release quality effect
Release quality must affect the shot by changing initial conditions, not by rolling a hidden make/miss result after release.

At release:
- excellent timing = minimal angle/power error
- okay timing = moderate angle/power error
- poor timing = significant angle/power error

Shooter ratings should influence:
- base accuracy stability
- power consistency
- green/yellow/red window forgiveness

Defender contest should influence:
- timing window tightness
- angle/power error penalties
- block chance
- shot disruption

## 10.5 One universal shot type
Use one universal shot type for v1. Do not build separate layup, floater, or dunk systems yet.

## 10.6 Bank shots
Backboard interaction is allowed. Simple bank shots are acceptable if they arise naturally from the physics.

## 10.7 Three-point rule
This is a half-court game with 2-point and 3-point scoring.

- Draw a configurable 3-point arc around the hoop
- Determine whether a shot is worth 2 or 3 based on the shooter’s **court position at the moment of release**
- Outside the arc = 3 points
- Inside the arc = 2 points

## 10.8 Trajectory dots
During shot aim:
- render dotted “trailing ants” style trajectory markers
- the dots must use the same ball simulation logic as the actual shot
- the preview should match the actual physics path as closely as possible
- the preview may ignore future moving defender blocks, but it should include the same raw projectile math and static hoop/backboard collision prediction

Use a reasonable number of dots, evenly spaced in time or arc length, so the path is readable.

---

# 11. Ball simulation, hoop collision, and scoring

## 11.1 Ball model
Track at minimum:
- `position_xy`
- `velocity_xy`
- `z`
- `vz`
- ball radius
- gravity
- in-flight state
- already_scored flag
- current owner if possessed

## 11.2 Flight
The ball uses:
- x/y travel on the court plane
- z rise and fall
- gravity over time
- optional damping on collisions as needed

## 11.3 Rim and backboard
Implement a readable arcade hoop:
- rim represented by an inner scoring area and collision boundaries
- backboard represented by a collision segment or rectangle
- ball can hit rim and bounce
- ball can hit backboard and bounce
- collisions should feel believable, not hyper-realistic

## 11.4 Scoring detection
A basket counts when the ball passes downward through the basket area.

Implement score detection in a robust one-count-only way:
- the ball must be descending
- the ball must cross through the hoop’s scoring region
- only count once per shot
- avoid double counting from rim rattles or repeated overlaps

## 11.5 No hidden post-release shot result
Once the shot is released, the outcome must come from the actual launch conditions and ball/hoop interactions, not from a later secret make/miss roll.

---

# 12. Passing system

## 12.1 Pass behavior
- passes are straight-line
- manual target selection by tapping teammate
- pass speed is configurable
- on a successful offensive catch, control transfers immediately

## 12.2 Pass interception
Defenders can intercept passes.

Implement interception using:
- current defender position
- possible intercept point along the pass line
- defender movement speed/reaction
- steal/intercept rating
- bad-pass/risky-lane context

A defender should be more likely to intercept:
- long passes
- cross-court passes
- passes thrown through a defender’s lane
- passes toward a well-guarded target

Short safe passes should be much safer.

## 12.3 Logging
Log all pass events:
- passer
- target
- pass start position
- pass target position
- distance
- whether intercepted
- interceptor if any
- resulting state transition

---

# 13. Offensive AI and route logic

## 13.1 General philosophy
Keep off-ball offense simple and readable. Use line-based route motion, anchor targets, and spacing logic. Do not build a complex tactics engine.

The routes must continuously run and never fully “reset” unless the possession itself resets after opponent sim or a dead-ball reset.

## 13.2 Starting formation
At the start of every new human possession, hard-reset all players into the default formation:
- PG bottom-middle with ball
- two wings
- two corners
- defenders matched man-to-man to each offensive player

This hard reset applies after:
- start of game
- end of opponent sim
- made human basket after opponent sim completes
- defensive rebound leading to sim
- turnover/interception leading to sim
- out-of-bounds leading to sim

Do **not** hard-reset after an offensive rebound. Continue live play in that case.

## 13.3 Exact route packages
Implement these three simple route packages.

### Package A: Wing Swap
Purpose: create a simple exchange and passing lane shift.

- Left wing moves toward center-high lane, then to right wing slot
- Right wing mirrors toward center-high lane, then to left wing slot
- Left and right corners hold depth but make small lift/drop adjustments to maintain spacing
- Package loops continuously

### Package B: Strong-Side Slash
Purpose: create a simple cut to the middle and fill behind it.

Determine ball side from the ballhandler’s x position.

- The wing on the same side as the ball makes a diagonal cut into the middle/high-slot area
- That cutter then exits toward the opposite wing
- The weak-side wing fills the vacated wing spot
- The strong-side corner lifts slightly to preserve spacing
- The weak-side corner stays deep or makes only a slight baseline drift

### Package C: Weak-Side Fill
Purpose: create movement through the lane and refill empty space.

Determine weak side from ballhandler position.

- Weak-side wing cuts through the lane toward the opposite corner
- Weak-side corner lifts to weak-side wing
- Strong-side wing drifts toward the slot/top area
- Strong-side corner adjusts slightly to keep corner spacing
- Package loops

## 13.4 Route execution approach
Implement routes as:
- target anchors
- waypoint sequences
- simple steering to next target
- continuous looping
- light separation/avoidance between teammates

Do not use heavy navigation unless needed. Simplicity is preferred.

## 13.5 Ballhandler-relative spacing
Teammates must react to the ballhandler’s position:
- if the ballhandler drifts near a teammate’s lane, that teammate should slide toward available open space
- the goal is to reduce crowding and preserve readable lanes

## 13.6 Open area logic
Define “open” using simple numeric rules exposed as config:
- a player is more open when their defender is farther away
- an area is less open when it is crowded by nearby teammates or defenders
- pass lanes should be considered part of openness
- do not allow teammates to stack tightly unless actively converging for rebounds

Initial logic should consider at least:
- distance to assigned defender
- distance to nearest other offensive teammate
- distance to nearest non-assigned defender
- pass lane obstruction

---

# 14. Defensive AI

## 14.1 Style
Defense is **pure man-to-man** in v1.
Each defender is assigned to one offensive player for the full possession.

Defenders do not switch assignments.

## 14.2 Behavior
Defenders should:
- follow and guard their assigned player
- maintain a reasonable man-to-man offset
- recover when beaten
- contest nearby shots
- attempt interceptions on risky passes
- attempt steals in bad situations
- pursue rebounds on misses
- attempt blocks if near the shooter and the shot path is contestable

## 14.3 Contested shots
A shot is contested when a defender is close enough to the shooter based on a configurable contest radius and line-to-hoop relationship.

Contested shots should:
- shrink the forgiving timing window
- increase angle/power error on non-perfect release
- increase block chance

## 14.4 Low-skill defender behavior
Some defenders should feel clumsier than others:
- worse perimeter defense should produce weaker angle control, slower recovery, and more overshoot/overcommit behavior
- stronger defenders should stay tighter and recover more cleanly

You may derive this from defense-related ratings rather than adding a separate “clumsy” stat.

---

# 15. Rebounds

## 15.1 Rebound mode
When a live shot misses or is blocked/deflected into a loose state:
- suspend normal route-running
- enter rebound mode
- offensive and defensive players closest to the rebound zone should pursue the ball

## 15.2 Rebound resolution
Rebound outcome should be based on:
- projected landing zone
- player distance to that zone
- rebound rating
- timing/reaction
- current momentum if useful

A simple and testable approach is preferred over complex collision wrestling.

## 15.3 Rebound winners
- offensive rebound -> continue possession live and transfer human control to the rebounder
- defensive rebound -> immediately transition to opponent sim
- log who won the rebound and why

---

# 16. Opponent possession simulation

## 16.1 Purpose
Opponent possessions must be simulated off-screen so the game remains offense-focused and quick.

The sim should:
- use on-court player ratings
- include randomness
- be fast
- update score/time
- produce useful logs
- support second-chance points

## 16.2 Inputs to sim
Use at least:
- offensive player ratings for the AWY team
- defensive player ratings for the HOM team
- current difficulty
- randomness/RNG
- remaining game clock

## 16.3 Suggested sim event tree
A good default approach:
1. Determine possession duration from a configurable range
2. Determine whether the possession ends in turnover or shot attempt
3. If shot attempt:
   - choose shooter using weighted usage/sim offense value
   - choose 2pt or 3pt attempt using shooter tendency / configured distribution
   - compute make chance from shooter offense vs opposing defense + difficulty + randomness
4. If miss:
   - compute offensive rebound chance using rebound aggregates and randomness
   - if offensive rebound happens, simulate a second-chance continuation
5. Clamp the sim so it never runs absurdly long

## 16.4 Allowed sim outcomes
Sim can produce:
- 2 points
- 3 points
- miss
- turnover
- offensive rebound
- second-chance points

No free throws in v1.

## 16.5 Difficulty
Implement at least:
- Easy
- Normal
- Hard

Default is **Normal**.

Difficulty affects:
- opponent sim scoring efficiency
- defender tightness and recovery
- steal/intercept pressure
- block/rebound effectiveness

Do not cheat by making live human ball physics fake. Difficulty should tune AI behavior and probabilities, not violate the core shot system.

## 16.6 Sim time consumption
Opponent sim must consume game clock time. Use a configurable possession-time model. A good default:
- main possession consumes roughly `4` to `14` seconds
- second-chance events can add a few more seconds
- clamp to remaining match time

## 16.7 Sim logs
The simulation must produce readable event logs in real time during the sim process in debug mode and write them to text files.

Example event sequence:
- `AWY possession start`
- `AWY WingR creates attempt`
- `shot: 3PT`
- `miss`
- `offensive rebound by AWY CornerL`
- `kickout`
- `made 2PT by AWY PG`
- `clock -7.8s`
- `score update HOM 12 / AWY 11`

Even if the visual game jump-cuts immediately, the sim system must still emit structured logs.

---

# 17. Ratings schema

Use a **0–100** rating scale.

Each player should have at least these ratings:
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

Use ratings both in live gameplay and in opponent sim where relevant.

## 17.1 Default teams
Create two default lineups:
- `HOM`
- `AWY`

Each should have 5 players with slight role differentiation:
- point guard / primary handler
- two wing-style players
- two corner/spacing players

Keep both teams reasonably balanced for the class demo. Slight differences are fine, but the game should be winnable and not oppressive on Normal.

---

# 18. HUD, UI, pause, and game flow

## 18.1 Top banner
The HUD must include a **black banner** at the top of the screen with:

- left: `HOM` abbreviation and score
- center: countdown timer and pause button
- right: `AWY` abbreviation and score

Example:
`HOM 12      1:24   [Pause]      AWY 11`

## 18.2 Start screen
Minimal start screen:
- title
- Start Game button

No extra menu complexity required.

## 18.3 Pause
Pause overlay must allow at least:
- Resume
- Restart Match
- Return to Main Menu (optional but useful)

## 18.4 End game
At game end:
- show final score
- show who won
- allow restart
- allow return to main menu

## 18.5 Feedback text
Required reactive text:
- show `STEAL!` when a live interception/steal occurs
- show `SWISH!` for a clean made shot
- show `BRICK!` for a clear hard miss off the rim/backboard

Keep feedback readable and arcade-like.

No audio required in v1.

---

# 19. Persistence and external services

For v1:
- no save system
- no analytics
- no ads
- no sign-in
- no online features
- no leaderboard
- no privacy/data collection features

Keep the project local and simple.

---

# 20. Architecture guidance

Use a clean, modular Godot architecture.

Suggested high-level structure:

- `MainMenu`
- `GameRoot`
- `Court`
- `Ball`
- `Player`
- `Hoop`
- `HUD`
- `PauseOverlay`
- `GameOverOverlay`
- `GameCoordinator`
- `InputController`
- `ShotController`
- `PassController`
- `RouteController`
- `DefenseController`
- `ReboundController`
- `OpponentSimController`
- `DebugController`

Use `Resource` files for:
- tuning configs
- team/player data
- route packages
- replay scenarios

## 20.1 Suggested repo layout
A suggested layout:

- `scenes/`
  - `MainMenu.tscn`
  - `GameRoot.tscn`
  - `Court.tscn`
  - `entities/Player.tscn`
  - `entities/Ball.tscn`
  - `entities/Hoop.tscn`
  - `ui/HUD.tscn`
  - `ui/PauseOverlay.tscn`
  - `ui/GameOverOverlay.tscn`
  - `debug/DebugOverlay.tscn`
  - `debug/TestRunner.tscn`

- `scripts/`
  - `game/GameCoordinator.gd`
  - `game/GameState.gd`
  - `input/InputController.gd`
  - `gameplay/ShotController.gd`
  - `gameplay/PassController.gd`
  - `gameplay/BallSimulator.gd`
  - `gameplay/HoopResolver.gd`
  - `gameplay/ReboundController.gd`
  - `ai/RouteController.gd`
  - `ai/DefenseController.gd`
  - `ai/OpponentSimController.gd`
  - `entities/PlayerController.gd`
  - `entities/PlayerData.gd`
  - `entities/TeamData.gd`
  - `debug/ScenarioRunner.gd`
  - `debug/BotPilot.gd`
  - `debug/LogWriter.gd`

- `data/`
  - `config/`
  - `teams/`
  - `routes/`
  - `scenarios/`

- `tests/`
  - pure logic tests
  - scenario tests
  - balance tests

- `docs/`

This does not have to be exact, but the final structure must be organized and documented.

## 20.2 Config resources
At minimum create config resources for:
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

---

# 21. Debugging, observability, and logs

This project must be easy for future LLM loops to debug.

## 21.1 Write persistent logs
Write logs to text files under a debug-safe path, ideally `user://logs/`.

Produce:
- a human-readable match log
- a structured JSONL or line-oriented event log
- test run logs
- scenario replay logs
- sim logs

## 21.2 Log categories
At minimum log:
- state transitions
- possession starts
- joystick start/update/end
- pass start/catch/intercept/out-of-bounds
- shot aim start/update/release
- shot timing quality
- shot launch parameters
- rim collisions
- backboard collisions
- score events
- rebound candidates and winner
- turnovers
- opponent sim event sequence
- pause/resume
- game end
- assertions from scenario tests

## 21.3 Debug overlay
Add a debug overlay toggle with options to show:
- route anchors / paths
- defender assignment lines
- contest radii
- catch radii
- pass intercept corridor
- predicted rebound landing area
- shot arc preview data
- current state machine state
- RNG seed in test mode

---

# 22. Testing requirements

Testing is a major priority. Do not treat testing as optional cleanup.

Because this is a gameplay-heavy Godot project, build a custom in-project test and scenario harness instead of relying only on ad hoc manual play. The harness must be able to set up states, simulate input, run seeded scenarios, and assert outcomes.

## 22.1 Testing architecture
Build these components:

### A. Pure logic tests
For math and state functions that do not need a full scene.

### B. Scenario runner
A deterministic runner that:
- loads a predefined match state
- sets a fixed seed
- spawns players/ball/court
- drives scripted inputs
- advances the simulation
- asserts expected outcomes

### C. Bot pilot
A scripted virtual player that can:
- move joystick
- tap a teammate
- hold and drag from the current ballhandler
- release at a chosen time
- wait
- assert current state

### D. Balance batch runner
A headless or fast-forward test suite that runs many scripted trials and reports broad gameplay metrics.

## 22.2 Deterministic test mode
Automated tests must support fixed seeds. Live normal matches can remain random, but test mode must be reproducible.

## 22.3 Required pure logic tests
At minimum write tests for:

1. joystick direction normalization
2. joystick deadzone behavior
3. ballhandler movement response
4. touch-to-teammate pass selection
5. hold-on-ballhandler enters shot aim
6. release-endpoint-inside-teammate-catch-radius converts shot aim to pass
7. invalid tiny drag cancels back to live offense
8. time scale enters 0.5 during shot aim
9. time scale restores after shot release/cancel
10. launch vector is opposite drag vector
11. drag distance maps to shot power correctly
12. shot timing quality classification for green/yellow/red
13. contest shrinks timing forgiveness
14. shooter release consistency affects timing forgiveness
15. shot error injection changes initial shot conditions
16. trajectory dots match simulator within tolerance
17. rim collision response
18. backboard collision response
19. scoring detection only counts once
20. 2pt vs 3pt classification from release position
21. ball out-of-bounds detection
22. pass interception feasibility calculation
23. defender assignment remains stable in man-to-man
24. offensive route target sequencing
25. spacing logic reduces teammate overlap
26. contested shot detection
27. block opportunity detection
28. rebound candidate ranking
29. rebound winner selection
30. stationary ballhandler pressure turnover timer/check
31. opponent sim event tree produces only valid outcomes
32. opponent sim second-chance handling
33. opponent sim consumes clock
34. pause halts time and gameplay
35. game-over trigger at zero
36. restart fully resets match state
37. logs are written when enabled

## 22.4 Required deterministic scenario tests
At minimum write scenario tests for:

1. **Clean pass-and-shoot make**
   - PG starts with ball
   - small dribble to create angle
   - pass to wing
   - control transfers
   - open green release
   - made shot
   - score updates
   - opponent sim runs
   - possession resets correctly

2. **Contested shot miss with defensive rebound**
   - dribble into tighter coverage
   - force a contested release
   - miss
   - rebound mode activates
   - defense secures rebound
   - opponent sim runs
   - score/time update and reset occur

3. **Bad cross-court pass steal**
   - hold or dribble into poor angle
   - force long pass through defender lane
   - defender intercepts
   - `STEAL!` feedback triggers
   - opponent sim runs
   - next possession resets correctly

4. **Stationary pressure turnover**
   - ballhandler stands still with defender in pressure radius
   - turnover chance triggers
   - possession goes to opponent sim

5. **Out-of-bounds turnover**
   - ballhandler crosses boundary
   - turnover occurs
   - opponent sim runs
   - reset returns to PG

6. **Offensive rebound continuation**
   - miss a shot
   - offense wins rebound
   - control transfers to rebounder
   - play continues without hard reset

7. **Clock hits zero during ball flight**
   - release shot just before `0:00`
   - allow shot and immediate rebound resolution
   - then end game cleanly

8. **Pause/resume safety**
   - enter pause during shot aim or live offense
   - resume
   - verify no clock drift and no broken state

9. **Long-run stability**
   - run many scripted possessions in sequence
   - ensure no soft lock, null ownership, duplicate scoring, or stuck states

## 22.5 Required balance/sanity tests
Write broad balance tests. These do not need perfect realism; they need to prevent nonsense.

Run seeded batch tests and report metrics. Use broad expected bands and log warnings/failures if the game is far outside them.

Suggested sanity targets on balanced teams, Normal difficulty:
- uncontested green 2PT make rate: roughly `60%–80%`
- uncontested yellow 2PT make rate: roughly `35%–60%`
- uncontested red 2PT make rate: roughly `5%–25%`
- contested green 2PT make rate should be clearly lower than uncontested green
- safe short pass interception rate should stay low
- risky long cross-court pass interception rate should be noticeably higher
- offensive rebound rate should land in a plausible arcade band, not near zero and not near automatic
- opponent sim points per possession should land in a sensible band and vary by difficulty
- the game should feel beatable on Normal, easier on Easy, and tougher on Hard

Use these as sanity constraints, not a demand for perfect basketball realism.

## 22.6 Test bot capabilities
The `BotPilot` should expose actions like:
- `move_joystick(vector, duration)`
- `tap_player(player_id)`
- `hold_drag_from_ballhandler(offset, duration)`
- `release_action()`
- `wait(seconds)`
- `assert_state(expected_state)`
- `assert_score(home, away)`
- `assert_controlled_player(player_id)`
- `assert_last_log_contains(text)`

These can be implemented however you prefer, but the scenario system must be able to simulate real gameplay.

## 22.7 Scenario format
Create reusable scenario resources or JSON-like definitions with fields such as:
- scenario name
- seed
- initial score/time
- initial player positions (optional overrides)
- active route package
- scripted actions
- expected assertions
- expected final state

---

# 23. Canonical scenario content to implement

Implement these three canonical example possessions as actual scenario tests and keep them documented.

## Scenario 1: Clean pass-and-shoot make
- Start in default possession reset formation
- Score can be neutral, e.g. HOM 0 / AWY 0
- PG has the ball at bottom-middle
- User moves slightly right to open passing lane
- User taps right wing
- Ball reaches right wing cleanly
- Control transfers to right wing
- Right wing enters shot aim with no close contest
- Trajectory line turns green at the release moment
- Shot is released with good power and angle
- Ball follows predicted arc
- Ball scores
- HUD increments by 2 or 3 depending on release location
- Opponent sim runs
- New possession resets cleanly to PG

## Scenario 2: Contested miss and defensive rebound
- Start in default formation
- PG dribbles left into tighter defense
- PG enters shot aim while defender is within contest radius
- Timing window is tighter than open shot window
- Release is intentionally late or poor
- Ball misses after realistic rim/backboard interaction
- Rebound mode begins
- Closest players pursue rebound
- Defense secures rebound
- Opponent sim consumes time, possibly scores
- New human possession begins in reset formation

## Scenario 3: Bad cross-court pass turnover
- Start in default formation
- PG holds slightly too long or dribbles into a compromised angle
- User taps opposite-side corner through a defender lane
- Pass begins
- Defender reads/intercepts the pass
- `STEAL!` feedback appears
- Opponent sim runs
- Score/time update
- New human possession resets to PG

---

# 24. Manual pre-release test checklist

Before marking the project ready, run this manual checklist:

1. Launch project to main menu
2. Start Game enters match immediately
3. Portrait layout is correct and readable
4. HUD banner shows `HOM`, timer, pause, `AWY`
5. Virtual joystick moves the ballhandler in all directions
6. Multitouch works: hold joystick with one touch and pass/shoot with another
7. Tapping teammates passes correctly and transfers control
8. Holding and dragging on the ballhandler enters shot aim and slow motion
9. Ballhandler cannot move during shot aim
10. Trajectory dots render and update during aim
11. Green/yellow/red timing feedback updates live
12. Shot release produces believable arc
13. Rim and backboard collisions work
14. Makes update the score correctly
15. Misses enter rebound mode
16. Offensive rebound continues play
17. Defensive rebound triggers opponent sim and reset
18. Bad pass can be intercepted
19. Stationary pressure can cause turnover
20. Out-of-bounds causes turnover
21. Pause stops gameplay and clock
22. Resume works cleanly
23. Game ends cleanly at timer expiration
24. Restart works and fully resets everything
25. Logs are written and readable

---

# 25. Persistent documentation requirements

As you build, maintain these files so later LLM loops inherit context:

- `docs/DECISIONS.md`
  - architecture decisions
  - control rules
  - physics choices
  - tradeoffs

- `docs/WORKLOG.md`
  - milestone-by-milestone summary of what was done

- `docs/KNOWN_ISSUES.md`
  - bugs not yet fixed
  - edge cases
  - polish backlog

- `docs/TEST_RESULTS.md`
  - latest test suite status
  - scenario pass/fail summary
  - balance metrics

- `AGENTS.md`
  - engine/version
  - how to run
  - how to run tests
  - important repo conventions
  - subsystem ownership notes
  - rule: when ambiguous, prefer the simplest working version and expose tuning in config

These files matter. Do not leave them empty.

---

# 26. Build order

Use this implementation order unless a better dependency-aware order is obviously superior:

1. Create project skeleton, docs, config resources, and state machine
2. Create court, hoop, ball, default teams, and possession reset
3. Implement joystick movement and ballhandler ownership
4. Implement tap pass and control transfer
5. Implement shot aim entry, slow motion, and drag math
6. Implement ball simulator and trajectory preview
7. Implement rim/backboard collisions and scoring
8. Implement top HUD, timer, pause, and end game
9. Implement offensive routes and spacing
10. Implement man-to-man defenders and contests
11. Implement pass interception, steals, and blocks
12. Implement rebound mode and rebound resolution
13. Implement opponent possession sim and score/time updates
14. Implement debug overlay and structured logging
15. Implement scenario runner, bot pilot, pure logic tests, and balance tests
16. Tune until the game is playable, fair, and stable

Do not leave testing until the very end.

---

# 27. Definition of done

The project is not done until all of the following are true:

1. The game boots to a start screen and starts a playable match.
2. The player can move, pass, shoot, score, miss, rebound, and turn the ball over.
3. The ball arc, hoop collisions, and score detection work reliably.
4. The player sees live trajectory dots and slow motion during shot aim.
5. Offensive teammates run 3 simple route packages continuously.
6. Defenders guard man-to-man and can contest, intercept, block, and rebound.
7. Opponent possessions are simulated and logged.
8. The HUD shows HOM score, AWY score, timer, and pause.
9. The game ends cleanly at 3 minutes and can restart.
10. The test suite exists and covers the main mechanics and edge cases.
11. Logs and docs are written clearly enough for future debugging by another LLM loop.
12. There are no major soft locks, no duplicate score-count bugs, and no obvious broken state transitions.

---

# 28. Final implementation philosophy

Build the simplest complete version that feels good and is easy to debug.

Prefer:
- explicit state
- modular code
- deterministic logic where helpful
- config-driven tuning
- repeatable tests
- readable logs
- mobile clarity

Avoid:
- overengineering
- hidden magic
- giant god classes
- fragile one-off scripts
- untestable randomness
- postponing testing

Start building now.