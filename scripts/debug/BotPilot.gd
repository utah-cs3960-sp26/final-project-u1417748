extends RefCounted
class_name BotPilot

var _log_writer: LogWriter
var _action_history: Array[Dictionary] = []

func _init(log_writer: LogWriter) -> void:
	_log_writer = log_writer

func apply_action(context: Object, action: ScenarioAction) -> Dictionary:
	var result := {
		"description": action.describe(),
		"status": "recorded",
		"payload": action.payload,
	}
	if context != null and context.has_method(DebugContract.METHOD_APPLY_BOT_ACTION):
		var hook_result := context.call(DebugContract.METHOD_APPLY_BOT_ACTION, action)
		result["status"] = "applied"
		result["hook_result"] = hook_result
	_action_history.append(result)
	_log_writer.write_event("replay_frames.ndjson", {
		"type": "bot_action",
		"action": action.describe(),
		"result": result,
	})
	return result

func get_action_history() -> Array[Dictionary]:
	return _action_history.duplicate(true)
