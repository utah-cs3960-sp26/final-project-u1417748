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

The shot interaction no longer uses opposite-drag aiming or a live trajectory preview. Holding on the current ballhandler now enters slow-motion shot aim and shows a bottom timing meter made of rectangular red and green zones. Releasing in green guarantees a make; releasing in red causes a miss or a contest-driven block. This change was made explicitly at the user's request and is now the control truth for the repo.

## 2026-04-08

### Gameplay is now the default boot target

The project no longer uses a runtime start screen. `GameRoot.tscn` is now the default `run/main_scene`, and pause/game-over overlays expose `Quit Game` instead of routing back to an otherwise dead menu scene. This keeps manual layout checks and headless smoke validation focused on the actual gameplay screen.

### Green meter releases are now absolute

The green meter chunk is now fixed authored geometry and no longer shrinks based on contest or shooter ratings. If the indicator lands in green, the shot always scores and cannot be blocked or downgraded after release. Runtime enforcement now continues through hoop resolution by treating green releases as forced makes until they score, instead of letting rim or backboard contact invalidate the make. Defense still matters only on red releases. This was changed to make the hold meter easier to read and to match the explicit "green always goes in" rule.

### The court presentation now uses an explicit half-court crop

The rotated court render no longer guesses at a narrow atlas slice. `CourtView` now treats the blue second-court art as a full source region and applies an explicit left-half crop before projecting it into portrait space. This keeps the active painted hoop area aligned with the single live top hoop while preserving the existing court/world geometry and projection math.

### The pseudo-perspective camera was flattened into a rectangular court view

The earlier projection pass made the court read like a tapered trapezoid, which hurt readability more than it helped. The shared `CourtProjection` system stays in place, but its authored defaults now flatten the court into a true rectangle with constant width and linear depth mapping. This keeps input, debug overlays, and ball-height rendering consistent while removing the stretched perspective feel.

### Player readability wins over showing more empty floor

The character sprites are now deliberately much larger and the default framing is slightly tighter. This was chosen to make the controlled player, nearby defenders, and held ball much easier to read in portrait mode, even if it means showing a little less empty court at once.

### Cinematic shots now use apex-driven launch profiles

The old fixed-time shot solver was replaced with an apex-driven launch builder that solves for minimum airtime and minimum apex by distance, then derives horizontal velocity from that longer vertical profile. Shots now launch from above the floor, hang in the air longer, and read as a deliberate arcade parabola instead of a fast line drive to the rim.

### The meter keeps control truth, but live preview dots are back

The repo still uses the hold-to-release meter as the only shot input. A live trajectory preview was restored as presentation, not aiming control: green preview dots show the guaranteed make path, while red preview dots show the deterministic miss path that would be launched if the player released on that frame. A stable aim-time miss variant is held from aim start through release so preview and live flight stay aligned.
