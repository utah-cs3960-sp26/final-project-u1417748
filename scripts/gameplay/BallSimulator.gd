class_name BallSimulator
extends RefCounted

static func build_ball_state(position_xy: Vector2, velocity_xy: Vector2, z_height: float, z_velocity: float, shot_value: int = 2) -> Dictionary:
	return {
		"position_xy": position_xy,
		"velocity_xy": velocity_xy,
		"z": z_height,
		"vz": z_velocity,
		"in_flight": true,
		"already_scored": false,
		"shot_value": shot_value,
		"last_collision": "",
		"was_blocked": false,
	}

static func advance_shot(state: Dictionary, delta: float, court_config: CourtConfig, physics_config: BallPhysicsConfig) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var last_position: Vector2 = state["position_xy"]
	var last_z: float = state["z"]
	state["position_xy"] += state["velocity_xy"] * delta
	state["z"] += state["vz"] * delta
	state["vz"] -= physics_config.gravity * delta
	var hoop_pos: Vector2 = court_config.get_hoop_world_position()
	var board_y: float = hoop_pos.y - court_config.backboard_offset
	if last_position.y > board_y and state["position_xy"].y <= board_y:
		if absf(state["position_xy"].x - hoop_pos.x) <= court_config.backboard_half_width + physics_config.ball_radius:
			if state["z"] >= court_config.backboard_bottom and state["z"] <= court_config.backboard_top:
				var velocity_xy: Vector2 = state["velocity_xy"]
				velocity_xy.y = absf(velocity_xy.y) * physics_config.backboard_bounce_damping
				velocity_xy.x *= 0.94
				state["velocity_xy"] = velocity_xy
				state["last_collision"] = "backboard"
				events.append({"type": "backboard", "position": state["position_xy"]})
	var rim_distance: float = state["position_xy"].distance_to(hoop_pos)
	if absf(state["z"] - court_config.rim_height) <= physics_config.collision_height_tolerance:
		if rim_distance <= court_config.hoop_radius + physics_config.ball_radius and rim_distance >= court_config.scoring_radius * 0.55:
			var normal: Vector2 = (state["position_xy"] - hoop_pos).normalized()
			if normal.length_squared() < 0.001:
				normal = Vector2(0.0, 1.0)
			state["velocity_xy"] = state["velocity_xy"].bounce(normal) * physics_config.rim_bounce_damping
			state["vz"] = maxf(state["vz"], 110.0)
			state["last_collision"] = "rim"
			events.append({"type": "rim", "position": state["position_xy"]})
	if not state["already_scored"]:
		if last_z > court_config.rim_height and state["z"] <= court_config.rim_height and state["vz"] < 0.0:
			if state["position_xy"].distance_to(hoop_pos) <= court_config.scoring_radius:
				state["already_scored"] = true
				events.append({"type": "score", "value": state["shot_value"], "clean": state["last_collision"] == ""})
	var playable_rect: Rect2 = court_config.get_playable_rect().grow(40.0)
	if not playable_rect.has_point(state["position_xy"]):
		state["in_flight"] = false
		events.append({"type": "out_of_bounds", "position": state["position_xy"]})
		return events
	if state["z"] <= 0.0:
		if absf(state["vz"]) > 70.0:
			state["z"] = 0.0
			state["vz"] = -state["vz"] * physics_config.floor_bounce_damping
			state["velocity_xy"] *= 0.82
			events.append({"type": "floor_bounce", "position": state["position_xy"]})
		else:
			state["z"] = 0.0
			state["vz"] = 0.0
			state["velocity_xy"] *= 0.5
			state["in_flight"] = false
			events.append({"type": "landed", "position": state["position_xy"]})
	return events

static func generate_preview_points(origin: Vector2, velocity_xy: Vector2, z_velocity: float, shot_value: int, court_config: CourtConfig, physics_config: BallPhysicsConfig) -> Array[Vector2]:
	var state: Dictionary = build_ball_state(origin, velocity_xy, 34.0, z_velocity, shot_value)
	var points: Array[Vector2] = []
	for _step: int in physics_config.preview_steps:
		advance_shot(state, physics_config.preview_step_seconds, court_config, physics_config)
		points.append(state["position_xy"] + Vector2(0.0, -state["z"] * 0.32))
		if not state["in_flight"]:
			break
	return points
