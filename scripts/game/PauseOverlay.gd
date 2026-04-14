class_name PauseOverlay
extends Control

signal resume_pressed()
signal restart_pressed()
signal quit_pressed()
signal no_defenders_toggled(enabled: bool)
signal show_controls_toggled(enabled: bool)

var _panel_container: PanelContainer
var _resume_button: Button
var _restart_button: Button
var _show_controls_button: CheckButton
var _no_defenders_button: CheckButton
var _quit_button: Button

var _syncing_no_defenders_button: bool = false
var _syncing_controls_button: bool = false


func _ready() -> void:
	anchors_preset = PRESET_FULL_RECT
	visible = false
	_build_ui()


func _build_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.58)
	dim.anchors_preset = PRESET_FULL_RECT
	add_child(dim)

	var margin: MarginContainer = MarginContainer.new()
	margin.anchors_preset = PRESET_FULL_RECT
	margin.add_theme_constant_override("margin_left", 96)
	margin.add_theme_constant_override("margin_top", 180)
	margin.add_theme_constant_override("margin_right", 96)
	margin.add_theme_constant_override("margin_bottom", 180)
	add_child(margin)

	var center: CenterContainer = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)

	_panel_container = PanelContainer.new()
	_panel_container.custom_minimum_size = Vector2(560.0, 0.0)
	_panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(_panel_container)

	var inner_margin: MarginContainer = MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 42)
	inner_margin.add_theme_constant_override("margin_top", 36)
	inner_margin.add_theme_constant_override("margin_right", 42)
	inner_margin.add_theme_constant_override("margin_bottom", 36)
	_panel_container.add_child(inner_margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 18)
	inner_margin.add_child(vbox)

	var title: Label = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	_resume_button = _create_button("Resume", func() -> void: resume_pressed.emit())
	vbox.add_child(_resume_button)

	_restart_button = _create_button("Restart Match", func() -> void: restart_pressed.emit())
	vbox.add_child(_restart_button)

	_show_controls_button = _create_toggle()
	_show_controls_button.toggled.connect(_on_show_controls_button_toggled)
	vbox.add_child(_show_controls_button)
	_update_show_controls_button_text()

	_no_defenders_button = _create_toggle()
	_no_defenders_button.toggled.connect(_on_no_defenders_button_toggled)
	vbox.add_child(_no_defenders_button)
	_update_no_defenders_button_text()

	_quit_button = _create_button("Quit Game", func() -> void: quit_pressed.emit())
	vbox.add_child(_quit_button)


func _create_button(text_value: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 68.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button


func _create_toggle() -> CheckButton:
	var button: CheckButton = CheckButton.new()
	button.custom_minimum_size = Vector2(0.0, 64.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


func set_no_defenders_enabled(enabled: bool) -> void:
	if _no_defenders_button == null:
		return
	_syncing_no_defenders_button = true
	_no_defenders_button.button_pressed = enabled
	_syncing_no_defenders_button = false
	_update_no_defenders_button_text()


func is_no_defenders_enabled() -> bool:
	return _no_defenders_button != null and _no_defenders_button.button_pressed


func set_controls_visible_enabled(enabled: bool) -> void:
	if _show_controls_button == null:
		return
	_syncing_controls_button = true
	_show_controls_button.button_pressed = enabled
	_syncing_controls_button = false
	_update_show_controls_button_text()


func is_controls_visible_enabled() -> bool:
	return _show_controls_button != null and _show_controls_button.button_pressed


func _on_no_defenders_button_toggled(enabled: bool) -> void:
	_update_no_defenders_button_text()
	if _syncing_no_defenders_button:
		return
	no_defenders_toggled.emit(enabled)


func _on_show_controls_button_toggled(enabled: bool) -> void:
	_update_show_controls_button_text()
	if _syncing_controls_button:
		return
	show_controls_toggled.emit(enabled)


func _update_no_defenders_button_text() -> void:
	if _no_defenders_button == null:
		return
	_no_defenders_button.text = "No Defenders: %s" % ("ON" if _no_defenders_button.button_pressed else "OFF")


func _update_show_controls_button_text() -> void:
	if _show_controls_button == null:
		return
	_show_controls_button.text = "Show Controls: %s" % ("ON" if _show_controls_button.button_pressed else "OFF")
