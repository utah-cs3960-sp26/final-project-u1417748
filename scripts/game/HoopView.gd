class_name HoopView
extends Node2D

const HOOP_ATLAS: Texture2D = preload("res://assets/Court/Court.png")

@export var hoop_body_region: Rect2 = Rect2(1011.0, 17.0, 61.0, 95.0)
@export var hoop_front_texture_path: String = "res://assets/Court/NetClean.png"
@export var hoop_body_scale: float = 2.25
@export var hoop_front_scale: float = 1.6
@export var hoop_body_rim_anchor: Vector2 = Vector2(22.0, 19.0)
@export var hoop_front_rim_anchor: Vector2 = Vector2(15.0, 4.0)
@export var hoop_body_offset: Vector2 = Vector2.ZERO
@export var hoop_front_offset: Vector2 = Vector2(0.0, 12.0)

var court_config: CourtConfig
var projection: CourtProjection

var _back_sprite: Sprite2D
var _front_sprite: Sprite2D
var _front_texture: Texture2D


func setup(config_value: CourtConfig, projection_value: CourtProjection = null) -> void:
	court_config = config_value
	projection = projection_value
	_ensure_sprites()
	queue_redraw()


func set_projection(projection_value: CourtProjection) -> void:
	projection = projection_value
	_sync_projection()


func _ready() -> void:
	_ensure_sprites()
	_sync_projection()


func _sync_projection() -> void:
	if projection != null and court_config != null:
		position = projection.hoop_screen_anchor()
		z_index = int(round(projection.depth_key(court_config.hoop_position))) + 24
	_sync_sprite_positions()


func has_sprite_visuals() -> bool:
	return _back_sprite != null and _front_sprite != null and _back_sprite.texture != null and _front_sprite.texture != null


func _ensure_sprites() -> void:
	if _back_sprite == null:
		_back_sprite = Sprite2D.new()
		_back_sprite.name = "HoopBodySprite"
		_back_sprite.texture = HOOP_ATLAS
		_back_sprite.region_enabled = true
		_back_sprite.region_rect = hoop_body_region
		_back_sprite.centered = false
		_back_sprite.scale = Vector2.ONE * hoop_body_scale
		_back_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_back_sprite.z_index = -20
		add_child(_back_sprite)
	if _front_sprite == null:
		_front_sprite = Sprite2D.new()
		_front_sprite.name = "HoopFrontSprite"
		_front_sprite.texture = _get_front_texture()
		_front_sprite.region_enabled = false
		_front_sprite.centered = false
		_front_sprite.scale = Vector2.ONE * hoop_front_scale
		_front_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_front_sprite.z_index = 4
		add_child(_front_sprite)
	_sync_sprite_positions()


func _sync_sprite_positions() -> void:
	if _back_sprite == null or _front_sprite == null:
		return
	_back_sprite.region_rect = hoop_body_region
	_back_sprite.scale = Vector2.ONE * hoop_body_scale
	_front_sprite.texture = _get_front_texture()
	_front_sprite.scale = Vector2.ONE * hoop_front_scale
	_back_sprite.position = hoop_body_offset - hoop_body_rim_anchor * hoop_body_scale
	_front_sprite.position = hoop_front_offset - hoop_front_rim_anchor * hoop_front_scale


func _get_front_texture() -> Texture2D:
	if _front_texture != null:
		return _front_texture
	var loaded_texture: Texture2D = load(hoop_front_texture_path) as Texture2D
	if loaded_texture != null:
		_front_texture = loaded_texture
		return _front_texture
	if not FileAccess.file_exists(hoop_front_texture_path):
		return null
	var image: Image = Image.load_from_file(hoop_front_texture_path)
	if image.is_empty():
		return null
	_front_texture = ImageTexture.create_from_image(image)
	return _front_texture
