class_name PlayerVisual
extends Node2D

const FRAME_SIZE: Vector2i = Vector2i(64, 64)
const HOME_FILL_TEXTURE: Texture2D = preload("res://assets/Character/Character1_NEW.png")
const HOME_OUTLINE_TEXTURE: Texture2D = preload("res://assets/Character/Character1_NEW_outline.png")
const AWAY_FILL_TEXTURE: Texture2D = preload("res://assets/Character/Character2_NEW.png")
const AWAY_OUTLINE_TEXTURE: Texture2D = preload("res://assets/Character/Character2_NEW_outline.png")

@export var sprite_offset: Vector2 = Vector2(0.0, -72.0)
@export var sprite_base_scale: float = 2.3

var _fill_sprite: Sprite2D
var _outline_sprite: Sprite2D
var _team_key: String = "home"
var _animation_state: String = "idle"
var _direction_bucket: String = "down"
var _frame_index: int = 0
var _frame_elapsed: float = 0.0
var _last_non_zero_facing: Vector2 = Vector2.DOWN

var _profiles: Dictionary = {
	"idle_down": {
		"frames": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
		"fps": 5.0,
		"loop": true,
	},
	"move_down": {
		"frames": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)],
		"fps": 10.0,
		"loop": true,
	},
	"idle_side": {
		"frames": [Vector2i(0, 10), Vector2i(1, 10), Vector2i(2, 10), Vector2i(3, 10), Vector2i(4, 10)],
		"fps": 5.0,
		"loop": true,
	},
	"move_side": {
		"frames": [Vector2i(0, 11), Vector2i(1, 11), Vector2i(2, 11), Vector2i(3, 11), Vector2i(4, 11)],
		"fps": 10.0,
		"loop": true,
	},
	"idle_up": {
		"frames": [Vector2i(0, 17), Vector2i(1, 17), Vector2i(2, 17), Vector2i(3, 17), Vector2i(4, 17)],
		"fps": 5.0,
		"loop": true,
	},
	"move_up": {
		"frames": [Vector2i(0, 18), Vector2i(1, 18), Vector2i(2, 18), Vector2i(3, 18), Vector2i(4, 18)],
		"fps": 10.0,
		"loop": true,
	},
	"aim": {
		"frames": [Vector2i(0, 12), Vector2i(1, 12), Vector2i(2, 12), Vector2i(3, 12), Vector2i(4, 12)],
		"fps": 8.0,
		"loop": true,
	},
	"shoot": {
		"frames": [Vector2i(0, 13), Vector2i(1, 13), Vector2i(2, 13), Vector2i(3, 13), Vector2i(4, 13), Vector2i(5, 13)],
		"fps": 14.0,
		"loop": false,
	},
	"catch": {
		"frames": [Vector2i(0, 19), Vector2i(1, 19), Vector2i(2, 19), Vector2i(3, 19), Vector2i(4, 19), Vector2i(5, 19)],
		"fps": 12.0,
		"loop": false,
	},
}


func _ready() -> void:
	_ensure_sprites()
	_apply_team_textures()
	_apply_profile_frame()


func set_team_key(team_key: String) -> void:
	_team_key = team_key
	_apply_team_textures()


func apply_state(animation_state: String, facing_direction: Vector2, delta: float) -> void:
	_ensure_sprites()
	var effective_facing: Vector2 = facing_direction
	if effective_facing.length_squared() > 0.001:
		_last_non_zero_facing = effective_facing.normalized()
	else:
		effective_facing = _last_non_zero_facing
	var next_bucket: String = _bucket_for_facing(effective_facing)
	var next_profile_key: String = _profile_key_for(animation_state, next_bucket)
	var current_profile_key: String = _profile_key_for(_animation_state, _direction_bucket)
	if next_profile_key != current_profile_key:
		_animation_state = animation_state
		_direction_bucket = next_bucket
		_frame_index = 0
		_frame_elapsed = 0.0
	else:
		_animation_state = animation_state
		_direction_bucket = next_bucket
	var profile: Dictionary = _get_profile(next_profile_key)
	var frames: Array = profile.get("frames", [])
	if frames.is_empty():
		return
	var fps: float = float(profile.get("fps", 1.0))
	if delta > 0.0 and frames.size() > 1 and fps > 0.0:
		_frame_elapsed += delta
		var frame_duration: float = 1.0 / fps
		while _frame_elapsed >= frame_duration:
			_frame_elapsed -= frame_duration
			_frame_index += 1
			if bool(profile.get("loop", true)):
				_frame_index %= frames.size()
			else:
				_frame_index = mini(_frame_index, frames.size() - 1)
	_apply_profile_frame()
	_apply_direction_flip(effective_facing)


func has_configured_sprites() -> bool:
	return _fill_sprite != null and _outline_sprite != null and _fill_sprite.texture != null


func _ensure_sprites() -> void:
	if _outline_sprite == null:
		_outline_sprite = Sprite2D.new()
		_outline_sprite.name = "OutlineSprite"
		_outline_sprite.centered = true
		_outline_sprite.region_enabled = true
		_outline_sprite.position = sprite_offset
		_outline_sprite.scale = Vector2.ONE * sprite_base_scale
		_outline_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_outline_sprite)
	if _fill_sprite == null:
		_fill_sprite = Sprite2D.new()
		_fill_sprite.name = "FillSprite"
		_fill_sprite.centered = true
		_fill_sprite.region_enabled = true
		_fill_sprite.position = sprite_offset
		_fill_sprite.scale = Vector2.ONE * sprite_base_scale
		_fill_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_fill_sprite)


func _apply_team_textures() -> void:
	if _fill_sprite == null or _outline_sprite == null:
		return
	if _team_key == "away":
		_fill_sprite.texture = AWAY_FILL_TEXTURE
		_outline_sprite.texture = AWAY_OUTLINE_TEXTURE
	else:
		_fill_sprite.texture = HOME_FILL_TEXTURE
		_outline_sprite.texture = HOME_OUTLINE_TEXTURE


func _apply_profile_frame() -> void:
	if _fill_sprite == null or _outline_sprite == null:
		return
	var profile_key: String = _profile_key_for(_animation_state, _direction_bucket)
	var profile: Dictionary = _get_profile(profile_key)
	var frames: Array = profile.get("frames", [])
	if frames.is_empty():
		return
	_frame_index = clampi(_frame_index, 0, frames.size() - 1)
	var frame: Vector2i = frames[_frame_index]
	var region: Rect2 = Rect2(frame.x * FRAME_SIZE.x, frame.y * FRAME_SIZE.y, FRAME_SIZE.x, FRAME_SIZE.y)
	_fill_sprite.region_rect = region
	_outline_sprite.region_rect = region


func _apply_direction_flip(facing_direction: Vector2) -> void:
	if _fill_sprite == null or _outline_sprite == null:
		return
	var flip_h: bool = absf(facing_direction.x) > 0.12 and facing_direction.x < 0.0
	_fill_sprite.flip_h = flip_h
	_outline_sprite.flip_h = flip_h


func _bucket_for_facing(facing_direction: Vector2) -> String:
	if absf(facing_direction.x) > absf(facing_direction.y):
		return "side"
	if facing_direction.y < -0.1:
		return "up"
	return "down"


func _profile_key_for(animation_state: String, direction_bucket: String) -> String:
	match animation_state:
		"idle", "move":
			return "%s_%s" % [animation_state, direction_bucket]
		_:
			return animation_state


func _get_profile(profile_key: String) -> Dictionary:
	return _profiles.get(profile_key, _profiles["idle_down"])
