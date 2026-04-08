class_name InputController
extends Node

signal movement_updated(direction: Vector2, magnitude: float)
signal pass_requested(target: PlayerController)
signal shot_aim_started(start_world: Vector2)
signal shot_aim_updated(current_world: Vector2, drag_vector: Vector2)
signal shot_aim_released(release_screen: Vector2, release_world: Vector2, drag_vector: Vector2)
signal pause_requested()

var joystick: JoystickControl
var projection: CourtProjection
var ballhandler: PlayerController
var offense_players: Array[PlayerController] = []
var shot_hold_delay: float = 0.16
var action_touch_index: int = -1
var action_start_screen: Vector2 = Vector2.ZERO
var action_current_screen: Vector2 = Vector2.ZERO
var action_start_world: Vector2 = Vector2.ZERO
var action_current_world: Vector2 = Vector2.ZERO
var action_elapsed: float = 0.0
var action_started_on_ballhandler: bool = false
var shot_hold_active: bool = false
var ballhandler_hold_radius: float = 72.0
var tap_radius: float = 60.0


func _ready() -> void:
	set_process_input(true)
	set_process(true)


func setup(joystick_control: JoystickControl, projection_value: CourtProjection = null) -> void:
	joystick = joystick_control
	projection = projection_value
	joystick.joystick_changed.connect(_on_joystick_changed)
	joystick.joystick_released.connect(_on_joystick_released)


func set_projection(projection_value: CourtProjection) -> void:
	projection = projection_value


func set_ballhandler(player: PlayerController) -> void:
	ballhandler = player


func set_offense_players(players: Array[PlayerController]) -> void:
	offense_players = players


func _process(delta: float) -> void:
	if action_touch_index == -1 or shot_hold_active or not action_started_on_ballhandler:
		return
	action_elapsed += delta
	if action_elapsed >= shot_hold_delay:
		shot_hold_active = true
		shot_aim_started.emit(ballhandler.world_position if ballhandler != null else action_start_world)


func _on_joystick_changed(direction: Vector2, magnitude: float) -> void:
	movement_updated.emit(direction, magnitude)


func _on_joystick_released() -> void:
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
	if event.pressed:
		if joystick != null and event.index == joystick.get_touch_index():
			return
		if action_touch_index != -1:
			return
		action_touch_index = event.index
		action_start_screen = event.position
		action_current_screen = event.position
		action_start_world = _screen_to_world_ground(event.position)
		action_current_world = action_start_world
		action_elapsed = 0.0
		action_started_on_ballhandler = _is_ballhandler_screen_hit(action_start_screen)
		shot_hold_active = false
	else:
		if event.index != action_touch_index:
			return
		_finish_action(event.position)


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index != action_touch_index:
		return
	action_current_screen = event.position
	action_current_world = _screen_to_world_ground(event.position)
	if shot_hold_active:
		shot_aim_updated.emit(action_current_world, Vector2.ZERO)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		action_touch_index = -2
		action_start_screen = event.position
		action_current_screen = event.position
		action_start_world = _screen_to_world_ground(event.position)
		action_current_world = action_start_world
		action_elapsed = 0.0
		action_started_on_ballhandler = _is_ballhandler_screen_hit(action_start_screen)
		shot_hold_active = false
	else:
		if action_touch_index == -2:
			_finish_action(event.position)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if action_touch_index != -2:
		return
	action_current_screen = event.position
	action_current_world = _screen_to_world_ground(event.position)
	if shot_hold_active:
		shot_aim_updated.emit(action_current_world, Vector2.ZERO)


func _finish_action(release_screen: Vector2) -> void:
	var release_world: Vector2 = _screen_to_world_ground(release_screen)
	if shot_hold_active:
		shot_aim_released.emit(release_screen, release_world, Vector2.ZERO)
	elif not action_started_on_ballhandler:
		var teammate: PlayerController = find_teammate_at_screen(release_screen)
		if teammate != null:
			pass_requested.emit(teammate)
	action_touch_index = -1
	action_elapsed = 0.0
	action_started_on_ballhandler = false
	shot_hold_active = false
	action_start_screen = Vector2.ZERO
	action_current_screen = Vector2.ZERO
	action_start_world = Vector2.ZERO
	action_current_world = Vector2.ZERO


func find_teammate_at_screen(screen_position: Vector2) -> PlayerController:
	for teammate in offense_players:
		if teammate == ballhandler:
			continue
		var hit_radius: float = maxf(tap_radius * teammate.projected_scale, teammate.get_input_hit_radius())
		if teammate.get_screen_anchor().distance_to(screen_position) <= hit_radius:
			return teammate
	return null


func _screen_to_world_ground(screen_position: Vector2) -> Vector2:
	if projection == null:
		return screen_position
	return projection.screen_to_world_ground(screen_position)


func _is_ballhandler_screen_hit(screen_position: Vector2) -> bool:
	if ballhandler == null:
		return false
	var hit_radius: float = maxf(ballhandler_hold_radius * ballhandler.projected_scale, ballhandler.get_input_hit_radius())
	return ballhandler.get_screen_anchor().distance_to(screen_position) <= hit_radius
