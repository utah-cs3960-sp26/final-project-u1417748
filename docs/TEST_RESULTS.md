# Test Results

## Phase-Gated Net, Direct Shoot, and Bottom Hoop Validation

The live top hoop now treats `NetCleanBottomHalf` as a phase-gated lower net mask. It stays below normal airborne, rim-mouth, and generic non-descending `front_of_net` ball frames, then rises above the ball during `net_channel` and the contiguous made-shot net-exit follow-through. `NetBody` remains above every top-hoop shot phase. The direct top-left `SHOOT` button two-tap timing path and bottom backside hoop validation from the same working tree are still covered. The full suite still exits non-zero because two existing shot-followthrough smoke checks are failing outside these paths.

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
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --log-file /tmp/pockethoops_godot_phase_gated_net_latest.log --script tests/RunTests.gd
```

## Automated Result

Final headless suite status: fail, with non-phase-gated-net, non-direct-shoot, and non-bottom-hoop failures only

- Pure logic passes: 1756
- Scenarios: 18 / 18
- Balance: 4 / 4
- Failures: 2

Failing pure-logic smoke checks:

- `guided make bounce starts only after floor contact`
- `straight dunk keeps moving through the landing after launch`

Validation note:

- The explicit `--log-file /tmp/pockethoops_godot_phase_gated_net_latest.log` run completed and preserved the test summary, but Godot also emitted warnings that project `user://logs/...` files could not be opened during that headless invocation.

Phase-gated net validation passed:

- `HoopView.supports_four_layer_visuals()` returned true and the layering snapshot included `net_clean_bottom_half`.
- The inactive smoke snapshot placed `NetClean` below shot-ball phases, inactive `NetCleanBottomHalf` below airborne/rim/generic-front ball phases, and `NetBody` above all top-hoop shot phases.
- Toggling the bottom-half mask active placed `net_channel` and through-net `front_of_net` ball phases below active `NetCleanBottomHalf`, with active `NetCleanBottomHalf` still below `NetBody`.
- A non-descending airborne ball near the hoop used `front_of_net` while keeping `bottom_half_mask_active = false`, so the ball rendered above inactive `NetCleanBottomHalf` and below `NetBody`.
- The same snapshot reported `Net`, `NetClean`, `NetCleanBottomHalf`, and `NetBody` as visible `30x28` textures sharing the same position and scale.
- Made shots still entered `net_channel`, activated the bottom-half mask during `net_channel`, kept it active through the made-shot `front_of_net` exit, triggered net swish on score, and did not re-enter hoop rendering after the clear threshold.

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

- `difficulty_order`: easy `0.93`, normal `1.07`, hard `1.26`
- `pass_risk`: short `0.00`, long `0.23`
- `rebound_distribution`: offense `0.29`, defense `0.71`
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
- the visible control panel now occupies the safe-area bottom third as a two-row layout with an exact `50/50` top `SHOOT | DUNK` split above a taller `PASS | MOVE | PASS` row
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
- the live top hoop now uses registered `Net`, `NetClean`, `NetCleanBottomHalf`, and `NetBody` masks, with `NetCleanBottomHalf` phase-gated so airborne/rim/generic-front balls draw above it while through-net made-shot phases draw behind it
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
- four-layer net registration, bottom-half mask presence, inactive-airborne z ordering above `NetCleanBottomHalf`, active through-net z ordering behind `NetCleanBottomHalf`, non-descending `front_of_net` mask inactivity, and post-clear non-reentry
- grounded landing on the authored finish-radius center for both jumper makes and dunk auto-makes
- finish-radius center stability from shot launch through landing, even while the camera transitions from player tracking to ball tracking
- cached finish-marker screen targeting from pre-release camera states, plus a smoke assertion that the landed ball shares the same visible marker center
- single-window `front_of_net` follow-through, no upward rendered motion before `floor_settle`, no hoop-render re-entry after clear, forced hoop-render clearing after the front-net exit threshold, landed-before-reset behavior, and buzzer completion after the new floor settle
