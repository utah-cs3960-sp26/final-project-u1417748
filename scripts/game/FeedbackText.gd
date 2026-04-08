class_name FeedbackText
extends Control

var _label: Label
var _timer: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchors_preset = PRESET_FULL_RECT
	_label = Label.new()
	_label.position = Vector2(0.0, 200.0)
	_label.size = Vector2(1080.0, 120.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 42)
	add_child(_label)
	visible = false


func _process(delta: float) -> void:
	if _timer <= 0.0:
		return
	_timer -= delta
	if _timer <= 0.0:
		visible = false


func show_feedback(text_value: String, color_value: Color = Color(1.0, 0.95, 0.4), duration: float = 1.0) -> void:
	_label.text = text_value
	_label.add_theme_color_override("font_color", color_value)
	_timer = duration
	visible = true
