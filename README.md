# Pocket Hoops

Pocket Hoops is a portrait-only, mobile-first, offense-only arcade basketball game being built in Godot 4.6.2 stable with typed GDScript.

This repository currently contains the project scaffold: the Godot project bootstrap, placeholder navigation scenes, baseline configuration resources, directory structure, the diagnostics/test harness foundation, and the documentation set future gameplay passes will build on.

## Current Status

This pass does not implement live basketball gameplay yet.

It does establish:

- a valid Godot project with portrait/mobile defaults
- a `MainMenu` scene, placeholder `GameRoot` scene, and diagnostics runner scene
- typed GDScript resource classes for major tuning and diagnostics domains
- project directories for scenes, scripts, data, tests, and docs
- baseline architecture, testing, worklog, and decision documentation
- resource-backed scenario and balance catalogs for future deterministic runs

## Requirements

- Godot 4.6.2 stable
- typed GDScript for new gameplay code

## Quick Start

1. Open the repository in Godot 4.6.2 stable.
2. Run the project. The main scene is `res://scenes/MainMenu.tscn`.
3. Use the menu to open either the placeholder match shell or the diagnostics runner.
4. The diagnostics scene lives at `res://scenes/debug/TestRunner.tscn`.

## Repository Layout

- `scenes/` contains bootstrap and future runtime scenes.
- `scripts/` is organized by subsystem ownership stream.
- `data/config/` stores editable `Resource` instances for tuning.
- `data/teams/`, `data/routes/`, `data/scenarios/`, and `data/balance/` are reserved for authored data.
- `tests/` is pre-split into pure-logic, scenario, balance, stability, and fixture buckets.
- `docs/` contains the durable project brief, architecture, decisions, and testing docs.

## Config Strategy

Major tuning is data-driven. Each core subsystem has:

- a typed `Resource` script in `scripts/config/` or `scripts/debug/` for diagnostics
- a project instance in `data/config/`

The baseline scaffold includes:

- `GameConfig`
- `CourtConfig`
- `BallPhysicsConfig`
- `ShotTimingConfig`
- `PassConfig`
- `RouteConfig`
- `DefenseConfig`
- `ReboundConfig`
- `OpponentSimConfig`
- `DifficultyConfig`
- `DebugConfig`

## Ownership Streams

The repo is documented around these workstreams:

- Coordinator / Tech Lead
- Gameplay / Input
- Ball Physics / Hoop
- AI / Movement
- Game State / Simulation / UI
- Testing / Diagnostics
- Art / Polish

See `docs/ARCHITECTURE.md` for the subsystem boundaries and handoff expectations.

## Documentation Map

- `docs/PROJECT_BRIEF.md` describes the product target.
- `docs/GAMEPLAY_SPEC.md` captures gameplay rules and interaction constraints.
- `docs/ARCHITECTURE.md` defines scene, script, config, and ownership structure.
- `docs/TEST_PLAN.md` defines the intended automated and manual test layers.
- `docs/DECISIONS.md`, `docs/WORKLOG.md`, `docs/KNOWN_ISSUES.md`, and `docs/TEST_RESULTS.md` track ongoing implementation state.

The root `PROJECT_BRIEF.md` and `ACCEPTANCE_TESTS.md` remain useful source documents for the broader class project brief and acceptance bar.

## Testing

The repository already includes early diagnostics and harness files, but this pass could not validate them in-engine because no Godot executable was available on the shell `PATH`.

Implemented now:

- resource-backed scenario definitions for the required acceptance cases
- resource-backed balance batch definitions for the required balance categories
- pure logic smoke tests for RNG and catalog completeness
- a reusable debug overlay, BotPilot, ScenarioRunner, and persistent log writer

Current validation is still limited to:

- project boot
- scene navigation
- resource and script load sanity

Planned test structure and expected commands are documented in `docs/TEST_PLAN.md`.
