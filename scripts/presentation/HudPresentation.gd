@tool
extends Control
class_name HudPresentation

signal pause_pressed

@export var presentation_theme: PresentationTheme = preload("res://data/config/RetroPresentationTheme.tres")
@export var home_score: int = 12
@export var away_score: int = 11
@export var clock_text: String = "3:00"

@onready var home_chip: PanelContainer = $Banner/Margin/Content/HomeChip
@onready var away_chip: PanelContainer = $Banner/Margin/Content/AwayChip
@onready var home_score_label: Label = $Banner/Margin/Content/HomeChip/ChipContent/HomeScore
@onready var away_score_label: Label = $Banner/Margin/Content/AwayChip/ChipContent/AwayScore
@onready var clock_label: Label = $Banner/Margin/Content/CenterBlock/ClockLabel
@onready var pause_button: Button = $Banner/Margin/Content/CenterBlock/PauseButton

func _ready() -> void:
	PresentationUi.apply(self, presentation_theme)
	$Banner.add_theme_stylebox_override("panel", PresentationUi.make_panel(presentation_theme.ui_banner, presentation_theme.ui_banner, 0, 0))
	home_chip.add_theme_stylebox_override("panel", PresentationUi.make_panel(presentation_theme.home_secondary, presentation_theme.home_primary, 8, 18))
	away_chip.add_theme_stylebox_override("panel", PresentationUi.make_panel(presentation_theme.away_secondary, presentation_theme.away_primary, 8, 18))
	pause_button.add_theme_color_override("font_color", presentation_theme.outline_color)
	pause_button.add_theme_color_override("font_hover_color", presentation_theme.outline_color)
	pause_button.add_theme_color_override("font_pressed_color", presentation_theme.outline_color)
	pause_button.pressed.connect(_on_pause_pressed)
	_sync_labels()

func set_scores(new_home_score: int, new_away_score: int) -> void:
	home_score = new_home_score
	away_score = new_away_score
	_sync_labels()

func set_clock(new_clock_text: String) -> void:
	clock_text = new_clock_text
	_sync_labels()

func _sync_labels() -> void:
	if not is_node_ready():
		return
	home_score_label.text = str(home_score)
	away_score_label.text = str(away_score)
	clock_label.text = clock_text

func _on_pause_pressed() -> void:
	pause_pressed.emit()
