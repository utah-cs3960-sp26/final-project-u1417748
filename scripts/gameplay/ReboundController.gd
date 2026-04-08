class_name ReboundController
extends RefCounted

var rebound_config: ReboundConfig


func get_rebound_candidates(
	landing_zone: Vector2,
	offense_players: Array[PlayerController],
	defense_players: Array[PlayerController]
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	_collect_team_candidates(candidates, landing_zone, offense_players, true, rebound_config.offensive_rebound_disadvantage)
	_collect_team_candidates(candidates, landing_zone, defense_players, false, 1.0)
	if not _has_team(candidates, true):
		var offense_fallback: Dictionary = _fallback_candidate(landing_zone, offense_players, true, rebound_config.offensive_rebound_disadvantage)
		if not offense_fallback.is_empty():
			candidates.append(offense_fallback)
	if not _has_team(candidates, false):
		var defense_fallback: Dictionary = _fallback_candidate(landing_zone, defense_players, false, 1.0)
		if not defense_fallback.is_empty():
			candidates.append(defense_fallback)
	return candidates


func pick_winner(candidates: Array[Dictionary], rng: GameRng) -> Dictionary:
	var weights: Array[float] = []
	for candidate in candidates:
		weights.append(candidate.weight)
	var index: int = rng.rand_weighted(weights)
	return candidates[index]


func _collect_team_candidates(
	candidates: Array[Dictionary],
	landing_zone: Vector2,
	players: Array[PlayerController],
	is_offense: bool,
	multiplier: float
) -> void:
	for player in players:
		var distance_value: float = player.world_position.distance_to(landing_zone)
		if distance_value > rebound_config.rebound_zone_radius:
			continue
		var rating: float = float(player.get_player_data().rebound) / 100.0
		var momentum_bonus: float = 1.0 + rebound_config.momentum_bonus if is_offense else 1.0
		var weight: float = maxf((1.0 - distance_value / rebound_config.rebound_zone_radius) * rating * multiplier * momentum_bonus, 0.01)
		candidates.append({"player": player, "weight": weight, "is_offense": is_offense})


func _fallback_candidate(
	landing_zone: Vector2,
	players: Array[PlayerController],
	is_offense: bool,
	multiplier: float
) -> Dictionary:
	var best_player: PlayerController = null
	var best_distance: float = INF
	for player in players:
		var distance_value: float = player.world_position.distance_to(landing_zone)
		if distance_value < best_distance:
			best_distance = distance_value
			best_player = player
	if best_player == null:
		return {}
	var fallback_strength: float = 0.3 if is_offense else 0.16
	var momentum_bonus: float = 1.0 + rebound_config.momentum_bonus if is_offense else 1.0
	var weight: float = maxf((float(best_player.get_player_data().rebound) / 100.0) * multiplier * fallback_strength * momentum_bonus, 0.01)
	return {"player": best_player, "weight": weight, "is_offense": is_offense, "fallback": true}


func _has_team(candidates: Array[Dictionary], is_offense: bool) -> bool:
	for candidate in candidates:
		if candidate.is_offense == is_offense:
			return true
	return false
