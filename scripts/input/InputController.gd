class_name InputController
extends Node

signal movement_zone_started(anchor_screen: Vector2, anchor_world: Vector2)
signal movement_zone_ended(release_screen: Vector2, release_world: Vector2, elapsed: float, reason: String)
signal movement_updated(direction: Vector2, magnitude: float)
signal pass_preview_changed(target: PlayerController, details: Dictionary)
signal pass_requested(target: PlayerController, details: Dictionary)
signal shot_mode_requested(details: Dictionary)
signal shot_timing_tapped(screen_position: Vector2)
signal pause_requested()

enum InteractionMode {
	DISABLED,
	LIVE_OFFENSE,
	SHOT_TIMING,
}

var input_config
var projection: CourtProjection
var ballhandler: PlayerController
var offense_players: Array[PlayerController] = []
var interaction_mode: int = InteractionMode.DISABLED
var allow_keyboard_debug: bool = true
var allow_mouse_emulation: bool = true

var gameplay_touch_index: int = -1
var gesture_anchor_screen: Vector2 = Vector2.ZERO
var gesture_current_screen: Vector2 = Vector2.ZERO
var gesture_anchor_world: Vector2 = Vector2.ZERO
var gesture_current_world: Vector2 = Vector2.ZERO
var gesture_start_time: float = 0.0
var gesture_last_sample_time: float = 0.0
var gesture_release_speed: float = 0.0
var gesture_preview_target: PlayerController
var gesture_preview_details: Dictionary = {}
var timing_tap_consumed: bool = false


func _ready() -> void:
	set_process_input(true)
	set_process(true)


func setup(
	config_value,
	projection_value: CourtProjection = null,
	keyboard_debug_enabled: bool = true,
	mouse_emulation_enabled: bool = true
) -> void:
	input_config = config_value
	projection = projection_value
	allow_keyboard_debug = keyboard_debug_enabled
	allow_mouse_emulation = mouse_emulation_enabled


func set_projection(projection_value: CourtProjection) -> void:
	projection = projection_value


func set_ballhandler(player: PlayerController) -> void:
	ballhandler = player
	_refresh_pass_preview()


func set_offense_players(players: Array[PlayerController]) -> void:
	offense_players = players
	_refresh_pass_preview()


func set_interaction_mode(mode_value: int) -> void:
	if interaction_mode == mode_value:
		return
	if interaction_mode == InteractionMode.LIVE_OFFENSE and mode_value != InteractionMode.LIVE_OFFENSE:
		_cancel_live_gesture("mode_change")
	interaction_mode = mode_value
	if interaction_mode != InteractionMode.LIVE_OFFENSE:
		movement_updated.emit(Vector2.ZERO, 0.0)
	if interaction_mode != InteractionMode.SHOT_TIMING:
		timing_tap_consumed = false


func _process(_delta: float) -> void:
	if interaction_mode != InteractionMode.LIVE_OFFENSE:
		return
	if gameplay_touch_index != -1:
		return
	if not allow_keyboard_debug:
		return
	var keyboard_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if keyboard_vector.length() > 0.0:
		var normalized: Vector2 = keyboard_vector.normalized()
		movement_updated.emit(normalized, clampf(keyboard_vector.length(), 0.0, 1.0))
	else:
		movement_updated.emit(Vector2.ZERO, 0.0)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		pause_requested.emit()
		return
	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if interaction_mode == InteractionMode.SHOT_TIMING:
		if event.pressed and not timing_tap_consumed:
			timing_tap_consumed = true
			shot_timing_tapped.emit(event.position)
		return
	if interaction_mode != InteractionMode.LIVE_OFFENSE:
		return
	if event.pressed:
		if gameplay_touch_index != -1 or not _is_in_movement_zone(event.position):
			return
		_begin_live_gesture(event.index, event.position)
		return
	if event.index != gameplay_touch_index:
		return
	_finish_live_gesture(event.position)


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if interaction_mode != InteractionMode.LIVE_OFFENSE or event.index != gameplay_touch_index:
		return
	_update_live_gesture(event.position)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT or not allow_mouse_emulation:
		return
	if interaction_mode == InteractionMode.SHOT_TIMING:
		if event.pressed and not timing_tap_consumed:
			timing_tap_consumed = true
			shot_timing_tapped.emit(event.position)
		return
	if interaction_mode != InteractionMode.LIVE_OFFENSE:
		return
	if event.pressed:
		if gameplay_touch_index != -1 or not _is_in_movement_zone(event.position):
			return
		_begin_live_gesture(-2, event.position)
		return
	if gameplay_touch_index == -2:
		_finish_live_gesture(event.position)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if interaction_mode != InteractionMode.LIVE_OFFENSE or gameplay_touch_index != -2 or not allow_mouse_emulation:
		return
	_update_live_gesture(event.position)


func _begin_live_gesture(pointer_index: int, screen_position: Vector2) -> void:
	gameplay_touch_index = pointer_index
	gesture_anchor_screen = screen_position
	gesture_current_screen = screen_position
	gesture_anchor_world = _screen_to_world_ground(screen_position)
	gesture_current_world = gesture_anchor_world
	gesture_start_time = _now_seconds()
	gesture_last_sample_time = gesture_start_time
	gesture_release_speed = 0.0
	_clear_pass_preview()
	movement_updated.emit(Vector2.ZERO, 0.0)
	movement_zone_started.emit(gesture_anchor_screen, gesture_anchor_world)


func _update_live_gesture(screen_position: Vector2) -> void:
	var previous_screen: Vector2 = gesture_current_screen
	var now_seconds: float = _now_seconds()
	var dt: float = maxf(now_seconds - gesture_last_sample_time, 0.0001)
	var segment_speed: float = screen_position.distance_to(previous_screen) / dt
	gesture_current_screen = screen_position
	gesture_current_world = _screen_to_world_ground(screen_position)
	gesture_last_sample_time = now_seconds
	gesture_release_speed = segment_speed
	var movement_snapshot: Dictionary = compute_movement_snapshot(gesture_anchor_screen, screen_position)
	movement_updated.emit(movement_snapshot["direction"], movement_snapshot["magnitude"])
	_refresh_pass_preview()


func _finish_live_gesture(release_screen: Vector2) -> void:
	if gameplay_touch_index == -1:
		return
	gesture_current_screen = release_screen
	gesture_current_world = _screen_to_world_ground(release_screen)
	var elapsed: float = maxf(_now_seconds() - gesture_start_time, 0.0)
	var release_world: Vector2 = gesture_current_world
	var movement_snapshot: Dictionary = compute_movement_snapshot(gesture_anchor_screen, release_screen)
	var flick_distance: float = float(movement_snapshot["distance"])
	var release_details: Dictionary = {
		"anchor_screen": gesture_anchor_screen,
		"release_screen": release_screen,
		"anchor_world": gesture_anchor_world,
		"release_world": release_world,
		"elapsed": elapsed,
		"flick_distance": flick_distance,
		"release_speed": gesture_release_speed,
		"direction": movement_snapshot["direction"],
		"pass_target": gesture_preview_target,
		"pass_target_role": gesture_preview_target.get_position_role() if gesture_preview_target != null else "",
		"pass_angle_error_rad": float(gesture_preview_details.get("angle_error_rad", 0.0)),
		"pass_distance": float(gesture_preview_details.get("distance", 0.0)),
	}
	movement_updated.emit(Vector2.ZERO, 0.0)
	if gesture_preview_target != null and qualifies_as_pass_flick(flick_distance, gesture_release_speed):
		movement_zone_ended.emit(release_screen, release_world, elapsed, "pass")
		pass_requested.emit(gesture_preview_target, release_details)
	else:
		movement_zone_ended.emit(release_screen, release_world, elapsed, "shot_arm")
		shot_mode_requested.emit(release_details)
	_clear_live_gesture_state()


func _cancel_live_gesture(reason: String) -> void:
	if gameplay_touch_index == -1:
		return
	var release_screen: Vector2 = gesture_current_screen
	var release_world: Vector2 = gesture_current_world
	var elapsed: float = maxf(_now_seconds() - gesture_start_time, 0.0)
	movement_updated.emit(Vector2.ZERO, 0.0)
	movement_zone_ended.emit(release_screen, release_world, elapsed, reason)
	_clear_live_gesture_state()


func _clear_live_gesture_state() -> void:
	gameplay_touch_index = -1
	gesture_anchor_screen = Vector2.ZERO
	gesture_current_screen = Vector2.ZERO
	gesture_anchor_world = Vector2.ZERO
	gesture_current_world = Vector2.ZERO
	gesture_start_time = 0.0
	gesture_last_sample_time = 0.0
	gesture_release_speed = 0.0
	_clear_pass_preview()


func _refresh_pass_preview() -> void:
	if gameplay_touch_index == -1 or ballhandler == null:
		_clear_pass_preview()
		return
	var gesture_vector: Vector2 = gesture_current_screen - gesture_anchor_screen
	var candidate: Dictionary = select_pass_preview_candidate(_build_pass_preview_candidates(), gesture_vector)
	var next_target: PlayerController = candidate.get("player", null) as PlayerController
	var next_angle_error: float = float(candidate.get("angle_error_rad", -1.0))
	var current_angle_error: float = float(gesture_preview_details.get("angle_error_rad", -1.0))
	if next_target == gesture_preview_target and absf(next_angle_error - current_angle_error) <= 0.0001:
		return
	gesture_preview_target = next_target
	gesture_preview_details = candidate
	pass_preview_changed.emit(gesture_preview_target, gesture_preview_details.duplicate(true))


func _clear_pass_preview() -> void:
	if gesture_preview_target == null and gesture_preview_details.is_empty():
		return
	gesture_preview_target = null
	gesture_preview_details.clear()
	pass_preview_changed.emit(null, {})


func get_touch_feedback_snapshot() -> Dictionary:
	return {
		"anchor_visible": gameplay_touch_index != -1 and interaction_mode == InteractionMode.LIVE_OFFENSE,
		"anchor_screen": gesture_anchor_screen,
		"current_screen": gesture_current_screen,
		"anchor_radius": input_config.anchor_visual_radius if input_config != null else 54.0,
		"knob_radius": input_config.anchor_knob_radius if input_config != null else 28.0,
		"anchor_alpha": input_config.anchor_visual_alpha if input_config != null else 0.2,
	}


func begin_test_live_gesture(screen_position: Vector2, pointer_index: int = -99) -> void:
	if interaction_mode != InteractionMode.LIVE_OFFENSE or gameplay_touch_index != -1:
		return
	_begin_live_gesture(pointer_index, screen_position)


func update_test_live_gesture(screen_position: Vector2) -> void:
	if interaction_mode != InteractionMode.LIVE_OFFENSE or gameplay_touch_index == -1:
		return
	_update_live_gesture(screen_position)


func end_test_live_gesture(screen_position: Vector2) -> void:
	if interaction_mode != InteractionMode.LIVE_OFFENSE or gameplay_touch_index == -1:
		return
	_finish_live_gesture(screen_position)


func tap_test_shot_timing(screen_position: Vector2 = Vector2.ZERO) -> void:
	if interaction_mode != InteractionMode.SHOT_TIMING or timing_tap_consumed:
		return
	timing_tap_consumed = true
	shot_timing_tapped.emit(screen_position)


func compute_movement_snapshot(anchor_screen: Vector2, current_screen: Vector2) -> Dictionary:
	var offset: Vector2 = current_screen - anchor_screen
	var distance_value: float = offset.length()
	var deadzone_value: float = input_config.deadzone if input_config != null else 22.0
	if distance_value <= deadzone_value:
		return {
			"direction": Vector2.ZERO,
			"magnitude": 0.0,
			"distance": distance_value,
		}
	var max_radius: float = input_config.invisible_stick_max_radius if input_config != null else 120.0
	var clamped: Vector2 = offset.limit_length(max_radius)
	return {
		"direction": clamped.normalized(),
		"magnitude": clampf((distance_value - deadzone_value) / maxf(max_radius - deadzone_value, 1.0), 0.0, 1.0),
		"distance": distance_value,
	}


func qualifies_as_pass_flick(flick_distance: float, release_speed: float) -> bool:
	if input_config == null:
		return flick_distance >= 92.0 and release_speed >= 920.0
	return flick_distance >= input_config.flick_min_distance and release_speed >= input_config.flick_min_release_speed


func select_pass_preview_candidate(candidates: Array[Dictionary], gesture_vector: Vector2) -> Dictionary:
	if input_config == null or gesture_vector.length() < input_config.pass_preview_min_vector_length:
		return {}
	var best_candidate: Dictionary = {}
	var best_angle_error: float = INF
	var best_distance: float = INF
	var gesture_direction: Vector2 = gesture_vector.normalized()
	var cone_limit_radians: float = deg_to_rad(input_config.pass_preview_cone_half_angle_degrees)
	for candidate in candidates:
		var to_candidate: Vector2 = candidate.get("direction_vector", Vector2.ZERO)
		if to_candidate.length_squared() <= 0.001:
			continue
		var candidate_direction: Vector2 = to_candidate.normalized()
		var angle_error: float = absf(gesture_direction.angle_to(candidate_direction))
		if angle_error > cone_limit_radians:
			continue
		var candidate_distance: float = float(candidate.get("distance", to_candidate.length()))
		if angle_error < best_angle_error - 0.0001:
			best_candidate = candidate.duplicate(true)
			best_angle_error = angle_error
			best_distance = candidate_distance
			best_candidate["angle_error_rad"] = angle_error
			continue
		if absf(angle_error - best_angle_error) <= 0.0001 and candidate_distance < best_distance:
			best_candidate = candidate.duplicate(true)
			best_angle_error = angle_error
			best_distance = candidate_distance
			best_candidate["angle_error_rad"] = angle_error
	return best_candidate


func _build_pass_preview_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if ballhandler == null:
		return candidates
	var ballhandler_anchor: Vector2 = ballhandler.get_screen_anchor()
	for teammate in offense_players:
		if teammate == null or teammate == ballhandler:
			continue
		var teammate_anchor: Vector2 = teammate.get_screen_anchor()
		var direction_vector: Vector2 = teammate_anchor - ballhandler_anchor
		candidates.append({
			"player": teammate,
			"distance": direction_vector.length(),
			"direction_vector": direction_vector,
		})
	return candidates


func _is_in_movement_zone(screen_position: Vector2) -> bool:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var movement_ratio: float = input_config.movement_zone_height_ratio if input_config != null else 0.35
	return screen_position.y >= viewport_size.y * (1.0 - movement_ratio)


func _screen_to_world_ground(screen_position: Vector2) -> Vector2:
	if projection == null:
		return screen_position
	return projection.screen_to_world_ground(screen_position)


func _now_seconds() -> float:
	return float(Time.get_ticks_usec()) / 1000000.0
