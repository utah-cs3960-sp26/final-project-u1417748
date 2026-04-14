# Decisions

## 2026-04-14

### The visible control panel now uses a split `SHOOT | DUNK` top row and the scoreboard lives above it

The first visible-panel pass replaced the old open-screen gestures, but its three-row layout still made `DUNK` travel farther than `SHOOT` and kept the scoreboard occupying the top edge of the screen. The current contract keeps the same bottom-third overlay and the same bottom `PASS | MOVE | PASS` row, but collapses the action row into a single exact `50/50` top split: top-left `SHOOT`, top-right `DUNK`. The removed bottom dunk strip does not keep any hitbox of its own; that reclaimed height goes into the new top row so both finish buttons read larger and faster to hit. The responsive HUD contract also changes here: `banner_rect` now means a compact scoreboard card anchored just above the left `SHOOT` half, not a full-width top banner. `Show Controls` remains presentation-only and hides only the panel art, not the relocated scoreboard. This was chosen to reduce thumb travel, keep shot and dunk options visually paired, and return the upper screen to gameplay instead of HUD chrome.

### The control panel now biases space toward movement instead of the action buttons

After the top-split pass, the action buttons still consumed too much of the bottom-third overlay relative to how often the player needs to steer. The current tuning trims the `SHOOT | DUNK` row down to two-thirds of its previous height, gives that reclaimed height to the bottom `PASS | MOVE | PASS` row, and also narrows each `PASS` lane to two-thirds of its previous width so the center `MOVE` lane inherits the freed width. This keeps the control scheme unchanged while making movement the largest touch target in the panel, which better matches actual play frequency and reduces accidental pass or finish selection during thumb repositioning.

### Action buttons now work as direct taps, including with a second finger during movement

The panel originally still required the primary movement gesture for every live-offense action, which made the visible buttons read like labels more than real controls. The current contract keeps drag-release actions intact, but also lets `PASS`, `SHOOT`, and `DUNK` fire as direct button taps even when no move drag is active. Because that tap path is independent from the movement pointer, a second finger can press any action button while the first finger keeps dragging in `MOVE`. The shot meter was widened at the same time so it spans the full top `SHOOT | DUNK` row instead of only the `SHOOT` half. This was chosen to make the visible panel behave like an actual touch control surface, improve readability, and reduce the amount of thumb travel needed to trigger shot timing.

### Control-panel buttons now stay neutral until hovered or pressed

The earlier visible-panel art still baked the action colors into every button all the time, which made the interface feel busy and reduced the value of the active-zone highlight. The current contract changes every visible button zone to the same dark neutral idle base `#1b1d3a`, then swaps only the active zone into its authored action color while a live drag is hovering over it or while that button is being pressed directly. Direct taps now also carry a short-lived pressed highlight so the button visibly flashes even when the action fires immediately. This was chosen to make active intent easier to read at a glance without changing the underlying control mapping.

## 2026-04-13

### Dunk rows now start from a distance-resolved visible frame instead of always restarting at frame 1

The frame-locked dunk motion pass still assumed every dunk replayed its full authored approach from frame `1`, which made short-distance finishes waste extra run-up frames and feel less responsive than the player's real position warranted. The current contract keeps the committed dunk family and row the same, but resolves an `approach_start_frame` from `distance_to_hoop` before the dunk row begins. Rows `13`, `15`, and `16` now share two authored thresholds in `PlayerAnimationConfig`: `90.0` starts directly on the jump frames, `120.0` preserves exactly three run frames, and distances out to the dunk radius blend back toward the full frame-`1` approach. `GameCoordinator` carries that start-frame choice through the active shot sequence and uses it to remap only the visible approach motion into the same configured contact and landing anchors. A small comparison epsilon is applied around the authored distance thresholds so diagonal side-dunk geometry that should sit exactly on the `90` or `120` cutoffs does not flip buckets because of floating-point drift. This was chosen to make dunks feel smarter and more alive without introducing hard, visibly discontinuous buckets or retuning the existing contact / landing anchors.

### Dunk approach, contact, and landing now all follow one frame-locked coordinator root-motion contract

The single-anchor freeze placement fix made the dunk hold deterministic, but the surrounding authored frames still let the player stand still while the animation advanced. The current contract moves the entire dunk sequence into one coordinator-owned root-motion path that follows the actual rendered frame number. Rows `13`, `15`, and `16` now define authored run-end, jump-end, contact-end, and landing anchors in `PlayerAnimationConfig`; `GameCoordinator` uses those values to move the shooter from the release-start world position into the contact anchor, pin the authored contact frames exactly on that anchor, and then ease the player back down to a grounded landing anchor while the ball is already in flight. `PlayerVisual` only reports frame progress now; it no longer owns any hold-only placement correction. This was chosen so the pre-dunk run, airborne approach, rim hang, and landing all read as one seamless motion, while still leaving the freeze and landing positions easy to tune from config.

### Dunk freeze placement now uses one row-specific root anchor per authored hold row

The earlier dunk-hold contract split freeze placement across two systems: `GameCoordinator` snapped the player root to one shared hoop-relative world anchor, and `PlayerVisual` then added a second row-specific local sprite translation only while the rim-contact hold was active. That made the final pose harder to reason about and harder to tune because there was no single authored value that meant “row `13` frame `10` goes here.” The current contract removes the hold-only sprite translation entirely. Rows `13`, `15`, and `16` now each own one authored world-space contact anchor in `PlayerAnimationConfig`, and `GameCoordinator` snaps the shooter root directly to that row-specific anchor when the hold starts. This was chosen to make dunk freeze placement deterministic and to expose one clear manual tuning knob per hold row.

## 2026-04-07

### Built clean-room on `main`

The implementation was created directly on the docs-only branch instead of reusing `smart-version` or `deep-version`. This keeps the delivered code aligned with the explicit clean-room requirement.

### Single authoritative coordinator

Global match state is owned by `GameCoordinator` alone. No gameplay singleton was added. This keeps transitions explicit, logged, and easier to test.

### Pure logic controllers for risky gameplay math

Shot timing, pass interception, ball motion, hoop checks, rebound selection, and opponent sim all live in small `RefCounted` controllers. This keeps the highest-risk systems headless-testable.

### Resource-backed tuning everywhere practical

All major feel values are loaded from `data/config/*.tres`. Runtime code only falls back to script defaults when a resource is missing.

### Deterministic scenario hooks were added deliberately

The automated scenario suite uses explicit coordinator test hooks for edge cases like buzzer resolution, forced steals, and rebound outcomes. This avoids brittle editor-only input choreography while keeping the shipped runtime path clean.

### Balance shot bands use a statistical probe, not full hoop resolution

The balance batch for green/yellow/red rates uses launch-output-derived probabilities instead of the live rim resolver. The live game still uses full simulated ball flight. The batch exists to monitor tuning bands, not to replace runtime scoring.

### Rebound batch fixture was re-centered

The first rebound batch geometry was unrealistically defense-favored. The fixture was adjusted to a more plausible near-rim scrum rather than distorting live rebound tuning to satisfy a bad test shape.

### Godot validation target

The project is authored for Godot 4.6.x and validated locally with 4.6.1 because that is the installed binary in this environment.

### Shot feel favors a floaty arcade arc over a hard launch

The shot system now uses separate forward and vertical growth curves. Horizontal speed ramps slowly, vertical lift ramps aggressively, and the preview begins as a weak starter shot in front of the player. This was chosen to make shot intent readable immediately and to match the requested casual, exaggerated feel.

### Low top-down angle is implemented as a render-only projection

Gameplay, AI, ball physics, hoop resolution, and authored scenarios still operate in a flat world-space court plane. A shared `CourtProjection` layer now handles player, ball, hoop, preview, debug, and input mapping in screen space. This keeps risky game math stable while allowing a stronger camera angle and screen-faithful interaction.

### Shot control changed from drag aim to hold-and-release meter

At this stage of development, the shot interaction no longer used opposite-drag aiming or a live trajectory preview. Holding on the current ballhandler entered slow-motion shot aim and showed a bottom timing meter made of rectangular red and green zones. Releasing in green guaranteed a make; releasing in red caused a miss or a contest-driven block. This was the control truth for the repo at that time and was later superseded by the one-thumb armed shot-timing flow documented below.

## 2026-04-08

### Gameplay is now the default boot target

The project no longer uses a runtime start screen. `GameRoot.tscn` is now the default `run/main_scene`, and pause/game-over overlays expose `Quit Game` instead of routing back to an otherwise dead menu scene. This keeps manual layout checks and headless smoke validation focused on the actual gameplay screen.

### Green meter releases are now absolute

The green meter chunk is now fixed authored geometry and no longer shrinks based on contest or shooter ratings. If the indicator lands in green, the shot always scores and cannot be blocked or downgraded after release. That guarantee is now enforced by the staged guided-make solver and simulator-owned descent path instead of by letting a widened forced-score flag rescue a bad flight late. Defense still matters only on red releases. This was changed to make the hold meter easier to read and to match the explicit "green always goes in" rule.

### The court presentation now uses an explicit half-court crop

The rotated court render no longer guesses at a narrow atlas slice. `CourtView` now treats the blue second-court art as a full source region and applies an explicit left-half crop before projecting it into portrait space. This keeps the active painted hoop area aligned with the single live top hoop while preserving the existing court/world geometry and projection math.

### The pseudo-perspective camera was flattened into a rectangular court view

The earlier projection pass made the court read like a tapered trapezoid, which hurt readability more than it helped. The shared `CourtProjection` system stays in place, but its authored defaults now flatten the court into a true rectangle with constant width and linear depth mapping. This keeps input, debug overlays, and ball-height rendering consistent while removing the stretched perspective feel.

### Player readability wins over showing more empty floor

The character sprites are now deliberately much larger and the default framing is slightly tighter. This was chosen to make the controlled player, nearby defenders, and held ball much easier to read in portrait mode, even if it means showing a little less empty court at once.

### Cinematic shots now use apex-driven launch profiles

The old fixed-time shot solver was replaced with an apex-driven launch builder that solves for minimum airtime and minimum apex by distance, then derives horizontal velocity from that longer vertical profile. Shots now launch from above the floor, hang in the air longer, and read as a deliberate arcade parabola instead of a fast line drive to the rim.

### The meter keeps control truth, but live preview dots are back

At this stage of development, the repo still used the hold-to-release meter as the only shot input. A live trajectory preview was restored as presentation, not aiming control: green preview dots showed the guaranteed make path, while red preview dots showed the deterministic miss path that would be launched if the player released on that frame. A stable aim-time miss variant was held from aim start through release so preview and live flight stayed aligned.

### Hoop occlusion is render-only and follows explicit phases

Made-shot legality still belongs to `HoopResolver`, but the render layer now treats the hoop as a layered visual stack with explicit backboard, rim-mouth, net-channel, and emerged phases. Normal makes should read in front of the backboard, meet the rim at the handoff point without an authored hover, then pass behind the hanging front net during the guided descent, and only move behind the board when the ball genuinely goes over it. This was added to make the scoring visual understandable without changing basket rules.

### Deterministic validation now uses a fixed 60 Hz coordinator step

Scenario and smoke harness runs now clamp `GameCoordinator` test mode to a fixed `1/60` frame step instead of trusting wall-clock `delta`. The new hoop follow-through timing exposed how fragile the old real-time progression was in headless runs. This keeps scenario waits, clock assertions, and short post-score holds stable without affecting normal gameplay, because the fixed step only applies when deterministic test mode is enabled.

### A counted make must enter the front half of the net

Green releases still remain guaranteed makes, but that guarantee no longer comes from a widened `rim_radius` scoring loophole. The shared score contract is now stricter: a basket only counts when the descending ball crosses the rim plane inside the inner score radius and on the front half of the hoop. The green shot solver was retargeted to a front-half net entry point so the visual path and the legal score path match.

### Green makes now use simulator-owned guided descent instead of forced scoring

The earlier fix still allowed green makes to be “saved” too late by a coordinator-owned visual follow-through after an otherwise bad free-flight path. That is no longer the contract. Green releases now solve a staged make profile up front, the live simulator owns the capture into the rim and the downward net descent, and the score only resolves when the simulator crosses the planned guided-descent gate. This was chosen to eliminate counted makes that still rendered above the rim or behind the backboard.

### The make arc now hands off on the rim plane, not above it

The first guided-make rewrite still let the arc terminate above the rim before the simulator dropped the ball into the net. That still read like a hard downward pop. The handoff point is now on the rim plane inside the legal front-half cylinder, with no authored hover. The next visible motion after the arc finishes is already downward into the net, and the score does not appear until that descent has begun.

## 2026-04-09

### Shot release is now animation-gated and the world ball stays hidden while possessed

The old visual contract still rendered the standalone `BallController` on the handler hand even though the new character rows already drew the ball inside the sprite sheet, and shots still launched on the exact input-release frame before the release animation had actually reached the handoff frame. The current contract is staged instead. Releasing the meter now commits a shot family, variant, and mirror direction into a brief `SHOT_RELEASE` state. The world ball stays hidden during that staged beat, and the coordinator only reveals and launches it after `PlayerVisual` reports that the committed row has crossed its configured release-after-frame threshold. Passes still reveal the ball immediately on pass start, while catches, rebounds, steal resolves, and possession resets hide it again as soon as a sprite regains possession. This was chosen to stop double-ball rendering and to make jumpers, layups, and dunks read off the authored sprite timing rather than off the input event.

### Shot aim now plays the committed release row while the meter fills

The live shot meter is no longer a separate ping-pong widget that runs independently of the sprite. `SHOT_AIM` now starts the real committed shot row immediately, the bar advances in one direction only, and the tail-end green window is aligned so its end lands on the row's authored release frame. If the player releases early, the shot quality locks at that moment and the animation keeps playing to the release frame before launch. If the player keeps holding through the release frame, the game auto-fires there and forces a miss as an overhold. Row 5 remains only a fallback hold pose for non-committed cases, not the main live shot-aim animation.

### Committed shot rows now all play at 15 FPS

The synced-windup rewrite still left shot presentation with mixed authored playback rates, which made some rows visibly spurt faster when the sequence moved from windup into release/followthrough. The committed shot families now all use a single 15 FPS cadence for aim, staged release, and followthrough. Release timing still comes from the same row-specific frame thresholds; only the seconds-to-release and full animation duration are recomputed from the unified 15 FPS source of truth.

### Pass steals now use a commit roll plus a visible live-ball race

The earlier interception rewrite fixed the presentation problem by making the ball flight authoritative and resolving catches or steals on the live ball, but it also made any lane-eligible defender feel too sticky because commitment was automatic. The current contract is hybrid. Each pass still identifies one best eligible defender by lane ETA, but that defender only gets the visible lane-cut override after a seeded commit roll based on pass geometry, defender pressure, passer accuracy, receiver catch security, and the current difficulty defense multiplier. Once a defender commits, the rest of the play stays visually honest: the ball keeps traveling on the same straight segment, the receiver breaks to the release-time catch point, the defender cuts into the lane, and the first player to the live ball wins. Ties still favor the offense on the claim frame, and steals still enter a short `STEAL_RESOLVE` state before the opponent sim jump-cut.

### Court framing now preserves full-height art instead of stretching or hard-half cropping

The court no longer relies on a fixed half-court crop that happens to fit the current portrait viewport. `CourtView` now treats the full rotated blue second-court region as the source, scales it to fill screen height without stretching, and crops only the extra width with a consistent offensive-side bias. This keeps the live hoop aligned to the existing world anchor while using the unused opposite-side art to fill vertical phone screens naturally.

### One-thumb lower-zone gestures replace the visible joystick and teammate tap-pass flow

At this stage of development, the shipped mobile control truth became a lower-screen invisible movement zone with a temporary thumb anchor, dead-zone filtering, flick-to-pass, and pre-release pass-target preview. The old visible joystick and tap-teammate pass path were retired from the runtime mobile flow. This was later refined again by the release-to-pass and tap-to-arm rules documented below.

### `SHOT_AIM` now means armed tap timing at normal speed

The earlier hold-to-release meter was replaced again so the user can play with one thumb more cleanly. A strong upward swipe that finishes in the top half of the screen now arms `SHOT_AIM`, starts the committed shot animation immediately, keeps gameplay at `1.0x`, and shows a one-way timing bar. The player then taps anywhere to lock the result. If the tap lands in green the shot is guaranteed, if it lands in red the shot misses or can be blocked, and if no tap arrives before the bar ends the result is a forced late miss. The existing authored release-frame gate remains in place after timing lock so the world ball still launches off the animation, not off the screen tap itself.

### Tap-to-pass now replaces release-to-pass

The release-to-pass flow still made passing and shooting compete for the same gesture ending, which made portrait one-thumb play harder to read than it needed to be. The current control truth separates them cleanly: a quick tap now passes, an empty tap uses the currently marked default teammate, and tapping a teammate directly overrides that default target. Lower-zone taps still count as pass taps if they never become a real drag, and empty taps with no valid default target safely do nothing.

### Upward swipe shot entry now wins over movement release

Tap-to-arm shot timing collided with the new tap-to-pass flow, so shot entry moved onto a distinct gesture. A strong upward swipe that ends in the top half of the screen now arms `SHOT_AIM`, including swipes that begin inside the lower movement zone. Movement still updates while the finger is down in that lower zone, but a qualifying upward swipe on release wins over the normal movement-stop behavior. Downward swipes, upward swipes that never reach the top half, horizontal drags, and short drags do not arm a shot.

### AI movement now eases into short corrections instead of snapping

The earlier off-ball offense and defense logic updated their targets every frame but still moved with direct velocity snaps, which made tiny guard recoveries and route-spacing corrections read as jitter rather than intent. The current contract keeps the same long-run pace, but AI-only movement now uses arrival steering with explicit arrival/stop radii, centerline hysteresis for strong-side and weak-side route selection, and a small defensive deadband around the guard spot. This was chosen to clean up motion readability without softening the player-controlled ballhandler.

### The light-blue teammate ring is now the persistent default pass marker

The earlier desktop defaults booted with the debug overlay visible and teammate catch rings rendered in light blue, while the actual gameplay pass preview used a separate yellow marker. That made normal play look noisy and made the real pass lock harder to read. The current contract flips that: normal boot hides the debug overlay, teammate catch rings stay behind the debug toggle, and the only gameplay ring shown by default is the light-blue ring on the coordinator-ranked default pass target. That target is recomputed from projected interception commit chance, pass distance, and hoop proximity, and it stays visible throughout `LIVE_OFFENSE` until a shot or pass begins.

### Authored dunk rows now hang on the rim before the world ball releases

The staged `SHOT_RELEASE` gate fixed double-ball launches, but rows `13`, `15`, and `16` still looked wrong because the committed dunk animation handed off into the same upward shot arc used by jumpers. Those close-finish rows now define a second authored milestone: a rim-contact frame plus a per-row contact offset. After the shot result is already locked, the coordinator waits for that contact frame, freezes the sprite there for `0.5` seconds, keeps the world ball hidden during the hang, and only then commits the release. Made dunks start directly at the rim entry point and drop through the hoop via guided descent, missed dunks start at the rim and bounce upward and away, and blocked dunks still resolve immediately through the existing block path without entering the hang. This was chosen to make dunk presentation read off the authored contact pose instead of reusing a jumper-style arc, while preserving the existing shot-meter timing and release-frame semantics.

### Close-finish family selection now uses explicit dunk gates and an explicit dunk rating

The older near-rim chooser mixed presentation and eligibility together, which let defender-space heuristics bleed into the family choice and made some guards reach dunk rows too easily once they were moving at the hoop. The current contract splits the decision into two stages. First, the player must qualify for the close-finish family at all by being inside the layup radius, moving toward the hoop, and carrying the normal finish-momentum speed. Second, dunk selection only happens if that same attempt is also inside the stricter dunk radius, above the higher dunk-speed threshold, and backed by a roster `dunk` rating at or above the dunk minimum. If any dunk-only gate fails, the attempt falls back to layup instead of jumping to a non-close jumper row.

Defender pressure is intentionally excluded from this chooser so the selected family stays deterministic and role-readable. Defense still matters afterward: once a dunk is already committed, the new `dunk` rating reduces only that dunk's block chance through a dunk-only multiplier, while layups and jumpers keep the existing block formula unchanged. This was chosen to make finish selection predictable from player archetype and geometry without mutating the existing shot-timing or general shot-outcome rules.

### The live hoop now sits farther back at the top of the court, and the 3PT radius moves with it

The previous hoop anchor still left the basket too far inside the painted area. The current contract moves the real hoop geometry back to `Vector2(540, -50)` and the backboard plane to `y = -120`, so the pole, board, rim, and net all sit above the court together instead of faking that move with a support-only offset. Because that also changes every hoop-distance-based rule, the three-point radius expands to `840`, the layup radius to `550`, and the dunk radius to `485` so on-court shot values and close-finish access still behave like they did before the relocation. `CourtProjection` also no longer clamps world points above the court top back to the horizon, which is what previously made negative hoop coordinates appear stuck.

## 2026-04-10

### Live dunks now bypass the timing meter and auto-finish

The staged dunk presentation looked right, but the remaining tap-to-time requirement still made dunks feel like mislabeled jumpers because the player had to “hit green” on a finish that was already at the rim. In the current demo phase, any shot that commits to a dunk family now skips `SHOT_AIM`, never shows the shot bar or preview dots, and immediately queues a guaranteed make tagged as `dunk_auto_make`. The authored row, rim-contact hold, hidden-world-ball contract, and guided straight-through release all stay intact; only the live timing interaction is removed. A hidden `ShotController` timer is still started so the existing animation-lock cleanup path does not regress.
