class_name ShotController
extends RefCounted

var shot_config: ShotTimingConfig
var ball_config: BallPhysicsConfig
var court_config: CourtConfig
var projection: CourtProjection

var is_aiming: bool = false
var aim_elapsed: float = 0.0
var aim_start_world: Vector2 = Vector2.ZERO
var current_drag_vector: Vector2 = Vector2.ZERO


func begin_aim(world_position: Vector2) -> void:
	is_aiming = true
	aim_elapsed = 0.0
	aim_start_world = world_position
	current_drag_vector = Vector2.ZERO


func update_aim(delta: float, drag_vector: Vector2) -> void:
	if not is_aiming:
		return
	aim_elapsed += delta
	current_drag_vector = drag_vector


func cancel_aim() -> void:
	is_aiming = false
	aim_elapsed = 0.0
	current_drag_vector = Vector2.ZERO


func get_current_quality(contested: bool, release_consistency: int) -> String:
	return classify_meter_progress(get_meter_progress(), contested, release_consistency)


func get_timing_window(_contested: bool, _release_consistency: int) -> float:
	return clampf(shot_config.green_window_ratio, 0.08, 0.3)


func release_action(
	ballhandler_position: Vector2,
	shooter: PlayerData,
	contested: bool,
	rng: GameRng
) -> Dictionary:
	if not is_aiming or aim_elapsed <= 0.0:
		cancel_aim()
		return {"kind": "cancel"}
	var quality: String = get_current_quality(contested, shooter.release_consistency)
	var params: Dictionary = build_make_launch_params(ballhandler_position)
	var outcome: String = "make"
	if quality != "green":
		params = build_miss_launch_params(ballhandler_position, rng)
		outcome = "miss"
	cancel_aim()
	return {
		"kind": "shot",
		"outcome": outcome,
		"quality": quality,
		"direction": params["direction"],
		"power": params.get("power", 1.0),
		"forward_power": params.get("forward_power", 1.0),
		"arc_power": params.get("arc_power", 1.0),
		"launch_speed": params["launch_speed"],
		"z_speed": params["z_speed"],
		"preview_origin": params["preview_origin"],
		"flight_time": params.get("flight_time", 0.0),
		"shot_value": 3 if court_config.is_three_point(ballhandler_position) else 2,
	}


func get_meter_progress() -> float:
	if shot_config == null or shot_config.meter_cycle_duration <= 0.0:
		return 0.0
	var cycle_position: float = fposmod(aim_elapsed / shot_config.meter_cycle_duration, 2.0)
	if cycle_position > 1.0:
		cycle_position = 2.0 - cycle_position
	return clampf(cycle_position, 0.0, 1.0)


func get_green_window(_contested: bool, _release_consistency: int) -> Vector2:
	var width: float = get_timing_window(false, 0)
	var start: float = clampf(shot_config.meter_green_center - width * 0.5, 0.0, 1.0)
	var end: float = clampf(start + width, 0.0, 1.0)
	return Vector2(start, end)


func classify_meter_progress(progress: float, contested: bool, release_consistency: int) -> String:
	var green_window: Vector2 = get_green_window(contested, release_consistency)
	if progress >= green_window.x and progress <= green_window.y:
		return "green"
	return "red"


func get_meter_snapshot(contested: bool, release_consistency: int) -> Dictionary:
	var progress: float = get_meter_progress()
	var green_window: Vector2 = get_green_window(contested, release_consistency)
	return {
		"visible": is_aiming,
		"progress": progress,
		"green_start": green_window.x,
		"green_end": green_window.y,
		"quality": classify_meter_progress(progress, contested, release_consistency),
		"width": shot_config.meter_width,
		"height": shot_config.meter_height,
		"bottom_margin": shot_config.meter_bottom_margin,
		"marker_width": shot_config.meter_marker_width,
	}


func build_make_launch_params(launch_origin: Vector2) -> Dictionary:
	var shot_origin: Vector2 = _get_shot_origin(launch_origin, court_config.hoop_position)
	var distance_ratio: float = clampf(shot_origin.distance_to(court_config.hoop_position) / maxf(court_config.three_point_radius, 1.0), 0.0, 1.0)
	var flight_time: float = lerpf(ball_config.made_shot_flight_time_near, ball_config.made_shot_flight_time_far, distance_ratio)
	return _build_launch_to_target(shot_origin, court_config.hoop_position, court_config.rim_height, flight_time, 1.0, 1.0)


func build_miss_launch_params(launch_origin: Vector2, rng: GameRng) -> Dictionary:
	var side_sign: float = -1.0 if rng.randf() < 0.5 else 1.0
	var depth_sign: float = -1.0 if rng.randf() < 0.5 else 1.0
	var miss_target: Vector2 = court_config.hoop_position + Vector2(
		side_sign * ball_config.miss_shot_side_offset,
		depth_sign * ball_config.miss_shot_depth_offset
	)
	var shot_origin: Vector2 = _get_shot_origin(launch_origin, miss_target)
	var distance_ratio: float = clampf(shot_origin.distance_to(court_config.hoop_position) / maxf(court_config.three_point_radius, 1.0), 0.0, 1.0)
	var flight_time: float = lerpf(ball_config.miss_shot_flight_time_near, ball_config.miss_shot_flight_time_far, distance_ratio)
	return _build_launch_to_target(shot_origin, miss_target, court_config.rim_height, flight_time, 0.55, 0.42)


func calculate_launch_params(
	drag_vector: Vector2,
	quality: String,
	shooter: PlayerData,
	contested: bool,
	rng: GameRng,
	launch_origin: Vector2 = Vector2.ZERO
) -> Dictionary:
	var base_direction: Vector2 = _get_base_direction(drag_vector, launch_origin)
	var normalized_drag: float = _get_normalized_drag_strength(drag_vector)
	var forward_power: float = pow(normalized_drag, ball_config.forward_growth_curve_exponent)
	var arc_power: float = pow(normalized_drag, ball_config.arc_growth_curve_exponent)
	var angle_error: float = _sample_error(quality, true, shooter, contested, rng)
	var power_error: float = _sample_error(quality, false, shooter, contested, rng)
	var angle: float = base_direction.angle() + angle_error
	var launch_direction: Vector2 = Vector2.RIGHT.rotated(angle)
	var adjusted_forward_power: float = clampf(forward_power * (1.0 + power_error), 0.0, 1.0)
	var adjusted_arc_power: float = clampf(arc_power * (1.0 + power_error * 0.55), 0.0, 1.0)
	var preview_origin: Vector2 = _get_preview_origin(launch_origin, launch_direction)
	var launch_speed: float = lerpf(ball_config.starter_forward_speed, ball_config.max_forward_speed, adjusted_forward_power)
	var z_speed: float = lerpf(ball_config.starter_z_speed, ball_config.max_z_speed, adjusted_arc_power)
	return {
		"direction": launch_direction,
		"power": adjusted_forward_power,
		"forward_power": adjusted_forward_power,
		"arc_power": adjusted_arc_power,
		"launch_speed": launch_speed,
		"z_speed": z_speed,
		"preview_origin": preview_origin,
	}


func create_preview(simulator: BallSimulator, world_position: Vector2, params: Dictionary) -> Array[Dictionary]:
	var probe: BallSimulator = simulator.clone_state()
	var preview_origin: Vector2 = params.get("preview_origin", world_position)
	var launch_speed: float = params.get("launch_speed", ball_config.starter_forward_speed)
	probe.launch(preview_origin, params["direction"], launch_speed, params["z_speed"])
	var raw_points: Array[Dictionary] = []
	var elapsed: float = 0.0
	var max_z: float = 0.0
	for index in ball_config.preview_sample_count:
		var progress: float = float(index) / maxf(float(maxi(ball_config.preview_sample_count - 1, 1)), 1.0)
		var step_delta: float = ball_config.preview_sample_delta * lerpf(0.3, 1.05, pow(progress, 1.35))
		probe.step(step_delta)
		elapsed += step_delta
		max_z = maxf(max_z, probe.z)
		raw_points.append({
			"position": probe.position_xy,
			"z": probe.z,
			"launch_time": elapsed,
			"sample_delta": step_delta,
		})
		if not probe.is_in_flight:
			break
	var points: Array[Dictionary] = []
	for index in raw_points.size():
		var point: Dictionary = raw_points[index]
		var progress: float = float(index) / maxf(float(maxi(raw_points.size() - 1, 1)), 1.0)
		var apex_ratio: float = 0.0
		if max_z > 0.0:
			apex_ratio = clampf(1.0 - absf(point["z"] - max_z) / max_z, 0.0, 1.0)
		var apex_weight: float = pow(apex_ratio, 1.6) * ball_config.preview_apex_emphasis_strength
		var radius: float = lerpf(ball_config.preview_dot_radius_min, ball_config.preview_dot_radius_max, clampf(progress * 0.72 + apex_weight, 0.0, 1.0))
		var alpha: float = clampf(0.3 + progress * 0.45 + apex_weight * 0.35, 0.18, 0.95)
		var screen_position: Vector2 = point["position"] + Vector2(0.0, -point["z"] * 0.14)
		if projection != null:
			screen_position = projection.preview_world_to_screen(point["position"], point["z"])
		points.append({
			"position": point["position"],
			"z": point["z"],
			"screen_position": screen_position,
			"radius": radius,
			"alpha": alpha,
			"apex_weight": apex_weight,
			"launch_time": point["launch_time"],
			"sample_delta": point["sample_delta"],
		})
	return points


func _sample_error(
	quality: String,
	is_angle: bool,
	shooter: PlayerData,
	contested: bool,
	rng: GameRng
) -> float:
	var base: float = 0.0
	match quality:
		"green":
			base = shot_config.green_angle_error if is_angle else shot_config.green_power_error
		"yellow":
			base = shot_config.yellow_angle_error if is_angle else shot_config.yellow_power_error
		_:
			base = shot_config.red_angle_error if is_angle else shot_config.red_power_error
	var shooter_bonus: float = 1.0 - ((float(shooter.shooting) + float(shooter.release_consistency)) * 0.5 / 100.0) * 0.28
	var contested_penalty: float = 1.18 if contested else 1.0
	var max_error: float = base * shooter_bonus * contested_penalty
	return rng.randf_range(-max_error, max_error)


func _find_pass_conversion_target(release_world: Vector2, teammates: Array[PlayerController], release_screen: Vector2 = Vector2.INF) -> PlayerController:
	for teammate in teammates:
		if release_screen != Vector2.INF and teammate.get_screen_anchor().distance_to(release_screen) <= teammate.get_input_hit_radius():
			return teammate
		if teammate.world_position.distance_to(release_world) <= shot_config.teammate_conversion_radius:
			return teammate
	return null


func _get_normalized_drag_strength(drag_vector: Vector2) -> float:
	return clampf(drag_vector.length() / maxf(shot_config.max_drag_distance, 1.0), 0.0, 1.0)


func _get_base_direction(drag_vector: Vector2, launch_origin: Vector2) -> Vector2:
	if drag_vector.length() > 0.001:
		return -drag_vector.normalized()
	if court_config != null and launch_origin != Vector2.ZERO:
		return (court_config.hoop_position - launch_origin).normalized()
	return Vector2.UP


func _get_preview_origin(launch_origin: Vector2, direction: Vector2) -> Vector2:
	if launch_origin == Vector2.ZERO:
		return launch_origin
	var lateral: Vector2 = direction.orthogonal()
	return launch_origin + lateral * ball_config.preview_origin_offset.x + direction * ball_config.preview_origin_offset.y


func _build_launch_to_target(
	shot_origin: Vector2,
	target_xy: Vector2,
	target_z: float,
	flight_time: float,
	forward_power: float,
	arc_power: float
) -> Dictionary:
	var safe_time: float = maxf(flight_time, 0.2)
	var delta_xy: Vector2 = target_xy - shot_origin
	var velocity_xy: Vector2 = delta_xy / safe_time
	var direction: Vector2 = velocity_xy.normalized() if velocity_xy.length() > 0.001 else Vector2.UP
	var launch_speed: float = velocity_xy.length()
	var z_speed: float = (target_z - 0.5 * ball_config.gravity * safe_time * safe_time) / safe_time
	return {
		"direction": direction,
		"power": forward_power,
		"forward_power": forward_power,
		"arc_power": arc_power,
		"launch_speed": launch_speed,
		"z_speed": z_speed,
		"preview_origin": shot_origin,
		"flight_time": safe_time,
	}


func _get_shot_origin(launch_origin: Vector2, target_xy: Vector2) -> Vector2:
	var direction: Vector2 = (target_xy - launch_origin).normalized()
	if direction.length() <= 0.001:
		direction = Vector2.UP
	return _get_preview_origin(launch_origin, direction)
