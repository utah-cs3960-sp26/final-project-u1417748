extends Control
class_name DebugOverlay

@export var config: DebugConfig

var _snapshot: Dictionary = {}
var _panel: PanelContainer
var _label: RichTextLabel
var _visible_by_toggle: bool = true

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.offset_left = 24.0
	_panel.offset_top = 24.0
	_panel.custom_minimum_size = Vector2(420.0, 200.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_label = RichTextLabel.new()
	_label.fit_content = true
	_label.scroll_active = false
	_label.bbcode_enabled = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)

	if config == null:
		config = DebugConfig.new()
	_visible_by_toggle = config.overlay_enabled_by_default
	visible = _visible_by_toggle
	_update_label()

func _unhandled_input(event: InputEvent) -> void:
	if config == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == config.toggle_keycode:
		_visible_by_toggle = not _visible_by_toggle
		visible = _visible_by_toggle
		queue_redraw()

func set_debug_text(value: String) -> void:
	if _label == null:
		return
	_label.text = value

func update_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	_update_label()
	queue_redraw()

func _update_label() -> void:
	if _label == null:
		return
	var lines := PackedStringArray([
		"Diagnostics Overlay",
		"-------------------",
	])
	for section in config.enabled_sections():
		if _snapshot.has(section):
			lines.append("%s: %s" % [section, _snapshot[section]])
	if _snapshot.has("seed"):
		lines.append("seed: %s" % _snapshot["seed"])
	_label.text = "\n".join(lines)

func _draw() -> void:
	if not visible:
		return
	_draw_lines(_snapshot.get("lines", []))
	_draw_circles(_snapshot.get("circles", []))
	_draw_points(_snapshot.get("points", []))

func _draw_lines(lines: Array) -> void:
	for entry in lines:
		if not (entry is Dictionary):
			continue
		var from_point: Vector2 = entry.get("from", Vector2.ZERO)
		var to_point: Vector2 = entry.get("to", Vector2.ZERO)
		var color: Color = entry.get("color", Color.CYAN)
		var width: float = entry.get("width", 2.0)
		draw_line(from_point, to_point, color, width)

func _draw_circles(circles: Array) -> void:
	for entry in circles:
		if not (entry is Dictionary):
			continue
		var center: Vector2 = entry.get("center", Vector2.ZERO)
		var radius: float = entry.get("radius", 24.0)
		var color: Color = entry.get("color", Color(1.0, 0.8, 0.0, 0.35))
		draw_circle(center, radius, color)

func _draw_points(points: Array) -> void:
	for entry in points:
		if not (entry is Dictionary):
			continue
		var position: Vector2 = entry.get("position", Vector2.ZERO)
		var color: Color = entry.get("color", Color.WHITE)
		draw_circle(position, 6.0, color)
