extends Control

const MENU_BACKGROUND_SCRIPT: GDScript = preload("res://scripts/game/MenuBackground.gd")

@onready var _court_background: TextureRect = $CourtBackground
@onready var _panel: PanelContainer = $Center/SettingsPanel


func _ready() -> void:
	MENU_BACKGROUND_SCRIPT.apply_to(_court_background)
	if _panel != null and _panel.has_signal("close_requested"):
		_panel.close_requested.connect(_on_close_requested)


func _on_close_requested() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
