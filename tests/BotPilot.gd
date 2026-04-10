class_name BotPilot
extends RefCounted

var action_queue: Array[Dictionary] = []
var action_index: int = 0
var action_elapsed: float = 0.0
var coordinator: GameCoordinator
var input_controller: InputController
var failures: PackedStringArray = PackedStringArray()


func move_thumb(direction: Vector2, duration: float) -> void:
	action_queue.append({"kind": "move_thumb", "direction": direction, "duration": duration})


func move_joystick(direction: Vector2, duration: float) -> void:
	move_thumb(direction, duration)


func flick_pass(player_id: String) -> void:
	action_queue.append({"kind": "flick_pass", "player_id": player_id})


func tap_player(player_id: String) -> void:
	flick_pass(player_id)


func arm_shot() -> void:
	action_queue.append({"kind": "arm_shot"})


func hold_drag_from_ballhandler(_offset: Vector2, _duration: float) -> void:
	arm_shot()


func set_meter_quality(quality: String) -> void:
	action_queue.append({"kind": "set_meter_quality", "quality": quality})


func hold_until_meter_quality(quality: String, _timeout: float = 2.0) -> void:
	action_queue.append({"kind": "hold_until_meter_quality", "quality": quality})


func tap_meter() -> void:
	action_queue.append({"kind": "tap_meter"})


func release_action() -> void:
	tap_meter()


func wait(seconds: float) -> void:
	action_queue.append({"kind": "wait", "seconds": seconds})


func pause_toggle() -> void:
	action_queue.append({"kind": "pause_toggle"})


func force_scoring_shot(role: String = "", shot_value: int = 0) -> void:
	action_queue.append({"kind": "force_scoring_shot", "role": role, "shot_value": shot_value})


func force_rebound(zone: Vector2) -> void:
	action_queue.append({"kind": "force_rebound", "zone": zone})


func force_defensive_rebound(role: String = "") -> void:
	action_queue.append({"kind": "force_defensive_rebound", "role": role})


func force_pass_interception() -> void:
	action_queue.append({"kind": "force_pass_interception"})


func force_pressure_turnover() -> void:
	action_queue.append({"kind": "force_pressure_turnover"})


func force_offensive_rebound(role: String) -> void:
	action_queue.append({"kind": "force_offensive_rebound", "role": role})


func assert_state(expected_state: String) -> void:
	action_queue.append({"kind": "assert_state", "expected_state": expected_state})


func assert_score(home: int, away: int) -> void:
	action_queue.append({"kind": "assert_score", "home": home, "away": away})


func assert_controlled_player(player_id: String) -> void:
	action_queue.append({"kind": "assert_controlled_player", "player_id": player_id})


func assert_last_log_contains(text: String) -> void:
	action_queue.append({"kind": "assert_last_log_contains", "text": text})


func setup(game_coordinator: GameCoordinator) -> void:
	coordinator = game_coordinator
	input_controller = coordinator.input_controller


func reset() -> void:
	action_index = 0
	action_elapsed = 0.0
	failures.clear()


func get_failures() -> PackedStringArray:
	return failures


func step(delta: float) -> bool:
	if action_index >= action_queue.size():
		return true
	var action: Dictionary = action_queue[action_index]
	action_elapsed += delta
	match action["kind"]:
		"move_thumb":
			var direction: Vector2 = action["direction"]
			input_controller.movement_updated.emit(direction.normalized(), clampf(direction.length(), 0.0, 1.0))
			if action_elapsed >= action["duration"]:
				input_controller.movement_updated.emit(Vector2.ZERO, 0.0)
				_advance()
		"flick_pass":
			_execute_flick_pass(str(action.get("player_id", "")))
			_advance()
		"arm_shot":
			_execute_arm_shot()
			_advance()
		"set_meter_quality", "hold_until_meter_quality":
			_set_meter_quality(str(action.get("quality", "")))
			_advance()
		"tap_meter":
			input_controller.tap_test_shot_timing(_get_lower_zone_anchor())
			_advance()
		"wait":
			if action_elapsed >= action["seconds"]:
				_advance()
		"pause_toggle":
			coordinator.test_toggle_pause()
			_advance()
		"force_scoring_shot":
			coordinator.test_force_scoring_shot(str(action.get("role", "")), int(action.get("shot_value", 0)))
			_advance()
		"force_rebound":
			coordinator.test_force_rebound_state(action["zone"])
			_advance()
		"force_defensive_rebound":
			coordinator.test_force_defensive_rebound(str(action.get("role", "")))
			_advance()
		"force_pass_interception":
			coordinator.test_force_pass_interception()
			_advance()
		"force_pressure_turnover":
			coordinator.test_force_pressure_turnover()
			_advance()
		"force_offensive_rebound":
			coordinator.test_force_offensive_rebound(str(action.get("role", "")))
			_advance()
		"assert_state":
			if coordinator.get_state_name() != str(action.get("expected_state", "")):
				failures.append("state expected %s got %s" % [str(action.get("expected_state", "")), coordinator.get_state_name()])
			_advance()
		"assert_score":
			if coordinator.context.home_score != int(action.get("home", 0)) or coordinator.context.away_score != int(action.get("away", 0)):
				failures.append("score expected %d-%d got %d-%d" % [int(action.get("home", 0)), int(action.get("away", 0)), coordinator.context.home_score, coordinator.context.away_score])
			_advance()
		"assert_controlled_player":
			if coordinator.get_controlled_role() != str(action.get("player_id", "")):
				failures.append("controlled role expected %s got %s" % [str(action.get("player_id", "")), coordinator.get_controlled_role()])
			_advance()
		"assert_last_log_contains":
			if not coordinator.match_log_contains(str(action.get("text", ""))):
				failures.append("match log missing %s" % str(action.get("text", "")))
			_advance()
		_:
			_advance()
	return action_index >= action_queue.size()


func _advance() -> void:
	action_index += 1
	action_elapsed = 0.0


func _execute_flick_pass(player_id: String) -> void:
	var target: PlayerController = coordinator.get_offense_player_by_role(player_id)
	var ballhandler: PlayerController = coordinator.current_ballhandler
	if target == null or ballhandler == null:
		return
	var anchor: Vector2 = _get_lower_zone_anchor()
	var screen_vector: Vector2 = target.get_screen_anchor() - ballhandler.get_screen_anchor()
	if screen_vector.length_squared() <= 0.001:
		screen_vector = Vector2(0.0, -1.0)
	var flick_distance: float = maxf(float(coordinator.input_config.flick_min_distance) + 48.0, 160.0)
	var release_screen: Vector2 = anchor + screen_vector.normalized() * flick_distance
	input_controller.begin_test_live_gesture(anchor)
	input_controller.update_test_live_gesture(release_screen)
	input_controller.end_test_live_gesture(release_screen)


func _execute_arm_shot() -> void:
	var anchor: Vector2 = _get_lower_zone_anchor()
	input_controller.begin_test_live_gesture(anchor)
	input_controller.end_test_live_gesture(anchor)


func _get_lower_zone_anchor() -> Vector2:
	var viewport_size: Vector2 = coordinator.get_viewport().get_visible_rect().size
	return Vector2(viewport_size.x * 0.5, viewport_size.y * 0.88)


func _set_meter_quality(quality: String) -> void:
	var shot_controller: ShotController = coordinator.shot_controller
	if shot_controller == null or shot_controller.shot_config == null:
		return
	var target_progress: float = 0.08
	if quality == "green":
		var green_window: Vector2 = shot_controller.get_green_window(false, 0)
		target_progress = (green_window.x + green_window.y) * 0.5
	elif quality == "yellow":
		var yellow_window: Vector2 = shot_controller.get_yellow_window(false, 0)
		target_progress = (yellow_window.x + yellow_window.y) * 0.5
	shot_controller.aim_elapsed = shot_controller.get_decision_duration_seconds() * target_progress
