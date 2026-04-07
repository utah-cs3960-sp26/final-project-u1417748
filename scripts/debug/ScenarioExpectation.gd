extends Resource
class_name ScenarioExpectation

enum Comparison {
	EQUAL,
	NOT_EQUAL,
	GREATER_EQUAL,
	LESS_EQUAL,
	CONTAINS,
	EXISTS,
	BOOLEAN_TRUE,
	BOOLEAN_FALSE,
}

@export var kind: String = "state"
@export var subject: String = ""
@export var comparison: Comparison = Comparison.EXISTS
@export var expected_value: Variant
@export_range(0.0, 100.0, 0.001) var tolerance: float = 0.0

func describe() -> String:
	return "%s %s %s" % [kind, subject, Comparison.keys()[comparison]]
