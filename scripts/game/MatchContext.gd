class_name MatchContext
extends RefCounted

var current_state: int = GameState.State.BOOT
var previous_state: int = GameState.State.BOOT
var match_time_remaining: float = 180.0
var home_score: int = 0
var away_score: int = 0
var possession_count: int = 0
var gameplay_time_scale: float = 1.0
var deterministic_mode: bool = false
var difficulty_level: int = 1
var last_touch_offense: bool = true
var last_feedback_text: String = ""
var buzzer_waiting_for_resolution: bool = false
var active_route_package: int = 0
var ballhandler_stationary_time: float = 0.0
var shot_value_pending: int = 2
var current_seed: int = 0


func reset(match_length_seconds: float, seed: int = 0) -> void:
	current_state = GameState.State.MATCH_SETUP
	previous_state = GameState.State.BOOT
	match_time_remaining = match_length_seconds
	home_score = 0
	away_score = 0
	possession_count = 0
	gameplay_time_scale = 1.0
	last_touch_offense = true
	last_feedback_text = ""
	buzzer_waiting_for_resolution = false
	active_route_package = 0
	ballhandler_stationary_time = 0.0
	shot_value_pending = 2
	current_seed = seed
