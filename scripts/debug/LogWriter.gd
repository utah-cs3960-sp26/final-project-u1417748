class_name LogWriter
extends RefCounted

var session_prefix: String = "session"
var log_dir: String = "user://logs"
var match_lines: PackedStringArray = PackedStringArray()


func _init(prefix: String = "session") -> void:
	session_prefix = prefix
	_ensure_log_dir()


func _ensure_log_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(log_dir))


func set_prefix(prefix: String) -> void:
	session_prefix = prefix
	_ensure_log_dir()


func log_match(line: String) -> void:
	match_lines.append(line)
	_append_text("%s_match.log" % session_prefix, line)


func log_event(event_name: String, payload: Dictionary = {}) -> void:
	var data: Dictionary = {
		"event": event_name,
		"payload": payload,
	}
	_append_text("%s_event.jsonl" % session_prefix, JSON.stringify(data))


func log_scenario(line: String) -> void:
	_append_text("%s_scenario.log" % session_prefix, line)


func log_sim(line: String) -> void:
	_append_text("%s_sim.log" % session_prefix, line)


func log_test(line: String) -> void:
	_append_text("%s_test.log" % session_prefix, line)


func clear_runtime_logs() -> void:
	match_lines.clear()


func _append_text(file_name: String, line: String) -> void:
	_ensure_log_dir()
	var path: String = "%s/%s" % [log_dir, file_name]
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to open log file: %s" % path)
		return
	file.seek_end()
	file.store_line(line)
	file.close()
