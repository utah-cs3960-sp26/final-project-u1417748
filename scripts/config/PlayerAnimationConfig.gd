class_name PlayerAnimationConfig
extends Resource

@export var stationary_speed_threshold: float = 18.0
@export var stationary_speed_release_threshold: float = 12.0
@export var small_move_speed_threshold: float = 110.0
@export var small_move_speed_release_threshold: float = 88.0
@export var facing_switch_min_vector_length: float = 24.0
@export var facing_switch_normalized_x_threshold: float = 0.22
@export var close_finish_radius: float = 550.0
@export var dunk_finish_radius: float = 485.0
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
