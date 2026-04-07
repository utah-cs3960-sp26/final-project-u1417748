class_name HUD
extends Control

signal pause_pressed

@onready var home_label: Label = $Banner/HomeLabel
@onready var center_label: Label = $Banner/CenterLabel
@onready var away_label: Label = $Banner/AwayLabel
@onready var pause_button: Button = $Banner/PauseButton

func _ready() -> void:
	pause_button.pressed.connect(_on_pause_pressed)

func set_score(home_abbr: String, home_score: int, away_abbr: String, away_score: int) -> void:
	home_label.text = "%s %d" % [home_abbr, home_score]
	away_label.text = "%s %d" % [away_abbr, away_score]

func set_clock(time_left: float) -> void:
	var total_seconds: int = maxi(0, int(ceil(time_left)))
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	center_label.text = "%d:%02d" % [minutes, seconds]

func _on_pause_pressed() -> void:
	emit_signal("pause_pressed")
