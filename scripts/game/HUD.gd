class_name HUD
extends Control

const SCOREBOARD_TEXTURE_PATH: String = "res://assets/Decor/scoreboard.png"
const SCOREBOARD_ART_SIZE: Vector2 = Vector2(1098.0, 248.0)
const HOME_SCORE_ZONE: Rect2 = Rect2(45.0, 88.0, 321.0, 102.0)
const CLOCK_ZONE: Rect2 = Rect2(366.0, 44.0, 366.0, 76.0)
const AWAY_SCORE_ZONE: Rect2 = Rect2(732.0, 88.0, 326.0, 102.0)
const DISPLAY_TEXT_COLOR: Color = Color(0.96, 0.98, 0.88, 1.0)
const DISPLAY_OUTLINE_COLOR: Color = Color(0.04, 0.04, 0.05, 0.94)
const PAUSE_BUTTON_BASE_COLOR: Color = Color(0.11, 0.13, 0.18, 0.86)
const PAUSE_BUTTON_HOVER_COLOR: Color = Color(0.17, 0.2, 0.28, 0.92)
const PAUSE_BUTTON_PRESSED_COLOR: Color = Color(0.08, 0.1, 0.15, 0.96)

signal pause_pressed()

var _scoreboard: TextureRect
var _home_label: Label
var _timer_label: Label
var _pause_button: Button
var _pause_bar_left_outline: ColorRect
var _pause_bar_right_outline: ColorRect
var _pause_bar_left_fill: ColorRect
var _pause_bar_right_fill: ColorRect
var _away_label: Label


func _ready() -> void:
	anchors_preset = PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()


func _build_ui() -> void:
	_scoreboard = TextureRect.new()
	_scoreboard.texture = _load_scoreboard_texture()
	_scoreboard.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scoreboard.stretch_mode = TextureRect.STRETCH_SCALE
	_scoreboard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scoreboard)

	_home_label = _create_display_label()
	add_child(_home_label)

	_timer_label = _create_display_label()
	add_child(_timer_label)

	_pause_button = Button.new()
	_pause_button.text = ""
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_button.clip_contents = true
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	add_child(_pause_button)

	_pause_bar_left_outline = _create_pause_bar(DISPLAY_OUTLINE_COLOR)
	_pause_button.add_child(_pause_bar_left_outline)
	_pause_bar_right_outline = _create_pause_bar(DISPLAY_OUTLINE_COLOR)
	_pause_button.add_child(_pause_bar_right_outline)
	_pause_bar_left_fill = _create_pause_bar(DISPLAY_TEXT_COLOR)
	_pause_button.add_child(_pause_bar_left_fill)
	_pause_bar_right_fill = _create_pause_bar(DISPLAY_TEXT_COLOR)
	_pause_button.add_child(_pause_bar_right_fill)

	_away_label = _create_display_label()
	add_child(_away_label)


func apply_layout(layout_metrics: Dictionary) -> void:
	if _scoreboard == null:
		return
	var banner_rect: Rect2 = layout_metrics.get("banner_rect", Rect2(Vector2.ZERO, SCOREBOARD_ART_SIZE))
	var pause_rect: Rect2 = layout_metrics.get("pause_button_rect", Rect2())
	var home_score_rect: Rect2 = _map_zone_to_banner(HOME_SCORE_ZONE, banner_rect)
	var clock_rect: Rect2 = _map_zone_to_banner(CLOCK_ZONE, banner_rect)
	var away_score_rect: Rect2 = _map_zone_to_banner(AWAY_SCORE_ZONE, banner_rect)

	_scoreboard.position = banner_rect.position
	_scoreboard.size = banner_rect.size

	_apply_label_layout(_home_label, home_score_rect, int(clampi(int(roundf(home_score_rect.size.y * 0.72)), 42, 96)))
	_apply_label_layout(_timer_label, clock_rect, int(clampi(int(roundf(clock_rect.size.y * 0.72)), 34, 88)))
	_apply_label_layout(_away_label, away_score_rect, int(clampi(int(roundf(away_score_rect.size.y * 0.72)), 42, 96)))

	_pause_button.position = pause_rect.position
	_pause_button.size = pause_rect.size
	_pause_button.custom_minimum_size = pause_rect.size
	_pause_button.visible = pause_rect.size.x > 0.0 and pause_rect.size.y > 0.0
	_apply_pause_button_style(pause_rect.size)
	_apply_pause_icon_layout(pause_rect.size)


func update_display(_home_abbrev: String, home_score: int, _away_abbrev: String, away_score: int, time_remaining: float) -> void:
	_home_label.text = str(home_score)
	_away_label.text = str(away_score)
	_timer_label.text = _format_clock(time_remaining)


func get_layout_snapshot() -> Dictionary:
	var scoreboard_rect: Rect2 = _scoreboard.get_global_rect() if _scoreboard != null else Rect2()
	return {
		"banner_rect": scoreboard_rect,
		"scoreboard_rect": scoreboard_rect,
		"home_rect": _home_label.get_global_rect() if _home_label != null else Rect2(),
		"timer_rect": _timer_label.get_global_rect() if _timer_label != null else Rect2(),
		"pause_rect": _pause_button.get_global_rect() if _pause_button != null else Rect2(),
		"away_rect": _away_label.get_global_rect() if _away_label != null else Rect2(),
	}


func get_scoreboard_texture_size() -> Vector2:
	if _scoreboard == null or _scoreboard.texture == null:
		return Vector2.ZERO
	return _scoreboard.texture.get_size()


func _format_clock(time_remaining: float) -> String:
	var total_seconds: int = maxi(int(ceil(time_remaining)), 0)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	return "%d:%02d" % [minutes, seconds]


func _create_display_label() -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", DISPLAY_TEXT_COLOR)
	label.add_theme_color_override("font_outline_color", DISPLAY_OUTLINE_COLOR)
	return label


func _create_pause_bar(bar_color: Color) -> ColorRect:
	var bar: ColorRect = ColorRect.new()
	bar.color = bar_color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _apply_label_layout(label: Label, rect: Rect2, font_size: int) -> void:
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", max(2, int(roundf(font_size * 0.08))))


func _apply_pause_button_style(button_size: Vector2) -> void:
	if _pause_button == null:
		return
	var corner_radius: int = int(roundf(minf(button_size.x, button_size.y) * 0.18))
	var border_width: int = max(2, int(roundf(minf(button_size.x, button_size.y) * 0.045)))
	_pause_button.add_theme_stylebox_override("normal", _build_pause_stylebox(PAUSE_BUTTON_BASE_COLOR, corner_radius, border_width))
	_pause_button.add_theme_stylebox_override("hover", _build_pause_stylebox(PAUSE_BUTTON_HOVER_COLOR, corner_radius, border_width))
	_pause_button.add_theme_stylebox_override("pressed", _build_pause_stylebox(PAUSE_BUTTON_PRESSED_COLOR, corner_radius, border_width))
	_pause_button.add_theme_stylebox_override("focus", _build_pause_stylebox(PAUSE_BUTTON_HOVER_COLOR, corner_radius, border_width))


func _build_pause_stylebox(fill_color: Color, corner_radius: int, border_width: int) -> StyleBoxFlat:
	var stylebox: StyleBoxFlat = StyleBoxFlat.new()
	stylebox.bg_color = fill_color
	stylebox.border_color = DISPLAY_OUTLINE_COLOR
	stylebox.border_width_left = border_width
	stylebox.border_width_top = border_width
	stylebox.border_width_right = border_width
	stylebox.border_width_bottom = border_width
	stylebox.corner_radius_top_left = corner_radius
	stylebox.corner_radius_top_right = corner_radius
	stylebox.corner_radius_bottom_right = corner_radius
	stylebox.corner_radius_bottom_left = corner_radius
	stylebox.anti_aliasing = true
	return stylebox


func _apply_pause_icon_layout(button_size: Vector2) -> void:
	if _pause_button == null:
		return
	var fill_height: float = maxf(button_size.y * 0.44, 8.0)
	var fill_width: float = maxf(button_size.x * 0.12, 4.0)
	var fill_gap: float = maxf(button_size.x * 0.14, 5.0)
	var total_width: float = fill_width * 2.0 + fill_gap
	var start_x: float = (button_size.x - total_width) * 0.5
	var start_y: float = (button_size.y - fill_height) * 0.5
	var outline_padding: float = maxf(button_size.x * 0.028, 1.0)
	var left_fill_rect: Rect2 = Rect2(Vector2(start_x, start_y), Vector2(fill_width, fill_height))
	var right_fill_rect: Rect2 = Rect2(Vector2(start_x + fill_width + fill_gap, start_y), Vector2(fill_width, fill_height))
	_apply_pause_bar_rect(_pause_bar_left_outline, left_fill_rect.grow(outline_padding))
	_apply_pause_bar_rect(_pause_bar_right_outline, right_fill_rect.grow(outline_padding))
	_apply_pause_bar_rect(_pause_bar_left_fill, left_fill_rect)
	_apply_pause_bar_rect(_pause_bar_right_fill, right_fill_rect)


func _apply_pause_bar_rect(bar: ColorRect, rect: Rect2) -> void:
	if bar == null:
		return
	bar.position = rect.position
	bar.size = rect.size


func _map_zone_to_banner(zone: Rect2, banner_rect: Rect2) -> Rect2:
	var scale_x: float = banner_rect.size.x / SCOREBOARD_ART_SIZE.x
	var scale_y: float = banner_rect.size.y / SCOREBOARD_ART_SIZE.y
	return Rect2(
		banner_rect.position + Vector2(zone.position.x * scale_x, zone.position.y * scale_y),
		Vector2(zone.size.x * scale_x, zone.size.y * scale_y)
	)


func _load_scoreboard_texture() -> Texture2D:
	var imported_texture: Resource = ResourceLoader.load(SCOREBOARD_TEXTURE_PATH, "Texture2D")
	if imported_texture is Texture2D:
		return imported_texture as Texture2D
	var scoreboard_image: Image = Image.new()
	var load_error: Error = scoreboard_image.load(SCOREBOARD_TEXTURE_PATH)
	if load_error != OK:
		push_warning("Failed to load scoreboard image: %s (%s)" % [SCOREBOARD_TEXTURE_PATH, error_string(load_error)])
		return null
	return ImageTexture.create_from_image(scoreboard_image)
