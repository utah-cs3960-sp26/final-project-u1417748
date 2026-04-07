class_name HoopView
extends Node2D

var hoop_radius: float = 38.0
var backboard_half_width: float = 76.0
var backboard_offset: float = 42.0

func configure(radius: float, board_half_width: float, board_offset: float) -> void:
	hoop_radius = radius
	backboard_half_width = board_half_width
	backboard_offset = board_offset
	queue_redraw()

func _draw() -> void:
	draw_line(Vector2(-backboard_half_width, -backboard_offset), Vector2(backboard_half_width, -backboard_offset), Color.WHITE, 10.0)
	draw_line(Vector2(-18, -backboard_offset), Vector2(-18, -backboard_offset + 48), Color.WHITE, 6.0)
	draw_line(Vector2(18, -backboard_offset), Vector2(18, -backboard_offset + 48), Color.WHITE, 6.0)
	draw_arc(Vector2.ZERO, hoop_radius, PI * 0.1, PI * 0.9, 22, Color("#ff6b6b"), 7.0, true)
	draw_circle(Vector2.ZERO, 6.0, Color("#f6d365"))
