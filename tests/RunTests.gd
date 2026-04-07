extends SceneTree

var _harness: TestHarness
var _all_results: Array[TestResult] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var harness_config: TestHarnessConfig = load("res://data/config/TestHarnessConfig.tres")
	_harness = TestHarness.new(harness_config)
	_all_results.append_array(_harness.run_pure_logic_suite())
	_harness.load_scenarios()
	for scenario_id: String in harness_config.required_scenarios:
		if not _harness.loaded_scenarios.has(scenario_id):
			_all_results.append(TestResult.failed(scenario_id, "scenario_execution", PackedStringArray([
				"Scenario definition missing from catalog.",
			])))
			continue
		var scene: PackedScene = load("res://scenes/GameRoot.tscn")
		var context: GameCoordinator = scene.instantiate()
		root.add_child(context)
		await process_frame
		var definition: ScenarioDefinition = _harness.loaded_scenarios[scenario_id]
		var result: TestResult = _harness.scenario_runner.run_definition(definition, context)
		_all_results.append(result)
		context.queue_free()
		await process_frame
	_all_results.append_array(_harness.run_balance_catalog())
	for result: TestResult in _all_results:
		print("[%s] %s" % [result.status_text(), result.test_id])
		for detail: String in result.details:
			print("  %s" % detail)
	var summary: Dictionary = _harness.summarize(_all_results)
	print("SUMMARY %s" % JSON.stringify(summary))
	quit(1 if int(summary.get("failed", 0)) > 0 else 0)
