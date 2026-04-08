class_name PassController
extends RefCounted

var pass_config: PassConfig
var court_config: CourtConfig
var active_pass: Dictionary = {}


func start_pass(
	from_position: Vector2,
	target_player: PlayerController,
	defenders: Array[PlayerController],
	rng: GameRng
) -> Dictionary:
	var target_position: Vector2 = target_player.world_position
	var interception: Dictionary = _find_interceptor(from_position, target_position, defenders, rng)
	var final_receiver: PlayerController = target_player
	var end_position: Vector2 = target_position
	if not interception.is_empty():
		final_receiver = interception.player
		end_position = interception.player.world_position
	var distance_value: float = from_position.distance_to(end_position)
	active_pass = {
		"start": from_position,
		"end": end_position,
		"receiver": final_receiver,
		"distance": distance_value,
		"elapsed": 0.0,
		"duration": distance_value / maxf(pass_config.pass_speed, 1.0),
		"intercepted": not interception.is_empty(),
	}
	return active_pass


func step_pass(delta: float) -> Dictionary:
	if active_pass.is_empty():
		return {"state": "idle"}
	active_pass.elapsed += delta
	var progress: float = clampf(active_pass.elapsed / maxf(active_pass.duration, 0.01), 0.0, 1.0)
	var world_position: Vector2 = active_pass.start.lerp(active_pass.end, progress)
	if not court_config.is_in_bounds(world_position):
		var out_result: Dictionary = {"state": "out_of_bounds", "position": world_position}
		active_pass = {}
		return out_result
	if progress >= 1.0:
		var caught_result: Dictionary = {
			"state": "complete",
			"receiver": active_pass.receiver,
			"intercepted": active_pass.intercepted,
			"position": world_position,
		}
		active_pass = {}
		return caught_result
	return {
		"state": "traveling",
		"position": world_position,
	}


func get_intercept_corridor() -> PackedVector2Array:
	if active_pass.is_empty():
		return PackedVector2Array()
	return PackedVector2Array([active_pass.start, active_pass.end])


func _find_interceptor(
	start_position: Vector2,
	target_position: Vector2,
	defenders: Array[PlayerController],
	rng: GameRng
) -> Dictionary:
	var distance_value: float = start_position.distance_to(target_position)
	var long_bonus: float = pass_config.long_pass_bonus if distance_value >= pass_config.long_pass_threshold else 0.0
	var cross_court_bonus: float = pass_config.cross_court_bonus if absf(start_position.x - target_position.x) >= pass_config.cross_court_x_delta else 0.0
	var best_candidate: Dictionary = {}
	var best_roll_target: float = 0.0

	for defender in defenders:
		var lane_distance: float = Geometry2D.get_closest_point_to_segment(defender.world_position, start_position, target_position).distance_to(defender.world_position)
		if lane_distance > pass_config.catch_radius * 1.3:
			continue
		var defender_data: PlayerData = defender.get_player_data()
		var lane_factor: float = 1.0 - clampf(lane_distance / maxf(pass_config.catch_radius * 1.3, 1.0), 0.0, 1.0)
		var chance: float = pass_config.base_interception_chance + long_bonus + cross_court_bonus + lane_factor * pass_config.lane_bonus
		chance *= 0.75 + float(defender_data.steal + defender_data.perimeter_defense) / 200.0
		if chance > best_roll_target and rng.randf() < chance:
			best_roll_target = chance
			best_candidate = {"player": defender, "chance": chance}
	return best_candidate
