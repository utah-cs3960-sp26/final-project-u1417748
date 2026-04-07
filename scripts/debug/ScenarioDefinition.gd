extends Resource
class_name ScenarioDefinition

@export var scenario_id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var tags: PackedStringArray = PackedStringArray()
@export var seed: int = 3960
@export var setup_data: Dictionary = {}
@export var actions: Array[ScenarioAction] = []
@export var expectations: Array[ScenarioExpectation] = []

func validate() -> PackedStringArray:
	var issues := PackedStringArray()
	if scenario_id.is_empty():
		issues.append("scenario_id is required")
	if title.is_empty():
		issues.append("title is required")
	if actions.is_empty():
		issues.append("at least one action is required")
	if expectations.is_empty():
		issues.append("at least one expectation is required")
	return issues

func summary() -> String:
	return "%s (%d actions, %d expectations, seed=%d)" % [
		title,
		actions.size(),
		expectations.size(),
		seed,
	]
