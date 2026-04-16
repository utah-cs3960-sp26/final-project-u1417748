class_name OpponentSimPresentation
extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/Player.tscn")
const BALL_SCENE: PackedScene = preload("res://scenes/entities/Ball.tscn")
const PLAYER_VISUAL_REQUEST_SCRIPT = preload("res://scripts/entities/PlayerVisualRequest.gd")
const HOME_ROLES: Array[String] = ["PG", "LW", "RW", "LC", "RC"]
const AWAY_ROLES: Array[String] = ["PG", "LW", "RW", "LC", "RC"]
const DEFAULT_CAMERA_ANCHOR_WORLD: Vector2 = Vector2.ZERO

var home_team: TeamData
var away_team: TeamData
var court_config: CourtConfig
var court_projection: CourtProjection
var player_animation_config: PlayerAnimationConfig

var _away_ghosts: Dictionary = {}
var _home_ghosts: Dictionary = {}
var _away_ordered: Array[PlayerController] = []
var _home_ordered: Array[PlayerController] = []
var _ghost_ball: BallController
var _ghost_ball_visible: bool = false
var _active: bool = false
var _current_step: Dictionary = {}
var _current_kind: String = ""
var _current_actor_id: String = ""
var _current_actor_role: String = ""
var _current_actor_team: String = ""
var _ball_owner_team: String = ""
var _ball_owner_role: String = ""
var _camera_anchor_world: Vector2 = DEFAULT_CAMERA_ANCHOR_WORLD
var _last_layout_delta: float = 0.0


func _ready() -> void:
	_build_runtime_children()
	hide_presentation()


func setup(
	home_team_value: TeamData,
	away_team_value: TeamData,
	court_config_value: CourtConfig,
	court_projection_value: CourtProjection,
	player_animation_config_value: PlayerAnimationConfig
) -> void:
	home_team = home_team_value
	away_team = away_team_value
	court_config = court_config_value
	court_projection = court_projection_value
	player_animation_config = player_animation_config_value
	_build_runtime_children()
	_sync_team_rosters()
	_sync_visual_config()
	_sync_visibility()


func show_step(step: Dictionary) -> void:
	_build_runtime_children()
	_current_step = step.duplicate(true)
	_current_kind = str(step.get("kind", ""))
	_current_actor_id = str(step.get("player_id", ""))
	_current_actor_role = str(step.get("player_role", ""))
	_current_actor_team = str(step.get("actor_team", ""))
	_resolve_actor_identity(step)
	_ball_owner_team = str(step.get("ball_owner_team", _current_actor_team))
	_ball_owner_role = str(step.get("ball_owner_role", _current_actor_role))
	_active = true
	_sync_team_rosters()
	_apply_step_layout()
	_sync_visual_config()
	_sync_visibility()


func hide_presentation() -> void:
	_active = false
	_current_step = {}
	_current_kind = ""
	_current_actor_id = ""
	_current_actor_role = ""
	_current_actor_team = ""
	_ball_owner_team = ""
	_ball_owner_role = ""
	_camera_anchor_world = DEFAULT_CAMERA_ANCHOR_WORLD
	_ghost_ball_visible = false
	_sync_visibility()


func sync_projection(delta: float) -> void:
	_last_layout_delta = delta
	if not _active:
		return
	if court_projection == null or court_config == null:
		return
	_apply_step_layout()
	_sync_visual_config()


func get_camera_anchor_world() -> Vector2:
	return _camera_anchor_world


func get_visual_snapshot() -> Dictionary:
	var away_positions: Dictionary = _build_positions_snapshot(_away_ghosts)
	var home_positions: Dictionary = _build_positions_snapshot(_home_ghosts)
	var ball_position: Vector2 = _get_ball_world_position(_ball_owner_team, _ball_owner_role) if _ball_owner_role != "" else Vector2.INF
	return {
		"active": _active,
		"current_kind": _current_kind,
		"actor_role": _current_actor_role,
		"actor_team": _current_actor_team,
		"ball_owner_team": _ball_owner_team,
		"ball_owner_role": _ball_owner_role,
		"camera_anchor_world": _camera_anchor_world,
		"away_positions_by_role": away_positions,
		"home_positions_by_role": home_positions,
		"away_positions": away_positions.values(),
		"home_positions": home_positions.values(),
		"ghost_positions": _build_flat_position_snapshot(away_positions, home_positions),
		"actor_position": _get_ball_world_position(_current_actor_team, _current_actor_role),
		"ball_position": ball_position,
		"ball_visible": _ghost_ball_visible and _ghost_ball != null and _ghost_ball.is_ball_visible(),
		"presentation_visible": visible,
	}


func _build_runtime_children() -> void:
	if _ghost_ball == null:
		_ghost_ball = BALL_SCENE.instantiate() as BallController
		_ghost_ball.name = "OpponentSimGhostBall"
		add_child(_ghost_ball)
		if _ghost_ball.has_method("set_ball_visible"):
			_ghost_ball.call("set_ball_visible", false)
	for role in AWAY_ROLES:
		_ensure_ghost(role, true)
	for role in HOME_ROLES:
		_ensure_ghost(role, false)


func _sync_visibility() -> void:
	visible = _active
	if _ghost_ball != null:
		_ghost_ball.call("set_ball_visible", _active and _ghost_ball_visible)
	for player in _away_ghosts.values():
		if player != null:
			player.visible = _active
	for player in _home_ghosts.values():
		if player != null:
			player.visible = _active


func _ensure_ghost(role: String, is_away: bool) -> PlayerController:
	var ghost_map: Dictionary = _away_ghosts if is_away else _home_ghosts
	if ghost_map.has(role):
		return ghost_map[role] as PlayerController
	var ghost: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	ghost.name = "%sGhost_%s" % ["Away" if is_away else "Home", role]
	add_child(ghost)
	ghost_map[role] = ghost
	if is_away:
		_away_ordered.append(ghost)
	else:
		_home_ordered.append(ghost)
	return ghost


func _sync_team_rosters() -> void:
	if away_team != null:
		for role in AWAY_ROLES:
			var away_player: PlayerController = _away_ghosts.get(role, null) as PlayerController
			if away_player == null:
				continue
			var away_data: PlayerData = away_team.get_player_by_role(role)
			if away_data != null:
				away_player.setup(away_data, false, away_team.primary_color, player_animation_config)
	if home_team != null:
		for role in HOME_ROLES:
			var home_player: PlayerController = _home_ghosts.get(role, null) as PlayerController
			if home_player == null:
				continue
			var home_data: PlayerData = home_team.get_player_by_role(role)
			if home_data != null:
				home_player.setup(home_data, true, home_team.primary_color, player_animation_config)


func _sync_visual_config() -> void:
	if court_projection == null or court_config == null:
		return
	for player in _away_ghosts.values():
		_sync_player_visual(player as PlayerController, true)
	for player in _home_ghosts.values():
		_sync_player_visual(player as PlayerController, false)
	_sync_ball_visual()


func _sync_player_visual(player: PlayerController, is_away: bool) -> void:
	if player == null:
		return
	var world_position: Vector2 = player.world_position
	var ground_anchor: Vector2 = court_projection.world_to_screen_ground(world_position)
	var shadow_offset: Vector2 = court_projection.shadow_anchor(world_position) - ground_anchor
	player.apply_projection(
		ground_anchor,
		court_projection.actor_scale(world_position),
		shadow_offset,
		court_projection.shadow_scale(world_position),
		court_projection.depth_key(world_position)
	)
	var request := _build_visual_request(player, is_away)
	player.sync_visual_state(request, _last_layout_delta)
	player.visible = _active


func _sync_ball_visual() -> void:
	if _ghost_ball == null or court_projection == null:
		return
	if not _ghost_ball_visible:
		_ghost_ball.call("set_ball_visible", false)
		return
	var owner_role: String = _ball_owner_role if _ball_owner_role != "" else _current_actor_role
	var owner_team: String = _ball_owner_team if _ball_owner_team != "" else _current_actor_team
	var owner_player: PlayerController = _get_player(owner_team, owner_role)
	var ball_world: Vector2 = _get_ball_world_position(owner_team, owner_role)
	var ball_z: float = 0.0
	if owner_player != null:
		ball_world = owner_player.world_position
	var projection_data: Dictionary = {
		"ground_anchor": court_projection.world_to_screen_ground(ball_world),
		"ball_anchor": court_projection.world_to_screen(ball_world, ball_z) + Vector2(0.0, -8.0),
		"shadow_anchor": court_projection.shadow_anchor(ball_world),
		"ball_radius": 14.0,
		"shadow_scale": court_projection.shadow_scale(ball_world, ball_z),
		"depth_key": court_projection.depth_key(ball_world, ball_z),
	}
	_ghost_ball.call("set_ball_visible", _active)
	_ghost_ball.sync_visual(ball_world, ball_z, projection_data)


func _apply_step_layout() -> void:
	if court_config == null:
		return
	var formation: Dictionary = _resolve_step_formation()
	_camera_anchor_world = formation.get("camera_anchor_world", DEFAULT_CAMERA_ANCHOR_WORLD)
	var away_positions: Dictionary = formation.get("away_positions", {})
	var home_positions: Dictionary = formation.get("home_positions", {})
	_apply_positions_to_team(_away_ghosts, away_positions, true)
	_apply_positions_to_team(_home_ghosts, home_positions, false)
	_apply_ball_owner_from_step()
	_sync_ball_visibility_flag()


func _apply_positions_to_team(ghosts_by_role: Dictionary, positions_by_role: Dictionary, is_away: bool) -> void:
	for role in ghosts_by_role.keys():
		var ghost: PlayerController = ghosts_by_role.get(role, null) as PlayerController
		if ghost == null:
			continue
		var position_xy: Vector2 = positions_by_role.get(role, _default_role_position(role, is_away))
		ghost.world_position = _clamp_to_bottom_half(position_xy)
		ghost.velocity = Vector2.ZERO
		ghost.set_controlled(false)
		if is_away:
			ghost.set_has_ball(role == _ball_owner_role and _is_away_team_key(_ball_owner_team))
		else:
			ghost.set_has_ball(role == _ball_owner_role and _is_home_team_key(_ball_owner_team))


func _apply_ball_owner_from_step() -> void:
	var actor_role: String = _current_actor_role
	var actor_team: String = _current_actor_team
	if actor_team == "":
		actor_team = "away"
	if actor_role == "":
		actor_role = "PG"
	if _current_kind in ["steal", "blocked_shot", "defensive_board"]:
		_ball_owner_team = "home"
		_ball_owner_role = actor_role
		_ghost_ball_visible = true
		return
	if _current_kind in ["turnover"]:
		_ball_owner_team = ""
		_ball_owner_role = ""
		_ghost_ball_visible = false
		return
	_ball_owner_team = actor_team
	_ball_owner_role = actor_role
	_ghost_ball_visible = true


func _sync_ball_visibility_flag() -> void:
	if _ghost_ball == null:
		return
	_ghost_ball_visible = _ghost_ball_visible and _active
	_ghost_ball.call("set_ball_visible", _ghost_ball_visible)


func _resolve_step_formation() -> Dictionary:
	var actor_role: String = _current_actor_role if _current_actor_role != "" else "PG"
	var actor_team: String = _current_actor_team if _current_actor_team != "" else "away"
	var actor_world: Vector2 = _default_role_position(actor_role, _is_away_team_key(actor_team))
	var camera_anchor: Vector2 = actor_world
	var away_positions: Dictionary = _build_base_away_positions()
	var home_positions: Dictionary = _build_base_home_positions()
	match _current_kind:
		"pass", "drive", "crossover", "kickout", "pick_and_roll":
			away_positions = _build_spacing_away_positions(actor_role, actor_world)
			home_positions = _build_pressure_home_positions(actor_world)
		"jump_shot", "corner_three":
			away_positions = _build_shot_away_positions(actor_role, actor_world)
			home_positions = _build_shot_home_positions(actor_world)
		"layup", "alley_oop", "dunk", "putback", "breakaway_layup":
			actor_world = _lane_attack_position(actor_role, _current_kind)
			away_positions = _build_finish_away_positions(actor_role, actor_world)
			home_positions = _build_finish_home_positions(actor_world)
			camera_anchor = actor_world
		"turnover":
			away_positions = _build_turnover_away_positions(actor_role)
			home_positions = _build_turnover_home_positions(actor_role)
		"steal", "blocked_shot", "defensive_board":
			away_positions = _build_pressure_away_positions(actor_role)
			home_positions = _build_recovery_home_positions(actor_role)
			camera_anchor = _default_role_position(actor_role, false)
		_:
			away_positions = _build_base_away_positions()
			home_positions = _build_base_home_positions()
	return {
		"away_positions": away_positions,
		"home_positions": home_positions,
		"camera_anchor_world": _clamp_to_bottom_half(camera_anchor),
	}


func _build_base_away_positions() -> Dictionary:
	return {
		"PG": _court_point(0.50, 0.76),
		"LW": _court_point(0.34, 0.68),
		"RW": _court_point(0.66, 0.68),
		"LC": _court_point(0.20, 0.90),
		"RC": _court_point(0.80, 0.90),
	}


func _build_base_home_positions() -> Dictionary:
	return {
		"PG": _court_point(0.50, 0.84),
		"LW": _court_point(0.40, 0.74),
		"RW": _court_point(0.60, 0.74),
		"LC": _court_point(0.28, 0.92),
		"RC": _court_point(0.72, 0.92),
	}


func _build_spacing_away_positions(actor_role: String, actor_world: Vector2) -> Dictionary:
	var positions: Dictionary = _build_base_away_positions()
	positions[actor_role] = actor_world
	return positions


func _build_shot_away_positions(actor_role: String, actor_world: Vector2) -> Dictionary:
	var positions: Dictionary = _build_base_away_positions()
	positions["PG"] = _court_point(0.50, 0.78)
	positions["LW"] = _court_point(0.36, 0.66)
	positions["RW"] = _court_point(0.64, 0.66)
	positions["LC"] = _court_point(0.22, 0.88)
	positions["RC"] = _court_point(0.78, 0.88)
	positions[actor_role] = actor_world
	return positions


func _build_finish_away_positions(actor_role: String, actor_world: Vector2) -> Dictionary:
	var positions: Dictionary = _build_base_away_positions()
	positions["PG"] = _court_point(0.50, 0.82)
	positions["LW"] = _court_point(0.36, 0.76)
	positions["RW"] = _court_point(0.64, 0.76)
	positions["LC"] = _court_point(0.28, 0.92)
	positions["RC"] = _court_point(0.72, 0.92)
	positions[actor_role] = actor_world
	return positions


func _build_turnover_away_positions(actor_role: String) -> Dictionary:
	var positions: Dictionary = _build_base_away_positions()
	positions["PG"] = _court_point(0.46, 0.74)
	positions["LW"] = _court_point(0.32, 0.68)
	positions["RW"] = _court_point(0.68, 0.68)
	positions["LC"] = _court_point(0.24, 0.90)
	positions["RC"] = _court_point(0.76, 0.90)
	positions[actor_role] = _court_point(0.50, 0.80)
	return positions


func _build_pressure_away_positions(actor_role: String) -> Dictionary:
	var positions: Dictionary = _build_base_away_positions()
	positions[actor_role] = _court_point(0.52, 0.78)
	return positions


func _build_pressure_home_positions(actor_world: Vector2) -> Dictionary:
	return {
		"PG": _court_point(0.48, 0.80),
		"LW": _court_point(0.40, 0.72),
		"RW": _court_point(0.60, 0.72),
		"LC": _court_point(0.30, 0.88),
		"RC": _court_point(0.70, 0.88),
	}


func _build_shot_home_positions(actor_world: Vector2) -> Dictionary:
	return {
		"PG": _court_point(0.50, 0.82),
		"LW": _court_point(0.38, 0.74),
		"RW": _court_point(0.62, 0.74),
		"LC": _court_point(0.30, 0.92),
		"RC": _court_point(0.70, 0.92),
	}


func _build_finish_home_positions(actor_world: Vector2) -> Dictionary:
	return {
		"PG": _court_point(0.48, 0.84),
		"LW": _court_point(0.40, 0.78),
		"RW": _court_point(0.60, 0.78),
		"LC": _court_point(0.34, 0.90),
		"RC": _court_point(0.66, 0.90),
	}


func _build_turnover_home_positions(actor_role: String) -> Dictionary:
	return {
		"PG": _court_point(0.52, 0.78),
		"LW": _court_point(0.40, 0.70),
		"RW": _court_point(0.60, 0.70),
		"LC": _court_point(0.30, 0.90),
		"RC": _court_point(0.70, 0.90),
	}


func _build_recovery_home_positions(actor_role: String) -> Dictionary:
	return {
		"PG": _court_point(0.50, 0.80),
		"LW": _court_point(0.36, 0.74),
		"RW": _court_point(0.64, 0.74),
		"LC": _court_point(0.28, 0.92),
		"RC": _court_point(0.72, 0.92),
	}


func _lane_attack_position(actor_role: String, kind: String) -> Vector2:
	var lane_x: float = 0.50
	if actor_role == "LW":
		lane_x = 0.44
	elif actor_role == "RW":
		lane_x = 0.56
	elif actor_role == "LC":
		lane_x = 0.35
	elif actor_role == "RC":
		lane_x = 0.65
	var lane_y: float = 0.90
	if kind == "breakaway_layup":
		lane_y = 0.96
	elif kind == "dunk":
		lane_y = 0.94
	elif kind == "alley_oop":
		lane_y = 0.92
	return _court_point(lane_x, lane_y)


func _default_role_position(role: String, is_away: bool) -> Vector2:
	var positions: Dictionary = _build_base_away_positions() if is_away else _build_base_home_positions()
	return positions.get(role, _court_point(0.50, 0.80))


func _get_player(team_key: String, role: String) -> PlayerController:
	var ghosts: Dictionary = _home_ghosts if _is_home_team_key(team_key) else _away_ghosts
	if ghosts.has(role):
		return ghosts.get(role, null) as PlayerController
	return _find_player_by_id(team_key, _current_actor_id)


func _find_player_by_id(team_key: String, player_id: String) -> PlayerController:
	if player_id == "":
		return null
	var team: TeamData = home_team if _is_home_team_key(team_key) else away_team
	if team == null:
		return null
	var ghosts: Dictionary = _home_ghosts if _is_home_team_key(team_key) else _away_ghosts
	for role in ghosts.keys():
		var player: PlayerController = ghosts.get(role, null) as PlayerController
		if player == null or player.get_player_data() == null:
			continue
		if player.get_player_data().player_id == player_id:
			return player
	return null


func _get_ball_world_position(team_key: String, role: String) -> Vector2:
	var player: PlayerController = _get_player(team_key, role)
	if player != null:
		return player.world_position
	return _default_role_position(role, not _is_home_team_key(team_key))


func _build_visual_request(player: PlayerController, is_away: bool) -> PlayerVisualRequest:
	var family: String = "no_ball_idle"
	var variant_index: int = 0
	var show_outline: bool = false
	var mirror_west: bool = false
	if court_config != null:
		mirror_west = player.world_position.x < court_config.court_rect.get_center().x
	var is_actor: bool = player.get_position_role() == _current_actor_role \
		and ((is_away and _is_away_team_key(_current_actor_team)) or (not is_away and _is_home_team_key(_current_actor_team)))
	show_outline = is_actor
	if player.get_position_role() == _ball_owner_role and ((is_away and _is_away_team_key(_ball_owner_team)) or (not is_away and _is_home_team_key(_ball_owner_team))):
		family = "ball_hold_secure"
	elif _current_kind in ["steal", "blocked_shot", "defensive_board"] and not is_away and is_actor:
		family = "guard_idle"
	elif _current_kind in ["layup", "alley_oop", "dunk", "putback", "breakaway_layup"] and is_away and is_actor:
		family = "close_finish_dunk" if _current_kind in ["dunk", "alley_oop"] else "close_finish_layup"
	elif _current_kind in ["jump_shot", "corner_three"] and is_actor:
		family = "set_shot_release"
	elif _current_kind in ["pass", "kickout"] and is_actor:
		family = "ball_move_small"
	elif _current_kind in ["drive", "crossover", "pick_and_roll"] and is_actor:
		family = "ball_move_run"
	elif _current_kind == "turnover" and is_actor:
		family = "guard_run"
	elif _current_kind == "steal" and is_actor:
		family = "jump_contest"
	return PLAYER_VISUAL_REQUEST_SCRIPT.new(family, variant_index, mirror_west, show_outline, false, false, 1)


func _resolve_actor_identity(step: Dictionary) -> void:
	if _current_actor_team == "":
		_current_actor_team = _guess_actor_team(step)
	if _current_actor_role == "" and _current_actor_id != "":
		_current_actor_role = _lookup_role_by_player_id(_current_actor_team, _current_actor_id)
	if _current_actor_role == "":
		_current_actor_role = str(step.get("player", "PG"))
	if _current_actor_role == "":
		_current_actor_role = "PG"


func _guess_actor_team(step: Dictionary) -> String:
	var actor_team: String = str(step.get("actor_team", ""))
	if actor_team != "":
		return actor_team
	var kind: String = str(step.get("kind", ""))
	if kind in ["steal", "blocked_shot", "defensive_board"]:
		return "home"
	return "away"


func _lookup_role_by_player_id(team_key: String, player_id: String) -> String:
	if player_id == "":
		return ""
	var team: TeamData = home_team if _is_home_team_key(team_key) else away_team
	if team == null:
		return ""
	for player in team.players:
		if player != null and player.player_id == player_id:
			return player.role
	return ""


func _clamp_to_bottom_half(position_xy: Vector2) -> Vector2:
	if court_config == null:
		return position_xy
	var normalized: Vector2 = court_config.court_to_normalized(position_xy)
	normalized.x = clampf(normalized.x, 0.0, 1.0)
	normalized.y = clampf(normalized.y, 0.5, 1.0)
	return court_config.normalized_to_court(normalized)


func _court_point(normalized_x: float, normalized_y: float) -> Vector2:
	if court_config == null:
		return Vector2.ZERO
	return court_config.normalized_to_court(Vector2(clampf(normalized_x, 0.0, 1.0), clampf(normalized_y, 0.5, 1.0)))


func _build_positions_snapshot(ghosts_by_role: Dictionary) -> Dictionary:
	var snapshot: Dictionary = {}
	for role in ghosts_by_role.keys():
		var ghost: PlayerController = ghosts_by_role.get(role, null) as PlayerController
		if ghost == null:
			continue
		snapshot[str(role)] = ghost.world_position
	return snapshot


func _build_flat_position_snapshot(away_positions: Dictionary, home_positions: Dictionary) -> Dictionary:
	var snapshot: Dictionary = {}
	for role in away_positions.keys():
		snapshot["away_position_%s" % str(role).to_lower()] = away_positions[role]
	for role in home_positions.keys():
		snapshot["home_position_%s" % str(role).to_lower()] = home_positions[role]
	return snapshot


func _is_home_team_key(team_key: String) -> bool:
	return team_key.to_lower() == "home" or team_key.to_upper() == "HOM"


func _is_away_team_key(team_key: String) -> bool:
	return team_key.to_lower() == "away" or team_key.to_upper() == "AWY"
