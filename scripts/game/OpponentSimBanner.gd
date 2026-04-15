class_name OpponentSimBanner
extends Control

signal advance_requested()

const BACKGROUND_COLOR: Color = Color(0.0, 0.0, 0.0, 0.8)
const TEXT_COLOR: Color = Color(0.96, 0.98, 0.92, 1.0)
const TEXT_OUTLINE_COLOR: Color = Color(0.02, 0.02, 0.025, 0.94)
const HORIZONTAL_PADDING_RATIO: float = 0.055
const DEFAULT_VIEWPORT_SIZE: Vector2 = Vector2(1080.0, 1920.0)

var _background: ColorRect
var _label: Label
var _banner_rect: Rect2 = Rect2()
var _label_rect: Rect2 = Rect2()
var _current_text: String = ""


func _ready() -> void:
	anchors_preset = PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_ui()


func apply_layout(layout_metrics: Dictionary) -> void:
	if _background == null or _label == null:
		return

	var viewport_rect: Rect2 = layout_metrics.get("viewport_rect", Rect2(Vector2.ZERO, DEFAULT_VIEWPORT_SIZE))
	var safe_rect: Rect2 = layout_metrics.get("safe_rect", viewport_rect)
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		safe_rect = viewport_rect
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		safe_rect = Rect2(Vector2.ZERO, DEFAULT_VIEWPORT_SIZE)

	var root_size: Vector2 = viewport_rect.size if viewport_rect.size.x > 0.0 and viewport_rect.size.y > 0.0 else safe_rect.size
	var ui_scale: float = maxf(root_size.y / DEFAULT_VIEWPORT_SIZE.y, 0.65)
	var banner_height: float = clampf(safe_rect.size.y * 0.09, 96.0 * ui_scale, 150.0 * ui_scale)
	_banner_rect = Rect2(
		Vector2(safe_rect.position.x, safe_rect.position.y + safe_rect.size.y * 0.5 - banner_height * 0.5),
		Vector2(safe_rect.size.x, banner_height)
	)
	var horizontal_padding: float = _banner_rect.size.x * HORIZONTAL_PADDING_RATIO
	_label_rect = Rect2(
		_banner_rect.position + Vector2(horizontal_padding, 0.0),
		Vector2(maxf(_banner_rect.size.x - horizontal_padding * 2.0, 0.0), _banner_rect.size.y)
	)

	_background.position = _banner_rect.position
	_background.size = _banner_rect.size
	_label.position = _label_rect.position
	_label.size = _label_rect.size

	var font_size: int = int(clampi(int(roundf(_banner_rect.size.y * 0.34)), 28, 54))
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_constant_override("outline_size", max(2, int(roundf(float(font_size) * 0.1))))


func show_action(text_value: String) -> void:
	_current_text = text_value
	if _label != null:
		_label.text = _current_text
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func hide_banner() -> void:
	_current_text = ""
	if _label != null:
		_label.text = ""
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func get_layout_snapshot() -> Dictionary:
	return {
		"banner_rect": _background.get_global_rect() if _background != null else Rect2(),
		"label_rect": _label.get_global_rect() if _label != null else Rect2(),
		"visible": visible,
		"background_color": _background.color if _background != null else Color(0.0, 0.0, 0.0, 0.0),
		"text": _current_text,
	}


func get_current_text() -> String:
	return _current_text


func is_showing() -> bool:
	return visible


func _build_ui() -> void:
	_background = ColorRect.new()
	_background.color = BACKGROUND_COLOR
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.clip_text = true
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.add_theme_color_override("font_outline_color", TEXT_OUTLINE_COLOR)
	add_child(_label)


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			accept_event()
			advance_requested.emit()
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			advance_requested.emit()
