class_name GameState
extends RefCounted

enum State {
	BOOT,
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


static func state_name(value: int) -> String:
	if value < 0 or value >= State.size():
		return "UNKNOWN"
	return State.keys()[value]


static func from_name(value: String) -> int:
	var normalized: String = value.strip_edges().to_upper()
	for index in State.size():
		if State.keys()[index] == normalized:
			return index
	return State.BOOT
