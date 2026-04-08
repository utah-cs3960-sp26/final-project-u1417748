# Known Issues

No blocking gameplay defects are currently recorded from the automated suite.

Remaining non-blocking limitations:

- Audio is intentionally absent in v1.
- Manual on-device multi-touch validation was not performed in this session; touch behavior is covered by desktop/headless validation and input-path tests.
- Opponent possessions are intentionally abstracted into a ratings-driven sim rather than a live defensive sequence.
- The atlas art pass currently uses a focused subset of the character-sheet actions and direction buckets; not every sprite-sheet animation row is mapped yet.
- The headless Godot harness currently reports object/resource leak warnings on exit after the suite summary even though tests pass. This did not block validation, but the cleanup path should be tightened in a later pass.
