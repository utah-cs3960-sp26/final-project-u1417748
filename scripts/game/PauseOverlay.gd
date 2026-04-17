class_name PauseOverlay
extends Control

const SETTINGS_PANEL_SCENE: PackedScene = preload("res://scenes/ui/SettingsPanel.tscn")

signal resume_pressed()
signal restart_pressed()
signal quit_pressed()
signal settings_pressed()

var _panel_container: PanelContainer
var _resume_button: Button
var _restart_button: Button
var _settings_button: Button
var _quit_button: Button
var _settings_modal: Control
var _settings_panel_instance: PanelContainer


func _ready() -> void:
	anchors_preset = PRESET_FULL_RECT
	visible = false
	_build_ui()


func _build_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.32)
	dim.anchors_preset = PRESET_FULL_RECT
	add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.anchors_preset = PRESET_FULL_RECT
	center.offset_left = 0.0
	center.offset_top = 0.0
	center.offset_right = 0.0
	center.offset_bottom = 0.0
	add_child(center)

	_panel_container = PanelContainer.new()
	_panel_container.custom_minimum_size = Vector2(820.0, 0.0)
	center.add_child(_panel_container)

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
