class_name DifficultyConfig
extends Resource

enum Level {
	EASY,
	NORMAL,
	HARD,
}

@export var level: Level = Level.NORMAL
@export var easy_defense_multiplier: float = 0.88
@export var normal_defense_multiplier: float = 1.0
@export var hard_defense_multiplier: float = 1.12
@export var easy_sim_efficiency: float = 0.92
@export var normal_sim_efficiency: float = 1.0
@export var hard_sim_efficiency: float = 1.12


func get_defense_multiplier() -> float:
	match level:
		Level.EASY:
			return easy_defense_multiplier
		Level.HARD:
			return hard_defense_multiplier
		_:
			return normal_defense_multiplier


func get_sim_efficiency() -> float:
	match level:
		Level.EASY:
			return easy_sim_efficiency
		Level.HARD:
			return hard_sim_efficiency
		_:
			return normal_sim_efficiency


static func level_name(value: int) -> String:
	match value:
		Level.EASY:
			return "easy"
		Level.HARD:
			return "hard"
		_:
			return "normal"
