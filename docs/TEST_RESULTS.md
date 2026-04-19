# Test Results

## Horizontal-Scroll Team Layout Validation

The team-management flow now keeps the roster readable on portrait screens by using separate full-width horizontal `STARTERS` and `BENCH` strips, strip heights that fully show a card without vertical clipping, section headers aligned to the title column, a `20px` gap between the subtitle and `STARTERS`, a viewport-width empty-bench placeholder centered against the full screen instead of the bench container, bottom navigation buttons inset `50px` above the phone edge with `30px` side padding, and a near-full-width bottom drag strip on lineup and bench cards so strip scrolling and drag/drop no longer fight over the same touch gesture.

## Environment

- Date: 2026-04-19
- Workspace: `/Users/teeds/Desktop/Programming/RetroBasketball/PocketHoops/final-project-u1417748`
- Engine used for validation: Godot 4.6.1 stable

## Commands Run

Automated suite:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd
```

## Automated Result

Full suite status: fail, with the new full-width carousel, no-clipping strip height, title-column header alignment, `20px` subtitle spacing, centered empty-bench placeholder, four-player shop, and `30px` / `50px` inset bottom-button coverage passing

- Pure logic checks recorded: 1855
- Scenarios: 18 / 18 resources executed
- Balance: 4 / 4 batches executed
- Failures: 5

Horizontal-layout and roster/shop validation passed:

- `TeamRoster` reset state starts with `1000` coins, five starter slots, an empty bench, and four featured shop players
- successful purchase deducts coins, marks the offer purchased, and places the player on the bench
- duplicate purchase and insufficient-funds purchase both fail cleanly
- swapping a bench player into a starter slot updates the starter and bench state while preserving the fixed gameplay slot order
- `TeamScreen` snapshot coverage passed for five starter cards, full-width horizontal starters and bench strips, a viewport-width empty-bench placeholder centered against the full screen, the shared coin badge, and a bottom action bar inset `50px` above the screen edge with `30px` side padding
- `TeamScreen` snapshot coverage also passed for title-column-aligned `STARTERS` and `BENCH` headers, a `20px` subtitle gap before `STARTERS`, and full-card viewport height in both horizontal strips
- team-page input smoke confirmed card-body drags pass swipe input through to the carousel, the starters strip actually scrolls on swipe, and the near-full-width bottom drag strip still starts roster swapping
- `ShopScreen` snapshot coverage passed for four featured offers, two wrapped rows, shared coin badge state, and a `Back To Team` button inset `50px` above the screen edge with `30px` side padding
- padded near-hover target acceptance and outside-threshold rejection both passed for the explicit drag/drop resolver
- a fresh `GameRoot` instance used the swapped featured player in live gameplay while keeping the fixed slot role

Current failing checks remain outside the new roster/shop flow:

- `scenario Buzzer Shot Completion state expected GAME_OVER got SHOT_IN_FLIGHT`
- `scenario Contested Green Release Scores home score expected 2 got 3`
- `guided make bounce starts only after floor contact`
- `outside arc three`
- `straight dunk keeps moving through the landing after launch`

## Main Menu Quit Button Removal Validation

The home screen no longer exposes a `Quit Game` action. `MainMenu.tscn` now instantiates with only the start, team, and settings buttons, while the in-match quit flow remains unchanged.

## Environment

- Date: 2026-04-19
- Workspace: `/Users/teeds/Desktop/Programming/RetroBasketball/PocketHoops/final-project-u1417748`
- Engine used for validation: Godot 4.6.1 stable

## Commands Run

Focused headless validation:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script /tmp/verify_main_menu_no_quit.gd
```

## Automated Result

Focused menu validation status: pass

- `MainMenu.tscn` instantiated successfully
- `ButtonStack/QuitButton` was absent as expected
- the new smoke assertion `main menu omits a quit button` was added to `tests/TestRunner.gd`

## Shot Timing Bar Centering Validation

The visible shot-timing bar now keeps its existing full-width action-row sizing, but it draws at the center of the safe viewport during `SHOT_AIM` instead of sitting inside the top `SHOOT | DUNK` control row. The new smoke coverage asserts both safe-area containment and centered placement.

## Environment

- Date: 2026-04-17
- Workspace: `/Users/teeds/Desktop/Programming/RetroBasketball/PocketHoops/final-project-u1417748`
- Engine used for validation: Godot 4.6.1 stable

## Commands Run

Automated suite:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd
```

## Automated Result

Full suite status: fail, with the new centered-meter assertions passing

- Pure logic passes: 1803
- Scenarios: 18 / 18
- Balance: 4 / 4
- Failures: 2
- Current failing checks:
  - `guided make bounce starts only after floor contact`
  - `straight dunk keeps moving through the landing after launch`

## Menu Background Reuse Validation

`TeamScreen.tscn` and `SettingsScreen.tscn` now use the same cached rotated court backdrop as `MainMenu.tscn`. Moving between the menu, team page, and settings page preserves one shared start-page background selection instead of reusing only the flat default court art.

## Environment

- Date: 2026-04-17
- Workspace: `/Users/teeds/Desktop/Programming/RetroBasketball/PocketHoops/final-project-u1417748`
- Engine used for validation: Godot 4.6.1 stable

## Commands Run

Gameplay boot smoke:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --quit
```

Automated suite:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd
```

## Automated Result

Boot smoke status: pass

- The project still boots headlessly after the shared menu-background change.

Full suite status: fail, with the menu-background assertions passing

- Pure logic passes: 1802
- Scenarios: 18 / 18
- Balance: 4 / 4
- Failures: 6
- Current failing checks:
  - `guided make bounce starts only after floor contact`
  - `straight dunk keeps moving through the landing after launch`
  - `Opponent Banner Game Over`
  - `Opponent Banner Multi-Step Score`
  - `Opponent Banner One-Step Score`
  - `Opponent Banner Tap Skip`

Shared menu-background assertions passed:

- `main menu exposes a court background node`
- `shared menu background chooses a source image`
- `team screen reuses the main menu background texture`
- `team screen keeps the shared menu background selection`
- `settings screen reuses the main menu background texture`
- `settings screen keeps the shared menu background selection`

## Pause Overlay Centering And Quit Validation

The in-game pause menu now resolves its own viewport-sized root rect and explicitly places the pause panel within the responsive safe rect instead of depending on deferred container layout under `CanvasLayer`. The pause card is intentionally raised `100px` above the safe-rect center, and the in-match `Quit Game` action now routes back to `MainMenu.tscn`.

## Environment

- Date: 2026-04-17
- Workspace: `/Users/teeds/Desktop/Programming/RetroBasketball/PocketHoops/final-project-u1417748`
- Engine used for validation: Godot 4.6.1 stable

## Commands Run

Gameplay boot smoke:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --quit
```

Automated suite:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd
```

## Automated Result

Boot smoke status: pass

- The project still boots headlessly after the pause overlay layout change.

Full suite status: fail, with pause overlay centering and quit-path coverage passing

- Pure logic passes: 1778
- Scenarios: 18 / 18
- Balance: 4 / 4
- Failures: 2
- The same pre-existing followthrough failures remain:
  - `guided make bounce starts only after floor contact`
  - `straight dunk keeps moving through the landing after launch`

Pause overlay-specific smoke coverage passed:

- `pause quit targets the main menu scene`
- `pause overlay root matches the viewport`
- `pause overlay tracks the responsive safe rect`
- `pause panel stays inside the safe area`
- `pause panel stays centered on screen with the raised offset`

## Pixeloid Font Theme Validation

The project GUI theme now resolves all default control text to `assets/fonts/pixeloid/PixeloidSans-Bold.ttf`. The shared theme and project custom font setting both point at the same font asset.

## Environment

- Date: 2026-04-16
- Workspace: `/Users/teeds/Desktop/Programming/RetroBasketball/PocketHoops/final-project-u1417748`
- Engine used for validation: Godot 4.6.1 stable

## Commands Run

Gameplay boot smoke:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --quit
```

Pixeloid theme assertion:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --log-file /tmp/pocket_hoops_pixeloid_verify.log --script /tmp/verify_pixeloid_theme.gd
```

## Automated Result

Final validation status: pass

- Boot smoke completed without theme or font load errors.
- The Pixeloid font loaded as a `FontFile`.
- `ProjectSettings.gui/theme/custom` resolved to `res://data/ui/PocketHoopsTheme.tres`.
- `ProjectSettings.gui/theme/custom_font` resolved to `res://assets/fonts/pixeloid/PixeloidSans-Bold.ttf`.
- `PocketHoopsTheme.default_font` resolved to the same Pixeloid font asset.

## Compact Controls, Mirrored Pause Button, Lower Net, Direct Shoot, and Bottom Hoop Validation

The visible control panel still uses the compact bottom-quarter footprint with small capped labels, and the HUD now splits into a left scoreboard card plus a mirrored standalone pause button above `DUNK`. The live top hoop still treats both `NetCleanBottomHalf` and `NetBody` as phase-gated lower net masks. The direct top-left `SHOOT` button two-tap timing path and bottom backside hoop validation from the same working tree are still covered. The full suite still exits non-zero because the same two existing shot-followthrough smoke checks are failing outside these paths.

## Environment

- Date: 2026-04-15
- Workspace: `/Users/teeds/Desktop/Programming/RetroBasketball/PocketHoops/final-project-u1417748`
- Engine used for validation: Godot 4.6.1 stable

## Commands Run

Gameplay boot smoke:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --quit
```

Automated suite:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd
```

## Automated Result

Final headless suite status: fail, with HUD relocation, compact-control, phase-gated-lower-net, direct-shoot, and bottom-hoop checks passing

- Pure logic passes: 1771
- Scenarios: 18 / 18
- Balance: 4 / 4
- Failures: 2

Failing pure-logic smoke checks:

- `guided make bounce starts only after floor contact`
- `straight dunk keeps moving through the landing after launch`

Validation note:

- The headless run wrote its project test summary to `user://logs/test_run_1146_test.log`.

HUD/control validation passed:

- The control panel occupies the compact lower quarter of the safe viewport: `460.8px` high on the `1920px` safe viewport.
- The panel remains bottom anchored above the configured safe margin.
- The `SHOOT | DUNK` top row still splits evenly, the `MOVE` lane remains taller than the action row, and the `MOVE` lane remains wider than either `PASS` lane.
- Main label sizes were capped at `31-32px`: `SHOOT 31`, `DUNK 31`, `MOVE 32`, `PASS 32`.
- Pass-focus labels were capped at `16px`.
- The scoreboard card still aligns to the left `SHOOT` half and stays inside the safe area.
- The standalone pause button rect was populated, no longer lived inside the scoreboard, stayed inside the safe area, sat above the control panel, aligned to the control panel's right edge, shared the scoreboard top alignment, and matched the scoreboard height.

Phase-gated lower-net validation passed:

- `HoopView.supports_four_layer_visuals()` returned true and the layering snapshot included `net_clean_bottom_half`.
- The inactive smoke snapshot placed `NetClean` below shot-ball phases and placed inactive `NetCleanBottomHalf` plus inactive `NetBody` below airborne/rim/generic-front ball phases.
- Toggling the through-net masks active placed `net_channel` and through-net `front_of_net` ball phases below active `NetCleanBottomHalf` and active `NetBody`.
- A non-descending airborne ball near the hoop used `front_of_net` while keeping `bottom_half_mask_active = false` and `net_body_mask_active = false`, so the ball rendered above both inactive lower net masks.
- The same snapshot reported `Net`, `NetClean`, `NetCleanBottomHalf`, and `NetBody` as visible `30x28` textures sharing the same position and scale.
- Made shots still entered `net_channel`, activated both lower net masks during `net_channel`, kept both active through the made-shot `front_of_net` exit, triggered net swish on score, and did not re-enter hoop rendering after the clear threshold.

Bottom-hoop-specific validation passed:

- The normalized bottom hoop texture loads as `144x170` and reports a visible bottom-court projected rect.
- The bottom hoop reports `scale_multiplier = 2.0` in the smoke snapshot.
- The bottom hoop reports `z_as_relative = false` and `z_index = 3000`.
- The z-order smoke verified live players, live ball, live top hoop, and all opponent-sim presentation sprites are below the bottom backside hoop.
- The bottom hoop remains anchored after opponent-sim cleanup.

Direct-shoot regression validation passed:

- Direct `SHOOT` tap enters `SHOT_AIM`, holds the `shot_aim` pose, shows the timing meter, leaves `pending_shot_release` empty until a second tap at the `SHOOT` button position, and then commits through the isolated `direct_shoot_button` timing mode.

Opponent presentation-specific validation passed:

- `run_possession()` returns `visual_steps` with a clamped `1..4` count.
- Every visual step has non-empty banner-ready text.
- Every generated visual step carries stable actor metadata (`player_id`, `player_role`, and `actor_team`) when applicable.
- Final visual-step points match `points_scored`.
- Repeating the same seed produces the same visual-step sequence.
- The coordinator smoke verified score and clock stay pending while the first banner beat is visible.
- The coordinator smoke verified live players and live ball hide while the opponent-sim presentation layer is active.
- The coordinator smoke verified five AWY ghost players, five HOM ghost defenders, and the ghost ball render in the bottom-half tableau layer.
- The visual snapshot verified ghost player world positions remain in the bottom half of the court.
- Auto-advance and tap-advance update both banner text and the current tableau immediately.
- Final-step completion hides the presentation layer, restores live entities, and applies score/time exactly once.
- The banner layout smoke verified full safe-width coverage, vertical centering, black `0.8` alpha, and matching current-step text.
- The coordinator smoke verified the scoreboard and controls hide while the banner is visible and restore when `LIVE_OFFENSE` resumes.
- One-second auto-advance, tap-to-advance, pause freeze/resume, final-step completion, score/time application exactly once, and banner hide all passed.

Balance metrics from the final run:

- `difficulty_order`: easy `0.92`, normal `1.04`, hard `1.23`
- `pass_risk`: short `0.00`, long `0.23`
- `rebound_distribution`: offense `0.38`, defense `0.62`
- `shot_quality`: green `1.0`, red `0.0`, contested green `1.0`, contested green window width `0.180000007152557`

## Scenario Result

Passed scenarios:

- Bad Cross Court Pass Steal
- Buzzer Shot Completion
- Center Release Idle
- Clean Pass And Shoot Make
- Contested Green Release Scores
- Contested Miss With Defensive Rebound
- Late Miss Timeout
- Long Run No Softlock
- Offensive Rebound Continuation
- Opponent Banner Game Over
- Opponent Banner Multi-Step Score
- Opponent Banner No-Score Turnover
- Opponent Banner One-Step Score
- Opponent Banner Tap Skip
- Out Of Bounds Turnover
- Pause Resume Safety
- Stationary Pressure Turnover
- Tap Red Miss

## Smoke Result

- the standalone `GameRoot` boot smoke completed without script or runtime regressions in the new control flow
- the opponent sim banner smoke passed with the sequence active in `OPPONENT_SIM`, score/clock deferred, scoreboard and controls hidden while text is visible, a centered `80%` black banner, one-second auto-advance, tap-to-advance, pause freeze/resume, exact once-only score/time application on final completion, and scoreboard/control restoration when offense resumes
- the visible control panel now occupies a compact safe-area bottom quarter as a two-row layout with an exact `50/50` top `SHOOT | DUNK` split above a taller `PASS | MOVE | PASS` row, and the main labels are capped at `34px`
- the center `MOVE` zone is now both taller and wider than either `PASS` lane, keeping live joystick movement responsive while the left and right `PASS` lanes both route to the same highlighted default receiver
- `PASS`, `SHOOT`, and `DUNK` now work as direct button taps even without a movement drag, and second-finger action taps still fire while the move drag is active
- all visible control buttons now share the same neutral dark idle base `#1b1d3a`, and only the hovered or pressed zone swaps into its action color
- the compact scoreboard card now sits bottom-left above the `SHOOT` half, stays inside the safe area, and no longer reserves the top edge of the screen
- top-left `SHOOT` releases now arm `shot_layout`, keep preview dots on court, and share a widened timing meter that spans the full `SHOOT | DUNK` top row
- top-right `DUNK` releases now request explicit dunk intent: eligible finishers skip the meter and enter the dunk make flow, close non-dunk finishers fall back to layups, and far-from-rim releases are ignored
- the pause overlay now includes a runtime `Show Controls` toggle; hiding the panel only hides the art and does not restore the legacy open-screen gesture model
- hidden-controls mode kept the same pass / move / shoot / dunk hitboxes active in deterministic smoke coverage and left the relocated scoreboard visible
- shot-meter diagnostics remain mirrored onto `CourtView` for test visibility, but only the control panel renders the meter in live play
- off-ball offense now uses the same authored shuffle row `19` as defense for any non-zero off-ball movement, and only falls back to row `1` when fully stopped
- guided makes now continue out of the hoop into a visible floor drop and a single small settle hop, then stop on the same hoop-base center used by the dunk-radius markers
- the live top hoop now uses registered `Net`, `NetClean`, `NetCleanBottomHalf`, and `NetBody` masks, with both lower net masks phase-gated so airborne/rim/generic-front balls draw above them while through-net made-shot phases draw behind them
- made shots now keep a monotonic downward rendered path from `guided_descent` through `floor_drop`, hold the full terminal drop through `net_exit`, and only begin moving upward again once the `floor_settle` bounce starts after floor contact
- the post-`net_exit` fall now uses a longer carried-velocity descent so the ball leaves the hoop at a speed that better matches the motion already established during the made shot
- made shots still keep one contiguous `front_of_net` handoff after `net_exit`, then release to plain world rendering only after the rendered ball has visibly cleared the hoop's front-net exit threshold
- the finish-radius world center is now cached from the live player-camera framing before launch, so made shots and dunk auto-finishes both land back on the exact authored marker center even after the score follow-through camera handoff
- the score follow-through camera now snaps directly into the cached landing frame and lets the net handoff offset carry the continuity, so the post-net fall no longer drifts toward a later camera target before the landing
- buzzer-beater makes now end the game as soon as the new floor settle completes, while normal made shots still wait for the visible landing before opponent sim begins

## Additional Coverage

The final pass added or updated deterministic coverage for:

- control-panel zone classification for left pass, right pass, top-left shoot, top-right dunk, and center cancel
- short-drag rejection and open-court release rejection outside the panel
- old bottom-center dunk-strip rejection after the move to the two-row layout
- direct `PASS`, `SHOOT`, and `DUNK` button taps without movement
- focused-pass-target routing through both pass lanes
- second-finger action-button taps while a move drag stays active
- neutral idle button colors plus hovered / pressed color swaps on the control panel
- hidden-controls mode preserving live input
- removal of the old direct teammate tap and open-screen upward-swipe live-offense paths
- `shot_layout` near-rim layup selection versus `dunk`-intent dunk selection and layup fallback
- far-from-rim `DUNK` releases staying in `LIVE_OFFENSE`
- pause `Show Controls` toggle sync between `PauseOverlay`, `GameCoordinator`, and `ControlPanel`
- scoreboard alignment, width match, and safe-area placement above the `SHOOT` half
- the enlarged `MOVE` lane plus the reduced pass-lane widths after the final proportion retune
- control-panel shot-meter geometry spanning beyond the `SHOOT` half while staying inside the full top action row
- scenario harness / bot pilot updates so scripted passes and shot releases use the new panel zones instead of the legacy open-screen gestures
- guided-make floor-finish sequencing through `net_exit -> floor_drop -> floor_settle`
- guided-make `net_exit` retaining full terminal drop plus pre-bounce rendered-anchor continuity until the floor bounce starts
- guided-make `floor_drop` opening from a speed-aligned carried-velocity sample instead of a faster post-net spike
- four-layer net registration, lower net mask presence, inactive-airborne z ordering above `NetCleanBottomHalf` and `NetBody`, active through-net z ordering behind both lower masks, non-descending `front_of_net` mask inactivity, and post-clear non-reentry
- grounded landing on the authored finish-radius center for both jumper makes and dunk auto-makes
- finish-radius center stability from shot launch through landing, even while the camera transitions from player tracking to ball tracking
- cached finish-marker screen targeting from pre-release camera states, plus a smoke assertion that the landed ball shares the same visible marker center
- single-window `front_of_net` follow-through, no upward rendered motion before `floor_settle`, no hoop-render re-entry after clear, forced hoop-render clearing after the front-net exit threshold, landed-before-reset behavior, and buzzer completion after the new floor settle
- latest headless suite after the dunk-button availability pass: Pure logic `1773`, Scenarios `18`, Balance `4`, Failures `2`; the only remaining failures were the pre-existing followthrough checks `guided make bounce starts only after floor contact` and `straight dunk keeps moving through the landing after launch`
- control-panel smoke coverage now asserts that the `DUNK` zone starts visually disabled from the perimeter, then clears the disabled state once the active ballhandler enters a live close-finish window near the rim
