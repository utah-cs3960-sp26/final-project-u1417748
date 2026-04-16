class_name HoopView
extends Node2D

const HOOP_ATLAS: Texture2D = preload("res://assets/Court/Court.png")

const BALL_RENDER_PHASE_BEHIND_BACKBOARD: String = "behind_backboard"
const BALL_RENDER_PHASE_RIM_MOUTH: String = "rim_mouth"
const BALL_RENDER_PHASE_NET_CHANNEL: String = "net_channel"
const BALL_RENDER_PHASE_FRONT_OF_NET: String = "front_of_net"
const BALL_RENDER_PHASE_BETWEEN_BOARD_AND_NET: String = BALL_RENDER_PHASE_NET_CHANNEL

const BALL_RENDER_Z_OFFSET_BEHIND_BACKBOARD: int = 2
const BALL_RENDER_Z_OFFSET_RIM_MOUTH: int = 29
const BALL_RENDER_Z_OFFSET_NET_CHANNEL: int = 30
const BALL_RENDER_Z_OFFSET_FRONT_OF_NET: int = 31

const BACKBOARD_Z_INDEX: int = -20
const REAR_HOOP_Z_INDEX: int = -8
const FRONT_RIM_Z_INDEX: int = 3
const BOTTOM_HALF_NET_INACTIVE_Z_INDEX: int = 4
const BOTTOM_HALF_NET_ACTIVE_Z_INDEX: int = 8
const FRONT_NET_Z_INDEX: int = 9
const BALL_RENDER_EXIT_SCREEN_MARGIN: float = 16.0

@export var hoop_body_region: Rect2 = Rect2(1011.0, 17.0, 61.0, 95.0)
@export var hoop_rear_texture_path: String = "res://assets/Court/Net.png"
@export var hoop_front_rim_texture_path: String = "res://assets/Court/NetClean.png"
@export var hoop_bottom_half_net_texture_path: String = "res://assets/Court/NetCleanBottomHalf.png"
@export var hoop_front_net_texture_path: String = "res://assets/Court/NetBody.png"
@export var hoop_body_scale: float = 2.25
@export var hoop_rear_scale: float = 1.6
@export var hoop_front_rim_scale: float = 1.6
@export var hoop_bottom_half_net_scale: float = 1.6
@export var hoop_front_net_scale: float = 1.6
@export var hoop_body_rim_anchor: Vector2 = Vector2(22.0, 19.0)
@export var hoop_rear_rim_anchor: Vector2 = Vector2(15.0, 4.0)
@export var hoop_front_rim_anchor: Vector2 = Vector2(15.0, 4.0)
@export var hoop_bottom_half_net_rim_anchor: Vector2 = Vector2(15.0, 4.0)
@export var hoop_front_net_rim_anchor: Vector2 = Vector2(15.0, 4.0)
@export var hoop_body_offset: Vector2 = Vector2.ZERO
@export var hoop_rear_offset: Vector2 = Vector2(0.0, 12.0)
@export var hoop_front_rim_offset: Vector2 = Vector2(0.0, 12.0)
@export var hoop_bottom_half_net_offset: Vector2 = Vector2(0.0, 12.0)
@export var hoop_front_net_offset: Vector2 = Vector2(0.0, 12.0)

var court_config: CourtConfig
var projection

var _backboard_sprite: Sprite2D
var _rear_hoop_sprite: Sprite2D
var _front_rim_sprite: Sprite2D
var _bottom_half_net_sprite: Sprite2D
var _front_net_sprite: Sprite2D
var _texture_cache: Dictionary = {}
var _net_swish_active: bool = false
var _net_swish_elapsed: float = 0.0
var _net_swish_duration: float = 0.0
var _net_swish_direction: float = 1.0
var _bottom_half_net_mask_active: bool = false


func setup(config_value: CourtConfig, projection_value = null) -> void:
	court_config = config_value
	projection = projection_value
	_ensure_sprites()
	queue_redraw()


func set_projection(projection_value) -> void:
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
	return supports_four_layer_visuals()


func supports_three_piece_visuals() -> bool:
	return supports_four_layer_visuals()


func supports_four_layer_visuals() -> bool:
	return _backboard_sprite != null \
		and _rear_hoop_sprite != null \
		and _front_rim_sprite != null \
		and _bottom_half_net_sprite != null \
		and _front_net_sprite != null \
		and _backboard_sprite.texture != null \
		and _rear_hoop_sprite.texture != null \
		and _front_rim_sprite.texture != null \
		and _bottom_half_net_sprite.texture != null \
		and _front_net_sprite.texture != null


func supports_render_phases() -> bool:
	return supports_four_layer_visuals()


func get_visual_top_screen_y() -> float:
	if not supports_four_layer_visuals():
		return global_position.y
	var min_local_y: float = _backboard_sprite.position.y
	min_local_y = minf(min_local_y, _rear_hoop_sprite.position.y)
	min_local_y = minf(min_local_y, _front_rim_sprite.position.y)
	min_local_y = minf(min_local_y, _bottom_half_net_sprite.position.y)
	min_local_y = minf(min_local_y, _front_net_sprite.position.y)
	return global_position.y + min_local_y


func get_debug_finish_radius_center_screen() -> Vector2:
	if _backboard_sprite == null:
		return global_position
	var body_scale: float = hoop_body_scale * _get_visual_scale_multiplier()
	var pole_bottom_y: float = global_position.y + _backboard_sprite.position.y + hoop_body_region.size.y * body_scale
	return Vector2(global_position.x, pole_bottom_y)


func get_ball_render_phase(
	world_position: Vector2,
	z_value: float,
	is_descending: bool = false,
	force_net_channel: bool = false,
	ball_radius: float = 14.0
) -> String:
	if court_config == null:
		return BALL_RENDER_PHASE_FRONT_OF_NET
	if force_net_channel:
		return BALL_RENDER_PHASE_NET_CHANNEL if z_value > court_config.net_exit_z else BALL_RENDER_PHASE_FRONT_OF_NET
	var distance_to_hoop: float = world_position.distance_to(court_config.hoop_position)
	var on_board_side: bool = world_position.y <= court_config.backboard_y + ball_radius * 0.2
	if on_board_side and z_value < court_config.over_backboard_z_threshold:
		return BALL_RENDER_PHASE_BEHIND_BACKBOARD
	if not is_descending:
		return BALL_RENDER_PHASE_FRONT_OF_NET
	var rim_mouth_radius: float = court_config.rim_inner_radius + ball_radius * 0.18
	var rim_floor_z: float = maxf(court_config.rim_height - ball_radius * 0.55, court_config.net_exit_z + 18.0)
	var in_rim_mouth: bool = (
		distance_to_hoop <= rim_mouth_radius
		and z_value <= court_config.rim_height + ball_radius * 0.95
		and z_value >= rim_floor_z
	)
	if in_rim_mouth:
		return BALL_RENDER_PHASE_RIM_MOUTH
	var channel_radius: float = court_config.net_channel_radius + ball_radius * 0.35
	var in_net_channel: bool = (
		distance_to_hoop <= channel_radius
		and z_value < rim_floor_z
		and z_value >= court_config.net_exit_z
	)
	if in_net_channel:
		return BALL_RENDER_PHASE_NET_CHANNEL
	return BALL_RENDER_PHASE_FRONT_OF_NET


func get_ball_z_index_for_phase(phase: String) -> int:
	var base_depth: int = _get_hoop_depth_key()
	match phase:
		BALL_RENDER_PHASE_BEHIND_BACKBOARD:
			return base_depth + BALL_RENDER_Z_OFFSET_BEHIND_BACKBOARD
		BALL_RENDER_PHASE_RIM_MOUTH:
			return base_depth + BALL_RENDER_Z_OFFSET_RIM_MOUTH
		BALL_RENDER_PHASE_NET_CHANNEL:
			return base_depth + BALL_RENDER_Z_OFFSET_NET_CHANNEL
		BALL_RENDER_PHASE_FRONT_OF_NET:
			return base_depth + BALL_RENDER_Z_OFFSET_FRONT_OF_NET
		_:
			return base_depth + BALL_RENDER_Z_OFFSET_NET_CHANNEL


func set_bottom_half_net_mask_active(active: bool) -> void:
	if _bottom_half_net_mask_active == active:
		return
	_bottom_half_net_mask_active = active
	_apply_bottom_half_net_z_index()


func is_bottom_half_net_mask_active() -> bool:
	return _bottom_half_net_mask_active


func get_layering_snapshot() -> Dictionary:
	var base_depth: int = _get_hoop_depth_key()
	var parent_z: int = z_index
	return {
		"supports_four_layer_visuals": supports_four_layer_visuals(),
		"bottom_half_mask_active": _bottom_half_net_mask_active,
		"bottom_half_net_inactive_z_index": BOTTOM_HALF_NET_INACTIVE_Z_INDEX,
		"bottom_half_net_active_z_index": BOTTOM_HALF_NET_ACTIVE_Z_INDEX,
		"bottom_half_net_inactive_effective_z_index": parent_z + BOTTOM_HALF_NET_INACTIVE_Z_INDEX,
		"bottom_half_net_active_effective_z_index": parent_z + BOTTOM_HALF_NET_ACTIVE_Z_INDEX,
		"base_depth": base_depth,
		"parent_z_index": parent_z,
		"layers": {
			"hoop_body": _build_layer_snapshot(_backboard_sprite, hoop_body_region.size, parent_z),
			"net": _build_layer_snapshot(_rear_hoop_sprite, _get_texture_size(hoop_rear_texture_path), parent_z),
			"net_clean": _build_layer_snapshot(_front_rim_sprite, _get_texture_size(hoop_front_rim_texture_path), parent_z),
			"net_clean_bottom_half": _build_layer_snapshot(_bottom_half_net_sprite, _get_texture_size(hoop_bottom_half_net_texture_path), parent_z),
			"net_body": _build_layer_snapshot(_front_net_sprite, _get_texture_size(hoop_front_net_texture_path), parent_z),
		},
		"ball_phases": {
			BALL_RENDER_PHASE_BEHIND_BACKBOARD: get_ball_z_index_for_phase(BALL_RENDER_PHASE_BEHIND_BACKBOARD),
			BALL_RENDER_PHASE_RIM_MOUTH: get_ball_z_index_for_phase(BALL_RENDER_PHASE_RIM_MOUTH),
			BALL_RENDER_PHASE_NET_CHANNEL: get_ball_z_index_for_phase(BALL_RENDER_PHASE_NET_CHANNEL),
			BALL_RENDER_PHASE_FRONT_OF_NET: get_ball_z_index_for_phase(BALL_RENDER_PHASE_FRONT_OF_NET),
		},
	}


func get_front_net_exit_screen_y() -> float:
	if projection == null or court_config == null:
		return 0.0
	var visual_scale: float = _get_visual_scale_multiplier()
	return position.y \
		+ hoop_front_net_offset.y * visual_scale \
		+ (_get_front_net_height() - hoop_front_net_rim_anchor.y) * hoop_front_net_scale * visual_scale \
		+ BALL_RENDER_EXIT_SCREEN_MARGIN * visual_scale


func trigger_net_swish(entry_offset_x: float = 0.0) -> void:
	if court_config == null:
		return
	_net_swish_active = true
	_net_swish_elapsed = 0.0
	_net_swish_duration = maxf(court_config.net_swish_duration, 0.01)
	_net_swish_direction = 1.0 if is_zero_approx(entry_offset_x) else signf(entry_offset_x)
	_apply_front_net_transform()


func stop_net_swish() -> void:
	_net_swish_active = false
	_net_swish_elapsed = 0.0
	_net_swish_duration = 0.0
	_net_swish_direction = 1.0
	_apply_front_net_transform()


func advance_visual_animation(delta: float) -> void:
	if not _net_swish_active:
		return
	_net_swish_elapsed = minf(_net_swish_elapsed + delta, _net_swish_duration)
	if _net_swish_elapsed >= _net_swish_duration:
		_net_swish_active = false
	_apply_front_net_transform()


func is_net_swish_active() -> bool:
	return _net_swish_active


func _ensure_sprites() -> void:
	if _backboard_sprite == null:
		_backboard_sprite = Sprite2D.new()
		_backboard_sprite.name = "HoopBodySprite"
		_backboard_sprite.texture = HOOP_ATLAS
		_backboard_sprite.region_enabled = true
		_backboard_sprite.region_rect = hoop_body_region
		_backboard_sprite.centered = false
		_backboard_sprite.scale = Vector2.ONE * hoop_body_scale
		_backboard_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_backboard_sprite.z_index = BACKBOARD_Z_INDEX
		add_child(_backboard_sprite)
	if _rear_hoop_sprite == null:
		_rear_hoop_sprite = Sprite2D.new()
		_rear_hoop_sprite.name = "RearHoopSprite"
		_rear_hoop_sprite.texture = _get_texture(hoop_rear_texture_path)
		_rear_hoop_sprite.centered = false
		_rear_hoop_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_rear_hoop_sprite.z_index = REAR_HOOP_Z_INDEX
		add_child(_rear_hoop_sprite)
	if _front_rim_sprite == null:
		_front_rim_sprite = Sprite2D.new()
		_front_rim_sprite.name = "FrontRimSprite"
		_front_rim_sprite.texture = _get_texture(hoop_front_rim_texture_path)
		_front_rim_sprite.centered = false
		_front_rim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_front_rim_sprite.z_index = FRONT_RIM_Z_INDEX
		add_child(_front_rim_sprite)
	if _bottom_half_net_sprite == null:
		_bottom_half_net_sprite = Sprite2D.new()
		_bottom_half_net_sprite.name = "BottomHalfNetSprite"
		_bottom_half_net_sprite.texture = _get_texture(hoop_bottom_half_net_texture_path)
		_bottom_half_net_sprite.centered = false
		_bottom_half_net_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_apply_bottom_half_net_z_index()
		add_child(_bottom_half_net_sprite)
	if _front_net_sprite == null:
		_front_net_sprite = Sprite2D.new()
		_front_net_sprite.name = "FrontNetSprite"
		_front_net_sprite.texture = _get_texture(hoop_front_net_texture_path)
		_front_net_sprite.centered = false
		_front_net_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_front_net_sprite.z_index = FRONT_NET_Z_INDEX
		add_child(_front_net_sprite)
	_sync_sprite_positions()


func _sync_sprite_positions() -> void:
	if not supports_four_layer_visuals():
		return
	var visual_scale: float = _get_visual_scale_multiplier()
	var body_scale: float = hoop_body_scale * visual_scale
	var rear_scale: float = hoop_rear_scale * visual_scale
	var front_rim_scale: float = hoop_front_rim_scale * visual_scale
	var bottom_half_net_scale: float = hoop_bottom_half_net_scale * visual_scale
	_backboard_sprite.region_rect = hoop_body_region
	_backboard_sprite.scale = Vector2.ONE * body_scale
	_backboard_sprite.position = hoop_body_offset * visual_scale - hoop_body_rim_anchor * body_scale
	_rear_hoop_sprite.texture = _get_texture(hoop_rear_texture_path)
	_rear_hoop_sprite.scale = Vector2.ONE * rear_scale
	_rear_hoop_sprite.position = _base_overlay_position(hoop_rear_offset * visual_scale, hoop_rear_rim_anchor, rear_scale)
	_front_rim_sprite.texture = _get_texture(hoop_front_rim_texture_path)
	_front_rim_sprite.scale = Vector2.ONE * front_rim_scale
	_front_rim_sprite.position = _base_overlay_position(hoop_front_rim_offset * visual_scale, hoop_front_rim_anchor, front_rim_scale)
	_bottom_half_net_sprite.texture = _get_texture(hoop_bottom_half_net_texture_path)
	_bottom_half_net_sprite.scale = Vector2.ONE * bottom_half_net_scale
	_bottom_half_net_sprite.position = _base_overlay_position(hoop_bottom_half_net_offset * visual_scale, hoop_bottom_half_net_rim_anchor, bottom_half_net_scale)
	_front_net_sprite.texture = _get_texture(hoop_front_net_texture_path)
	_apply_front_net_transform()


func _apply_bottom_half_net_z_index() -> void:
	if _bottom_half_net_sprite == null:
		return
	_bottom_half_net_sprite.z_index = BOTTOM_HALF_NET_ACTIVE_Z_INDEX if _bottom_half_net_mask_active else BOTTOM_HALF_NET_INACTIVE_Z_INDEX


func _base_overlay_position(offset: Vector2, anchor: Vector2, scale_value: float) -> Vector2:
	return offset - anchor * scale_value


func _apply_front_net_transform() -> void:
	if _front_net_sprite == null:
		return
	var visual_scale: float = _get_visual_scale_multiplier()
	var scaled_scale: float = hoop_front_net_scale * visual_scale
	var base_position: Vector2 = _base_overlay_position(hoop_front_net_offset * visual_scale, hoop_front_net_rim_anchor, scaled_scale)
	var base_scale: Vector2 = Vector2.ONE * scaled_scale
	_front_net_sprite.position = base_position
	_front_net_sprite.scale = base_scale
	if not _net_swish_active or court_config == null or _net_swish_duration <= 0.0:
		return
	var progress: float = clampf(_net_swish_elapsed / _net_swish_duration, 0.0, 1.0)
	var envelope: float = sin(progress * PI) * (1.0 - progress * 0.2)
	var sway: float = court_config.net_swish_sway_amplitude * envelope * sin(progress * PI * 2.0) * _net_swish_direction
	var stretch_ratio: float = 1.0 + court_config.net_swish_stretch * envelope
	var width_ratio: float = 1.0 - court_config.net_swish_stretch * 0.35 * envelope
	_front_net_sprite.position = base_position + Vector2(sway, 0.0)
	_front_net_sprite.scale = Vector2(base_scale.x * width_ratio, base_scale.y * stretch_ratio)


func _get_visual_scale_multiplier() -> float:
	if projection == null:
		return 1.0
	return projection.get_hoop_visual_scale_multiplier()


func _get_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var loaded_texture: Texture2D = null
	if ResourceLoader.exists(path, "Texture2D") or ResourceLoader.exists(path):
		loaded_texture = load(path) as Texture2D
	if loaded_texture == null and FileAccess.file_exists(path):
		var image: Image = Image.load_from_file(path)
		if not image.is_empty():
			loaded_texture = ImageTexture.create_from_image(image)
	if loaded_texture != null:
		_texture_cache[path] = loaded_texture
	return loaded_texture


func _get_texture_size(path: String) -> Vector2:
	var texture: Texture2D = _get_texture(path)
	if texture == null:
		return Vector2.ZERO
	return Vector2(float(texture.get_width()), float(texture.get_height()))


func _build_layer_snapshot(sprite: Sprite2D, texture_size: Vector2, parent_z: int) -> Dictionary:
	if sprite == null:
		return {
			"visible": false,
			"z_index": 0,
			"effective_z_index": parent_z,
			"texture_size": texture_size,
			"position": Vector2.ZERO,
			"scale": Vector2.ZERO,
		}
	return {
		"visible": sprite.visible and sprite.texture != null,
		"z_index": sprite.z_index,
		"effective_z_index": parent_z + sprite.z_index,
		"texture_size": texture_size,
		"position": sprite.position,
		"scale": sprite.scale,
	}


func _get_front_net_height() -> float:
	var texture: Texture2D = _get_texture(hoop_front_net_texture_path)
	return float(texture.get_height()) if texture != null else 28.0


func _get_hoop_depth_key() -> int:
	if projection != null and court_config != null:
		return int(round(projection.depth_key(court_config.hoop_position)))
	return int(round(position.y))
