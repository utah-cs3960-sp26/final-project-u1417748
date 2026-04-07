extends RefCounted
class_name TestCase

func get_test_id() -> String:
	return "unimplemented_test_case"

func get_category() -> String:
	return "uncategorized"

func run_case(_harness: Object) -> TestResult:
	return TestResult.skipped(get_test_id(), get_category(), PackedStringArray([
		"Test case was discovered but not implemented.",
	]))
