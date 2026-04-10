class_name ShotController
extends RefCounted

const PROFILE_KIND_FREE_FLIGHT: String = "free_flight"
const PROFILE_KIND_GUIDED_MAKE: String = "guided_make"

var shot_config: ShotTimingConfig
var ball_config: BallPhysicsConfig
var court_config: CourtConfig
var projection: CourtProjection

var is_aiming: bool = false
var aim_elapsed: float = 0.0
var aim_start_world: Vector2 = Vector2.ZERO
var aim_timing_profile: Dictionary = {}
var aim_variant_ready: bool = false
var aim_miss_side_sign: float = 1.0
var aim_miss_depth_sign: float = 1.0


func begin_aim(world_position: Vector2, timing_profile: Dictionary = {}, rng: GameRng = null) -> void:
	is_aiming = true
	aim_elapsed = 0.0
	aim_start_world = world_position
	aim_timing_profile = timing_profile.duplicate(true)
	_roll_aim_variant(rng)


func update_aim(delta: float, _drag_vector: Vector2 = Vector2.ZERO) -> void:
	if not is_aiming:
		return
	aim_elapsed += delta


func cancel_aim() -> void:
	is_aiming = false
	aim_elapsed = 0.0
	aim_timing_profile.clear()
	aim_variant_ready = false


func get_current_quality(contested: bool, release_consistency: int) -> String:
	return classify_meter_progress(get_meter_progress(), contested, release_consistency)


func get_timing_window(_contested: bool, _release_consistency: int) -> float:
	return clampf(shot_config.green_window_ratio, 0.08, 0.3)


func get_timing_profile() -> Dictionary:
	return aim_timing_profile.duplicate(true)


func get_release_time_seconds() -> float:
	if not aim_timing_profile.is_empty():
		return maxf(float(aim_timing_profile.get("release_time_seconds", 0.0)), 0.0)
	return maxf(float(shot_config.meter_cycle_duration) * clampf(float(shot_config.meter_green_center), 0.0, 1.0), 0.0)


func get_decision_duration_seconds() -> float:
	return maxf(get_release_time_seconds(), 0.0)


func get_full_animation_duration_seconds() -> float:
	if not aim_timing_profile.is_empty():
		return maxf(float(aim_timing_profile.get("full_animation_duration_seconds", 0.0)), 0.0)
	return maxf(float(shot_config.meter_cycle_duration), 0.0)


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
	var action: Dictionary = _compose_release_action(params, quality, quality)
	cancel_aim()
	return action


func build_action_for_quality(
	ballhandler_position: Vector2,
	_shooter: PlayerData,
	quality: String,
	rng: GameRng = null,
	forced_timing_result: String = "",
	force_miss: bool = false
) -> Dictionary:
	if not aim_variant_ready:
		_roll_aim_variant(rng)
	var launch_quality: String = "red" if force_miss else quality
	var params: Dictionary = build_launch_profile(ballhandler_position, launch_quality)
	if force_miss:
		params["outcome"] = "miss"
		params["force_make"] = false
	return _compose_release_action(params, quality, forced_timing_result if forced_timing_result != "" else quality)


func get_meter_progress() -> float:
	var duration: float = get_decision_duration_seconds()
	if shot_config == null or duration <= 0.0:
		return 0.0
	return clampf(aim_elapsed / duration, 0.0, 1.0)


func get_green_window(_contested: bool, _release_consistency: int) -> Vector2:
	var width: float = get_timing_window(false, 0)
	var end: float = clampf(_get_release_progress(), 0.0, 1.0)
	var start: float = clampf(end - width, 0.0, end)
	return Vector2(start, end)


func get_yellow_window(_contested: bool, _release_consistency: int) -> Vector2:
	var green_window: Vector2 = get_green_window(false, 0)
	var yellow_end: float = green_window.x
	var yellow_width: float = clampf(shot_config.yellow_window_ratio, 0.0, 0.9)
	var yellow_start: float = clampf(yellow_end - yellow_width, 0.0, yellow_end)
	return Vector2(yellow_start, yellow_end)


func classify_meter_progress(progress: float, contested: bool, release_consistency: int) -> String:
	var green_window: Vector2 = get_green_window(contested, release_consistency)
	var yellow_window: Vector2 = get_yellow_window(contested, release_consistency)
	if progress >= green_window.x and progress <= green_window.y:
		return "green"
	if progress >= yellow_window.x and progress < yellow_window.y:
		return "yellow"
	return "red"


func get_meter_snapshot(contested: bool, release_consistency: int) -> Dictionary:
	var progress: float = get_meter_progress()
	var green_window: Vector2 = get_green_window(contested, release_consistency)
	var yellow_window: Vector2 = get_yellow_window(contested, release_consistency)
	return {
		"visible": is_aiming,
		"progress": progress,
		"yellow_start": yellow_window.x,
		"yellow_end": yellow_window.y,
		"green_start": green_window.x,
		"green_end": green_window.y,
		"release_progress": _get_release_progress(),
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


func _get_release_progress() -> float:
	if get_decision_duration_seconds() <= 0.0:
		return clampf(float(shot_config.meter_green_center), 0.0, 1.0)
	return 1.0


func _compose_release_action(params: Dictionary, quality: String, timing_result: String) -> Dictionary:
	return {
		"kind": "shot",
		"profile_kind": params.get("profile_kind", PROFILE_KIND_FREE_FLIGHT),
		"quality": quality,
		"timing_result": timing_result,
		"outcome": params["outcome"],
		"launch_position": params["launch_position"],
		"launch_z": params["launch_z"],
		"velocity_xy": params["velocity_xy"],
		"vz": params["vz"],
		"flight_time": params["flight_time"],
		"apex_z": params["apex_z"],
		"target_xy": params["target_xy"],
		"shot_value": params["shot_value"],
		"force_make": params.get("force_make", false),
	}.merged(params, true)


func build_launch_profile(launch_origin: Vector2, quality: String) -> Dictionary:
	var shot_value: int = 3 if court_config.is_three_point(launch_origin) else 2
	if quality == "green":
		return _build_guided_make_profile(launch_origin, quality, shot_value)
	var target_xy: Vector2 = get_current_miss_target()
	var shot_origin: Vector2 = _get_shot_origin(launch_origin, target_xy)
	var distance_ratio: float = clampf(shot_origin.distance_to(court_config.hoop_position) / maxf(court_config.three_point_radius, 1.0), 0.0, 1.0)
	var min_apex: float = lerpf(ball_config.made_shot_min_apex_near, ball_config.made_shot_min_apex_far, distance_ratio) * ball_config.miss_apex_scale
	var min_flight: float = lerpf(ball_config.made_shot_min_flight_time_near, ball_config.made_shot_min_flight_time_far, distance_ratio) * ball_config.miss_min_flight_time_scale
	return _build_launch_to_target(
		shot_origin,
		target_xy,
		ball_config.shot_release_height,
		court_config.rim_height,
		min_apex,
		min_flight,
		quality,
		"miss",
		shot_value,
		false
	)


func create_preview(simulator: BallSimulator, params: Dictionary) -> Array[Dictionary]:
	var probe: BallSimulator = simulator.clone_state()
	var flight_time: float = maxf(float(params.get("flight_time", ball_config.preview_sample_delta)), ball_config.preview_sample_delta)
	var segment_count: int = maxi(ball_config.preview_sample_count, int(ceil(flight_time / maxf(ball_config.preview_sample_delta, 0.01))) + 1)
	var sample_times: Array[float] = []
	for index in segment_count:
		sample_times.append(flight_time * float(index + 1) / float(segment_count))
	var apex_time: float = float(params.get("apex_time", params.get("vz", 0.0) / maxf(absf(ball_config.gravity), 0.001)))
	if apex_time > 0.0 and apex_time < flight_time:
		sample_times.append(apex_time)
	sample_times.sort()
	probe.launch_shot_profile(params)
	var raw_points: Array[Dictionary] = []
	var max_z: float = float(params.get("launch_z", ball_config.shot_release_height))
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
			screen_position.y += projection.guided_make_terminal_screen_drop(probe.get_terminal_visual_drop_weight())
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


func get_current_make_target() -> Vector2:
	return _get_make_score_gate_xy()


func get_current_make_entry_target() -> Vector2:
	return _get_make_handoff_xy()


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


func _build_guided_make_profile(launch_origin: Vector2, quality: String, shot_value: int) -> Dictionary:
	var distance_ratio: float = clampf(launch_origin.distance_to(court_config.hoop_position) / maxf(court_config.three_point_radius, 1.0), 0.0, 1.0)
	var base_apex: float = lerpf(ball_config.made_shot_min_apex_near, ball_config.made_shot_min_apex_far, distance_ratio)
	var base_flight: float = lerpf(ball_config.made_shot_min_flight_time_near, ball_config.made_shot_min_flight_time_far, distance_ratio)
	var entry_xy: Vector2 = _get_make_handoff_xy()
	var entry_z: float = court_config.rim_height
	var shot_origin: Vector2 = _get_shot_origin(launch_origin, entry_xy)
	var flight_boosts: Array[float] = [0.0, 0.08, 0.16, 0.24, 0.32]
	var apex_boosts: Array[float] = [0.0, 32.0, 64.0, 96.0]
	var fallback_profile: Dictionary = {}
	for flight_boost in flight_boosts:
		for apex_boost in apex_boosts:
			var arc_result: Dictionary = _compute_arc_through_target(
				shot_origin,
				entry_xy,
				ball_config.shot_release_height,
				entry_z,
				base_apex + apex_boost,
				base_flight + flight_boost
			)
			var approach: Dictionary = {
				"velocity_xy": arc_result["velocity_xy"],
				"vz": arc_result["vz"],
				"flight_time": arc_result["flight_time"],
				"apex_z": arc_result["apex_z"],
			}
			var candidate: Dictionary = _build_guided_make_profile_data(
				launch_origin,
				shot_origin,
				approach,
				entry_xy,
				entry_z,
				quality,
				shot_value,
				arc_result["entry_time"]
			)
			if fallback_profile.is_empty():
				fallback_profile = candidate
			if _validate_guided_make_profile(candidate):
				return candidate
	if not fallback_profile.is_empty():
		return fallback_profile
	var fallback_arc: Dictionary = _compute_arc_through_target(
		shot_origin,
		entry_xy,
		ball_config.shot_release_height,
		entry_z,
		base_apex + 96.0,
		base_flight + 0.32
	)
	var fallback_approach: Dictionary = {
		"velocity_xy": fallback_arc["velocity_xy"],
		"vz": fallback_arc["vz"],
		"flight_time": fallback_arc["flight_time"],
		"apex_z": fallback_arc["apex_z"],
	}
	return _build_guided_make_profile_data(
		launch_origin,
		shot_origin,
		fallback_approach,
		entry_xy,
		entry_z,
		quality,
		shot_value,
		fallback_arc["entry_time"]
	)


func _build_guided_make_profile_data(
	launch_origin: Vector2,
	shot_origin: Vector2,
	approach: Dictionary,
	entry_xy: Vector2,
	entry_z: float,
	quality: String,
	shot_value: int,
	override_entry_time: float = -1.0
) -> Dictionary:
	var score_gate_xy: Vector2 = entry_xy
	var score_gate_z: float = _get_make_score_gate_z()
	var capture_duration: float = 0.0
	var guided_descent_duration: float = maxf(ball_config.made_shot_descent_duration, 0.12)
	var net_exit_xy: Vector2 = Vector2(court_config.hoop_position.x, score_gate_xy.y)
	var net_exit_z: float = court_config.net_exit_z
	var exit_xy: Vector2 = net_exit_xy + Vector2(0.0, ball_config.ball_radius * 0.18)
	var exit_z: float = maxf(court_config.net_exit_z - 36.0, 0.0)
	var exit_duration: float = maxf(minf(guided_descent_duration * 0.45, 0.12), 0.06)
	var actual_entry_time: float = override_entry_time if override_entry_time > 0.0 else float(approach["flight_time"])
	var total_time: float = actual_entry_time + capture_duration + guided_descent_duration + exit_duration
	var apex_time: float = float(approach["vz"]) / maxf(absf(ball_config.gravity), 0.001)
	return {
		"profile_kind": PROFILE_KIND_GUIDED_MAKE,
		"quality": quality,
		"outcome": "make",
		"launch_position": shot_origin,
		"launch_z": ball_config.shot_release_height,
		"velocity_xy": approach["velocity_xy"],
		"vz": approach["vz"],
		"flight_time": total_time,
		"apex_z": approach["apex_z"],
		"apex_time": apex_time,
		"target_xy": score_gate_xy,
		"shot_value": shot_value,
		"force_make": false,
		"approach_launch_position": shot_origin,
		"approach_launch_z": ball_config.shot_release_height,
		"approach_velocity_xy": approach["velocity_xy"],
		"approach_vz": approach["vz"],
		"entry_xy": entry_xy,
		"entry_z": entry_z,
		"entry_time": actual_entry_time,
		"score_gate_xy": score_gate_xy,
		"score_gate_z": score_gate_z,
		"net_exit_xy": net_exit_xy,
		"net_exit_z": net_exit_z,
		"exit_xy": exit_xy,
		"exit_z": exit_z,
		"descent_duration": ball_config.made_shot_descent_duration,
		"capture_duration": capture_duration,
		"guided_descent_duration": guided_descent_duration,
		"net_exit_duration": exit_duration,
		"launch_origin": launch_origin,
	}


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
	var apex_time: float = float(solved_profile["vz"]) / maxf(absf(ball_config.gravity), 0.001)
	return {
		"profile_kind": PROFILE_KIND_FREE_FLIGHT,
		"quality": quality,
		"outcome": outcome,
		"launch_position": shot_origin,
		"launch_z": release_z,
		"velocity_xy": solved_profile["velocity_xy"],
		"vz": solved_profile["vz"],
		"flight_time": solved_profile["flight_time"],
		"apex_z": solved_profile["apex_z"],
		"apex_time": apex_time,
		"target_xy": target_xy,
		"shot_value": shot_value,
		"force_make": force_make,
	}


func _get_shot_origin(launch_origin: Vector2, target_xy: Vector2) -> Vector2:
	var direction: Vector2 = (target_xy - launch_origin).normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector2.UP
	return _get_preview_origin(launch_origin, direction)


func _get_preview_origin(launch_origin: Vector2, direction: Vector2) -> Vector2:
	if launch_origin == Vector2.ZERO:
		return launch_origin
	var lateral: Vector2 = direction.orthogonal()
	return launch_origin + lateral * ball_config.preview_origin_offset.x + direction * ball_config.preview_origin_offset.y


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


func _validate_guided_make_profile(profile: Dictionary) -> bool:
	var entry_xy: Vector2 = profile["entry_xy"]
	var entry_z: float = float(profile["entry_z"])
	var score_gate_xy: Vector2 = profile["score_gate_xy"]
	var score_gate_z: float = float(profile["score_gate_z"])
	if entry_xy.distance_to(court_config.hoop_position) > ball_config.made_shot_capture_radius:
		return false
	if entry_xy.y < court_config.hoop_position.y + court_config.score_entry_min_front_offset:
		return false
	if entry_xy.y - court_config.backboard_y < ball_config.made_shot_backboard_clearance:
		return false
	if absf(entry_z - court_config.rim_height) > 0.001:
		return false
	if score_gate_xy.distance_to(court_config.hoop_position) > court_config.rim_inner_radius:
		return false
	if score_gate_xy.y < court_config.hoop_position.y + court_config.score_entry_min_front_offset:
		return false
	if score_gate_z >= court_config.rim_height:
		return false
	var descent_horizontal: float = maxf(entry_xy.distance_to(score_gate_xy), 0.001)
	var descent_vertical: float = maxf(entry_z - score_gate_z, 0.001)
	var descent_angle_deg: float = rad_to_deg(atan2(descent_vertical, descent_horizontal))
	if descent_angle_deg < ball_config.made_shot_min_descent_angle_deg:
		return false
	var probe: BallSimulator = BallSimulator.new()
	probe.gravity = ball_config.gravity
	probe.ball_radius = ball_config.ball_radius
	probe.launch(
		profile["approach_launch_position"],
		profile["approach_velocity_xy"],
		float(profile["approach_launch_z"]),
		float(profile["approach_vz"]),
		false
	)
	var entry_time: float = float(profile["entry_time"])
	var elapsed: float = 0.0
	var step_delta: float = 1.0 / 60.0
	while elapsed < entry_time - 0.0001 and probe.is_in_flight:
		var segment: float = minf(step_delta, entry_time - elapsed)
		probe.step(segment)
		elapsed += segment
		if _sample_is_board_side(probe.position_xy, probe.z):
			return false
		if _sample_hits_backboard(probe):
			return false
		if _sample_hits_outer_rim(probe):
			return false
	if probe.position_xy.distance_to(entry_xy) > 14.0:
		return false
	if absf(probe.z - entry_z) > 14.0:
		return false
	return true


func _sample_is_board_side(sample_xy: Vector2, sample_z: float) -> bool:
	return sample_z < court_config.over_backboard_z_threshold and sample_xy.y <= court_config.backboard_y + ball_config.ball_radius * 0.2


func _sample_hits_backboard(probe: BallSimulator) -> bool:
	var half_width: float = court_config.backboard_width * 0.5 + ball_config.ball_radius
	var crossed: bool = probe.previous_position_xy.y >= court_config.backboard_y and probe.position_xy.y <= court_config.backboard_y
	if not crossed:
		return false
	if absf(probe.position_xy.x - court_config.backboard_x_center) > half_width:
		return false
	return probe.z >= court_config.rim_height - 40.0 and probe.z <= court_config.rim_height + 180.0


func _sample_hits_outer_rim(probe: BallSimulator) -> bool:
	var current_distance: float = probe.position_xy.distance_to(court_config.hoop_position)
	var previous_distance: float = probe.previous_position_xy.distance_to(court_config.hoop_position)
	var outer_radius: float = court_config.rim_radius + ball_config.ball_radius
	var near_height: bool = absf(probe.z - court_config.rim_height) <= 48.0
	return near_height and current_distance <= outer_radius and previous_distance >= current_distance and current_distance >= court_config.rim_inner_radius


func _get_make_entry_xy(front_depth: float) -> Vector2:
	return court_config.hoop_position + Vector2(0.0, front_depth)


func _get_make_handoff_xy() -> Vector2:
	return _get_make_score_gate_xy()


func _get_make_score_gate_xy() -> Vector2:
	return Vector2(
		court_config.hoop_position.x,
		court_config.hoop_position.y + maxf(court_config.score_entry_min_front_offset, minf(ball_config.made_shot_entry_front_depth * 0.45, ball_config.made_shot_descent_centering_tolerance))
	)


func _get_make_score_gate_z() -> float:
	return court_config.rim_height - minf(ball_config.ball_radius * 0.45, 10.0)


func _compute_arc_through_target(
	shot_origin: Vector2,
	entry_xy: Vector2,
	release_z: float,
	rim_z: float,
	min_apex: float,
	min_flight: float
) -> Dictionary:
	var direction: Vector2 = (entry_xy - shot_origin).normalized()
	var overshoot_distance: float = ball_config.ball_radius * 0.7
	var virtual_target_xy: Vector2 = entry_xy + direction * overshoot_distance
	var virtual_target_z: float = rim_z - ball_config.ball_radius * 0.5
	var arc: Dictionary = _solve_ballistic_profile(
		shot_origin, virtual_target_xy, release_z, virtual_target_z,
		min_apex, min_flight
	)
	var vz_launch: float = arc["vz"]
	var g: float = maxf(absf(ball_config.gravity), 0.001)
	var discriminant: float = vz_launch * vz_launch - 2.0 * g * (rim_z - release_z)
	var entry_time: float = arc["flight_time"]
	if discriminant >= 0.0:
		entry_time = (vz_launch + sqrt(discriminant)) / g
	var actual_entry_xy: Vector2 = shot_origin + arc["velocity_xy"] * entry_time
	var vz_at_entry: float = vz_launch - g * entry_time
	return {
		"velocity_xy": arc["velocity_xy"],
		"vz": vz_launch,
		"flight_time": arc["flight_time"],
		"apex_z": arc["apex_z"],
		"entry_time": entry_time,
		"actual_entry_xy": actual_entry_xy,
		"vz_at_entry": vz_at_entry,
	}
