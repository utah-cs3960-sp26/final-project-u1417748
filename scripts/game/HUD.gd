class_name HUD
extends Control

signal pause_pressed()

var _banner: ColorRect
var _padding: MarginContainer
var _row: HBoxContainer
var _home_holder: Control
var _home_label: Label
var _center_box: VBoxContainer
var _timer_label: Label
var _pause_button: Button
var _away_holder: Control
var _away_label: Label


func _ready() -> void:
	anchors_preset = PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()


func _build_ui() -> void:
	_banner = ColorRect.new()
	_banner.color = Color(0.02, 0.02, 0.03, 0.96)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)

	_padding = MarginContainer.new()
	_padding.anchors_preset = PRESET_FULL_RECT
	_padding.anchor_right = 1.0
	_padding.anchor_bottom = 1.0
	_padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(_padding)

	_row = HBoxContainer.new()
	_row.anchors_preset = PRESET_FULL_RECT
	_row.anchor_right = 1.0
	_row.anchor_bottom = 1.0
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_padding.add_child(_row)

	_home_holder = Control.new()
	_home_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_home_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_home_holder)

	_home_label = Label.new()
	_home_label.anchors_preset = PRESET_FULL_RECT
	_home_label.anchor_right = 1.0
	_home_label.anchor_bottom = 1.0
	_home_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_home_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_home_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home_holder.add_child(_home_label)

	_center_box = VBoxContainer.new()
	_center_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_center_box)

	_timer_label = Label.new()
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_box.add_child(_timer_label)

	_pause_button = Button.new()
	_pause_button.text = "Pause"
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	_center_box.add_child(_pause_button)

	_away_holder = Control.new()
	_away_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_away_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_away_holder)

	_away_label = Label.new()
	_away_label.anchors_preset = PRESET_FULL_RECT
	_away_label.anchor_right = 1.0
	_away_label.anchor_bottom = 1.0
	_away_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_away_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_away_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_away_holder.add_child(_away_label)


func apply_layout(layout_metrics: Dictionary) -> void:
	if _banner == null:
		return
	var banner_rect: Rect2 = layout_metrics.get("banner_rect", Rect2(0.0, 0.0, 1080.0, 128.0))
	var ui_scale: float = float(layout_metrics.get("ui_scale", 1.0))
	_banner.position = banner_rect.position
	_banner.size = banner_rect.size

	var padding_horizontal: int = int(round(maxf(18.0 * ui_scale, 14.0)))
	var padding_vertical: int = int(round(maxf(12.0 * ui_scale, 10.0)))
	_padding.add_theme_constant_override("margin_left", padding_horizontal)
	_padding.add_theme_constant_override("margin_top", padding_vertical)
	_padding.add_theme_constant_override("margin_right", padding_horizontal)
	_padding.add_theme_constant_override("margin_bottom", padding_vertical)
	_row.add_theme_constant_override("separation", int(round(maxf(14.0 * ui_scale, 10.0))))
	_center_box.add_theme_constant_override("separation", int(round(maxf(6.0 * ui_scale, 4.0))))

	var score_font_size: int = int(round(clampf(34.0 * ui_scale, 28.0, 34.0)))
	var timer_font_size: int = int(round(clampf(34.0 * ui_scale, 28.0, 34.0)))
	var pause_font_size: int = int(round(clampf(18.0 * ui_scale, 14.0, 18.0)))
	var pause_height: float = clampf(36.0 * ui_scale, 32.0, 36.0)
	var pause_width: float = clampf(148.0 * ui_scale, 120.0, 148.0)
	var center_min_width: float = clampf(228.0 * ui_scale, 188.0, 228.0)
	var score_min_width: float = clampf(230.0 * ui_scale, 176.0, 230.0)

	_home_holder.custom_minimum_size = Vector2(score_min_width, 0.0)
	_away_holder.custom_minimum_size = Vector2(score_min_width, 0.0)
	_center_box.custom_minimum_size = Vector2(center_min_width, 0.0)
	_home_label.add_theme_font_size_override("font_size", score_font_size)
	_timer_label.add_theme_font_size_override("font_size", timer_font_size)
	_away_label.add_theme_font_size_override("font_size", score_font_size)
	_pause_button.add_theme_font_size_override("font_size", pause_font_size)
	_pause_button.custom_minimum_size = Vector2(pause_width, pause_height)
	_timer_label.custom_minimum_size = Vector2(center_min_width, 0.0)


func update_display(home_abbrev: String, home_score: int, away_abbrev: String, away_score: int, time_remaining: float) -> void:
	_home_label.text = "%s %d" % [home_abbrev, home_score]
	_away_label.text = "%s %d" % [away_abbrev, away_score]
	_timer_label.text = _format_clock(time_remaining)


func get_layout_snapshot() -> Dictionary:
	return {
		"banner_rect": _banner.get_global_rect() if _banner != null else Rect2(),
		"home_rect": _home_label.get_global_rect() if _home_label != null else Rect2(),
		"timer_rect": _timer_label.get_global_rect() if _timer_label != null else Rect2(),
		"pause_rect": _pause_button.get_global_rect() if _pause_button != null else Rect2(),
		"away_rect": _away_label.get_global_rect() if _away_label != null else Rect2(),
	}


func _format_clock(time_remaining: float) -> String:
	var total_seconds: int = maxi(int(ceil(time_remaining)), 0)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	return "%d:%02d" % [minutes, seconds]
