class_name OpponentSimController
extends RefCounted

var sim_config: OpponentSimConfig
var difficulty_config: DifficultyConfig


func run_possession(
	offense_team: TeamData,
	defense_team: TeamData,
	remaining_time: float,
	rng: GameRng
) -> Dictionary:
	var events: PackedStringArray = PackedStringArray()
	events.append("%s possession start" % offense_team.abbreviation)
	var time_consumed: float = minf(rng.randf_range(sim_config.possession_time_min, sim_config.possession_time_max), remaining_time)
	var turnover_chance: float = sim_config.turnover_chance / difficulty_config.get_defense_multiplier()
	if rng.randf() < turnover_chance:
		events.append("%s turnover" % offense_team.abbreviation)
		return {
			"events": events,
			"points_scored": 0,
			"time_consumed": time_consumed,
		}

	var shooter: PlayerData = _choose_shooter(offense_team.players, rng)
	var is_three: bool = rng.randf() < sim_config.three_point_attempt_rate
	events.append("%s %s creates attempt" % [offense_team.abbreviation, shooter.display_name])
	events.append("shot: %s" % ("3PT" if is_three else "2PT"))
	var make_chance: float = _get_make_chance(shooter, defense_team, is_three)
	if rng.randf() < make_chance:
		var points: int = 3 if is_three else 2
		events.append("made %s by %s" % ["3PT" if is_three else "2PT", shooter.display_name])
		events.append("clock -%0.1fs" % time_consumed)
		return {
			"events": events,
			"points_scored": points,
			"time_consumed": time_consumed,
		}

	events.append("miss")
	if rng.randf() < sim_config.offensive_rebound_rate * difficulty_config.get_sim_efficiency():
		var rebounder: PlayerData = _choose_rebounder(offense_team.players, rng)
		events.append("offensive rebound by %s" % rebounder.display_name)
		events.append("kickout")
		var second_time: float = minf(rng.randf_range(sim_config.second_chance_time_min, sim_config.second_chance_time_max), maxf(remaining_time - time_consumed, 0.0))
		time_consumed += second_time
		if rng.randf() < make_chance * 0.82:
			var second_points: int = 2 if rng.randf() < 0.72 else 3
			events.append("made %dPT by %s" % [second_points, rebounder.display_name])
			events.append("clock -%0.1fs" % time_consumed)
			return {
				"events": events,
				"points_scored": second_points,
				"time_consumed": time_consumed,
			}
		events.append("second chance miss")

	events.append("clock -%0.1fs" % time_consumed)
	return {
		"events": events,
		"points_scored": 0,
		"time_consumed": time_consumed,
	}


func _choose_shooter(players: Array[PlayerData], rng: GameRng) -> PlayerData:
	var weights: Array[float] = []
	for player in players:
		weights.append(maxf(float(player.sim_offense), 1.0))
	return players[rng.rand_weighted(weights)]


func _choose_rebounder(players: Array[PlayerData], rng: GameRng) -> PlayerData:
	var weights: Array[float] = []
	for player in players:
		weights.append(maxf(float(player.rebound), 1.0))
	return players[rng.rand_weighted(weights)]


func _get_make_chance(shooter: PlayerData, defense_team: TeamData, is_three: bool) -> float:
	var defense_total: float = 0.0
	for defender in defense_team.players:
		defense_total += float(defender.perimeter_defense)
	var defense_average: float = defense_total / maxf(float(defense_team.players.size()), 1.0)
	var base: float = 0.48 + (float(shooter.sim_offense + shooter.shooting) * 0.5 - defense_average) / 240.0
	if is_three:
		base -= 0.08
	base += sim_config.make_bias
	base *= difficulty_config.get_sim_efficiency()
	return clampf(base, 0.18, 0.72)
