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
		var to_hoop: Vector2 = (court_config.hoop_position - assignment.world_position).normalized()
		var desired: Vector2 = assignment.world_position + to_hoop * defense_config.guard_distance
		var move_speed: float = (150.0 + float(defender.get_player_data().speed) * 1.8) * defense_scale
		defender.move_toward_target(desired, move_speed / 320.0, delta)


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


func can_block_shot(shooter: PlayerController, rng: GameRng) -> bool:
	return get_blocking_defender(shooter, rng) != null


func get_blocking_defender(shooter: PlayerController, rng: GameRng) -> PlayerController:
	var defender: PlayerController = get_assigned_defender(shooter)
	if defender == null:
		return null
	var distance_value: float = defender.world_position.distance_to(shooter.world_position)
	if distance_value > defense_config.block_radius:
		return null
	var data: PlayerData = defender.get_player_data()
	var chance: float = clampf((float(data.block) / 100.0) * (1.0 - distance_value / defense_config.block_radius), 0.0, 0.4)
	return defender if rng.randf() < chance else null


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
