class_name GameState
extends RefCounted

enum Value {
	BOOT,
	MAIN_MENU,
	MATCH_SETUP,
	LIVE_OFFENSE,
	PASS_IN_FLIGHT,
	SHOT_AIM,
	SHOT_IN_FLIGHT,
	REBOUND_LIVE,
	OPPONENT_SIM,
	PAUSED,
	GAME_OVER,
}

static func label_for(state: int) -> String:
	match state:
		Value.BOOT:
			return "BOOT"
		Value.MAIN_MENU:
			return "MAIN_MENU"
		Value.MATCH_SETUP:
			return "MATCH_SETUP"
		Value.LIVE_OFFENSE:
			return "LIVE_OFFENSE"
		Value.PASS_IN_FLIGHT:
			return "PASS_IN_FLIGHT"
		Value.SHOT_AIM:
			return "SHOT_AIM"
		Value.SHOT_IN_FLIGHT:
			return "SHOT_IN_FLIGHT"
		Value.REBOUND_LIVE:
			return "REBOUND_LIVE"
		Value.OPPONENT_SIM:
			return "OPPONENT_SIM"
		Value.PAUSED:
			return "PAUSED"
		Value.GAME_OVER:
			return "GAME_OVER"
		_:
			return "UNKNOWN"
