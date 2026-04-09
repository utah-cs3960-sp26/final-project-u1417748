class_name BallSimulator
extends RefCounted

const PROFILE_KIND_FREE_FLIGHT: String = "free_flight"
const PROFILE_KIND_GUIDED_MAKE: String = "guided_make"

const FLIGHT_PHASE_NONE: String = "none"
const FLIGHT_PHASE_FREE_FLIGHT: String = "free_flight"
const FLIGHT_PHASE_MAKE_CAPTURE: String = "make_capture"
const FLIGHT_PHASE_GUIDED_DESCENT: String = "guided_descent"
const FLIGHT_PHASE_NET_EXIT: String = "net_exit"

var position_xy: Vector2 = Vector2.ZERO
var previous_position_xy: Vector2 = Vector2.ZERO
var velocity_xy: Vector2 = Vector2.ZERO
var z: float = 0.0
var previous_z: float = 0.0
var vz: float = 0.0
var gravity: float = -920.0
var ball_radius: float = 18.0
var launch_z: float = 0.0
var is_in_flight: bool = false
var already_scored: bool = false
var forced_make: bool = false

var shot_profile: Dictionary = {}
var profile_kind: String = PROFILE_KIND_FREE_FLIGHT
var flight_phase: String = FLIGHT_PHASE_NONE
var shot_elapsed: float = 0.0
var phase_elapsed: float = 0.0
var is_guided_make: bool = false
var guided_make_captured: bool = false
var passed_score_gate: bool = false
var step_score_crossed: bool = false
var step_score_sample_xy: Vector2 = Vector2.ZERO
var step_score_sample_z: float = 0.0
var step_score_sample_t: float = 0.0


func clone_state() -> BallSimulator:
	var clone: BallSimulator = BallSimulator.new()
	clone.position_xy = position_xy
	clone.previous_position_xy = previous_position_xy
	clone.velocity_xy = velocity_xy
	clone.z = z
	clone.previous_z = previous_z
	clone.vz = vz
	clone.gravity = gravity
	clone.ball_radius = ball_radius
	clone.launch_z = launch_z
	clone.is_in_flight = is_in_flight
	clone.already_scored = already_scored
	clone.forced_make = forced_make
	clone.shot_profile = shot_profile.duplicate(true)
	clone.profile_kind = profile_kind
	clone.flight_phase = flight_phase
	clone.shot_elapsed = shot_elapsed
	clone.phase_elapsed = phase_elapsed
	clone.is_guided_make = is_guided_make
	clone.guided_make_captured = guided_make_captured
	clone.passed_score_gate = passed_score_gate
	clone.step_score_crossed = step_score_crossed
	clone.step_score_sample_xy = step_score_sample_xy
	clone.step_score_sample_z = step_score_sample_z
	clone.step_score_sample_t = step_score_sample_t
	return clone


func reset_to_possession(world_position: Vector2) -> void:
	position_xy = world_position
	previous_position_xy = world_position
	velocity_xy = Vector2.ZERO
	z = 0.0
	previous_z = 0.0
	vz = 0.0
	launch_z = 0.0
	is_in_flight = false
	already_scored = false
	forced_make = false
	shot_profile.clear()
	profile_kind = PROFILE_KIND_FREE_FLIGHT
	flight_phase = FLIGHT_PHASE_NONE
	shot_elapsed = 0.0
	phase_elapsed = 0.0
	is_guided_make = false
	guided_make_captured = false
	passed_score_gate = false
	_clear_step_events()


func launch(world_position: Vector2, velocity_value: Vector2, initial_z: float, z_speed: float, force_make: bool = false) -> void:
	position_xy = world_position
	previous_position_xy = world_position
	velocity_xy = velocity_value
	launch_z = maxf(initial_z, 0.0)
	z = launch_z
	previous_z = launch_z
	vz = z_speed
	is_in_flight = true
	already_scored = false
	forced_make = force_make
	shot_profile.clear()
	profile_kind = PROFILE_KIND_FREE_FLIGHT
	flight_phase = FLIGHT_PHASE_FREE_FLIGHT
	shot_elapsed = 0.0
	phase_elapsed = 0.0
	is_guided_make = false
	guided_make_captured = false
	passed_score_gate = false
	_clear_step_events()


func launch_shot_profile(profile: Dictionary) -> void:
	if str(profile.get("profile_kind", PROFILE_KIND_FREE_FLIGHT)) != PROFILE_KIND_GUIDED_MAKE:
		launch(
			profile.get("launch_position", Vector2.ZERO),
			profile.get("velocity_xy", Vector2.ZERO),
			float(profile.get("launch_z", 0.0)),
			float(profile.get("vz", 0.0)),
			bool(profile.get("force_make", false))
		)
		return
	shot_profile = profile.duplicate(true)
	profile_kind = PROFILE_KIND_GUIDED_MAKE
	is_guided_make = true
	guided_make_captured = false
	passed_score_gate = false
	_clear_step_events()
	launch(
		profile.get("approach_launch_position", profile.get("launch_position", Vector2.ZERO)),
		profile.get("approach_velocity_xy", profile.get("velocity_xy", Vector2.ZERO)),
		float(profile.get("approach_launch_z", profile.get("launch_z", 0.0))),
		float(profile.get("approach_vz", profile.get("vz", 0.0))),
		false
	)
	shot_profile = profile.duplicate(true)
	profile_kind = PROFILE_KIND_GUIDED_MAKE
	is_guided_make = true
	forced_make = false
	flight_phase = FLIGHT_PHASE_FREE_FLIGHT
	shot_elapsed = 0.0
	phase_elapsed = 0.0
	guided_make_captured = false
	passed_score_gate = false
	_clear_step_events()


func step(delta: float) -> void:
	_clear_step_events()
	if delta <= 0.0 or not is_in_flight:
		return
	previous_position_xy = position_xy
	previous_z = z
	if not is_guided_make:
		_step_free_flight_segment(delta)
		return
	var remaining: float = delta
	while remaining > 0.0001 and is_in_flight:
		match flight_phase:
			FLIGHT_PHASE_FREE_FLIGHT:
				var time_to_entry: float = maxf(_get_entry_time() - shot_elapsed, 0.0)
				if time_to_entry > remaining + 0.0001:
					_step_free_flight_segment(remaining)
					shot_elapsed += remaining
					remaining = 0.0
				else:
					if time_to_entry > 0.0001:
						_step_free_flight_segment(time_to_entry)
						shot_elapsed += time_to_entry
						remaining -= time_to_entry
					_enter_make_capture()
			FLIGHT_PHASE_MAKE_CAPTURE:
				_enter_guided_descent()
			FLIGHT_PHASE_GUIDED_DESCENT:
				remaining = _step_guided_descent_phase(remaining)
			FLIGHT_PHASE_NET_EXIT:
				remaining = _step_guided_phase(
					remaining,
					_get_net_exit_xy(),
					_get_net_exit_z(),
					_get_exit_xy(),
					_get_exit_z(),
					_get_net_exit_duration(),
					FLIGHT_PHASE_NONE
				)
			_:
				is_in_flight = false
				flight_phase = FLIGHT_PHASE_NONE
				remaining = 0.0


func predict_trajectory(point_count: int, delta: float) -> Array[Dictionary]:
	var probe: BallSimulator = clone_state()
	var points: Array[Dictionary] = []
	for _index in point_count:
		probe.step(delta)
		points.append({
			"position": probe.position_xy,
			"z": probe.z,
		})
		if not probe.is_in_flight:
			break
	return points


func get_profile_kind() -> String:
	return profile_kind


func get_flight_phase() -> String:
	return flight_phase


func is_guided_make_profile() -> bool:
	return is_guided_make


func has_guided_make_captured() -> bool:
	return guided_make_captured


func has_passed_score_gate() -> bool:
	return passed_score_gate


func did_score_this_step() -> bool:
	return step_score_crossed


func get_step_score_event() -> Dictionary:
	return {
		"scored": step_score_crossed,
		"score_sample_xy": step_score_sample_xy,
		"score_sample_z": step_score_sample_z,
		"score_sample_t": step_score_sample_t,
	}


func get_render_phase_name() -> String:
	match flight_phase:
		FLIGHT_PHASE_MAKE_CAPTURE:
			return "rim_mouth"
		FLIGHT_PHASE_GUIDED_DESCENT:
			return "net_channel"
		FLIGHT_PHASE_NET_EXIT:
			return "front_of_net"
		_:
			return ""


func get_remaining_visual_time() -> float:
	if not is_guided_make or not is_in_flight:
		return 0.0
	match flight_phase:
		FLIGHT_PHASE_FREE_FLIGHT:
			return maxf(_get_entry_time() - shot_elapsed, 0.0) + _get_guided_descent_duration() + _get_net_exit_duration()
		FLIGHT_PHASE_MAKE_CAPTURE:
			return _get_guided_descent_duration() + _get_net_exit_duration()
		FLIGHT_PHASE_GUIDED_DESCENT:
			return maxf(_get_guided_descent_duration() - phase_elapsed, 0.0) + _get_net_exit_duration()
		FLIGHT_PHASE_NET_EXIT:
			return maxf(_get_net_exit_duration() - phase_elapsed, 0.0)
		_:
			return 0.0


func _step_free_flight_segment(delta: float) -> void:
	position_xy += velocity_xy * delta
	vz += gravity * delta
	z += vz * delta
	if z <= 0.0 and vz < 0.0:
		z = 0.0
		vz = 0.0
		is_in_flight = false
		flight_phase = FLIGHT_PHASE_NONE


func _step_guided_phase(
	remaining: float,
	start_xy: Vector2,
	start_z: float,
	end_xy: Vector2,
	end_z: float,
	duration: float,
	next_phase: String
) -> float:
	var safe_duration: float = maxf(duration, 0.0001)
	var time_left: float = maxf(safe_duration - phase_elapsed, 0.0)
	var step_time: float = minf(remaining, time_left)
	var from_ratio: float = clampf(phase_elapsed / safe_duration, 0.0, 1.0)
	var to_ratio: float = clampf((phase_elapsed + step_time) / safe_duration, 0.0, 1.0)
	var current_xy: Vector2 = start_xy.lerp(end_xy, _ease_guided_ratio(from_ratio))
	var current_z: float = lerpf(start_z, end_z, _ease_guided_ratio(from_ratio))
	var next_xy: Vector2 = start_xy.lerp(end_xy, _ease_guided_ratio(to_ratio))
	var next_z: float = lerpf(start_z, end_z, _ease_guided_ratio(to_ratio))
	position_xy = next_xy
	z = next_z
	if step_time > 0.0001:
		velocity_xy = (next_xy - current_xy) / step_time
		vz = (next_z - current_z) / step_time
	phase_elapsed += step_time
	var remaining_after: float = remaining - step_time
	if phase_elapsed >= safe_duration - 0.0001:
		match next_phase:
			FLIGHT_PHASE_GUIDED_DESCENT:
				_enter_guided_descent()
			FLIGHT_PHASE_NET_EXIT:
				_enter_net_exit()
			FLIGHT_PHASE_NONE:
				_finish_guided_make()
			_:
				flight_phase = next_phase
				phase_elapsed = 0.0
	return maxf(remaining_after, 0.0)


func _step_guided_descent_phase(remaining: float) -> float:
	var safe_duration: float = maxf(_get_guided_descent_duration(), 0.0001)
	var time_left: float = maxf(safe_duration - phase_elapsed, 0.0)
	var step_time: float = minf(remaining, time_left)
	var from_ratio: float = clampf(phase_elapsed / safe_duration, 0.0, 1.0)
	var to_ratio: float = clampf((phase_elapsed + step_time) / safe_duration, 0.0, 1.0)
	var current_xy: Vector2 = _get_entry_xy().lerp(_get_net_exit_xy(), from_ratio)
	var current_z: float = lerpf(_get_entry_z(), _get_net_exit_z(), from_ratio)
	var next_xy: Vector2 = _get_entry_xy().lerp(_get_net_exit_xy(), to_ratio)
	var next_z: float = lerpf(_get_entry_z(), _get_net_exit_z(), to_ratio)
	position_xy = next_xy
	z = next_z
	if step_time > 0.0001:
		velocity_xy = (next_xy - current_xy) / step_time
		vz = (next_z - current_z) / step_time
	if not passed_score_gate:
		var gate_progress: float = _get_score_gate_progress()
		if from_ratio < gate_progress and to_ratio >= gate_progress:
			passed_score_gate = true
			step_score_crossed = true
			step_score_sample_xy = _get_score_gate_xy()
			step_score_sample_z = _get_score_gate_z()
			step_score_sample_t = gate_progress
	phase_elapsed += step_time
	var remaining_after: float = remaining - step_time
	if phase_elapsed >= safe_duration - 0.0001:
		_enter_net_exit()
	return maxf(remaining_after, 0.0)


func _enter_make_capture() -> void:
	flight_phase = FLIGHT_PHASE_MAKE_CAPTURE
	guided_make_captured = true
	phase_elapsed = 0.0
	position_xy = _get_entry_xy()
	z = _get_entry_z()
	velocity_xy = Vector2.ZERO
	vz = 0.0


func _enter_guided_descent() -> void:
	flight_phase = FLIGHT_PHASE_GUIDED_DESCENT
	phase_elapsed = 0.0
	position_xy = _get_entry_xy()
	z = _get_entry_z()
	velocity_xy = Vector2.ZERO
	vz = -maxf((_get_entry_z() - _get_net_exit_z()) / maxf(_get_guided_descent_duration(), 0.001), 1.0)


func _enter_net_exit() -> void:
	flight_phase = FLIGHT_PHASE_NET_EXIT
	phase_elapsed = 0.0
	position_xy = _get_net_exit_xy()
	z = _get_net_exit_z()
	velocity_xy = Vector2.ZERO
	vz = -maxf((_get_net_exit_z() - _get_exit_z()) / maxf(_get_net_exit_duration(), 0.001), 1.0)


func _finish_guided_make() -> void:
	position_xy = _get_exit_xy()
	z = _get_exit_z()
	velocity_xy = Vector2.ZERO
	vz = 0.0
	is_in_flight = false
	flight_phase = FLIGHT_PHASE_NONE
	phase_elapsed = 0.0


func _ease_guided_ratio(value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)


func _get_entry_time() -> float:
	return float(shot_profile.get("entry_time", 0.0))


func _get_entry_xy() -> Vector2:
	return shot_profile.get("entry_xy", position_xy)


func _get_entry_z() -> float:
	return float(shot_profile.get("entry_z", z))


func _get_score_gate_xy() -> Vector2:
	return shot_profile.get("score_gate_xy", position_xy)


func _get_score_gate_z() -> float:
	return float(shot_profile.get("score_gate_z", z))


func _get_score_gate_progress() -> float:
	var total_drop: float = maxf(_get_entry_z() - _get_net_exit_z(), 0.001)
	return clampf((_get_entry_z() - _get_score_gate_z()) / total_drop, 0.0, 1.0)


func _get_net_exit_xy() -> Vector2:
	return shot_profile.get("net_exit_xy", position_xy)


func _get_net_exit_z() -> float:
	return float(shot_profile.get("net_exit_z", z))


func _get_exit_xy() -> Vector2:
	return shot_profile.get("exit_xy", _get_net_exit_xy())


func _get_exit_z() -> float:
	return float(shot_profile.get("exit_z", 0.0))


func _get_capture_duration() -> float:
	return maxf(float(shot_profile.get("capture_duration", float(shot_profile.get("descent_duration", 0.2)) * 0.34)), 0.04)


func _get_guided_descent_duration() -> float:
	return maxf(float(shot_profile.get("guided_descent_duration", float(shot_profile.get("descent_duration", 0.2)) * 0.66)), 0.06)


func _get_net_exit_duration() -> float:
	return maxf(float(shot_profile.get("net_exit_duration", 0.08)), 0.04)


func _clear_step_events() -> void:
	step_score_crossed = false
	step_score_sample_xy = Vector2.ZERO
	step_score_sample_z = 0.0
	step_score_sample_t = 0.0
