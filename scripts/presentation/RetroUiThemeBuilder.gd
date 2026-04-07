extends RefCounted
class_name RetroUiThemeBuilder

static func build(theme_data: PresentationTheme) -> Theme:
	var theme := Theme.new()
	var panel_style := _panel_style(theme_data.ui_surface, theme_data.line_color, 10, 22)
	var panel_alt_style := _panel_style(theme_data.ui_surface_alt, theme_data.line_color, 10, 22)
	var button_normal := _panel_style(theme_data.ui_surface_alt, theme_data.line_color, 8, 18)
	var button_hover := _panel_style(theme_data.ui_accent, theme_data.outline_color, 8, 18)
	var button_pressed := _panel_style(theme_data.home_primary, theme_data.outline_color, 8, 18)
	var button_disabled := _panel_style(theme_data.ui_surface.darkened(0.2), theme_data.ui_muted_text, 8, 18)
	var banner_style := _panel_style(theme_data.ui_banner, theme_data.ui_banner, 0, 0)

	theme.set_stylebox("panel", "Panel", panel_style)
	theme.set_stylebox("panel", "PanelContainer", panel_style)
	theme.set_stylebox("normal", "Button", button_normal)
	theme.set_stylebox("hover", "Button", button_hover)
	theme.set_stylebox("pressed", "Button", button_pressed)
	theme.set_stylebox("focus", "Button", button_hover)
	theme.set_stylebox("disabled", "Button", button_disabled)
	theme.set_stylebox("normal", "TextureButton", button_normal)
	theme.set_stylebox("hover", "TextureButton", button_hover)
	theme.set_stylebox("pressed", "TextureButton", button_pressed)
	theme.set_stylebox("disabled", "TextureButton", button_disabled)
	theme.set_stylebox("panel", "BannerPanel", banner_style)

	theme.set_color("font_color", "Label", theme_data.ui_text)
	theme.set_color("font_outline_color", "Label", theme_data.ui_shadow)
	theme.set_constant("outline_size", "Label", 2)
	theme.set_font_size("font_size", "Label", 30)

	theme.set_color("default_color", "RichTextLabel", theme_data.ui_text)
	theme.set_font_size("normal_font_size", "RichTextLabel", 28)

	theme.set_color("font_color", "Button", theme_data.ui_text)
	theme.set_color("font_hover_color", "Button", theme_data.outline_color)
	theme.set_color("font_pressed_color", "Button", theme_data.outline_color)
	theme.set_color("font_disabled_color", "Button", theme_data.ui_muted_text)
	theme.set_color("font_outline_color", "Button", theme_data.ui_shadow)
	theme.set_constant("outline_size", "Button", 2)
	theme.set_font_size("font_size", "Button", 34)
	theme.set_constant("h_separation", "HBoxContainer", 18)
	theme.set_constant("v_separation", "VBoxContainer", 18)
	return theme

static func panel_style(fill_color: Color, border_color: Color, border_width: int = 8, radius: int = 18) -> StyleBoxFlat:
	return _panel_style(fill_color, border_color, border_width, radius)

static func _panel_style(fill_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.28)
	style.shadow_size = 6
	style.content_margin_left = 18.0
	style.content_margin_top = 14.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 14.0
	return style
