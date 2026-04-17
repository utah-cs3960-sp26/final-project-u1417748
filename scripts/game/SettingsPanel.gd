class_name SettingsPanel
extends PanelContainer

signal close_requested()

@onready var _show_controls_check: CheckButton = %ShowControlsCheck
@onready var _no_defenders_check: CheckButton = %NoDefendersCheck
@onready var _show_debug_check: CheckButton = %ShowDebugCheck
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_show_controls_check.button_pressed = GameSettings.show_controls
	_no_defenders_check.button_pressed = GameSettings.no_defenders
	_show_debug_check.button_pressed = GameSettings.show_debug

	_show_controls_check.toggled.connect(GameSettings.set_show_controls)
	_no_defenders_check.toggled.connect(GameSettings.set_no_defenders)
	_show_debug_check.toggled.connect(GameSettings.set_show_debug)
	_back_button.pressed.connect(_on_back_pressed)

	GameSettings.changed.connect(_on_settings_changed)


func _on_back_pressed() -> void:
	close_requested.emit()


func _on_settings_changed(key: String, value: bool) -> void:
	match key:
		"show_controls":
			if _show_controls_check.button_pressed != value:
				_show_controls_check.set_pressed_no_signal(value)
		"no_defenders":
			if _no_defenders_check.button_pressed != value:
				_no_defenders_check.set_pressed_no_signal(value)
		"show_debug":
			if _show_debug_check.button_pressed != value:
				_show_debug_check.set_pressed_no_signal(value)
