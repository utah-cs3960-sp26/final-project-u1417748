class_name DefenseController
extends RefCounted

static func get_guard_target(offense_player: PlayerController, hoop_pos: Vector2, is_on_ball: bool, config: DefenseConfig) -> Vector2:
	var toward_hoop: Vector2 = (hoop_pos - offense_player.global_position).normalized()
	if toward_hoop.length_squared() < 0.001:
		toward_hoop = Vector2.UP
	var distance: float = config.on_ball_guard_distance if is_on_ball else config.base_guard_distance
	return offense_player.global_position - toward_hoop * distance

static func get_contest_info(shooter: PlayerController, defenders: Array[PlayerController], hoop_pos: Vector2, config: DefenseConfig) -> Dictionary:
	var best_index: int = -1
	var best_strength: float = 0.0
	for defender: PlayerController in defenders:
		var distance: float = defender.global_position.distance_to(shooter.global_position)
		if distance > config.contest_radius:
			continue
		var line_factor: float = 1.0 - absf((hoop_pos - shooter.global_position).normalized().dot((defender.global_position - shooter.global_position).normalized())) * 0.45
		var strength: float = clampf(1.0 - distance / config.contest_radius, 0.0, 1.0)
		strength *= remap(defender.get_defense_score(), 0.0, 100.0, 0.7, 1.1) * line_factor
		if strength > best_strength:
			best_strength = strength
			best_index = defender.player_index
	return {"index": best_index, "strength": clampf(best_strength, 0.0, 1.0)}

static func get_block_candidate(shooter: PlayerController, defenders: Array[PlayerController], config: DefenseConfig) -> int:
	for defender: PlayerController in defenders:
		if defender.global_position.distance_to(shooter.global_position) <= config.block_radius and defender.get_block_score() >= 50.0:
			return defender.player_index
	return -1

static func should_force_pressure_turnover(ballhandler: PlayerController, on_ball_defender: PlayerController, stationary_time: float, config: DefenseConfig, difficulty_multiplier: float, rng: RandomNumberGenerator) -> bool:
	if on_ball_defender == null:
		return false
	if on_ball_defender.global_position.distance_to(ballhandler.global_position) > config.pressure_radius:
		return false
	if stationary_time < config.pressure_stationary_seconds:
		return false
	var defense_edge: float = (on_ball_defender.get_steal_score() + on_ball_defender.get_defense_score()) * 0.5 - ballhandler.get_handle_score()
	var chance: float = clampf(0.08 + defense_edge / 220.0, 0.04, 0.32) * difficulty_multiplier
	return rng.randf() <= chance
