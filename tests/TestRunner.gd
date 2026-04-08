class_name TestRunner
extends Node

var pure_logic_results: Array[Dictionary] = []
var scenario_results: Array[Dictionary] = []
var balance_results: Array[Dictionary] = []
var total_failed: int = 0
var logger: LogWriter = LogWriter.new("test_run")


func _ready() -> void:
	await get_tree().process_frame
	await run_all()
	_write_summary()
	get_tree().quit(1 if total_failed > 0 else 0)


func run_all() -> Array:
	pure_logic_results.clear()
	scenario_results.clear()
	balance_results.clear()
	total_failed = 0
	logger.set_prefix("test_run_%d" % Time.get_ticks_msec())
	logger.clear_runtime_logs()
	logger.log_test("Pocket Hoops tests starting")
	_run_pure_logic()
	await _run_scenarios()
	_run_balance()
	return pure_logic_results


func _write_summary() -> void:
	var summary: PackedStringArray = PackedStringArray()
	summary.append("Pocket Hoops test summary")
	summary.append("Pure logic: %d" % pure_logic_results.size())
	summary.append("Scenarios: %d" % scenario_results.size())
	summary.append("Balance: %d" % balance_results.size())
	summary.append("Failures: %d" % total_failed)
	for result in pure_logic_results + scenario_results + balance_results:
		var status: String = "PASS" if result["passed"] else "FAIL"
		summary.append("[%s] %s %s" % [status, result["name"] if result.has("name") else result.get("display_name", result.get("batch_id", "unknown")), result.get("detail", "")])
	var summary_text: String = "\n".join(summary)
	logger.log_test(summary_text)
	print(summary_text)


func _run_pure_logic() -> void:
	_assert_true(Vector2(3.0, 4.0).normalized().length() > 0.99, "joystick normalization", "")

	var shot_controller: ShotController = ShotController.new()
	shot_controller.shot_config = ShotTimingConfig.new()
	shot_controller.ball_config = BallPhysicsConfig.new()
	shot_controller.court_config = CourtConfig.new()
	var projection_config: ProjectionConfig = ProjectionConfig.new()
	projection_config.preview_projection_lift_multiplier = 1.0
	var projection: CourtProjection = CourtProjection.new(projection_config, shot_controller.court_config)
	shot_controller.projection = projection
	var rng: GameRng = GameRng.new()
	rng.reseed(42)
	var shooter: PlayerData = PlayerData.new()
	shooter.shooting = 82
	shooter.release_consistency = 80

	var green_window: Vector2 = shot_controller.get_green_window(false, shooter.release_consistency)
	var contested_green_window: Vector2 = shot_controller.get_green_window(true, shooter.release_consistency)
	var low_consistency_green_window: Vector2 = shot_controller.get_green_window(false, 12)
	_assert_true(absf((contested_green_window.y - contested_green_window.x) - (green_window.y - green_window.x)) < 0.0001, "contest does not change meter green", "")
	_assert_true(absf((low_consistency_green_window.y - low_consistency_green_window.x) - (green_window.y - green_window.x)) < 0.0001, "ratings do not change meter green", "")
	_assert_true(shot_controller.classify_meter_progress(shot_controller.shot_config.meter_green_center, false, shooter.release_consistency) == "green", "meter green center", "")
	_assert_true(shot_controller.classify_meter_progress(shot_controller.shot_config.meter_green_center, true, 10) == "green", "meter green center holds under contest", "")
	_assert_true(shot_controller.classify_meter_progress(0.08, false, shooter.release_consistency) == "red", "meter red edge", "")

	shot_controller.begin_aim(Vector2.ZERO)
	shot_controller.update_aim(shot_controller.shot_config.meter_cycle_duration * shot_controller.shot_config.meter_green_center, Vector2.ZERO)
	var meter_snapshot: Dictionary = shot_controller.get_meter_snapshot(false, shooter.release_consistency)
	_assert_true(meter_snapshot["visible"] and meter_snapshot["quality"] == "green", "meter snapshot visible and green", "")
	var contested_snapshot: Dictionary = shot_controller.get_meter_snapshot(true, 10)
	_assert_true(absf(float(contested_snapshot["green_start"]) - float(meter_snapshot["green_start"])) < 0.0001 and absf(float(contested_snapshot["green_end"]) - float(meter_snapshot["green_end"])) < 0.0001, "meter snapshot green window stays fixed", "")
	var ping_pong_probe: ShotController = ShotController.new()
	ping_pong_probe.shot_config = shot_controller.shot_config
	ping_pong_probe.ball_config = shot_controller.ball_config
	ping_pong_probe.court_config = shot_controller.court_config
	ping_pong_probe.begin_aim(Vector2.ZERO)
	ping_pong_probe.update_aim(ping_pong_probe.shot_config.meter_cycle_duration * 1.25, Vector2.ZERO)
	_assert_true(absf(ping_pong_probe.get_meter_progress() - 0.75) < 0.03, "meter ping pong motion", "")

	var far_ground: Vector2 = projection.world_to_screen_ground(Vector2(540.0, 320.0))
	var near_ground: Vector2 = projection.world_to_screen_ground(Vector2(540.0, 1500.0))
	_assert_true(far_ground.y < near_ground.y, "projection orders up-court depth", "")
	var court_rect: Rect2 = shot_controller.court_config.court_rect
	var top_left: Vector2 = projection.world_to_screen_ground(court_rect.position)
	var top_right: Vector2 = projection.world_to_screen_ground(Vector2(court_rect.end.x, court_rect.position.y))
	var bottom_left: Vector2 = projection.world_to_screen_ground(Vector2(court_rect.position.x, court_rect.end.y))
	var bottom_right: Vector2 = projection.world_to_screen_ground(court_rect.end)
	_assert_true(absf((top_right.x - top_left.x) - (bottom_right.x - bottom_left.x)) < 0.001, "projection keeps court width constant", "")
	var mid_world_y: float = court_rect.position.y + court_rect.size.y * 0.5
	var mid_ground: Vector2 = projection.world_to_screen_ground(Vector2(court_rect.get_center().x, mid_world_y))
	var expected_mid_y: float = lerpf(projection_config.screen_horizon_y, projection_config.screen_floor_y, 0.5)
	_assert_true(absf(mid_ground.y - expected_mid_y) < 0.001, "projection maps court depth linearly", "")
	var round_trip_world: Vector2 = Vector2(740.0, 1110.0)
	var round_trip_screen: Vector2 = projection.world_to_screen_ground(round_trip_world)
	_assert_true(projection.screen_to_world_ground(round_trip_screen).distance_to(round_trip_world) < 0.01, "projection round trips ground coordinates", "")
	var lifted: Vector2 = projection.world_to_screen(Vector2(540.0, 1100.0), 180.0)
	var ground: Vector2 = projection.world_to_screen_ground(Vector2(540.0, 1100.0))
	_assert_true(absf(lifted.x - ground.x) < 0.001 and lifted.y < ground.y, "projection lifts from ground anchor", "")
	_assert_true(projection.actor_scale(Vector2(540.0, 1500.0)) > projection.actor_scale(Vector2(540.0, 420.0)), "near actors render larger", "")
	_assert_true(projection.depth_key(Vector2(540.0, 1500.0)) > projection.depth_key(Vector2(540.0, 420.0)), "near actors sort in front", "")
	var make_params: Dictionary = shot_controller.build_make_launch_params(Vector2(540.0, 1100.0))
	_assert_true(make_params["direction"].dot((shot_controller.court_config.hoop_position - make_params["preview_origin"]).normalized()) > 0.98, "made shot aims at hoop", "")
	var make_sim: BallSimulator = BallSimulator.new()
	make_sim.gravity = shot_controller.ball_config.gravity
	make_sim.ball_radius = shot_controller.ball_config.ball_radius
	var resolver: HoopResolver = HoopResolver.new(CourtConfig.new(), BallPhysicsConfig.new())
	make_sim.launch(make_params["preview_origin"], make_params["direction"], make_params["launch_speed"], make_params["z_speed"])
	var scored: bool = false
	for _frame in 120:
		make_sim.step(1.0 / 60.0)
		if resolver.check_hoop_interaction(make_sim)["hit_type"] == "score":
			scored = true
			break
	_assert_true(scored, "green launch scores through hoop", "")
	var miss_params: Dictionary = shot_controller.build_miss_launch_params(Vector2(540.0, 1100.0), rng)
	var miss_sim: BallSimulator = BallSimulator.new()
	miss_sim.gravity = shot_controller.ball_config.gravity
	miss_sim.ball_radius = shot_controller.ball_config.ball_radius
	miss_sim.launch(miss_params["preview_origin"], miss_params["direction"], miss_params["launch_speed"], miss_params["z_speed"])
	var miss_scored: bool = false
	for _miss_frame in 120:
		miss_sim.step(1.0 / 60.0)
		if resolver.check_hoop_interaction(miss_sim)["hit_type"] == "score":
			miss_scored = true
			break
	_assert_true(not miss_scored, "red launch misses rim center", "")
	var forced_make_params: Dictionary = shot_controller.build_make_launch_params(Vector2(560.0, 760.0))
	var forced_make_sim: BallSimulator = BallSimulator.new()
	forced_make_sim.gravity = shot_controller.ball_config.gravity
	forced_make_sim.ball_radius = shot_controller.ball_config.ball_radius
	forced_make_sim.launch(forced_make_params["preview_origin"], forced_make_params["direction"], forced_make_params["launch_speed"], forced_make_params["z_speed"], true)
	var forced_scored: bool = false
	for _forced_frame in 150:
		forced_make_sim.step(1.0 / 60.0)
		if resolver.check_hoop_interaction(forced_make_sim)["hit_type"] == "score":
			forced_scored = true
			break
	_assert_true(forced_scored, "forced green launch scores from contested lane", "")

	shot_controller.begin_aim(Vector2(540.0, 1100.0))
	var green_hold: float = shot_controller.shot_config.meter_cycle_duration * shot_controller.shot_config.meter_green_center
	shot_controller.update_aim(green_hold, Vector2.ZERO)
	var green_action: Dictionary = shot_controller.release_action(Vector2(540.0, 1100.0), shooter, false, rng)
	_assert_true(green_action["kind"] == "shot" and green_action["outcome"] == "make" and green_action["quality"] == "green", "green release makes shot", "")
	shot_controller.begin_aim(Vector2(540.0, 1100.0))
	shot_controller.update_aim(green_hold, Vector2.ZERO)
	var contested_green_action: Dictionary = shot_controller.release_action(Vector2(540.0, 1100.0), shooter, true, rng)
	_assert_true(contested_green_action["kind"] == "shot" and contested_green_action["outcome"] == "make" and contested_green_action["quality"] == "green", "green release stays make under contest", "")
	shot_controller.begin_aim(Vector2(540.0, 1100.0))
	shot_controller.update_aim(0.04, Vector2.ZERO)
	var red_action: Dictionary = shot_controller.release_action(Vector2(540.0, 1100.0), shooter, false, rng)
	_assert_true(red_action["kind"] == "shot" and red_action["outcome"] == "miss" and red_action["quality"] == "red", "red release misses shot", "")

	var simulator: BallSimulator = BallSimulator.new()
	simulator.gravity = BallPhysicsConfig.new().gravity
	simulator.launch(Vector2(540.0, 980.0), Vector2.UP, 700.0, 700.0)
	simulator.step(1.0 / 60.0)
	_assert_true(simulator.z > 0.0, "ball gains z", "")
	_assert_true(simulator.vz < 700.0, "gravity reduces vz", "")

	var score_sim: BallSimulator = BallSimulator.new()
	score_sim.position_xy = Vector2(540.0, 360.0)
	score_sim.previous_position_xy = Vector2(540.0, 372.0)
	score_sim.previous_z = 210.0
	score_sim.z = 160.0
	score_sim.vz = -100.0
	_assert_true(resolver.check_hoop_interaction(score_sim)["hit_type"] == "score", "descending score plane", "")

	var court: CourtConfig = CourtConfig.new()
	_assert_true(not court.is_three_point(court.hoop_position + Vector2(0.0, 120.0)), "inside arc two", "")
	_assert_true(court.is_three_point(court.hoop_position + Vector2(0.0, 500.0)), "outside arc three", "")

	var pass_controller: PassController = PassController.new()
	pass_controller.pass_config = PassConfig.new()
	pass_controller.court_config = court
	var defender: PlayerController = PlayerController.new()
	var defender_data: PlayerData = PlayerData.new()
	defender_data.steal = 85
	defender_data.perimeter_defense = 82
	defender.setup(defender_data, false, Color.RED)
	defender.world_position = Vector2(540.0, 720.0)
	var short_target: PlayerController = PlayerController.new()
	short_target.setup(PlayerData.new(), true, Color.BLUE)
	short_target.world_position = Vector2(600.0, 840.0)
	var long_target: PlayerController = PlayerController.new()
	long_target.setup(PlayerData.new(), true, Color.BLUE)
	long_target.world_position = Vector2(820.0, 420.0)
	rng.reseed(11)
	var short_found: int = 0
	var long_found: int = 0
	for _i in 40:
		if pass_controller._find_interceptor(Vector2(520.0, 900.0), short_target.world_position, [defender], rng).size() > 0:
			short_found += 1
		if pass_controller._find_interceptor(Vector2(260.0, 1180.0), long_target.world_position, [defender], rng).size() > 0:
			long_found += 1
	_assert_true(long_found > short_found, "risky pass intercepted more", "short=%d long=%d" % [short_found, long_found])
	var input_controller: InputController = InputController.new()
	input_controller.set_projection(projection)
	input_controller.set_ballhandler(short_target)
	input_controller.set_offense_players([short_target, long_target])
	input_controller.shot_hold_delay = shot_controller.shot_config.hold_start_delay
	short_target.apply_projection(projection.world_to_screen_ground(short_target.world_position), projection.actor_scale(short_target.world_position), projection.shadow_anchor(short_target.world_position) - projection.world_to_screen_ground(short_target.world_position), projection.shadow_scale(short_target.world_position), projection.depth_key(short_target.world_position))
	long_target.apply_projection(projection.world_to_screen_ground(long_target.world_position), projection.actor_scale(long_target.world_position), projection.shadow_anchor(long_target.world_position) - projection.world_to_screen_ground(long_target.world_position), projection.shadow_scale(long_target.world_position), projection.depth_key(long_target.world_position))
	_assert_true(input_controller.find_teammate_at_screen(long_target.get_screen_anchor()) == long_target, "projected tap selects intended teammate", "")

	var route_controller: RouteController = RouteController.new()
	route_controller.route_config = RouteConfig.new()
	route_controller.court_config = court
	var players: Array[PlayerController] = []
	for role in ["PG", "LW", "RW", "LC", "RC"]:
		var player: PlayerController = PlayerController.new()
		var data: PlayerData = PlayerData.new()
		data.role = role
		player.setup(data, true, Color.BLUE)
		player.world_position = court.get_anchor_map()[role]
		players.append(player)
	var targets: Dictionary = route_controller.get_route_targets(players, players[0], 0, 1.2)
	_assert_true(targets.size() == 4, "route targets generated", "")

	var rebound_controller: ReboundController = ReboundController.new()
	rebound_controller.rebound_config = ReboundConfig.new()
	var candidates: Array[Dictionary] = rebound_controller.get_rebound_candidates(Vector2(540.0, 640.0), players.slice(0, 2), players.slice(2, 5))
	_assert_true(candidates.size() >= 2, "rebound fallback candidates", "")

	var sim_controller: OpponentSimController = OpponentSimController.new()
	sim_controller.sim_config = OpponentSimConfig.new()
	sim_controller.difficulty_config = DifficultyConfig.new()
	rng.reseed(9)
	var home_team: TeamData = load("res://data/teams/HOM.tres")
	var away_team: TeamData = load("res://data/teams/AWY.tres")
	var sim_result: Dictionary = sim_controller.run_possession(away_team, home_team, 180.0, rng)
	_assert_true(sim_result["points_scored"] >= 0 and sim_result["points_scored"] <= 3, "opponent sim valid score", "")
	_assert_true(sim_result["time_consumed"] > 0.0, "opponent sim consumes time", "")

	var log_writer: LogWriter = LogWriter.new()
	log_writer.set_prefix("test_check")
	log_writer.log_match("hello")
	var file_path: String = ProjectSettings.globalize_path("user://logs/test_check_match.log")
	_assert_true(FileAccess.file_exists(file_path), "logs written", file_path)
	_assert_true(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/GameRoot.tscn", "gameplay boot scene", "")
	var game_root_scene: PackedScene = load("res://scenes/GameRoot.tscn")
	var game_root: Node2D = game_root_scene.instantiate() as Node2D
	add_child(game_root)
	var smoke_court_view: CourtView = game_root.get_node("CourtView") as CourtView
	var smoke_coordinator: GameCoordinator = game_root.get_node("GameCoordinator") as GameCoordinator
	_assert_true(smoke_court_view != null and smoke_court_view.has_textured_court(), "court art smoke", "")
	_assert_true(smoke_coordinator != null and smoke_coordinator.hoop_node != null and smoke_coordinator.hoop_node.has_sprite_visuals(), "hoop art smoke", "")
	_assert_true(smoke_coordinator != null and smoke_coordinator.ball_node != null and smoke_coordinator.ball_node.has_sprite_visuals(), "ball art smoke", "")
	var home_visual_ok: bool = smoke_coordinator != null and smoke_coordinator.offense_players.size() == 5
	if home_visual_ok:
		for smoke_player in smoke_coordinator.offense_players + smoke_coordinator.defense_players:
			if not smoke_player.has_sprite_visuals():
				home_visual_ok = false
				break
	_assert_true(home_visual_ok, "player art smoke", "")
	game_root.queue_free()
	for player in players:
		player.free()
	defender.free()
	short_target.free()
	long_target.free()


func _run_scenarios() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://data/scenarios")):
		return
	var runner: ScenarioRunner = ScenarioRunner.new()
	for file_name in DirAccess.get_files_at("res://data/scenarios"):
		if not file_name.ends_with(".tres"):
			continue
		var definition: ScenarioDefinition = load("res://data/scenarios/%s" % file_name)
		var result: Dictionary = await runner.run_scenario(get_tree(), definition)
		scenario_results.append(result)
		logger.log_test("[%s] scenario %s %s" % ["PASS" if result["passed"] else "FAIL", result["name"], result["detail"]])
		if not result["passed"]:
			total_failed += 1


func _run_balance() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://data/balance")):
		return
	var runner: BalanceRunner = BalanceRunner.new()
	for file_name in DirAccess.get_files_at("res://data/balance"):
		if not file_name.ends_with(".tres"):
			continue
		var definition: BalanceBatchDefinition = load("res://data/balance/%s" % file_name)
		var result: Dictionary = runner.run_batch(definition)
		result["name"] = result["batch_id"]
		balance_results.append(result)
		logger.log_test("[%s] balance %s %s" % ["PASS" if result["passed"] else "FAIL", result["batch_id"], result["detail"]])
		if not result["passed"]:
			total_failed += 1


func _assert_true(condition: bool, name: String, detail: String) -> void:
	var result: Dictionary = {"name": name, "passed": condition, "detail": detail}
	pure_logic_results.append(result)
	if not condition:
		total_failed += 1


func _max_preview_z(points: Array[Dictionary]) -> float:
	var max_z: float = 0.0
	for point in points:
		max_z = maxf(max_z, point["z"])
	return max_z
