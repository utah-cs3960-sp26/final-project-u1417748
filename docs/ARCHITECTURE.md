# Architecture

## Current Scaffold

The repository now contains a minimal Godot project centered on reusable presentation scenes.

### Main Flow

- `res://scenes/MainMenu.tscn`
- `res://scenes/GameRoot.tscn`

`MainMenu` is a presentation-only entry scene that changes to `GameRoot` when the start button is pressed.

## Presentation Modules

### Shared Config

- `res://scripts/presentation/PresentationTheme.gd`
- `res://data/config/RetroPresentationTheme.tres`

This resource owns the current palette, viewport reference size, court margins, and basic sizing constants for court and entity art.

### Court And Entities

- `res://scenes/Court.tscn`
- `res://scenes/entities/Player.tscn`
- `res://scenes/entities/Ball.tscn`
- `res://scenes/entities/Hoop.tscn`

These scenes are rendered through lightweight typed GDScript draw calls. They do not own gameplay state.

### UI Scenes

- `res://scenes/ui/HUD.tscn`
- `res://scenes/ui/PauseOverlay.tscn`
- `res://scenes/ui/GameOverOverlay.tscn`
- `res://scenes/debug/DebugOverlay.tscn`

These scenes are themed by `RetroUiThemeBuilder.gd` and expose simple presentation scripts for later integration.

## Decoupling Rules Used Here

- No gameplay singleton or coordinator was introduced in this session.
- Presentation scripts do not decide possessions, scoring, routes, or timing outcomes.
- The UI only emits button-level signals or updates labels.
- The demo dribble motion in `GameRootView.gd` is purely a visual attract-mode placeholder.

## Next Integration Targets

1. replace `GameRootView.gd` with a real coordinator-driven match scene controller
2. connect HUD text and overlays to an explicit game state machine
3. drive player and ball presentation scenes from gameplay data instead of static demo positions
4. add input, AI, and deterministic diagnostics layers behind the existing scene structure
