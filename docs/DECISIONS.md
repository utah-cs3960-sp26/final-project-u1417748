# Decisions

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

The earlier hold-to-release meter was replaced again so the user can play with one thumb more cleanly. A quick tap-release now arms `SHOT_AIM`, starts the committed shot animation immediately, keeps gameplay at `1.0x`, and shows a one-way timing bar. The player then taps anywhere to lock the result. If the tap lands in green the shot is guaranteed, if it lands in red the shot misses or can be blocked, and if no tap arrives before the bar ends the result is a forced late miss. The existing authored release-frame gate remains in place after timing lock so the world ball still launches off the animation, not off the screen tap itself.

### Release-to-pass now pairs with quick tap shot entry

The flick-distance and release-speed pass gate was too aggressive and made passing and shooting blur together in an unhelpful way. The current control truth keeps the same lower-zone anchor and live pass-preview lock, but release arbitration is now simpler: a quick tap arms `SHOT_AIM`, center release after a real drag cancels to idle, off-center release with a locked teammate passes immediately, and off-center release with no lock does nothing. Lower-zone taps only arm a shot if the touch never becomes a real drag, and gameplay taps are routed through unhandled input so HUD controls like pause keep precedence over shot arming.
