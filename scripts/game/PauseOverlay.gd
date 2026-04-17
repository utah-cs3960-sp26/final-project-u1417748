class_name PauseOverlay
extends Control

const SETTINGS_PANEL_SCENE: PackedScene = preload("res://scenes/ui/SettingsPanel.tscn")
const DEFAULT_VIEWPORT_SIZE: Vector2 = Vector2(1080.0, 1920.0)
const PANEL_TARGET_WIDTH: float = 820.0
const PANEL_MIN_SIDE_PADDING: float = 24.0
const PANEL_MAX_SIDE_PADDING: float = 72.0
const PANEL_RAISE_OFFSET: float = 100.0

signal resume_pressed()
signal restart_pressed()
signal quit_pressed()
signal settings_pressed()

var _center_container: Control
var _panel_container: PanelContainer
var _resume_button: Button
var _restart_button: Button
var _settings_button: Button
var _quit_button: Button
var _settings_modal: Control
var _settings_panel_instance: PanelContainer
var _resolved_viewport_rect: Rect2 = Rect2(Vector2.ZERO, DEFAULT_VIEWPORT_SIZE)
var _resolved_safe_rect: Rect2 = Rect2(Vector2.ZERO, DEFAULT_VIEWPORT_SIZE)


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_apply_viewport_layout()


func apply_layout(layout_metrics: Dictionary) -> void:
	var viewport_rect: Rect2 = layout_metrics.get("viewport_rect", Rect2(Vector2.ZERO, DEFAULT_VIEWPORT_SIZE))
	var safe_rect: Rect2 = layout_metrics.get("safe_rect", viewport_rect)
	_apply_layout_rects(viewport_rect, safe_rect)


func get_layout_snapshot() -> Dictionary:
	return {
		"root_rect": get_global_rect(),
		"viewport_rect": _resolved_viewport_rect,
		"safe_rect": _resolved_safe_rect,
		"panel_rect": _panel_container.get_global_rect() if _panel_container != null else Rect2(),
		"visible": visible,
	}


func _build_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.32)
	dim.anchors_preset = PRESET_FULL_RECT
	add_child(dim)

	_center_container = Control.new()
	add_child(_center_container)

	_panel_container = PanelContainer.new()
	_panel_container.custom_minimum_size = Vector2(PANEL_TARGET_WIDTH, 0.0)
	_center_container.add_child(_panel_container)

	var inner_margin: MarginContainer = MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 56)
	inner_margin.add_theme_constant_override("margin_top", 48)
	inner_margin.add_theme_constant_override("margin_right", 56)
	inner_margin.add_theme_constant_override("margin_bottom", 48)
	_panel_container.add_child(inner_margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 22)
	inner_margin.add_child(vbox)

	var title: Label = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

	_resume_button = _create_button("Resume", func() -> void: resume_pressed.emit())
	vbox.add_child(_resume_button)

	_restart_button = _create_button("Restart Match", func() -> void: restart_pressed.emit())
	vbox.add_child(_restart_button)

	_settings_button = _create_button("Settings", func() -> void: open_settings())
	vbox.add_child(_settings_button)

	_quit_button = _create_button("Quit Game", func() -> void: quit_pressed.emit())
	vbox.add_child(_quit_button)


func _create_button(text_value: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 84.0)
	button.add_theme_font_size_override("font_size", 28)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button


func open_settings() -> void:
	settings_pressed.emit()
	if _settings_modal != null and is_instance_valid(_settings_modal):
		return

	_settings_modal = Control.new()
	_settings_modal.anchors_preset = PRESET_FULL_RECT
	_settings_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_settings_modal)

	var modal_dim: ColorRect = ColorRect.new()
	modal_dim.color = Color(0.0, 0.0, 0.0, 0.55)
	modal_dim.anchors_preset = PRESET_FULL_RECT
	_settings_modal.add_child(modal_dim)

	var modal_margin: MarginContainer = MarginContainer.new()
	modal_margin.anchors_preset = PRESET_FULL_RECT
	modal_margin.add_theme_constant_override("margin_left", 72)
	modal_margin.add_theme_constant_override("margin_top", 180)
	modal_margin.add_theme_constant_override("margin_right", 72)
	modal_margin.add_theme_constant_override("margin_bottom", 180)
	_settings_modal.add_child(modal_margin)

	var modal_center: CenterContainer = CenterContainer.new()
	modal_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_margin.add_child(modal_center)

	_settings_panel_instance = SETTINGS_PANEL_SCENE.instantiate() as PanelContainer
	modal_center.add_child(_settings_panel_instance)
	if _settings_panel_instance.has_signal("close_requested"):
		_settings_panel_instance.close_requested.connect(close_settings)


func close_settings() -> void:
	if _settings_modal != null and is_instance_valid(_settings_modal):
		_settings_modal.queue_free()
	_settings_modal = null
	_settings_panel_instance = null


func _apply_viewport_layout() -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		_apply_layout_rects(Rect2(Vector2.ZERO, DEFAULT_VIEWPORT_SIZE), Rect2(Vector2.ZERO, DEFAULT_VIEWPORT_SIZE))
		return
	var viewport_rect: Rect2 = viewport.get_visible_rect()
	_apply_layout_rects(viewport_rect, viewport_rect)


func _apply_layout_rects(viewport_rect: Rect2, safe_rect: Rect2) -> void:
	var resolved_viewport_rect: Rect2 = viewport_rect
	if resolved_viewport_rect.size.x <= 0.0 or resolved_viewport_rect.size.y <= 0.0:
		resolved_viewport_rect = Rect2(Vector2.ZERO, DEFAULT_VIEWPORT_SIZE)

	var resolved_safe_rect: Rect2 = safe_rect
	if resolved_safe_rect.size.x <= 0.0 or resolved_safe_rect.size.y <= 0.0:
		resolved_safe_rect = resolved_viewport_rect

	_resolved_viewport_rect = resolved_viewport_rect
	_resolved_safe_rect = resolved_safe_rect

	set_anchors_preset(PRESET_TOP_LEFT)
	position = resolved_viewport_rect.position
	size = resolved_viewport_rect.size
	custom_minimum_size = resolved_viewport_rect.size

	if _center_container == null:
		return

	_center_container.set_anchors_preset(PRESET_TOP_LEFT)
	_center_container.position = resolved_safe_rect.position - resolved_viewport_rect.position
	_center_container.size = resolved_safe_rect.size
	_center_container.custom_minimum_size = resolved_safe_rect.size

	if _panel_container != null:
		var horizontal_padding: float = clampf(resolved_safe_rect.size.x * 0.05, PANEL_MIN_SIDE_PADDING, PANEL_MAX_SIDE_PADDING)
		var panel_width: float = minf(PANEL_TARGET_WIDTH, maxf(resolved_safe_rect.size.x - horizontal_padding * 2.0, 320.0))
		_panel_container.custom_minimum_size = Vector2(panel_width, 0.0)
		var panel_size: Vector2 = _panel_container.get_combined_minimum_size()
		var panel_x: float = maxf((resolved_safe_rect.size.x - panel_size.x) * 0.5, 0.0)
		var centered_y: float = (resolved_safe_rect.size.y - panel_size.y) * 0.5 - PANEL_RAISE_OFFSET
		var panel_y: float = clampf(centered_y, 0.0, maxf(resolved_safe_rect.size.y - panel_size.y, 0.0))
		_panel_container.position = Vector2(panel_x, panel_y)
		_panel_container.size = panel_size
