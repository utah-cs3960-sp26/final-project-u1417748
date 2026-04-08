class_name BallController
extends Node2D

const BALL_TEXTURE: Texture2D = preload("res://assets/Ball/Ball.png")
const BALL_OUTLINE_TEXTURE: Texture2D = preload("res://assets/Ball/Ball_outline.png")

@export var ball_sprite_size: Vector2 = Vector2(16.0, 16.0)

var current_z: float = 0.0
var ball_screen_offset: Vector2 = Vector2.ZERO
var shadow_local_position: Vector2 = Vector2(0.0, 18.0)
var current_ball_radius: float = 14.0
var current_shadow_scale: float = 1.0

var _fill_sprite: Sprite2D
var _outline_sprite: Sprite2D


func _ready() -> void:
	_ensure_sprites()


func sync_visual(world_position: Vector2, z_value: float, projection_data: Dictionary = {}) -> void:
	_ensure_sprites()
	current_z = z_value
	position = projection_data.get("ground_anchor", world_position)
	var ball_anchor: Vector2 = projection_data.get("ball_anchor", position + Vector2(0.0, -z_value * 0.18))
	var shadow_anchor: Vector2 = projection_data.get("shadow_anchor", position + Vector2(0.0, 18.0))
	ball_screen_offset = ball_anchor - position
	shadow_local_position = shadow_anchor - position
	current_ball_radius = projection_data.get("ball_radius", clampf(14.0 + current_z * 0.018, 14.0, 24.0))
	current_shadow_scale = projection_data.get("shadow_scale", clampf(1.0 - current_z / 500.0, 0.35, 1.0))
	z_index = int(round(projection_data.get("depth_key", position.y))) + 8
	_sync_sprite_transform()
	queue_redraw()


func _draw() -> void:
	draw_ellipse(shadow_local_position, 16.0 * current_shadow_scale, 9.0 * current_shadow_scale, Color(0.0, 0.0, 0.0, 0.24))


func has_sprite_visuals() -> bool:
	return _fill_sprite != null and _outline_sprite != null and _fill_sprite.texture != null


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


func _sync_sprite_transform() -> void:
	if _fill_sprite == null or _outline_sprite == null:
		return
	var sprite_scale: float = (current_ball_radius * 2.0) / maxf(ball_sprite_size.x, 1.0)
	_fill_sprite.position = ball_screen_offset
	_outline_sprite.position = ball_screen_offset
	_fill_sprite.scale = Vector2.ONE * sprite_scale
	_outline_sprite.scale = Vector2.ONE * sprite_scale
