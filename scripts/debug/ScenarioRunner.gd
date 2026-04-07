extends RefCounted
class_name ScenarioRunner

var _config: TestHarnessConfig
var _log_writer: LogWriter
var _bot_pilot: BotPilot
var _rng: DeterministicRng

func _init(config: TestHarnessConfig, log_writer: LogWriter) -> void:
	_config = config
	_log_writer = log_writer
	_bot_pilot = BotPilot.new(_log_writer)
	_rng = DeterministicRng.new(_config.deterministic_seed)

func dry_run_definition(definition: ScenarioDefinition) -> TestResult:
	var validation_issues := definition.validate()
	if not validation_issues.is_empty():
		return TestResult.failed(definition.scenario_id, "scenario_catalog", validation_issues)
	_log_writer.write_event(_config.scenario_log_name, {
		"type": "scenario_catalog_validated",
		"scenario_id": definition.scenario_id,
		"summary": definition.summary(),
	})
	return TestResult.passed(definition.scenario_id, "scenario_catalog", PackedStringArray([
		definition.summary(),
	]))

func run_definition(definition: ScenarioDefinition, context: Object = null) -> TestResult:
	var validation_result := dry_run_definition(definition)
	if validation_result.status == TestResult.Status.FAILED:
		return validation_result
	_rng.reseed(definition.seed)
	_log_writer.write_event(_config.scenario_log_name, {
		"type": "scenario_started",
		"scenario_id": definition.scenario_id,
		"seed": definition.seed,
		"setup_data": definition.setup_data,
	})
	if context != null and context.has_method(DebugContract.METHOD_BEGIN_TEST_MODE):
		context.call(DebugContract.METHOD_BEGIN_TEST_MODE, {
			"seed": definition.seed,
			"setup_data": definition.setup_data,
		})
	for action in definition.actions:
		var action_result := _bot_pilot.apply_action(context, action)
		_log_writer.write_event(_config.replay_log_name, {
			"type": "scenario_step",
			"scenario_id": definition.scenario_id,
			"action": action.describe(),
			"rng": _rng.snapshot(),
			"result": action_result,
		})
	if context == null:
		return TestResult.skipped(definition.scenario_id, "scenario_execution", PackedStringArray([
			"Scenario validated and replay frames were logged.",
			"Gameplay context is not wired yet, so runtime assertions were deferred.",
		]))
	return _evaluate_expectations(definition, context)

func _evaluate_expectations(definition: ScenarioDefinition, context: Object) -> TestResult:
	if not context.has_method(DebugContract.METHOD_GET_DEBUG_SNAPSHOT):
		return TestResult.skipped(definition.scenario_id, "scenario_execution", PackedStringArray([
			"Gameplay context does not yet expose get_debug_snapshot().",
		]))
	var snapshot: Dictionary = context.call(DebugContract.METHOD_GET_DEBUG_SNAPSHOT)
	var failures := PackedStringArray()
	for expectation in definition.expectations:
		var actual_value := _resolve_snapshot_value(snapshot, expectation.subject)
		var passed := _compare(expectation, actual_value)
		_log_writer.write_assertion(expectation.describe(), passed, {
			"scenario_id": definition.scenario_id,
			"subject": expectation.subject,
			"actual": actual_value,
			"expected": expectation.expected_value,
		})
		if not passed:
			failures.append("%s actual=%s expected=%s" % [
				expectation.describe(),
				actual_value,
				expectation.expected_value,
			])
	if failures.is_empty():
		return TestResult.passed(definition.scenario_id, "scenario_execution", PackedStringArray([
			"All scenario expectations passed.",
		]))
	return TestResult.failed(definition.scenario_id, "scenario_execution", failures)

func _resolve_snapshot_value(snapshot: Dictionary, subject: String) -> Variant:
	if subject.is_empty():
		return null
	var value: Variant = snapshot
	for part in subject.split("."):
		if value is Dictionary and value.has(part):
			value = value[part]
		else:
			return null
	return value

func _compare(expectation: ScenarioExpectation, actual_value: Variant) -> bool:
	match expectation.comparison:
		ScenarioExpectation.Comparison.EQUAL:
			if expectation.tolerance > 0.0 and actual_value is float and expectation.expected_value is float:
				return absf(actual_value - float(expectation.expected_value)) <= expectation.tolerance
			return actual_value == expectation.expected_value
		ScenarioExpectation.Comparison.NOT_EQUAL:
			return actual_value != expectation.expected_value
		ScenarioExpectation.Comparison.GREATER_EQUAL:
			return float(actual_value) >= float(expectation.expected_value)
		ScenarioExpectation.Comparison.LESS_EQUAL:
			return float(actual_value) <= float(expectation.expected_value)
		ScenarioExpectation.Comparison.CONTAINS:
			if actual_value is Array:
				return actual_value.has(expectation.expected_value)
			if actual_value is String:
				return String(actual_value).contains(String(expectation.expected_value))
			return false
		ScenarioExpectation.Comparison.EXISTS:
			return actual_value != null
		ScenarioExpectation.Comparison.BOOLEAN_TRUE:
			return bool(actual_value)
		ScenarioExpectation.Comparison.BOOLEAN_FALSE:
			return not bool(actual_value)
	return false
