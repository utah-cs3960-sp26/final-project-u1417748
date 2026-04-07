@tool
extends Node2D
class_name PlayerPresentation

enum TeamSide {
	HOME,
	AWAY,
}

@export var presentation_theme: PresentationTheme = preload("res://data/config/RetroPresentationTheme.tres")
@export var team_side: TeamSide = TeamSide.HOME
@export var controlled: bool = false
@export_range(0.85, 1.3, 0.01) var sprite_scale: float = 1.0

func _ready() -> void:
	queue_redraw()

func set_controlled_visual(is_controlled: bool) -> void:
	controlled = is_controlled
	queue_redraw()

func _draw() -> void:
	var is_home := team_side == TeamSide.HOME
	var primary := presentation_theme.get_team_primary(is_home)
	var secondary := presentation_theme.get_team_secondary(is_home)
	var outline := presentation_theme.outline_color
	var skin := presentation_theme.skin_tone
	var body_radius := presentation_theme.player_radius * sprite_scale
	var shadow_size := presentation_theme.player_shadow_size * sprite_scale
	var body_center := Vector2(0.0, 0.0)
	var head_center := Vector2(0.0, -body_radius - 18.0 * sprite_scale)
	var left_hand := body_center + Vector2(-body_radius - 10.0 * sprite_scale, -4.0 * sprite_scale)
	var right_hand := body_center + Vector2(body_radius + 10.0 * sprite_scale, -4.0 * sprite_scale)
	var left_foot := body_center + Vector2(-18.0 * sprite_scale, body_radius + 24.0 * sprite_scale)
	var right_foot := body_center + Vector2(18.0 * sprite_scale, body_radius + 24.0 * sprite_scale)
	var shorts_rect := Rect2(Vector2(-body_radius * 0.8, body_radius * 0.28), Vector2(body_radius * 1.6, body_radius * 0.78))
	var trim_rect := Rect2(Vector2(-body_radius * 0.72, -body_radius * 0.16), Vector2(body_radius * 1.44, body_radius * 0.28))

	draw_colored_polygon(_ellipse(Vector2(0.0, body_radius + 48.0 * sprite_scale), shadow_size, 18), presentation_theme.shadow_color)
	if controlled:
		draw_arc(Vector2(0.0, body_radius + 48.0 * sprite_scale), shadow_size.x * 0.8, 0.0, TAU, 48, presentation_theme.ui_accent, 6.0, true)

	draw_circle(body_center, body_radius + 6.0 * sprite_scale, outline)
	draw_circle(body_center, body_radius, primary)
	draw_rect(shorts_rect.grow(4.0 * sprite_scale), outline)
	draw_rect(shorts_rect, secondary)
	draw_rect(trim_rect.grow(3.0 * sprite_scale), outline)
	draw_rect(trim_rect, presentation_theme.neutral_fill)

	draw_circle(head_center, 22.0 * sprite_scale, outline)
	draw_circle(head_center, 18.0 * sprite_scale, skin)
	draw_circle(left_hand, 12.0 * sprite_scale, outline)
	draw_circle(left_hand, 8.0 * sprite_scale, skin)
	draw_circle(right_hand, 12.0 * sprite_scale, outline)
	draw_circle(right_hand, 8.0 * sprite_scale, skin)
	_draw_shoe(left_foot, outline, secondary)
	_draw_shoe(right_foot, outline, secondary)

func _draw_shoe(center: Vector2, outline: Color, fill: Color) -> void:
	draw_circle(center, 11.0 * sprite_scale, outline)
	draw_circle(center, 7.0 * sprite_scale, fill)

func _ellipse(center: Vector2, radii: Vector2, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := TAU * float(index) / float(point_count)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points
