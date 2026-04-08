class_name JoystickControl
extends Control

signal joystick_changed(direction: Vector2, magnitude: float)
signal joystick_released()

var base_radius: float = 120.0
var knob_radius: float = 46.0
var deadzone: float = 22.0
var active_touch_index: int = -1
var current_vector: Vector2 = Vector2.ZERO
var current_magnitude: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			if active_touch_index == -1:
				active_touch_index = touch.index
				_update_vector(touch.position)
		elif touch.index == active_touch_index:
			active_touch_index = -1
			current_vector = Vector2.ZERO
			current_magnitude = 0.0
			joystick_released.emit()
			queue_redraw()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == active_touch_index:
			_update_vector(drag.position)


func _process(_delta: float) -> void:
	if active_touch_index != -1:
		return
	var keyboard_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if keyboard_vector.length() > 0.0:
		current_vector = keyboard_vector.normalized()
		current_magnitude = clampf(keyboard_vector.length(), 0.0, 1.0)
		joystick_changed.emit(current_vector, current_magnitude)
	else:
		if current_magnitude > 0.0:
			current_vector = Vector2.ZERO
			current_magnitude = 0.0
			joystick_released.emit()
	queue_redraw()


func _update_vector(world_position: Vector2) -> void:
	var local_center: Vector2 = size * 0.5
	var offset: Vector2 = world_position - global_position - local_center
	var distance_value: float = offset.length()
	if distance_value <= deadzone:
		current_vector = Vector2.ZERO
		current_magnitude = 0.0
		joystick_changed.emit(current_vector, current_magnitude)
		queue_redraw()
		return
	var clamped: Vector2 = offset.limit_length(base_radius)
	current_vector = clamped.normalized()
	current_magnitude = clampf((distance_value - deadzone) / maxf(base_radius - deadzone, 1.0), 0.0, 1.0)
	joystick_changed.emit(current_vector, current_magnitude)
	queue_redraw()


func get_touch_index() -> int:
	return active_touch_index


func _draw() -> void:
	var center: Vector2 = size * 0.5
	draw_circle(center, base_radius, Color(0.0, 0.0, 0.0, 0.18))
	draw_circle(center, base_radius - 12.0, Color(0.14, 0.17, 0.24, 0.78))
	draw_circle(center, base_radius - 16.0, Color(0.1, 0.12, 0.18, 0.92))
	var knob_offset: Vector2 = current_vector * current_magnitude * (base_radius - knob_radius - 8.0)
	draw_circle(center + knob_offset, knob_radius, Color(0.93, 0.74, 0.28, 0.92))
