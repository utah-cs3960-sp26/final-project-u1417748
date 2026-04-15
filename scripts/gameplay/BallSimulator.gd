class_name BallSimulator
extends RefCounted

const PROFILE_KIND_FREE_FLIGHT: String = "free_flight"
const PROFILE_KIND_GUIDED_MAKE: String = "guided_make"

const FLIGHT_PHASE_NONE: String = "none"
const FLIGHT_PHASE_FREE_FLIGHT: String = "free_flight"
const FLIGHT_PHASE_MAKE_CAPTURE: String = "make_capture"
const FLIGHT_PHASE_GUIDED_DESCENT: String = "guided_descent"
const FLIGHT_PHASE_NET_EXIT: String = "net_exit"
const FLIGHT_PHASE_FLOOR_DROP: String = "floor_drop"
const FLIGHT_PHASE_FLOOR_SETTLE: String = "floor_settle"

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
		shot_profile = profile.duplicate(true)
		profile_kind = PROFILE_KIND_FREE_FLIGHT
		return
	var start_phase: String = str(profile.get("start_phase", FLIGHT_PHASE_FREE_FLIGHT))
	if start_phase != FLIGHT_PHASE_FREE_FLIGHT:
		shot_profile = profile.duplicate(true)
		profile_kind = PROFILE_KIND_GUIDED_MAKE
		is_guided_make = true
		guided_make_captured = start_phase != FLIGHT_PHASE_FREE_FLIGHT
		passed_score_gate = false
		_clear_step_events()
		position_xy = profile.get("entry_xy", profile.get("launch_position", Vector2.ZERO))
		previous_position_xy = position_xy
		launch_z = float(profile.get("entry_z", profile.get("launch_z", 0.0)))
		z = launch_z
		previous_z = launch_z
		velocity_xy = Vector2.ZERO
		vz = 0.0
		is_in_flight = true
		already_scored = false
		forced_make = false
		shot_elapsed = float(profile.get("entry_time", 0.0))
		phase_elapsed = 0.0
		match start_phase:
			FLIGHT_PHASE_GUIDED_DESCENT:
				_enter_guided_descent()
			FLIGHT_PHASE_NET_EXIT:
				passed_score_gate = true
				_enter_net_exit()
			FLIGHT_PHASE_FLOOR_DROP:
				passed_score_gate = true
				_enter_floor_drop()
			FLIGHT_PHASE_FLOOR_SETTLE:
				passed_score_gate = true
				_enter_floor_settle()
			_:
				flight_phase = FLIGHT_PHASE_FREE_FLIGHT
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
				remaining = _step_net_exit_phase(remaining)
			FLIGHT_PHASE_FLOOR_DROP:
				remaining = _step_floor_drop_phase(remaining)
			FLIGHT_PHASE_FLOOR_SETTLE:
				remaining = _step_floor_settle_phase(remaining)
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


func get_terminal_visual_drop_weight() -> float:
	if not is_guided_make or not is_in_flight:
		return 0.0
	match flight_phase:
		FLIGHT_PHASE_FREE_FLIGHT:
			var entry_time: float = maxf(_get_entry_time(), 0.0001)
			var approach_ratio: float = clampf(shot_elapsed / entry_time, 0.0, 1.0)
			return clampf((approach_ratio - 0.8) / 0.2, 0.0, 1.0)
		FLIGHT_PHASE_MAKE_CAPTURE, FLIGHT_PHASE_GUIDED_DESCENT, FLIGHT_PHASE_NET_EXIT:
			return 1.0
		FLIGHT_PHASE_FLOOR_DROP:
			var floor_duration: float = maxf(_get_floor_drop_duration(), 0.0001)
			var floor_progress: float = clampf(phase_elapsed / floor_duration, 0.0, 1.0)
			return 1.0 - _ease_guided_ratio(floor_progress)
		_:
			return 0.0


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
			return maxf(_get_entry_time() - shot_elapsed, 0.0) + _get_guided_descent_duration() + _get_net_exit_duration() + _get_floor_finish_duration()
		FLIGHT_PHASE_MAKE_CAPTURE:
			return _get_guided_descent_duration() + _get_net_exit_duration() + _get_floor_finish_duration()
		FLIGHT_PHASE_GUIDED_DESCENT:
			return maxf(_get_guided_descent_duration() - phase_elapsed, 0.0) + _get_net_exit_duration() + _get_floor_finish_duration()
		FLIGHT_PHASE_NET_EXIT:
			return maxf(_get_net_exit_duration() - phase_elapsed, 0.0) + _get_floor_finish_duration()
		FLIGHT_PHASE_FLOOR_DROP:
			return maxf(_get_floor_drop_duration() - phase_elapsed, 0.0) + _get_floor_settle_duration()
		FLIGHT_PHASE_FLOOR_SETTLE:
			return maxf(_get_floor_settle_duration() - phase_elapsed, 0.0)
		_:
			return 0.0


func _step_free_flight_segment(delta: float) -> void:
	position_xy += velocity_xy * delta
	z += vz * delta + 0.5 * gravity * delta * delta
	vz += gravity * delta
	if z <= 0.0 and vz < 0.0:
		z = 0.0
		vz = 0.0
		is_in_flight = false
		flight_phase = FLIGHT_PHASE_NONE


func _step_guided_hermite_phase(
	remaining: float,
	start_xy: Vector2,
	start_z: float,
	end_xy: Vector2,
	end_z: float,
	start_velocity_xy: Vector2,
	start_vz: float,
	end_velocity_xy: Vector2,
	end_vz: float,
	duration: float,
	next_phase: String,
	record_score_gate: bool = false
) -> float:
	var safe_duration: float = maxf(duration, 0.0001)
	var time_left: float = maxf(safe_duration - phase_elapsed, 0.0)
	var step_time: float = minf(remaining, time_left)
	var from_time: float = phase_elapsed
	var to_time: float = clampf(phase_elapsed + step_time, 0.0, safe_duration)
	var current_sample: Dictionary = _sample_guided_hermite_motion(
		start_xy,
		start_z,
		start_velocity_xy,
		start_vz,
		end_xy,
		end_z,
		end_velocity_xy,
		end_vz,
		safe_duration,
		from_time
	)
	var next_sample: Dictionary = _sample_guided_hermite_motion(
		start_xy,
		start_z,
		start_velocity_xy,
		start_vz,
		end_xy,
		end_z,
		end_velocity_xy,
		end_vz,
		safe_duration,
		to_time
	)
	position_xy = next_sample.get("position_xy", end_xy)
	z = next_sample.get("z", end_z)
	velocity_xy = next_sample.get("velocity_xy", Vector2.ZERO)
	vz = float(next_sample.get("vz", 0.0))
	if record_score_gate and not passed_score_gate:
		var current_z: float = float(current_sample.get("z", start_z))
		var next_z: float = float(next_sample.get("z", end_z))
		var gate_z: float = _get_score_gate_z()
		if current_z >= gate_z and next_z <= gate_z:
			var gate_alpha: float = clampf((current_z - gate_z) / maxf(current_z - next_z, 0.001), 0.0, 1.0)
			var gate_start_xy: Vector2 = current_sample.get("position_xy", start_xy)
			var gate_end_xy: Vector2 = next_sample.get("position_xy", end_xy)
			passed_score_gate = true
			step_score_crossed = true
			step_score_sample_xy = gate_start_xy.lerp(gate_end_xy, gate_alpha)
			step_score_sample_z = gate_z
			step_score_sample_t = lerpf(from_time / safe_duration, to_time / safe_duration, gate_alpha)
	phase_elapsed += step_time
	var remaining_after: float = remaining - step_time
	if phase_elapsed >= safe_duration - 0.0001:
		match next_phase:
			FLIGHT_PHASE_GUIDED_DESCENT:
				_enter_guided_descent()
			FLIGHT_PHASE_NET_EXIT:
				_enter_net_exit()
			FLIGHT_PHASE_FLOOR_DROP:
				_store_floor_drop_start_state()
				flight_phase = FLIGHT_PHASE_FLOOR_DROP
				phase_elapsed = 0.0
			FLIGHT_PHASE_NONE:
				_finish_guided_make()
			_:
				flight_phase = next_phase
				phase_elapsed = 0.0
	return maxf(remaining_after, 0.0)


func _step_net_exit_phase(remaining: float) -> float:
	return _step_guided_hermite_phase(
		remaining,
		_get_net_exit_xy(),
		_get_net_exit_z(),
		_get_exit_xy(),
		_get_exit_z(),
		_get_net_exit_start_velocity_xy(),
		_get_net_exit_start_vz(),
		_get_net_exit_end_velocity_xy(),
		_get_net_exit_end_vz(),
		_get_net_exit_duration(),
		FLIGHT_PHASE_FLOOR_DROP if _has_floor_finish() else FLIGHT_PHASE_NONE,
		false
	)


func _sample_guided_hermite_motion(
	start_xy: Vector2,
	start_z: float,
	start_velocity_xy: Vector2,
	start_vz: float,
	end_xy: Vector2,
	end_z: float,
	end_velocity_xy: Vector2,
	end_vz: float,
	duration: float,
	time_value: float
) -> Dictionary:
	var safe_duration: float = maxf(duration, 0.0001)
	var u: float = clampf(time_value / safe_duration, 0.0, 1.0)
	return {
		"position_xy": _sample_hermite_vector2(start_xy, end_xy, start_velocity_xy, end_velocity_xy, safe_duration, u),
		"velocity_xy": _sample_hermite_velocity_vector2(start_xy, end_xy, start_velocity_xy, end_velocity_xy, safe_duration, u),
		"z": _sample_hermite_float(start_z, end_z, start_vz, end_vz, safe_duration, u),
		"vz": _sample_hermite_velocity_float(start_z, end_z, start_vz, end_vz, safe_duration, u),
	}


func _sample_hermite_vector2(start_value: Vector2, end_value: Vector2, start_velocity: Vector2, end_velocity: Vector2, duration: float, u: float) -> Vector2:
	var clamped_u: float = clampf(u, 0.0, 1.0)
	var u2: float = clamped_u * clamped_u
	var u3: float = u2 * clamped_u
	var tangent_start: Vector2 = start_velocity * duration
	var tangent_end: Vector2 = end_velocity * duration
	return (
		(2.0 * u3 - 3.0 * u2 + 1.0) * start_value
		+ (u3 - 2.0 * u2 + clamped_u) * tangent_start
		+ (-2.0 * u3 + 3.0 * u2) * end_value
		+ (u3 - u2) * tangent_end
	)


func _sample_hermite_velocity_vector2(start_value: Vector2, end_value: Vector2, start_velocity: Vector2, end_velocity: Vector2, duration: float, u: float) -> Vector2:
	var safe_duration: float = maxf(duration, 0.0001)
	var clamped_u: float = clampf(u, 0.0, 1.0)
	var u2: float = clamped_u * clamped_u
	var tangent_start: Vector2 = start_velocity * safe_duration
	var tangent_end: Vector2 = end_velocity * safe_duration
	var derivative: Vector2 = (
		(6.0 * u2 - 6.0 * clamped_u) * start_value
		+ (3.0 * u2 - 4.0 * clamped_u + 1.0) * tangent_start
		+ (-6.0 * u2 + 6.0 * clamped_u) * end_value
		+ (3.0 * u2 - 2.0 * clamped_u) * tangent_end
	)
	return derivative / safe_duration


func _sample_hermite_float(start_value: float, end_value: float, start_velocity: float, end_velocity: float, duration: float, u: float) -> float:
	var clamped_u: float = clampf(u, 0.0, 1.0)
	var u2: float = clamped_u * clamped_u
	var u3: float = u2 * clamped_u
	var tangent_start: float = start_velocity * duration
	var tangent_end: float = end_velocity * duration
	return (
		(2.0 * u3 - 3.0 * u2 + 1.0) * start_value
		+ (u3 - 2.0 * u2 + clamped_u) * tangent_start
		+ (-2.0 * u3 + 3.0 * u2) * end_value
		+ (u3 - u2) * tangent_end
	)


func _sample_hermite_velocity_float(start_value: float, end_value: float, start_velocity: float, end_velocity: float, duration: float, u: float) -> float:
	var safe_duration: float = maxf(duration, 0.0001)
	var clamped_u: float = clampf(u, 0.0, 1.0)
	var u2: float = clamped_u * clamped_u
	var tangent_start: float = start_velocity * safe_duration
	var tangent_end: float = end_velocity * safe_duration
	var derivative: float = (
		(6.0 * u2 - 6.0 * clamped_u) * start_value
		+ (3.0 * u2 - 4.0 * clamped_u + 1.0) * tangent_start
		+ (-6.0 * u2 + 6.0 * clamped_u) * end_value
		+ (3.0 * u2 - 2.0 * clamped_u) * tangent_end
	)
	return derivative / safe_duration


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
				if next_phase == FLIGHT_PHASE_FLOOR_DROP:
					_store_floor_drop_start_state()
				flight_phase = next_phase
				phase_elapsed = 0.0
	return maxf(remaining_after, 0.0)


func _step_guided_descent_phase(remaining: float) -> float:
	return _step_guided_hermite_phase(
		remaining,
		_get_entry_xy(),
		_get_entry_z(),
		_get_net_exit_xy(),
		_get_net_exit_z(),
		_get_guided_entry_velocity_xy(),
		_get_guided_entry_vz(),
		_get_guided_descent_end_velocity_xy(),
		_get_guided_descent_end_vz(),
		_get_guided_descent_duration(),
		FLIGHT_PHASE_NET_EXIT,
		true
	)


func _enter_make_capture() -> void:
	flight_phase = FLIGHT_PHASE_MAKE_CAPTURE
	guided_make_captured = true
	phase_elapsed = 0.0
	position_xy = _get_entry_xy()
	z = _get_entry_z()
	velocity_xy = _get_guided_entry_velocity_xy()
	vz = _get_guided_entry_vz()


func _enter_guided_descent() -> void:
	flight_phase = FLIGHT_PHASE_GUIDED_DESCENT
	phase_elapsed = 0.0
	position_xy = _get_entry_xy()
	z = _get_entry_z()
	velocity_xy = _get_guided_entry_velocity_xy()
	vz = _get_guided_entry_vz()


func _enter_net_exit() -> void:
	flight_phase = FLIGHT_PHASE_NET_EXIT
	phase_elapsed = 0.0
	position_xy = _get_net_exit_xy()
	z = _get_net_exit_z()
	velocity_xy = _get_net_exit_start_velocity_xy()
	vz = _get_net_exit_start_vz()


func _enter_floor_drop() -> void:
	if not _has_floor_finish():
		_finish_guided_make()
		return
	flight_phase = FLIGHT_PHASE_FLOOR_DROP
	phase_elapsed = 0.0
	position_xy = _get_exit_xy()
	z = _get_exit_z()
	velocity_xy = _get_floor_drop_start_velocity_xy()
	vz = _get_floor_drop_start_vz()
	_store_floor_drop_start_state()
	if _get_floor_drop_duration() <= 0.0001:
		position_xy = _get_floor_target_xy()
		z = 0.0
		if _should_run_floor_settle():
			_enter_floor_settle()
		else:
			_finish_guided_make()
		return


func _enter_floor_settle() -> void:
	if not _should_run_floor_settle():
		_finish_guided_make()
		return
	flight_phase = FLIGHT_PHASE_FLOOR_SETTLE
	phase_elapsed = 0.0
	position_xy = _get_floor_target_xy()
	z = 0.0
	velocity_xy = Vector2.ZERO
	vz = 0.0


func _finish_guided_make() -> void:
	position_xy = _get_terminal_xy()
	z = _get_terminal_z()
	velocity_xy = Vector2.ZERO
	vz = 0.0
	is_in_flight = false
	flight_phase = FLIGHT_PHASE_NONE
	phase_elapsed = 0.0


func _ease_guided_ratio(value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)


func _get_guided_entry_velocity_xy() -> Vector2:
	if shot_profile.has("guided_entry_velocity_xy"):
		return shot_profile.get("guided_entry_velocity_xy", Vector2.ZERO)
	return shot_profile.get("approach_velocity_xy", velocity_xy)


func _get_guided_entry_vz() -> float:
	if shot_profile.has("guided_entry_vz"):
		return float(shot_profile.get("guided_entry_vz", 0.0))
	if shot_profile.has("approach_vz"):
		return float(shot_profile.get("approach_vz", 0.0)) + gravity * _get_entry_time()
	return vz


func _get_guided_descent_end_velocity_xy() -> Vector2:
	if shot_profile.has("guided_descent_end_velocity_xy"):
		return shot_profile.get("guided_descent_end_velocity_xy", Vector2.ZERO)
	return (_get_exit_xy() - _get_net_exit_xy()) / maxf(_get_net_exit_duration(), 0.001)


func _get_guided_descent_end_vz() -> float:
	if shot_profile.has("guided_descent_end_vz"):
		return float(shot_profile.get("guided_descent_end_vz", 0.0))
	return (_get_exit_z() - _get_net_exit_z()) / maxf(_get_net_exit_duration(), 0.001)


func _get_net_exit_start_velocity_xy() -> Vector2:
	if shot_profile.has("net_exit_start_velocity_xy"):
		return shot_profile.get("net_exit_start_velocity_xy", Vector2.ZERO)
	return _get_guided_descent_end_velocity_xy()


func _get_net_exit_start_vz() -> float:
	if shot_profile.has("net_exit_start_vz"):
		return float(shot_profile.get("net_exit_start_vz", 0.0))
	return _get_guided_descent_end_vz()


func _get_net_exit_end_velocity_xy() -> Vector2:
	if shot_profile.has("net_exit_end_velocity_xy"):
		return shot_profile.get("net_exit_end_velocity_xy", Vector2.ZERO)
	if _has_floor_finish() and _get_floor_drop_duration() > 0.0:
		return (_get_floor_target_xy() - _get_exit_xy()) / maxf(_get_floor_drop_duration(), 0.001) * 0.5
	return Vector2.ZERO


func _get_net_exit_end_vz() -> float:
	if shot_profile.has("net_exit_end_vz"):
		return float(shot_profile.get("net_exit_end_vz", 0.0))
	if _has_floor_finish() and _get_floor_drop_duration() > 0.0:
		return minf((0.0 - _get_exit_z()) / maxf(_get_floor_drop_duration(), 0.001) * 0.5, -1.0)
	return -maxf(_get_exit_z() / maxf(_get_net_exit_duration(), 0.001), 1.0)


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


func _step_floor_drop_phase(remaining: float) -> float:
	var safe_duration: float = maxf(_get_floor_drop_duration(), 0.0001)
	var time_left: float = maxf(safe_duration - phase_elapsed, 0.0)
	var step_time: float = minf(remaining, time_left)
	var from_time: float = phase_elapsed
	var to_time: float = clampf(phase_elapsed + step_time, 0.0, safe_duration)
	var start_xy: Vector2 = _get_floor_drop_start_xy()
	var start_z: float = _get_floor_drop_start_z()
	var start_velocity_xy: Vector2 = _get_floor_drop_start_velocity_xy()
	var start_vz: float = _get_floor_drop_start_vz()
	var current_sample: Dictionary = _sample_floor_drop_motion(start_xy, start_z, start_velocity_xy, start_vz, safe_duration, from_time)
	var next_sample: Dictionary = _sample_floor_drop_motion(start_xy, start_z, start_velocity_xy, start_vz, safe_duration, to_time)
	position_xy = next_sample.get("position_xy", _get_floor_target_xy())
	z = maxf(float(next_sample.get("z", 0.0)), 0.0)
	velocity_xy = next_sample.get("velocity_xy", Vector2.ZERO)
	vz = float(next_sample.get("vz", 0.0))
	if step_time > 0.0001 and to_time <= safe_duration - 0.0001:
		var current_xy: Vector2 = current_sample.get("position_xy", start_xy)
		var current_z: float = float(current_sample.get("z", start_z))
		velocity_xy = (position_xy - current_xy) / step_time
		vz = (z - current_z) / step_time
	phase_elapsed += step_time
	var remaining_after: float = remaining - step_time
	if phase_elapsed >= safe_duration - 0.0001:
		position_xy = _get_floor_target_xy()
		z = 0.0
		if _should_run_floor_settle():
			_enter_floor_settle()
		else:
			_finish_guided_make()
	return maxf(remaining_after, 0.0)


func _step_floor_settle_phase(remaining: float) -> float:
	var safe_duration: float = maxf(_get_floor_settle_duration(), 0.0001)
	var time_left: float = maxf(safe_duration - phase_elapsed, 0.0)
	var step_time: float = minf(remaining, time_left)
	var from_ratio: float = clampf(phase_elapsed / safe_duration, 0.0, 1.0)
	var to_ratio: float = clampf((phase_elapsed + step_time) / safe_duration, 0.0, 1.0)
	var current_z: float = _get_floor_settle_hop_z(from_ratio)
	var next_z: float = _get_floor_settle_hop_z(to_ratio)
	position_xy = _get_floor_target_xy()
	z = next_z
	if step_time > 0.0001:
		velocity_xy = Vector2.ZERO
		vz = (next_z - current_z) / step_time
	phase_elapsed += step_time
	var remaining_after: float = remaining - step_time
	if phase_elapsed >= safe_duration - 0.0001:
		_finish_guided_make()
	return maxf(remaining_after, 0.0)


func _get_floor_target_xy() -> Vector2:
	return shot_profile.get("floor_target_xy", _get_exit_xy())


func _get_floor_drop_start_xy() -> Vector2:
	return shot_profile.get("floor_drop_start_xy", _get_exit_xy())


func _get_floor_drop_start_z() -> float:
	return float(shot_profile.get("floor_drop_start_z", _get_exit_z()))


func _get_floor_drop_start_velocity_xy() -> Vector2:
	return shot_profile.get("floor_drop_start_velocity_xy", Vector2.ZERO)


func _get_floor_drop_start_vz() -> float:
	var fallback_duration: float = maxf(_get_floor_drop_duration(), 0.001)
	return float(shot_profile.get("floor_drop_start_vz", -maxf(_get_exit_z() / fallback_duration, 1.0)))


func _get_floor_drop_duration() -> float:
	return maxf(float(shot_profile.get("floor_drop_duration", 0.0)), 0.0)


func _get_floor_settle_hop_height() -> float:
	return maxf(float(shot_profile.get("floor_settle_hop_height", 0.0)), 0.0)


func _get_floor_settle_duration() -> float:
	return maxf(float(shot_profile.get("floor_settle_duration", 0.0)), 0.0)


func _has_floor_finish() -> bool:
	return shot_profile.has("floor_target_xy") and (_get_floor_drop_duration() > 0.0 or _should_run_floor_settle())


func _should_run_floor_settle() -> bool:
	return _get_floor_settle_duration() > 0.0 and _get_floor_settle_hop_height() > 0.0


func _get_floor_finish_duration() -> float:
	return _get_floor_drop_duration() + _get_floor_settle_duration()


func _get_terminal_xy() -> Vector2:
	return _get_floor_target_xy() if _has_floor_finish() else _get_exit_xy()


func _get_terminal_z() -> float:
	return 0.0 if _has_floor_finish() else _get_exit_z()


func _get_floor_settle_hop_z(progress: float) -> float:
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	return 4.0 * _get_floor_settle_hop_height() * clamped_progress * (1.0 - clamped_progress)


func _store_floor_drop_start_state() -> void:
	shot_profile["floor_drop_start_xy"] = position_xy
	shot_profile["floor_drop_start_z"] = z
	shot_profile["floor_drop_start_velocity_xy"] = velocity_xy
	shot_profile["floor_drop_start_vz"] = vz


func _sample_floor_drop_motion(
	start_xy: Vector2,
	start_z: float,
	start_velocity_xy: Vector2,
	start_vz: float,
	duration: float,
	time_value: float
) -> Dictionary:
	var safe_duration: float = maxf(duration, 0.0001)
	var clamped_time: float = clampf(time_value, 0.0, safe_duration)
	var target_xy: Vector2 = _get_floor_target_xy()
	var resolved_start_velocity_xy := Vector2(
		_clamp_floor_drop_start_velocity_component(target_xy.x - start_xy.x, start_velocity_xy.x, safe_duration),
		_clamp_floor_drop_start_velocity_component(target_xy.y - start_xy.y, start_velocity_xy.y, safe_duration)
	)
	var resolved_start_vz: float = _clamp_floor_drop_start_velocity_component(0.0 - start_z, start_vz, safe_duration)
	var acceleration_xy: Vector2 = _solve_floor_drop_acceleration_vector2(start_xy, target_xy, resolved_start_velocity_xy, safe_duration)
	var acceleration_z: float = _solve_floor_drop_acceleration_float(start_z, 0.0, resolved_start_vz, safe_duration)
	return {
		"position_xy": _sample_floor_drop_constant_acceleration_vector2(start_xy, resolved_start_velocity_xy, acceleration_xy, clamped_time),
		"velocity_xy": _sample_floor_drop_constant_acceleration_velocity_vector2(resolved_start_velocity_xy, acceleration_xy, clamped_time),
		"z": _sample_floor_drop_constant_acceleration_float(start_z, resolved_start_vz, acceleration_z, clamped_time),
		"vz": _sample_floor_drop_constant_acceleration_velocity_float(resolved_start_vz, acceleration_z, clamped_time),
	}


func _clamp_floor_drop_start_velocity_component(distance: float, speed: float, duration: float) -> float:
	if absf(distance) <= 0.001:
		return 0.0
	var safe_duration: float = maxf(duration, 0.0001)
	var max_speed: float = (2.0 * absf(distance)) / safe_duration
	return clampf(speed, -max_speed, max_speed)


func _solve_floor_drop_acceleration_vector2(start_value: Vector2, end_value: Vector2, start_velocity: Vector2, duration: float) -> Vector2:
	var safe_duration: float = maxf(duration, 0.0001)
	return 2.0 * (end_value - start_value - start_velocity * safe_duration) / (safe_duration * safe_duration)


func _solve_floor_drop_acceleration_float(start_value: float, end_value: float, start_velocity: float, duration: float) -> float:
	var safe_duration: float = maxf(duration, 0.0001)
	return (2.0 * (end_value - start_value - start_velocity * safe_duration)) / (safe_duration * safe_duration)


func _sample_floor_drop_constant_acceleration_vector2(start_value: Vector2, start_velocity: Vector2, acceleration: Vector2, time_value: float) -> Vector2:
	return start_value + start_velocity * time_value + 0.5 * acceleration * time_value * time_value


func _sample_floor_drop_constant_acceleration_velocity_vector2(start_velocity: Vector2, acceleration: Vector2, time_value: float) -> Vector2:
	return start_velocity + acceleration * time_value


func _sample_floor_drop_constant_acceleration_float(start_value: float, start_velocity: float, acceleration: float, time_value: float) -> float:
	return start_value + start_velocity * time_value + 0.5 * acceleration * time_value * time_value


func _sample_floor_drop_constant_acceleration_velocity_float(start_velocity: float, acceleration: float, time_value: float) -> float:
	return start_velocity + acceleration * time_value


func _clear_step_events() -> void:
	step_score_crossed = false
	step_score_sample_xy = Vector2.ZERO
	step_score_sample_z = 0.0
	step_score_sample_t = 0.0
