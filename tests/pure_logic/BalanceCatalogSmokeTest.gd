extends TestCase

func get_test_id() -> String:
	return "balance_catalog_required_entries"

func get_category() -> String:
	return "pure_logic"

func run_case(harness: Object) -> TestResult:
	if not (harness is TestHarness):
		return TestResult.failed(get_test_id(), get_category(), PackedStringArray([
			"Harness object does not implement TestHarness.",
		]))
	var typed_harness: TestHarness = harness
	typed_harness.load_balance_batches()
	var missing := PackedStringArray()
	for required_id in typed_harness.config.required_balance_batches:
		if not typed_harness.loaded_balance_batches.has(required_id):
			missing.append(required_id)
	if missing.is_empty():
		return TestResult.passed(get_test_id(), get_category(), PackedStringArray([
			"All required balance batch definitions are present.",
		]))
	return TestResult.failed(get_test_id(), get_category(), PackedStringArray([
		"Missing balance batches: %s" % ", ".join(missing),
	]))
