extends Resource
class_name BalanceBatchDefinition

@export var batch_id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var seed: int = 3960
@export_range(1, 10000, 1) var iterations: int = 100
@export var scenario_id: String = ""
@export var metrics: PackedStringArray = PackedStringArray()
@export var thresholds: Dictionary = {}

func validate() -> PackedStringArray:
	var issues := PackedStringArray()
	if batch_id.is_empty():
		issues.append("batch_id is required")
	if title.is_empty():
		issues.append("title is required")
	if scenario_id.is_empty():
		issues.append("scenario_id is required")
	if metrics.is_empty():
		issues.append("at least one metric is required")
	return issues
