class_name ScenarioDefinition
extends Resource

@export var scenario_id: String = ""
@export var display_name: String = ""
@export var seed: int = 0
@export var initial_time_remaining: float = 180.0
@export var initial_home_score: int = 0
@export var initial_away_score: int = 0
@export var setup: Dictionary = {}
@export var actions: Array[ScenarioAction] = []
@export var expectations: Array[ScenarioExpectation] = []
@export var tags: PackedStringArray = []
