class_name HUD
extends Control

signal pause_pressed()

var _home_label: Label
var _timer_label: Label
var _away_label: Label
var _pause_button: Button


func _ready() -> void:
	anchors_preset = PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()


func _build_ui() -> void:
	var banner: ColorRect = ColorRect.new()
	banner.color = Color(0.02, 0.02, 0.03, 0.96)
	banner.position = Vector2(0.0, 0.0)
	banner.size = Vector2(1080.0, 128.0)
	add_child(banner)

	_home_label = Label.new()
	_home_label.position = Vector2(28.0, 26.0)
	_home_label.size = Vector2(250.0, 80.0)
	_home_label.add_theme_font_size_override("font_size", 34)
	add_child(_home_label)

	_timer_label = Label.new()
	_timer_label.position = Vector2(388.0, 26.0)
	_timer_label.size = Vector2(300.0, 80.0)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 34)
	add_child(_timer_label)

	_away_label = Label.new()
	_away_label.position = Vector2(800.0, 26.0)
	_away_label.size = Vector2(250.0, 80.0)
	_away_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_away_label.add_theme_font_size_override("font_size", 34)
	add_child(_away_label)

	_pause_button = Button.new()
	_pause_button.position = Vector2(472.0, 78.0)
	_pause_button.size = Vector2(136.0, 36.0)
	_pause_button.text = "Pause"
	_pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	add_child(_pause_button)


func update_display(home_abbrev: String, home_score: int, away_abbrev: String, away_score: int, time_remaining: float) -> void:
	_home_label.text = "%s %d" % [home_abbrev, home_score]
	_away_label.text = "%s %d" % [away_abbrev, away_score]
	_timer_label.text = _format_clock(time_remaining)


func _format_clock(time_remaining: float) -> String:
	var total_seconds: int = maxi(int(ceil(time_remaining)), 0)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	return "%d:%02d" % [minutes, seconds]
