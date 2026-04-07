class_name ShotController
extends RefCounted

static func drag_to_power_ratio(drag_length: float, config: ShotTimingConfig) -> float:
	var normalized: float = inverse_lerp(config.min_shot_drag_distance, config.max_shot_drag_distance, drag_length)
	normalized = clampf(normalized, 0.0, 1.0)
	return pow(normalized, config.power_curve)

static func get_release_quality(hold_time: float, shooter_consistency: float, contest_amount: float, config: ShotTimingConfig) -> Dictionary:
	var consistency_bonus: float = remap(shooter_consistency, 0.0, 100.0, -0.05, 0.12)
	var contest_penalty: float = contest_amount * 0.18
	var center: float = config.base_center_time + contest_penalty * 0.16 - consistency_bonus * 0.1
	var width: float = maxf(0.18, config.base_window_width + consistency_bonus - contest_penalty)
	var distance_from_center: float = absf(hold_time - center)
	var normalized_error: float = clampf(distance_from_center / (width * 0.5), 0.0, 1.5)
	var label: String = "red"
	var color: Color = Color("#f25f5c")
	if normalized_error <= config.green_fraction:
		label = "green"
		color = Color("#6cff82")
	elif normalized_error <= config.yellow_fraction:
		label = "yellow"
		color = Color("#ffd166")
	return {
		"center": center,
		"width": width,
		"normalized_error": normalized_error,
		"label": label,
		"color": color,
	}

static func release_endpoint_pass_target(release_point: Vector2, players: Array[PlayerController], controlled_index: int, catch_radius: float) -> int:
	for player: PlayerController in players:
		if player.player_index == controlled_index:
			continue
		if player.global_position.distance_to(release_point) <= catch_radius:
			return player.player_index
	return -1

static func build_launch(ballhandler_pos: Vector2, drag_vector: Vector2, shooter: PlayerController, contest_amount: float, quality: Dictionary, timing_config: ShotTimingConfig, physics_config: BallPhysicsConfig, rng: RandomNumberGenerator) -> Dictionary:
	var release_direction: Vector2 = -drag_vector.normalized()
	if release_direction.length_squared() < 0.001:
		release_direction = Vector2.UP
	var power_ratio: float = drag_to_power_ratio(drag_vector.length(), timing_config)
	var shot_stability: float = (shooter.get_shooting_score() + shooter.get_release_consistency()) * 0.5 / 100.0
	var error_scalar: float = clampf(quality["normalized_error"] / maxf(timing_config.yellow_fraction, 0.01), 0.0, 1.0)
	var contest_scalar: float = clampf(contest_amount, 0.0, 1.0)
	var angle_error_max: float = timing_config.max_angle_error_degrees * (1.15 - shot_stability * 0.45) * (1.0 + contest_scalar * 0.6)
	var power_error_max: float = timing_config.max_power_error_fraction * (1.1 - shot_stability * 0.35) * (1.0 + contest_scalar * 0.55)
	var angle_error: float = deg_to_rad(rng.randf_range(-angle_error_max, angle_error_max) * error_scalar)
	var power_error: float = rng.randf_range(-power_error_max, power_error_max) * error_scalar
	release_direction = release_direction.rotated(angle_error)
	var xy_speed: float = lerpf(physics_config.shot_min_speed, physics_config.shot_max_speed, clampf(power_ratio + power_error, 0.0, 1.0))
	var z_speed: float = lerpf(physics_config.shot_min_vz, physics_config.shot_max_vz, clampf(power_ratio + power_error * 0.6, 0.0, 1.0))
	return {
		"velocity_xy": release_direction * xy_speed,
		"vz": z_speed,
		"power_ratio": power_ratio,
		"release_direction": release_direction,
		"angle_error": angle_error,
		"power_error": power_error,
		"origin": ballhandler_pos,
	}
