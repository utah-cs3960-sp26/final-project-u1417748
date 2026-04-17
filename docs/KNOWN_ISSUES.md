# Known Issues

Current blocking automated-suite issues:

- The latest full headless suite exits non-zero on six checks: `guided make bounce starts only after floor contact`, `straight dunk keeps moving through the landing after launch`, `Opponent Banner Game Over`, `Opponent Banner Multi-Step Score`, `Opponent Banner One-Step Score`, and `Opponent Banner Tap Skip`.

Remaining non-blocking limitations:

- Audio is intentionally absent in v1.
- Manual on-device multi-touch validation was not performed in this session; touch behavior is covered by desktop/headless validation and input-path tests.
- Live offense intentionally honors only one gameplay touch at a time. Extra touches are ignored except for HUD interaction and the shot-timing tap.
- Mobile haptics use best-effort `Input.vibrate_handheld()` support and degrade silently on unsupported devices or desktop builds.
- Opponent possessions remain ratings-driven static jump-cut tableaux rather than a continuous live defensive sequence; the presentation shows players and ball positions for each action beat, but does not animate movement between beats.
- Headless validation with an explicit engine `--log-file` can emit warnings that project `user://logs/...` files could not be opened. The suite summary still writes to the explicit log path, but the project log path should be checked in a later diagnostics pass.
- `GameOverOverlay` still uses the older fixed-position panel layout; `PauseOverlay` now uses the responsive safe-area pass, but the game-over screen has not yet been converted to the same rect-driven layout path.
- The staged `SHOT_RELEASE` presentation intentionally keeps the standalone world ball hidden while a player-held sprite still owns the ball; single-frame captures before the authored release frame will therefore show no loose ball, which is expected behavior.
- The armed timing flow intentionally keeps the committed shot animation playing after the timing tap while the locked result waits for the authored release frame; if the player never taps before the bar ends, a late miss is forced by design.
- The headless Godot harness currently reports object/resource leak warnings on exit after the suite summary even though tests pass. This did not block validation, but the cleanup path should be tightened in a later pass.
