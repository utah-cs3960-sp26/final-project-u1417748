class_name PassController
extends RefCounted

static func get_tapped_teammate(players: Array[PlayerController], world_point: Vector2, controlled_index: int, catch_radius: float) -> int:
	for player: PlayerController in players:
		if player.player_index == controlled_index:
			continue
		if player.global_position.distance_to(world_point) <= catch_radius:
			return player.player_index
	return -1

static func distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var length_squared: float = ab.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(a)
	var t: float = clampf((point - a).dot(ab) / length_squared, 0.0, 1.0)
	return point.distance_to(a + ab * t)

static func find_best_interceptor(start_pos: Vector2, end_pos: Vector2, defenders: Array[PlayerController], pass_config: PassConfig, difficulty_multiplier: float) -> Dictionary:
	var best_score: float = 0.0
	var best_index: int = -1
	var best_point: Vector2 = Vector2.ZERO
	var pass_distance: float = start_pos.distance_to(end_pos)
	for defender: PlayerController in defenders:
		var closest_point: Vector2 = Geometry2D.get_closest_point_to_segment(defender.global_position, start_pos, end_pos)
		var lane_distance: float = defender.global_position.distance_to(closest_point)
		if lane_distance > pass_config.intercept_lane_width:
			continue
		var lane_factor: float = 1.0 - lane_distance / pass_config.intercept_lane_width
		var risk_bonus: float = 0.0
		if pass_distance >= pass_config.risky_crosscourt_distance:
			risk_bonus += 0.22
		elif pass_distance <= pass_config.safe_pass_distance:
			risk_bonus -= 0.08
		var steal_factor: float = remap(defender.get_steal_score(), 0.0, 100.0, 0.1, 0.95)
		var defense_factor: float = remap(defender.get_defense_score(), 0.0, 100.0, 0.2, 1.0)
		var score: float = (lane_factor * 0.55 + steal_factor * 0.25 + defense_factor * 0.20 + risk_bonus) * difficulty_multiplier
		if score > best_score:
			best_score = score
			best_index = defender.player_index
			best_point = closest_point
	if best_index == -1 or best_score < 0.42:
		return {"index": -1, "point": Vector2.ZERO, "score": best_score}
	return {"index": best_index, "point": best_point, "score": best_score}

static func build_pass(start_pos: Vector2, end_pos: Vector2, passer_index: int, receiver_index: int, speed: float, interceptor_index: int = -1, interceptor_point: Vector2 = Vector2.ZERO) -> Dictionary:
	var direction: Vector2 = (end_pos - start_pos).normalized()
	if direction.length_squared() < 0.001:
		direction = Vector2.RIGHT
	return {
		"position": start_pos,
		"start_pos": start_pos,
		"target_pos": end_pos,
		"direction": direction,
		"speed": speed,
		"passer_index": passer_index,
		"receiver_index": receiver_index,
		"interceptor_index": interceptor_index,
		"interceptor_point": interceptor_point,
		"complete": false,
	}

static func advance_pass(pass_state: Dictionary, delta: float, court_rect: Rect2) -> Dictionary:
	pass_state["position"] += pass_state["direction"] * pass_state["speed"] * delta
	if not court_rect.grow(24.0).has_point(pass_state["position"]):
		pass_state["complete"] = true
		return {"type": "out_of_bounds", "position": pass_state["position"]}
	if pass_state["interceptor_index"] >= 0 and pass_state["position"].distance_to(pass_state["interceptor_point"]) <= pass_state["speed"] * delta * 1.2:
		pass_state["complete"] = true
		return {"type": "intercepted", "player_index": pass_state["interceptor_index"], "position": pass_state["interceptor_point"]}
	if pass_state["position"].distance_to(pass_state["target_pos"]) <= pass_state["speed"] * delta * 1.2:
		pass_state["complete"] = true
		return {"type": "caught", "player_index": pass_state["receiver_index"], "position": pass_state["target_pos"]}
	return {"type": "flying"}
