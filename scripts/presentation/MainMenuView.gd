@tool
extends Control
class_name MainMenuView

signal start_requested

@export var presentation_theme: PresentationTheme = preload("res://data/config/RetroPresentationTheme.tres")

@onready var start_button: Button = $Layout/CenterColumn/HeroCard/HeroContent/StartButton
@onready var hero_card: PanelContainer = $Layout/CenterColumn/HeroCard

func _ready() -> void:
	PresentationUi.apply(self, presentation_theme)
	hero_card.add_theme_stylebox_override("panel", PresentationUi.make_panel(presentation_theme.ui_surface, presentation_theme.line_color, 10, 28))
	start_button.pressed.connect(_on_start_pressed)
	start_button.grab_focus()

func _on_start_pressed() -> void:
	start_requested.emit()
	get_tree().change_scene_to_file("res://scenes/GameRoot.tscn")
