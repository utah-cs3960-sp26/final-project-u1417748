# Worklog

## 2026-04-17

### Menu screens now reuse the main-menu start background

- extracted a shared `MenuBackground.gd` helper that keeps one cached rotated court-background texture for the menu flow instead of letting each screen manage its own backdrop independently
- wired `MainMenu`, `TeamScreen`, and `SettingsScreen` through that helper so the Team and Settings pages now show the same start-page background art selection as the current main menu
- added headless smoke coverage that instantiates all three scenes and asserts the Team and Settings screens reuse the exact same background texture resource and selected source image as the main menu
- changed the opponent-sim score banner's score wrapper from `CanvasGroup` to `Control` so the current headless suite can complete on the local Godot `4.6.1` runtime instead of failing immediately on unsupported `mouse_filter` / `size` assignments
- reran validation after the menu-background pass: boot smoke passed; the full suite now reports pure logic `1802`, scenarios `18`, balance `4`, failures `6`
- the new shared-background assertions passed; the current failing checks are `guided make bounce starts only after floor contact`, `straight dunk keeps moving through the landing after launch`, `Opponent Banner Game Over`, `Opponent Banner Multi-Step Score`, `Opponent Banner One-Step Score`, and `Opponent Banner Tap Skip`

### Pause overlay now centers against the full responsive viewport

- changed `PauseOverlay` so it no longer relies on container auto-layout under `CanvasLayer`; it now resolves an explicit viewport-sized root rect and a safe-rect-scoped panel placement during the coordinator's responsive layout pass
- kept the dimmer and modal behavior the same, but moved the pause card to a deterministic centered rect so the menu no longer opens from the top-left corner on runtime pause
- raised the pause card by `100px` relative to the safe-rect center while still clamping it fully inside the visible safe area
- changed the in-match `Quit Game` path from a direct `SceneTree.quit()` call to `MainMenu.tscn`, which matches the repo's current `run/main_scene` and works for both desktop and mobile-style flows
- added smoke coverage for the pause overlay root rect, safe-rect sync, safe-area containment, raised-card positioning, and the pause quit target scene path to prevent future HUD/layout changes from regressing the pause menu behavior
- reran headless validation after the pause centering and quit-path fix: boot smoke passed; the full suite still reported the same two pre-existing followthrough failures (`guided make bounce starts only after floor contact` and `straight dunk keeps moving through the landing after launch`), while the new pause overlay and quit-target checks passed

## 2026-04-16

### Pause button mirrored to the bottom-right HUD corner

- moved the live pause control out of the scoreboard art and added a dedicated `pause_button_rect` responsive-layout slot above the right `DUNK` half, with a square footprint that matches the scoreboard card height
- replaced the old `Pause` text button with a standalone icon-only button that renders the pause symbol as two vertical bars over a bordered HUD tile using the same light text / dark outline palette as the scoreboard
- updated HUD smoke coverage and manual test guidance so the scoreboard now owns only score and clock content, while the pause button is validated independently for safe-area containment, right-edge alignment, top alignment with the scoreboard, and height parity with the scoreboard card
- reran the full headless suite after the mirrored-pause HUD pass: pure logic `1771`, scenarios `18`, balance `4`, failures `2`; the only remaining failures were the same existing shot-followthrough checks (`guided make bounce starts only after floor contact` and `straight dunk keeps moving through the landing after launch`)

### Pixeloid project font theme applied

- added `data/ui/PocketHoopsTheme.tres` as the shared project theme and set its default font to `assets/fonts/pixeloid/PixeloidSans-Bold.ttf`
- wired `project.godot` so both the custom GUI theme and project custom font resolve to Pixeloid, covering scene-authored labels/buttons and dynamically created HUD, control-panel, overlay, player-debug, and banner text through Godot theme fallback
- regenerated the missing Pixeloid imported font data locally after the first boot smoke exposed a stale `.import` reference
- validated the change with a clean headless boot and a one-off theme assertion script using an explicit `/tmp` log file

### Compact bottom controls implemented

- reduced the visible control panel height from `33%` to `24%` of the safe viewport while keeping the same bottom anchoring, two-row split, pass lanes, move lane, and direct action hitboxes
- reduced main control labels to low-30px sizing with a `34px` cap, reduced pass-focus labels to a `16px` cap, and lightened label outlines for the smaller text
- added a control-panel font-size snapshot for smoke tests and updated the layout smoke to assert compact height, bottom anchoring, preserved zone geometry, and label caps
- reran the full headless suite: pure logic `1765`, scenarios `18`, balance `4`, failures `2`; the compact-control assertions passed, with the remaining failures still limited to existing shot-followthrough checks

## 2026-04-15

### Phase-gated full lower net masks implemented

- changed `NetBody` from an always-front lower net layer into the same inactive/active through-net mask state used by `NetCleanBottomHalf`
- kept `NetBody` aligned to the same `30x28` registration transform, with inactive `NetBody` below airborne, rim-mouth, and generic `front_of_net` ball phases and active `NetBody` above `net_channel` plus made-shot net-exit follow-through
- updated the coordinator through-net render context so one mask flag activates and resets both lower net sprites together when the ball enters, exits, clears, becomes owned, or hides
- expanded hoop render smoke coverage so inactive airborne/front frames must draw above both lower net masks, while `net_channel` and made-shot `front_of_net` must draw behind both active masks
- reran validation after the NetBody phase-gating pass: boot smoke passed; full headless suite reported pure logic passes `1762`, scenarios `18`, balance `4`, failures `2`; the new lower-net mask assertions passed, with the remaining failures still limited to existing shot-followthrough checks

### Phase-gated bottom net mask implemented

- changed `NetCleanBottomHalf` from a permanently frontmost lower mask into an inactive/active z-state owned by `HoopView`
- kept all four top-hoop net sprites on the same `30x28` registration transform, while the inactive state renders below airborne, rim-mouth, and generic `front_of_net` ball phases and the active state rises above `net_channel` plus made-shot net-exit follow-through
- added a coordinator render-context flag so `net_channel` always activates the bottom-half mask, made-shot `front_of_net` after net entry keeps it active, and non-descending airborne `front_of_net` frames keep it inactive
- expanded hoop render smoke coverage for inactive and active z snapshots, the non-descending airborne regression, dynamic made-shot mask activation, no post-clear re-entry, net swish activation, and four-layer `30x28` registration
- reran validation after the phase-gated mask pass: boot smoke passed; full headless suite reported pure logic passes `1756`, scenarios `18`, balance `4`, failures `2`; the new phase-gated net assertions passed, with the remaining failures still limited to existing shot-followthrough checks

### Four-layer top net depth implemented

- added `NetCleanBottomHalf` as a fourth registered top-hoop overlay layer in `HoopView`, using the same `30x28` canvas, `1.6` authored scale, `Vector2(15, 4)` rim anchor, and `Vector2(0, 12)` net offset as `Net`, `NetClean`, and `NetBody`
- shifted the shot-ball hoop phase z offsets so `rim_mouth`, `net_channel`, and the existing `front_of_net` follow-through phase render in front of `NetClean` while preserving `NetBody` above top-hoop shot phases; the later phase-gated pass above now controls when `NetCleanBottomHalf` rises in front
- mirrored the new fallback phase z offsets in `BallController` so any non-`HoopView` ball depth path stays consistent with the top-hoop contract
- added a `HoopView` layering snapshot for tests to inspect effective layer z values, bottom-half sprite presence, texture sizes, positions, and scale registration
- expanded the hoop render smoke to assert the four-layer z band, shared `30x28` registration, made-shot `net_channel -> front_of_net` follow-through, no hoop-render re-entry after clear, and net swish activation
- reran validation after the net layering pass: boot smoke passed; full headless suite reported pure logic passes `1745`, scenarios `18`, balance `4`, failures `2`; the new four-layer net assertions passed, with the remaining failures still limited to existing shot-followthrough checks

### Direct `SHOOT` button now opens the timing bar before release

- changed direct top-left `SHOOT` button taps to use a coordinator-owned two-tap timing mode: first tap enters `SHOT_AIM`, shows the top-row timing meter and trajectory preview, and holds the shooter in the aim pose
- deferred the committed release row only for that direct-button path, then starts it when the second tap at the `SHOOT` button position commits the shot or when the meter times out into a late miss
- kept drag-release shots, direct `DUNK`, pass controls, movement, and second-finger action taps on their existing paths
- extended coordinator smoke coverage to assert first-tap meter visibility, no pending release past the authored release frame, second-tap release staging, and the isolated `direct_shoot_button` timing mode
- reran validation after the direct-shoot timing pass: boot smoke passed; full headless suite reported pure logic `1738`, scenarios `18`, balance `4`, failures `2`, with the new direct-shoot assertions passing and the remaining failures still limited to existing shot-followthrough checks

### Bottom backside hoop enlarged and moved above sprites

- changed the opposite-side hoop from a `CourtView` draw call into a high-z `Sprite2D` child so entity sprites layer behind the bottom back-of-hoop art
- added `CourtConfig.opposite_hoop_visual_scale_multiplier = 2.0` and `CourtConfig.opposite_hoop_z_index = 3000` so the larger size and render order stay tunable
- extended the bottom-hoop snapshot and smoke coverage to assert doubled scale and z ordering above live/presentation entity sprites
- reran validation after the hoop layering pass: boot smoke passed; full headless suite reported pure logic `1738`, scenarios `18`, balance `4`, failures `2`; the bottom-hoop scale/z-order checks passed, with the remaining failures still limited to existing shot-followthrough checks

### Opponent sim court tableaux implemented and validated

- normalized the new back-of-hoop asset into `assets/Court/HoopBodyBackNormalized.png` on a transparent `144x170` canvas while keeping the provided source art unchanged
- added `CourtConfig.opposite_hoop_position` and updated `CourtView` to draw the bottom/opposite hoop behind gameplay entities with a smoke-test snapshot for projected rect and texture size
- added `OpponentSimPresentation` as a dedicated `Entities` child that owns five AWY ghost players, five passive HOM defender ghosts, and a ghost ball for static bottom-half tableaux during `OPPONENT_SIM`
- extended opponent visual-step data with `player_id`, `player_role`, and `actor_team` so the tableau layer can place the relevant actor while preserving the existing score/time resolution
- integrated the tableau layer into `GameCoordinator`: live players and live ball hide during opponent sim, the banner and ghosts advance together, camera tracking snaps to the current actor/tableau center, and cleanup restores live entities on completion or reset paths
- expanded deterministic smoke coverage for the bottom hoop, hidden live entities, visible ghost tableaux, bottom-half position bounds, auto/tap advance, pause freeze/resume, and exact once-only final score/time application
- reran the full headless suite after the tableau pass: pure logic `1728`, scenarios `18`, balance `4`, failures `2`; all opponent-sim presentation checks passed, with the remaining failures limited to existing shot-followthrough smoke checks

### Opponent sim action banner implemented and validated

- extended `OpponentSimController.run_possession()` so every opponent possession now returns deterministic `visual_steps` alongside `events`, `points_scored`, and `time_consumed`
- added tunable `visual_step_min`, `visual_step_max`, and `visual_step_duration` settings to `OpponentSimConfig`
- added `OpponentSimBanner` under `UIRoot`, with a centered safe-width black `80%` opacity action strip, readable wrapped text, full-screen tap capture while visible, and debug layout/text accessors
- refactored `GameCoordinator` so `OPPONENT_SIM` persists while the visual sequence plays; score and clock are now applied only after the final step completes or is skipped
- hid the live scoreboard and bottom control panel during opponent-sim action text, then restored them after the reset returns to `LIVE_OFFENSE`
- added coordinator and scenario helpers for forced opponent-sim entry/results, plus deterministic scenario coverage for one-step score, multi-step score, no-score turnover, tap-skip, and low-clock game-over
- updated existing defensive-rebound, steal, turnover, made-shot reset, and long-run scenarios to account for the staged opponent sim delay
- reran validation after implementation and the transient UI-hide pass: pure logic `1681`, scenarios `18`, balance `4`, failures `2`; all banner-specific checks and scenarios passed, with the remaining failures limited to existing shot-followthrough smoke checks

### Opponent sim action banner docs prepared for implementation

- documented the planned shift from instant opponent-sim jump cuts to `1..4` visible action beats shown in a centered black `80%` opacity banner
- recorded the intended action vocabulary for setup, scoring, and no-score outcomes, with the final visible action required to match the resolved `points_scored`
- added test-plan coverage for visual-step generation, deterministic score/no-score seeds, banner layout, one-second auto-advance, tap-to-advance, deferred score/clock application, and low-clock game-over resolution
- noted the then-current limitation that opponent sim remained text-presented rather than a live animated defensive sequence; this has since been superseded by static court tableaux

## 2026-04-14

### Scored-ball follow-through now hands camera control over to the landing frame immediately

- changed `GameCoordinator` so the post-net score follow-through snaps straight into the authored landing-camera frame and lets the existing hoop handoff offset carry continuity, instead of freezing one camera frame and then steering again later
- cached both the world-space finish center and the screen-space marker center from pre-release non-ball states only (`MATCH_SETUP`, `LIVE_OFFENSE`, `SHOT_AIM`) so the scored-ball landing target is based on the same visible dunk-radius marker the player actually saw before launch
- moved the hoop-render smoke's visible-marker assertion to capture the finish marker after deterministic setup has rebuilt the live projection state, avoiding a stale pre-setup screen sample
- reran the full headless suite after the landing-frame handoff rewrite: Pure logic `1648`, Scenarios `13`, Balance `4`, Failures `0`

### Finish-radius landing target now stays locked to the live player-camera marker

- removed the bad layout-time finish-center cache refresh that could sample the hoop-base marker before the live player camera was actually in place, which let guided makes inherit the wrong floor target
- changed `GameCoordinator` to refresh `finish_logic_center_world_cached` only from live non-ball camera states (`MATCH_SETUP`, `LIVE_OFFENSE`, `SHOT_AIM`, `SHOT_RELEASE`), then reuse that cached world point through score follow-through so the floor target stays stable while the camera tracks the shot
- cleared the cached finish center on match, possession, and scenario resets so a new offense always reacquires the authored dunk-radius center from the current player-camera framing before the next shot launches
- reran the full headless suite after the finish-radius cache fix: Pure logic `1647`, Scenarios `13`, Balance `4`, Failures `0`

### Scored-ball net exit now stays seamless until the floor bounce

- fixed the made-shot visual hiccup where the ball could step upward during `net_exit` because the guided terminal screen-drop effect was decaying before the hoop follow-through had actually finished
- changed `BallSimulator` so guided makes hold the terminal presentation drop at full weight through `net_exit`, then cut over to the floor-drop path only once the explicit hoop follow-through is done
- added a coordinator-side pre-bounce continuity guard that seeds from the live on-screen anchor at score time and clamps `guided_descent -> net_exit -> floor_drop` so the rendered ball never moves upward before the first floor bounce
- kept the existing single small `floor_settle` bounce, but locked the new regression coverage so the first upward motion is only allowed once `floor_settle` begins after floor contact
- reran the full headless suite after the scored-ball continuity fix: Pure logic `1644`, Scenarios `13`, Balance `4`, Failures `0`

### Control-panel buttons now stay dark until hovered or pressed

- changed the visible panel art so `SHOOT`, `DUNK`, `PASS`, and `MOVE` all share the same neutral idle base color `#1b1d3a` instead of always showing their action colors
- kept the original action palettes, but now only swap a zone into its colored version while the live drag is hovering over that zone or while that button is being pressed directly
- added a short-lived direct-tap highlight in `InputController` so immediate `PASS`, `SHOOT`, and `DUNK` taps still flash visibly even though they fire on press
- extended deterministic coverage to assert the neutral idle base, drag-hover color swap, and direct-tap pressed highlight before rerunning validation
- reran the game-scene smoke boot plus the full headless suite after the neutral-idle button pass: Pure logic `1622`, Scenarios `13`, Balance `4`, Failures `0`

### Action buttons now work as direct taps and the shot meter spans the full top row

- added a direct-button input path for `PASS`, `SHOOT`, and `DUNK`, so each visible button can fire without first starting a movement drag
- kept drag-release actions intact, but made the action-button tap path independent from the move pointer so a second finger can trigger pass, shoot, or dunk while the first finger keeps dragging in `MOVE`
- widened the visible shot meter so it now spans the combined `SHOOT | DUNK` top row instead of only the `SHOOT` half, making the green window larger and easier to read during `SHOT_AIM`
- extended pure-input and coordinator smoke coverage to assert direct button taps, second-finger action taps during movement, and the widened control-panel meter geometry before rerunning validation
- reran the game-scene smoke boot plus the full headless suite after the direct-button / top-row-meter pass: Pure logic `1617`, Scenarios `13`, Balance `4`, Failures `0`

### Retuned the visible basketball render to 1.5x the original size

- set the held and live ball render radii in `ProjectionConfig` to `1.5x` the original values so passes, shots, and rebounds still read larger on screen without the oversized 2x look
- kept the change render-only by leaving `BallPhysicsConfig.ball_radius` and hoop collision math unchanged
- updated smoke coverage so the projection radii stay at or above the new 1.5x thresholds
- reran the full headless suite after the ball-visual pass: Pure logic `1609`, Scenarios `13`, Balance `4`, Failures `0`

### Rebalanced the visible panel so movement gets most of the space

- reduced the top `SHOOT | DUNK` row height to two-thirds of its previous size and gave the reclaimed height to the lower `PASS | MOVE | PASS` row so the movement band is taller
- reduced each `PASS` lane width to two-thirds of its previous size and shifted the freed width into the center `MOVE` lane so the move zone is now the widest control target on the panel
- extended smoke coverage to assert the taller move row, narrower matched pass lanes, and wider center move lane before rerunning validation
- reran the game-scene smoke boot plus the full headless suite after the move-lane enlargement pass: Pure logic `1608`, Scenarios `13`, Balance `4`, Failures `0`

### Split the action row into `SHOOT | DUNK` and moved the scoreboard above the left half

- reshaped the then-larger control panel from a three-row stack into a two-row layout with an exact `50/50` top `SHOOT | DUNK` split over the existing `PASS | MOVE | PASS` row, removing the old bottom full-width dunk strip entirely
- kept the same gesture contract and coordinator-owned shot-family logic, but remapped `shot_layout` to the top-left half and `dunk` to the top-right half while making the old bottom-center dunk area inert
- changed the responsive HUD contract so `banner_rect` now points to a compact bottom-left scoreboard card sized to the `SHOOT` half and anchored just above the control panel instead of reserving the top edge of the viewport
- updated layout smoke coverage to assert the top-row split geometry, the absence of a bottom dunk band, scoreboard alignment above the `SHOOT` half, and `Show Controls` leaving the scoreboard visible while hiding only the panel art
- reran the game-scene smoke boot plus the full headless suite after the top-split / scoreboard relocation pass: Pure logic `1605`, Scenarios `13`, Balance `4`, Failures `0`

### Visible control panel replaced the old open-screen offense gestures

- replaced the old open-court live-offense gesture model with the initial dedicated large control panel: top `SHOOT`, middle `PASS | MOVE | PASS`, bottom `DUNK`
- refactored `InputController` to classify live-offense releases against coordinator-owned control-zone rects instead of viewport-wide tap / swipe rules, and made the center `MOVE` zone the required gesture origin
- kept the coordinator as the single owner of the focused pass target, then routed both `PASS` lanes through that one highlighted receiver while removing direct teammate tap overrides from the live control path
- added explicit `shot_layout` and `dunk` control intents so upward `SHOOT` releases now force close finishes to stay layups, while downward `DUNK` releases choose dunk when eligible, fall back to layup when only close-finish-eligible, and ignore far-from-rim attempts
- added `ControlPanel.tscn` / `ControlPanel.gd`, moved the visible timing meter into the `SHOOT` band, removed joystick / meter rendering from `CourtView`, and added a pause-menu `Show Controls` toggle that hides the panel art without changing the underlying hitboxes
- updated input smoke coverage, coordinator smoke coverage, scenario resources, and bot pilot helpers around the new panel contract, then reran the full headless suite: Pure logic `1593`, Scenarios `13`, Balance `4`, Failures `0`

### Off-ball offense slow movement now reuses the defense shuffle row

- split off-ball offense movement presentation into a true slow-move family plus the existing run family, instead of treating every non-idle off-ball motion as the run row
- mapped the new off-ball slow family to row `19`, which is the same authored shuffle row already used by `guard_shuffle`, and then removed the old off-ball idle threshold so any non-zero off-ball offense movement now resolves to that shuffle row while the ballhandler path stays unchanged
- extended the deterministic visual smoke checks to cover off-ball offense idle, shuffle, run, and threshold hysteresis transitions separately
- reran the full headless suite after the off-ball shuffle fix: Pure logic `1597`, Scenarios `13`, Balance `4`, Failures `0`

### Textured scoreboard HUD now uses the authored decor board art

- cropped `assets/Decor/scoreboard.png` down to the measured board bounds (`1098x248`) so the live HUD no longer carries the empty transparent margin that came with the source art
- replaced the old flat top banner with a textured scoreboard layout that anchors to the top safe area, renders only the numeric home and away scores under the art's built-in `HOME` / `GUEST` headings, keeps the game clock in the center inset, and places the pause control on the lower center shelf
- adjusted the scoreboard placement to center against the visible viewport midpoint horizontally instead of only centering inside the safe rect math, so the board now reads visually centered on screen
- reduced the centered scoreboard footprint to two-thirds of its previous on-screen size while keeping the same authored score, clock, and pause zones, so the board reads less dominant and opens more vertical space for play
- changed the responsive layout contract so `banner_rect` now describes the scaled scoreboard art bounds instead of a fixed-height strip, updated HUD smoke coverage to assert scoreboard containment, viewport-center alignment, left/center/right ordering, pause-under-clock placement, and the trimmed scoreboard texture dimensions, and switched the HUD back onto the imported `Texture2D` path now that the cropped board has import metadata
- reran the full headless suite after the scoreboard HUD, centering, and two-thirds scale pass: Pure logic `1571`, Scenarios `13`, Balance `4`, Failures `0`

## 2026-04-13

### Dunk contact hold was shortened for a more fluid finish

- reduced `dunk_contact_hold_seconds` from `0.5` to `0.18` in the shared animation config so dunk contact still reads, but no longer lingers long enough to feel like a freeze frame
- kept the authored contact frame and root-motion anchors unchanged, which means the player still reaches the same dunk pose and landing path, but launches back into the follow-through much sooner
- updated deterministic and smoke expectations for the shorter hold window and reran parse/load plus the full headless suite after the timing pass: Pure logic `1565`, Scenarios `13`, Balance `4`, Failures `0`

### Dunk hold and landing anchors are now authored separately for east and west facing finishes

- replaced the old one-sided dunk contact / landing anchor contract with explicit east-facing and west-facing anchors for rows `13`, `15`, and `16`, then seeded the west values as `x`-mirrored copies of the existing east values so mirrored dunks attach to the correct side of the rim by default
- updated `GameCoordinator` to resolve the active dunk's `mirror_west` flag and use the facing-specific contact and landing anchors for the hold snap, root-motion approach, and post-release landing path instead of always snapping to the east-tuned offsets
- extended deterministic dunk coverage so anchor metadata, hold snapshots, and root-motion traces all assert the correct facing-specific anchor selection and remain deterministic across repeated seeds, then reran parse/load plus the full headless suite after the facing-aware anchor pass: Pure logic `1605`, Scenarios `13`, Balance `4`, Failures `0`

### Close-finish and dunk distance logic now use the same lowered hoop-base anchor as the debug rings

- moved the real close-finish / dunk-distance center off the raw rim world point and onto the rendered hoop-base debug anchor, so the visible radius guides now match the actual layup and dunk eligibility checks instead of only approximating them
- added a coordinator helper that converts the hoop view's lower screen-space anchor back into world space, then routed finish-selection vectors and dunk smart-start distance checks through that shared anchor while leaving the authored dunk contact / landing anchors relative to the hoop config
- updated smoke coverage that stages players near the hoop so test setups use the same lowered finish center as runtime selection, then reran parse/load plus the full headless suite after the alignment pass: Pure logic `1576`, Scenarios `13`, Balance `4`, Failures `0`

### Debug overlay is now enabled by default during local runs

- changed `data/config/DebugConfig.tres` so the `F3` debug overlay starts visible by default instead of hidden, which makes the new finish-radius guides and the existing coordinator diagnostics show up immediately during tuning

### Finish-radius debug rings now anchor to the rendered hoop base instead of the rim center

- added a hoop-view debug anchor at the bottom of the pole/body sprite and shifted the projected finish-radius rings to that lower screen-space center so the guides line up with the visible hoop art instead of the world rim center
- added smoke coverage that compares the snapshot ring center to the hoop view's debug anchor so future hoop-art tweaks do not silently move the radius guides back out of alignment

### Debug overlay now draws bright finish and dunk-start radius rings

- added a `show_finish_radii` debug toggle and projected four bright overlay rings from the hoop center: close-finish radius, max dunk radius, medium smart-start distance, and short smart-start distance
- routed the ring geometry through `GameCoordinator.get_debug_snapshot()` so the circles stay in the same projected camera space as the rest of the debug overlay and remain readable under close-camera tracking
- gave each ring a high-contrast outline plus a distinct vibrant color in `DebugOverlay` and added smoke coverage proving the snapshot exposes all four named radius guides

### Dunk starts now choose the visible approach frames from live hoop distance

- added shared smart-start thresholds to `PlayerAnimationConfig` so dunk rows now resolve their visible starting frame from the shooter's current `distance_to_hoop`: `90.0` starts directly on the jump frames, `120.0` preserves exactly three run frames, and the outer dunk edge still keeps the full authored run-up
- extended the active dunk metadata and locked visual request path to carry `approach_start_frame`, `approach_distance_to_hoop`, and `approach_bucket`, then taught `PlayerVisual` to restart a dunk row at that authored start frame without renumbering the absolute release/contact gates
- rewrote coordinator dunk root motion to use only the visible approach span from the chosen start frame to contact, so late-start dunks skip hidden ground frames, short-distance dunks jump immediately, and all variants still land on the same configured contact and landing anchors
- added a small shared threshold epsilon around the smart-start distance comparisons so side-dunk geometry that should land exactly on the `90` or `120` cutoffs does not drift into the wrong bucket because of floating-point rounding
- extended deterministic coverage for max, medium-threshold, and short starts across rows `13`, `15`, and `16`, and reran parse/load plus the full headless suite after the smart-start pass: Pure logic `1572`, Scenarios `13`, Balance `4`, Failures `0`

### Frame-locked dunk root motion now carries the player into and out of the hold anchor

- kept the dunk contact anchors for rows `13`, `15`, and `16` as the single freeze-frame source of truth, and added authored per-row run/jump/contact-end windows plus per-row landing anchors in `PlayerAnimationConfig`
- moved dunk root motion into `GameCoordinator`, where the coordinator now advances the shooter's world position from release start into the configured contact anchor, pins the authored contact frames there, and then eases the player back down to the configured landing anchor while the ball is already in flight
- exposed the live frame number from `PlayerVisual` so coordinator root motion follows the exact rendered animation frame instead of a separate timer, and kept blocked dunks on the existing no-hold path
- extended deterministic coverage so rows `13`, `15`, and `16` now prove non-contact frames keep moving, contact frames land exactly on the configured anchor, row `16` stays pinned across both contact frames, and landing continues after launch until the configured grounded anchor is reached
- reran parse/load plus the full headless suite after the frame-locked dunk root-motion pass: Pure logic `1041`, Scenarios `13`, Balance `4`, Failures `0`

### Canonicalized dunk freeze placement to one authored anchor per hold row

- removed the old hold-only sprite offset path from `PlayerVisual` so dunk contact rows no longer compose a shared root snap with a second local freeze translation
- added per-row dunk contact anchors for rows `13`, `15`, and `16` in `PlayerAnimationConfig`, and updated `GameCoordinator` to snap the shooter root to the committed row's configured anchor exactly once when the contact hold begins
- kept the current user-authored contact anchors in `data/config/PlayerAnimationConfig.tres` as the manual tuning source for the freeze pose while rows `15` and `16` preserve their finish poses through their own root anchors
- refreshed the dunk release-frame expectations to the current authored values and added deterministic smoke coverage proving rows `13`, `15`, and `16` all snap to a single configured world anchor and the same projected screen position across repeated seeds / approach setups
- reran parse/load plus the full headless suite after the dunk-freeze refactor: Pure logic `723`, Scenarios `13`, Balance `4`, Failures `0`

## 2026-04-10

### Live dunks now auto-finish without the timing bar

- changed `GameCoordinator` so any shot that commits to a dunk family now skips `SHOT_AIM`, never shows the shot bar, never requires a green tap, and immediately queues a guaranteed `dunk_auto_make`
- kept the authored dunk release contract intact by still starting the hidden shot-timing controller for cleanup, preserving the rim-contact hold, hidden world-ball hang, and straight-through guided descent after release
- rewrote the dunk smoke coverage so straight and side dunks now assert immediate `SHOT_RELEASE`, hidden meter state, auto-make timing tags, and the same post-hold make-drop launch path
- reran the full headless suite after the dunk auto-finish change: Pure logic `693`, Scenarios `13`, Balance `4`, Failures `0`

### Hoop moved back to the top boundary

- moved the real hoop anchor to `Vector2(540, -50)` and the backboard collision plane to `y = -120` so the pole, board, rim, and net all sit farther back above the court instead of relying on a support-only visual offset
- removed the temporary split-support hoop art workaround and restored the single combined hoop-body atlas region
- widened the live `three_point_radius` to `840`, `close_finish_radius` to `550`, and `dunk_finish_radius` to `485` so shot-value boundaries and near-rim finish access stay aligned after the actual hoop geometry moved back
- removed the projection clamp that pinned negative hoop world Y to the court top, which is why earlier negative hoop values appeared not to move
- nudged `easy_sim_efficiency` down to `0.88` so the difficulty balance batch still orders Easy below Normal after the hoop-distance retune
- reran the full headless suite after the real negative-Y hoop move: Pure logic `641`, Scenarios `13`, Balance `4`, Failures `0`

### Pause-menu no-defenders toggle and forced close-range dunks

- added a `No Defenders` toggle to the pause overlay so debug sessions can hide all live defenders without leaving the match
- routed live defense, pass interception, and rebound candidate collection through an active-defenders filter so disabled defenders stop contesting, blocking, stealing, or rebounding while hidden
- added a defender-free close-range override to the finish chooser so any shot taken inside the normal close-finish radius commits to a dunk family even for low-dunk or stationary players
- added smoke coverage for the pause overlay toggle, defender visibility changes, and the forced close-range dunk override
- reran the full headless suite after the no-defenders debug toggle: Pure logic `638`, Scenarios `13`, Balance `4`, Failures `0`

### Dunk vs layup decision gates and explicit dunk ratings

- added an explicit `dunk` rating to `PlayerData`, exposed it through `get_rating()`, and seeded the current HOM and AWY rosters with role-specific dunk values
- rewrote close-finish selection into a deterministic two-stage chooser: players first qualify for the layup-or-dunk family by hoop distance, hoop-facing momentum, and the existing finish speed gate, then only qualify for dunk rows if they also meet the stricter dunk radius, dunk-speed, and dunk-rating gates
- kept straight-vs-side finish routing after the family choice, preserved the set-shot and jumper paths outside close-finish conditions, and limited straight-dunk row randomization to the already-committed dunk family
- extended `DefenseController` with a pure dunk-aware block-chance helper so committed dunks gain block resistance from the new `dunk` rating while layups and jumpers keep the existing block formula
- added deterministic coverage for dunk threshold metadata, roster dunk seeding, dunk-only block resistance, layup fallback on low dunk rating or low dunk speed, defender-independent family selection, and regression coverage proving LC archetypes still reach rows `13`, `15`, and `16`
- reran the full headless suite after the dunk-vs-layup chooser rewrite: Pure logic `629`, Scenarios `13`, Balance `4`, Failures `0`

### Dunk contact hold and straight-through finish

- added dunk-contact metadata for rows `13`, `15`, and `16`, including authored rim-contact frames, a shared `0.5` second hold, and per-row contact offsets so the dunk hand lands on the rim graphic during the freeze
- extended `SHOT_RELEASE` so unblocked dunk rows now wait for the authored contact frame, hang on the rim with the world ball hidden, then release only after the hold completes
- changed dunk makes to start directly at the rim entry point and drop straight through the hoop and net, while dunk misses now launch from that same point into a short upward-and-away bounce
- added deterministic coverage for dunk contact metadata, hold timing, hidden-ball behavior during the rim hang, straight-through make descent, upward-and-away miss bounce, and blocked-dunk bypass behavior
- reran the full headless suite after the dunk-specific release rewrite: Pure logic `598`, Scenarios `13`, Balance `4`, Failures `0`

### Stricter upward-only shot swipe gate

- tightened shot entry so `SHOT_AIM` now only arms from an upward swipe whose release lands in the top half of the screen
- removed downward swipe shot entry and rejected upward swipes that stay in the lower half, while keeping lower-zone movement active until a qualifying upward release wins on lift-off
- updated the bot pilot and smoke helpers so automated shot-entry gestures now intentionally finish above the halfway line instead of relying on a shorter upward flick
- reran the headless suite after the stricter gate: Pure logic `472`, Scenarios `13`, Balance `4`, Failures `0`

### Tap-pass and swipe-shot control swap

- swapped live-offense control arbitration so quick taps now request passes and strong upward swipes now arm `SHOT_AIM`
- added a coordinator-owned default pass target that stays marked with the light-blue ring during `LIVE_OFFENSE`, with empty taps passing to that ranked teammate and direct teammate taps overriding the marker
- kept lower-zone drags as movement while the finger is down, but made qualifying upward lower-zone releases arm shot mode instead of resolving as ordinary movement-stop releases
- added `PassController.evaluate_pass_target()` so the default pass marker, pass-risk ranking, and live pass start all share the same interception-commit, distance, and hoop-proximity evaluation
- rewired `InputController`, `BotPilot`, `ScenarioRunner`, and coordinator smoke hooks around `tap_pass` and `swipe_shot` semantics while keeping backward-compatible aliases for older scenario resources
- re-ran headless validation after the control swap: Pure logic `470`, Scenarios `13`, Balance `4`, Failures `0`

## 2026-04-07

### Clean-room scaffold

- created `project.godot`, portrait startup scene, directory layout, and base scene tree
- added resource scripts for game, court, ball, shot, pass, route, defense, rebound, sim, difficulty, and debug tuning
- authored default HOM/AWY teams as `TeamData` resources

### Gameplay runtime

- implemented `GameCoordinator` as the single state owner
- added joystick movement, tap passing, shot aim, pass conversion, pause, game over, and possession reset flow
- implemented pure gameplay controllers for passes, shots, ball flight, hoop resolution, rebounds, routes, defense, and opponent sim
- added procedural placeholder court, player, hoop, HUD, overlay, and feedback rendering

### Diagnostics and tests

- implemented `LogWriter`, deterministic RNG support, debug overlay, headless test runner, scenario runner, bot pilot, and balance runner
- authored nine scenario resources and four balance batch resources
- added deterministic coordinator hooks for brittle edge-case scenarios
- tuned rebound and balance fixtures until the full suite passed

### Documentation closeout

- replaced placeholder README content
- added project brief, gameplay spec, architecture, decisions, test plan, known issues, and test results docs

### High-arc shot rework

- replaced the flat single-power shot feel with separate forward and arc growth curves
- added a weak starter preview that appears immediately when shot aim begins
- reduced horizontal launch aggression and raised vertical lift for a slower, more casual arc
- densified preview dots, added apex emphasis, and moved the preview origin slightly in front of the shooter
- added pure-logic coverage for starter preview, arc growth, floatiness, preview/live launch consistency, tiny-drag cancel, and pass conversion override

### Low top-down projection refactor

- added `ProjectionConfig` and `CourtProjection` as a render-only view layer
- moved players to explicit `world_position` gameplay coordinates instead of treating `Node2D.position` as simulation truth
- projected players, shadows, held ball, live ball, hoop, debug geometry, and shot preview into screen space from `GameCoordinator`
- converted action input and scripted harness gestures to projected screen targeting with inverse ground-plane mapping back into world space
- updated pure-logic coverage for projection monotonicity, projected preview/live agreement, projected tap targeting, and screen-drag launch mapping

### Hold-to-shoot meter rework

- replaced drag-to-shoot with a touch-and-hold meter on the current ballhandler
- added a bottom rectangular timing bar with a mostly red lane, a smaller green make window, and a moving indicator block
- changed shot resolution so green releases deterministically launch a make path through the rim, while red releases launch misses or allow contest-driven blocks
- added a short post-score hold so made shots visibly finish through the hoop before the game transitions
- updated the harness and balance probe to validate the meter-driven mechanic instead of the old drag-preview flow

## 2026-04-08

### Fixed-green shot guarantee

- removed contest and release-consistency effects from the green meter geometry so the visible green chunk is always the actual guaranteed-make window
- enforced green releases through hoop resolution with a forced-make flight flag so guaranteed shots cannot rattle out on rim or backboard contact
- kept contest pressure only on red releases, where the miss path can still be blocked before rebound resolution
- added deterministic coverage for contested green makes, fixed-window snapshots, and a coordinator-level harness step that sets a precise meter quality before release
- replaced the flaky defensive-rebound scenario trigger with a deterministic defensive-rebound hook so the suite no longer depends on rebound RNG for that case

### Atlas art integration

- replaced the procedural placeholder court with a textured projected half-court sampled from the second court variant in the new atlas and rotated into the portrait offense-only presentation
- replaced procedural hoop and ball drawing with atlas-backed hoop/net layers and layered basketball sprites while keeping the existing resolver, projection, and ball-flight math intact
- added `PlayerVisual` as a sprite-only presentation child for each `PlayerController`, using Character1 for home, Character2 for away, and a focused first-pass set of idle, move, aim, shoot, and catch/rebound animations
- added coordinator-side facing and animation-state resolution so movement, aim, pass catches, offensive rebounds, and shot releases drive the new sprite presentation without moving gameplay rules into the art layer
- added smoke coverage that instantiates `GameRoot` and asserts the textured court plus hoop, ball, and player sprite visuals are present during the automated suite

### Gameplay-first boot and render calibration

- changed `project.godot` so the project boots directly into `GameRoot.tscn` and removed the dead `MainMenu` scene/script path
- replaced pause/game-over `Main Menu` actions with `Quit Game` so overlays still expose an exit path without referencing a removed scene
- corrected the second-court source bounds to the full 484x229 atlas region and made the active portrait floor an explicit left-half crop of that source
- switched court strip rendering to an `AtlasTexture`-backed sampling path with normalized UVs so the rotated floor art actually renders instead of sampling empty atlas space
- generated a clean transparent `NetClean.png` from the user-provided net screenshot and used it as the front hoop layer, then tuned the front-net anchor so it hangs below the backboard over the painted rim area

### Flat rectangular framing and larger players

- retuned `ProjectionConfig` so the court maps to a true rectangle with constant width, linear depth, and a slightly tighter on-screen framing
- kept the same `CourtProjection` and inverse input mapping APIs, but changed the authored defaults away from the old pseudo-perspective stretch
- substantially increased player sprite scale and raised the sprite offset so enlarged characters stay foot-anchored to the floor
- enlarged hit radii, screen anchors, held-ball anchors, and held/live ball render sizes so the bigger player presentation still aligns cleanly during input and possession
- added pure-logic coverage for constant court width, linear depth mapping, and exact ground-coordinate round-tripping under the flatter projection

### Cinematic shot arc refactor

- replaced the fixed-time make/miss shot builder with an apex-driven launch profile that enforces minimum airtime and minimum apex by distance
- changed shot launches to begin above the floor and updated `BallSimulator.launch` to accept full horizontal velocity plus launch z
- restored visible arc preview dots during aim, with green showing the make path and red showing the deterministic miss path stored from aim start
- raised live and preview z-lift, increased live ball size growth, and strengthened shadow shrink so the new arc reads clearly on screen
- expanded pure-logic coverage for cinematic airtime, apex height, preview/live launch agreement, and above-floor release behavior
- lengthened the contested green release scenario wait so the longer arc fully resolves back to live offense inside the harness

### Hoop depth-visual contract

- added deterministic test coverage for explicit hoop render phases and the through-net score follow-through contract
- documented the layered hoop visual model so normal makes stay in front of the backboard, pass behind the front net on score, and only render behind the board on true over-the-top paths
- recorded the through-net score visual behavior in the gameplay spec, architecture notes, test plan, and acceptance checklist without changing score legality
- switched coordinator test mode to a fixed 60 Hz simulation step so made-shot follow-through timing, scenario waits, and clock assertions stay stable in headless deterministic runs

### Front-half net-entry score fix

- moved green make trajectories off raw hoop center and onto a dedicated front-half net-entry target so guaranteed makes visibly enter the mouth of the net
- tightened `HoopResolver` so both forced and normal scores must cross the rim plane inside the inner cylinder and on the front side of the hoop
- clamped score follow-through start positions into the legal net channel so a scored frame cannot begin above or behind the backboard
- added pure-logic regressions for the screenshot case where a backboard-side descending crossing used to score despite missing the net

### Three-piece hoop pass-through refactor

- split the old single front hoop overlay into a three-piece render stack: a rear/full hoop silhouette, a front rim lip, and a hanging front net body
- converted `Net.png` into a transparent combined rear hoop layer and regenerated `NetClean.png` as a rim-only layer, then authored a matching `NetBody.png` for the swishable lower net
- added explicit `rim_mouth` and `net_channel` ball render phases so a made shot now spends a readable frame inside the rim before dropping behind the front net
- added a small `HoopView`-owned net swish animation that stretches and sways the front net body on scored follow-through without touching score legality
- extended deterministic smoke coverage so the harness now checks three-piece hoop availability, rim-mouth first-frame rendering, net-channel progression, front-of-net emergence, and score-triggered swish activation

### Guided make descent rewrite

- replaced the old green-shot forced-score contract with a staged guided-make profile that solves a legal front-half rim entry and then hands off to simulator-owned downward descent
- extended `BallSimulator` so made shots move from free flight into a rim-plane handoff and then through `guided_descent` and `net_exit` before the score resolves
- changed `HoopResolver` so guided makes can still collide during approach, but only score from the simulator-reported guided-descent gate instead of any arbitrary early crossing
- removed the coordinator-owned render-only score rescue from the live scoring path and reduced it to phase/state tracking plus net-swish triggering
- retimed deterministic `force_scoring_shot` scenarios so they now launch a real guided make instead of fabricating an instant scored frame

### Rim-plane handoff rewrite

- moved the end of the green make arc from an above-rim entry point down to the rim plane at the legal front-half handoff point
- removed the authored above-rim linger from the live solver and kept any `rim_mouth` read to at most a transient transition frame
- pushed the score gate slightly below the rim so feedback appears only after the ball has visibly started descending into the net
- updated smoke coverage so made shots no longer require a sustained rim-mouth phase and explicitly fail if score feedback appears while the ball is above the rim

### Terminal made-shot screen drop

- reduced the render-only terminal drop for guided makes from 65px to about 60px so the final approach and descent sit slightly higher while keeping the same terminal path behavior
- kept the solver, score legality, and hoop geometry unchanged; the drop is purely a presentation offset in the terminal guided-make path
- applied the same visual-only lowering to the terminal guided-make preview samples so the last green preview segment stays aligned with the live finish without affecting miss paths

## 2026-04-09

### Close-camera retune and player floor marker cleanup

- retuned the projection-layer close camera from `2.4x` down to `2.1x` so the court and players still read close, but with slightly more surrounding floor in frame
- removed the old black player ground shadow draw from `PlayerController` while leaving the live ball shadow and the rest of the projection math untouched
- replaced the controlled-player floor circle with a thin outlined oval positioned lower and wider so the player feet sit visually inside the marker instead of above its center
- added a `PlayerController` debug floor-marker snapshot so the headless suite can assert that player shadows stay disabled and the controlled marker remains an outlined oval with the expected feet-centered offset
- reran the headless suite after the visual cleanup; the latest pass landed at Pure logic `463`, Scenarios `13`, Balance `4`, Failures `0`

### Dynamic close camera

- added a projection-layer close camera with `2.4x` zoom that hard-centers the tracked subject on the visible viewport midpoint without changing gameplay-world coordinates
- extended `CourtProjection` into a base-layout-plus-camera pipeline so render zoom/translation apply after the responsive court mapping, while inverse touch mapping removes the same camera transform before converting back to world space
- switched possession tracking to the controlled player using an upper-body anchor offset, and switched pass, shot, rebound, and made-shot follow-through tracking to the live rendered ball anchor including its z-height presentation
- kept player-follow movement lightly smoothed, but snapped live-ball tracking so the launched ball stays centered from the first visible flight frame instead of easing behind fast passes or shots
- moved depth ordering onto base projection space and scaled hoop, actor, shadow, held-ball, live-ball, and guided-make presentation through the zoomed projection values so the full court presentation reads much closer on screen
- expanded deterministic coverage around centered opening possession framing, centered pass and shot flight, camera-aware inverse mapping, world-space pass travel under a centered camera, and HUD containment after the close-camera transform

### Visible pass flight and steal resolve

- rewrote `PassController` so passes now keep a full active-flight snapshot with a fixed release-time endpoint, an active interceptor, a live chase point, rating-scaled claim radii, and explicit `complete_offense` / `complete_steal` outcomes
- made pass flight authoritative for the live ball render path so the ball stays visibly in motion through `PASS_IN_FLIGHT` instead of snapping back to the handler at the end of the frame
- added coordinator-side receiver and defender pass-flight movement overrides plus a short `STEAL_RESOLVE` state that pins the ball to the stealing defender before the opponent sim starts
- extended pass logging and debug overlay snapshots with pass target, chase, and resolution markers so deterministic runs explain why a pass succeeded, was stolen, or went out of bounds
- updated deterministic scenarios, bot assertions, and balance probes so the harness now validates real visible catches and steals instead of the old instant-turnover shortcut

### Probabilistic pass steal tuning

- changed pass defense from automatic lane commitment to a hybrid model: one best eligible defender is still selected by ETA, but that defender only cuts the lane after a seeded commit roll using pass geometry, defender pressure, passer accuracy, receiver catch security, and the difficulty defense multiplier
- kept the visible live-ball race intact after commitment, so the ball path, receiver break, and defender cut all still read honestly on screen
- extended the debug snapshot and pass-start logs with eligible defender, committed defender, and commit-chance data so tuning is visible during desktop runs
- retuned the pass-risk batch around the new commit gate; the latest headless run landed at short steals `0.00` and long steals `0.23` on Normal difficulty
- fixed the scripted cross-court steal scenario so it explicitly uses `force_pass_interception` before asserting the visible `STEAL_RESOLVE` path

### Full-screen court rescale

- retuned `ProjectionConfig` so the projected court now fills the full `1080x1920` viewport behind the HUD, with the top sideline at screen top, the bottom sideline at screen bottom, and both sidelines landing flush on the left and right screen edges
- increased actor presentation scale by the same court-fill ratio so players stay proportionate to the larger floor without changing `CourtConfig`, route anchors, or other gameplay-world coordinates
- moved held-ball radius, live-ball min/max radius, and hoop visual scale into `ProjectionConfig` so the court, ball, and hoop all scale from one presentation resource instead of mixed hardcoded render constants
- retuned the hoop screen offset so the larger backboard and rim art still clear the 128 px HUD banner while the court art continues rendering behind it
- extended pure-logic and smoke validation with fullscreen court bounds, hoop-over-HUD clearance, larger player presentation, held-ball hand alignment, and in-flight ball/projection alignment coverage

### Full-sheet player animation overhaul

- added `PlayerAnimationConfig` plus a runtime `PlayerVisualRequest` contract so `GameCoordinator` now classifies player presentation into full-sheet animation families without moving gameplay ownership into the art layer
- replaced the old coarse `idle/move/aim/shoot/catch` player art pass with row-driven playback covering no-ball idle, multiple with-ball idle/dribble states, jumper releases, layups, dunks, side dunks, guard states, off-ball runs, and jump contests
- collapsed the facing model to east-facing sprite art plus westward X mirroring, and restricted outline rendering to the currently controlled player while leaving all other players fill-only
- added a short defender jump pose, hooked the block check to identify the actual blocker, and routed close-finish shots into layup, straight-dunk, or side-dunk presentation using hoop proximity and approach direction
- extended the headless suite with exact row, flip, outline, fill-texture, variant-lock, layup/dunk, and guard-state assertions so the full-sheet mapping now has deterministic regression coverage

### Slower post-net floor drop speed alignment

- replaced the first pass of the guided-make `floor_drop` with a longer carried-velocity fall so the ball no longer accelerates too aggressively as soon as it leaves `net_exit`
- changed `BallSimulator` floor-drop sampling from the earlier short Hermite ease to constant-acceleration motion seeded from the outgoing `net_exit` velocity, which keeps the post-net descent closer to the speed the made shot was already showing on screen
- retuned `BallPhysicsConfig.made_shot_floor_drop_duration` from `0.24` to `0.42` seconds so the ball has enough time to travel from the hoop exit to the hoop-base floor target without a visible speed spike
- updated the dunk root-motion determinism harness to compare the final landing against a camera-independent base screen anchor, since the longer scored-ball follow-through now keeps the camera on the live ball slightly longer than before
- extended the clean-make and buzzer-beater scenarios to wait through the longer visible landing, then reran the headless suite green at Pure logic `1646`, Scenarios `13`, Balance `4`, Failures `0`

### Release-synced shot staging and hidden held-ball presentation

- inserted a new `SHOT_RELEASE` coordinator state so releasing the meter now commits a locked shot family, row variant, and west-mirror flag before the ball is actually launched
- changed shot classification so row 4 is now a defender-space set shot, row 5 is the aim hold, rows 8 and 10 are randomized jumper releases, rows 14 and 17 split straight vs side layups, and rows 13, 15, and 16 cover straight and side dunks from movement snapshots taken at shot initiation
- hid the standalone `BallController` whenever a player-owned sprite already contains the ball, so the world ball now appears only on pass start, after the correct release frame of a committed shot, and during genuine loose/in-flight states
- added row-specific release-after-frame metadata plus lightweight debug accessors on `PlayerVisual` / `PlayerController`, then moved the coordinator launch trigger to the first tick after the authored release frame has finished displaying
- expanded the smoke suite with hidden-held-ball checks, staged shot-release timing, deterministic row-8-or-10 jumper selection, straight-vs-side layup routing, deterministic dunk row locks, steal/offensive-rebound hide-on-catch behavior, and delayed blocker jump-pose coverage

### Aim-synced shot windup and meter alignment

- switched shot aim to start the committed release row immediately so the hold bar and sprite animation advance from the same timing profile
- aligned the tail-end green window so the end of green lands on the authored release frame for the selected row
- kept early releases locked to the current quality while the animation continues through followthrough before launch
- added overhold auto-release at the authored release frame, with forced-miss behavior when the player keeps holding too long
- retained row 5 only as a fallback hold pose for non-committed or canceled cases, not as the main live shot-aim animation

### Unified 15 FPS shot cadence

- changed every committed shot family in `PlayerVisual` to a shared 15 FPS playback rate so set shots, jumpers, layups, and dunks no longer jump between mixed row speeds
- updated the coordinator fallback timing helpers so release-pose duration, release seconds, and full animation duration all derive from the same 15 FPS shot profile instead of old 16 FPS defaults
- extended the deterministic suite with exact 15 FPS timing-profile checks for rows 4, 8, 10, 13, 14, 15, 16, and 17 plus a no-restart continuation cadence check

### iOS test export setup

- added a local `export_presets.cfg` iOS preset for device testing with the existing Apple developer team configuration and an ignored `.godot/ios_export` Xcode-project target
- documented the Godot-to-Xcode install flow in `docs/IOS_TESTING.md` so local device testing does not depend on App Store publishing steps
- restored the missing `scripts/game/MainMenu.gd` stub referenced by `scenes/MainMenu.tscn` so export packing no longer trips over a stale scene script

### One-thumb control and full-height court rework

- added `InputConfig` as a dedicated resource for movement-zone height, invisible-stick radius, dead zone, pass-preview cone, tap thresholds, anchor visuals, and best-effort mobile haptics
- removed the runtime joystick scene and replaced movement with an invisible lower-screen drag zone that spawns a faint temporary thumb anchor
- changed passing from teammate taps to directional flicks, including live pre-release target preview and deterministic cone-based target selection
- changed shooting so releasing a non-pass gesture arms shot mode at normal speed, starts the committed shot animation immediately, and waits for a tap-anywhere timing lock instead of using a hold-to-release meter
- added late-miss timeout handling when the timing bar reaches the end without a tap, while preserving the existing authored release-frame launch gate after the timing decision is locked
- updated `CourtView` so the rotated court art keeps its source aspect ratio, fills the full screen height, crops excess width with an offensive bias, and renders transient movement-anchor and pass-preview overlays
- rewired the bot pilot, deterministic scenarios, and pure-logic coverage around `move_thumb`, `flick_pass`, `arm_shot`, and `tap_meter`, and added a dedicated late-miss timeout scenario

### Release-to-pass and tap-to-arm shot follow-up

- removed the release-speed and flick-distance pass dependency from the shipped mobile input path while keeping the existing live pass-preview lock and ring fill
- changed release arbitration so quick taps arm shot mode, center release after a real drag cancels, off-center release with a lock passes, and off-center release without a lock cancels
- replaced the swipe thresholds in `InputConfig` with quick-tap duration and excursion limits
- routed gameplay touch recognition through unhandled input so HUD controls keep precedence over shot-arm taps
- extended structured release logs with offset, distance, release reason, and tap metrics
- rewired the deterministic harness around `release_pass`, `tap_shot`, `release_center`, and `tap_meter`
- added deterministic coverage for upper-screen tap shot arming, lower-zone tap shot arming, center release idle, tap red miss, and pause/resume safety while armed in shot mode

### Responsive mobile court and HUD layout

- added a `GameCoordinator`-owned responsive layout contract that reads the visible viewport plus `DisplayServer.get_display_safe_area()`, then derives `banner_rect`, `available_play_rect`, `court_screen_rect`, `presentation_scale`, and `ui_scale`
- changed `CourtProjection` to accept runtime screen-layout overrides so world-space gameplay stays untouched while the rendered court now fits and centers below the live banner instead of assuming a fixed `1080x1920` frame
- scaled actor presentation, shadow offset, hoop offset/scale, live ball radii, held-ball radius, and guided-make screen-drop presentation from the centered court width so visuals stay proportional on narrower phones
- rebuilt `HUD` from responsive containers with a centered timer/pause stack and exposed a layout snapshot used by smoke tests to assert all banner controls stay fully inside the top bar
- updated smoke and pure-logic coverage around responsive court bounds, centered play-area placement, hoop-over-banner clearance, and HUD child-rect containment

### Smooth AI steering and blue pass preview cleanup

- replaced the AI’s snap-to-target corrections with eased arrival steering for off-ball offense, on-ball defense, rebound pursuit, pass receivers, and committed lane-cut defenders while leaving user-controlled movement unchanged
- added route side-switch hysteresis around the hoop centerline so strong-side and weak-side packages do not thrash when the ballhandler hovers near the middle of the floor
- added animation-family and facing hysteresis so off-ball runners and defenders stop chattering between idle, shuffle, run, and left/right mirror states during tiny corrective moves
- changed the shipped default presentation so the debug overlay no longer boots visible, teammate catch rings stay hidden in normal play, and the active pass-preview target now uses the light-blue ring style instead of the older yellow marker
- extended the deterministic suite with route hysteresis, smooth-settle steering, animation/facing hysteresis, and gameplay pass-preview feedback assertions; the latest headless run landed at Pure logic `434`, Scenarios `13`, Balance `4`, Failures `0`

### Made baskets now fall cleanly from the net to the hoop-base floor target

- extended `BallSimulator` guided makes with two new terminal phases, `floor_drop` and `floor_settle`, so every made basket now keeps one continuous swish-to-floor motion instead of ending under the net and rattling around the hoop art
- injected guided-make floor-finish metadata from `GameCoordinator` at launch time, using the same `get_finish_logic_center_world()` anchor that drives the visible dunk-radius markers so jumper makes and dunk auto-makes both land on the authored hoop-base center
- replaced the immediate post-`net_exit` render clear with a short coordinator-owned `front_of_net` handoff, so the first `floor_drop` frame keeps the last hoop-space screen anchor and decays smoothly into world-space rendering instead of popping back above the net
- changed the handoff release rule so the hoop-layer render only clears after the rendered ball has visibly crossed `HoopView.get_front_net_exit_screen_y()`, and once it clears the shot can never reactivate `net_channel` or `front_of_net`
- stopped the net swish as soon as the explicit hoop phase ends, while the new handoff keeps only the layering contract alive for the floor finish
- added temporary `score_followthrough_trace` diagnostics that print to the Godot console and append structured rows into the active match event log, capturing simulator phase, render phase, handoff offsets, rendered/world ball anchors, and the live front-net exit threshold for post-score glitch triage
- tightened the buzzer path so expired-clock made shots finish the game as soon as the ball has completed the new floor settle instead of waiting on an outdated post-score timer
- extended deterministic coverage for guided-make `net_exit -> floor_drop -> floor_settle` ordering, grounded landing on the supplied floor target, single-window `front_of_net` rendering, no render-phase re-entry after clear, floor-drop continuity against the last hoop-exit frame, landed-before-reset behavior, and a dunk auto-finish smoke case that shares the same landing target
- reran the full headless suite after the render-handoff fix: Pure logic `1640`, Scenarios `13`, Balance `4`, Failures `0`

### Dunk button disabled feedback

- added a coordinator-owned `dunk_available` control-panel flag derived from the same non-random close-finish gates that drive dunk-intent resolution, so the HUD no longer invents a separate availability rule
- updated `ControlPanel` to tint and dim the `DUNK` zone when the current ballhandler has no live close-finish action available, while leaving the existing pass-lane disabled treatment intact
- extended deterministic smoke coverage to assert that the `DUNK` zone starts disabled from the perimeter and re-enables once the active ballhandler enters a live close-finish window near the rim
