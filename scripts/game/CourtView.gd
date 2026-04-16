class_name CourtView
extends Node2D

const COURT_TEXTURE: Texture2D = preload("res://assets/Court/Court.png")
const BOTTOM_HOOP_TEXTURE_PATH: String = "res://assets/Court/HoopBodyBackNormalized.png"
const BACKDROP_COLOR: Color = Color("7f708a")
const PASS_PREVIEW_RING_COLOR: Color = Color(0.35, 0.85, 1.0, 0.82)
const PASS_PREVIEW_FILL_COLOR: Color = Color(0.35, 0.85, 1.0, 0.16)
const BOTTOM_HOOP_ANCHOR_RATIO: Vector2 = Vector2(0.5, 1.0)
const DEFAULT_BOTTOM_HOOP_SCALE_MULTIPLIER: float = 2.0
const DEFAULT_BOTTOM_HOOP_Z_INDEX: int = 3000

@export var court_variant_source_region: Rect2 = Rect2(16.0, 256.0, 484.0, 229.0)
@export var court_strip_count: int = 28

var court_config: CourtConfig
var projection
var court_screen_rect: Rect2 = Rect2(0.0, 0.0, 1080.0, 1920.0)
var trajectory_points: Array[Dictionary] = []
var trajectory_color: Color = Color(0.3, 0.95, 0.4, 0.95)
var shot_meter: Dictionary = {}
var input_feedback: Dictionary = {}
var _bottom_hoop_texture: Texture2D
var _bottom_hoop_sprite: Sprite2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_bottom_hoop_sprite()
	_sync_bottom_hoop_sprite()


func setup(config_value: CourtConfig, projection_value = null) -> void:
	court_config = config_value
	projection = projection_value
	_sync_bottom_hoop_sprite()
	queue_redraw()


func set_projection(projection_value) -> void:
	projection = projection_value
	_sync_bottom_hoop_sprite()
	queue_redraw()


func apply_layout(layout_metrics: Dictionary) -> void:
	court_screen_rect = layout_metrics.get("court_screen_rect", court_screen_rect)
	_sync_bottom_hoop_sprite()
	queue_redraw()


func set_preview(points: Array[Dictionary], color_value: Color) -> void:
	trajectory_points = points
	trajectory_color = color_value
	_sync_bottom_hoop_sprite()
	queue_redraw()


func set_shot_meter(meter_value: Dictionary) -> void:
	shot_meter = meter_value
	_sync_bottom_hoop_sprite()
	queue_redraw()


func clear_shot_meter() -> void:
	shot_meter.clear()
	_sync_bottom_hoop_sprite()
	queue_redraw()


func set_input_feedback(feedback_value: Dictionary) -> void:
	input_feedback = feedback_value.duplicate(true)
	_sync_bottom_hoop_sprite()
	queue_redraw()


func clear_input_feedback() -> void:
	input_feedback.clear()
	_sync_bottom_hoop_sprite()
	queue_redraw()


func clear_preview() -> void:
	trajectory_points.clear()
	_sync_bottom_hoop_sprite()
	queue_redraw()


func _draw() -> void:
	if court_config == null:
		return
	var rect: Rect2 = court_config.court_rect
	_draw_background()
	_draw_textured_court(rect)
	_draw_input_feedback()
	for point in trajectory_points:
		var screen_position: Vector2 = point.get("screen_position", point["position"] + Vector2(0.0, -point["z"] * 0.14))
		var radius: float = point.get("radius", clampf(6.0 + point["z"] * 0.01, 4.0, 11.0))
		var alpha: float = point.get("alpha", trajectory_color.a)
		var apex_weight: float = point.get("apex_weight", 0.0)
		var dot_color: Color = Color(trajectory_color.r, trajectory_color.g, trajectory_color.b, alpha)
		draw_circle(screen_position, radius, dot_color)
		if apex_weight > 0.05:
			draw_circle(screen_position, radius * 0.4, Color(1.0, 1.0, 1.0, clampf(apex_weight * 0.35, 0.0, 0.24)))


func has_textured_court() -> bool:
	var source_region: Rect2 = _get_active_court_source_region()
	return COURT_TEXTURE != null and source_region.size.x > 0.0 and source_region.size.y > 0.0


func has_bottom_hoop_visual() -> bool:
	var texture: Texture2D = _get_bottom_hoop_texture()
	return texture != null \
		and texture.get_width() > 0 \
		and texture.get_height() > 0


func get_bottom_hoop_snapshot() -> Dictionary:
	var draw_rect: Rect2 = _get_bottom_hoop_draw_rect()
	var world_anchor: Vector2 = _get_bottom_hoop_world_anchor()
	var screen_anchor: Vector2 = _project_ground(world_anchor) if court_config != null else Vector2.ZERO
	return {
		"visible": has_bottom_hoop_visual() and court_config != null,
		"texture_size": Vector2(
			float(_get_bottom_hoop_texture().get_width()) if _get_bottom_hoop_texture() != null else 0.0,
			float(_get_bottom_hoop_texture().get_height()) if _get_bottom_hoop_texture() != null else 0.0
		),
		"world_anchor": world_anchor,
		"normalized_anchor": court_config.court_to_normalized(world_anchor) if court_config != null else Vector2.ZERO,
		"screen_anchor": screen_anchor,
		"screen_rect": draw_rect,
		"draw_scale": _get_bottom_hoop_scale(),
		"scale_multiplier": _get_bottom_hoop_scale_multiplier(),
		"z_index": _get_bottom_hoop_z_index(),
		"z_as_relative": false,
	}


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
	draw_rect(Rect2(Vector2.ZERO, _get_viewport_size()), BACKDROP_COLOR)


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
		uvs.append_array([
			Vector2(source_left_x, 1.0),
			Vector2(source_left_x, 0.0),
			Vector2(source_right_x, 0.0),
			Vector2(source_right_x, 1.0),
		])
		draw_polygon(quad, colors, uvs, court_texture)


func _get_bottom_hoop_draw_rect() -> Rect2:
	if court_config == null or not has_bottom_hoop_visual():
		return Rect2()
	var anchor_screen: Vector2 = _project_ground(_get_bottom_hoop_world_anchor())
	var texture: Texture2D = _get_bottom_hoop_texture()
	if texture == null:
		return Rect2()
	var texture_size: Vector2 = Vector2(float(texture.get_width()), float(texture.get_height()))
	var scale_value: float = _get_bottom_hoop_scale()
	var draw_size: Vector2 = texture_size * scale_value
	return Rect2(anchor_screen - draw_size * BOTTOM_HOOP_ANCHOR_RATIO, draw_size)


func _get_bottom_hoop_world_anchor() -> Vector2:
	if court_config == null:
		return Vector2.ZERO
	return court_config.opposite_hoop_position


func _get_bottom_hoop_scale() -> float:
	var scale_multiplier: float = _get_bottom_hoop_scale_multiplier()
	if projection == null:
		return scale_multiplier
	if projection.has_method("get_hoop_visual_scale_multiplier"):
		return maxf(float(projection.call("get_hoop_visual_scale_multiplier")) * scale_multiplier, 0.01)
	if projection.has_method("get_total_presentation_scale"):
		return maxf(float(projection.call("get_total_presentation_scale")) * scale_multiplier, 0.01)
	return scale_multiplier


func _get_bottom_hoop_scale_multiplier() -> float:
	if court_config == null:
		return DEFAULT_BOTTOM_HOOP_SCALE_MULTIPLIER
	return maxf(court_config.opposite_hoop_visual_scale_multiplier, 0.01)


func _get_bottom_hoop_z_index() -> int:
	if court_config == null:
		return DEFAULT_BOTTOM_HOOP_Z_INDEX
	return court_config.opposite_hoop_z_index


func _get_bottom_hoop_texture() -> Texture2D:
	if _bottom_hoop_texture != null:
		return _bottom_hoop_texture
	if ResourceLoader.exists(BOTTOM_HOOP_TEXTURE_PATH, "Texture2D") or ResourceLoader.exists(BOTTOM_HOOP_TEXTURE_PATH):
		_bottom_hoop_texture = load(BOTTOM_HOOP_TEXTURE_PATH) as Texture2D
	if _bottom_hoop_texture == null and FileAccess.file_exists(BOTTOM_HOOP_TEXTURE_PATH):
		var image: Image = Image.load_from_file(BOTTOM_HOOP_TEXTURE_PATH)
		if not image.is_empty():
			_bottom_hoop_texture = ImageTexture.create_from_image(image)
	return _bottom_hoop_texture


func _ensure_bottom_hoop_sprite() -> void:
	if _bottom_hoop_sprite != null:
		return
	_bottom_hoop_sprite = Sprite2D.new()
	_bottom_hoop_sprite.name = "BottomHoopBackSprite"
	_bottom_hoop_sprite.centered = false
	_bottom_hoop_sprite.z_as_relative = false
	_bottom_hoop_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_bottom_hoop_sprite)


func _sync_bottom_hoop_sprite() -> void:
	_ensure_bottom_hoop_sprite()
	if _bottom_hoop_sprite == null:
		return
	var texture: Texture2D = _get_bottom_hoop_texture()
	_bottom_hoop_sprite.texture = texture
	_bottom_hoop_sprite.visible = texture != null and court_config != null
	_bottom_hoop_sprite.z_index = _get_bottom_hoop_z_index()
	_bottom_hoop_sprite.z_as_relative = false
	if not _bottom_hoop_sprite.visible:
		return
	var draw_rect: Rect2 = _get_bottom_hoop_draw_rect()
	_bottom_hoop_sprite.position = draw_rect.position
	_bottom_hoop_sprite.scale = Vector2.ONE * _get_bottom_hoop_scale()


func _get_active_court_source_region() -> Rect2:
	var display_size: Vector2 = court_screen_rect.size if court_screen_rect.size.x > 0.0 and court_screen_rect.size.y > 0.0 else _get_viewport_size()
	if display_size.x <= 0.0 or display_size.y <= 0.0:
		return court_variant_source_region
	var full_region: Rect2 = court_variant_source_region
	var visible_source_depth: float = minf(full_region.size.x, full_region.size.y * display_size.y / maxf(display_size.x, 1.0))
	visible_source_depth = clampf(visible_source_depth, 1.0, full_region.size.x)
	return Rect2(full_region.position, Vector2(visible_source_depth, full_region.size.y))


func _project_ground(world_position: Vector2) -> Vector2:
	if projection == null:
		return world_position
	return projection.world_to_screen_ground(world_position)


func _draw_input_feedback() -> void:
	var pass_target_screen: Vector2 = input_feedback.get("pass_target_screen", Vector2.INF)
	if pass_target_screen != Vector2.INF:
		var pass_radius: float = float(input_feedback.get("pass_target_radius", 28.0))
		draw_circle(pass_target_screen, pass_radius, PASS_PREVIEW_FILL_COLOR)
		draw_arc(pass_target_screen, pass_radius, 0.0, TAU, 28, PASS_PREVIEW_RING_COLOR, 3.0)


func _get_viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size
