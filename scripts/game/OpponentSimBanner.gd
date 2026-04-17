class_name OpponentSimBanner
extends Control

signal advance_requested()

const BACKGROUND_COLOR: Color = Color(0.0, 0.0, 0.0, 0.8)
const TEXT_COLOR: Color = Color(0.96, 0.98, 0.92, 1.0)
const TEXT_OUTLINE_COLOR: Color = Color(0.02, 0.02, 0.025, 0.94)
const SCORE_OUTLINE_COLOR: Color = Color(0.18, 0.12, 0.0, 0.96)
const SCORE_COLOR_LOW: Color = Color(1.00, 0.78, 0.12, 1.0)
const SCORE_COLOR_HIGH: Color = Color(1.00, 0.98, 0.55, 1.0)
const SCORE_JITTER_PIXELS: float = 3.5
const SCORE_JITTER_FREQ_X: float = 31.0
const SCORE_JITTER_FREQ_Y: float = 27.0
const HORIZONTAL_PADDING_RATIO: float = 0.055
const DEFAULT_VIEWPORT_SIZE: Vector2 = Vector2(1080.0, 1920.0)
const SCORE_GRADIENT_SHADER: Shader = preload("res://scripts/game/ScoreBannerGradient.gdshader")

var _background: ColorRect
var _label: Label
var _score_group: Control
var _score_label: Label
var _score_shader_material: ShaderMaterial
var _banner_rect: Rect2 = Rect2()
var _label_rect: Rect2 = Rect2()
var _current_text: String = ""
var _score_visible: bool = false
var _score_jitter_enabled: bool = false
var _score_jitter_time: float = 0.0


func _ready() -> void:
	anchors_preset = PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_ui()
	set_process(true)


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

	if _score_group != null and _score_label != null:
		_score_group.position = _banner_rect.position
		_score_group.size = _banner_rect.size
		_score_label.position = Vector2.ZERO
		_score_label.size = _banner_rect.size
		var score_font_size: int = int(clampi(int(roundf(_banner_rect.size.y * 0.46)), 38, 72))
		_score_label.add_theme_font_size_override("font_size", score_font_size)
		_score_label.add_theme_constant_override("outline_size", max(3, int(roundf(float(score_font_size) * 0.12))))


func show_action(text_value: String) -> void:
	_current_text = text_value
	if _label != null:
		_label.text = _current_text
		_label.visible = true
	if _score_group != null:
		_score_group.visible = false
	_score_visible = false
	_score_jitter_enabled = false
	_score_jitter_time = 0.0
	if _score_label != null:
		_score_label.position = Vector2.ZERO
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func show_score(points: int, intercept_input: bool = true) -> void:
	_current_text = "%d points!" % points
	if _label != null:
		_label.visible = false
		_label.text = ""
	if _score_label != null:
		_score_label.text = _current_text
		_score_label.position = Vector2.ZERO
	if _score_group != null:
		_score_group.visible = true
	_score_visible = true
	_score_jitter_enabled = points >= 3
	_score_jitter_time = 0.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP if intercept_input else Control.MOUSE_FILTER_IGNORE


func hide_banner() -> void:
	_current_text = ""
	if _label != null:
		_label.text = ""
		_label.visible = true
	if _score_label != null:
		_score_label.text = ""
		_score_label.position = Vector2.ZERO
	if _score_group != null:
		_score_group.visible = false
	_score_visible = false
	_score_jitter_enabled = false
	_score_jitter_time = 0.0
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func get_layout_snapshot() -> Dictionary:
	var snapshot: Dictionary = {
		"banner_rect": _background.get_global_rect() if _background != null else Rect2(),
		"label_rect": _label.get_global_rect() if _label != null else Rect2(),
		"visible": visible,
		"background_color": _background.color if _background != null else Color(0.0, 0.0, 0.0, 0.0),
		"text": _current_text,
		"is_score": _score_visible,
		"jitter_enabled": _score_jitter_enabled,
	}
	if _score_visible and _score_label != null:
		snapshot["label_rect"] = _score_label.get_global_rect()
		snapshot["score_label_position"] = _score_label.position
	return snapshot


func get_current_text() -> String:
	return _current_text


func is_showing() -> bool:
	return visible


func is_score_display() -> bool:
	return _score_visible


func is_jitter_active() -> bool:
	return _score_visible and _score_jitter_enabled


func get_score_label_offset() -> Vector2:
	if _score_label == null:
		return Vector2.ZERO
	return _score_label.position


func _process(delta: float) -> void:
	if not _score_visible or not _score_jitter_enabled or _score_label == null:
		return
	_score_jitter_time += delta
	var ox: float = sin(_score_jitter_time * SCORE_JITTER_FREQ_X) * SCORE_JITTER_PIXELS
	var oy: float = cos(_score_jitter_time * SCORE_JITTER_FREQ_Y) * SCORE_JITTER_PIXELS
	_score_label.position = Vector2(ox, oy)


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

	_score_group = Control.new()
	_score_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_group.visible = false
	add_child(_score_group)

	_score_shader_material = ShaderMaterial.new()
	_score_shader_material.shader = SCORE_GRADIENT_SHADER
	_score_shader_material.set_shader_parameter("color_low", SCORE_COLOR_LOW)
	_score_shader_material.set_shader_parameter("color_high", SCORE_COLOR_HIGH)
	_score_group.material = _score_shader_material

	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score_label.clip_text = true
	_score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_label.add_theme_color_override("font_color", Color.WHITE)
	_score_label.add_theme_color_override("font_outline_color", SCORE_OUTLINE_COLOR)
	_score_group.add_child(_score_label)


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
