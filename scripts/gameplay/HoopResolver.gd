class_name HoopResolver
extends RefCounted

var court_config: CourtConfig
var ball_config: BallPhysicsConfig


func _init(config_court: CourtConfig = null, config_ball: BallPhysicsConfig = null) -> void:
	court_config = config_court
	ball_config = config_ball


func check_hoop_interaction(ball_sim: BallSimulator) -> Dictionary:
	var result: Dictionary = {
		"hit_type": "none",
		"new_velocity_xy": ball_sim.velocity_xy,
		"new_vz": ball_sim.vz,
		"scored": false,
	}
	if court_config == null or ball_config == null:
		return result

	if ball_sim.forced_make:
		if _check_forced_make_score(ball_sim):
			result.hit_type = "score"
			result.scored = true
		return result

	if _check_backboard(ball_sim):
		result.hit_type = "backboard"
		result.new_velocity_xy = Vector2(
			ball_sim.velocity_xy.x * 0.74 - _bank_assist(ball_sim) * 90.0,
			absf(ball_sim.velocity_xy.y) * 0.78
		)
		result.new_vz = ball_sim.vz * ball_config.backboard_bounce_damping
		return result

	if _check_score(ball_sim):
		result.hit_type = "score"
		result.scored = true
		return result

	if _check_rim(ball_sim):
		var normal: Vector2 = (ball_sim.position_xy - court_config.hoop_position).normalized()
		if normal.length_squared() <= 0.0001:
			normal = Vector2.UP
		var reflected: Vector2 = ball_sim.velocity_xy.bounce(normal) * ball_config.rim_bounce_damping
		result.hit_type = "rim"
		result.new_velocity_xy = reflected
		result.new_vz = absf(ball_sim.vz) * 0.58
		return result

	return result


func _check_backboard(ball_sim: BallSimulator) -> bool:
	var half_width: float = court_config.backboard_width * 0.5 + ball_config.ball_radius
	var current_crossing: bool = ball_sim.previous_position_xy.y >= court_config.backboard_y and ball_sim.position_xy.y <= court_config.backboard_y
	if not current_crossing:
		return false
	if absf(ball_sim.position_xy.x - court_config.backboard_x_center) > half_width:
		return false
	return ball_sim.z >= court_config.rim_height - 40.0 and ball_sim.z <= court_config.rim_height + 180.0


func _check_rim(ball_sim: BallSimulator) -> bool:
	var current_distance: float = ball_sim.position_xy.distance_to(court_config.hoop_position)
	var previous_distance: float = ball_sim.previous_position_xy.distance_to(court_config.hoop_position)
	var outer_radius: float = court_config.rim_radius + ball_config.ball_radius
	var near_height: bool = absf(ball_sim.z - court_config.rim_height) <= 48.0
	return near_height and current_distance <= outer_radius and previous_distance >= current_distance and current_distance >= court_config.rim_inner_radius


func _check_score(ball_sim: BallSimulator) -> bool:
	if ball_sim.already_scored or ball_sim.vz >= 0.0:
		return false
	var crossed_plane: bool = ball_sim.previous_z >= court_config.rim_height and ball_sim.z <= court_config.rim_height
	if not crossed_plane:
		return false
	var denominator: float = ball_sim.previous_z - ball_sim.z
	var t: float = 0.0
	if not is_zero_approx(denominator):
		t = clampf((ball_sim.previous_z - court_config.rim_height) / denominator, 0.0, 1.0)
	var sample_pos: Vector2 = ball_sim.previous_position_xy.lerp(ball_sim.position_xy, t)
	return sample_pos.distance_to(court_config.hoop_position) <= court_config.rim_inner_radius


func _check_forced_make_score(ball_sim: BallSimulator) -> bool:
	if ball_sim.already_scored or ball_sim.vz >= 0.0:
		return false
	var crossed_plane: bool = ball_sim.previous_z >= court_config.rim_height and ball_sim.z <= court_config.rim_height
	if not crossed_plane:
		return false
	var denominator: float = ball_sim.previous_z - ball_sim.z
	var t: float = 0.0
	if not is_zero_approx(denominator):
		t = clampf((ball_sim.previous_z - court_config.rim_height) / denominator, 0.0, 1.0)
	var sample_pos: Vector2 = ball_sim.previous_position_xy.lerp(ball_sim.position_xy, t)
	return sample_pos.distance_to(court_config.hoop_position) <= court_config.rim_radius


func estimate_landing_position(ball_sim: BallSimulator) -> Vector2:
	var probe: BallSimulator = ball_sim.clone_state()
	for _index in 360:
		probe.step(1.0 / 60.0)
		if not probe.is_in_flight:
			break
	return probe.position_xy


func _bank_assist(ball_sim: BallSimulator) -> float:
	var offset_ratio: float = clampf((ball_sim.position_xy.x - court_config.backboard_x_center) / maxf(court_config.backboard_width * 0.5, 1.0), -1.0, 1.0)
	return offset_ratio * ball_config.bank_assist
