class_name CoinsBadge
extends PanelContainer

var _coins: int = 0
var _title_label: Label
var _value_label: Label


func _ready() -> void:
	_ensure_ui()
	_sync_text()


func set_coins(value: int) -> void:
	_coins = max(value, 0)
	_ensure_ui()
	_sync_text()


func get_value_text() -> String:
	return str(_coins)


func get_snapshot() -> Dictionary:
	return {
		"coins": _coins,
		"text": get_value_text(),
	}


func _ensure_ui() -> void:
	if _value_label != null:
		return
	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	style_box.bg_color = Color(0.08, 0.1, 0.16, 0.92)
	style_box.border_width_left = 4
	style_box.border_width_top = 4
	style_box.border_width_right = 4
	style_box.border_width_bottom = 4
	style_box.border_color = Color(1.0, 0.82, 0.32, 0.95)
	style_box.corner_radius_top_left = 24
	style_box.corner_radius_top_right = 24
	style_box.corner_radius_bottom_right = 24
	style_box.corner_radius_bottom_left = 24
	add_theme_stylebox_override("panel", style_box)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	_title_label = Label.new()
	_title_label.text = "COINS"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	hbox.add_child(_title_label)

	_value_label = Label.new()
	_value_label.add_theme_font_size_override("font_size", 34)
	_value_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.98))
	hbox.add_child(_value_label)


func _sync_text() -> void:
	if _value_label == null:
		return
	_value_label.text = str(_coins)
