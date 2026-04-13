class_name PlayerData
extends Resource

@export var player_id: String = ""
@export var display_name: String = "Player"
@export var role: String = "PG"
@export var speed: int = 70
@export var acceleration: int = 70
@export var handle: int = 70
@export var pass_accuracy: int = 70
@export var catch_rating: int = 70
@export var shooting: int = 70
@export var release_consistency: int = 70
@export var perimeter_defense: int = 70
@export var steal: int = 70
@export var dunk: int = 70
@export var block: int = 70
@export var rebound: int = 70
@export var sim_offense: int = 70


func get_rating(stat_name: String) -> int:
	match stat_name:
		"speed":
			return speed
		"acceleration":
			return acceleration
		"handle":
			return handle
		"pass_accuracy":
			return pass_accuracy
		"catch":
			return catch_rating
		"shooting":
			return shooting
		"release_consistency":
			return release_consistency
		"perimeter_defense":
			return perimeter_defense
		"steal":
			return steal
		"dunk":
			return dunk
		"block":
			return block
		"rebound":
			return rebound
		"sim_offense":
			return sim_offense
		_:
			return 50
