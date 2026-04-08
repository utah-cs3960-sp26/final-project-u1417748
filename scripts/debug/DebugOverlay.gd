class_name DebugOverlay
extends Control

var coordinator: Node
var debug_config: DebugConfig
var _label: Label


func _ready() -> void:
	anchors_preset = PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.position = Vector2(18.0, 140.0)
	_label.size = Vector2(380.0, 420.0)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.78))
	add_child(_label)


func setup(coordinator_node: Node, config_value: DebugConfig) -> void:
	coordinator = coordinator_node
	debug_config = config_value
	visible = debug_config.debug_overlay_enabled


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3 and debug_config != null:
		debug_config.debug_overlay_enabled = not debug_config.debug_overlay_enabled
		visible = debug_config.debug_overlay_enabled
		queue_redraw()


func _process(_delta: float) -> void:
	if not visible or coordinator == null or not coordinator.has_method("get_debug_snapshot"):
		return
	var snapshot: Dictionary = coordinator.get_debug_snapshot()
	_label.text = "State: %s\nClock: %s\nScore: HOM %d / AWY %d\nSeed: %d" % [
		snapshot.get("state_name", "UNKNOWN"),
		snapshot.get("clock_text", "0:00"),
		snapshot.get("home_score", 0),
		snapshot.get("away_score", 0),
		snapshot.get("seed", 0),
	]
	queue_redraw()


func _draw() -> void:
	if not visible or coordinator == null or not coordinator.has_method("get_debug_snapshot"):
		return
	var snapshot: Dictionary = coordinator.get_debug_snapshot()
	if debug_config == null:
		return
	if debug_config.show_routes:
		for segment in snapshot.get("route_segments", []):
			draw_line(segment.a, segment.b, Color(0.2, 1.0, 0.8, 0.8), 2.0)
	if debug_config.show_defender_lines:
		for segment in snapshot.get("defender_segments", []):
			draw_line(segment.a, segment.b, Color(1.0, 0.4, 0.3, 0.75), 2.0)
	if debug_config.show_contest_radii:
		for ring in snapshot.get("contest_rings", []):
			draw_polyline(ring, Color(1.0, 0.7, 0.25, 0.6), 2.0)
	if debug_config.show_catch_radii:
		for ring in snapshot.get("catch_rings", []):
			draw_polyline(ring, Color(0.35, 0.85, 1.0, 0.6), 2.0)
	if debug_config.show_intercept_corridor:
		var corridor: PackedVector2Array = snapshot.get("intercept_corridor", PackedVector2Array())
		if corridor.size() == 2:
			draw_line(corridor[0], corridor[1], Color(1.0, 0.2, 0.8, 0.8), 3.0)
	if debug_config.show_rebound_zone:
		var rebound_zone: PackedVector2Array = snapshot.get("rebound_zone", PackedVector2Array())
		if rebound_zone.size() > 0:
			draw_polyline(rebound_zone, Color(1.0, 1.0, 0.4, 0.7), 2.0)
	if debug_config.show_shot_preview_data:
		for point in snapshot.get("shot_preview", []):
			draw_circle(point.get("screen_position", point["position"] + Vector2(0.0, -point["z"] * 0.14)), 4.0, Color(0.4, 1.0, 0.5, 0.6))
