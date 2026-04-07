extends RefCounted
class_name TestHarness

var config: TestHarnessConfig
var log_writer: LogWriter
var scenario_runner: ScenarioRunner
var loaded_scenarios: Dictionary = {}
var loaded_balance_batches: Dictionary = {}

func _init(harness_config: TestHarnessConfig) -> void:
	config = harness_config
	log_writer = LogWriter.new(config)
	scenario_runner = ScenarioRunner.new(config, log_writer)

func load_scenarios() -> Dictionary:
	loaded_scenarios = _load_resources(config.scenario_directory, ".tres")
	return loaded_scenarios

func load_balance_batches() -> Dictionary:
	loaded_balance_batches = _load_resources(config.balance_directory, ".tres")
	return loaded_balance_batches

func discover_test_cases() -> Array[TestCase]:
	var cases: Array[TestCase] = []
	for path in _list_files_recursive(config.pure_logic_test_directory, ".gd"):
		var script_resource := load(path)
		if script_resource is GDScript:
			var candidate := script_resource.new()
			if candidate is TestCase:
				cases.append(candidate)
	return cases

func run_pure_logic_suite() -> Array[TestResult]:
	var results: Array[TestResult] = []
	for test_case in discover_test_cases():
		var started_at := Time.get_ticks_usec()
		var result := test_case.run_case(self)
		result.duration_seconds = float(Time.get_ticks_usec() - started_at) / 1000000.0
		results.append(result)
		log_writer.write_test_result(result)
	return results

func run_scenario_catalog() -> Array[TestResult]:
	if loaded_scenarios.is_empty():
		load_scenarios()
	var results: Array[TestResult] = []
	for scenario_id in loaded_scenarios.keys():
		var definition: ScenarioDefinition = loaded_scenarios[scenario_id]
		var result := scenario_runner.dry_run_definition(definition)
		results.append(result)
		log_writer.write_test_result(result)
	return results

func run_balance_catalog() -> Array[TestResult]:
	if loaded_balance_batches.is_empty():
		load_balance_batches()
	var results: Array[TestResult] = []
	for batch_id in loaded_balance_batches.keys():
		var definition: BalanceBatchDefinition = loaded_balance_batches[batch_id]
		var issues := definition.validate()
		var result := TestResult.passed(batch_id, "balance_catalog", PackedStringArray([
			definition.title,
		]))
		if not issues.is_empty():
			result = TestResult.failed(batch_id, "balance_catalog", issues)
		results.append(result)
		log_writer.write_test_result(result)
	return results

func summarize(results: Array[TestResult]) -> Dictionary:
	var passed := 0
	var failed := 0
	var skipped := 0
	for result in results:
		match result.status:
			TestResult.Status.PASSED:
				passed += 1
			TestResult.Status.FAILED:
				failed += 1
			TestResult.Status.SKIPPED:
				skipped += 1
	return {
		"passed": passed,
		"failed": failed,
		"skipped": skipped,
		"total": results.size(),
	}

func required_scenarios_present() -> bool:
	if loaded_scenarios.is_empty():
		load_scenarios()
	for required_id in config.required_scenarios:
		if not loaded_scenarios.has(required_id):
			return false
	return true

func required_balance_batches_present() -> bool:
	if loaded_balance_batches.is_empty():
		load_balance_batches()
	for required_id in config.required_balance_batches:
		if not loaded_balance_batches.has(required_id):
			return false
	return true

func _load_resources(base_dir: String, suffix: String) -> Dictionary:
	var resources := {}
	for path in _list_files_recursive(base_dir, suffix):
		var resource := load(path)
		if resource == null:
			continue
		var resource_id := ""
		if resource.has_method("get"):
			if resource.get("scenario_id") != null and not String(resource.get("scenario_id")).is_empty():
				resource_id = String(resource.get("scenario_id"))
			elif resource.get("batch_id") != null and not String(resource.get("batch_id")).is_empty():
				resource_id = String(resource.get("batch_id"))
		if resource_id.is_empty():
			resource_id = path.get_file().get_basename().to_snake_case()
		resources[resource_id] = resource
	return resources

func _list_files_recursive(base_dir: String, suffix: String) -> PackedStringArray:
	var results := PackedStringArray()
	_scan_dir(base_dir, suffix, results)
	return results

func _scan_dir(base_dir: String, suffix: String, results: PackedStringArray) -> void:
	var directory := DirAccess.open(base_dir)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var full_path := base_dir.path_join(entry)
		if directory.current_is_dir():
			_scan_dir(full_path, suffix, results)
		elif full_path.ends_with(suffix):
			results.append(full_path)
		entry = directory.get_next()
	directory.list_dir_end()
