class_name BallController
extends Node2D

const BALL_TEXTURE: Texture2D = preload("res://assets/Ball/Ball.png")
const BALL_OUTLINE_TEXTURE: Texture2D = preload("res://assets/Ball/Ball_outline.png")

const BALL_RENDER_PHASE_BEHIND_BACKBOARD: String = "behind_backboard"
const BALL_RENDER_PHASE_RIM_MOUTH: String = "rim_mouth"
const BALL_RENDER_PHASE_NET_CHANNEL: String = "net_channel"
const BALL_RENDER_PHASE_FRONT_OF_NET: String = "front_of_net"
const BALL_RENDER_PHASE_BETWEEN_BOARD_AND_NET: String = BALL_RENDER_PHASE_NET_CHANNEL

const BALL_RENDER_Z_OFFSET_BEHIND_BACKBOARD: int = 2
const BALL_RENDER_Z_OFFSET_RIM_MOUTH: int = 29
const BALL_RENDER_Z_OFFSET_NET_CHANNEL: int = 30
const BALL_RENDER_Z_OFFSET_FRONT_OF_NET: int = 31
const NO_Z_INDEX_OVERRIDE: int = -2147483648

@export var ball_sprite_size: Vector2 = Vector2(16.0, 16.0)

var current_z: float = 0.0
var current_render_phase: String = ""
var ball_screen_offset: Vector2 = Vector2.ZERO
var shadow_local_position: Vector2 = Vector2(0.0, 18.0)
var current_ball_radius: float = 14.0
var current_shadow_scale: float = 1.0
var _ball_visible: bool = true

var _fill_sprite: Sprite2D
var _outline_sprite: Sprite2D


func _ready() -> void:
	_ensure_sprites()
	_apply_ball_visibility()


func sync_visual(world_position: Vector2, z_value: float, projection_data: Dictionary = {}, z_index_override: int = NO_Z_INDEX_OVERRIDE, render_phase: String = "") -> void:
	_ensure_sprites()
	_apply_ball_visibility()
	current_z = z_value
	current_render_phase = render_phase if render_phase != "" else str(projection_data.get("render_phase", ""))
	position = projection_data.get("ground_anchor", world_position)
	var ball_anchor: Vector2 = projection_data.get("ball_anchor", position + Vector2(0.0, -z_value * 0.18))
	var shadow_anchor: Vector2 = projection_data.get("shadow_anchor", position + Vector2(0.0, 18.0))
	ball_screen_offset = ball_anchor - position
	shadow_local_position = shadow_anchor - position
	current_ball_radius = projection_data.get("ball_radius", clampf(14.0 + current_z * 0.018, 14.0, 24.0))
	current_shadow_scale = projection_data.get("shadow_scale", clampf(1.0 - current_z / 500.0, 0.35, 1.0))
	if z_index_override != NO_Z_INDEX_OVERRIDE:
		z_index = z_index_override
	elif projection_data.has("z_index_override"):
		z_index = int(projection_data["z_index_override"])
	elif current_render_phase != "":
		z_index = _get_phase_z_index(projection_data)
	else:
		z_index = int(round(projection_data.get("depth_key", position.y))) + 8
	_sync_sprite_transform()
	queue_redraw()


func set_ball_visible(is_visible: bool) -> void:
	if _ball_visible == is_visible:
		return
	_ball_visible = is_visible
	_apply_ball_visibility()
	queue_redraw()


func is_ball_visible() -> bool:
	return _ball_visible


func _draw() -> void:
	draw_ellipse(shadow_local_position, 16.0 * current_shadow_scale, 9.0 * current_shadow_scale, Color(0.0, 0.0, 0.0, 0.24))


func has_sprite_visuals() -> bool:
	return _fill_sprite != null and _outline_sprite != null and _fill_sprite.texture != null


func get_render_phase() -> String:
	return current_render_phase


func _ensure_sprites() -> void:
	if _outline_sprite == null:
		_outline_sprite = Sprite2D.new()
		_outline_sprite.name = "BallOutlineSprite"
		_outline_sprite.texture = BALL_OUTLINE_TEXTURE
		_outline_sprite.centered = true
		_outline_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_outline_sprite)
	if _fill_sprite == null:
		_fill_sprite = Sprite2D.new()
		_fill_sprite.name = "BallFillSprite"
		_fill_sprite.texture = BALL_TEXTURE
		_fill_sprite.centered = true
		_fill_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_fill_sprite)
	_sync_sprite_transform()


func _apply_ball_visibility() -> void:
	visible = _ball_visible
	if _fill_sprite != null:
		_fill_sprite.visible = _ball_visible
	if _outline_sprite != null:
		_outline_sprite.visible = _ball_visible


func _sync_sprite_transform() -> void:
	if _fill_sprite == null or _outline_sprite == null:
		return
	var sprite_scale: float = (current_ball_radius * 2.0) / maxf(ball_sprite_size.x, 1.0)
	_fill_sprite.position = ball_screen_offset
	_outline_sprite.position = ball_screen_offset
	_fill_sprite.scale = Vector2.ONE * sprite_scale
	_outline_sprite.scale = Vector2.ONE * sprite_scale


func _get_phase_z_index(projection_data: Dictionary) -> int:
	var base_depth: int = int(round(projection_data.get("depth_key", position.y)))
	match current_render_phase:
		BALL_RENDER_PHASE_BEHIND_BACKBOARD:
			return base_depth + BALL_RENDER_Z_OFFSET_BEHIND_BACKBOARD
		BALL_RENDER_PHASE_RIM_MOUTH:
			return base_depth + BALL_RENDER_Z_OFFSET_RIM_MOUTH
		BALL_RENDER_PHASE_NET_CHANNEL:
			return base_depth + BALL_RENDER_Z_OFFSET_NET_CHANNEL
		BALL_RENDER_PHASE_FRONT_OF_NET:
			return base_depth + BALL_RENDER_Z_OFFSET_FRONT_OF_NET
		_:
			return base_depth + 8
