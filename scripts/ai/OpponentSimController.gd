class_name OpponentSimController
extends RefCounted

static func simulate_possession(offense_team: TeamData, defense_team: TeamData, config: OpponentSimConfig, difficulty_profile: Dictionary, remaining_clock: float, rng: RandomNumberGenerator) -> Dictionary:
	var events: Array[String] = []
	var score_delta: int = 0
	var time_used: float = minf(remaining_clock, rng.randf_range(config.possession_min_seconds, config.possession_max_seconds))
	var sim_efficiency: float = float(difficulty_profile.get("sim_efficiency", 1.0))
	events.append("AWY possession start")
	if rng.randf() <= config.turnover_base_chance / sim_efficiency:
		events.append("turnover")
		return {"time_used": time_used, "score_delta": 0, "events": events, "result": "turnover"}
	var shooter_index: int = _weighted_player_index(offense_team.players, rng)
	var shooter: PlayerData = offense_team.players[shooter_index]
	var attempt_three: bool = rng.randf() <= config.three_point_tendency
	var defense_average: float = _average_defense(defense_team.players)
	var base_make: float = remap(float(shooter.sim_offense), 0.0, 100.0, 0.28, 0.62)
	if attempt_three:
		base_make -= 0.08
	base_make += (sim_efficiency - 1.0) * 0.12
	base_make -= remap(defense_average, 0.0, 100.0, 0.03, 0.17)
	base_make = clampf(base_make, 0.14, 0.68)
	events.append("%s creates attempt" % shooter.display_name)
	events.append("shot: %s" % ("3PT" if attempt_three else "2PT"))
	if rng.randf() <= base_make:
		score_delta = 3 if attempt_three else 2
		events.append("made %s by %s" % ["3PT" if attempt_three else "2PT", shooter.display_name])
		return {"time_used": time_used, "score_delta": score_delta, "events": events, "result": "make"}
	events.append("miss")
	var offense_rebound_chance: float = clampf(config.offensive_rebound_base + (_average_rebound(offense_team.players) - _average_rebound(defense_team.players)) / 300.0, 0.10, 0.38)
	for loop_index: int in range(config.max_second_chance_loops):
		if rng.randf() > offense_rebound_chance:
			break
		var rebounder: PlayerData = offense_team.players[rng.randi_range(0, offense_team.players.size() - 1)]
		events.append("offensive rebound by %s" % rebounder.display_name)
		var extra_time: float = minf(remaining_clock - time_used, rng.randf_range(config.second_chance_min_seconds, config.second_chance_max_seconds))
		time_used += maxf(extra_time, 0.0)
		if rng.randf() <= base_make + 0.08:
			score_delta = 2 if rng.randf() < 0.66 else 3
			events.append("made %s by %s" % ["3PT" if score_delta == 3 else "2PT", rebounder.display_name])
			return {"time_used": minf(time_used, remaining_clock), "score_delta": score_delta, "events": events, "result": "second_chance_make"}
		events.append("kickout miss")
	return {"time_used": minf(time_used, remaining_clock), "score_delta": 0, "events": events, "result": "miss"}

static func _weighted_player_index(players: Array[PlayerData], rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for player: PlayerData in players:
		total += maxf(10.0, float(player.sim_offense))
	var pick: float = rng.randf() * total
	var running: float = 0.0
	for index: int in range(players.size()):
		running += maxf(10.0, float(players[index].sim_offense))
		if running >= pick:
			return index
	return players.size() - 1

static func _average_defense(players: Array[PlayerData]) -> float:
	var total: float = 0.0
	for player: PlayerData in players:
		total += (player.perimeter_defense + player.steal + player.block) / 3.0
	return total / maxf(1.0, float(players.size()))

static func _average_rebound(players: Array[PlayerData]) -> float:
	var total: float = 0.0
	for player: PlayerData in players:
		total += player.rebound
	return total / maxf(1.0, float(players.size()))
