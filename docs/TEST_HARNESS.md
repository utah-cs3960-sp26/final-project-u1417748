# Test Harness

This repository needs a deterministic harness that can validate gameplay-heavy systems without depending on ad hoc editor play.

This document defines the clean-room test structure to use for a Godot 4.6 typed GDScript basketball game.

## Goals

- Deterministic by default under test mode.
- Seeded and replayable.
- Split into pure logic, deterministic scenario, balance batch, and long-run stability layers.
- Logged to `user://logs/`.
- Separated from runtime gameplay code.

## Directory Layout

```
tests/
  RunTests.gd
  TestRunner.gd
  ScenarioRunner.gd
  BotPilot.gd
  BalanceRunner.gd
  harness/
    DeterministicRng.gd
    TestResult.gd
    ScenarioAction.gd
    ScenarioDefinition.gd
    ScenarioExpectation.gd
    BalanceBatchDefinition.gd
  pure_logic/
  scenarios/
  balance/
  fixtures/
  stability/
```

## Deterministic Runner Contract

The runner should expose one headless entrypoint and a small set of reusable test primitives:

- `RunTests.gd` is the headless entrypoint.
- `TestRunner.gd` owns category ordering and summary reporting.
- `ScenarioRunner.gd` executes a seeded scenario resource against a match context.
- `BotPilot.gd` queues scripted input actions.
- `BalanceRunner.gd` executes repeated seeded trials and emits aggregate metrics.

## Recommended Resource Interfaces

### `ScenarioDefinition`

Required fields:

- `scenario_id: String`
- `display_name: String`
- `seed: int`
- `initial_time_remaining: float`
- `initial_home_score: int`
- `initial_away_score: int`
- `actions: Array[ScenarioAction]`
- `expectations: Array[ScenarioExpectation]`

### `ScenarioAction`

Recommended fields:

- `kind: String`
- `seconds: float`
- `target_id: String`
- `vector: Vector2`
- `value: Variant`
- `note: String`

### `ScenarioExpectation`

Recommended fields:

- `kind: String`
- `subject: String`
- `comparison: String`
- `value: Variant`
- `tolerance: float`

### `BalanceBatchDefinition`

Recommended fields:

- `batch_id: String`
- `display_name: String`
- `seed: int`
- `trial_count: int`
- `metric_keys: Array[String]`
- `limits: Dictionary`

## Test Categories

1. Pure logic tests for deterministic math and state functions.
2. Scenario tests for scripted possession flows.
3. Balance batches for broad statistical sanity.
4. Stability tests for long-run no-softlock behavior.

## Logging Contract

The harness should write separate artifacts for:

- match log
- event log
- test run log
- scenario log
- balance log

Logs should be line-oriented and human readable first, structured second.

## Minimal Interface Guidance

The harness should prefer small methods that are easy to mock:

- `run_all() -> Array[TestResult]`
- `run_scenario(definition: ScenarioDefinition) -> TestResult`
- `run_batch(definition: BalanceBatchDefinition) -> Dictionary`
- `step(delta: float) -> bool`
- `write_results() -> void`

The exact runtime gameplay implementation can evolve later. The harness contract should stay stable so future work can add gameplay coverage without rewriting the test structure.
