class_name ControlPanel
extends Control

const PANEL_OUTLINE_COLOR: Color = Color("2a1f37")
const PANEL_SHADOW_COLOR: Color = Color(0.08, 0.04, 0.12, 0.38)
const BUTTON_IDLE_COLOR: Color = Color("1b1d3a")
const BUTTON_IDLE_ACCENT_COLOR: Color = Color("2a2d57")
const SHOOT_BASE_COLOR: Color = Color("6d55b8")
const SHOOT_ACCENT_COLOR: Color = Color("8f79d3")
const MOVE_BASE_COLOR: Color = Color("5065bf")
const MOVE_ACCENT_COLOR: Color = Color("7388dd")
const PASS_BASE_COLOR: Color = Color("d7744a")
const PASS_ACCENT_COLOR: Color = Color("f0a46a")
const DUNK_BASE_COLOR: Color = Color("c8464e")
const DUNK_ACCENT_COLOR: Color = Color("ea6a68")
const DISABLED_TINT: Color = Color(0.42, 0.42, 0.48, 0.86)
const TEXT_COLOR: Color = Color(0.98, 0.98, 0.96, 1.0)
const TEXT_OUTLINE_COLOR: Color = Color(0.15, 0.08, 0.12, 0.95)
const JOYSTICK_BASE_COLOR: Color = Color("5565bb")
const JOYSTICK_RING_COLOR: Color = Color("9cb7ff")
const JOYSTICK_KNOB_COLOR: Color = Color("2d3158")
const JOYSTICK_KNOB_HIGHLIGHT: Color = Color("b7bbd0")
const JOYSTICK_RING_FILL_COLOR: Color = Color(0.61, 0.72, 1.0, 0.18)
const JOYSTICK_RING_STROKE_COLOR: Color = Color(0.61, 0.72, 1.0, 0.82)

var _layout_metrics: Dictionary = {}
var _panel_state: Dictionary = {}

var _shoot_label: Label
var _move_label: Label
var _pass_left_label: Label
var _pass_right_label: Label
var _dunk_label: Label
var _pass_left_focus_label: Label
var _pass_right_focus_label: Label


func _ready() -> void:
	anchors_preset = PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()


func apply_layout(layout_metrics: Dictionary) -> void:
	_layout_metrics = layout_metrics.duplicate(true)
	_apply_label_layouts()
	queue_redraw()


func set_panel_state(panel_state: Dictionary) -> void:
	_panel_state = panel_state.duplicate(true)
	visible = bool(_panel_state.get("controls_visible", true))
	_sync_label_text()
	_apply_label_layouts()
	queue_redraw()


func _build_ui() -> void:
	_shoot_label = _create_zone_label("SHOOT")
	_move_label = _create_zone_label("MOVE")
	_pass_left_label = _create_zone_label("PASS")
	_pass_right_label = _create_zone_label("PASS")
	_dunk_label = _create_zone_label("DUNK")
	_pass_left_focus_label = _create_focus_label()
	_pass_right_focus_label = _create_focus_label()


func _create_zone_label(text_value: String) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.add_theme_color_override("font_outline_color", TEXT_OUTLINE_COLOR)
	add_child(label)
	return label


func _create_focus_label() -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.92, 0.94))
	label.add_theme_color_override("font_outline_color", TEXT_OUTLINE_COLOR)
	add_child(label)
	return label


func _sync_label_text() -> void:
	var pass_available: bool = bool(_panel_state.get("pass_available", false))
	var pass_role: String = str(_panel_state.get("pass_target_role", ""))
	var focus_text: String = pass_role if pass_available and pass_role != "" else "NO TARGET"
	_pass_left_focus_label.text = focus_text
	_pass_right_focus_label.text = focus_text


func _apply_label_layouts() -> void:
	var zone_rects: Dictionary = _layout_metrics.get("control_zone_rects", {})
	if zone_rects.is_empty():
		return
	_layout_zone_label(_shoot_label, zone_rects.get("shoot", Rect2()), 0.18, 0.48, 0.42)
	_layout_zone_label(_move_label, zone_rects.get("move", Rect2()), 0.14, 0.26, 0.22)
	_layout_zone_label(_pass_left_label, zone_rects.get("pass_left", Rect2()), 0.34, 0.42, 0.22)
	_layout_zone_label(_pass_right_label, zone_rects.get("pass_right", Rect2()), 0.34, 0.42, 0.22)
	_layout_zone_label(_dunk_label, zone_rects.get("dunk", Rect2()), 0.18, 0.48, 0.42)
	_layout_focus_label(_pass_left_focus_label, zone_rects.get("pass_left", Rect2()))
	_layout_focus_label(_pass_right_focus_label, zone_rects.get("pass_right", Rect2()))


func _layout_zone_label(label: Label, zone_rect: Rect2, top_ratio: float, height_ratio: float, size_ratio: float) -> void:
	if label == null:
		return
	var label_rect: Rect2 = Rect2(
		Vector2(zone_rect.position.x, zone_rect.position.y + zone_rect.size.y * top_ratio),
		Vector2(zone_rect.size.x, zone_rect.size.y * height_ratio)
	)
	label.position = label_rect.position
	label.size = label_rect.size
	var font_size: int = int(clampi(int(roundf(zone_rect.size.y * size_ratio)), 24, 82))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", max(2, int(roundf(font_size * 0.1))))


func _layout_focus_label(label: Label, zone_rect: Rect2) -> void:
	if label == null:
		return
	var label_rect: Rect2 = Rect2(
		Vector2(zone_rect.position.x + zone_rect.size.x * 0.08, zone_rect.end.y - zone_rect.size.y * 0.24),
		Vector2(zone_rect.size.x * 0.84, zone_rect.size.y * 0.18)
	)
	label.position = label_rect.position
	label.size = label_rect.size
	var font_size: int = int(clampi(int(roundf(zone_rect.size.y * 0.12)), 15, 28))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", max(2, int(roundf(font_size * 0.1))))


func _draw() -> void:
	if not visible:
		return
	var panel_rect: Rect2 = _layout_metrics.get("control_panel_rect", Rect2())
	var zone_rects: Dictionary = _layout_metrics.get("control_zone_rects", {})
	if panel_rect.size.x <= 0.0 or zone_rects.is_empty():
		return

	draw_rect(Rect2(panel_rect.position + Vector2(0.0, 6.0), panel_rect.size), PANEL_SHADOW_COLOR)

	var pass_available: bool = bool(_panel_state.get("pass_available", false))
	var highlight_zone: String = str(_panel_state.get("highlight_zone", ""))

	_draw_zone(zone_rects.get("shoot", Rect2()), _resolve_zone_visual_state("shoot", highlight_zone, pass_available))
	_draw_zone(zone_rects.get("move", Rect2()), _resolve_zone_visual_state("move", highlight_zone, pass_available))
	_draw_zone(zone_rects.get("pass_left", Rect2()), _resolve_zone_visual_state("pass_left", highlight_zone, pass_available))
	_draw_zone(zone_rects.get("pass_right", Rect2()), _resolve_zone_visual_state("pass_right", highlight_zone, pass_available))
	_draw_zone(zone_rects.get("dunk", Rect2()), _resolve_zone_visual_state("dunk", highlight_zone, pass_available))

	_draw_pass_focus_badge(zone_rects.get("pass_left", Rect2()), pass_available, highlight_zone == "pass_left")
	_draw_pass_focus_badge(zone_rects.get("pass_right", Rect2()), pass_available, highlight_zone == "pass_right")
	_draw_joystick(zone_rects.get("move", Rect2()))
	_draw_shot_meter(_get_top_action_rect(zone_rects))


func _draw_zone(zone_rect: Rect2, zone_visual_state: Dictionary) -> void:
	if zone_rect.size.x <= 0.0 or zone_rect.size.y <= 0.0:
		return
	var resolved_base: Color = zone_visual_state.get("base_color", BUTTON_IDLE_COLOR)
	var resolved_accent: Color = zone_visual_state.get("accent_color", BUTTON_IDLE_ACCENT_COLOR)
	var highlighted: bool = bool(zone_visual_state.get("highlighted", false))

	draw_rect(zone_rect, resolved_base)
	var inset_rect: Rect2 = zone_rect.grow(-6.0)
	if inset_rect.size.x > 0.0 and inset_rect.size.y > 0.0:
		draw_rect(inset_rect, resolved_base.lerp(resolved_accent, 0.2))
		var accent_height: float = maxf(zone_rect.size.y * 0.18, 10.0)
		draw_rect(Rect2(inset_rect.position, Vector2(inset_rect.size.x, accent_height)), resolved_accent)
	draw_rect(zone_rect, PANEL_OUTLINE_COLOR, false, 5.0)
	if highlighted:
		draw_rect(zone_rect.grow(-3.0), Color(1.0, 0.96, 0.84, 0.66), false, 3.0)


func get_zone_visual_state_snapshot(zone_name: String) -> Dictionary:
	var pass_available: bool = bool(_panel_state.get("pass_available", false))
	var highlight_zone: String = str(_panel_state.get("highlight_zone", ""))
	return _resolve_zone_visual_state(zone_name, highlight_zone, pass_available).duplicate(true)


func _resolve_zone_visual_state(zone_name: String, highlight_zone: String, pass_available: bool) -> Dictionary:
	var palette: Dictionary = _get_zone_palette(zone_name)
	var highlighted: bool = highlight_zone == zone_name
	var disabled: bool = (zone_name == "pass_left" or zone_name == "pass_right") and not pass_available
	var resolved_base: Color = BUTTON_IDLE_COLOR
	var resolved_accent: Color = BUTTON_IDLE_ACCENT_COLOR
	if disabled:
		resolved_base = BUTTON_IDLE_COLOR.lerp(DISABLED_TINT, 0.58)
		resolved_accent = BUTTON_IDLE_ACCENT_COLOR.lerp(DISABLED_TINT, 0.42)
	elif highlighted:
		resolved_base = palette.get("base_color", BUTTON_IDLE_COLOR)
		resolved_accent = palette.get("accent_color", BUTTON_IDLE_ACCENT_COLOR)
	return {
		"zone_name": zone_name,
		"highlighted": highlighted and not disabled,
		"disabled": disabled,
		"base_color": resolved_base,
		"accent_color": resolved_accent,
		"base_color_html": resolved_base.to_html(false),
		"accent_color_html": resolved_accent.to_html(false),
	}


func _get_zone_palette(zone_name: String) -> Dictionary:
	match zone_name:
		"shoot":
			return {"base_color": SHOOT_BASE_COLOR, "accent_color": SHOOT_ACCENT_COLOR}
		"move":
			return {"base_color": MOVE_BASE_COLOR, "accent_color": MOVE_ACCENT_COLOR}
		"pass_left", "pass_right":
			return {"base_color": PASS_BASE_COLOR, "accent_color": PASS_ACCENT_COLOR}
		"dunk":
			return {"base_color": DUNK_BASE_COLOR, "accent_color": DUNK_ACCENT_COLOR}
	return {"base_color": BUTTON_IDLE_COLOR, "accent_color": BUTTON_IDLE_ACCENT_COLOR}


func _draw_pass_focus_badge(zone_rect: Rect2, pass_available: bool, highlighted: bool) -> void:
	if zone_rect.size.x <= 0.0 or zone_rect.size.y <= 0.0:
		return
	var badge_rect: Rect2 = Rect2(
		Vector2(zone_rect.position.x + zone_rect.size.x * 0.16, zone_rect.end.y - zone_rect.size.y * 0.22),
		Vector2(zone_rect.size.x * 0.68, zone_rect.size.y * 0.12)
	)
	var badge_color: Color = Color(0.16, 0.16, 0.2, 0.32 if pass_available else 0.22)
	if highlighted and pass_available:
		badge_color = Color(0.28, 0.22, 0.16, 0.45)
	draw_rect(badge_rect, badge_color)
	draw_rect(badge_rect, Color(1.0, 0.94, 0.84, 0.38), false, 2.0)


func _draw_joystick(move_rect: Rect2) -> void:
	if move_rect.size.x <= 0.0 or move_rect.size.y <= 0.0:
		return
	var active: bool = bool(_panel_state.get("anchor_visible", false))
	var anchor_position: Vector2 = _panel_state.get("anchor_screen", move_rect.get_center())
	var current_position: Vector2 = _panel_state.get("current_screen", anchor_position)
	if not active:
		anchor_position = move_rect.get_center() + Vector2(0.0, move_rect.size.y * 0.1)
		current_position = anchor_position
	var base_radius: float = minf(move_rect.size.x, move_rect.size.y) * 0.22
	var ring_radius: float = base_radius * 1.28
	var knob_radius: float = base_radius * 0.42
	draw_circle(anchor_position, ring_radius, JOYSTICK_RING_FILL_COLOR)
	draw_arc(anchor_position, ring_radius, 0.0, TAU, 40, JOYSTICK_RING_STROKE_COLOR, 4.0)
	draw_circle(anchor_position, base_radius, JOYSTICK_BASE_COLOR)
	draw_arc(anchor_position, base_radius, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.14), 3.0)
	var knob_position: Vector2 = anchor_position
	if active:
		knob_position = current_position
		if knob_position.distance_to(anchor_position) > base_radius:
			knob_position = anchor_position + (knob_position - anchor_position).limit_length(base_radius)
	draw_circle(knob_position, knob_radius, JOYSTICK_KNOB_COLOR)
	draw_circle(knob_position + Vector2(-knob_radius * 0.18, -knob_radius * 0.22), knob_radius * 0.48, JOYSTICK_KNOB_HIGHLIGHT)


func get_shot_meter_bar_rect_snapshot() -> Rect2:
	var zone_rects: Dictionary = _layout_metrics.get("control_zone_rects", {})
	if zone_rects.is_empty():
		return Rect2()
	return _compute_shot_meter_rect(_get_top_action_rect(zone_rects), _panel_state.get("shot_meter", {}))


func _get_top_action_rect(zone_rects: Dictionary) -> Rect2:
	var shoot_rect: Rect2 = zone_rects.get("shoot", Rect2())
	var dunk_rect: Rect2 = zone_rects.get("dunk", Rect2())
	if shoot_rect.size.x <= 0.0:
		return dunk_rect
	if dunk_rect.size.x <= 0.0:
		return shoot_rect
	return Rect2(
		shoot_rect.position,
		Vector2(maxf(dunk_rect.end.x - shoot_rect.position.x, 1.0), maxf(maxf(shoot_rect.size.y, dunk_rect.size.y), 1.0))
	)


func _compute_shot_meter_rect(action_rect: Rect2, shot_meter: Dictionary) -> Rect2:
	if action_rect.size.x <= 0.0 or action_rect.size.y <= 0.0:
		return Rect2()
	if not bool(shot_meter.get("visible", false)):
		return Rect2()
	var padding_x: float = maxf(action_rect.size.x * 0.035, 28.0)
	var meter_width: float = maxf(action_rect.size.x - padding_x * 2.0, 1.0)
	var meter_height: float = minf(maxf(float(shot_meter.get("height", 42.0)), action_rect.size.y * 0.22), action_rect.size.y * 0.34)
	return Rect2(
		Vector2(action_rect.get_center().x - meter_width * 0.5, action_rect.end.y - meter_height - action_rect.size.y * 0.12),
		Vector2(meter_width, meter_height)
	)


func _draw_shot_meter(action_rect: Rect2) -> void:
	var shot_meter: Dictionary = _panel_state.get("shot_meter", {})
	var bar_rect: Rect2 = _compute_shot_meter_rect(action_rect, shot_meter)
	if bar_rect.size.x <= 0.0 or bar_rect.size.y <= 0.0:
		return
	var marker_width: float = minf(float(shot_meter.get("marker_width", 20.0)), bar_rect.size.x * 0.18)
	var green_start: float = float(shot_meter.get("green_start", 0.6))
	var green_end: float = float(shot_meter.get("green_end", 0.78))
	var yellow_start: float = float(shot_meter.get("yellow_start", 0.32))
	var yellow_end: float = float(shot_meter.get("yellow_end", green_start))
	var progress: float = float(shot_meter.get("progress", 0.0))
	draw_rect(bar_rect.grow(10.0), Color(0.05, 0.05, 0.08, 0.72))
	draw_rect(bar_rect, Color(0.76, 0.16, 0.16, 0.96))
	var yellow_rect: Rect2 = Rect2(
		Vector2(bar_rect.position.x + bar_rect.size.x * yellow_start, bar_rect.position.y),
		Vector2(bar_rect.size.x * maxf(yellow_end - yellow_start, 0.0), bar_rect.size.y)
	)
	if yellow_rect.size.x > 0.0:
		draw_rect(yellow_rect, Color(1.0, 0.84, 0.3, 0.98))
	var green_rect: Rect2 = Rect2(
		Vector2(bar_rect.position.x + bar_rect.size.x * green_start, bar_rect.position.y),
		Vector2(bar_rect.size.x * maxf(green_end - green_start, 0.0), bar_rect.size.y)
	)
	if green_rect.size.x > 0.0:
		draw_rect(green_rect, Color(0.22, 0.86, 0.34, 1.0))
	draw_rect(bar_rect, Color(0.98, 0.95, 0.86, 0.92), false, 4.0)
	var marker_x: float = bar_rect.position.x + bar_rect.size.x * progress - marker_width * 0.5
	var marker_rect: Rect2 = Rect2(Vector2(marker_x, bar_rect.position.y - 7.0), Vector2(marker_width, bar_rect.size.y + 14.0))
	draw_rect(marker_rect, Color(0.98, 0.96, 0.9))
	draw_rect(marker_rect.grow(-4.0), Color(0.08, 0.09, 0.1, 0.92))
