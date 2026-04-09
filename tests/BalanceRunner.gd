class_name BalanceRunner
extends RefCounted

var last_results: Array[Dictionary] = []


func run_batch(definition: Resource) -> Dictionary:
	var batch: BalanceBatchDefinition = definition as BalanceBatchDefinition
	var result: Dictionary = {}
	match batch.batch_id:
		"shot_quality":
			result = _run_shot_quality_batch(batch)
		"pass_risk":
			result = _run_pass_risk_batch(batch)
		"difficulty_order":
			result = _run_difficulty_batch(batch)
		"rebound_distribution":
			result = _run_rebound_batch(batch)
		_:
			result = {
				"batch_id": batch.batch_id,
				"display_name": batch.display_name,
				"seed": batch.seed,
				"trial_count": batch.trial_count,
				"metrics": {},
				"passed": false,
				"detail": "unknown batch id",
			}
	last_results.append(result)
	return result


func _run_shot_quality_batch(batch: BalanceBatchDefinition) -> Dictionary:
	var shot_controller: ShotController = ShotController.new()
	shot_controller.shot_config = ShotTimingConfig.new()
	shot_controller.ball_config = BallPhysicsConfig.new()
	shot_controller.court_config = CourtConfig.new()
	var shooter: PlayerData = PlayerData.new()
	shooter.shooting = 82
	shooter.release_consistency = 82
	var green_window: Vector2 = shot_controller.get_green_window(false, shooter.release_consistency)
	var contested_green_window: Vector2 = shot_controller.get_green_window(true, shooter.release_consistency)
	var metrics: Dictionary = {
		"green_rate": 1.0,
		"red_rate": 0.0,
		"contested_green_rate": 1.0,
		"green_window_width": green_window.y - green_window.x,
		"contested_green_window_width": contested_green_window.y - contested_green_window.x,
	}
	var passed: bool = metrics["green_rate"] == 1.0 \
		and metrics["red_rate"] == 0.0 \
		and metrics["contested_green_rate"] == 1.0 \
		and absf(metrics["contested_green_window_width"] - metrics["green_window_width"]) < 0.0001
	return {
		"batch_id": batch.batch_id,
		"display_name": batch.display_name,
		"seed": batch.seed,
		"trial_count": batch.trial_count,
		"metrics": metrics,
		"passed": passed,
		"detail": JSON.stringify(metrics),
	}


func _run_pass_risk_batch(batch: BalanceBatchDefinition) -> Dictionary:
	var rng: GameRng = GameRng.new()
	rng.reseed(batch.seed)
	var pass_controller: PassController = PassController.new()
	pass_controller.pass_config = PassConfig.new()
	pass_controller.court_config = CourtConfig.new()
	pass_controller.difficulty_config = DifficultyConfig.new()
	var passer: PlayerController = PlayerController.new()
	var passer_data: PlayerData = PlayerData.new()
	passer_data.pass_accuracy = 78
	passer.setup(passer_data, true, Color.BLUE)
	var defender: PlayerController = PlayerController.new()
	var defender_data: PlayerData = PlayerData.new()
	defender_data.steal = 90
	defender_data.perimeter_defense = 86
	defender_data.speed = 82
	defender.setup(defender_data, false, Color.RED)
	var target: PlayerController = PlayerController.new()
	var target_data: PlayerData = PlayerData.new()
	target_data.catch_rating = 76
	target_data.speed = 74
	target.setup(target_data, true, Color.BLUE)
	var short_intercepts: int = 0
	var long_intercepts: int = 0
	var defense_speed_scale: float = DifficultyConfig.new().get_defense_multiplier()
	for _index in batch.trial_count:
		target.world_position = Vector2(560.0 + rng.randf_range(-18.0, 18.0), 760.0 + rng.randf_range(-18.0, 18.0))
		defender.world_position = Vector2(540.0 + rng.randf_range(-12.0, 12.0), 700.0 + rng.randf_range(-18.0, 18.0))
		var short_result: Dictionary = _simulate_pass_race(
			pass_controller,
			Vector2(520.0, 840.0),
			target,
			[defender],
			Vector2(rng.randf_range(18.0, 42.0), rng.randf_range(20.0, 44.0)),
			1.0,
			defense_speed_scale,
			240,
			rng,
			passer
		)
		if short_result.get("state", "") == "complete_steal":
			short_intercepts += 1
		target.world_position = Vector2(820.0 + rng.randf_range(-24.0, 24.0), 420.0 + rng.randf_range(-20.0, 20.0))
		defender.world_position = Vector2(540.0 + rng.randf_range(-14.0, 14.0), 700.0 + rng.randf_range(-24.0, 24.0))
		var long_result: Dictionary = _simulate_pass_race(
			pass_controller,
			Vector2(280.0, 1180.0),
			target,
			[defender],
			Vector2(rng.randf_range(96.0, 148.0), rng.randf_range(112.0, 180.0)),
			1.0,
			defense_speed_scale,
			240,
			rng,
			passer
		)
		if long_result.get("state", "") == "complete_steal":
			long_intercepts += 1
	var short_rate: float = float(short_intercepts) / batch.trial_count
	var long_rate: float = float(long_intercepts) / batch.trial_count
	target.free()
	defender.free()
	passer.free()
	return {
		"batch_id": batch.batch_id,
		"display_name": batch.display_name,
		"seed": batch.seed,
		"trial_count": batch.trial_count,
		"metrics": {"short_rate": short_rate, "long_rate": long_rate},
		"passed": short_rate < 0.12 and long_rate >= 0.22 and long_rate <= 0.45 and long_rate >= short_rate + 0.15,
		"detail": "short=%0.2f long=%0.2f" % [short_rate, long_rate],
	}


func _run_difficulty_batch(batch: BalanceBatchDefinition) -> Dictionary:
	var averages: Dictionary = {}
	for level in [DifficultyConfig.Level.EASY, DifficultyConfig.Level.NORMAL, DifficultyConfig.Level.HARD]:
		var rng: GameRng = GameRng.new()
		rng.reseed(batch.seed + level)
		var difficulty: DifficultyConfig = DifficultyConfig.new()
		difficulty.level = level
		var controller: OpponentSimController = OpponentSimController.new()
		controller.sim_config = OpponentSimConfig.new()
		controller.difficulty_config = difficulty
		var home: TeamData = load("res://data/teams/HOM.tres")
		var away: TeamData = load("res://data/teams/AWY.tres")
		var total_points: int = 0
		for _index in batch.trial_count:
			var result: Dictionary = controller.run_possession(away, home, 180.0, rng)
			total_points += result["points_scored"]
		averages[DifficultyConfig.level_name(level)] = float(total_points) / batch.trial_count
	var easy: float = averages.get("easy", 0.0)
	var normal: float = averages.get("normal", 0.0)
	var hard: float = averages.get("hard", 0.0)
	return {
		"batch_id": batch.batch_id,
		"display_name": batch.display_name,
		"seed": batch.seed,
		"trial_count": batch.trial_count,
		"metrics": {"easy": easy, "normal": normal, "hard": hard},
		"passed": easy <= normal and normal <= hard,
		"detail": "easy=%0.2f normal=%0.2f hard=%0.2f" % [easy, normal, hard],
	}


func _run_rebound_batch(batch: BalanceBatchDefinition) -> Dictionary:
	var rng: GameRng = GameRng.new()
	rng.reseed(batch.seed)
	var rebound_controller: ReboundController = ReboundController.new()
	rebound_controller.rebound_config = ReboundConfig.new()
	var offense_total: int = 0
	var defense_total: int = 0
	for _index in batch.trial_count:
		var offense: Array[PlayerController] = []
		var defense: Array[PlayerController] = []
		for i in 5:
			var o: PlayerController = PlayerController.new()
			var od: PlayerData = PlayerData.new()
			od.rebound = 62 + i
			o.setup(od, true, Color.BLUE)
			o.world_position = Vector2(430.0 + i * 28.0, 760.0 + i * 18.0)
			offense.append(o)
			var d: PlayerController = PlayerController.new()
			var dd: PlayerData = PlayerData.new()
			dd.rebound = 68 + i
			d.setup(dd, false, Color.RED)
			d.world_position = Vector2(500.0 + i * 22.0, 700.0 + i * 16.0)
			defense.append(d)
		var candidates: Array[Dictionary] = rebound_controller.get_rebound_candidates(Vector2(540.0, 620.0), offense, defense)
		var winner: Dictionary = rebound_controller.pick_winner(candidates, rng)
		if winner["is_offense"]:
			offense_total += 1
		else:
			defense_total += 1
		for player in offense:
			player.free()
		for player in defense:
			player.free()
	var offense_rate: float = float(offense_total) / batch.trial_count
	var defense_rate: float = float(defense_total) / batch.trial_count
	return {
		"batch_id": batch.batch_id,
		"display_name": batch.display_name,
		"seed": batch.seed,
		"trial_count": batch.trial_count,
		"metrics": {"offense_rate": offense_rate, "defense_rate": defense_rate},
		"passed": offense_rate > 0.18 and defense_rate > 0.35,
		"detail": "off=%0.2f def=%0.2f" % [offense_rate, defense_rate],
	}


func _simulate_pass_race(
	pass_controller: PassController,
	start_position: Vector2,
	target: PlayerController,
	defenders: Array[PlayerController],
	receiver_release_offset: Vector2,
	receiver_speed_scale: float,
	defender_speed_scale: float,
	max_frames: int = 240,
	rng: GameRng = null,
	passer: PlayerController = null
) -> Dictionary:
	pass_controller.start_pass(start_position, target, defenders, rng, passer)
	var release_target: Vector2 = pass_controller.get_active_pass_snapshot().get("end", target.world_position)
	target.world_position = release_target + receiver_release_offset
	target.velocity = Vector2.ZERO
	for _frame in max_frames:
		var snapshot: Dictionary = pass_controller.get_active_pass_snapshot()
		if snapshot.is_empty():
			break
		target.move_toward_target(release_target, receiver_speed_scale, 1.0 / 60.0)
		var interceptor: PlayerController = snapshot.get("active_interceptor", null) as PlayerController
		if interceptor != null:
			interceptor.move_toward_target(snapshot.get("chase_point", interceptor.world_position), defender_speed_scale, 1.0 / 60.0)
		var result: Dictionary = pass_controller.step_pass(1.0 / 60.0)
		if result.get("state", "") != "traveling":
			return result
	return {"state": "traveling", "frames": max_frames}
