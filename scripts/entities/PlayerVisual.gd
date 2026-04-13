class_name PlayerVisual
extends Node2D

const FRAME_SIZE: Vector2i = Vector2i(64, 64)
const ROW_FRAME_COUNTS: Array[int] = [4, 5, 23, 7, 8, 7, 14, 17, 7, 29, 5, 5, 15, 15, 14, 18, 15, 5, 5, 7, 4, 6]
const RELEASE_AFTER_FRAME_BY_ROW: Dictionary = {
	4: 5,
	8: 11,
	10: 23,
	13: 9,
	14: 9,
	15: 10,
	16: 10,
	17: 11,
}
const DEFAULT_DUNK_CONTACT_FRAME_BY_ROW: Dictionary = {
	13: 10,
	15: 11,
	16: 11,
}
const HOME_FILL_TEXTURE: Texture2D = preload("res://assets/Character/Character1_NEW.png")
const HOME_OUTLINE_TEXTURE: Texture2D = preload("res://assets/Character/Character1_NEW_outline.png")
const AWAY_FILL_TEXTURE: Texture2D = preload("res://assets/Character/Character2_NEW.png")
const AWAY_OUTLINE_TEXTURE: Texture2D = preload("res://assets/Character/Character2_NEW_outline.png")

const FAMILY_ROWS: Dictionary = {
	"no_ball_idle": [1],
	"ball_idle_open": [2, 3, 11],
	"ball_hold_secure": [5],
	"ball_idle_pressured": [6, 7],
	"ball_move_small": [12],
	"ball_move_run": [9],
	"shot_aim": [5],
	"set_shot_release": [4],
	"jumper_release": [8, 10],
	"close_finish_layup": [14, 17],
	"close_finish_dunk": [13, 15],
	"close_finish_side_dunk": [16],
	"guard_idle": [18, 21],
	"guard_shuffle": [19],
	"guard_run": [20],
	"off_ball_run": [20],
	"jump_contest": [22],
}

const FAMILY_FPS: Dictionary = {
	"no_ball_idle": 5.0,
	"ball_idle_open": 6.0,
	"ball_hold_secure": 6.0,
	"ball_idle_pressured": 7.0,
	"ball_move_small": 8.0,
	"ball_move_run": 10.0,
	"shot_aim": 15.0,
	"set_shot_release": 15.0,
	"jumper_release": 15.0,
	"close_finish_layup": 15.0,
	"close_finish_dunk": 15.0,
	"close_finish_side_dunk": 15.0,
	"guard_idle": 5.0,
	"guard_shuffle": 8.0,
	"guard_run": 10.0,
	"off_ball_run": 10.0,
	"jump_contest": 14.0,
}

const NON_LOOPING_FAMILIES: Dictionary = {
	"set_shot_release": true,
	"jumper_release": true,
	"close_finish_layup": true,
	"close_finish_dunk": true,
	"close_finish_side_dunk": true,
	"jump_contest": true,
}

@export var sprite_offset: Vector2 = Vector2(0.0, -72.0)
@export var sprite_base_scale: float = 2.3

var animation_config: PlayerAnimationConfig
var _fill_sprite: Sprite2D
var _outline_sprite: Sprite2D
var _team_key: String = "home"
var _animation_family: String = "no_ball_idle"
var _variant_index: int = 0
var _current_row_index: int = 1
var _frame_index: int = 0
var _frame_elapsed: float = 0.0
var _mirror_west: bool = false
var _show_outline: bool = false
var _release_after_frame: int = -1
var _release_ready_this_tick: bool = false
var _world_ball_release_ready_this_tick: bool = false
var _animation_elapsed: float = 0.0
var _animation_completed: bool = false
var _allow_dunk_contact_hold: bool = false
var _dunk_contact_hold_active: bool = false
var _dunk_contact_hold_finished: bool = false
var _dunk_contact_hold_remaining: float = 0.0


func _ready() -> void:
	_ensure_sprites()
	_apply_team_textures()
	_apply_current_frame()
	_apply_sprite_flags()


func set_team_key(team_key: String) -> void:
	_team_key = team_key
	_apply_team_textures()


func set_animation_config(config_value: PlayerAnimationConfig) -> void:
	animation_config = config_value
	_sync_sprite_positions()


func apply_state(request, delta: float) -> void:
	_ensure_sprites()
	if request == null:
		return
	var next_family: String = request.animation_family if FAMILY_ROWS.has(request.animation_family) else "no_ball_idle"
	var next_rows: Array = FAMILY_ROWS.get(next_family, [1])
	var next_variant: int = clampi(request.variant_index, 0, maxi(next_rows.size() - 1, 0))
	var next_row: int = int(next_rows[next_variant])
	var should_restart: bool = request.force_restart \
		or next_family != _animation_family \
		or next_variant != _variant_index \
		or next_row != _current_row_index
	var previous_frame_number: int = 1 if should_restart else _frame_index + 1
	_animation_family = next_family
	_variant_index = next_variant
	_current_row_index = next_row
	_mirror_west = request.mirror_west
	_show_outline = request.show_outline
	_allow_dunk_contact_hold = bool(request.allow_dunk_contact_hold)
	_release_after_frame = int(RELEASE_AFTER_FRAME_BY_ROW.get(_current_row_index, -1))
	_release_ready_this_tick = false
	_world_ball_release_ready_this_tick = false
	var start_hold_on_entry: bool = false
	if should_restart:
		_frame_index = 0
		_frame_elapsed = 0.0
		_animation_elapsed = 0.0
		_animation_completed = false
		_reset_dunk_contact_hold()
	elif _should_use_dunk_contact_hold() and not _dunk_contact_hold_finished and not _dunk_contact_hold_active \
		and _frame_index + 1 >= _get_dunk_contact_frame_for_row(_current_row_index):
		_start_dunk_contact_hold()
		start_hold_on_entry = true
	_advance_frames(0.0 if start_hold_on_entry else delta)
	_release_ready_this_tick = _is_release_crossed(previous_frame_number)
	if not _should_use_dunk_contact_hold():
		_world_ball_release_ready_this_tick = _release_ready_this_tick
	_apply_current_frame()
	_apply_sprite_flags()


func has_configured_sprites() -> bool:
	return _fill_sprite != null and _outline_sprite != null and _fill_sprite.texture != null


func get_debug_animation_family() -> String:
	return _animation_family


func get_debug_row_index() -> int:
	return _current_row_index


func get_debug_variant_index() -> int:
	return _variant_index


func get_debug_frame_number() -> int:
	return _frame_index + 1


func get_debug_release_after_frame() -> int:
	return _release_after_frame


func get_current_animation_elapsed_time() -> float:
	return _animation_elapsed


func is_current_animation_complete() -> bool:
	return _animation_completed


func get_current_animation_timing_profile() -> Dictionary:
	var profile: Dictionary = build_timing_profile_for_family_variant(_animation_family, _variant_index)
	profile["dunk_contact_frame"] = get_debug_dunk_contact_frame()
	profile["dunk_contact_hold_seconds"] = _get_dunk_contact_hold_seconds()
	profile["dunk_contact_hold_active"] = _dunk_contact_hold_active
	return profile


func is_ball_release_ready() -> bool:
	return _release_ready_this_tick


func is_world_ball_release_ready() -> bool:
	return _world_ball_release_ready_this_tick


func get_debug_dunk_contact_frame() -> int:
	return _get_dunk_contact_frame_for_row(_current_row_index)


func is_dunk_contact_hold_active() -> bool:
	return _dunk_contact_hold_active


func get_debug_dunk_contact_hold_remaining() -> float:
	return _dunk_contact_hold_remaining


func get_debug_flip_h() -> bool:
	return _fill_sprite != null and _fill_sprite.flip_h


func is_outline_visible() -> bool:
	return _outline_sprite != null and _outline_sprite.visible


func get_debug_fill_texture_path() -> String:
	if _fill_sprite == null or _fill_sprite.texture == null:
		return ""
	return _fill_sprite.texture.resource_path


func _ensure_sprites() -> void:
	if _outline_sprite == null:
		_outline_sprite = Sprite2D.new()
		_outline_sprite.name = "OutlineSprite"
		_outline_sprite.centered = true
		_outline_sprite.region_enabled = true
		_outline_sprite.scale = Vector2.ONE * sprite_base_scale
		_outline_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_outline_sprite)
	if _fill_sprite == null:
		_fill_sprite = Sprite2D.new()
		_fill_sprite.name = "FillSprite"
		_fill_sprite.centered = true
		_fill_sprite.region_enabled = true
		_fill_sprite.scale = Vector2.ONE * sprite_base_scale
		_fill_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_fill_sprite)
	_sync_sprite_positions()


func _apply_team_textures() -> void:
	if _fill_sprite == null or _outline_sprite == null:
		return
	if _team_key == "away":
		_fill_sprite.texture = AWAY_FILL_TEXTURE
		_outline_sprite.texture = AWAY_OUTLINE_TEXTURE
	else:
		_fill_sprite.texture = HOME_FILL_TEXTURE
		_outline_sprite.texture = HOME_OUTLINE_TEXTURE


func _advance_frames(delta: float) -> void:
	var frame_count: int = _get_frame_count_for_row(_current_row_index)
	var timing_profile: Dictionary = build_timing_profile_for_family_variant(_animation_family, _variant_index)
	var full_duration: float = float(timing_profile.get("full_animation_duration_seconds", 0.0))
	if delta > 0.0:
		if _is_looping_family(_animation_family) or full_duration <= 0.0:
			_animation_elapsed += delta
		else:
			_animation_elapsed = minf(_animation_elapsed + delta, full_duration)
	if delta <= 0.0 or frame_count <= 1:
		_animation_completed = not _is_looping_family(_animation_family) and _frame_index >= frame_count - 1
		return
	if _dunk_contact_hold_active:
		_dunk_contact_hold_remaining = maxf(_dunk_contact_hold_remaining - delta, 0.0)
		if _dunk_contact_hold_remaining <= 0.0:
			_dunk_contact_hold_active = false
			_dunk_contact_hold_finished = true
			_world_ball_release_ready_this_tick = true
		_animation_completed = not _is_looping_family(_animation_family) and _frame_index >= frame_count - 1
		return
	var fps: float = float(FAMILY_FPS.get(_animation_family, 6.0))
	if fps <= 0.0:
		_animation_completed = not _is_looping_family(_animation_family) and _frame_index >= frame_count - 1
		return
	var frame_duration: float = 1.0 / fps
	_frame_elapsed += delta
	while _frame_elapsed >= frame_duration:
		_frame_elapsed -= frame_duration
		_frame_index += 1
		if _is_looping_family(_animation_family):
			_frame_index %= frame_count
		else:
			_frame_index = mini(_frame_index, frame_count - 1)
		if _should_start_dunk_contact_hold():
			_start_dunk_contact_hold()
			_animation_completed = false
			return
	_animation_completed = not _is_looping_family(_animation_family) and _frame_index >= frame_count - 1


func _is_release_crossed(previous_frame_number: int) -> bool:
	if _release_after_frame <= 0:
		return false
	if _is_looping_family(_animation_family):
		return false
	var current_frame_number: int = _frame_index + 1
	return previous_frame_number <= _release_after_frame and current_frame_number > _release_after_frame


func _apply_current_frame() -> void:
	if _fill_sprite == null or _outline_sprite == null:
		return
	var frame_count: int = _get_frame_count_for_row(_current_row_index)
	if frame_count <= 0:
		return
	_frame_index = clampi(_frame_index, 0, frame_count - 1)
	var region: Rect2 = Rect2(
		_frame_index * FRAME_SIZE.x,
		(_current_row_index - 1) * FRAME_SIZE.y,
		FRAME_SIZE.x,
		FRAME_SIZE.y
	)
	_fill_sprite.region_rect = region
	_outline_sprite.region_rect = region


func _apply_sprite_flags() -> void:
	if _fill_sprite == null or _outline_sprite == null:
		return
	_fill_sprite.flip_h = _mirror_west
	_outline_sprite.flip_h = _mirror_west
	_outline_sprite.visible = _show_outline
	_sync_sprite_positions()


func _sync_sprite_positions() -> void:
	if _fill_sprite == null or _outline_sprite == null:
		return
	var active_offset: Vector2 = _get_active_sprite_offset()
	_fill_sprite.position = active_offset
	_outline_sprite.position = active_offset


func _get_active_sprite_offset() -> Vector2:
	var active_offset: Vector2 = sprite_offset
	var contact_frame: int = _get_dunk_contact_frame_for_row(_current_row_index)
	var should_apply_contact_offset: bool = _dunk_contact_hold_active \
		or (_dunk_contact_hold_finished and _frame_index + 1 == contact_frame and _allow_dunk_contact_hold)
	if should_apply_contact_offset:
		var extra_offset: Vector2 = _get_dunk_contact_offset_for_row(_current_row_index)
		if _mirror_west:
			extra_offset.x *= -1.0
		active_offset += extra_offset
	return active_offset


func _get_frame_count_for_row(row_index: int) -> int:
	if row_index < 1 or row_index > ROW_FRAME_COUNTS.size():
		return ROW_FRAME_COUNTS[0]
	return ROW_FRAME_COUNTS[row_index - 1]


func _is_looping_family(animation_family: String) -> bool:
	return not NON_LOOPING_FAMILIES.has(animation_family)


func _should_use_dunk_contact_hold() -> bool:
	return _allow_dunk_contact_hold and _get_dunk_contact_frame_for_row(_current_row_index) > 0


func _should_start_dunk_contact_hold() -> bool:
	if not _should_use_dunk_contact_hold() or _dunk_contact_hold_finished or _dunk_contact_hold_active:
		return false
	return _frame_index + 1 >= _get_dunk_contact_frame_for_row(_current_row_index)


func _start_dunk_contact_hold() -> void:
	_frame_index = clampi(_get_dunk_contact_frame_for_row(_current_row_index) - 1, 0, _get_frame_count_for_row(_current_row_index) - 1)
	_frame_elapsed = 0.0
	_dunk_contact_hold_active = true
	_dunk_contact_hold_remaining = _get_dunk_contact_hold_seconds()


func _reset_dunk_contact_hold() -> void:
	_dunk_contact_hold_active = false
	_dunk_contact_hold_finished = false
	_dunk_contact_hold_remaining = 0.0


func _get_dunk_contact_hold_seconds() -> float:
	if animation_config != null:
		return maxf(animation_config.dunk_contact_hold_seconds, 0.0)
	return 0.5


func _get_dunk_contact_frame_for_row(row_index: int) -> int:
	if animation_config != null:
		match row_index:
			13:
				return animation_config.dunk_contact_frame_row_13
			15:
				return animation_config.dunk_contact_frame_row_15
			16:
				return animation_config.dunk_contact_frame_row_16
	return int(DEFAULT_DUNK_CONTACT_FRAME_BY_ROW.get(row_index, -1))


func _get_dunk_contact_offset_for_row(row_index: int) -> Vector2:
	if animation_config != null:
		match row_index:
			13:
				return animation_config.dunk_contact_offset_row_13
			15:
				return animation_config.dunk_contact_offset_row_15
			16:
				return animation_config.dunk_contact_offset_row_16
	return Vector2.ZERO


static func get_row_index_for_family_variant(animation_family: String, variant_index: int) -> int:
	var rows: Array = FAMILY_ROWS.get(animation_family, [1])
	var clamped_variant: int = clampi(variant_index, 0, maxi(rows.size() - 1, 0))
	return int(rows[clamped_variant])


static func build_timing_profile_for_family_variant(animation_family: String, variant_index: int) -> Dictionary:
	var row_index: int = get_row_index_for_family_variant(animation_family, variant_index)
	return build_timing_profile_for_row(row_index, animation_family)


static func build_timing_profile_for_row(row_index: int, animation_family: String = "") -> Dictionary:
	var resolved_row_index: int = clampi(row_index, 1, ROW_FRAME_COUNTS.size())
	var total_frames: int = ROW_FRAME_COUNTS[resolved_row_index - 1]
	var fps: float = float(FAMILY_FPS.get(animation_family, 15.0))
	var release_after_frame: int = int(RELEASE_AFTER_FRAME_BY_ROW.get(resolved_row_index, -1))
	var release_time_seconds: float = 0.0
	if release_after_frame > 0 and fps > 0.0:
		release_time_seconds = float(release_after_frame) / fps
	return {
		"row_index": resolved_row_index,
		"total_frames": total_frames,
		"release_after_frame": release_after_frame,
		"fps": fps,
		"release_time_seconds": release_time_seconds,
		"full_animation_duration_seconds": float(total_frames) / maxf(fps, 0.001),
	}
