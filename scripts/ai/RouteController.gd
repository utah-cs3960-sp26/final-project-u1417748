class_name RouteController
extends RefCounted

var route_config: RouteConfig
var court_config: CourtConfig
var spacing_solver: SpacingSolver = SpacingSolver.new()
var _last_side_sign: float = 1.0
var _side_sign_initialized: bool = false


func reset_runtime_state() -> void:
	_last_side_sign = 1.0
	_side_sign_initialized = false


func get_route_targets(
	offense_players: Array[PlayerController],
	ballhandler: PlayerController,
	package_index: int,
	phase_time: float
) -> Dictionary:
	var anchors: Dictionary = court_config.get_anchor_map()
	var phase: float = fmod(phase_time, route_config.package_duration) / maxf(route_config.package_duration, 0.01)
	var targets: Dictionary = {}
	var ballhandler_position: Vector2 = anchors.get("PG", court_config.hoop_position + Vector2(0.0, 320.0))
	if ballhandler != null:
		ballhandler_position = ballhandler.world_position
	var side_sign: float = _resolve_side_sign(ballhandler_position)

	for player in offense_players:
		if player == ballhandler:
			continue
		match package_index:
			0:
				targets[player] = _wing_swap_target(player.get_position_role(), anchors, phase)
			1:
				targets[player] = _strong_side_slash_target(player.get_position_role(), anchors, phase, side_sign)
			_:
				targets[player] = _weak_side_fill_target(player.get_position_role(), anchors, phase, side_sign)

	return spacing_solver.apply_spacing(
		targets,
		offense_players,
		ballhandler,
		route_config.spacing_repulsion_radius,
		route_config.spacing_slide_strength
	)


func _wing_swap_target(role: String, anchors: Dictionary, phase: float) -> Vector2:
	var midpoint: Vector2 = court_config.normalized_to_court(Vector2(0.5, 0.42))
	match role:
		"LW":
			return _ping_pong(anchors["LW"], midpoint, anchors["RW"], phase)
		"RW":
			return _ping_pong(anchors["RW"], midpoint, anchors["LW"], phase)
		"LC":
			return anchors["LC"] + Vector2(18.0, route_config.corner_lift_distance * sin(phase * TAU))
		"RC":
			return anchors["RC"] + Vector2(-18.0, route_config.corner_lift_distance * cos(phase * TAU))
		_:
			return anchors.get(role, anchors["PG"])


func _strong_side_slash_target(role: String, anchors: Dictionary, phase: float, side_sign: float) -> Vector2:
	var middle_high: Vector2 = court_config.normalized_to_court(Vector2(0.5, 0.4))
	var left_is_strong: bool = side_sign < 0.0
	match role:
		"LW":
			if left_is_strong:
				return _ping_pong(anchors["LW"], middle_high, anchors["RW"], phase)
			return _ping_pong(anchors["LW"], anchors["LW"] + Vector2(-16.0, -route_config.slot_drift_distance), anchors["LW"], phase)
		"RW":
			if not left_is_strong:
				return _ping_pong(anchors["RW"], middle_high, anchors["LW"], phase)
			return _ping_pong(anchors["RW"], anchors["RW"] + Vector2(16.0, -route_config.slot_drift_distance), anchors["RW"], phase)
		"LC":
			return anchors["LC"] + Vector2(0.0, route_config.corner_lift_distance if left_is_strong else 8.0)
		"RC":
			return anchors["RC"] + Vector2(0.0, route_config.corner_lift_distance if not left_is_strong else 8.0)
		_:
			return anchors.get(role, anchors["PG"])


func _weak_side_fill_target(role: String, anchors: Dictionary, phase: float, side_sign: float) -> Vector2:
	var lane_point: Vector2 = court_config.normalized_to_court(Vector2(0.5, 0.48))
	var left_is_weak: bool = side_sign > 0.0
	match role:
		"LW":
			if left_is_weak:
				return _ping_pong(anchors["LW"], lane_point, anchors["RC"], phase)
			return anchors["LW"] + Vector2(0.0, -route_config.slot_drift_distance)
		"RW":
			if not left_is_weak:
				return _ping_pong(anchors["RW"], lane_point, anchors["LC"], phase)
			return anchors["RW"] + Vector2(0.0, -route_config.slot_drift_distance)
		"LC":
			if left_is_weak:
				return _ping_pong(anchors["LC"], anchors["LW"], anchors["LW"], phase)
			return anchors["LC"] + Vector2(16.0, 8.0)
		"RC":
			if not left_is_weak:
				return _ping_pong(anchors["RC"], anchors["RW"], anchors["RW"], phase)
			return anchors["RC"] + Vector2(-16.0, 8.0)
		_:
			return anchors.get(role, anchors["PG"])


func _ping_pong(start_value: Vector2, middle_value: Vector2, end_value: Vector2, phase: float) -> Vector2:
	if phase < 0.5:
		return start_value.lerp(middle_value, phase / 0.5)
	return middle_value.lerp(end_value, (phase - 0.5) / 0.5)


func _resolve_side_sign(ballhandler_position: Vector2) -> float:
	var center_x: float = court_config.hoop_position.x
	var switch_deadband: float = maxf(route_config.side_switch_deadband, 0.0)
	if not _side_sign_initialized:
		_last_side_sign = -1.0 if ballhandler_position.x < center_x else 1.0
		_side_sign_initialized = true
		return _last_side_sign
	if _last_side_sign < 0.0 and ballhandler_position.x > center_x + switch_deadband:
		_last_side_sign = 1.0
	elif _last_side_sign > 0.0 and ballhandler_position.x < center_x - switch_deadband:
		_last_side_sign = -1.0
	return _last_side_sign
