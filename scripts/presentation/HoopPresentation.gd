@tool
extends Node2D
class_name HoopPresentation

@export var presentation_theme: PresentationTheme = preload("res://data/config/RetroPresentationTheme.tres")
@export_range(0.8, 1.3, 0.01) var hoop_scale: float = 1.0

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var outline := presentation_theme.outline_color
	var rim_color := presentation_theme.rim_color
	var board_fill := presentation_theme.backboard_fill
	var board_trim := presentation_theme.backboard_trim
	var rim_radius := presentation_theme.rim_radius * hoop_scale
	var board_rect := Rect2(Vector2(-156.0, -84.0) * hoop_scale, Vector2(312.0, 116.0) * hoop_scale)
	var target_rect := Rect2(Vector2(-38.0, -46.0) * hoop_scale, Vector2(76.0, 48.0) * hoop_scale)
	var support_rect := Rect2(Vector2(-26.0, -8.0) * hoop_scale, Vector2(52.0, 118.0) * hoop_scale)
	var rim_center := Vector2(0.0, 54.0) * hoop_scale

	draw_rect(board_rect.grow(8.0 * hoop_scale), outline)
	draw_rect(board_rect, board_fill)
	draw_rect(target_rect.grow(5.0 * hoop_scale), outline)
	draw_rect(target_rect, board_trim)
	draw_rect(support_rect.grow(4.0 * hoop_scale), outline)
	draw_rect(support_rect, board_trim)

	draw_arc(rim_center, rim_radius, deg_to_rad(8.0), deg_to_rad(172.0), 40, outline, 18.0 * hoop_scale, true)
	draw_arc(rim_center, rim_radius, deg_to_rad(8.0), deg_to_rad(172.0), 40, rim_color, 10.0 * hoop_scale, true)
	for net_index in range(5):
		var x_offset := lerpf(-rim_radius * 0.62, rim_radius * 0.62, float(net_index) / 4.0)
		draw_line(rim_center + Vector2(x_offset, 8.0 * hoop_scale), rim_center + Vector2(x_offset * 0.42, 74.0 * hoop_scale), outline, 3.0 * hoop_scale)
		draw_line(rim_center + Vector2(x_offset, 8.0 * hoop_scale), rim_center + Vector2(x_offset * 0.42, 74.0 * hoop_scale), board_fill, 2.0 * hoop_scale)
	for rim_index in range(4):
		var y_offset := lerpf(16.0, 62.0, float(rim_index) / 3.0) * hoop_scale
		draw_line(rim_center + Vector2(-rim_radius * 0.42, y_offset), rim_center + Vector2(rim_radius * 0.42, y_offset), board_fill, 2.0 * hoop_scale)
