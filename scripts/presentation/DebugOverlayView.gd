@tool
extends Control
class_name DebugOverlayView

@export var presentation_theme: PresentationTheme = preload("res://data/config/RetroPresentationTheme.tres")

@onready var panel: PanelContainer = $Margin/Panel

func _ready() -> void:
	PresentationUi.apply(self, presentation_theme)
	panel.add_theme_stylebox_override("panel", PresentationUi.make_panel(Color(presentation_theme.ui_surface.r, presentation_theme.ui_surface.g, presentation_theme.ui_surface.b, 0.9), presentation_theme.ui_accent, 6, 18))
