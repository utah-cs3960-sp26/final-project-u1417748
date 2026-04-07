extends TestCase

func get_test_id() -> String:
	return "gameplay_mechanics_smoke"

func get_category() -> String:
	return "pure_logic"

func run_case(_harness: Object) -> TestResult:
	var failures := PackedStringArray()
	var shot_config: ShotTimingConfig = load("res://data/config/ShotTimingConfig.tres")
	var pass_config: PassConfig = load("res://data/config/PassConfig.tres")
	var court_config: CourtConfig = load("res://data/config/CourtConfig.tres")
	var route_config: RouteConfig = load("res://data/config/RouteConfig.tres")
	var ball_config: BallPhysicsConfig = load("res://data/config/BallPhysicsConfig.tres")
	var sim_config: OpponentSimConfig = load("res://data/config/OpponentSimConfig.tres")
	var difficulty_config: DifficultyConfig = load("res://data/config/DifficultyConfig.tres")
	var home_team: TeamData = load("res://data/teams/HOM.tres")
	var away_team: TeamData = load("res://data/teams/AWY.tres")
	var low_power: float = ShotController.drag_to_power_ratio(shot_config.min_shot_drag_distance + 12.0, shot_config)
	var high_power: float = ShotController.drag_to_power_ratio(shot_config.max_shot_drag_distance, shot_config)
	if high_power <= low_power:
		failures.append("Shot power mapping is not monotonic.")
	var player_scene: PackedScene = load("res://scenes/entities/Player.tscn")
	var near_defender: PlayerController = player_scene.instantiate()
	near_defender.setup(away_team.players[0], away_team.abbreviation, away_team.primary_color, away_team.secondary_color, false, 0)
	near_defender.global_position = Vector2(220.0, 40.0)
	var far_defender: PlayerController = player_scene.instantiate()
	far_defender.setup(away_team.players[1], away_team.abbreviation, away_team.primary_color, away_team.secondary_color, false, 1)
	far_defender.global_position = Vector2(220.0, 220.0)
	var interceptor: Dictionary = PassController.find_best_interceptor(Vector2.ZERO, Vector2(420.0, 0.0), [near_defender, far_defender], pass_config, 1.0)
	if int(interceptor.get("index", -1)) != 0:
		failures.append("Expected the lane defender to be selected as interceptor.")
	var anchors: Array[Vector2] = court_config.get_default_anchors()
	var route_targets: Array[Vector2] = RouteController.get_route_targets(court_config, anchors[0], 1.6, route_config)
	if route_targets.size() != 5:
		failures.append("Route controller did not return 5 offensive targets.")
	var preview_points: Array[Vector2] = BallSimulator.generate_preview_points(anchors[0], Vector2(0.0, -ball_config.shot_max_speed * 0.55), ball_config.shot_max_vz * 0.72, 2, court_config, ball_config)
	if preview_points.is_empty():
		failures.append("Ball preview generation returned no points.")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3960
	var sim_result: Dictionary = OpponentSimController.simulate_possession(away_team, home_team, sim_config, difficulty_config.get_profile("Normal"), 24.0, rng)
	if float(sim_result.get("time_used", 0.0)) <= 0.0 or float(sim_result.get("time_used", 0.0)) > 24.0:
		failures.append("Opponent sim time used fell outside expected bounds.")
	if int(sim_result.get("score_delta", -1)) not in [0, 2, 3]:
		failures.append("Opponent sim produced an invalid score delta.")
	if failures.is_empty():
		return TestResult.passed(get_test_id(), get_category(), PackedStringArray([
			"Core gameplay math helpers and sim outputs look internally consistent.",
		]))
	return TestResult.failed(get_test_id(), get_category(), failures)
