class_name PassController
extends RefCounted

var pass_config: PassConfig
var court_config: CourtConfig
var difficulty_config: DifficultyConfig
var active_pass: Dictionary = {}


func start_pass(
	from_position: Vector2,
	target_player: PlayerController,
	defenders: Array[PlayerController],
	rng: GameRng = null,
	passer: PlayerController = null
) -> Dictionary:
	var evaluation: Dictionary = evaluate_pass_target(from_position, target_player, defenders, passer)
	var target_position: Vector2 = evaluation.get("target_position", target_player.world_position if target_player != null else from_position)
	var distance_value: float = float(evaluation.get("distance", from_position.distance_to(target_position)))
	var eligible_interceptor: Dictionary = evaluation.get("eligible_interceptor_data", {})
	var eligible_player: PlayerController = evaluation.get("eligible_interceptor", null) as PlayerController
	var commit_chance: float = float(evaluation.get("commit_chance", 0.0))
	var commit_succeeded: bool = eligible_player != null and _roll_commit(commit_chance, rng)
	var active_interceptor: PlayerController = eligible_player if commit_succeeded else null
	var chase_point: Vector2 = evaluation.get("eligible_chase_point", target_position)
	active_pass = {
		"start": from_position,
		"end": target_position,
		"intended_receiver": target_player,
		"current_position": from_position,
		"progress": 0.0,
		"distance": distance_value,
		"elapsed": 0.0,
		"duration": maxf(distance_value / maxf(pass_config.pass_speed, 1.0), 0.01),
		"eligible_interceptor": eligible_player,
		"eligible_chase_point": chase_point,
		"active_interceptor": active_interceptor,
		"chase_point": chase_point if commit_succeeded else target_position,
		"receiver_claim_radius": get_offense_claim_radius(target_player),
		"interceptor_claim_radius": get_defense_claim_radius(active_interceptor),
		"commit_chance": commit_chance,
		"commit_succeeded": commit_succeeded,
		"resolved_outcome": "",
		"resolved_position": from_position,
		"force_steal": false,
	}
	return get_active_pass_snapshot()


func evaluate_pass_target(
	from_position: Vector2,
	target_player: PlayerController,
	defenders: Array[PlayerController],
	passer: PlayerController = null
) -> Dictionary:
	if target_player == null:
		return {}
	var target_position: Vector2 = target_player.world_position
	var distance_value: float = from_position.distance_to(target_position)
	var eligible_interceptor: Dictionary = _find_interceptor(from_position, target_position, defenders)
	var eligible_player: PlayerController = eligible_interceptor.get("player", null) as PlayerController
	var chase_point: Vector2 = eligible_interceptor.get("closest_point", target_position)
	var commit_chance: float = _calculate_commit_chance(from_position, target_position, eligible_interceptor, target_player, passer)
	return {
		"target_player": target_player,
		"target_position": target_position,
		"distance": distance_value,
		"eligible_interceptor": eligible_player,
		"eligible_interceptor_data": eligible_interceptor.duplicate(true),
		"eligible_chase_point": chase_point,
		"commit_chance": commit_chance,
		"target_y": target_position.y,
	}


func step_pass(delta: float) -> Dictionary:
	if active_pass.is_empty():
		return {"state": "idle"}
	active_pass.elapsed += delta
	var progress: float = clampf(active_pass.elapsed / maxf(active_pass.duration, 0.01), 0.0, 1.0)
	var world_position: Vector2 = active_pass.start.lerp(active_pass.end, progress)
	active_pass.progress = progress
	active_pass.current_position = world_position
	_refresh_chase_point()
	if not court_config.is_in_bounds(world_position):
		active_pass.resolved_outcome = "out_of_bounds"
		active_pass.resolved_position = world_position
		var out_result: Dictionary = _build_result("out_of_bounds")
		active_pass = {}
		return out_result
	var receiver: PlayerController = active_pass.intended_receiver
	var interceptor: PlayerController = active_pass.active_interceptor
	var receiver_can_claim: bool = receiver != null and world_position.distance_to(receiver.world_position) <= get_offense_claim_radius(receiver)
	var interceptor_can_claim: bool = interceptor != null and world_position.distance_to(interceptor.world_position) <= _get_active_interceptor_claim_radius()
	if bool(active_pass.get("force_steal", false)):
		receiver_can_claim = false
	if receiver_can_claim:
		active_pass.resolved_outcome = "offense"
		active_pass.resolved_position = world_position
		var offense_result: Dictionary = _build_result("complete_offense")
		active_pass = {}
		return offense_result
	if interceptor_can_claim:
		active_pass.resolved_outcome = "steal"
		active_pass.resolved_position = world_position
		var steal_result: Dictionary = _build_result("complete_steal")
		active_pass = {}
		return steal_result
	return _build_result("traveling")


func get_intercept_corridor() -> PackedVector2Array:
	if active_pass.is_empty():
		return PackedVector2Array()
	return PackedVector2Array([active_pass.start, active_pass.end])


func has_active_pass() -> bool:
	return not active_pass.is_empty()


func get_active_pass_snapshot() -> Dictionary:
	if active_pass.is_empty():
		return {}
	return {
		"start": active_pass.start,
		"end": active_pass.end,
		"current_position": active_pass.current_position,
		"progress": active_pass.progress,
		"distance": active_pass.distance,
		"elapsed": active_pass.elapsed,
		"duration": active_pass.duration,
		"intended_receiver": active_pass.intended_receiver,
		"eligible_interceptor": active_pass.eligible_interceptor,
		"eligible_chase_point": active_pass.eligible_chase_point,
		"active_interceptor": active_pass.active_interceptor,
		"chase_point": active_pass.chase_point,
		"receiver_claim_radius": active_pass.receiver_claim_radius,
		"interceptor_claim_radius": active_pass.interceptor_claim_radius,
		"commit_chance": active_pass.commit_chance,
		"commit_succeeded": active_pass.commit_succeeded,
		"resolved_outcome": active_pass.resolved_outcome,
		"resolved_position": active_pass.resolved_position,
		"force_steal": active_pass.force_steal,
	}


func get_offense_claim_radius(player: PlayerController) -> float:
	if player == null:
		return pass_config.catch_radius
	var player_data: PlayerData = player.get_player_data()
	if player_data == null:
		return pass_config.catch_radius
	var multiplier: float = _rating_to_multiplier(
		player_data.catch_rating,
		pass_config.offense_catch_radius_multiplier_min,
		pass_config.offense_catch_radius_multiplier_max
	)
	return pass_config.catch_radius * multiplier


func get_defense_claim_radius(player: PlayerController) -> float:
	if player == null:
		return 0.0
	var player_data: PlayerData = player.get_player_data()
	if player_data == null:
		return 0.0
	var defense_rating: float = (float(player_data.steal) + float(player_data.perimeter_defense)) * 0.5
	var multiplier: float = _rating_to_multiplier(
		int(round(defense_rating)),
		pass_config.defense_intercept_radius_multiplier_min,
		pass_config.defense_intercept_radius_multiplier_max
	)
	return pass_config.catch_radius * multiplier


func force_interception(defenders: Array[PlayerController] = []) -> Dictionary:
	if active_pass.is_empty():
		return {}
	var interceptor: PlayerController = active_pass.get("active_interceptor", null) as PlayerController
	if interceptor == null:
		interceptor = active_pass.get("eligible_interceptor", null) as PlayerController
	if interceptor == null and not defenders.is_empty():
		var forced_candidate: Dictionary = _find_interceptor(
			active_pass.get("current_position", active_pass.start),
			active_pass.end,
			defenders
		)
		interceptor = forced_candidate.get("player", null) as PlayerController
		if interceptor != null:
			active_pass.eligible_interceptor = interceptor
			active_pass.eligible_chase_point = forced_candidate.get("closest_point", active_pass.end)
	if interceptor == null:
		return {}
	active_pass.eligible_interceptor = interceptor
	active_pass.active_interceptor = interceptor
	active_pass.chase_point = active_pass.get("eligible_chase_point", active_pass.end)
	active_pass.interceptor_claim_radius = maxf(get_defense_claim_radius(interceptor) * 1.8, get_defense_claim_radius(interceptor))
	active_pass.commit_chance = 1.0
	active_pass.commit_succeeded = true
	active_pass.force_steal = true
	_refresh_chase_point()
	return get_active_pass_snapshot()


func _find_interceptor(
	start_position: Vector2,
	target_position: Vector2,
	defenders: Array[PlayerController]
) -> Dictionary:
	var best_candidate: Dictionary = {}
	var best_eta: float = INF
	for defender in defenders:
		var closest_point: Vector2 = Geometry2D.get_closest_point_to_segment(defender.world_position, start_position, target_position)
		var lane_distance: float = closest_point.distance_to(defender.world_position)
		var claim_radius: float = get_defense_claim_radius(defender)
		if lane_distance > claim_radius * 1.3:
			continue
		var eta: float = _estimate_eta(defender, closest_point, claim_radius)
		if eta < best_eta:
			best_eta = eta
			best_candidate = {
				"player": defender,
				"closest_point": closest_point,
				"eta": eta,
				"lane_distance": lane_distance,
				"claim_radius": claim_radius,
				"lane_limit": claim_radius * 1.3,
			}
	return best_candidate


func _refresh_chase_point() -> void:
	if active_pass.is_empty():
		return
	var interceptor: PlayerController = active_pass.get("active_interceptor", null) as PlayerController
	if interceptor == null:
		active_pass.chase_point = active_pass.end
		return
	var lane_start: Vector2 = active_pass.get("current_position", active_pass.start)
	var lane_end: Vector2 = active_pass.end
	if lane_start.distance_to(lane_end) <= 0.01:
		active_pass.chase_point = lane_end
		return
	active_pass.chase_point = Geometry2D.get_closest_point_to_segment(interceptor.world_position, lane_start, lane_end)


func _build_result(state_name: String) -> Dictionary:
	return {
		"state": state_name,
		"position": active_pass.get("current_position", active_pass.get("resolved_position", Vector2.ZERO)),
		"target_point": active_pass.get("end", Vector2.ZERO),
		"intended_receiver": active_pass.get("intended_receiver", null),
		"eligible_interceptor": active_pass.get("eligible_interceptor", null),
		"active_interceptor": active_pass.get("active_interceptor", null),
		"chase_point": active_pass.get("chase_point", active_pass.get("end", Vector2.ZERO)),
		"progress": active_pass.get("progress", 0.0),
		"commit_chance": active_pass.get("commit_chance", 0.0),
		"commit_succeeded": active_pass.get("commit_succeeded", false),
		"resolved_position": active_pass.get("resolved_position", active_pass.get("current_position", Vector2.ZERO)),
	}


func _get_active_interceptor_claim_radius() -> float:
	var interceptor: PlayerController = active_pass.get("active_interceptor", null) as PlayerController
	if interceptor == null:
		return 0.0
	var boosted_radius: float = float(active_pass.get("interceptor_claim_radius", 0.0))
	return maxf(boosted_radius, get_defense_claim_radius(interceptor))


func _estimate_eta(player: PlayerController, target_position: Vector2, claim_radius: float) -> float:
	if player == null:
		return INF
	var player_data: PlayerData = player.get_player_data()
	if player_data == null:
		return INF
	var run_speed: float = (180.0 + float(player_data.speed) * 2.2)
	if run_speed <= 0.0:
		return INF
	var remaining_distance: float = maxf(player.world_position.distance_to(target_position) - claim_radius, 0.0)
	return remaining_distance / run_speed


func _calculate_commit_chance(
	start_position: Vector2,
	target_position: Vector2,
	interceptor_candidate: Dictionary,
	target_player: PlayerController,
	passer: PlayerController
) -> float:
	if interceptor_candidate.is_empty():
		return 0.0
	var chance: float = pass_config.base_interception_chance
	var travel_vector: Vector2 = target_position - start_position
	if travel_vector.length() >= pass_config.long_pass_threshold:
		chance += pass_config.long_pass_bonus
	if absf(travel_vector.x) >= pass_config.cross_court_x_delta:
		chance += pass_config.cross_court_bonus
	var lane_limit: float = float(interceptor_candidate.get("lane_limit", 0.0))
	var lane_distance: float = float(interceptor_candidate.get("lane_distance", lane_limit))
	var lane_factor: float = 1.0 - clampf(lane_distance / maxf(lane_limit, 0.001), 0.0, 1.0)
	chance += pass_config.lane_bonus * lane_factor
	var interceptor: PlayerController = interceptor_candidate.get("player", null) as PlayerController
	chance += _get_defender_pressure(interceptor) * pass_config.defender_pressure_scale
	chance -= _get_pass_accuracy_resistance(passer) * pass_config.pass_accuracy_resistance_scale
	chance -= _get_catch_security(target_player) * pass_config.catch_security_scale
	chance *= _get_defense_multiplier()
	return clampf(chance, pass_config.commit_chance_min, pass_config.commit_chance_max)


func _roll_commit(commit_chance: float, rng: GameRng) -> bool:
	if commit_chance <= 0.0:
		return false
	if rng != null:
		return rng.randf() < commit_chance
	var fallback_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	fallback_rng.randomize()
	return fallback_rng.randf() < commit_chance


func _get_defender_pressure(player: PlayerController) -> float:
	if player == null:
		return 0.0
	var player_data: PlayerData = player.get_player_data()
	if player_data == null:
		return 0.0
	return clampf((float(player_data.steal) + float(player_data.perimeter_defense)) * 0.5 / 100.0, 0.0, 1.0)


func _get_pass_accuracy_resistance(player: PlayerController) -> float:
	if player == null:
		return 0.7
	var player_data: PlayerData = player.get_player_data()
	if player_data == null:
		return 0.7
	return clampf(float(player_data.pass_accuracy) / 100.0, 0.0, 1.0)


func _get_catch_security(player: PlayerController) -> float:
	if player == null:
		return 0.7
	var player_data: PlayerData = player.get_player_data()
	if player_data == null:
		return 0.7
	return clampf(float(player_data.catch_rating) / 100.0, 0.0, 1.0)


func _get_defense_multiplier() -> float:
	if difficulty_config == null:
		return 1.0
	return difficulty_config.get_defense_multiplier()


func _rating_to_multiplier(rating: int, min_value: float, max_value: float) -> float:
	return lerpf(min_value, max_value, clampf(float(rating) / 100.0, 0.0, 1.0))
