# Test Plan

## Presentation Scaffold Checks

Once Godot 4.6.2 stable is available, run these smoke checks in the editor:

1. open the project and confirm it boots to `MainMenu`
2. press `Start Game` and confirm `GameRoot` loads without scene or script errors
3. verify the court is portrait-oriented with a top-center hoop and lower-third joystick zone
4. verify five home and five away player placeholders render in readable default spacing
5. verify the HUD banner renders cleanly with `HOM`, timer, pause, and `AWY`
6. verify pause overlay opens from the pause button and from `Esc`
7. verify `F3` toggles the debug overlay
8. confirm the ball demo bounce remains visual-only and does not trigger scene errors

## Static Validation Done In This Session

- scene paths and resource references were checked manually
- presentation scripts were reviewed for scene-node path consistency
- project settings were checked for portrait configuration and main-scene boot path

## Deferred Automated Validation

The full project still needs:
- GDScript parse checks in Godot
- deterministic scenario tests
- gameplay and state-machine tests
- logging verification
