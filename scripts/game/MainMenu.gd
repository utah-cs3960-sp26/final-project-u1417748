class_name MainMenu
extends Control

const MENU_BACKGROUND_SCRIPT: GDScript = preload("res://scripts/game/MenuBackground.gd")

@onready var start_button: Button = %StartButton
@onready var team_button: Button = %TeamButton
@onready var settings_button: Button = %SettingsButton
@onready var court_background: TextureRect = $CourtBackground


func _ready() -> void:
	MENU_BACKGROUND_SCRIPT.apply_to(court_background)
	start_button.pressed.connect(_on_start_pressed)
	team_button.pressed.connect(_on_team_pressed)
	settings_button.pressed.connect(_on_settings_pressed)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/GameRoot.tscn")


func _on_team_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/TeamScreen.tscn")


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/SettingsScreen.tscn")
