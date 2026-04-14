# Test Results

## Environment

- Date: 2026-04-14
- Workspace: `/Users/teeds/Desktop/Programming/RetroBasketball/PocketHoops/final-project-u1417748`
- Engine used for validation: Godot 4.6.1 stable

## Commands Run

Gameplay boot smoke:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . res://scenes/GameRoot.tscn --quit-after 3
```

Automated suite:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --script tests/RunTests.gd
```

## Automated Result

Final headless suite status: pass

- Pure logic: 1622 / 1622
- Scenarios: 13 / 13
- Balance: 4 / 4
- Failures: 0

Balance metrics from the final run:

- `difficulty_order`: easy `0.94`, normal `1.07`, hard `1.32`
- `pass_risk`: short `0.00`, long `0.23`
- `rebound_distribution`: offense `0.28`, defense `0.72`
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
- Out Of Bounds Turnover
- Pause Resume Safety
- Stationary Pressure Turnover
- Tap Red Miss

## Smoke Result

- the standalone `GameRoot` boot smoke and the full headless suite both completed without script or runtime regressions in the new control flow
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
