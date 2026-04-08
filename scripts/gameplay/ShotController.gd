class_name ShotController
extends RefCounted

var shot_config: ShotTimingConfig
var ball_config: BallPhysicsConfig
var court_config: CourtConfig
var projection: CourtProjection

var is_aiming: bool = false
var aim_elapsed: float = 0.0
var aim_start_world: Vector2 = Vector2.ZERO
var aim_variant_ready: bool = false
var aim_miss_side_sign: float = 1.0
var aim_miss_depth_sign: float = 1.0


func begin_aim(world_position: Vector2, rng: GameRng = null) -> void:
	is_aiming = true
	aim_elapsed = 0.0
	aim_start_world = world_position
	_roll_aim_variant(rng)


func update_aim(delta: float, _drag_vector: Vector2 = Vector2.ZERO) -> void:
	if not is_aiming:
		return
	aim_elapsed += delta


func cancel_aim() -> void:
	is_aiming = false
	aim_elapsed = 0.0
	aim_variant_ready = false


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
	if not aim_variant_ready:
		_roll_aim_variant(rng)
	var quality: String = get_current_quality(contested, shooter.release_consistency)
	var params: Dictionary = build_launch_profile(ballhandler_position, quality)
	cancel_aim()
	return {
		"kind": "shot",
		"quality": quality,
		"outcome": params["outcome"],
		"launch_position": params["launch_position"],
		"launch_z": params["launch_z"],
		"velocity_xy": params["velocity_xy"],
		"vz": params["vz"],
		"flight_time": params["flight_time"],
		"apex_z": params["apex_z"],
		"target_xy": params["target_xy"],
		"shot_value": params["shot_value"],
		"force_make": params["force_make"],
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


func get_preview_profile(ballhandler_position: Vector2, shooter: PlayerData, contested: bool) -> Dictionary:
	if not is_aiming:
		return {}
	var quality: String = get_current_quality(contested, shooter.release_consistency)
	return build_launch_profile(ballhandler_position, quality)


func build_current_launch_profile(ballhandler_position: Vector2, shooter: PlayerData, contested: bool) -> Dictionary:
	return get_preview_profile(ballhandler_position, shooter, contested)


func build_launch_profile(launch_origin: Vector2, quality: String) -> Dictionary:
	var is_make: bool = quality == "green"
	var target_xy: Vector2 = court_config.hoop_position if is_make else get_current_miss_target()
	var shot_origin: Vector2 = _get_shot_origin(launch_origin, target_xy)
	var distance_ratio: float = clampf(shot_origin.distance_to(court_config.hoop_position) / maxf(court_config.three_point_radius, 1.0), 0.0, 1.0)
	var min_apex: float = lerpf(ball_config.made_shot_min_apex_near, ball_config.made_shot_min_apex_far, distance_ratio)
	var min_flight: float = lerpf(ball_config.made_shot_min_flight_time_near, ball_config.made_shot_min_flight_time_far, distance_ratio)
	if not is_make:
		min_apex *= ball_config.miss_apex_scale
		min_flight *= ball_config.miss_min_flight_time_scale
	return _build_launch_to_target(
		shot_origin,
		target_xy,
		ball_config.shot_release_height,
		court_config.rim_height,
		min_apex,
		min_flight,
		quality,
		"make" if is_make else "miss",
		3 if court_config.is_three_point(launch_origin) else 2,
		is_make
	)


func create_preview(simulator: BallSimulator, params: Dictionary) -> Array[Dictionary]:
	var probe: BallSimulator = simulator.clone_state()
	var launch_position: Vector2 = params.get("launch_position", Vector2.ZERO)
	var launch_z: float = float(params.get("launch_z", ball_config.shot_release_height))
	var velocity_xy: Vector2 = params.get("velocity_xy", Vector2.ZERO)
	var vz: float = float(params.get("vz", 0.0))
	var force_make: bool = bool(params.get("force_make", false))
	var flight_time: float = maxf(float(params.get("flight_time", ball_config.preview_sample_delta)), ball_config.preview_sample_delta)
	var segment_count: int = maxi(ball_config.preview_sample_count, int(ceil(flight_time / maxf(ball_config.preview_sample_delta, 0.01))) + 1)
	var sample_times: Array[float] = []
	for index in segment_count:
		sample_times.append(flight_time * float(index + 1) / float(segment_count))
	var apex_time: float = vz / maxf(absf(ball_config.gravity), 0.001)
	if apex_time > 0.0 and apex_time < flight_time:
		sample_times.append(apex_time)
	sample_times.sort()
	probe.launch(launch_position, velocity_xy, launch_z, vz, force_make)
	var raw_points: Array[Dictionary] = []
	var max_z: float = launch_z
	var elapsed: float = 0.0
	for sample_time in sample_times:
		var step_delta: float = maxf(float(sample_time) - elapsed, 0.0)
		if step_delta <= 0.0001:
			continue
		probe.step(step_delta)
		elapsed += step_delta
		max_z = maxf(max_z, probe.z)
		raw_points.append({
			"position": probe.position_xy,
			"z": probe.z,
			"launch_time": elapsed,
			"sample_delta": step_delta,
		})
		if elapsed >= flight_time or not probe.is_in_flight:
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


func get_current_miss_target() -> Vector2:
	if court_config == null or ball_config == null:
		return Vector2.ZERO
	return court_config.hoop_position + Vector2(
		aim_miss_side_sign * ball_config.miss_shot_side_offset,
		aim_miss_depth_sign * ball_config.miss_shot_depth_offset
	)


func _roll_aim_variant(rng: GameRng = null) -> void:
	aim_variant_ready = true
	if rng == null:
		aim_miss_side_sign = 1.0
		aim_miss_depth_sign = 1.0
		return
	aim_miss_side_sign = -1.0 if rng.randf() < 0.5 else 1.0
	aim_miss_depth_sign = -1.0 if rng.randf() < 0.5 else 1.0


func _get_preview_origin(launch_origin: Vector2, direction: Vector2) -> Vector2:
	if launch_origin == Vector2.ZERO:
		return launch_origin
	var lateral: Vector2 = direction.orthogonal()
	return launch_origin + lateral * ball_config.preview_origin_offset.x + direction * ball_config.preview_origin_offset.y


func _build_launch_to_target(
	shot_origin: Vector2,
	target_xy: Vector2,
	release_z: float,
	target_z: float,
	min_apex: float,
	min_flight: float,
	quality: String,
	outcome: String,
	shot_value: int,
	force_make: bool
) -> Dictionary:
	var solved_profile: Dictionary = _solve_ballistic_profile(shot_origin, target_xy, release_z, target_z, min_apex, min_flight)
	return {
		"quality": quality,
		"outcome": outcome,
		"launch_position": shot_origin,
		"launch_z": release_z,
		"velocity_xy": solved_profile["velocity_xy"],
		"vz": solved_profile["vz"],
		"flight_time": solved_profile["flight_time"],
		"apex_z": solved_profile["apex_z"],
		"target_xy": target_xy,
		"shot_value": shot_value,
		"force_make": force_make,
	}


func _get_shot_origin(launch_origin: Vector2, target_xy: Vector2) -> Vector2:
	var direction: Vector2 = (target_xy - launch_origin).normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector2.UP
	return _get_preview_origin(launch_origin, direction)


func _solve_ballistic_profile(
	shot_origin: Vector2,
	target_xy: Vector2,
	release_z: float,
	target_z: float,
	min_apex: float,
	min_flight: float
) -> Dictionary:
	var gravity_strength: float = maxf(absf(ball_config.gravity), 0.001)
	var apex_z: float = _solve_apex_for_min_flight(release_z, target_z, min_apex, min_flight, gravity_strength)
	var flight_time: float = _flight_time_from_apex(release_z, target_z, apex_z, gravity_strength)
	var velocity_xy: Vector2 = (target_xy - shot_origin) / maxf(flight_time, 0.001)
	var vz: float = sqrt(maxf(2.0 * gravity_strength * maxf(apex_z - release_z, 0.0), 0.0))
	return {
		"velocity_xy": velocity_xy,
		"vz": vz,
		"flight_time": flight_time,
		"apex_z": apex_z,
	}


func _solve_apex_for_min_flight(
	release_z: float,
	target_z: float,
	min_apex: float,
	min_flight: float,
	gravity_strength: float
) -> float:
	var safe_apex: float = maxf(maxf(min_apex, release_z + 1.0), target_z + 1.0)
	if _flight_time_from_apex(release_z, target_z, safe_apex, gravity_strength) >= min_flight:
		return safe_apex
	var low: float = safe_apex
	var high: float = safe_apex
	var guard: int = 0
	while _flight_time_from_apex(release_z, target_z, high, gravity_strength) < min_flight and guard < 24:
		high += 64.0
		guard += 1
	for _iteration in 20:
		var mid: float = (low + high) * 0.5
		if _flight_time_from_apex(release_z, target_z, mid, gravity_strength) < min_flight:
			low = mid
		else:
			high = mid
	return high


func _flight_time_from_apex(release_z: float, target_z: float, apex_z: float, gravity_strength: float) -> float:
	var rise: float = maxf(apex_z - release_z, 0.0)
	var fall: float = maxf(apex_z - target_z, 0.0)
	return sqrt((2.0 * rise) / gravity_strength) + sqrt((2.0 * fall) / gravity_strength)
