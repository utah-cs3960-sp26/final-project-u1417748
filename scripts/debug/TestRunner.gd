extends Control
class_name TestRunner

@export var harness_config: TestHarnessConfig
@export var debug_config: DebugConfig

@onready var _status_label: Label = %StatusLabel
@onready var _scenario_list: ItemList = %ScenarioList
@onready var _output_text: RichTextLabel = %OutputText
@onready var _debug_overlay: DebugOverlay = %DebugOverlay

var _harness: TestHarness

func _ready() -> void:
	if harness_config == null:
		harness_config = TestHarnessConfig.new()
	if debug_config == null:
		debug_config = DebugConfig.new()
	_harness = TestHarness.new(harness_config)
	_debug_overlay.config = debug_config
	_refresh_catalogs()
	_append_output("Pocket Hoops diagnostics scaffold ready.")
	_append_output("Use this scene to validate test catalogs, log plumbing, and future gameplay hooks.")

func _on_run_smoke_suite_pressed() -> void:
	var results := _harness.run_pure_logic_suite()
	_emit_summary("Pure Logic", results)

func _on_validate_scenarios_pressed() -> void:
	var results := _harness.run_scenario_catalog()
	_emit_summary("Scenario Catalog", results)

func _on_validate_balance_pressed() -> void:
	var results := _harness.run_balance_catalog()
	_emit_summary("Balance Catalog", results)

func _on_refresh_pressed() -> void:
	_refresh_catalogs()
	_append_output("Catalogs refreshed from disk.")

func _refresh_catalogs() -> void:
	_harness.load_scenarios()
	_harness.load_balance_batches()
	_scenario_list.clear()
	for scenario_id in _harness.loaded_scenarios.keys():
		var definition: ScenarioDefinition = _harness.loaded_scenarios[scenario_id]
		_scenario_list.add_item("%s - %s" % [scenario_id, definition.title])
	_status_label.text = "Scenarios: %d | Balance batches: %d" % [
		_harness.loaded_scenarios.size(),
		_harness.loaded_balance_batches.size(),
	]
	_debug_overlay.update_snapshot({
		"game_state": "diagnostics_idle",
		"rng_seed": harness_config.deterministic_seed,
		"seed": harness_config.deterministic_seed,
		"shot_preview": "pending gameplay integration",
		"route_geometry": "provider hook ready",
		"defender_assignments": "provider hook ready",
		"contest_radii": "provider hook ready",
		"catch_radii": "provider hook ready",
		"intercept_corridors": "provider hook ready",
		"rebound_zone": "provider hook ready",
	})

func _emit_summary(label: String, results: Array[TestResult]) -> void:
	var summary := _harness.summarize(results)
	_append_output("%s -> passed=%d failed=%d skipped=%d total=%d" % [
		label,
		summary["passed"],
		summary["failed"],
		summary["skipped"],
		summary["total"],
	])
	for result in results:
		_append_output("[%s] %s" % [result.status_text(), result.test_id])
		for detail in result.details:
			_append_output("  %s" % detail)

func _append_output(line: String) -> void:
	if _output_text.text.is_empty():
		_output_text.text = line
	else:
		_output_text.text += "\n%s" % line
