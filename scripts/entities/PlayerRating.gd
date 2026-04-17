class_name PlayerRating
extends RefCounted

const ROLE_WEIGHTS: Dictionary = {
	"PG": {
		"handle": 0.22,
		"pass_accuracy": 0.20,
		"speed": 0.14,
		"acceleration": 0.10,
		"shooting": 0.12,
		"steal": 0.08,
		"perimeter_defense": 0.08,
		"catch": 0.06,
	},
	"LW": {
		"shooting": 0.20,
		"speed": 0.16,
		"acceleration": 0.12,
		"catch": 0.12,
		"release_consistency": 0.12,
		"handle": 0.10,
		"perimeter_defense": 0.10,
		"dunk": 0.08,
	},
	"RW": {
		"shooting": 0.22,
		"release_consistency": 0.16,
		"catch": 0.14,
		"perimeter_defense": 0.12,
		"speed": 0.10,
		"handle": 0.08,
		"steal": 0.08,
		"pass_accuracy": 0.10,
	},
	"LC": {
		"dunk": 0.22,
		"rebound": 0.20,
		"block": 0.16,
		"catch": 0.12,
		"perimeter_defense": 0.10,
		"acceleration": 0.08,
		"shooting": 0.06,
		"handle": 0.06,
	},
	"RC": {
		"shooting": 0.22,
		"release_consistency": 0.20,
		"catch": 0.16,
		"rebound": 0.12,
		"perimeter_defense": 0.10,
		"dunk": 0.08,
		"block": 0.06,
		"pass_accuracy": 0.06,
	},
}


static func compute(player_data: PlayerData) -> int:
	if player_data == null:
		return 50
	var weights: Dictionary = ROLE_WEIGHTS.get(player_data.role, ROLE_WEIGHTS["PG"])
	var weighted_sum: float = 0.0
	var total_weight: float = 0.0
	for stat_name in weights:
		weighted_sum += float(player_data.get_rating(stat_name)) * float(weights[stat_name])
		total_weight += float(weights[stat_name])
	var mean: float = weighted_sum / maxf(total_weight, 0.0001)
	return clampi(roundi(mean), 40, 99)
