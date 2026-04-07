@tool
extends Control
class_name GameOverOverlayPresentation

signal restart_requested
signal menu_requested

@export var presentation_theme: PresentationTheme = preload("res://data/config/RetroPresentationTheme.tres")
@export var summary_text: String = "HOM 21 - 19 AWY"

@onready var card: PanelContainer = $Backdrop/CenterCard/CardPanel
@onready var summary_label: Label = $Backdrop/CenterCard/CardPanel/CardContent/SummaryLabel
@onready var restart_button: Button = $Backdrop/CenterCard/CardPanel/CardContent/RestartButton
@onready var menu_button: Button = $Backdrop/CenterCard/CardPanel/CardContent/MenuButton

func _ready() -> void:
	PresentationUi.apply(self, presentation_theme)
	card.add_theme_stylebox_override("panel", PresentationUi.make_panel(presentation_theme.ui_surface, presentation_theme.away_primary, 10, 28))
	visible = false
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	_sync_summary()

func set_summary(new_summary_text: String) -> void:
	summary_text = new_summary_text
	_sync_summary()

func _sync_summary() -> void:
	if not is_node_ready():
		return
	summary_label.text = summary_text
