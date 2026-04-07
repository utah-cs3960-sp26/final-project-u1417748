extends RefCounted
class_name LogWriter

var _config: TestHarnessConfig
var _legacy_prefix: String = "match"
var _legacy_match_log_name: String = ""
var _legacy_event_log_name: String = ""
var _legacy_sim_log_name: String = ""

func _init(config_or_prefix: Variant = null) -> void:
	if config_or_prefix is TestHarnessConfig:
		_config = config_or_prefix
	else:
		_config = TestHarnessConfig.new()
		if config_or_prefix is String and not String(config_or_prefix).is_empty():
			_legacy_prefix = String(config_or_prefix)
	ensure_log_directory()
	_configure_legacy_names()

func ensure_log_directory() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_config.logs_directory))

func resolve_log_path(filename: String) -> String:
	return _config.logs_directory.path_join(filename)

func write_line(filename: String, message: String) -> void:
	var path := resolve_log_path(filename)
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE_READ)
	if file == null:
		push_warning("Unable to open log file %s" % path)
		return
	file.seek_end()
	file.store_line(message)
	file.close()

func write_event(filename: String, event: Dictionary) -> void:
	var enriched_event := event.duplicate(true)
	enriched_event["timestamp_unix"] = Time.get_unix_time_from_system()
	write_line(filename, JSON.stringify(enriched_event))

func write_test_result(result: TestResult) -> void:
	write_event(_config.test_log_name, result.to_dictionary())

func write_assertion(assertion_name: String, passed: bool, details: Dictionary = {}) -> void:
	write_event(_config.event_log_name, {
		"type": "assertion",
		"assertion": assertion_name,
		"passed": passed,
		"details": details,
	})

func log_line(line: String) -> void:
	write_line(_legacy_match_log_name, line)

func log_event(event_type: String, payload: Dictionary) -> void:
	write_event(_legacy_event_log_name, {
		"type": event_type,
		"payload": payload,
	})

func log_sim_line(line: String) -> void:
	write_line(_legacy_sim_log_name, line)

func _configure_legacy_names() -> void:
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	_legacy_match_log_name = "%s_%s.log" % [_legacy_prefix, stamp]
	_legacy_event_log_name = "%s_%s.jsonl" % [_legacy_prefix, stamp]
	_legacy_sim_log_name = "%s_%s_sim.log" % [_legacy_prefix, stamp]
