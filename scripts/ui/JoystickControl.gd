class_name JoystickControl
extends Control

var input_controller: InputController

func set_input_controller(controller: InputController) -> void:
	input_controller = controller
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if input_controller == null:
		return
	var state: Dictionary = input_controller.get_joystick_draw_state()
	if not state.get("active", false):
		var fallback_center: Vector2 = Vector2(size.x * 0.25, size.y * 0.78)
		draw_circle(fallback_center, 64.0, Color(1, 1, 1, 0.05))
		draw_circle(fallback_center, 64.0, Color(1, 1, 1, 0.16), false, 4.0, true)
		return
	var center: Vector2 = state["center"]
	var knob: Vector2 = state["position"]
	var radius: float = state["radius"]
	draw_circle(center, radius, Color(0, 0, 0, 0.18))
	draw_circle(center, radius, Color(1, 1, 1, 0.22), false, 4.0, true)
	draw_circle(knob, radius * 0.42, Color("#f6d365"))
	draw_circle(knob, radius * 0.42, Color("#2a1a10"), false, 3.0, true)
