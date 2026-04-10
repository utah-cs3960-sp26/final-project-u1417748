class_name ScenarioRunner
extends RefCounted

var deterministic_rng: HarnessDeterministicRng = HarnessDeterministicRng.new()
var last_result: Dictionary = {}
var last_summary: String = ""
var logger: LogWriter = LogWriter.new("scenario")


func configure(seed: int) -> void:
	deterministic_rng.reset(seed)


func run_scenario(tree: SceneTree, definition: ScenarioDefinition) -> Dictionary:
	configure(definition.seed)
	logger.set_prefix("scenario_%s_%d" % [definition.scenario_id, definition.seed])
	logger.log_scenario("BEGIN %s" % definition.scenario_id)
	var scene: PackedScene = load("res://scenes/GameRoot.tscn")
	var game_root: Node = scene.instantiate()
	tree.root.add_child(game_root)
	await tree.process_frame
	await tree.process_frame

	var coordinator: GameCoordinator = game_root.get_node("GameCoordinator") as GameCoordinator
	coordinator.begin_test_mode(definition.seed)
	coordinator.apply_test_setup(definition.initial_home_score, definition.initial_away_score, definition.initial_time_remaining)
	coordinator.apply_scenario_setup(definition.setup)
	var pilot: BotPilot = BotPilot.new()
	pilot.setup(coordinator)
	_queue_actions(pilot, definition.actions)
	pilot.reset()

	var timeout_seconds: float = 24.0
	var elapsed: float = 0.0
	while elapsed < timeout_seconds and not pilot.step(1.0 / 60.0):
		await tree.process_frame
		elapsed += 1.0 / 60.0
	await tree.process_frame
	await tree.process_frame

	var failures: PackedStringArray = PackedStringArray()
	for pilot_failure in pilot.get_failures():
		failures.append(pilot_failure)
	for expectation in definition.expectations:
		var failure: String = _check_expectation(coordinator, expectation)
		if failure != "":
			failures.append(failure)

	var result: Dictionary = {
		"name": definition.display_name if definition.display_name != "" else definition.scenario_id,
		"category": "scenario",
		"seed": definition.seed,
		"passed": failures.is_empty(),
		"detail": "" if failures.is_empty() else "; ".join(failures),
	}
	last_result = result
	last_summary = "%s: %s" % [result["name"], "PASS" if result["passed"] else result["detail"]]
	logger.log_scenario("%s %s" % [definition.scenario_id, "PASS" if result["passed"] else result["detail"]])
	tree.root.remove_child(game_root)
	game_root.free()
	await tree.process_frame
	return result


func get_summary() -> String:
	return last_summary


func _queue_actions(pilot: BotPilot, actions: Array[ScenarioAction]) -> void:
	for action in actions:
		match action.kind:
			"move_thumb", "move_joystick":
				pilot.move_thumb(action.vector, action.seconds)
			"flick_pass", "tap_player":
				pilot.flick_pass(action.target_id)
			"arm_shot", "hold_drag":
				pilot.arm_shot()
			"set_meter_quality":
				pilot.set_meter_quality(str(action.value))
			"hold_until_meter_quality":
				pilot.hold_until_meter_quality(str(action.value), action.seconds)
			"tap_meter", "release":
				pilot.tap_meter()
			"wait":
				pilot.wait(action.seconds)
			"pause_toggle":
				pilot.pause_toggle()
			"force_scoring_shot":
				pilot.force_scoring_shot(action.target_id, int(action.value) if action.value != null else 0)
			"force_rebound":
				pilot.force_rebound(action.vector)
			"force_defensive_rebound":
				pilot.force_defensive_rebound(action.target_id)
			"force_pass_interception":
				pilot.force_pass_interception()
			"force_pressure_turnover":
				pilot.force_pressure_turnover()
			"force_offensive_rebound":
				pilot.force_offensive_rebound(action.target_id)
			"assert_state":
				pilot.assert_state(str(action.value))
			"assert_score":
				var expected_score: Dictionary = action.value if action.value is Dictionary else {}
				pilot.assert_score(int(expected_score.get("home", 0)), int(expected_score.get("away", 0)))
			"assert_controlled_player":
				pilot.assert_controlled_player(action.target_id)
			"assert_last_log_contains":
				pilot.assert_last_log_contains(str(action.value))


func _check_expectation(coordinator: GameCoordinator, expectation: ScenarioExpectation) -> String:
	match expectation.kind:
		"state":
			if coordinator.get_state_name() != str(expectation.value):
				return "state expected %s got %s" % [str(expectation.value), coordinator.get_state_name()]
		"home_score":
			if coordinator.context.home_score != int(expectation.value):
				return "home score expected %d got %d" % [int(expectation.value), coordinator.context.home_score]
		"away_score":
			if coordinator.context.away_score != int(expectation.value):
				return "away score expected %d got %d" % [int(expectation.value), coordinator.context.away_score]
		"controlled_role":
			if coordinator.get_controlled_role() != str(expectation.value):
				return "controlled role expected %s got %s" % [str(expectation.value), coordinator.get_controlled_role()]
		"log_contains":
			if not coordinator.match_log_contains(str(expectation.value)):
				return "match log missing %s" % str(expectation.value)
		"clock_at_most":
			if coordinator.context.match_time_remaining > float(expectation.value):
				return "clock expected <= %0.2f got %0.2f" % [float(expectation.value), coordinator.context.match_time_remaining]
		"clock_at_least":
			if coordinator.context.match_time_remaining < float(expectation.value):
				return "clock expected >= %0.2f got %0.2f" % [float(expectation.value), coordinator.context.match_time_remaining]
		"feedback_contains":
			if not coordinator.context.last_feedback_text.contains(str(expectation.value)):
				return "feedback missing %s" % str(expectation.value)
		"state_not":
			if coordinator.get_state_name() == str(expectation.value):
				return "state should not be %s" % str(expectation.value)
		"ball_render_phase":
			if not coordinator.has_method("get_ball_render_phase"):
				return "ball render phase accessor missing"
			var phase: String = str(coordinator.call("get_ball_render_phase"))
			if expectation.value is Array:
				if not (phase in expectation.value):
					return "ball render phase expected one of %s got %s" % [str(expectation.value), phase]
			elif phase != str(expectation.value):
				return "ball render phase expected %s got %s" % [str(expectation.value), phase]
		"through_net_score":
			if not coordinator.has_method("did_last_scored_shot_pass_through_net"):
				return "through-net score accessor missing"
			if bool(coordinator.call("did_last_scored_shot_pass_through_net")) != bool(expectation.value):
				return "through-net score expected %s got %s" % [str(expectation.value), str(coordinator.call("did_last_scored_shot_pass_through_net"))]
		"score_followthrough_active":
			if not coordinator.has_method("get_score_followthrough_active"):
				return "score follow-through accessor missing"
			if bool(coordinator.call("get_score_followthrough_active")) != bool(expectation.value):
				return "score follow-through expected %s got %s" % [str(expectation.value), str(coordinator.call("get_score_followthrough_active"))]
	return ""
