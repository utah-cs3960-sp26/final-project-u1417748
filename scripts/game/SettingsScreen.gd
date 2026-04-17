extends Control

@onready var _panel: PanelContainer = $Center/SettingsPanel


func _ready() -> void:
	if _panel != null and _panel.has_signal("close_requested"):
		_panel.close_requested.connect(_on_close_requested)


func _on_close_requested() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
