# Tests

This directory is the deterministic harness surface for the project.

## Layout

- `RunTests.gd` is the headless entrypoint.
- `TestRunner.gd` coordinates all categories and writes summary logs.
- `ScenarioRunner.gd` executes seeded resource-defined scenarios.
- `BotPilot.gd` queues scripted input actions.
- `BalanceRunner.gd` runs statistical sanity batches.
- `harness/` contains the typed Resource definitions used by scenarios and batches.
- `pure_logic/` holds unit-style deterministic logic tests.
- `scenarios/` holds scenario resources or scenario-specific fixtures.
- `balance/` holds balance batch resources and metric definitions.
- `fixtures/` holds reusable setup data and golden outputs.
- `stability/` holds long-run soft-lock checks.

## Contract

The harness should be deterministic under a fixed seed, write logs to `user://logs/`, and avoid importing runtime gameplay dependencies unless a test explicitly needs them.
