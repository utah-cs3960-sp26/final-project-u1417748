class_name PlayerController
extends Node2D

const LABEL_POSITION: Vector2 = Vector2(-48.0, -134.0)
const LABEL_SIZE: Vector2 = Vector2(96.0, 24.0)
const BASE_INPUT_HIT_RADIUS: float = 84.0
const SCREEN_ANCHOR_OFFSET: Vector2 = Vector2(0.0, -44.0)
const BALL_ANCHOR_OFFSET: Vector2 = Vector2(24.0, -82.0)

var player_data: PlayerData
var is_offense: bool = true
var team_color: Color = Color.WHITE
var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.28)
var is_controlled: bool = false
var has_ball: bool = false
var world_position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var projected_scale: float = 1.0
var projected_shadow_offset: Vector2 = Vector2(0.0, 18.0)
var projected_shadow_scale: float = 1.0
var input_hit_radius: float = 58.0
var shot_pose_timer: float = 0.0
var catch_pose_timer: float = 0.0
var jump_pose_timer: float = 0.0

var _label: Label
var _visual: PlayerVisual


func _ready() -> void:
	z_index = 3
	_ensure_visual()
	if _label == null:
		_label = Label.new()
		_label.position = LABEL_POSITION
		_label.size = LABEL_SIZE
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 12)
		_label.visible = OS.is_debug_build()
		add_child(_label)
	_update_label()


func setup(data: PlayerData, offense_flag: bool, color_value: Color) -> void:
	player_data = data
	is_offense = offense_flag
	team_color = color_value
	if is_node_ready():
		_ensure_visual()
		_update_label()
		_sync_visual_team()
	queue_redraw()


func _update_label() -> void:
	if _label == null or player_data == null:
		return
	_label.text = player_data.role
	_label.add_theme_color_override("font_color", Color(0.96, 0.95, 0.85))


func _draw() -> void:
	draw_ellipse(projected_shadow_offset, 23.0 * projected_shadow_scale, 12.0 * projected_shadow_scale, shadow_color)
	if is_controlled:
		draw_arc(Vector2(0.0, 2.0), 22.0, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.95), 3.0)


func set_controlled(value: bool) -> void:
	is_controlled = value
	queue_redraw()


func set_has_ball(value: bool) -> void:
	has_ball = value
	queue_redraw()


func get_player_data() -> PlayerData:
	return player_data


func get_position_role() -> String:
	if player_data == null:
		return ""
	return player_data.role


func get_display_name() -> String:
	if player_data == null:
		return "Player"
	return player_data.display_name


func move_in_direction(direction: Vector2, speed_scale: float, delta: float) -> void:
	if player_data == null:
		return
	var max_speed: float = (180.0 + float(player_data.speed) * 2.2) * speed_scale
	velocity = direction * max_speed
	world_position += velocity * delta


func move_toward_target(target: Vector2, speed_scale: float, delta: float) -> void:
	var to_target: Vector2 = target - world_position
	if to_target.length() <= 2.0:
		velocity = Vector2.ZERO
		return
	move_in_direction(to_target.normalized(), speed_scale, delta)


func move_toward_target_smooth(
	target: Vector2,
	speed_scale: float,
	delta: float,
	arrival_radius: float,
	stop_radius: float,
	acceleration: float,
	deceleration: float
) -> void:
	if player_data == null:
		return
	var to_target: Vector2 = target - world_position
	var distance_value: float = to_target.length()
	var resolved_stop_radius: float = maxf(stop_radius, 0.0)
	var resolved_arrival_radius: float = maxf(arrival_radius, resolved_stop_radius + 0.001)
	if distance_value <= resolved_stop_radius:
		velocity = velocity.move_toward(Vector2.ZERO, maxf(deceleration, 0.0) * delta)
		if velocity.length() <= 1.0:
			velocity = Vector2.ZERO
		world_position += velocity * delta
		return
	var max_speed: float = (180.0 + float(player_data.speed) * 2.2) * speed_scale
	var desired_direction: Vector2 = to_target / maxf(distance_value, 0.001)
	var desired_speed: float = max_speed
	if distance_value < resolved_arrival_radius:
		var arrival_alpha: float = clampf(
			(distance_value - resolved_stop_radius) / maxf(resolved_arrival_radius - resolved_stop_radius, 0.001),
			0.0,
			1.0
		)
		desired_speed *= arrival_alpha * arrival_alpha * (3.0 - 2.0 * arrival_alpha)
	var desired_velocity: Vector2 = desired_direction * desired_speed
	var steering_step: float = maxf(acceleration, 0.0)
	if desired_velocity.length_squared() < velocity.length_squared():
		steering_step = maxf(deceleration, 0.0)
	velocity = velocity.move_toward(desired_velocity, steering_step * delta)
	if distance_value <= resolved_stop_radius * 1.12 and desired_speed <= 4.5:
		world_position = target - desired_direction * minf(distance_value, resolved_stop_radius)
		velocity = Vector2.ZERO
		return
	if distance_value <= resolved_stop_radius * 1.35 and velocity.length() <= 4.0:
		velocity = Vector2.ZERO
	world_position += velocity * delta


func apply_projection(
	screen_ground_position: Vector2,
	scale_value: float,
	shadow_offset_value: Vector2,
	shadow_scale_value: float,
	depth_key_value: float
) -> void:
	position = screen_ground_position
	projected_scale = scale_value
	projected_shadow_offset = shadow_offset_value
	projected_shadow_scale = shadow_scale_value
	input_hit_radius = BASE_INPUT_HIT_RADIUS * scale_value
	scale = Vector2.ONE * scale_value
	z_index = int(round(depth_key_value))
	queue_redraw()


func sync_visual_state(request, delta: float) -> void:
	_ensure_visual()
	shot_pose_timer = maxf(shot_pose_timer - delta, 0.0)
	catch_pose_timer = maxf(catch_pose_timer - delta, 0.0)
	jump_pose_timer = maxf(jump_pose_timer - delta, 0.0)
	if _visual == null:
		return
	_visual.apply_state(request, delta)


func trigger_shot_pose(duration: float = 0.28) -> void:
	shot_pose_timer = maxf(duration, 0.0)


func trigger_catch_pose(duration: float = 0.18) -> void:
	catch_pose_timer = maxf(duration, 0.0)


func trigger_jump_pose(duration: float = 0.18) -> void:
	jump_pose_timer = maxf(duration, 0.0)


func has_sprite_visuals() -> bool:
	return _visual != null and _visual.has_configured_sprites()


func get_debug_animation_family() -> String:
	return _visual.get_debug_animation_family() if _visual != null else ""


func get_debug_row_index() -> int:
	return _visual.get_debug_row_index() if _visual != null else -1


func get_debug_variant_index() -> int:
	return _visual.get_debug_variant_index() if _visual != null else -1


func get_debug_frame_number() -> int:
	return _visual.get_debug_frame_number() if _visual != null else -1


func get_debug_release_after_frame() -> int:
	return _visual.get_debug_release_after_frame() if _visual != null else -1


func get_current_animation_elapsed_time() -> float:
	return _visual.get_current_animation_elapsed_time() if _visual != null else 0.0


func is_current_animation_complete() -> bool:
	return _visual.is_current_animation_complete() if _visual != null else false


func get_current_shot_timing_profile() -> Dictionary:
	return _visual.get_current_animation_timing_profile() if _visual != null else {}


func is_ball_release_ready() -> bool:
	return _visual.is_ball_release_ready() if _visual != null else false


func get_debug_flip_h() -> bool:
	return _visual.get_debug_flip_h() if _visual != null else false


func is_outline_visible() -> bool:
	return _visual.is_outline_visible() if _visual != null else false


func get_debug_fill_texture_path() -> String:
	return _visual.get_debug_fill_texture_path() if _visual != null else ""


func get_screen_anchor() -> Vector2:
	return global_position + SCREEN_ANCHOR_OFFSET * projected_scale


func get_input_hit_radius() -> float:
	return input_hit_radius


func get_ball_screen_anchor() -> Vector2:
	return global_position + BALL_ANCHOR_OFFSET * projected_scale


func _ensure_visual() -> void:
	if _visual == null:
		_visual = get_node_or_null("PlayerVisual") as PlayerVisual
	if _visual == null:
		_visual = PlayerVisual.new()
		_visual.name = "PlayerVisual"
		add_child(_visual)
		if _label != null:
			move_child(_visual, 0)
	_sync_visual_team()


func _sync_visual_team() -> void:
	if _visual == null:
		return
	_visual.set_team_key("home" if is_offense else "away")
