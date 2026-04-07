@tool
extends Node2D
class_name CourtPresentation

@export var presentation_theme: PresentationTheme = preload("res://data/config/RetroPresentationTheme.tres")
@export var show_joystick_zone: bool = true

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var viewport_rect := Rect2(Vector2.ZERO, presentation_theme.viewport_size)
	draw_rect(viewport_rect, presentation_theme.screen_bg_color)
	_draw_court(presentation_theme.get_court_rect())
	if show_joystick_zone:
		_draw_joystick_zone(viewport_rect)

func _draw_court(court_rect: Rect2) -> void:
	var stripe_count := 16
	var stripe_height := court_rect.size.y / float(stripe_count)
	for stripe_index in range(stripe_count):
		var stripe_color := presentation_theme.court_wood_dark if stripe_index % 2 == 0 else presentation_theme.court_wood_light
		var stripe_rect := Rect2(
			court_rect.position + Vector2(0.0, stripe_height * stripe_index),
			Vector2(court_rect.size.x, stripe_height + 1.0)
		)
		draw_rect(stripe_rect, stripe_color)

	var lane_rect := presentation_theme.get_key_rect()
	draw_rect(lane_rect, presentation_theme.paint_fill)
	draw_rect(court_rect, presentation_theme.line_color, false, 6.0)
	draw_rect(lane_rect, presentation_theme.line_color, false, 6.0)

	var hoop_anchor := presentation_theme.get_hoop_anchor()
	var line_color := presentation_theme.line_color
	var arc_radius := minf(court_rect.size.x * 0.42, 360.0)
	var arc_start := deg_to_rad(28.0)
	var arc_end := deg_to_rad(152.0)
	var left_arc_point := hoop_anchor + Vector2(cos(arc_start), sin(arc_start)) * arc_radius
	var right_arc_point := hoop_anchor + Vector2(cos(arc_end), sin(arc_end)) * arc_radius
	var corner_y := court_rect.position.y + 100.0
	var left_corner_x := court_rect.position.x + 96.0
	var right_corner_x := court_rect.end.x - 96.0

	draw_arc(hoop_anchor, arc_radius, arc_start, arc_end, 48, line_color, 6.0, true)
	draw_line(Vector2(left_corner_x, corner_y), Vector2(left_corner_x, left_arc_point.y), line_color, 6.0)
	draw_line(Vector2(right_corner_x, corner_y), Vector2(right_corner_x, right_arc_point.y), line_color, 6.0)

	var free_throw_center := Vector2(lane_rect.get_center().x, lane_rect.end.y)
	draw_arc(free_throw_center, lane_rect.size.x * 0.34, 0.0, PI, 32, line_color, 6.0, true)
	draw_arc(hoop_anchor, 146.0, deg_to_rad(38.0), deg_to_rad(142.0), 24, line_color, 6.0, true)
	draw_circle(hoop_anchor + Vector2(0.0, 248.0), 18.0, Color(line_color.r, line_color.g, line_color.b, 0.35))
	draw_circle(Vector2(court_rect.position.x + 128.0, court_rect.end.y - 150.0), 10.0, Color(line_color.r, line_color.g, line_color.b, 0.3))
	draw_circle(Vector2(court_rect.end.x - 128.0, court_rect.end.y - 150.0), 10.0, Color(line_color.r, line_color.g, line_color.b, 0.3))

func _draw_joystick_zone(viewport_rect: Rect2) -> void:
	var zone_rect := Rect2(
		Vector2(presentation_theme.sideline_margin, viewport_rect.size.y - presentation_theme.lower_input_height),
		Vector2(viewport_rect.size.x - presentation_theme.sideline_margin * 2.0, presentation_theme.lower_input_height - 42.0)
	)
	draw_rect(zone_rect, presentation_theme.joystick_zone_color)
	draw_rect(zone_rect, Color(presentation_theme.line_color.r, presentation_theme.line_color.g, presentation_theme.line_color.b, 0.25), false, 4.0)

	var guide_radius := 112.0
	var guide_center := Vector2(zone_rect.position.x + 172.0, zone_rect.get_center().y + 60.0)
	draw_circle(guide_center, guide_radius, Color(presentation_theme.line_color.r, presentation_theme.line_color.g, presentation_theme.line_color.b, 0.08))
	draw_circle(guide_center, guide_radius * 0.44, Color(presentation_theme.line_color.r, presentation_theme.line_color.g, presentation_theme.line_color.b, 0.12))
	draw_arc(guide_center, guide_radius, 0.0, TAU, 48, Color(presentation_theme.line_color.r, presentation_theme.line_color.g, presentation_theme.line_color.b, 0.22), 4.0, true)
