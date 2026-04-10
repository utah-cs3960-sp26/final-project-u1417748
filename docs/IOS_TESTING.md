# iOS Test Install

This project already has portrait orientation enabled in [`project.godot`](/Users/teeds/Desktop/Programming/RetroBasketball/PocketHoops/final-project-u1417748/project.godot#L24) and touch input wired through [`scripts/input/InputController.gd`](/Users/teeds/Desktop/Programming/RetroBasketball/PocketHoops/final-project-u1417748/scripts/input/InputController.gd). The shipped mobile flow is now an invisible lower-screen movement zone with release-to-pass, quick-tap shot arming, and tap-anywhere shot timing.

## Local preset

An iOS export preset now exists in `export_presets.cfg` for local testing. It is intentionally git-ignored because it contains signing metadata.

Current preset values:

- team ID: `PHLT3QV58J`
- bundle ID: `com.teeds.pockethoops.dev`
- export target: `.godot/ios_export/PocketHoops.xcodeproj`
- export mode: project-only export for Xcode install

If your Apple team identifier is different, update `application/app_store_team_id` in `export_presets.cfg` before exporting.

## Godot export flow

1. Open the project in Godot 4.6.1 or 4.6.2.
2. Go to `Project > Export`.
3. Select the `iOS` preset.
4. Verify the team ID and bundle identifier.
5. Click `Export Project`.
6. Export. The preset now defaults to `.godot/ios_export/PocketHoops.xcodeproj`.

## Xcode install flow

1. Open the generated [`PocketHoops.xcodeproj`](/Users/teeds/Desktop/Programming/RetroBasketball/PocketHoops/final-project-u1417748/.godot/ios_export/PocketHoops.xcodeproj) in Xcode.
2. Select the `PocketHoops` target.
3. In `Signing & Capabilities`, confirm `Automatically manage signing` is enabled and your developer team is selected.
4. Connect your iPhone and choose it as the run destination.
5. Press `Run`.

## Device-side requirements

- The phone may prompt you to trust the developer certificate the first time.
- On modern iOS versions, `Developer Mode` may need to be enabled before the app can launch.

## CLI fallback

You can also export from Terminal:

```bash
'/Applications/Godot.app/Contents/MacOS/Godot' --headless --path . --export-debug iOS .godot/ios_export/PocketHoops.xcodeproj
```

That path keeps the generated Xcode project in the ignored `.godot/` export area while you test.
