extends RefCounted
class_name PresentationUi

static func apply(target: Control, theme_data: PresentationTheme) -> void:
	target.theme = RetroUiThemeBuilder.build(theme_data)

static func make_panel(fill_color: Color, border_color: Color, border_width: int = 8, radius: int = 18) -> StyleBoxFlat:
	return RetroUiThemeBuilder.panel_style(fill_color, border_color, border_width, radius)
