class_name DefenseController
extends RefCounted

var defense_config: DefenseConfig
var difficulty_config: DifficultyConfig
var court_config: CourtConfig
var assignments: Dictionary = {}
var steal_check_accumulator: float = 0.0


func setup_assignments(offense_players: Array[PlayerController], defense_players: Array[PlayerController]) -> void:
	assignments.clear()
	for defender in defense_players:
		var matched: PlayerController = offense_players.front()
		for offense in offense_players:
			if offense.get_position_role() == defender.get_position_role():
				matched = offense
				break
		assignments[defender] = matched


func update_defense(
	delta: float,
	offense_players: Array[PlayerController],
	defense_players: Array[PlayerController],
	ballhandler: PlayerController
) -> void:
	if assignments.is_empty():
		setup_assignments(offense_players, defense_players)
	var defense_scale: float = difficulty_config.get_defense_multiplier()
	for defender in defense_players:
		var assignment: PlayerController = assignments.get(defender, ballhandler)
		if assignment == null:
			defender.velocity = Vector2.ZERO
			continue
		var to_hoop: Vector2 = (court_config.hoop_position - assignment.world_position).normalized()
		var desired: Vector2 = assignment.world_position + to_hoop * defense_config.guard_distance
		var move_speed: float = (150.0 + float(defender.get_player_data().speed) * 1.8) * defense_scale
		if defender.world_position.distance_to(desired) <= defense_config.guard_deadband_radius:
			defender.move_toward_target_smooth(
				defender.world_position,
				move_speed / 320.0,
				delta,
				defense_config.guard_arrival_radius,
				defense_config.guard_stop_radius,
				defense_config.guard_acceleration,
				defense_config.guard_deceleration
			)
			continue
		defender.move_toward_target_smooth(
			desired,
			move_speed / 320.0,
			delta,
			defense_config.guard_arrival_radius,
			defense_config.guard_stop_radius,
			defense_config.guard_acceleration,
			defense_config.guard_deceleration
		)


func get_contest_level(shooter: PlayerController) -> float:
	var defender: PlayerController = get_assigned_defender(shooter)
	if defender == null:
		return 0.0
	var distance_value: float = defender.world_position.distance_to(shooter.world_position)
	if distance_value > defense_config.contest_radius:
		return 0.0
	return 1.0 - clampf(distance_value / defense_config.contest_radius, 0.0, 1.0)


func is_contested(shooter: PlayerController) -> bool:
	return get_contest_level(shooter) > 0.2


func can_block_shot(shooter: PlayerController, rng: GameRng, shot_family: String = "") -> bool:
	return get_blocking_defender(shooter, rng, shot_family) != null


func get_block_chance(shooter: PlayerController, defender: PlayerController, shot_family: String = "") -> float:
	if shooter == null or defender == null or defense_config == null:
		return 0.0
	var distance_value: float = defender.world_position.distance_to(shooter.world_position)
	if distance_value > defense_config.block_radius:
		return 0.0
	var defender_data: PlayerData = defender.get_player_data()
	if defender_data == null:
		return 0.0
	var chance: float = clampf((float(defender_data.block) / 100.0) * (1.0 - distance_value / defense_config.block_radius), 0.0, 0.4)
	if _is_dunk_family(shot_family):
		var shooter_data: PlayerData = shooter.get_player_data()
		var dunk_ratio: float = clampf(float(shooter_data.dunk if shooter_data != null else 0) / 100.0, 0.0, 1.0)
		chance *= lerpf(1.0, defense_config.dunk_block_chance_min_multiplier, dunk_ratio)
	return clampf(chance, 0.0, 0.4)


func get_blocking_defender(shooter: PlayerController, rng: GameRng, shot_family: String = "") -> PlayerController:
	var defender: PlayerController = get_assigned_defender(shooter)
	if defender == null:
		return null
	var chance: float = get_block_chance(shooter, defender, shot_family)
	return defender if rng.randf() < chance else null


func _is_dunk_family(shot_family: String) -> bool:
	return shot_family == "close_finish_dunk" or shot_family == "close_finish_side_dunk"


func should_trigger_pressure_turnover(
	ballhandler: PlayerController,
	delta: float,
	context: MatchContext,
	rng: GameRng
) -> bool:
	var defender: PlayerController = get_assigned_defender(ballhandler)
	if defender == null:
		return false
	if defender.world_position.distance_to(ballhandler.world_position) > defense_config.pressure_radius:
		steal_check_accumulator = 0.0
		context.ballhandler_stationary_time = 0.0
		return false
	if ballhandler.velocity.length() <= 18.0:
		context.ballhandler_stationary_time += delta
	else:
		context.ballhandler_stationary_time = 0.0
		steal_check_accumulator = 0.0
		return false
	if context.ballhandler_stationary_time < defense_config.stationary_turnover_time:
		return false
	steal_check_accumulator += delta
	if steal_check_accumulator < defense_config.steal_check_interval:
		return false
	steal_check_accumulator = 0.0
	var defender_data: PlayerData = defender.get_player_data()
	var ballhandler_data: PlayerData = ballhandler.get_player_data()
	var chance: float = 0.06 + maxf(float(defender_data.steal + defender_data.perimeter_defense - ballhandler_data.handle), 0.0) / 220.0
	return rng.randf() < clampf(chance, 0.02, 0.45)


func get_assigned_defender(offense_player: PlayerController) -> PlayerController:
	for defender in assignments.keys():
		if assignments[defender] == offense_player:
			return defender
	return null
