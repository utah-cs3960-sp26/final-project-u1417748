class_name DifficultyConfig
extends Resource

@export var easy_defense_multiplier: float = 0.88
@export var normal_defense_multiplier: float = 1.0
@export var hard_defense_multiplier: float = 1.15
@export var easy_sim_efficiency: float = 0.92
@export var normal_sim_efficiency: float = 1.0
@export var hard_sim_efficiency: float = 1.12
@export var easy_rebound_multiplier: float = 0.93
@export var normal_rebound_multiplier: float = 1.0
@export var hard_rebound_multiplier: float = 1.08

func get_profile(difficulty: String) -> Dictionary:
	match difficulty.to_lower():
		"easy":
			return {"defense": easy_defense_multiplier, "sim_efficiency": easy_sim_efficiency, "rebound": easy_rebound_multiplier}
		"hard":
			return {"defense": hard_defense_multiplier, "sim_efficiency": hard_sim_efficiency, "rebound": hard_rebound_multiplier}
		_:
			return {"defense": normal_defense_multiplier, "sim_efficiency": normal_sim_efficiency, "rebound": normal_rebound_multiplier}
