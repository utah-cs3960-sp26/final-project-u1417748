class_name CourtConfig
extends Resource

@export var origin: Vector2 = Vector2(90.0, 170.0)
@export var size: Vector2 = Vector2(900.0, 1600.0)
@export var hoop_normalized: Vector2 = Vector2(0.5, 0.10)
@export var point_guard_start: Vector2 = Vector2(0.5, 0.78)
@export var left_wing_start: Vector2 = Vector2(0.32, 0.52)
@export var right_wing_start: Vector2 = Vector2(0.68, 0.52)
@export var left_corner_start: Vector2 = Vector2(0.18, 0.26)
@export var right_corner_start: Vector2 = Vector2(0.82, 0.26)
@export var three_point_radius: float = 560.0
@export var hoop_radius: float = 38.0
@export var scoring_radius: float = 28.0
@export var backboard_half_width: float = 76.0
@export var backboard_offset: float = 42.0
@export var rim_height: float = 146.0
@export var backboard_top: float = 220.0
@export var backboard_bottom: float = 80.0

func normalized_to_world(value: Vector2) -> Vector2:
	return origin + Vector2(value.x * size.x, value.y * size.y)

func get_playable_rect() -> Rect2:
	return Rect2(origin, size)

func get_default_anchors() -> Array[Vector2]:
	return [
		normalized_to_world(point_guard_start),
		normalized_to_world(left_wing_start),
		normalized_to_world(right_wing_start),
		normalized_to_world(left_corner_start),
		normalized_to_world(right_corner_start),
	]

func get_hoop_world_position() -> Vector2:
	return normalized_to_world(hoop_normalized)
