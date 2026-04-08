class_name GameOverOverlay
extends Control

signal restart_pressed()
signal quit_pressed()

var _result_label: Label


func _ready() -> void:
	anchors_preset = PRESET_FULL_RECT
	visible = false
	_build_ui()


func _build_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.anchors_preset = PRESET_FULL_RECT
	add_child(dim)

	var panel: Panel = Panel.new()
	panel.position = Vector2(220.0, 540.0)
	panel.size = Vector2(640.0, 620.0)
	add_child(panel)

	_result_label = Label.new()
	_result_label.position = Vector2(80.0, 80.0)
	_result_label.size = Vector2(480.0, 180.0)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 34)
	panel.add_child(_result_label)

	var restart_button: Button = Button.new()
	restart_button.position = Vector2(150.0, 340.0)
	restart_button.size = Vector2(340.0, 64.0)
	restart_button.text = "Restart Match"
	restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	panel.add_child(restart_button)

	var quit_button: Button = Button.new()
	quit_button.position = Vector2(150.0, 440.0)
	quit_button.size = Vector2(340.0, 64.0)
	quit_button.text = "Quit Game"
	quit_button.pressed.connect(func() -> void: quit_pressed.emit())
	panel.add_child(quit_button)


func show_result(home_score: int, away_score: int) -> void:
	var result_text: String = "TIED GAME"
	if home_score > away_score:
		result_text = "HOME WINS"
	elif away_score > home_score:
		result_text = "AWAY WINS"
	_result_label.text = "%s\nHOM %d  AWY %d" % [result_text, home_score, away_score]
