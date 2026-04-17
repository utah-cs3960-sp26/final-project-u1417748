class_name MainMenu
extends Control

@onready var start_button: Button = %StartButton
@onready var team_button: Button = %TeamButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	team_button.pressed.connect(_on_team_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/GameRoot.tscn")


func _on_team_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/TeamScreen.tscn")


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/SettingsScreen.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
