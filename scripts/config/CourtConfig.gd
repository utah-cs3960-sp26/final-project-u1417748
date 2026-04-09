class_name CourtConfig
extends Resource

@export var court_rect: Rect2 = Rect2(120.0, 220.0, 840.0, 1480.0)
@export var hoop_position: Vector2 = Vector2(540.0, 360.0)
@export var three_point_radius: float = 430.0
@export var rim_radius: float = 62.0
@export var rim_inner_radius: float = 40.0
@export var rim_height: float = 185.0
@export var backboard_width: float = 180.0
@export var backboard_y: float = 290.0
@export var backboard_x_center: float = 540.0
@export var over_backboard_z_threshold: float = 320.0
@export var net_channel_radius: float = 40.0
@export var net_followthrough_depth: float = 26.0
@export var net_exit_z: float = 58.0
@export var score_followthrough_duration: float = 0.34
@export var score_followthrough_centering_strength: float = 0.78
@export var rim_mouth_duration: float = 0.06
@export var rim_mouth_depth: float = 10.0
@export var net_swish_duration: float = 0.18
@export var net_swish_sway_amplitude: float = 3.0
@export var net_swish_stretch: float = 0.08
@export var made_shot_entry_depth: float = 18.0
@export var score_entry_min_front_offset: float = 6.0
@export var out_of_bounds_margin: float = 24.0
@export var point_guard_start: Vector2 = Vector2(0.50, 0.78)
@export var left_wing_start: Vector2 = Vector2(0.32, 0.52)
@export var right_wing_start: Vector2 = Vector2(0.68, 0.52)
@export var left_corner_start: Vector2 = Vector2(0.18, 0.26)
@export var right_corner_start: Vector2 = Vector2(0.82, 0.26)


func normalized_to_court(value: Vector2) -> Vector2:
	return Vector2(
		court_rect.position.x + value.x * court_rect.size.x,
		court_rect.position.y + value.y * court_rect.size.y
	)


func court_to_normalized(value: Vector2) -> Vector2:
	return Vector2(
		(value.x - court_rect.position.x) / court_rect.size.x,
		(value.y - court_rect.position.y) / court_rect.size.y
	)


func get_anchor_map() -> Dictionary:
	return {
		"PG": normalized_to_court(point_guard_start),
		"LW": normalized_to_court(left_wing_start),
		"RW": normalized_to_court(right_wing_start),
		"LC": normalized_to_court(left_corner_start),
		"RC": normalized_to_court(right_corner_start),
	}


func is_in_bounds(position_xy: Vector2) -> bool:
	return court_rect.grow(-out_of_bounds_margin).has_point(position_xy)


func is_three_point(position_xy: Vector2) -> bool:
	return position_xy.distance_to(hoop_position) > three_point_radius
