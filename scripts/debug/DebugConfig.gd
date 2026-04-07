extends Resource
class_name DebugConfig

@export var debug_overlay_enabled: bool = true
@export var overlay_enabled_by_default: bool = true
@export var deterministic_mode: bool = true
@export var deterministic_seed: int = 3960
@export var keyboard_debug_enabled: bool = true
@export var draw_route_guides: bool = true
@export var draw_defense_guides: bool = true
@export var show_game_state: bool = true
@export var show_route_geometry: bool = true
@export var show_defender_assignments: bool = true
@export var show_contest_radii: bool = true
@export var show_catch_radii: bool = true
@export var show_intercept_corridors: bool = true
@export var show_rebound_zone: bool = true
@export var show_shot_preview: bool = true
@export var show_rng_seed: bool = true
@export var toggle_keycode: Key = KEY_F3
@export_range(1.0, 60.0, 1.0) var refresh_rate_hz: float = 10.0

func enabled_sections() -> PackedStringArray:
	var sections := PackedStringArray()
	if show_game_state:
		sections.append("game_state")
	if show_route_geometry:
		sections.append("route_geometry")
	if show_defender_assignments:
		sections.append("defender_assignments")
	if show_contest_radii:
		sections.append("contest_radii")
	if show_catch_radii:
		sections.append("catch_radii")
	if show_intercept_corridors:
		sections.append("intercept_corridors")
	if show_rebound_zone:
		sections.append("rebound_zone")
	if show_shot_preview:
		sections.append("shot_preview")
	if show_rng_seed:
		sections.append("rng_seed")
	return sections
