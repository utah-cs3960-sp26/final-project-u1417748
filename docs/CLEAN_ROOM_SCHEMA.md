# Clean-Room Schema and Docs Outline

This document is the clean-room guidance layer for the Pocket Hoops project. It describes the minimum authored data shapes and the documentation update order needed to build the game from scratch without importing implementation code from any prior branch.

## 1. Resource Class Shapes

All gameplay-affecting values should live in typed `Resource` scripts under `scripts/config/` and authored `.tres` instances under `data/config/`.

### 1.1 Core config resources

Each config should be a small, typed `Resource` with only exported tuning fields.

- `GameConfig`
  - match duration
  - startup scene routing
  - scoring / reset policy toggles
  - deterministic-test flags
- `CourtConfig`
  - court rectangle
  - hoop position
  - rim / backboard geometry
  - three-point radius
  - normalized formation anchors
- `BallPhysicsConfig`
  - ball radius
  - gravity
  - launch speed bounds
  - bounce damping
  - preview sample count
- `ShotTimingConfig`
  - hold-to-shoot delay
  - meter cycle duration
  - green meter window
  - meter layout dimensions
  - post-score follow-through duration
- `PassConfig`
  - pass speed
  - catch radius
  - interception corridor width
  - interception probability modifiers
- `RouteConfig`
  - three route package definitions
  - route anchor offsets
  - spacing / separation thresholds
- `DefenseConfig`
  - guard distance
  - contest radius
  - block radius
  - steal pressure settings
- `ReboundConfig`
  - rebound zone radius
  - pursuit delay
  - rebound weighting
- `OpponentSimConfig`
  - possession time range
  - shot attempt weights
  - turnover weights
  - second-chance weights
- `DifficultyConfig`
  - Easy / Normal / Hard enum or named fields
  - difficulty multipliers for pressure, offense, and rebound
- `DebugConfig`
  - overlay toggles
  - log verbosity toggles
  - deterministic seed visibility

### 1.2 Team and player data

`PlayerData` and `TeamData` should be authored resources, not hard-coded lineups.

- `PlayerData`
  - `player_id`
  - `display_name`
  - `role`
  - ratings on a 0–100 scale:
    - speed
    - acceleration
    - handle
    - pass_accuracy
    - catch
    - shooting
    - release_consistency
    - perimeter_defense
    - steal
    - block
    - rebound
    - sim_offense
- `TeamData`
  - `team_id`
  - `team_name`
  - `short_name`
  - roster of exactly five `PlayerData` resources
  - optional color palette hints for rendering

### 1.3 Scenario and balance data

Deterministic testing should be resource-backed too.

- `ScenarioDefinition`
  - `scenario_id`
  - title
  - seed
  - initial score
  - initial clock
  - scripted actions
  - expected assertions
- `ScenarioAction`
  - action type
  - target player or touch target
  - duration
  - offset / vector data
  - optional wait / assert payload
- `ScenarioExpectation`
  - expected state
  - expected score
  - expected log fragment
  - expected possession owner
- `BalanceBatchDefinition`
  - batch name
  - seed
  - trial count
  - metric bands
  - pass/fail thresholds

## 2. File Layout

Use these folders as the minimum authored-data layout:

- `data/config/`
  - one `.tres` per config resource
- `data/teams/`
  - `HOM.tres`
  - `AWY.tres`
- `data/scenarios/`
  - one `.tres` per required deterministic scenario
- `data/balance/`
  - one `.tres` per balance batch or tuning probe
- `docs/`
  - durable project and test documentation

## 3. Docs Update Outline

The documentation should be updated in the same implementation session as the matching authored data. Use this order:

1. `docs/PROJECT_BRIEF.md`
   - lock the product summary, platform target, and scope boundaries
2. `docs/GAMEPLAY_SPEC.md`
   - define control rules, state flow, scoring, AI, and opponent sim behavior
3. `docs/ARCHITECTURE.md`
   - describe scene structure, resource ownership, controller boundaries, and logging paths
4. `docs/DECISIONS.md`
   - record any non-obvious implementation choice, especially data-shape and control-scheme decisions
5. `docs/TEST_PLAN.md`
   - enumerate pure-logic, scenario, balance, stability, and smoke tests
6. `docs/WORKLOG.md`
   - note what changed, why it changed, and any tuning tradeoffs
7. `docs/KNOWN_ISSUES.md`
   - record deferred work, runtime gaps, or visual shortcomings
8. `docs/TEST_RESULTS.md`
   - capture actual validation results, including deterministic runs and balance batches

## 4. Recommended Decision Rules

- Prefer the simplest resource shape that can be edited in the Godot inspector.
- Keep authored data separate from runtime logic.
- Keep `GameCoordinator` as the only global match-state authority.
- Record any control-scheme, scoring, possession-reset, or test-harness change in `docs/DECISIONS.md`.
- If a feature is simplified, write down the reason immediately rather than relying on commit history.
