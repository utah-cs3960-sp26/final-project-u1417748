@tool
extends Control
class_name PauseOverlayPresentation

signal resume_requested
signal restart_requested
signal menu_requested

@export var presentation_theme: PresentationTheme = preload("res://data/config/RetroPresentationTheme.tres")

@onready var card: PanelContainer = $Backdrop/CenterCard/CardPanel
@onready var resume_button: Button = $Backdrop/CenterCard/CardPanel/CardContent/ResumeButton
@onready var restart_button: Button = $Backdrop/CenterCard/CardPanel/CardContent/RestartButton
@onready var menu_button: Button = $Backdrop/CenterCard/CardPanel/CardContent/MenuButton

func _ready() -> void:
	PresentationUi.apply(self, presentation_theme)
	card.add_theme_stylebox_override("panel", PresentationUi.make_panel(presentation_theme.ui_surface, presentation_theme.ui_accent, 10, 28))
	visible = false
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
