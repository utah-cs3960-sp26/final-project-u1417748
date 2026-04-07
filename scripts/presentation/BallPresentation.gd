@tool
extends Node2D
class_name BallPresentation

@export var presentation_theme: PresentationTheme = preload("res://data/config/RetroPresentationTheme.tres")
@export_range(0.0, 96.0, 1.0) var ball_height: float = 18.0

func _ready() -> void:
	queue_redraw()

func set_ball_height(value: float) -> void:
	ball_height = maxf(value, 0.0)
	queue_redraw()

func _draw() -> void:
	var base_radius := presentation_theme.ball_radius
	var scale_boost := 1.0 + ball_height * 0.004
	var ball_radius := base_radius * scale_boost
	var shadow_scale := clampf(1.0 - ball_height * 0.006, 0.58, 1.0)
	var shadow_radii := Vector2(base_radius * 1.12, base_radius * 0.48) * shadow_scale
	var shadow_center := Vector2(0.0, 10.0)
	var ball_center := Vector2(0.0, -ball_height)

	draw_colored_polygon(_ellipse(shadow_center, shadow_radii, 18), presentation_theme.shadow_color)
	draw_circle(ball_center, ball_radius + 4.0, presentation_theme.outline_color)
	draw_circle(ball_center, ball_radius, presentation_theme.ball_primary)
	draw_arc(ball_center, ball_radius * 0.88, deg_to_rad(210.0), deg_to_rad(330.0), 18, presentation_theme.ball_secondary, 3.0, true)
	draw_arc(ball_center, ball_radius * 0.88, deg_to_rad(30.0), deg_to_rad(150.0), 18, presentation_theme.ball_secondary, 3.0, true)
	draw_line(ball_center + Vector2(-ball_radius, 0.0), ball_center + Vector2(ball_radius, 0.0), presentation_theme.ball_secondary, 3.0)
	draw_line(ball_center + Vector2(0.0, -ball_radius), ball_center + Vector2(0.0, ball_radius), presentation_theme.ball_secondary, 3.0)

func _ellipse(center: Vector2, radii: Vector2, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := TAU * float(index) / float(point_count)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points
