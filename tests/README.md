# Tests Layout

This directory is the in-project diagnostics surface for Pocket Hoops.

## Subdirectories

- `pure_logic/` contains deterministic, code-only tests that do not require a live gameplay scene.
- `scenarios/` is reserved for future integration scripts that execute `ScenarioDefinition` resources against a gameplay context.
- `balance/` is reserved for future batch runners that consume `BalanceBatchDefinition` resources and emit tuning metrics.
- `fixtures/` is reserved for reusable seeded setup data, replay baselines, and golden logs.

## Current Status

The initial scaffold focuses on smoke coverage for:
- deterministic RNG reproducibility
- scenario catalog completeness and validation
- balance catalog completeness and validation
- log writing through the custom harness

Future loops should keep new tests small, deterministic, and aligned with the categories in `docs/TEST_PLAN.md`.
