class_name PlayerAnimationConfig
extends Resource

const DUNK_SMART_START_DISTANCE_EPSILON: float = 0.01

@export var stationary_speed_threshold: float = 18.0
@export var stationary_speed_release_threshold: float = 12.0
@export var small_move_speed_threshold: float = 110.0
@export var small_move_speed_release_threshold: float = 88.0
@export var facing_switch_min_vector_length: float = 24.0
@export var facing_switch_normalized_x_threshold: float = 0.22
@export var close_finish_radius: float = 200.0
@export var dunk_finish_radius: float = 135.0
@export var side_finish_lateral_threshold: float = 70.0
@export var finish_momentum_speed_threshold: float = 70.0
@export var dunk_momentum_speed_threshold: float = 95.0
@export var dunk_rating_min: int = 60
@export var set_shot_space_radius: float = 150.0
@export var toward_hoop_dot_threshold: float = 0.35
@export var dunk_contact_hold_seconds: float = 0.5
@export var dunk_contact_frame_row_13: int = 10
@export var dunk_contact_frame_row_15: int = 11
@export var dunk_contact_frame_row_16: int = 11
@export var dunk_run_end_frame_row_13: int = 7
@export var dunk_run_end_frame_row_15: int = 7
@export var dunk_run_end_frame_row_16: int = 7
@export var dunk_jump_end_frame_row_13: int = 9
@export var dunk_jump_end_frame_row_15: int = 10
@export var dunk_jump_end_frame_row_16: int = 10
@export var dunk_contact_end_frame_row_13: int = 10
@export var dunk_contact_end_frame_row_15: int = 11
@export var dunk_contact_end_frame_row_16: int = 12
@export var dunk_smart_start_short_distance: float = 90.0
@export var dunk_smart_start_medium_distance: float = 120.0
@export var dunk_contact_anchor_offset_row_13: Vector2 = Vector2(-20.0, 172.0)
@export var dunk_contact_anchor_offset_row_15: Vector2 = Vector2(-30.0, 162.0)
@export var dunk_contact_anchor_offset_row_16: Vector2 = Vector2(-42.0, 160.0)
@export var dunk_landing_anchor_offset_row_13: Vector2 = Vector2(-20.0, 268.0)
@export var dunk_landing_anchor_offset_row_15: Vector2 = Vector2(-30.0, 258.0)
@export var dunk_landing_anchor_offset_row_16: Vector2 = Vector2(-42.0, 256.0)
@export var dunk_landing_ease_power: float = 1.8


func get_dunk_contact_frame(row_index: int) -> int:
	match row_index:
		13:
			return dunk_contact_frame_row_13
		15:
			return dunk_contact_frame_row_15
		16:
			return dunk_contact_frame_row_16
	return -1


func get_dunk_run_end_frame(row_index: int) -> int:
	match row_index:
		13:
			return dunk_run_end_frame_row_13
		15:
			return dunk_run_end_frame_row_15
		16:
			return dunk_run_end_frame_row_16
	return -1


func get_dunk_jump_end_frame(row_index: int) -> int:
	match row_index:
		13:
			return dunk_jump_end_frame_row_13
		15:
			return dunk_jump_end_frame_row_15
		16:
			return dunk_jump_end_frame_row_16
	return -1


func get_dunk_contact_end_frame(row_index: int) -> int:
	match row_index:
		13:
			return dunk_contact_end_frame_row_13
		15:
			return dunk_contact_end_frame_row_15
		16:
			return dunk_contact_end_frame_row_16
	return -1


func get_dunk_jump_start_frame(row_index: int) -> int:
	return max(get_dunk_run_end_frame(row_index) + 1, 1)


func get_dunk_medium_start_frame(row_index: int) -> int:
	return max(get_dunk_run_end_frame(row_index) - 2, 1)


func get_dunk_approach_bucket(distance_to_hoop: float) -> String:
	var short_distance: float = maxf(dunk_smart_start_short_distance, 0.0)
	var medium_distance: float = maxf(dunk_smart_start_medium_distance, short_distance)
	if distance_to_hoop <= short_distance + DUNK_SMART_START_DISTANCE_EPSILON:
		return "short"
	if distance_to_hoop < medium_distance - DUNK_SMART_START_DISTANCE_EPSILON:
		return "medium"
	return "max"


func resolve_dunk_approach_start_frame(row_index: int, distance_to_hoop: float) -> int:
	var contact_frame: int = get_dunk_contact_frame(row_index)
	if contact_frame <= 1:
		return 1
	var jump_start_frame: int = clampi(get_dunk_jump_start_frame(row_index), 1, contact_frame - 1)
	var medium_start_frame: int = clampi(get_dunk_medium_start_frame(row_index), 1, jump_start_frame)
	var short_distance: float = maxf(dunk_smart_start_short_distance, 0.0)
	var medium_distance: float = maxf(dunk_smart_start_medium_distance, short_distance)
	if distance_to_hoop >= dunk_finish_radius - DUNK_SMART_START_DISTANCE_EPSILON:
		return 1
	if distance_to_hoop <= short_distance + DUNK_SMART_START_DISTANCE_EPSILON:
		return jump_start_frame
	if distance_to_hoop < medium_distance - DUNK_SMART_START_DISTANCE_EPSILON:
		var medium_alpha: float = inverse_lerp(short_distance, medium_distance, clampf(distance_to_hoop, short_distance, medium_distance))
		return clampi(ceili(lerpf(float(jump_start_frame), float(medium_start_frame), medium_alpha)), 1, jump_start_frame)
	if distance_to_hoop <= dunk_finish_radius + DUNK_SMART_START_DISTANCE_EPSILON and dunk_finish_radius > medium_distance:
		var max_alpha: float = inverse_lerp(medium_distance, dunk_finish_radius, clampf(distance_to_hoop, medium_distance, dunk_finish_radius))
		return clampi(ceili(lerpf(float(medium_start_frame), 1.0, max_alpha)), 1, medium_start_frame)
	return 1


func get_dunk_contact_anchor_offset(row_index: int) -> Vector2:
	match row_index:
		13:
			return dunk_contact_anchor_offset_row_13
		15:
			return dunk_contact_anchor_offset_row_15
		16:
			return dunk_contact_anchor_offset_row_16
	return Vector2.ZERO


func get_dunk_landing_anchor_offset(row_index: int) -> Vector2:
	match row_index:
		13:
			return dunk_landing_anchor_offset_row_13
		15:
			return dunk_landing_anchor_offset_row_15
		16:
			return dunk_landing_anchor_offset_row_16
	return Vector2.ZERO
