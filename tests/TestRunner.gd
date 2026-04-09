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
	await _run_pure_logic()
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
	var preview_lifted: Vector2 = projection.preview_world_to_screen(Vector2(540.0, 1100.0), 180.0)
	var ground: Vector2 = projection.world_to_screen_ground(Vector2(540.0, 1100.0))
	_assert_true(absf(lifted.x - ground.x) < 0.001 and lifted.y < ground.y, "projection lifts from ground anchor", "")
	_assert_true(ground.y - lifted.y > 60.0, "projection gives cinematic z lift", "")
	_assert_true(preview_lifted.y < lifted.y, "preview lift exceeds live ball lift", "")
	_assert_true(projection.actor_scale(Vector2(540.0, 1500.0)) > projection.actor_scale(Vector2(540.0, 420.0)), "near actors render larger", "")
	_assert_true(projection.depth_key(Vector2(540.0, 1500.0)) > projection.depth_key(Vector2(540.0, 420.0)), "near actors sort in front", "")
	var near_origin: Vector2 = Vector2(560.0, 760.0)
	var far_origin: Vector2 = Vector2(540.0, 1400.0)
	var near_green_profile: Dictionary = shot_controller.build_launch_profile(near_origin, "green")
	var far_green_profile: Dictionary = shot_controller.build_launch_profile(far_origin, "green")
	var expected_make_entry: Vector2 = shot_controller.get_current_make_entry_target()
	_assert_true(str(near_green_profile.get("profile_kind", "")) == ShotController.PROFILE_KIND_GUIDED_MAKE, "green launch uses guided make profile", "")
	_assert_true(near_green_profile["entry_xy"].distance_to(expected_make_entry) < 0.001, "green launch targets front rim entry", "")
	_assert_true(absf(float(near_green_profile["entry_z"]) - shot_controller.court_config.rim_height) < 0.001, "guided make handoff sits on rim plane", str(near_green_profile["entry_z"]))
	_assert_true(float(near_green_profile["score_gate_z"]) < shot_controller.court_config.rim_height, "guided make score gate starts below rim", str(near_green_profile["score_gate_z"]))
	_assert_true(float(near_green_profile["launch_z"]) > 0.0, "shots launch above floor", "")
	_assert_true(float(near_green_profile["flight_time"]) >= shot_controller.ball_config.made_shot_min_flight_time_near, "near shot meets cinematic airtime", "")
	_assert_true(float(far_green_profile["flight_time"]) >= shot_controller.ball_config.made_shot_min_flight_time_far, "far shot meets cinematic airtime", "")
	_assert_true(float(far_green_profile["apex_z"]) >= shot_controller.ball_config.made_shot_min_apex_far, "far shot meets cinematic apex", "")
	_assert_true(float(far_green_profile["flight_time"]) > float(near_green_profile["flight_time"]), "far shot hangs longer than near shot", "")
	_assert_true(float(far_green_profile["apex_z"]) > float(near_green_profile["apex_z"]), "far shot arcs higher than near shot", "")
	_assert_true(_is_legal_score_sample(near_green_profile["score_gate_xy"], shot_controller.court_config), "green score gate stays inside legal corridor", str(near_green_profile["score_gate_xy"]))
	var far_preview_points: Array[Dictionary] = shot_controller.create_preview(_new_ball_simulator(shot_controller.ball_config), far_green_profile)
	_assert_true(_max_preview_z(far_preview_points) >= float(far_green_profile["apex_z"]) - 56.0, "far preview stays close to cinematic apex", "")
	var make_sim: BallSimulator = _new_ball_simulator(shot_controller.ball_config)
	var resolver: HoopResolver = HoopResolver.new(CourtConfig.new(), BallPhysicsConfig.new())
	make_sim.launch_shot_profile(near_green_profile)
	var scored: bool = false
	var score_interaction: Dictionary = {}
	var first_score_interaction: Dictionary = {}
	var saw_guided_descent: bool = false
	var saw_net_exit: bool = false
	var pre_score_board_side: bool = false
	var max_descent_center_offset: float = 0.0
	var score_phase: String = ""
	var handoff_reached: bool = false
	var saw_above_rim_after_handoff: bool = false
	var first_guided_descent_z: float = INF
	var first_guided_descent_vz: float = 0.0
	for _frame in 300:
		make_sim.step(1.0 / 60.0)
		match make_sim.get_flight_phase():
			BallSimulator.FLIGHT_PHASE_GUIDED_DESCENT:
				saw_guided_descent = true
				if is_inf(first_guided_descent_z):
					first_guided_descent_z = make_sim.z
					first_guided_descent_vz = make_sim.vz
			BallSimulator.FLIGHT_PHASE_NET_EXIT:
				saw_net_exit = true
		if make_sim.get_flight_phase() != BallSimulator.FLIGHT_PHASE_FREE_FLIGHT and make_sim.get_flight_phase() != BallSimulator.FLIGHT_PHASE_NONE:
			handoff_reached = true
		if handoff_reached and not scored and make_sim.z > shot_controller.court_config.rim_height + 0.01:
			saw_above_rim_after_handoff = true
		if not make_sim.has_passed_score_gate():
			if make_sim.z < shot_controller.court_config.over_backboard_z_threshold and make_sim.position_xy.y <= shot_controller.court_config.backboard_y + shot_controller.ball_config.ball_radius * 0.2:
				pre_score_board_side = true
		if make_sim.get_flight_phase() == BallSimulator.FLIGHT_PHASE_GUIDED_DESCENT or make_sim.get_flight_phase() == BallSimulator.FLIGHT_PHASE_NET_EXIT:
			max_descent_center_offset = maxf(max_descent_center_offset, absf(make_sim.position_xy.x - shot_controller.court_config.hoop_position.x))
		score_interaction = resolver.check_hoop_interaction(make_sim)
		if score_interaction["hit_type"] == "score" and not scored:
			scored = true
			score_phase = make_sim.get_flight_phase()
			first_score_interaction = score_interaction.duplicate(true)
		if scored and saw_net_exit and not make_sim.is_in_flight:
			break
	_assert_true(saw_guided_descent, "guided make enters guided descent", "")
	_assert_true(saw_net_exit, "guided make exits below net", "")
	_assert_true(not saw_above_rim_after_handoff, "guided make never rises above rim after handoff", "")
	_assert_true(not pre_score_board_side, "guided make never goes board-side before score", "")
	_assert_true(max_descent_center_offset <= shot_controller.ball_config.made_shot_descent_centering_tolerance + 0.5, "guided make descent stays centered", str(max_descent_center_offset))
	_assert_true(scored, "green launch scores through hoop", "")
	if scored:
		_assert_true(first_guided_descent_z <= shot_controller.court_config.rim_height + 0.01 and first_guided_descent_vz < 0.0, "first visible guided descent sample is already dropping from rim", "%0.2f %0.2f" % [first_guided_descent_z, first_guided_descent_vz])
		_assert_true(score_phase == BallSimulator.FLIGHT_PHASE_GUIDED_DESCENT, "green score happens during guided descent", score_phase)
		_assert_true(_is_legal_score_sample(first_score_interaction["score_sample_xy"], shot_controller.court_config), "green score enters legal front-half corridor", str(first_score_interaction["score_sample_xy"]))
	shot_controller.begin_aim(Vector2(540.0, 1100.0), rng)
	shot_controller.update_aim(0.04, Vector2.ZERO)
	var red_preview_profile: Dictionary = shot_controller.get_preview_profile(Vector2(540.0, 1100.0), shooter, false)
	var red_preview_points: Array[Dictionary] = shot_controller.create_preview(_new_ball_simulator(shot_controller.ball_config), red_preview_profile)
	var red_action: Dictionary = shot_controller.release_action(Vector2(540.0, 1100.0), shooter, false, rng)
	_assert_true(red_action["kind"] == "shot" and red_action["outcome"] == "miss" and red_action["quality"] == "red", "red release misses shot", "")
	_assert_true(str(red_action.get("profile_kind", "")) == ShotController.PROFILE_KIND_FREE_FLIGHT, "red release stays free-flight", "")
	_assert_true(_launch_profiles_match(red_preview_profile, red_action), "red preview matches release path", "")
	_assert_true(not red_preview_points.is_empty(), "red preview renders samples", "")
	if not red_preview_points.is_empty():
		var preview_probe: BallSimulator = _new_ball_simulator(shot_controller.ball_config)
		preview_probe.launch_shot_profile(red_action)
		for point in red_preview_points:
			preview_probe.step(point["sample_delta"])
		var red_preview_last: Dictionary = red_preview_points[maxi(red_preview_points.size() - 1, 0)]
		_assert_true(preview_probe.position_xy.distance_to(red_preview_last["position"]) < 0.01 and absf(preview_probe.z - float(red_preview_last["z"])) < 0.01, "preview samples mirror live simulation", "")
	var miss_sim: BallSimulator = _new_ball_simulator(shot_controller.ball_config)
	miss_sim.launch_shot_profile(red_action)
	var miss_scored: bool = false
	var miss_entered_guided_phase: bool = false
	for _miss_frame in 240:
		miss_sim.step(1.0 / 60.0)
		if miss_sim.get_flight_phase() == BallSimulator.FLIGHT_PHASE_MAKE_CAPTURE or miss_sim.get_flight_phase() == BallSimulator.FLIGHT_PHASE_GUIDED_DESCENT or miss_sim.get_flight_phase() == BallSimulator.FLIGHT_PHASE_NET_EXIT:
			miss_entered_guided_phase = true
		if resolver.check_hoop_interaction(miss_sim)["hit_type"] == "score":
			miss_scored = true
			break
	_assert_true(not miss_entered_guided_phase, "miss does not enter guided make phases", "")
	_assert_true(not miss_scored, "red launch misses rim center", "")

	var green_hold: float = shot_controller.shot_config.meter_cycle_duration * shot_controller.shot_config.meter_green_center
	shot_controller.begin_aim(Vector2(540.0, 1100.0), rng)
	shot_controller.update_aim(green_hold, Vector2.ZERO)
	var green_preview_profile: Dictionary = shot_controller.get_preview_profile(Vector2(540.0, 1100.0), shooter, false)
	var green_action: Dictionary = shot_controller.release_action(Vector2(540.0, 1100.0), shooter, false, rng)
	_assert_true(green_action["kind"] == "shot" and green_action["outcome"] == "make" and green_action["quality"] == "green", "green release makes shot", "")
	_assert_true(_launch_profiles_match(green_preview_profile, green_action), "green preview matches release path", "")
	shot_controller.begin_aim(Vector2(540.0, 1100.0), rng)
	shot_controller.update_aim(green_hold, Vector2.ZERO)
	var contested_green_action: Dictionary = shot_controller.release_action(Vector2(540.0, 1100.0), shooter, true, rng)
	_assert_true(contested_green_action["kind"] == "shot" and contested_green_action["outcome"] == "make" and contested_green_action["quality"] == "green", "green release stays make under contest", "")

	var simulator: BallSimulator = _new_ball_simulator(BallPhysicsConfig.new())
	simulator.launch(Vector2(540.0, 980.0), Vector2.UP * 700.0, shot_controller.ball_config.shot_release_height, 700.0)
	simulator.step(1.0 / 60.0)
	_assert_true(simulator.z > shot_controller.ball_config.shot_release_height, "ball gains z", "")
	_assert_true(simulator.vz < 700.0, "gravity reduces vz", "")

	var score_sim: BallSimulator = BallSimulator.new()
	score_sim.position_xy = Vector2(540.0, 360.0)
	score_sim.previous_position_xy = Vector2(540.0, 372.0)
	score_sim.previous_z = 210.0
	score_sim.z = 160.0
	score_sim.vz = -100.0
	_assert_true(resolver.check_hoop_interaction(score_sim)["hit_type"] == "score", "descending score plane", "")
	var invalid_score_sim: BallSimulator = BallSimulator.new()
	invalid_score_sim.position_xy = Vector2(540.0, 354.0)
	invalid_score_sim.previous_position_xy = Vector2(540.0, 354.0)
	invalid_score_sim.previous_z = 210.0
	invalid_score_sim.z = 160.0
	invalid_score_sim.vz = -100.0
	_assert_true(resolver.check_hoop_interaction(invalid_score_sim)["hit_type"] != "score", "backboard-side crossing does not score", "")
	var invalid_forced_score_sim: BallSimulator = BallSimulator.new()
	invalid_forced_score_sim.position_xy = Vector2(540.0, 354.0)
	invalid_forced_score_sim.previous_position_xy = Vector2(540.0, 354.0)
	invalid_forced_score_sim.previous_z = 210.0
	invalid_forced_score_sim.z = 160.0
	invalid_forced_score_sim.vz = -100.0
	invalid_forced_score_sim.forced_make = true
	_assert_true(resolver.check_hoop_interaction(invalid_forced_score_sim)["hit_type"] != "score", "forced make does not score from invalid back-half entry", "")

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
	_assert_true(smoke_coordinator != null and smoke_coordinator.hoop_node != null and smoke_coordinator.hoop_node.has_method("get_ball_z_index_for_phase"), "hoop render-phase z accessor exists", "")
	_assert_true(smoke_coordinator != null and smoke_coordinator.hoop_node != null and smoke_coordinator.hoop_node.has_method("get_front_net_exit_screen_y"), "hoop net exit helper exists", "")
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
	await get_tree().process_frame
	await _run_hoop_render_phase_smoke()


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


func _run_hoop_render_phase_smoke() -> void:
	var game_root_scene: PackedScene = load("res://scenes/GameRoot.tscn")
	var game_root: Node2D = game_root_scene.instantiate() as Node2D
	add_child(game_root)
	await get_tree().process_frame
	await get_tree().process_frame
	var smoke_coordinator: GameCoordinator = game_root.get_node("GameCoordinator") as GameCoordinator
	_assert_true(smoke_coordinator != null, "through-net smoke coordinator exists", "")
	if smoke_coordinator == null:
		game_root.queue_free()
		await get_tree().process_frame
		return
	_assert_true(smoke_coordinator.has_method("get_ball_render_phase"), "ball render phase accessor exists", "")
	_assert_true(smoke_coordinator.has_method("did_last_scored_shot_pass_through_net"), "through-net score accessor exists", "")
	_assert_true(smoke_coordinator.has_method("get_net_swish_active"), "net swish accessor exists", "")
	if smoke_coordinator.hoop_node != null:
		if smoke_coordinator.hoop_node.has_method("supports_three_piece_visuals"):
			_assert_true(bool(smoke_coordinator.hoop_node.call("supports_three_piece_visuals")), "three-piece hoop visuals exist", "")
		var back_z: int = int(smoke_coordinator.hoop_node.call("get_ball_z_index_for_phase", "behind_backboard"))
		var rim_z: int = int(smoke_coordinator.hoop_node.call("get_ball_z_index_for_phase", "rim_mouth"))
		var channel_z: int = int(smoke_coordinator.hoop_node.call("get_ball_z_index_for_phase", "net_channel"))
		var front_z: int = int(smoke_coordinator.hoop_node.call("get_ball_z_index_for_phase", "front_of_net"))
		_assert_true(back_z < rim_z and rim_z < channel_z and channel_z < front_z, "hoop phase z-order increases frontward", "%d %d %d %d" % [back_z, rim_z, channel_z, front_z])
		if smoke_coordinator.hoop_node.has_method("is_net_swish_active"):
			_assert_true(not bool(smoke_coordinator.hoop_node.call("is_net_swish_active")), "net swish idle before score", "")
	smoke_coordinator.begin_test_mode(1708)
	smoke_coordinator.test_force_scoring_shot("RC", 2)
	var through_net: bool = false
	var score_seen: bool = false
	var score_phase: String = ""
	var swish_when_scored: bool = false
	var first_phase_frame: Dictionary = {}
	var front_after_net_frame: int = -1
	var score_z: float = INF
	for frame in 180:
		await get_tree().process_frame
		if smoke_coordinator.has_method("did_last_scored_shot_pass_through_net"):
			through_net = bool(smoke_coordinator.call("did_last_scored_shot_pass_through_net"))
		if smoke_coordinator.has_method("get_ball_render_phase"):
			var phase: String = str(smoke_coordinator.call("get_ball_render_phase"))
			if phase != "" and not first_phase_frame.has(phase):
				first_phase_frame[phase] = frame
			if phase == "front_of_net" and first_phase_frame.has("net_channel") and frame > int(first_phase_frame["net_channel"]) and front_after_net_frame == -1:
				front_after_net_frame = frame
			if smoke_coordinator.context.home_score > 0 and not score_seen:
				score_seen = true
				score_phase = phase
				score_z = smoke_coordinator.ball_simulator.z
				if smoke_coordinator.has_method("get_net_swish_active"):
					swish_when_scored = bool(smoke_coordinator.call("get_net_swish_active"))
		if score_seen and front_after_net_frame != -1:
			break
	_assert_true(first_phase_frame.has("net_channel"), "made shot enters net channel phase", str(first_phase_frame))
	_assert_true(front_after_net_frame != -1, "made shot emerges front of net", str(first_phase_frame))
	if first_phase_frame.has("rim_mouth") and first_phase_frame.has("net_channel"):
		_assert_true(int(first_phase_frame["rim_mouth"]) <= int(first_phase_frame["net_channel"]), "optional rim-mouth handoff occurs before net channel", str(first_phase_frame))
	if first_phase_frame.has("net_channel") and front_after_net_frame != -1:
		_assert_true(int(first_phase_frame["net_channel"]) < front_after_net_frame, "guided make phases stay ordered", str({"net_channel": first_phase_frame["net_channel"], "front_of_net": front_after_net_frame}))
	_assert_true(through_net, "made shot records through-net follow-through", "")
	_assert_true(score_seen, "made shot resolves during smoke test", "")
	_assert_true(score_phase == "net_channel", "scored frame occurs during guided descent", score_phase)
	_assert_true(score_z <= smoke_coordinator.court_config.rim_height + 0.01, "score cannot appear while ball is above rim", str(score_z))
	if smoke_coordinator.has_method("get_score_followthrough_active"):
		_assert_true(bool(smoke_coordinator.call("get_score_followthrough_active")) or score_phase == "front_of_net", "score follow-through activates after score", "")
	if smoke_coordinator.has_method("get_net_swish_active"):
		_assert_true(swish_when_scored, "net swish activates on score", "")
	game_root.queue_free()
	await get_tree().process_frame


func _max_preview_z(points: Array[Dictionary]) -> float:
	var max_z: float = 0.0
	for point in points:
		max_z = maxf(max_z, point["z"])
	return max_z


func _new_ball_simulator(config: BallPhysicsConfig) -> BallSimulator:
	var simulator: BallSimulator = BallSimulator.new()
	simulator.gravity = config.gravity
	simulator.ball_radius = config.ball_radius
	return simulator


func _launch_profiles_match(a: Dictionary, b: Dictionary, tolerance: float = 0.01) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	if str(a.get("profile_kind", "")) != str(b.get("profile_kind", "")):
		return false
	var matches: bool = a["launch_position"].distance_to(b["launch_position"]) <= tolerance \
		and a["target_xy"].distance_to(b["target_xy"]) <= tolerance \
		and a["velocity_xy"].distance_to(b["velocity_xy"]) <= tolerance \
		and absf(float(a["launch_z"]) - float(b["launch_z"])) <= tolerance \
		and absf(float(a["vz"]) - float(b["vz"])) <= tolerance \
		and absf(float(a["flight_time"]) - float(b["flight_time"])) <= tolerance
	if not matches:
		return false
	if str(a.get("profile_kind", "")) != ShotController.PROFILE_KIND_GUIDED_MAKE:
		return true
	return a["entry_xy"].distance_to(b["entry_xy"]) <= tolerance \
		and a["score_gate_xy"].distance_to(b["score_gate_xy"]) <= tolerance \
		and a["net_exit_xy"].distance_to(b["net_exit_xy"]) <= tolerance \
		and absf(float(a["entry_z"]) - float(b["entry_z"])) <= tolerance \
		and absf(float(a["entry_time"]) - float(b["entry_time"])) <= tolerance \
		and absf(float(a["descent_duration"]) - float(b["descent_duration"])) <= tolerance


func _is_legal_score_sample(sample_pos: Vector2, court: CourtConfig) -> bool:
	if sample_pos.distance_to(court.hoop_position) > court.rim_inner_radius:
		return false
	return sample_pos.y >= court.hoop_position.y + court.score_entry_min_front_offset
