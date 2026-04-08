class_name BalanceBatchDefinition
extends Resource

@export var batch_id: String = ""
@export var display_name: String = ""
@export var seed: int = 0
@export var trial_count: int = 100
@export var metric_keys: PackedStringArray = []
@export var limits: Dictionary = {}
@export var tags: PackedStringArray = []
