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
		var turnover_player: PlayerData = _choose_visual_player(offense_team.players, "%s_turnover_%0.2f" % [offense_team.abbreviation, time_consumed])
		events.append("%s turnover" % offense_team.abbreviation)
		return {
			"events": events,
			"points_scored": 0,
			"time_consumed": time_consumed,
			"visual_steps": _build_visual_steps(offense_team, turnover_player, "turnover", 0, false, [], events, time_consumed),
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
			"visual_steps": _build_visual_steps(offense_team, shooter, "made_three" if is_three else "made_two", points, false, [], events, time_consumed),
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
				"visual_steps": _build_visual_steps(offense_team, rebounder, "second_chance_three" if second_points == 3 else "second_chance_two", second_points, true, [shooter, rebounder], events, time_consumed),
			}
		events.append("second chance miss")

	events.append("clock -%0.1fs" % time_consumed)
	return {
		"events": events,
		"points_scored": 0,
		"time_consumed": time_consumed,
		"visual_steps": _build_visual_steps(offense_team, shooter, "miss", 0, false, [], events, time_consumed),
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


func _build_visual_steps(
	offense_team: TeamData,
	final_player: PlayerData,
	final_kind: String,
	points: int,
	prefer_second_chance: bool,
	required_setup_players: Array[PlayerData],
	events: PackedStringArray,
	time_consumed: float
) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var seed_text: String = "%s|%s|%d|%0.2f" % [offense_team.abbreviation, "|".join(events), points, time_consumed]
	var total_steps: int = _get_visual_step_count(seed_text, prefer_second_chance, required_setup_players.size())
	var setup_count: int = maxi(total_steps - 1, 0)
	var required_setup_count: int = mini(required_setup_players.size(), setup_count)
	for index in required_setup_count:
		var setup_player: PlayerData = required_setup_players[index]
		var required_kind: String = "missed_jumper" if index == 0 else "offensive_board"
		steps.append(_create_visual_step(required_kind, setup_player, 0, false))
	var remaining_setup_count: int = setup_count - required_setup_count
	for index in remaining_setup_count:
		var setup_seed: String = "%s|setup|%d" % [seed_text, index]
		var setup_actor: PlayerData = _choose_visual_player(offense_team.players, setup_seed)
		var setup_kind: String = _choose_setup_kind(setup_seed)
		steps.append(_create_visual_step(setup_kind, setup_actor, 0, false))
	steps.append(_create_visual_step(_choose_final_kind(final_kind, seed_text), final_player, points, true))
	if points > 0:
		var prior_step: Dictionary = steps[steps.size() - 1]
		prior_step["is_final"] = false
		var score_step: Dictionary = {
			"text": "%d points!" % points,
			"kind": "score",
			"player": prior_step.get("player", ""),
			"points": points,
			"is_final": true,
			"player_id": prior_step.get("player_id", ""),
			"player_role": prior_step.get("player_role", ""),
			"actor_team": "away",
		}
		steps.append(score_step)
	return steps


func _get_visual_step_count(seed_text: String, prefer_second_chance: bool, required_setup_count: int) -> int:
	var min_count: int = clampi(sim_config.visual_step_min, 1, 4)
	var max_count: int = clampi(sim_config.visual_step_max, min_count, 4)
	var required_count: int = clampi(required_setup_count + 1, min_count, max_count)
	if prefer_second_chance:
		min_count = maxi(min_count, required_count)
	return min_count + _hash_to_index(seed_text, max_count - min_count + 1)


func _choose_setup_kind(seed_text: String) -> String:
	var setup_kinds: PackedStringArray = PackedStringArray([
		"pass",
		"drive",
		"crossover",
		"kickout",
		"pick_and_roll",
	])
	return setup_kinds[_hash_to_index(seed_text, setup_kinds.size())]


func _choose_final_kind(result_kind: String, seed_text: String) -> String:
	match result_kind:
		"made_three":
			var three_kinds: PackedStringArray = PackedStringArray(["corner_three", "jump_shot"])
			return three_kinds[_hash_to_index(seed_text, three_kinds.size())]
		"made_two":
			var two_kinds: PackedStringArray = PackedStringArray(["jump_shot", "layup", "alley_oop", "dunk", "breakaway_layup"])
			return two_kinds[_hash_to_index(seed_text, two_kinds.size())]
		"second_chance_three":
			var second_three_kinds: PackedStringArray = PackedStringArray(["corner_three", "jump_shot"])
			return second_three_kinds[_hash_to_index(seed_text, second_three_kinds.size())]
		"second_chance_two":
			var second_two_kinds: PackedStringArray = PackedStringArray(["putback", "layup", "dunk"])
			return second_two_kinds[_hash_to_index(seed_text, second_two_kinds.size())]
		"turnover":
			var turnover_kinds: PackedStringArray = PackedStringArray(["turnover", "steal"])
			return turnover_kinds[_hash_to_index(seed_text, turnover_kinds.size())]
		"miss":
			var miss_kinds: PackedStringArray = PackedStringArray(["missed_jumper", "blocked_shot", "defensive_board"])
			return miss_kinds[_hash_to_index(seed_text, miss_kinds.size())]
	return "turnover"


func _choose_visual_player(players: Array[PlayerData], seed_text: String) -> PlayerData:
	if players.is_empty():
		return null
	return players[_hash_to_index(seed_text, players.size())]


func _hash_to_index(seed_text: String, size: int) -> int:
	if size <= 0:
		return 0
	return absi(seed_text.hash()) % size


func _create_visual_step(kind: String, player: PlayerData, points: int, is_final: bool) -> Dictionary:
	var player_name: String = _get_visual_step_player_name(kind, player)
	var text_value: String = _get_visual_step_text(kind, player_name)
	var actor_team: String = _get_actor_team(kind)
	var player_id_value: String = _get_player_id_value(player, actor_team, kind)
	var player_role_value: String = _get_player_role_value(player, kind)
	return {
		"text": text_value,
		"kind": kind,
		"player": player_name,
		"points": points,
		"is_final": is_final,
		"player_id": player_id_value,
		"player_role": player_role_value,
		"actor_team": actor_team,
	}


func _get_visual_step_player_name(kind: String, player: PlayerData) -> String:
	if player != null:
		return player.display_name
	if kind == "defensive_board":
		return "HOM"
	return "AWY"


func _get_actor_team(kind: String) -> String:
	if kind == "defensive_board" or kind == "steal" or kind == "blocked_shot":
		return "home"
	return "away"


func _get_player_id_value(player: PlayerData, actor_team: String, kind: String) -> String:
	if actor_team == "home":
		var role_suffix: String = player.role.to_lower() if player != null and player.role != "" else kind
		return "hom_%s" % role_suffix
	if player != null and player.player_id != "":
		return player.player_id
	return "awy_%s" % kind


func _get_player_role_value(player: PlayerData, kind: String) -> String:
	if player != null and player.role != "":
		return player.role
	if kind == "defensive_board":
		return "C"
	return "AWY"


func _get_visual_step_text(kind: String, player_name: String) -> String:
	match kind:
		"pass":
			return "Pass to %s" % player_name
		"drive":
			return "Drive by %s" % player_name
		"crossover":
			return "Crossover from %s" % player_name
		"kickout":
			return "Kickout to %s" % player_name
		"pick_and_roll":
			return "Pick-and-roll to %s" % player_name
		"jump_shot":
			return "Jump shot from %s" % player_name
		"corner_three":
			return "Corner three from %s" % player_name
		"layup":
			return "Layup from %s" % player_name
		"alley_oop":
			return "Alley-oop from %s" % player_name
		"dunk":
			return "Dunk from %s" % player_name
		"putback":
			return "Putback from %s" % player_name
		"breakaway_layup":
			return "Breakaway layup from %s" % player_name
		"turnover":
			return "Turnover from %s" % player_name
		"steal":
			return "Steal from %s" % player_name
		"missed_jumper":
			return "Missed jumper from %s" % player_name
		"blocked_shot":
			return "Blocked shot from %s" % player_name
		"defensive_board":
			return "Defensive board by HOM"
		"offensive_board":
			return "Offensive board by %s" % player_name
	return "Turnover from %s" % player_name
