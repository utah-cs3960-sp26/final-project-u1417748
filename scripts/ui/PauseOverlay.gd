class_name PauseOverlay
extends Control

signal resume_requested
signal restart_requested
signal menu_requested

func _ready() -> void:
	visible = false
	$Panel/VBoxContainer/ResumeButton.pressed.connect(func() -> void: emit_signal("resume_requested"))
	$Panel/VBoxContainer/RestartButton.pressed.connect(func() -> void: emit_signal("restart_requested"))
	$Panel/VBoxContainer/MenuButton.pressed.connect(func() -> void: emit_signal("menu_requested"))
