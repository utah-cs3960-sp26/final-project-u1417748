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


func release_pass(player_id: String) -> void:
	tap_pass(player_id)


func flick_pass(player_id: String) -> void:
	tap_pass(player_id)


func tap_player(player_id: String) -> void:
	tap_pass(player_id)


func tap_pass(player_id: String = "") -> void:
	action_queue.append({"kind": "tap_pass", "player_id": player_id})


func tap_shot() -> void:
	swipe_shot(Vector2.UP)


func swipe_shot(direction: Vector2 = Vector2.UP) -> void:
	action_queue.append({"kind": "swipe_shot", "direction": direction})


func arm_shot() -> void:
	swipe_shot(Vector2.UP)


func hold_drag_from_ballhandler(_offset: Vector2, _duration: float) -> void:
	swipe_shot(Vector2.UP)


func release_center() -> void:
	action_queue.append({"kind": "release_center"})


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


func force_opponent_sim() -> void:
	action_queue.append({"kind": "force_opponent_sim"})


func force_opponent_sim_result(points_scored: int, action_count: int, time_consumed: float) -> void:
	action_queue.append({"kind": "force_opponent_sim_result", "points_scored": points_scored, "action_count": action_count, "time_consumed": time_consumed})


func tap_opponent_banner() -> void:
	action_queue.append({"kind": "tap_opponent_banner"})


func assert_state(expected_state: String) -> void:
	action_queue.append({"kind": "assert_state", "expected_state": expected_state})


func assert_score(home: int, away: int) -> void:
	action_queue.append({"kind": "assert_score", "home": home, "away": away})


func assert_controlled_player(player_id: String) -> void:
	action_queue.append({"kind": "assert_controlled_player", "player_id": player_id})


func assert_last_log_contains(text: String) -> void:
	action_queue.append({"kind": "assert_last_log_contains", "text": text})


func assert_opponent_visual_field(field: String, expected: Variant) -> void:
	action_queue.append({"kind": "assert_opponent_visual_field", "field": field, "expected": expected})


func assert_opponent_visual_bottom_half() -> void:
	action_queue.append({"kind": "assert_opponent_visual_bottom_half"})


func assert_bottom_hoop_field(field: String, expected: Variant) -> void:
	action_queue.append({"kind": "assert_bottom_hoop_field", "field": field, "expected": expected})


func assert_bottom_hoop_bottom_anchored() -> void:
	action_queue.append({"kind": "assert_bottom_hoop_bottom_anchored"})


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
		"tap_pass", "release_pass":
			_execute_tap_pass(str(action.get("player_id", "")))
			_advance()
		"tap_shot":
			_execute_swipe_shot(Vector2.UP)
			_advance()
		"swipe_shot":
			_execute_swipe_shot(action.get("direction", Vector2.UP))
			_advance()
		"release_center":
			_execute_release_center()
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
		"force_opponent_sim":
			coordinator.test_force_opponent_sim()
			_advance()
		"force_opponent_sim_result":
			coordinator.test_force_opponent_sim_result(int(action.get("points_scored", 0)), int(action.get("action_count", 1)), float(action.get("time_consumed", 4.0)))
			_advance()
		"tap_opponent_banner":
			coordinator.test_advance_opponent_sim_sequence()
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
		"assert_opponent_visual_field":
			if not _snapshot_field_matches(_get_opponent_visual_snapshot(), str(action.get("field", "")), action.get("expected", null)):
				failures.append("opponent visual snapshot field expected %s == %s" % [str(action.get("field", "")), str(action.get("expected", null))])
			_advance()
		"assert_opponent_visual_bottom_half":
			if not _opponent_visual_positions_are_bottom_half(_get_opponent_visual_snapshot()):
				failures.append("opponent visual snapshot positions were not confined to bottom half")
			_advance()
		"assert_bottom_hoop_field":
			if not _snapshot_field_matches(_get_bottom_hoop_snapshot(), str(action.get("field", "")), action.get("expected", null)):
				failures.append("bottom hoop snapshot field expected %s == %s" % [str(action.get("field", "")), str(action.get("expected", null))])
			_advance()
		"assert_bottom_hoop_bottom_anchored":
			if not _bottom_hoop_is_bottom_anchored(_get_bottom_hoop_snapshot()):
				failures.append("bottom hoop snapshot was not bottom anchored")
			_advance()
		_:
			_advance()
	return action_index >= action_queue.size()


func _advance() -> void:
	action_index += 1
	action_elapsed = 0.0


func _execute_tap_pass(player_id: String) -> void:
	var target: PlayerController = coordinator.get_offense_player_by_role(player_id)
	var tap_position: Vector2 = target.get_screen_anchor() if target != null else _get_upper_pass_tap_position()
	input_controller.tap_test_pass(tap_position, 0.05)


func _execute_swipe_shot(direction: Vector2 = Vector2.UP) -> void:
	var swipe_direction: Vector2 = direction.normalized()
	if swipe_direction.length_squared() <= 0.001:
		swipe_direction = Vector2.UP
	var swipe_start: Vector2 = _get_shot_swipe_start_position()
	var swipe_end: Vector2 = _get_control_zone_center("shoot")
	if swipe_direction.y > 0.001:
		swipe_end = _get_control_zone_center("dunk")
	elif absf(swipe_direction.x) > absf(swipe_direction.y):
		swipe_end = swipe_start + Vector2(maxf(float(coordinator.input_config.control_action_min_distance_pixels) + 24.0, float(coordinator.input_config.deadzone) + 12.0), 0.0)
	input_controller.swipe_test_shot_arm(
		swipe_start,
		swipe_end,
		0.12
	)


func _execute_release_center() -> void:
	var anchor: Vector2 = _get_lower_zone_anchor()
	var drag_distance: float = maxf(float(coordinator.input_config.control_action_min_distance_pixels) + 24.0, float(coordinator.input_config.deadzone) + 12.0)
	var drag_screen: Vector2 = anchor + Vector2(drag_distance, 0.0)
	input_controller.begin_test_live_gesture(anchor)
	input_controller.update_test_live_gesture(drag_screen)
	input_controller.end_test_live_gesture(anchor)


func _get_opponent_visual_snapshot() -> Dictionary:
	if coordinator == null or not coordinator.has_method("get_opponent_sim_visual_snapshot"):
		return {}
	var snapshot: Variant = coordinator.call("get_opponent_sim_visual_snapshot")
	return snapshot if snapshot is Dictionary else {}


func _get_bottom_hoop_snapshot() -> Dictionary:
	if coordinator == null or coordinator.court_view == null or not coordinator.court_view.has_method("get_bottom_hoop_snapshot"):
		return {}
	var snapshot: Variant = coordinator.court_view.call("get_bottom_hoop_snapshot")
	return snapshot if snapshot is Dictionary else {}


func _snapshot_field_matches(snapshot: Dictionary, field_path: String, expected: Variant) -> bool:
	if snapshot.is_empty() or field_path.strip_edges() == "":
		return false
	var current: Variant = snapshot
	for segment in field_path.split(".", false):
		if current is Dictionary and current.has(segment):
			current = current[segment]
		else:
			return false
	return current == expected


func _opponent_visual_positions_are_bottom_half(snapshot: Dictionary) -> bool:
	if snapshot.is_empty() or coordinator == null or coordinator.court_config == null:
		return false
	var court_rect: Rect2 = coordinator.court_config.court_rect
	var minimum_y: float = court_rect.position.y + court_rect.size.y * 0.5 - 0.01
	var positions: Array[Vector2] = []
	_collect_snapshot_positions(snapshot.get("ghost_positions_by_team", {}), positions)
	_collect_snapshot_positions(snapshot.get("ghost_positions_by_role", {}), positions)
	_collect_snapshot_positions(snapshot.get("ghost_positions", {}), positions)
	_collect_snapshot_positions(snapshot.get("away_positions", []), positions)
	_collect_snapshot_positions(snapshot.get("home_positions", []), positions)
	_collect_snapshot_positions(snapshot.get("away_ghost_positions", []), positions)
	_collect_snapshot_positions(snapshot.get("home_ghost_positions", []), positions)
	_collect_snapshot_positions(snapshot.get("actor_position", Vector2.INF), positions)
	_collect_snapshot_positions(snapshot.get("ball_anchor", Vector2.INF), positions)
	_collect_snapshot_positions(snapshot.get("ball_position", Vector2.INF), positions)
	if positions.is_empty():
		return false
	for position in positions:
		if position == Vector2.INF:
			continue
		if position.y < minimum_y:
			return false
	return true


func _bottom_hoop_is_bottom_anchored(snapshot: Dictionary) -> bool:
	if snapshot.is_empty() or coordinator == null or coordinator.court_config == null:
		return false
	var anchor_value: Variant = snapshot.get("anchor_screen", snapshot.get("screen_anchor", snapshot.get("anchor", Vector2.INF)))
	if anchor_value is Vector2 and anchor_value != Vector2.INF:
		return anchor_value.y >= coordinator.court_config.court_rect.position.y + coordinator.court_config.court_rect.size.y * 0.5
	var rect_value: Variant = snapshot.get("screen_rect", snapshot.get("bottom_hoop_rect", snapshot.get("rect", Rect2())))
	if rect_value is Rect2:
		var hoop_rect: Rect2 = rect_value
		if hoop_rect.size.x <= 0.0 or hoop_rect.size.y <= 0.0:
			return false
		if coordinator == null or coordinator.court_config == null:
			return false
		var court_rect: Rect2 = coordinator.court_config.court_rect
		if hoop_rect.get_center().y < court_rect.position.y + court_rect.size.y * 0.5:
			return false
		return true
	return false


func _collect_snapshot_positions(value: Variant, positions: Array[Vector2]) -> void:
	if value is Vector2:
		positions.append(value)
	elif value is Array:
		for item in value:
			_collect_snapshot_positions(item, positions)
	elif value is Dictionary:
		for key in value.keys():
			var key_name: String = str(key).to_lower()
			if key_name.contains("position"):
				_collect_snapshot_positions(value[key], positions)


func _get_lower_zone_anchor() -> Vector2:
	return _get_control_zone_center("move")


func _get_upper_pass_tap_position() -> Vector2:
	return _get_control_zone_center("pass_right")


func _get_shot_swipe_start_position() -> Vector2:
	return _get_lower_zone_anchor()


func _get_shot_swipe_distance() -> float:
	return maxf(float(coordinator.input_config.control_action_min_distance_pixels) + 48.0, 140.0)


func _get_control_zone_center(zone_name: String) -> Vector2:
	var control_layout: Dictionary = input_controller.get_control_layout_snapshot()
	var zone_rects: Dictionary = control_layout.get("control_zone_rects", {})
	var zone_rect: Rect2 = zone_rects.get(zone_name, Rect2())
	if zone_rect.size.x <= 0.0 or zone_rect.size.y <= 0.0:
		var viewport_size: Vector2 = coordinator.get_viewport().get_visible_rect().size
		return viewport_size * 0.5
	return zone_rect.get_center()


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
