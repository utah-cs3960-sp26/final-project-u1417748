class_name ReboundController
extends RefCounted

static func estimate_landing_zone(ball_state: Dictionary) -> Vector2:
	return ball_state.get("position_xy", Vector2.ZERO)

static func choose_winner(offense_players: Array[PlayerController], defense_players: Array[PlayerController], target_point: Vector2, config: ReboundConfig, difficulty_profile: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var best_side: String = "offense"
	var best_index: int = 0
	var best_score: float = -INF
	var rebound_multiplier: float = float(difficulty_profile.get("rebound", 1.0))
	for player: PlayerController in offense_players:
		var distance_score: float = -player.global_position.distance_to(target_point) * config.distance_weight
		var rating_score: float = player.get_rebound_score() * config.rating_weight + config.offense_bias
		var total: float = distance_score + rating_score + rng.randf_range(-12.0, 12.0)
		if total > best_score:
			best_score = total
			best_side = "offense"
			best_index = player.player_index
	for player: PlayerController in defense_players:
		var distance_score: float = -player.global_position.distance_to(target_point) * config.distance_weight
		var rating_score: float = player.get_rebound_score() * config.rating_weight * rebound_multiplier
		var total: float = distance_score + rating_score + rng.randf_range(-12.0, 12.0)
		if total > best_score:
			best_score = total
			best_side = "defense"
			best_index = player.player_index
	return {
		"side": best_side,
		"index": best_index,
		"score": best_score,
		"target": target_point,
	}
