class_name BallView
extends Node2D

var ball_radius: float = 16.0
var ball_z: float = 0.0
var show_shadow: bool = true

func set_ball_state(world_pos: Vector2, z_height: float, radius: float) -> void:
	position = world_pos
	ball_z = z_height
	ball_radius = radius
	scale = Vector2.ONE * (1.0 + min(ball_z / 420.0, 0.25))
	queue_redraw()

func _draw() -> void:
	if show_shadow:
		var shadow_alpha: float = clampf(0.3 - ball_z / 600.0, 0.08, 0.28)
		draw_circle(Vector2(0.0, ball_radius * 1.2), ball_radius * 1.1, Color(0, 0, 0, shadow_alpha))
	draw_circle(Vector2(0.0, -ball_z * 0.35), ball_radius, Color("#d66c25"))
	draw_circle(Vector2(0.0, -ball_z * 0.35), ball_radius, Color("#2a1a10"), false, 2.0, true)
	draw_line(Vector2(-ball_radius, -ball_z * 0.35), Vector2(ball_radius, -ball_z * 0.35), Color("#2a1a10"), 2.0)
	draw_line(Vector2(0, -ball_radius - ball_z * 0.35), Vector2(0, ball_radius - ball_z * 0.35), Color("#2a1a10"), 2.0)
