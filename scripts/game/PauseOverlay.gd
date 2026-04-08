class_name PauseOverlay
extends Control

signal resume_pressed()
signal restart_pressed()
signal quit_pressed()


func _ready() -> void:
	anchors_preset = PRESET_FULL_RECT
	visible = false
	_build_ui()


func _build_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.anchors_preset = PRESET_FULL_RECT
	add_child(dim)

	var panel: Panel = Panel.new()
	panel.position = Vector2(250.0, 620.0)
	panel.size = Vector2(580.0, 520.0)
	add_child(panel)

	var title: Label = Label.new()
	title.position = Vector2(200.0, 60.0)
	title.size = Vector2(180.0, 44.0)
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 34)
	panel.add_child(title)

	var resume_button: Button = Button.new()
	resume_button.position = Vector2(120.0, 180.0)
	resume_button.size = Vector2(340.0, 64.0)
	resume_button.text = "Resume"
	resume_button.pressed.connect(func() -> void: resume_pressed.emit())
	panel.add_child(resume_button)

	var restart_button: Button = Button.new()
	restart_button.position = Vector2(120.0, 280.0)
	restart_button.size = Vector2(340.0, 64.0)
	restart_button.text = "Restart Match"
	restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	panel.add_child(restart_button)

	var quit_button: Button = Button.new()
	quit_button.position = Vector2(120.0, 380.0)
	quit_button.size = Vector2(340.0, 64.0)
	quit_button.text = "Quit Game"
	quit_button.pressed.connect(func() -> void: quit_pressed.emit())
	panel.add_child(quit_button)
