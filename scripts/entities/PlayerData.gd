class_name PlayerData
extends Resource

@export var player_id: String = ""
@export var display_name: String = ""
@export var role: String = ""
@export var speed: int = 65
@export var acceleration: int = 65
@export var handle: int = 65
@export var pass_accuracy: int = 65
@export var catch_rating: int = 65
@export var shooting: int = 65
@export var release_consistency: int = 65
@export var perimeter_defense: int = 65
@export var steal: int = 65
@export var block: int = 45
@export var rebound: int = 60
@export var sim_offense: int = 65

func get_rating_map() -> Dictionary:
	return {
		"speed": speed,
		"acceleration": acceleration,
		"handle": handle,
		"pass_accuracy": pass_accuracy,
		"catch": catch_rating,
		"shooting": shooting,
		"release_consistency": release_consistency,
		"perimeter_defense": perimeter_defense,
		"steal": steal,
		"block": block,
		"rebound": rebound,
		"sim_offense": sim_offense,
	}
