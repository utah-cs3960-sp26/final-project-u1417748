class_name CourtView
extends Node2D

const COURT_TEXTURE: Texture2D = preload("res://assets/Court/Court.png")
const BACKDROP_COLOR: Color = Color("7f708a")

@export var court_variant_source_region: Rect2 = Rect2(16.0, 256.0, 484.0, 229.0)
@export var active_half_crop: Rect2 = Rect2(0.0, 0.0, 0.5, 1.0)
@export var court_strip_count: int = 28

var court_config: CourtConfig
var projection: CourtProjection
var trajectory_points: Array[Dictionary] = []
var trajectory_color: Color = Color(0.3, 0.95, 0.4, 0.95)
var shot_meter: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(config_value: CourtConfig, projection_value: CourtProjection = null) -> void:
	court_config = config_value
	projection = projection_value
	queue_redraw()


func set_projection(projection_value: CourtProjection) -> void:
	projection = projection_value
	queue_redraw()


func set_preview(points: Array[Dictionary], color_value: Color) -> void:
	trajectory_points = points
	trajectory_color = color_value
	queue_redraw()


func set_shot_meter(meter_value: Dictionary) -> void:
	shot_meter = meter_value
	queue_redraw()


func clear_shot_meter() -> void:
	shot_meter.clear()
	queue_redraw()


func clear_preview() -> void:
	trajectory_points.clear()
	queue_redraw()


func _draw() -> void:
	if court_config == null:
		return
	var rect: Rect2 = court_config.court_rect
	_draw_background()
	_draw_textured_court(rect)
	for point in trajectory_points:
		var screen_position: Vector2 = point.get("screen_position", point["position"] + Vector2(0.0, -point["z"] * 0.14))
		var radius: float = point.get("radius", clampf(6.0 + point["z"] * 0.01, 4.0, 11.0))
		var alpha: float = point.get("alpha", trajectory_color.a)
		var apex_weight: float = point.get("apex_weight", 0.0)
		var dot_color: Color = Color(trajectory_color.r, trajectory_color.g, trajectory_color.b, alpha)
		draw_circle(screen_position, radius, dot_color)
		if apex_weight > 0.05:
			draw_circle(screen_position, radius * 0.4, Color(1.0, 1.0, 1.0, clampf(apex_weight * 0.35, 0.0, 0.24)))
	if bool(shot_meter.get("visible", false)):
		_draw_shot_meter()


func has_textured_court() -> bool:
	var source_region: Rect2 = _get_active_court_source_region()
	return COURT_TEXTURE != null and source_region.size.x > 0.0 and source_region.size.y > 0.0


func _project_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, steps: int) -> PackedVector2Array:
	var world_points: Array[Vector2] = []
	for index in steps + 1:
		var t: float = float(index) / float(maxi(steps, 1))
		var angle: float = lerpf(start_angle, end_angle, t)
		world_points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	if projection == null:
		return PackedVector2Array(world_points)
	return projection.project_polyline(world_points)


func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1080.0, 1920.0)), BACKDROP_COLOR)


func _draw_textured_court(rect: Rect2) -> void:
	if COURT_TEXTURE == null:
		draw_rect(rect, Color(0.2, 0.36, 0.56))
		return
	var source_region: Rect2 = _get_active_court_source_region()
	var court_texture: AtlasTexture = AtlasTexture.new()
	court_texture.atlas = COURT_TEXTURE
	court_texture.region = source_region
	var strip_total: int = maxi(court_strip_count, 4)
	var colors: PackedColorArray = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	for strip_index in strip_total:
		var top_ratio: float = float(strip_index) / float(strip_total)
		var bottom_ratio: float = float(strip_index + 1) / float(strip_total)
		var top_y: float = lerpf(rect.position.y, rect.end.y, top_ratio)
		var bottom_y: float = lerpf(rect.position.y, rect.end.y, bottom_ratio)
		var quad: PackedVector2Array = PackedVector2Array()
		var top_left: Vector2 = _project_ground(Vector2(rect.position.x, top_y))
		var top_right: Vector2 = _project_ground(Vector2(rect.end.x, top_y))
		var bottom_right: Vector2 = _project_ground(Vector2(rect.end.x, bottom_y))
		var bottom_left: Vector2 = _project_ground(Vector2(rect.position.x, bottom_y))
		quad.append_array([top_left, top_right, bottom_right, bottom_left])
		var uvs: PackedVector2Array = PackedVector2Array()
		var source_left_x: float = top_ratio
		var source_right_x: float = bottom_ratio
		var source_top_y: float = 0.0
		var source_bottom_y: float = 1.0
		uvs.append_array([
			Vector2(source_left_x, source_bottom_y),
			Vector2(source_left_x, source_top_y),
			Vector2(source_right_x, source_top_y),
			Vector2(source_right_x, source_bottom_y),
		])
		draw_polygon(quad, colors, uvs, court_texture)


func _get_active_court_source_region() -> Rect2:
	var crop_position: Vector2 = court_variant_source_region.position + court_variant_source_region.size * active_half_crop.position
	var crop_size: Vector2 = court_variant_source_region.size * active_half_crop.size
	return Rect2(crop_position, crop_size)


func _project_ground(world_position: Vector2) -> Vector2:
	if projection == null:
		return world_position
	return projection.world_to_screen_ground(world_position)


func _draw_shot_meter() -> void:
	var meter_width: float = float(shot_meter.get("width", 560.0))
	var meter_height: float = float(shot_meter.get("height", 42.0))
	var bottom_margin: float = float(shot_meter.get("bottom_margin", 164.0))
	var marker_width: float = float(shot_meter.get("marker_width", 20.0))
	var bar_rect: Rect2 = Rect2(
		Vector2((1080.0 - meter_width) * 0.5, 1920.0 - bottom_margin - meter_height),
		Vector2(meter_width, meter_height)
	)
	var green_start: float = float(shot_meter.get("green_start", 0.6))
	var green_end: float = float(shot_meter.get("green_end", 0.78))
	var yellow_start: float = float(shot_meter.get("yellow_start", 0.32))
	var yellow_end: float = float(shot_meter.get("yellow_end", green_start))
	var progress: float = float(shot_meter.get("progress", 0.0))
	draw_rect(bar_rect.grow(12.0), Color(0.04, 0.04, 0.06, 0.76))
	draw_rect(bar_rect, Color(0.74, 0.16, 0.16, 0.96))
	var yellow_rect: Rect2 = Rect2(
		Vector2(bar_rect.position.x + bar_rect.size.x * yellow_start, bar_rect.position.y),
		Vector2(bar_rect.size.x * maxf(yellow_end - yellow_start, 0.0), bar_rect.size.y)
	)
	if yellow_rect.size.x > 0.0:
		draw_rect(yellow_rect, Color(1.0, 0.84, 0.28, 0.98))
	var green_rect: Rect2 = Rect2(
		Vector2(bar_rect.position.x + bar_rect.size.x * green_start, bar_rect.position.y),
		Vector2(bar_rect.size.x * maxf(green_end - green_start, 0.0), bar_rect.size.y)
	)
	if green_rect.size.x > 0.0:
		draw_rect(green_rect, Color(0.22, 0.86, 0.34, 1.0))
	draw_rect(bar_rect, Color(0.98, 0.95, 0.86, 0.92), false, 4.0)
	var marker_x: float = bar_rect.position.x + bar_rect.size.x * progress - marker_width * 0.5
	var marker_rect: Rect2 = Rect2(Vector2(marker_x, bar_rect.position.y - 8.0), Vector2(marker_width, bar_rect.size.y + 16.0))
	draw_rect(marker_rect, Color(0.98, 0.96, 0.9))
	draw_rect(marker_rect.grow(-4.0), Color(0.08, 0.09, 0.1, 0.92))
