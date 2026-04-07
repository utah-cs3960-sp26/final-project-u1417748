class_name CourtView
extends Node2D

var court_config: CourtConfig
var offense_targets: Array[Vector2] = []
var defense_pairs: Array[PackedVector2Array] = []
var rebound_target: Vector2 = Vector2.ZERO
var show_rebound_target: bool = false
var show_routes: bool = true
var show_defense: bool = true
var preview_points: Array[Vector2] = []

func configure(config: CourtConfig) -> void:
	court_config = config
	queue_redraw()

func update_debug(route_targets: Array[Vector2], defender_pairs: Array[PackedVector2Array], rebound_point: Vector2, rebound_visible: bool, preview: Array[Vector2], routes_visible: bool, defense_visible: bool) -> void:
	offense_targets = route_targets
	defense_pairs = defender_pairs
	rebound_target = rebound_point
	show_rebound_target = rebound_visible
	preview_points = preview
	show_routes = routes_visible
	show_defense = defense_visible
	queue_redraw()

func _draw() -> void:
	if court_config == null:
		return
	var rect: Rect2 = court_config.get_playable_rect()
	draw_rect(rect, Color("#1b7a52"), true)
	draw_rect(rect, Color("#f6d365"), false, 8.0)
	var hoop_pos: Vector2 = court_config.get_hoop_world_position()
	var key_rect := Rect2(court_config.origin + Vector2(rect.size.x * 0.25, 0.0), Vector2(rect.size.x * 0.5, rect.size.y * 0.22))
	draw_rect(key_rect, Color(1, 1, 1, 0.08), false, 6.0)
	draw_arc(hoop_pos, court_config.three_point_radius, PI * 0.18, PI * 0.82, 48, Color("#f6d365"), 5.0, true)
	draw_line(court_config.origin + Vector2(rect.size.x * 0.1, 0.0), court_config.origin + Vector2(rect.size.x * 0.1, 260.0), Color("#f6d365"), 5.0)
	draw_line(court_config.origin + Vector2(rect.size.x * 0.9, 0.0), court_config.origin + Vector2(rect.size.x * 0.9, 260.0), Color("#f6d365"), 5.0)
	draw_arc(hoop_pos, 132.0, PI * 0.20, PI * 0.80, 24, Color("#f6d365"), 4.0, true)
	if show_routes:
		for target: Vector2 in offense_targets:
			draw_circle(target, 10.0, Color(0.2, 0.95, 1.0, 0.7))
	if show_defense:
		for pair: PackedVector2Array in defense_pairs:
			if pair.size() == 2:
				draw_line(pair[0], pair[1], Color(1.0, 0.38, 0.38, 0.45), 3.0)
	if show_rebound_target:
		draw_circle(rebound_target, 42.0, Color(1.0, 0.95, 0.2, 0.18))
		draw_circle(rebound_target, 42.0, Color(1.0, 0.95, 0.2, 0.7), false, 3.0, true)
	for point: Vector2 in preview_points:
		draw_circle(point, 7.0, Color(1, 1, 1, 0.92))
