# Known Issues

No blocking opponent-sim banner defects are currently recorded from the automated suite.

Remaining non-blocking limitations:

- The latest full headless suite exits non-zero on two shot-followthrough smoke checks outside the opponent-sim banner path: `guided make bounce starts only after floor contact` and `straight dunk keeps moving through the landing after launch`.
- Audio is intentionally absent in v1.
- Manual on-device multi-touch validation was not performed in this session; touch behavior is covered by desktop/headless validation and input-path tests.
- Live offense intentionally honors only one gameplay touch at a time. Extra touches are ignored except for HUD interaction and the shot-timing tap.
- Mobile haptics use best-effort `Input.vibrate_handheld()` support and degrade silently on unsupported devices or desktop builds.
- Opponent possessions remain ratings-driven and text-presented rather than a live defensive sequence; the action banner explains the simulated possession but does not animate AWY players.
- `PauseOverlay` and `GameOverOverlay` still use the older fixed-position panel layout; the responsive safe-area pass in this session only covered the live-match HUD and centered court framing.
- The staged `SHOT_RELEASE` presentation intentionally keeps the standalone world ball hidden while a player-held sprite still owns the ball; single-frame captures before the authored release frame will therefore show no loose ball, which is expected behavior.
- The armed timing flow intentionally keeps the committed shot animation playing after the timing tap while the locked result waits for the authored release frame; if the player never taps before the bar ends, a late miss is forced by design.
- The headless Godot harness currently reports object/resource leak warnings on exit after the suite summary even though tests pass. This did not block validation, but the cleanup path should be tightened in a later pass.
