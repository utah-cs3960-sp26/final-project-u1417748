# PROJECT_BRIEF.md

## Working title

**Working Title:** Untitled Vertical Basketball  
This is a temporary internal title. The shipped project must use an original name and original branding.

---

## Project overview

This project is a **portrait, retro, arcade-style, offense-only basketball game** built for a class demo, with enough technical quality and structure to be extended later for Android and iOS publishing.

The game is designed around a fast loop:

1. start the game quickly
2. control the offense only
3. dribble, pass, and shoot toward the hoop at the top of the screen
4. resolve makes, misses, rebounds, steals, and turnovers quickly
5. simulate the opponent possession automatically
6. jump back to the player’s next offensive possession

The result should feel like a pocket arcade sports game: easy to pick up, fast to replay, and satisfying in short sessions.

---

## One-sentence fantasy

A quick-to-play casual pocket basketball game where the player only controls offense in a vertical retro court, keeping every possession fast, readable, and satisfying.

---

## Why this game exists

This project is being built under a constraint: an LLM-driven coding loop should be able to produce a complete, playable system as early as possible. Because of that, the design intentionally narrows the scope to a tight loop that still shows off meaningful gameplay and technical depth.

The design avoids large systemic surfaces such as live defense, full basketball rules, complex menus, deep progression, or online systems. Instead, it focuses attention on the highest-value gameplay pillars:

- satisfying shot input
- believable ball arc and rim interaction
- quick passing and spacing decisions
- simple readable teammate movement
- fast possession turnover through simulation
- strong debug visibility and testability

---

## Target deliverable

The first deliverable is a **class-demo-ready playable prototype**.

That prototype must:
- be fun enough to demonstrate
- clearly communicate the game’s core idea
- look cohesive even with placeholder art
- support repeated play without soft-locking
- be built cleanly enough that it can later be extended into a publishable mobile title

---

## Target platforms

Primary development target:
- mobile-first portrait game design

Immediate goal:
- class demo build

Future-friendly target:
- Android
- iOS

The architecture should support later export and polish, but the current priority is a clean playable prototype.

---

## Audience

The intended audience is broad casual players who want:
- a quick basketball-flavored game session
- intuitive touch controls
- arcade immediacy instead of deep simulation
- a simple “one more game” loop

This is not aimed at players who want a full sports-management or realism-heavy basketball simulator.

---

## Core pillars

### 1. Fast
The game should start quickly and keep possessions short.  
Dead time is the enemy. Opponent possessions are simulated specifically to preserve pace.

### 2. Readable
The player should always understand:
- where the hoop is
- who they control
- who is open
- what input to use
- why a shot went in or missed
- when possession changed

### 3. Satisfying
The shooting mechanic is the emotional center of the game.  
Pulling back, seeing the arc, releasing at the right moment, and watching the ball interact with the rim should feel good.

### 4. Mobile-native
The game should feel designed for thumbs:
- joystick in the lower portion of the screen
- tap passes
- hold-drag shooting
- portrait orientation
- minimal UI clutter

### 5. Contained scope
Every system should support the class demo without opening huge complexity traps.

### 6. Debuggable
Because this project is being built by an autonomous coding loop, it must produce:
- clear logs
- deterministic test scenarios
- scenario replay support
- explicit system docs

---

## Core gameplay loop

A typical loop looks like this:

1. The app opens to a minimal start screen.
2. The player taps **Start Game**.
3. A 3-minute match begins.
4. The human starts on offense with the point guard holding the ball.
5. The player moves with the joystick, taps teammates to pass, or holds and drags from the ballhandler to shoot.
6. Off-ball teammates continuously move through simple route packages while defenders guard them man-to-man.
7. The player tries to create an open look and release the shot well.
8. The ball follows a live arc with rim/backboard interaction.
9. If the shot misses, nearby players try to rebound.
10. If the offense gets the rebound, live play continues.
11. If the defense gets the rebound, or if a turnover occurs, the opponent possession is simulated automatically.
12. The game jump-cuts back to the next human offensive possession.
13. The loop continues until the 3-minute clock reaches zero.

---

## Hard MVP

The MVP is complete only when all of the following are playable and stable:

- title/start screen exists
- match starts immediately from the menu
- 5 offensive players are on court
- 5 defensive players are on court
- the human controls the current offensive ballhandler
- the ballhandler can move with a virtual joystick
- tapping a teammate passes the ball to that teammate
- holding and dragging from the ballhandler enters shot aim
- shot aim slows time to half speed
- shot aim shows predicted trajectory dots
- shot direction and power come from the drag input
- the shot uses live 2D + z-height ball motion
- the ball can hit the rim and backboard
- the system can detect a made basket correctly
- the score updates correctly
- missed shots can create live rebounds
- defenders can intercept bad passes
- defenders can contest or block shots
- offensive teammates run three simple route packages
- defenders guard their assigned matchup in pure man-to-man
- the black top HUD banner shows HOM, timer, pause, and AWY
- the opponent possession can be simulated and logged
- the match ends cleanly at 0:00
- the match can be restarted cleanly

---

## Explicit non-goals for v1

The following are intentionally out of scope and should not absorb build time:

- live defense controlled by the human player
- full inbound rules
- fouls
- free throws
- travel
- backcourt
- goaltending
- jump balls
- overtime
- advanced coaching/tactics systems
- audio and music
- save data
- progression or franchise mode
- unlocks
- monetization
- ads
- sign-in
- leaderboards
- online multiplayer
- real teams, leagues, players, or copyrighted branding

---

## Match structure

### Match length
- 3 minutes total
- countdown clock
- no shot clock

### Scoring
- 2-point and 3-point shots both exist
- shot value is determined from the shooter’s position at release
- the 3-point line is configurable

### End of game
- when the timer reaches zero, the current live shot and immediate rebound resolution may finish
- after that, the game ends
- a final score screen appears
- restart must be available

---

## Court model and camera

The game uses:
- portrait orientation
- half-court only
- fixed camera
- hoop at the top center
- lower portion of the screen reserved for joystick/input comfort
- top banner HUD above the court

The world is fundamentally 2D for players, but the ball uses simulated z-height for:
- arcs
- rim interaction
- backboard bounces
- blocks
- rebound feel

This gives the game a 2.5D presentation while keeping the implementation tractable.

---

## Control scheme

### Movement
- the current ballhandler is moved with a virtual joystick
- the joystick sits in the bottom third of the screen
- directional input is immediate and analog-like

### Passing
- tapping a teammate passes directly to that teammate
- passes are straight-line passes
- catches transfer control to the receiving player

### Shooting
- press and hold on the ballhandler
- drag away from the ballhandler to aim and charge the shot
- the launch direction is 180 degrees opposite the drag direction
- the farther the drag, the greater the shot power
- while aiming:
  - the player cannot move
  - time slows to 0.5x
  - trajectory dots appear
  - shot timing quality is shown through color

### Shot/pass arbitration
If the player is in shot aim and releases:
- inside a teammate catch radius -> convert to pass
- otherwise -> launch shot

This keeps the input system compact while still allowing expressive play.

---

## The shot mechanic

The shot mechanic is the heart of the project.

It must deliver:
- immediate visual clarity
- satisfying drag-to-release feel
- readable trajectory
- convincing arc
- believable rim and backboard interaction
- meaningful timing skill

### Timing model
While holding the shot:
- a timing window is active
- the ideal release is the middle of that window
- closer defenders make the window tighter
- better shooters make the window more forgiving or stable

### Feedback model
Line color during aim shows the current release quality if the player releases now:
- green = excellent
- yellow = okay
- red = poor

### Outcome model
Release quality changes the actual shot launch parameters, not a hidden post-release make/miss roll.  
This means shot outcomes should come from:
- player position
- drag vector
- release timing quality
- player ratings
- defender pressure
- ball flight
- hoop interaction

---

## Ball physics and hoop interaction

The ball uses:
- x/y position on the court plane
- z height above the plane
- x/y velocity
- z velocity
- gravity
- controlled collision response against rim and backboard

The goal is not perfect realism. The goal is:
- arcade believability
- consistency
- tuning control
- readable trajectory preview
- satisfying makes and misses

Scoring is only counted when the descending ball passes through the basket bounds in a valid way, and only once per shot.

---

## Offensive team behavior

The human always controls the offensive player who currently has the ball.

The other four offensive players continuously move through simple route packages intended to:
- create openings
- provide passing targets
- preserve spacing
- prevent everyone from bunching together

The three route families are:

### Wing Swap
The two wings exchange sides while the corners make slight supporting adjustments.

### Strong-Side Slash
The wing on the same side as the ball cuts toward the middle and exits while the other players refill space.

### Weak-Side Fill
The weak-side players move through and refill wing/corner space to maintain motion and spacing.

The offense does not need advanced basketball IQ for v1. It needs to be readable, dynamic, and good enough to create openings.

---

## Defensive behavior

Defense is intentionally simple in structure:
- pure man-to-man
- one defender assigned to one offensive player for the possession
- no switching in v1

Defenders should be able to:
- stay with their matchup
- contest nearby shots
- intercept risky passes
- attempt steals in bad situations
- attempt blocks when positioned well
- pursue rebounds

Different defenders should feel meaningfully different through ratings, not through giant behavior trees.

---

## Rebounds and possession change

After a missed shot:
- live rebound mode begins
- nearby players pursue the rebound area
- if the offense gets it, live offense continues immediately
- if the defense gets it, opponent possession is simulated

After:
- made baskets
- defensive rebounds
- steals
- bad-pass interceptions
- out-of-bounds turnovers

the game should:
1. simulate the opponent possession,
2. update score and time,
3. reset to a new human offensive possession.

---

## Opponent possession simulation

Opponent possessions are off-screen and simulated to preserve the fast arcade rhythm.

The simulation should:
- use the current on-court player ratings
- consume clock time
- allow makes, misses, turnovers, offensive rebounds, and second-chance points
- log what happened
- vary by difficulty

The simulation is a pacing tool, not a replacement for the game’s main live mechanic, which is the human offensive possession.

---

## Ratings schema

Use a 0–100 scale.

Each player should have at least:
- speed
- acceleration
- handle
- pass accuracy
- catch
- shooting
- release consistency
- perimeter defense
- steal
- block
- rebound
- sim offense

These ratings must meaningfully affect both live systems and the opponent sim.

---

## Difficulty

At minimum:
- Easy
- Normal
- Hard

Default:
- Normal

Difficulty should affect:
- defender tightness
- interception pressure
- block/rebound effectiveness
- opponent sim efficiency

It should not fake human shot outcomes after release.

---

## Visual direction

The presentation should feel retro and pixel-inspired:
- chunky readable sprites
- limited palette
- clear silhouettes
- bold outlines
- arcade energy
- minimal clutter

It does not need to literally run at low resolution, but it should evoke a pixel-era sports game feel.

Placeholder art is acceptable as long as it is:
- original
- coherent
- readable
- license-safe

Simple shadows under players and subtle ball scaling should help sell depth.

---

## UI requirements

### Start screen
Must include:
- game title or placeholder title
- Start Game button

### Top banner
The black top HUD banner must show:
- left: `HOM` and home score
- center: countdown timer and pause button
- right: `AWY` and away score

### Pause
Pause must allow:
- resume
- restart
- optionally return to menu

### End of game
Must show:
- final score
- winner
- restart option

### Feedback text
At minimum:
- `STEAL!`
- `SWISH!`
- `BRICK!`

---

## Persistence and services

None required in v1:
- no save data
- no settings persistence
- no online systems
- no telemetry
- no monetization

---

## Design priorities if time slips

If time pressure forces scope triage, preserve systems in this order:

1. shot mechanic quality
2. live ball arc and hoop interaction
3. passing and control transfer
4. scoring and timer
5. rebound loop
6. opponent sim
7. basic route-running
8. defensive contest/interception behavior
9. polish

Never cut the shot mechanic to save minor polish work.

---

## Success criteria

This prototype is successful if:
- it is immediately understandable to a first-time player
- it can be played from start to finish without breaking
- the shot mechanic feels deliberate and satisfying
- the offense-only loop feels fast and replayable
- teammates move enough to create choices
- defense creates pressure without making scoring impossible
- the opponent sim keeps the match moving
- logs and tests make the project maintainable by future LLM loops

---

## Primary risks

### Risk 1: The shot mechanic feels bad
Mitigation:
- prioritize it early
- keep physics controlled
- expose tuning values
- build preview and tests early

### Risk 2: AI movement becomes messy or crowded
Mitigation:
- use simple route anchors
- keep spacing rules numeric and tunable
- favor readability over complexity

### Risk 3: State transitions become fragile
Mitigation:
- explicit state machine
- centralized transitions
- scenario tests for all major transitions
- logging

### Risk 4: Randomness makes debugging difficult
Mitigation:
- deterministic seed mode for automated tests
- structured logs
- scenario replay support

### Risk 5: The project becomes too large
Mitigation:
- protect the MVP
- keep non-goals out
- avoid speculative systems

---

## Final product statement

This project is a tightly scoped, offense-only, portrait basketball arcade game whose demo value depends on one thing above all else: making shooting, passing, spacing, and quick possession flow feel good immediately.

Everything in the project should support that goal.
