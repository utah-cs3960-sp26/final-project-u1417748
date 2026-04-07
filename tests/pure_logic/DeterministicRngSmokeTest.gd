extends TestCase

func get_test_id() -> String:
	return "rng_smoke_reproducible_sequence"

func get_category() -> String:
	return "pure_logic"

func run_case(_harness: Object) -> TestResult:
	var first := DeterministicRng.new(123456)
	var second := DeterministicRng.new(123456)
	var samples_a := PackedStringArray()
	var samples_b := PackedStringArray()
	for _i in range(5):
		samples_a.append(str(first.next_float()))
		samples_b.append(str(second.next_float()))
	if samples_a == samples_b:
		return TestResult.passed(get_test_id(), get_category(), PackedStringArray([
			"DeterministicRng produced identical sequences for identical seeds.",
		]))
	return TestResult.failed(get_test_id(), get_category(), PackedStringArray([
		"DeterministicRng produced divergent sequences for identical seeds.",
	]))
