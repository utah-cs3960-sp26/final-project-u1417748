@tool
extends Resource
class_name PresentationTheme

@export_group("Viewport")
@export var viewport_size: Vector2 = Vector2(1080.0, 1920.0)
@export var hud_height: float = 148.0
@export var sideline_margin: float = 56.0
@export var top_margin: float = 172.0
@export var lower_input_height: float = 436.0

@export_group("Court Palette")
@export var screen_bg_color: Color = Color8(15, 24, 39)
@export var court_wood_dark: Color = Color8(160, 88, 42)
@export var court_wood_light: Color = Color8(198, 120, 57)
@export var paint_fill: Color = Color8(96, 126, 156)
@export var line_color: Color = Color8(244, 226, 183)
@export var joystick_zone_color: Color = Color8(14, 21, 33, 120)
@export var shadow_color: Color = Color8(7, 10, 15, 112)

@export_group("Team Palette")
@export var home_primary: Color = Color8(94, 227, 237)
@export var home_secondary: Color = Color8(17, 76, 105)
@export var away_primary: Color = Color8(255, 131, 101)
@export var away_secondary: Color = Color8(111, 34, 48)
@export var neutral_fill: Color = Color8(245, 236, 206)
@export var skin_tone: Color = Color8(225, 173, 124)
@export var outline_color: Color = Color8(9, 12, 19)
@export var ball_primary: Color = Color8(220, 114, 46)
@export var ball_secondary: Color = Color8(105, 51, 18)
@export var rim_color: Color = Color8(201, 242, 90)
@export var backboard_fill: Color = Color8(245, 236, 206)
@export var backboard_trim: Color = Color8(44, 53, 73)

@export_group("UI Palette")
@export var ui_banner: Color = Color8(9, 12, 19)
@export var ui_surface: Color = Color8(24, 35, 52)
@export var ui_surface_alt: Color = Color8(34, 48, 71)
@export var ui_text: Color = Color8(245, 236, 206)
@export var ui_muted_text: Color = Color8(172, 182, 194)
@export var ui_accent: Color = Color8(201, 242, 90)
@export var ui_shadow: Color = Color8(9, 12, 19, 170)
@export var danger_accent: Color = Color8(235, 89, 89)

@export_group("Sizing")
@export var player_radius: float = 38.0
@export var player_shadow_size: Vector2 = Vector2(78.0, 20.0)
@export var ball_radius: float = 23.0
@export var rim_radius: float = 92.0

func get_court_rect() -> Rect2:
	var origin := Vector2(sideline_margin, top_margin)
	var size := Vector2(viewport_size.x - sideline_margin * 2.0, viewport_size.y - top_margin - 64.0)
	return Rect2(origin, size)

func get_key_rect() -> Rect2:
	var court_rect := get_court_rect()
	var width := minf(court_rect.size.x * 0.42, 430.0)
	var height := 356.0
	return Rect2(
		Vector2(court_rect.get_center().x - width * 0.5, court_rect.position.y + 74.0),
		Vector2(width, height)
	)

func get_hoop_anchor() -> Vector2:
	return Vector2(viewport_size.x * 0.5, top_margin + 112.0)

func get_team_primary(is_home: bool) -> Color:
	return home_primary if is_home else away_primary

func get_team_secondary(is_home: bool) -> Color:
	return home_secondary if is_home else away_secondary
