# Known Issues

No blocking gameplay defects are currently recorded from the automated suite.

Remaining non-blocking limitations:

- Audio is intentionally absent in v1.
- Manual on-device multi-touch validation was not performed in this session; touch behavior is covered by desktop/headless validation and input-path tests.
- Opponent possessions are intentionally abstracted into a ratings-driven sim rather than a live defensive sequence.
- The staged `SHOT_RELEASE` presentation intentionally keeps the standalone world ball hidden while a player-held sprite still owns the ball; single-frame captures before the authored release frame will therefore show no loose ball, which is expected behavior.
- The synced aim windup intentionally keeps the committed shot animation playing after an early release while the shot quality stays locked; if the player holds past the authored release frame, the auto-release is forced to miss by design.
- The headless Godot harness currently reports object/resource leak warnings on exit after the suite summary even though tests pass. This did not block validation, but the cleanup path should be tightened in a later pass.
