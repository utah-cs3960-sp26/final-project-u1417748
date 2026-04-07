class_name GameOverOverlay
extends Control

signal restart_requested
signal menu_requested

@onready var result_label: Label = $Panel/VBoxContainer/ResultLabel
@onready var score_label: Label = $Panel/VBoxContainer/ScoreLabel

func _ready() -> void:
	visible = false
	$Panel/VBoxContainer/RestartButton.pressed.connect(func() -> void: emit_signal("restart_requested"))
	$Panel/VBoxContainer/MenuButton.pressed.connect(func() -> void: emit_signal("menu_requested"))

func set_summary(result_text: String, score_text: String) -> void:
	result_label.text = result_text
	score_label.text = score_text
