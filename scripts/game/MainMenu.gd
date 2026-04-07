class_name MainMenu
extends Control

@onready var start_button: Button = $CenterPanel/VBoxContainer/StartButton
@onready var diagnostics_button: Button = $CenterPanel/VBoxContainer/DiagnosticsButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	diagnostics_button.pressed.connect(_on_diagnostics_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/GameRoot.tscn")

func _on_diagnostics_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/debug/TestRunner.tscn")
