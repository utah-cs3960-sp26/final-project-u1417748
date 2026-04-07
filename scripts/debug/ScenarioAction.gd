extends Resource
class_name ScenarioAction

enum ActionType {
	WAIT,
	JOYSTICK,
	TAP_TEAMMATE,
	HOLD_SHOT,
	RELEASE_SHOT,
	PAUSE,
	RESUME,
	CUSTOM,
}

@export var action_type: ActionType = ActionType.WAIT
@export var actor_id: String = "ballhandler"
@export var vector: Vector2 = Vector2.ZERO
@export_range(0.0, 10.0, 0.01) var duration_seconds: float = 0.0
@export var payload: Dictionary = {}

func describe() -> String:
	return "%s actor=%s vector=%s duration=%.2f payload=%s" % [
		ActionType.keys()[action_type],
		actor_id,
		vector,
		duration_seconds,
		payload,
	]
