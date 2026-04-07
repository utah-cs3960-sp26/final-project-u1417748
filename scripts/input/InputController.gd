class_name InputController
extends Node

signal joystick_vector_changed(vector: Vector2)
signal action_started(world_pos: Vector2)
signal action_dragged(start_pos: Vector2, current_pos: Vector2)
signal action_released(start_pos: Vector2, end_pos: Vector2, moved_distance: float)
signal pause_requested
signal debug_overlay_toggled

var joystick_touch_id: int = -1
var action_touch_id: int = -1
var joystick_center: Vector2 = Vector2.ZERO
var joystick_position: Vector2 = Vector2.ZERO
var joystick_vector: Vector2 = Vector2.ZERO
var joystick_max_radius: float = 110.0
var joystick_deadzone: float = 16.0
var action_start_position: Vector2 = Vector2.ZERO
var action_current_position: Vector2 = Vector2.ZERO
var mouse_action_active: bool = false

func _ready() -> void:
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		emit_signal("pause_requested")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_debug"):
		emit_signal("debug_overlay_toggled")
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if event.position.y >= get_viewport().get_visible_rect().size.y * 0.66 and joystick_touch_id == -1:
			joystick_touch_id = event.index
			joystick_center = event.position
			joystick_position = event.position
			_emit_joystick_vector()
		else:
			if action_touch_id == -1:
				action_touch_id = event.index
				action_start_position = event.position
				action_current_position = event.position
				emit_signal("action_started", event.position)
	else:
		if event.index == joystick_touch_id:
			joystick_touch_id = -1
			joystick_position = joystick_center
			joystick_vector = Vector2.ZERO
			emit_signal("joystick_vector_changed", joystick_vector)
		if event.index == action_touch_id:
			var moved: float = action_start_position.distance_to(action_current_position)
			emit_signal("action_released", action_start_position, action_current_position, moved)
			action_touch_id = -1

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index == joystick_touch_id:
		joystick_position = event.position
		_emit_joystick_vector()
	elif event.index == action_touch_id:
		action_current_position = event.position
		emit_signal("action_dragged", action_start_position, action_current_position)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		mouse_action_active = true
		action_start_position = event.position
		action_current_position = event.position
		emit_signal("action_started", event.position)
	else:
		if mouse_action_active:
			var moved: float = action_start_position.distance_to(action_current_position)
			emit_signal("action_released", action_start_position, action_current_position, moved)
		mouse_action_active = false

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if mouse_action_active:
		action_current_position = event.position
		emit_signal("action_dragged", action_start_position, action_current_position)

func _emit_joystick_vector() -> void:
	var delta: Vector2 = joystick_position - joystick_center
	if delta.length() <= joystick_deadzone:
		joystick_vector = Vector2.ZERO
	else:
		var clamped: Vector2 = delta.limit_length(joystick_max_radius)
		joystick_vector = clamped / joystick_max_radius
		emit_signal("joystick_vector_changed", joystick_vector)

func get_keyboard_vector() -> Vector2:
	var vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return vector

func get_joystick_draw_state() -> Dictionary:
	return {
		"active": joystick_touch_id != -1,
		"center": joystick_center,
		"position": joystick_center + joystick_vector * joystick_max_radius,
		"radius": joystick_max_radius,
	}

func set_debug_joystick(vector: Vector2) -> void:
	joystick_vector = vector.limit_length(1.0)
	emit_signal("joystick_vector_changed", joystick_vector)
