extends Control

const MENU_SCENE_PATH := "res://scenes/MainMenu.tscn"
const GameState := preload("res://scripts/game/GameState.gd")

@onready var scaffold_label: Label = $MarginContainer/VBoxContainer/BodyPanel/MarginContainer/VBoxContainer/ScaffoldLabel
@onready var back_button: Button = $MarginContainer/VBoxContainer/Footer/BackButton


func _ready() -> void:
	scaffold_label.text = "Current scaffold state: %s\nGameplay systems are intentionally deferred in this pass." % GameState.to_string(GameState.Value.MATCH_SETUP)
	back_button.pressed.connect(_on_back_button_pressed)


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE_PATH)
