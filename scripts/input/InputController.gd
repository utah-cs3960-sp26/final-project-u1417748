class_name InputController
extends Node

signal movement_zone_started(anchor_screen: Vector2, anchor_world: Vector2)
signal movement_zone_ended(release_screen: Vector2, release_world: Vector2, elapsed: float, reason: String, details: Dictionary)
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
var gesture_max_excursion: float = 0.0
var gesture_preview_target: PlayerController
var gesture_preview_details: Dictionary = {}
var tap_candidate_touch_index: int = -1
var tap_candidate_start_screen: Vector2 = Vector2.ZERO
var tap_candidate_current_screen: Vector2 = Vector2.ZERO
var tap_candidate_start_world: Vector2 = Vector2.ZERO
var tap_candidate_current_world: Vector2 = Vector2.ZERO
var tap_candidate_start_time: float = 0.0
var tap_candidate_max_distance: float = 0.0
var tap_candidate_started_in_movement_zone: bool = false
var timing_tap_consumed: bool = false


func _ready() -> void:
	set_process_input(true)
	set_process_unhandled_input(true)
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
		_clear_shot_tap_candidate_state()
	interaction_mode = mode_value
	if interaction_mode != InteractionMode.LIVE_OFFENSE:
		movement_updated.emit(Vector2.ZERO, 0.0)
	if interaction_mode != InteractionMode.SHOT_TIMING:
		timing_tap_consumed = false


func _process(_delta: float) -> void:
	if interaction_mode != InteractionMode.LIVE_OFFENSE:
		return
	if _has_active_pointer():
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


func _unhandled_input(event: InputEvent) -> void:
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
		if _has_active_pointer():
			return
		if _is_in_movement_zone(event.position):
			_begin_live_gesture(event.index, event.position)
		else:
			_begin_shot_tap_candidate(event.index, event.position, false)
		return
	if event.index == gameplay_touch_index:
		_finish_live_gesture(event.position)
	elif event.index == tap_candidate_touch_index:
		_finish_shot_tap_candidate(event.position)


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if interaction_mode != InteractionMode.LIVE_OFFENSE:
		return
	if event.index == gameplay_touch_index:
		_update_live_gesture(event.position)
	elif event.index == tap_candidate_touch_index:
		_update_shot_tap_candidate(event.position)


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
		if _has_active_pointer():
			return
		if _is_in_movement_zone(event.position):
			_begin_live_gesture(-2, event.position)
		else:
			_begin_shot_tap_candidate(-2, event.position, false)
		return
	if gameplay_touch_index == -2:
		_finish_live_gesture(event.position)
	elif tap_candidate_touch_index == -2:
		_finish_shot_tap_candidate(event.position)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if interaction_mode != InteractionMode.LIVE_OFFENSE or not allow_mouse_emulation:
		return
	if gameplay_touch_index == -2:
		_update_live_gesture(event.position)
	elif tap_candidate_touch_index == -2:
		_update_shot_tap_candidate(event.position)


func _begin_live_gesture(pointer_index: int, screen_position: Vector2) -> void:
	gameplay_touch_index = pointer_index
	gesture_anchor_screen = screen_position
	gesture_current_screen = screen_position
	gesture_anchor_world = _screen_to_world_ground(screen_position)
	gesture_current_world = gesture_anchor_world
	gesture_start_time = _now_seconds()
	gesture_max_excursion = 0.0
	_clear_pass_preview()
	movement_updated.emit(Vector2.ZERO, 0.0)
	movement_zone_started.emit(gesture_anchor_screen, gesture_anchor_world)


func _update_live_gesture(screen_position: Vector2) -> void:
	gesture_current_screen = screen_position
	gesture_current_world = _screen_to_world_ground(screen_position)
	gesture_max_excursion = maxf(gesture_max_excursion, screen_position.distance_to(gesture_anchor_screen))
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
	var max_touch_distance: float = maxf(gesture_max_excursion, release_screen.distance_to(gesture_anchor_screen))
	var tap_classification: Dictionary = classify_shot_tap(elapsed, max_touch_distance)
	if bool(tap_classification.get("qualifies", false)):
		var tap_details: Dictionary = _build_shot_tap_details(
			gesture_anchor_screen,
			release_screen,
			gesture_anchor_world,
			release_world,
			elapsed,
			max_touch_distance,
			true
		)
		movement_updated.emit(Vector2.ZERO, 0.0)
		movement_zone_ended.emit(release_screen, release_world, elapsed, "tap_shot", tap_details)
		_clear_live_gesture_state()
		shot_mode_requested.emit(tap_details)
		return
	var release_classification: Dictionary = classify_live_release(gesture_anchor_screen, release_screen, gesture_preview_target != null)
	var release_reason: String = str(release_classification.get("release_reason", "center_cancel"))
	var pass_target: PlayerController = gesture_preview_target
	var release_details: Dictionary = {
		"anchor_screen": gesture_anchor_screen,
		"release_screen": release_screen,
		"anchor_world": gesture_anchor_world,
		"release_world": release_world,
		"elapsed": elapsed,
		"release_offset_screen": release_classification.get("release_offset_screen", release_screen - gesture_anchor_screen),
		"release_distance": float(release_classification.get("release_distance", movement_snapshot["distance"])),
		"release_reason": release_reason,
		"direction": movement_snapshot["direction"],
		"pass_target": gesture_preview_target,
		"pass_target_role": gesture_preview_target.get_position_role() if gesture_preview_target != null else "",
		"pass_angle_error_rad": float(gesture_preview_details.get("angle_error_rad", 0.0)),
		"pass_distance": float(gesture_preview_details.get("distance", 0.0)),
		"tap_duration": elapsed,
		"tap_max_distance": max_touch_distance,
		"started_in_movement_zone": true,
	}
	movement_updated.emit(Vector2.ZERO, 0.0)
	movement_zone_ended.emit(release_screen, release_world, elapsed, release_reason, release_details)
	_clear_live_gesture_state()
	if release_reason == "pass" and pass_target != null:
		pass_requested.emit(pass_target, release_details)


func _cancel_live_gesture(reason: String) -> void:
	if gameplay_touch_index == -1:
		return
	var release_screen: Vector2 = gesture_current_screen
	var release_world: Vector2 = gesture_current_world
	var elapsed: float = maxf(_now_seconds() - gesture_start_time, 0.0)
	var max_touch_distance: float = maxf(gesture_max_excursion, release_screen.distance_to(gesture_anchor_screen))
	var release_classification: Dictionary = classify_live_release(gesture_anchor_screen, release_screen, gesture_preview_target != null)
	var release_details: Dictionary = {
		"anchor_screen": gesture_anchor_screen,
		"release_screen": release_screen,
		"anchor_world": gesture_anchor_world,
		"release_world": release_world,
		"elapsed": elapsed,
		"release_offset_screen": release_classification.get("release_offset_screen", release_screen - gesture_anchor_screen),
		"release_distance": float(release_classification.get("release_distance", (release_screen - gesture_anchor_screen).length())),
		"release_reason": reason,
		"tap_duration": elapsed,
		"tap_max_distance": max_touch_distance,
		"started_in_movement_zone": true,
	}
	movement_updated.emit(Vector2.ZERO, 0.0)
	movement_zone_ended.emit(release_screen, release_world, elapsed, reason, release_details)
	_clear_live_gesture_state()


func _clear_live_gesture_state() -> void:
	gameplay_touch_index = -1
	gesture_anchor_screen = Vector2.ZERO
	gesture_current_screen = Vector2.ZERO
	gesture_anchor_world = Vector2.ZERO
	gesture_current_world = Vector2.ZERO
	gesture_start_time = 0.0
	gesture_max_excursion = 0.0
	_clear_pass_preview()


func _begin_shot_tap_candidate(pointer_index: int, screen_position: Vector2, started_in_movement_zone: bool) -> void:
	tap_candidate_touch_index = pointer_index
	tap_candidate_start_screen = screen_position
	tap_candidate_current_screen = screen_position
	tap_candidate_start_world = _screen_to_world_ground(screen_position)
	tap_candidate_current_world = tap_candidate_start_world
	tap_candidate_start_time = _now_seconds()
	tap_candidate_max_distance = 0.0
	tap_candidate_started_in_movement_zone = started_in_movement_zone


func _update_shot_tap_candidate(screen_position: Vector2) -> void:
	if tap_candidate_touch_index == -1:
		return
	tap_candidate_current_screen = screen_position
	tap_candidate_current_world = _screen_to_world_ground(screen_position)
	tap_candidate_max_distance = maxf(tap_candidate_max_distance, screen_position.distance_to(tap_candidate_start_screen))


func _finish_shot_tap_candidate(release_screen: Vector2) -> void:
	if tap_candidate_touch_index == -1:
		return
	tap_candidate_current_screen = release_screen
	tap_candidate_current_world = _screen_to_world_ground(release_screen)
	var elapsed: float = maxf(_now_seconds() - tap_candidate_start_time, 0.0)
	var max_touch_distance: float = maxf(tap_candidate_max_distance, release_screen.distance_to(tap_candidate_start_screen))
	var tap_classification: Dictionary = classify_shot_tap(elapsed, max_touch_distance)
	if bool(tap_classification.get("qualifies", false)):
		var tap_details: Dictionary = _build_shot_tap_details(
			tap_candidate_start_screen,
			release_screen,
			tap_candidate_start_world,
			tap_candidate_current_world,
			elapsed,
			max_touch_distance,
			tap_candidate_started_in_movement_zone
		)
		_clear_shot_tap_candidate_state()
		shot_mode_requested.emit(tap_details)
		return
	_clear_shot_tap_candidate_state()


func _clear_shot_tap_candidate_state() -> void:
	tap_candidate_touch_index = -1
	tap_candidate_start_screen = Vector2.ZERO
	tap_candidate_current_screen = Vector2.ZERO
	tap_candidate_start_world = Vector2.ZERO
	tap_candidate_current_world = Vector2.ZERO
	tap_candidate_start_time = 0.0
	tap_candidate_max_distance = 0.0
	tap_candidate_started_in_movement_zone = false


func _build_shot_tap_details(
	tap_start_screen: Vector2,
	tap_end_screen: Vector2,
	tap_start_world: Vector2,
	tap_end_world: Vector2,
	tap_duration: float,
	tap_max_distance: float,
	started_in_movement_zone: bool
) -> Dictionary:
	return {
		"arm_reason": "tap",
		"release_reason": "tap_shot",
		"tap_start_screen": tap_start_screen,
		"tap_end_screen": tap_end_screen,
		"tap_start_world": tap_start_world,
		"tap_end_world": tap_end_world,
		"tap_duration": tap_duration,
		"tap_max_distance": tap_max_distance,
		"started_in_movement_zone": started_in_movement_zone,
		"release_offset_screen": tap_end_screen - tap_start_screen,
		"release_distance": tap_end_screen.distance_to(tap_start_screen),
	}


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
	if interaction_mode != InteractionMode.LIVE_OFFENSE or _has_active_pointer():
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


func tap_test_shot_arm(screen_position: Vector2 = Vector2.ZERO, duration: float = 0.05) -> void:
	if interaction_mode != InteractionMode.LIVE_OFFENSE or _has_active_pointer():
		return
	var touch_duration: float = maxf(duration, 0.0)
	if _is_in_movement_zone(screen_position):
		_begin_live_gesture(-97, screen_position)
		gesture_start_time = _now_seconds() - touch_duration
		_finish_live_gesture(screen_position)
		return
	_begin_shot_tap_candidate(-98, screen_position, false)
	tap_candidate_start_time = _now_seconds() - touch_duration
	_finish_shot_tap_candidate(screen_position)


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


func classify_shot_tap(touch_duration: float, max_touch_excursion: float) -> Dictionary:
	var max_duration: float = input_config.shot_tap_max_duration_seconds if input_config != null else 0.18
	var max_movement: float = input_config.shot_tap_max_movement_pixels if input_config != null else 20.0
	return {
		"qualifies": touch_duration <= max_duration and max_touch_excursion <= max_movement,
		"tap_duration": touch_duration,
		"tap_max_distance": max_touch_excursion,
	}


func classify_live_release(anchor_screen: Vector2, release_screen: Vector2, has_pass_target: bool) -> Dictionary:
	var release_offset_screen: Vector2 = release_screen - anchor_screen
	var release_distance: float = release_offset_screen.length()
	var deadzone_value: float = input_config.deadzone if input_config != null else 22.0
	if release_distance <= deadzone_value:
		return {
			"release_offset_screen": release_offset_screen,
			"release_distance": release_distance,
			"release_reason": "center_cancel",
			"should_pass": false,
			"should_arm_shot": false,
		}
	if has_pass_target:
		return {
			"release_offset_screen": release_offset_screen,
			"release_distance": release_distance,
			"release_reason": "pass",
			"should_pass": true,
			"should_arm_shot": false,
		}
	return {
		"release_offset_screen": release_offset_screen,
		"release_distance": release_distance,
		"release_reason": "no_target_cancel",
		"should_pass": false,
		"should_arm_shot": false,
	}


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
	var viewport: Viewport = get_viewport()
	var viewport_size: Vector2 = viewport.get_visible_rect().size if viewport != null else Vector2(1080.0, 1920.0)
	var movement_ratio: float = input_config.movement_zone_height_ratio if input_config != null else 0.35
	return screen_position.y >= viewport_size.y * (1.0 - movement_ratio)


func _screen_to_world_ground(screen_position: Vector2) -> Vector2:
	if projection == null:
		return screen_position
	return projection.screen_to_world_ground(screen_position)


func _has_active_pointer() -> bool:
	return gameplay_touch_index != -1 or tap_candidate_touch_index != -1


func _now_seconds() -> float:
	return float(Time.get_ticks_usec()) / 1000000.0
