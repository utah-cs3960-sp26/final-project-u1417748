class_name InputController
extends Node

signal movement_zone_started(anchor_screen: Vector2, anchor_world: Vector2)
signal movement_zone_ended(release_screen: Vector2, release_world: Vector2, elapsed: float, reason: String, details: Dictionary)
signal movement_updated(direction: Vector2, magnitude: float)
signal pass_requested(target: PlayerController, details: Dictionary)
signal shot_mode_requested(details: Dictionary)
signal shot_timing_tapped(screen_position: Vector2)
signal pause_requested()

const DEFAULT_VIEWPORT_SIZE: Vector2 = Vector2(1080.0, 1920.0)

enum InteractionMode {
	DISABLED,
	LIVE_OFFENSE,
	SHOT_TIMING,
}

enum ControlZone {
	NONE,
	SHOOT,
	PASS_LEFT,
	MOVE,
	PASS_RIGHT,
	DUNK,
}

var input_config
var projection
var ballhandler: PlayerController
var offense_players: Array[PlayerController] = []
var interaction_mode: int = InteractionMode.DISABLED
var allow_keyboard_debug: bool = true
var allow_mouse_emulation: bool = true

var control_panel_rect: Rect2 = Rect2()
var control_zone_rects: Dictionary = {}

var gameplay_touch_index: int = -1
var gesture_anchor_screen: Vector2 = Vector2.ZERO
var gesture_current_screen: Vector2 = Vector2.ZERO
var gesture_anchor_world: Vector2 = Vector2.ZERO
var gesture_current_world: Vector2 = Vector2.ZERO
var gesture_start_time: float = 0.0
var gesture_max_excursion: float = 0.0
var timing_tap_consumed: bool = false
var transient_highlight_zone: String = ""
var transient_highlight_until: float = 0.0


func _ready() -> void:
	set_process_input(true)
	set_process_unhandled_input(true)
	set_process(true)


func setup(
	config_value,
	projection_value = null,
	keyboard_debug_enabled: bool = true,
	mouse_emulation_enabled: bool = true
) -> void:
	input_config = config_value
	projection = projection_value
	allow_keyboard_debug = keyboard_debug_enabled
	allow_mouse_emulation = mouse_emulation_enabled


func set_projection(projection_value) -> void:
	projection = projection_value


func set_control_layout(layout_metrics: Dictionary) -> void:
	control_panel_rect = layout_metrics.get("control_panel_rect", Rect2())
	control_zone_rects = Dictionary(layout_metrics.get("control_zone_rects", {})).duplicate(true)


func get_control_layout_snapshot() -> Dictionary:
	var layout: Dictionary = _resolve_control_layout()
	return {
		"control_panel_rect": layout.get("control_panel_rect", Rect2()),
		"control_zone_rects": Dictionary(layout.get("control_zone_rects", {})).duplicate(true),
	}


func set_ballhandler(player: PlayerController) -> void:
	ballhandler = player


func set_offense_players(players: Array[PlayerController]) -> void:
	offense_players = players


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
		if _handle_direct_action_press(event.index, event.position):
			return
		if _has_active_pointer() or not _is_in_move_zone(event.position):
			return
		_begin_live_gesture(event.index, event.position)
		return
	if event.index == gameplay_touch_index:
		_finish_live_gesture(event.position)


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if interaction_mode != InteractionMode.LIVE_OFFENSE:
		return
	if event.index == gameplay_touch_index:
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
		if _handle_direct_action_press(-3, event.position):
			return
		if _has_active_pointer() or not _is_in_move_zone(event.position):
			return
		_begin_live_gesture(-2, event.position)
		return
	if gameplay_touch_index == -2:
		_finish_live_gesture(event.position)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if interaction_mode != InteractionMode.LIVE_OFFENSE or not allow_mouse_emulation:
		return
	if gameplay_touch_index == -2:
		_update_live_gesture(event.position)


func _begin_live_gesture(pointer_index: int, screen_position: Vector2) -> void:
	gameplay_touch_index = pointer_index
	gesture_anchor_screen = screen_position
	gesture_current_screen = screen_position
	gesture_anchor_world = _screen_to_world_ground(screen_position)
	gesture_current_world = gesture_anchor_world
	gesture_start_time = _now_seconds()
	gesture_max_excursion = 0.0
	movement_updated.emit(Vector2.ZERO, 0.0)
	movement_zone_started.emit(gesture_anchor_screen, gesture_anchor_world)


func _update_live_gesture(screen_position: Vector2) -> void:
	gesture_current_screen = screen_position
	gesture_current_world = _screen_to_world_ground(screen_position)
	gesture_max_excursion = maxf(gesture_max_excursion, screen_position.distance_to(gesture_anchor_screen))
	var movement_snapshot: Dictionary = compute_movement_snapshot(gesture_anchor_screen, screen_position)
	movement_updated.emit(movement_snapshot["direction"], movement_snapshot["magnitude"])


func _finish_live_gesture(release_screen: Vector2) -> void:
	if gameplay_touch_index == -1:
		return
	gesture_current_screen = release_screen
	gesture_current_world = _screen_to_world_ground(release_screen)
	var elapsed: float = maxf(_now_seconds() - gesture_start_time, 0.0)
	var release_world: Vector2 = gesture_current_world
	var max_touch_distance: float = maxf(gesture_max_excursion, release_screen.distance_to(gesture_anchor_screen))
	var release_classification: Dictionary = classify_control_release(gesture_anchor_screen, release_screen)
	var release_details: Dictionary = _build_gameplay_action_details(
		gesture_anchor_screen,
		release_screen,
		gesture_anchor_world,
		release_world,
		elapsed,
		max_touch_distance,
		true
	)
	release_details.merge(release_classification, true)
	var release_reason: String = str(release_classification.get("release_reason", "move_release"))
	movement_updated.emit(Vector2.ZERO, 0.0)
	movement_zone_ended.emit(release_screen, release_world, elapsed, release_reason, release_details)
	_clear_live_gesture_state()
	if not bool(release_classification.get("qualifies", false)):
		return
	match str(release_classification.get("action_type", "")):
		"pass":
			pass_requested.emit(null, release_details)
		"shot":
			shot_mode_requested.emit(release_details)


func _cancel_live_gesture(reason: String) -> void:
	if gameplay_touch_index == -1:
		return
	var release_screen: Vector2 = gesture_current_screen
	var release_world: Vector2 = gesture_current_world
	var elapsed: float = maxf(_now_seconds() - gesture_start_time, 0.0)
	var max_touch_distance: float = maxf(gesture_max_excursion, release_screen.distance_to(gesture_anchor_screen))
	var release_details: Dictionary = _build_gameplay_action_details(
		gesture_anchor_screen,
		release_screen,
		gesture_anchor_world,
		release_world,
		elapsed,
		max_touch_distance,
		true
	)
	release_details["release_reason"] = reason
	release_details["release_zone"] = _control_zone_name(_get_control_zone_for_screen(release_screen))
	movement_updated.emit(Vector2.ZERO, 0.0)
	movement_zone_ended.emit(release_screen, release_world, elapsed, reason, release_details)
	_clear_live_gesture_state()


func _handle_direct_action_press(pointer_index: int, screen_position: Vector2, tap_duration: float = 0.0) -> bool:
	if interaction_mode != InteractionMode.LIVE_OFFENSE:
		return false
	var zone: int = _get_control_zone_for_screen(screen_position)
	match zone:
		ControlZone.PASS_LEFT, ControlZone.PASS_RIGHT, ControlZone.SHOOT, ControlZone.DUNK:
			_set_transient_highlight(_control_zone_name(zone))
			var details: Dictionary = _build_direct_action_details(pointer_index, screen_position, zone, tap_duration)
			if zone == ControlZone.PASS_LEFT or zone == ControlZone.PASS_RIGHT:
				pass_requested.emit(null, details)
			else:
				shot_mode_requested.emit(details)
			return true
	return false


func _build_direct_action_details(pointer_index: int, screen_position: Vector2, zone: int, tap_duration: float) -> Dictionary:
	var world_position: Vector2 = _screen_to_world_ground(screen_position)
	var zone_name: String = _control_zone_name(zone)
	var details: Dictionary = _build_gameplay_action_details(
		screen_position,
		screen_position,
		world_position,
		world_position,
		maxf(tap_duration, 0.0),
		0.0,
		false
	)
	var action_type: String = "pass" if zone == ControlZone.PASS_LEFT or zone == ControlZone.PASS_RIGHT else "shot"
	var control_intent: String = ""
	var release_reason: String = "%s_button_tap" % zone_name
	if zone == ControlZone.SHOOT:
		control_intent = "shot_layout"
	elif zone == ControlZone.DUNK:
		control_intent = "dunk"
	details.merge(
		{
			"tap_pointer_index": pointer_index,
			"direct_button_tap": true,
			"arm_reason": "direct_button_tap" if action_type == "shot" else "",
			"release_zone": zone_name,
			"action_zone": zone_name,
			"qualifies": true,
			"action_distance_met": true,
			"action_type": action_type,
			"control_intent": control_intent,
			"release_reason": release_reason,
			"pass_target_source": "focused_target",
		},
		true
	)
	return details


func _clear_live_gesture_state() -> void:
	gameplay_touch_index = -1
	gesture_anchor_screen = Vector2.ZERO
	gesture_current_screen = Vector2.ZERO
	gesture_anchor_world = Vector2.ZERO
	gesture_current_world = Vector2.ZERO
	gesture_start_time = 0.0
	gesture_max_excursion = 0.0


func _build_gameplay_action_details(
	tap_start_screen: Vector2,
	tap_end_screen: Vector2,
	tap_start_world: Vector2,
	tap_end_world: Vector2,
	tap_duration: float,
	tap_max_distance: float,
	started_in_movement_zone: bool
) -> Dictionary:
	return {
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


func get_touch_feedback_snapshot() -> Dictionary:
	var active: bool = gameplay_touch_index != -1 and interaction_mode == InteractionMode.LIVE_OFFENSE
	var transient_zone: String = _get_transient_highlight_zone()
	var highlight_zone: String = ""
	var current_zone: String = ""
	var action_distance_met: bool = false
	if active:
		var release_classification: Dictionary = classify_control_release(gesture_anchor_screen, gesture_current_screen)
		current_zone = str(release_classification.get("release_zone", ""))
		action_distance_met = bool(release_classification.get("action_distance_met", false))
		highlight_zone = current_zone if current_zone != "" else "move"
		if highlight_zone == "none":
			highlight_zone = ""
	elif transient_zone != "":
		current_zone = transient_zone
		highlight_zone = transient_zone
		action_distance_met = true
	return {
		"anchor_visible": active,
		"anchor_screen": gesture_anchor_screen,
		"current_screen": gesture_current_screen,
		"anchor_radius": input_config.anchor_visual_radius if input_config != null else 54.0,
		"knob_radius": input_config.anchor_knob_radius if input_config != null else 28.0,
		"anchor_alpha": input_config.anchor_visual_alpha if input_config != null else 0.2,
		"current_zone": current_zone,
		"highlight_zone": highlight_zone,
		"action_distance_met": action_distance_met,
	}


func begin_test_live_gesture(screen_position: Vector2 = Vector2.ZERO, pointer_index: int = -99) -> void:
	if interaction_mode != InteractionMode.LIVE_OFFENSE or _has_active_pointer():
		return
	var anchor: Vector2 = screen_position if screen_position != Vector2.ZERO else _get_zone_center("move")
	if not _is_in_move_zone(anchor):
		anchor = _get_zone_center("move")
	_begin_live_gesture(pointer_index, anchor)


func update_test_live_gesture(screen_position: Vector2) -> void:
	if interaction_mode != InteractionMode.LIVE_OFFENSE or gameplay_touch_index == -1:
		return
	_update_live_gesture(screen_position)


func end_test_live_gesture(screen_position: Vector2 = Vector2.ZERO) -> void:
	if interaction_mode != InteractionMode.LIVE_OFFENSE or gameplay_touch_index == -1:
		return
	var release_screen: Vector2 = screen_position if screen_position != Vector2.ZERO else gesture_current_screen
	_finish_live_gesture(release_screen)


func tap_test_shot_timing(screen_position: Vector2 = Vector2.ZERO) -> void:
	if interaction_mode != InteractionMode.SHOT_TIMING or timing_tap_consumed:
		return
	timing_tap_consumed = true
	shot_timing_tapped.emit(screen_position)


func tap_test_control_button(zone_name: String, duration: float = 0.05, pointer_index: int = -96) -> void:
	if interaction_mode != InteractionMode.LIVE_OFFENSE:
		return
	var resolved_zone: String = zone_name
	if resolved_zone not in ["pass_left", "pass_right", "shoot", "dunk"]:
		return
	_handle_direct_action_press(pointer_index, _get_zone_center(resolved_zone), duration)


func tap_test_pass(screen_position: Vector2 = Vector2.ZERO, duration: float = 0.05) -> void:
	if interaction_mode != InteractionMode.LIVE_OFFENSE:
		return
	var release_zone: String = "pass_left" if screen_position.x > 0.0 and screen_position.x < _get_viewport_size().x * 0.5 else "pass_right"
	var authored_zone: String = _control_zone_name(_get_control_zone_for_screen(screen_position))
	if authored_zone == "pass_left" or authored_zone == "pass_right":
		release_zone = authored_zone
	tap_test_control_button(release_zone, duration, -97)


func swipe_test_shot_arm(
	start_screen: Vector2 = Vector2.ZERO,
	end_screen: Vector2 = Vector2.ZERO,
	duration: float = 0.12
) -> void:
	if interaction_mode != InteractionMode.LIVE_OFFENSE or _has_active_pointer():
		return
	var start_position: Vector2 = start_screen if start_screen != Vector2.ZERO else _get_zone_center("move")
	if not _is_in_move_zone(start_position):
		start_position = _get_zone_center("move")
	var release_zone: String = "shoot"
	if end_screen != Vector2.ZERO:
		var authored_zone: String = _control_zone_name(_get_control_zone_for_screen(end_screen))
		if authored_zone == "shoot" or authored_zone == "dunk" or authored_zone == "move":
			release_zone = authored_zone
		else:
			var swipe_vector: Vector2 = end_screen - start_position
			if absf(swipe_vector.x) > absf(swipe_vector.y):
				release_zone = "move"
			elif swipe_vector.y > 0.0:
				release_zone = "dunk"
	elif end_screen.y > start_position.y:
		release_zone = "dunk"
	var release_screen: Vector2 = _get_zone_center(release_zone)
	_begin_live_gesture(-98, start_position)
	gesture_start_time = _now_seconds() - maxf(duration, 0.0)
	_update_live_gesture(release_screen)
	_finish_live_gesture(release_screen)


func swipe_test_dunk_arm(duration: float = 0.12) -> void:
	swipe_test_shot_arm(_get_zone_center("move"), _get_zone_center("dunk"), duration)


func tap_test_shot_arm(screen_position: Vector2 = Vector2.ZERO, duration: float = 0.05) -> void:
	tap_test_control_button("shoot", duration, -98)


func tap_test_dunk_button(duration: float = 0.05) -> void:
	tap_test_control_button("dunk", duration, -95)


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


func classify_control_release(anchor_screen: Vector2, release_screen: Vector2) -> Dictionary:
	var release_offset_screen: Vector2 = release_screen - anchor_screen
	var release_distance: float = release_offset_screen.length()
	var min_distance: float = input_config.control_action_min_distance_pixels if input_config != null else 52.0
	var zone: int = _get_control_zone_for_screen(release_screen)
	var zone_name: String = _control_zone_name(zone)
	var action_distance_met: bool = release_distance >= min_distance
	var action_type: String = ""
	var control_intent: String = ""
	var release_reason: String = "center_cancel" if release_distance <= float(input_config.deadzone if input_config != null else 22.0) else "move_release"
	var qualifies: bool = false
	match zone:
		ControlZone.PASS_LEFT, ControlZone.PASS_RIGHT:
			qualifies = action_distance_met
			action_type = "pass" if qualifies else ""
			release_reason = "pass_left_release" if zone == ControlZone.PASS_LEFT and qualifies else "pass_right_release" if zone == ControlZone.PASS_RIGHT and qualifies else release_reason
		ControlZone.SHOOT:
			qualifies = action_distance_met
			action_type = "shot" if qualifies else ""
			control_intent = "shot_layout" if qualifies else ""
			release_reason = "shoot_release" if qualifies else release_reason
		ControlZone.DUNK:
			qualifies = action_distance_met
			action_type = "shot" if qualifies else ""
			control_intent = "dunk" if qualifies else ""
			release_reason = "dunk_release" if qualifies else release_reason
		ControlZone.MOVE:
			release_reason = "center_cancel" if release_distance <= float(input_config.deadzone if input_config != null else 22.0) else "move_release"
		_:
			release_reason = "move_release"
	return {
		"release_offset_screen": release_offset_screen,
		"release_distance": release_distance,
		"release_zone": zone_name,
		"action_zone": zone_name if qualifies else "",
		"qualifies": qualifies,
		"action_distance_met": action_distance_met,
		"action_type": action_type,
		"control_intent": control_intent,
		"release_reason": release_reason,
		"pass_target_source": "focused_target",
	}


func _control_zone_name(zone: int) -> String:
	match zone:
		ControlZone.SHOOT:
			return "shoot"
		ControlZone.PASS_LEFT:
			return "pass_left"
		ControlZone.MOVE:
			return "move"
		ControlZone.PASS_RIGHT:
			return "pass_right"
		ControlZone.DUNK:
			return "dunk"
	return "none"


func _is_in_move_zone(screen_position: Vector2) -> bool:
	return _get_zone_rect("move").has_point(screen_position)


func _get_control_zone_for_screen(screen_position: Vector2) -> int:
	for zone_name in ["shoot", "pass_left", "move", "pass_right", "dunk"]:
		if _get_zone_rect(zone_name).has_point(screen_position):
			match zone_name:
				"shoot":
					return ControlZone.SHOOT
				"pass_left":
					return ControlZone.PASS_LEFT
				"move":
					return ControlZone.MOVE
				"pass_right":
					return ControlZone.PASS_RIGHT
				"dunk":
					return ControlZone.DUNK
	return ControlZone.NONE


func _get_zone_rect(zone_name: String) -> Rect2:
	var layout: Dictionary = _resolve_control_layout()
	var zone_rects: Dictionary = layout.get("control_zone_rects", {})
	return zone_rects.get(zone_name, Rect2())


func _get_zone_center(zone_name: String) -> Vector2:
	var zone_rect: Rect2 = _get_zone_rect(zone_name)
	if zone_rect.size.x <= 0.0 or zone_rect.size.y <= 0.0:
		return _get_viewport_size() * 0.5
	return zone_rect.get_center()


func _resolve_control_layout() -> Dictionary:
	if control_panel_rect.size.x > 0.0 and control_panel_rect.size.y > 0.0 and not control_zone_rects.is_empty():
		return {
			"control_panel_rect": control_panel_rect,
			"control_zone_rects": control_zone_rects,
		}
	return _build_default_control_layout()


func _build_default_control_layout() -> Dictionary:
	var viewport_size: Vector2 = _get_viewport_size()
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, viewport_size)
	var ui_scale: float = clampf(viewport_size.x / DEFAULT_VIEWPORT_SIZE.x, 0.82, 1.0)
	var horizontal_margin: float = (input_config.control_panel_horizontal_margin if input_config != null else 12.0) * ui_scale
	var bottom_margin: float = (input_config.control_panel_bottom_margin if input_config != null else 16.0) * ui_scale
	var panel_height: float = viewport_rect.size.y * (input_config.control_panel_height_ratio if input_config != null else 0.33)
	var panel_rect: Rect2 = Rect2(
		Vector2(viewport_rect.position.x + horizontal_margin, viewport_rect.end.y - panel_height - bottom_margin),
		Vector2(viewport_rect.size.x - horizontal_margin * 2.0, panel_height)
	)
	return {
		"control_panel_rect": panel_rect,
		"control_zone_rects": _build_control_zone_rects(panel_rect, ui_scale),
	}


func _build_control_zone_rects(panel_rect: Rect2, ui_scale: float) -> Dictionary:
	var gutter: float = (input_config.control_panel_gutter if input_config != null else 10.0) * ui_scale
	var top_row_ratio: float = clampf(input_config.control_panel_top_row_height_ratio if input_config != null else 0.45, 0.3, 0.7)
	var top_row_height: float = maxf((panel_rect.size.y - gutter) * top_row_ratio, 1.0)
	var middle_height: float = maxf(panel_rect.size.y - top_row_height - gutter, 1.0)
	var top_row_rect: Rect2 = Rect2(panel_rect.position, Vector2(panel_rect.size.x, top_row_height))
	var middle_rect: Rect2 = Rect2(Vector2(panel_rect.position.x, top_row_rect.end.y + gutter), Vector2(panel_rect.size.x, middle_height))
	var top_half_width: float = maxf(top_row_rect.size.x * 0.5, 1.0)
	var shoot_rect: Rect2 = Rect2(top_row_rect.position, Vector2(top_half_width, top_row_rect.size.y))
	var dunk_rect: Rect2 = Rect2(
		Vector2(top_row_rect.position.x + top_half_width, top_row_rect.position.y),
		Vector2(maxf(top_row_rect.size.x - top_half_width, 1.0), top_row_rect.size.y)
	)
	var side_ratio: float = clampf(input_config.control_panel_side_zone_width_ratio if input_config != null else 0.25, 0.15, 0.4)
	var available_middle_width: float = maxf(middle_rect.size.x - gutter * 2.0, 1.0)
	var side_width: float = available_middle_width * side_ratio
	var move_width: float = maxf(available_middle_width - side_width * 2.0, 1.0)
	var pass_left_rect: Rect2 = Rect2(middle_rect.position, Vector2(side_width, middle_rect.size.y))
	var move_rect: Rect2 = Rect2(Vector2(pass_left_rect.end.x + gutter, middle_rect.position.y), Vector2(move_width, middle_rect.size.y))
	var pass_right_rect: Rect2 = Rect2(Vector2(move_rect.end.x + gutter, middle_rect.position.y), Vector2(side_width, middle_rect.size.y))
	return {
		"shoot": shoot_rect,
		"pass_left": pass_left_rect,
		"move": move_rect,
		"pass_right": pass_right_rect,
		"dunk": dunk_rect,
	}


func _screen_to_world_ground(screen_position: Vector2) -> Vector2:
	if projection == null:
		return screen_position
	return projection.screen_to_world_ground(screen_position)


func _has_active_pointer() -> bool:
	return gameplay_touch_index != -1


func _get_viewport_size() -> Vector2:
	var viewport: Viewport = get_viewport()
	return viewport.get_visible_rect().size if viewport != null else DEFAULT_VIEWPORT_SIZE


func _now_seconds() -> float:
	return float(Time.get_ticks_usec()) / 1000000.0


func _set_transient_highlight(zone_name: String) -> void:
	if zone_name == "" or zone_name == "none":
		transient_highlight_zone = ""
		transient_highlight_until = 0.0
		return
	transient_highlight_zone = zone_name
	transient_highlight_until = _now_seconds() + maxf(
		float(input_config.control_button_press_highlight_seconds if input_config != null else 0.12),
		0.0
	)


func _get_transient_highlight_zone() -> String:
	if transient_highlight_zone == "":
		return ""
	if _now_seconds() > transient_highlight_until:
		transient_highlight_zone = ""
		transient_highlight_until = 0.0
		return ""
	return transient_highlight_zone
