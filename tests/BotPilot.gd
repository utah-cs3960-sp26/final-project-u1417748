class_name BotPilot
extends RefCounted

var action_queue: Array[Dictionary] = []
var action_index: int = 0
var action_elapsed: float = 0.0
var coordinator: GameCoordinator
var input_controller: InputController
var active_drag_release_position: Vector2 = Vector2.ZERO
var failures: PackedStringArray = PackedStringArray()


func move_joystick(direction: Vector2, duration: float) -> void:
	action_queue.append({"kind": "move_joystick", "direction": direction, "duration": duration})


func tap_player(player_id: String) -> void:
	action_queue.append({"kind": "tap_player", "player_id": player_id})


func hold_drag_from_ballhandler(offset: Vector2, duration: float) -> void:
	action_queue.append({"kind": "hold_drag_from_ballhandler", "offset": offset, "duration": duration})


func hold_until_meter_quality(quality: String, timeout: float = 2.0) -> void:
	action_queue.append({"kind": "hold_until_meter_quality", "quality": quality, "timeout": timeout})


func release_action() -> void:
	action_queue.append({"kind": "release_action"})


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
	active_drag_release_position = Vector2.ZERO
	failures.clear()


func get_failures() -> PackedStringArray:
	return failures


func step(delta: float) -> bool:
	if action_index >= action_queue.size():
		return true
	var action: Dictionary = action_queue[action_index]
	action_elapsed += delta
	match action["kind"]:
		"move_joystick":
			input_controller.movement_updated.emit(action["direction"].normalized(), clampf(action["direction"].length(), 0.0, 1.0))
			if action_elapsed >= action["duration"]:
				input_controller.movement_updated.emit(Vector2.ZERO, 0.0)
				_advance()
		"tap_player":
			var target: PlayerController = coordinator.get_offense_player_by_role(action["player_id"])
			if target != null:
				var tapped: PlayerController = input_controller.find_teammate_at_screen(target.get_screen_anchor())
				if tapped != null:
					input_controller.pass_requested.emit(tapped)
			_advance()
		"hold_drag_from_ballhandler":
			var ballhandler: PlayerController = coordinator.current_ballhandler
			if ballhandler == null:
				_advance()
				return action_index >= action_queue.size()
			if action_elapsed <= delta:
				input_controller.shot_aim_started.emit(ballhandler.world_position)
				active_drag_release_position = ballhandler.get_screen_anchor()
			if action_elapsed >= action["duration"]:
				_advance()
		"hold_until_meter_quality":
			var meter_ballhandler: PlayerController = coordinator.current_ballhandler
			if meter_ballhandler == null:
				_advance()
				return action_index >= action_queue.size()
			if action_elapsed <= delta:
				input_controller.shot_aim_started.emit(meter_ballhandler.world_position)
				active_drag_release_position = meter_ballhandler.get_screen_anchor()
			if coordinator.context.current_state == GameState.State.SHOT_AIM and action_elapsed > delta:
				_set_meter_quality(str(action.get("quality", "")))
				_advance()
				return action_index >= action_queue.size()
			if action_elapsed >= float(action.get("timeout", 2.0)):
				_advance()
		"release_action":
			var projection: CourtProjection = coordinator.court_projection
			var release_world: Vector2 = projection.screen_to_world_ground(active_drag_release_position) if projection != null else active_drag_release_position
			input_controller.shot_aim_released.emit(active_drag_release_position, release_world, Vector2.ZERO)
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


func _set_meter_quality(quality: String) -> void:
	var shot_controller: ShotController = coordinator.shot_controller
	if shot_controller == null or shot_controller.shot_config == null:
		return
	var target_progress: float = shot_controller.shot_config.meter_green_center
	if quality != "green":
		target_progress = 0.08
	shot_controller.aim_elapsed = shot_controller.shot_config.meter_cycle_duration * target_progress
