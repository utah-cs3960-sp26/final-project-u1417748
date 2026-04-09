class_name GameCoordinator
extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/Player.tscn")
const BALL_SCENE: PackedScene = preload("res://scenes/entities/Ball.tscn")
const HOOP_SCENE: PackedScene = preload("res://scenes/entities/Hoop.tscn")

var game_config: GameConfig
var court_config: CourtConfig
var projection_config: ProjectionConfig
var ball_config: BallPhysicsConfig
var shot_config: ShotTimingConfig
var pass_config: PassConfig
var route_config: RouteConfig
var defense_config: DefenseConfig
var rebound_config: ReboundConfig
var opponent_sim_config: OpponentSimConfig
var difficulty_config: DifficultyConfig
var debug_config: DebugConfig

var home_team: TeamData
var away_team: TeamData

var context: MatchContext = MatchContext.new()
var rng: GameRng
var log_writer: LogWriter

var shot_controller: ShotController = ShotController.new()
var pass_controller: PassController = PassController.new()
var route_controller: RouteController = RouteController.new()
var defense_controller: DefenseController = DefenseController.new()
var rebound_controller: ReboundController = ReboundController.new()
var opponent_sim_controller: OpponentSimController = OpponentSimController.new()
var ball_simulator: BallSimulator = BallSimulator.new()
var hoop_resolver: HoopResolver
var court_projection: CourtProjection

var court_view: CourtView
var entities_node: Node2D
var systems_node: Node
var ui_root: CanvasLayer
var joystick: JoystickControl
var input_controller: InputController
var hud: HUD
var pause_overlay: PauseOverlay
var game_over_overlay: GameOverOverlay
var feedback_text: FeedbackText
var debug_overlay: DebugOverlay

var offense_players: Array[PlayerController] = []
var defense_players: Array[PlayerController] = []
var ball_node: BallController
var hoop_node: HoopView
var current_ballhandler: PlayerController
var shot_owner: PlayerController
var shot_had_rim_contact: bool = false
var current_move_direction: Vector2 = Vector2.ZERO
var current_move_magnitude: float = 0.0
var route_phase_time: float = 0.0
var current_preview_points: Array[Dictionary] = []
var current_preview_color: Color = Color(0.3, 0.95, 0.4, 0.95)
var rebound_delay_timer: float = 0.0
var active_rebound_zone: Vector2 = Vector2.ZERO
var made_shot_animation_timer: float = 0.0
var score_followthrough_state: Dictionary = {}
var current_ball_render_phase: String = ""
var last_scored_shot_passed_through_net: bool = false


func _ready() -> void:
	_resolve_nodes()
	_load_resources()
	_build_services()
	_spawn_entities()
	_wire_input_and_ui()
	_start_new_match()


func _resolve_nodes() -> void:
	var root: Node = get_parent()
	court_view = root.get_node("CourtView") as CourtView
	entities_node = root.get_node("Entities") as Node2D
	systems_node = root.get_node("Systems")
	ui_root = root.get_node("UIRoot") as CanvasLayer
	joystick = ui_root.get_node("Joystick") as JoystickControl
	hud = ui_root.get_node("HUD") as HUD
	pause_overlay = ui_root.get_node("PauseOverlay") as PauseOverlay
	game_over_overlay = ui_root.get_node("GameOverOverlay") as GameOverOverlay
	feedback_text = ui_root.get_node("FeedbackText") as FeedbackText
	debug_overlay = root.get_node("DebugOverlay") as DebugOverlay
	input_controller = systems_node.get_node("InputController") as InputController


func _load_resources() -> void:
	game_config = _load_or_default("res://data/config/GameConfig.tres", GameConfig.new()) as GameConfig
	court_config = _load_or_default("res://data/config/CourtConfig.tres", CourtConfig.new()) as CourtConfig
	projection_config = _load_or_default("res://data/config/ProjectionConfig.tres", ProjectionConfig.new()) as ProjectionConfig
	ball_config = _load_or_default("res://data/config/BallPhysicsConfig.tres", BallPhysicsConfig.new()) as BallPhysicsConfig
	shot_config = _load_or_default("res://data/config/ShotTimingConfig.tres", ShotTimingConfig.new()) as ShotTimingConfig
	pass_config = _load_or_default("res://data/config/PassConfig.tres", PassConfig.new()) as PassConfig
	route_config = _load_or_default("res://data/config/RouteConfig.tres", RouteConfig.new()) as RouteConfig
	defense_config = _load_or_default("res://data/config/DefenseConfig.tres", DefenseConfig.new()) as DefenseConfig
	rebound_config = _load_or_default("res://data/config/ReboundConfig.tres", ReboundConfig.new()) as ReboundConfig
	opponent_sim_config = _load_or_default("res://data/config/OpponentSimConfig.tres", OpponentSimConfig.new()) as OpponentSimConfig
	difficulty_config = _load_or_default("res://data/config/DifficultyConfig.tres", DifficultyConfig.new()) as DifficultyConfig
	debug_config = _load_or_default("res://data/config/DebugConfig.tres", DebugConfig.new()) as DebugConfig
	home_team = _load_or_default("res://data/teams/HOM.tres", TeamData.new()) as TeamData
	away_team = _load_or_default("res://data/teams/AWY.tres", TeamData.new()) as TeamData
	if home_team.players.is_empty():
		home_team = _create_default_team(true)
	if away_team.players.is_empty():
		away_team = _create_default_team(false)


func _build_services() -> void:
	rng = GameRng.new()
	rng.reseed(game_config.default_seed)
	log_writer = LogWriter.new()
	log_writer.set_prefix("match")
	context.difficulty_level = difficulty_config.level
	court_projection = CourtProjection.new(projection_config, court_config)
	shot_controller.shot_config = shot_config
	shot_controller.ball_config = ball_config
	shot_controller.court_config = court_config
	shot_controller.projection = court_projection
	pass_controller.pass_config = pass_config
	pass_controller.court_config = court_config
	route_controller.route_config = route_config
	route_controller.court_config = court_config
	defense_controller.defense_config = defense_config
	defense_controller.difficulty_config = difficulty_config
	defense_controller.court_config = court_config
	rebound_controller.rebound_config = rebound_config
	opponent_sim_controller.sim_config = opponent_sim_config
	opponent_sim_controller.difficulty_config = difficulty_config
	ball_simulator.gravity = ball_config.gravity
	ball_simulator.ball_radius = ball_config.ball_radius
	hoop_resolver = HoopResolver.new(court_config, ball_config)
	court_view.setup(court_config, court_projection)
	debug_overlay.setup(self, debug_config)


func _spawn_entities() -> void:
	_clear_entity_children()
	hoop_node = HOOP_SCENE.instantiate() as HoopView
	entities_node.add_child(hoop_node)
	hoop_node.setup(court_config, court_projection)
	for player_data in home_team.players:
		var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
		player.setup(player_data, true, home_team.primary_color)
		entities_node.add_child(player)
		offense_players.append(player)
	for player_data in away_team.players:
		var defender: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
		defender.setup(player_data, false, Color(0.91, 0.34, 0.3))
		entities_node.add_child(defender)
		defense_players.append(defender)
	ball_node = BALL_SCENE.instantiate() as BallController
	entities_node.add_child(ball_node)
	ball_node.z_index = 6
	_sync_projection_visuals()


func _wire_input_and_ui() -> void:
	input_controller.setup(joystick, court_projection)
	input_controller.shot_hold_delay = shot_config.hold_start_delay
	input_controller.movement_updated.connect(_on_movement_updated)
	input_controller.pass_requested.connect(_on_pass_requested)
	input_controller.shot_aim_started.connect(_on_shot_aim_started)
	input_controller.shot_aim_updated.connect(_on_shot_aim_updated)
	input_controller.shot_aim_released.connect(_on_shot_aim_released)
	input_controller.pause_requested.connect(_toggle_pause)
	hud.pause_pressed.connect(_toggle_pause)
	pause_overlay.resume_pressed.connect(_resume_from_pause)
	pause_overlay.restart_pressed.connect(_start_new_match)
	pause_overlay.quit_pressed.connect(_quit_game)
	game_over_overlay.restart_pressed.connect(_start_new_match)
	game_over_overlay.quit_pressed.connect(_quit_game)


func _start_new_match() -> void:
	context.reset(game_config.match_length_seconds, game_config.default_seed)
	rng.reseed(context.current_seed)
	log_writer.set_prefix("match_%d" % Time.get_ticks_msec())
	log_writer.clear_runtime_logs()
	route_phase_time = 0.0
	rebound_delay_timer = 0.0
	made_shot_animation_timer = 0.0
	_clear_score_followthrough()
	current_preview_points.clear()
	_change_state(GameState.State.MATCH_SETUP)
	_reset_possession()
	_change_state(GameState.State.LIVE_OFFENSE)
	_update_hud()
	pause_overlay.visible = false
	game_over_overlay.visible = false


func _reset_possession() -> void:
	context.possession_count += 1
	context.active_route_package = (context.possession_count - 1) % 3
	current_move_direction = Vector2.ZERO
	current_move_magnitude = 0.0
	shot_owner = null
	context.gameplay_time_scale = 1.0
	pass_controller.active_pass = {}
	shot_controller.cancel_aim()
	made_shot_animation_timer = 0.0
	_clear_score_followthrough(false)
	current_preview_points.clear()
	court_view.clear_preview()
	court_view.clear_shot_meter()
	var anchors: Dictionary = court_config.get_anchor_map()
	for player in offense_players:
		player.world_position = anchors[player.get_position_role()]
		player.velocity = Vector2.ZERO
	for defender in defense_players:
		var match_anchor: Vector2 = anchors[defender.get_position_role()]
		var offset: Vector2 = (court_config.hoop_position - match_anchor).normalized() * defense_config.guard_distance
		defender.world_position = match_anchor + offset
		defender.velocity = Vector2.ZERO
	defense_controller.setup_assignments(offense_players, defense_players)
	var point_guard: PlayerController = offense_players[0]
	for player in offense_players:
		if player.get_position_role() == "PG":
			point_guard = player
			break
	_set_ballhandler(point_guard)
	ball_simulator.reset_to_possession(current_ballhandler.world_position)
	_sync_ball_to_handler()
	context.last_touch_offense = true
	_update_hud()
	log_writer.log_match("Possession reset %d" % context.possession_count)
	log_writer.log_event("possession_reset", {"package": context.active_route_package})
	_sync_projection_visuals()


func _process(delta: float) -> void:
	if context.current_state == GameState.State.PAUSED or context.current_state == GameState.State.GAME_OVER:
		_sync_projection_visuals(0.0)
		return
	var frame_delta: float = 1.0 / 60.0 if context.deterministic_mode else delta
	var scaled_delta: float = frame_delta * context.gameplay_time_scale
	_update_clock(scaled_delta)
	match context.current_state:
		GameState.State.LIVE_OFFENSE:
			_update_live_offense(scaled_delta)
		GameState.State.SHOT_AIM:
			_update_shot_aim(scaled_delta)
		GameState.State.PASS_IN_FLIGHT:
			_update_pass_in_flight(scaled_delta)
		GameState.State.SHOT_IN_FLIGHT:
			_update_shot_in_flight(scaled_delta)
		GameState.State.REBOUND_LIVE:
			_update_rebound_live(scaled_delta)
	_sync_projection_visuals(scaled_delta)


func _update_clock(delta: float) -> void:
	if context.current_state == GameState.State.OPPONENT_SIM or context.current_state == GameState.State.MATCH_SETUP:
		return
	context.match_time_remaining = maxf(context.match_time_remaining - delta, 0.0)
	_update_hud()
	if context.match_time_remaining > 0.0:
		return
	if context.current_state == GameState.State.SHOT_IN_FLIGHT or context.current_state == GameState.State.REBOUND_LIVE:
		context.buzzer_waiting_for_resolution = true
		return
	_finish_game()


func _update_live_offense(delta: float) -> void:
	route_phase_time += delta
	if current_ballhandler != null:
		current_ballhandler.move_in_direction(current_move_direction, current_move_magnitude, delta)
		_clamp_to_court(current_ballhandler)
	_update_off_ball_offense(delta)
	_update_defense(delta)
	if current_ballhandler != null and not court_config.is_in_bounds(current_ballhandler.world_position):
		log_writer.log_match("Ballhandler out of bounds")
		_run_opponent_possession()
		return
	if current_ballhandler != null and defense_controller.should_trigger_pressure_turnover(current_ballhandler, delta, context, rng):
		_show_feedback("STEAL!", Color(1.0, 0.46, 0.36))
		log_writer.log_match("Pressure turnover")
		_run_opponent_possession()
		return
	_sync_ball_to_handler()


func _update_shot_aim(delta: float) -> void:
	route_phase_time += delta
	shot_controller.update_aim(delta)
	_update_off_ball_offense(delta)
	_update_defense(delta)
	if current_ballhandler == null:
		return
	var contested: bool = defense_controller.is_contested(current_ballhandler)
	var preview_profile: Dictionary = shot_controller.build_current_launch_profile(
		current_ballhandler.world_position,
		current_ballhandler.get_player_data(),
		contested
	)
	if preview_profile.is_empty():
		current_preview_points.clear()
		court_view.clear_preview()
	else:
		current_preview_points = shot_controller.create_preview(ball_simulator, preview_profile)
		current_preview_color = _quality_color(str(preview_profile.get("quality", "red")))
		court_view.set_preview(current_preview_points, current_preview_color)
	court_view.set_shot_meter(shot_controller.get_meter_snapshot(contested, current_ballhandler.get_player_data().release_consistency))
	_sync_ball_to_handler()


func _update_pass_in_flight(delta: float) -> void:
	route_phase_time += delta
	_update_off_ball_offense(delta)
	_update_defense(delta)
	var result: Dictionary = pass_controller.step_pass(delta)
	if result.get("state", "") == "traveling":
		_sync_ball_world_visual(result["position"], ball_config.pass_height)
	elif result.get("state", "") == "out_of_bounds":
		log_writer.log_match("Pass out of bounds")
		_run_opponent_possession()
	elif result.get("state", "") == "complete":
		var receiver: PlayerController = result["receiver"]
		if result["intercepted"]:
			_show_feedback("STEAL!", Color(1.0, 0.45, 0.35))
			log_writer.log_match("Pass intercepted by %s" % receiver.get_display_name())
			_run_opponent_possession()
			return
		receiver.trigger_catch_pose(0.24)
		_set_ballhandler(receiver)
		_change_state(GameState.State.LIVE_OFFENSE)
		_sync_ball_to_handler()
		log_writer.log_match("Pass caught by %s" % receiver.get_display_name())


func _update_shot_in_flight(delta: float) -> void:
	if made_shot_animation_timer > 0.0:
		ball_simulator.step(delta)
		if get_score_followthrough_active():
			_advance_score_followthrough(delta)
		_sync_ball_world_visual(ball_simulator.position_xy, ball_simulator.z)
		made_shot_animation_timer = maxf(made_shot_animation_timer - delta, 0.0)
		if made_shot_animation_timer <= 0.0:
			if context.buzzer_waiting_for_resolution or context.match_time_remaining <= 0.0:
				_finish_game()
			else:
				_run_opponent_possession()
		return
	route_phase_time += delta
	_update_off_ball_offense(delta)
	_update_defense(delta)
	ball_simulator.step(delta)
	_maybe_begin_guided_make_net_swish()
	var interaction: Dictionary = hoop_resolver.check_hoop_interaction(ball_simulator)
	match interaction["hit_type"]:
		"backboard":
			ball_simulator.velocity_xy = interaction["new_velocity_xy"]
			ball_simulator.vz = interaction["new_vz"]
			shot_had_rim_contact = true
			log_writer.log_match("Backboard collision")
		"rim":
			ball_simulator.velocity_xy = interaction["new_velocity_xy"]
			ball_simulator.vz = interaction["new_vz"]
			shot_had_rim_contact = true
			log_writer.log_match("Rim collision")
		"score":
			ball_simulator.already_scored = true
			context.home_score += context.shot_value_pending
			_show_feedback("SWISH!" if not shot_had_rim_contact else "BUCKET!", Color(0.44, 1.0, 0.58))
			log_writer.log_match("Score %d points" % context.shot_value_pending)
			_update_hud()
			_begin_score_followthrough(interaction)
			_sync_ball_world_visual(ball_simulator.position_xy, ball_simulator.z)
			made_shot_animation_timer = maxf(shot_config.made_shot_animation_duration, ball_simulator.get_remaining_visual_time() + 0.08)
			return
	_sync_ball_world_visual(ball_simulator.position_xy, ball_simulator.z)
	if not ball_simulator.is_in_flight and not ball_simulator.already_scored:
		_show_feedback("BRICK!", Color(1.0, 0.76, 0.36))
		_begin_rebound()


func _update_rebound_live(delta: float) -> void:
	rebound_delay_timer += delta
	for player in offense_players:
		player.move_toward_target(active_rebound_zone, rebound_config.pursuit_speed_bonus, delta)
		_clamp_to_court(player)
	for defender in defense_players:
		defender.move_toward_target(active_rebound_zone, rebound_config.pursuit_speed_bonus, delta)
		_clamp_to_court(defender)
	if rebound_delay_timer < rebound_config.rebound_reaction_delay:
		return
	if not court_config.is_in_bounds(active_rebound_zone):
		log_writer.log_match("Loose ball out of bounds")
		_run_opponent_possession()
		return
	var candidates: Array[Dictionary] = rebound_controller.get_rebound_candidates(active_rebound_zone, offense_players, defense_players)
	if candidates.is_empty():
		_run_opponent_possession()
		return
	var winner: Dictionary = rebound_controller.pick_winner(candidates, rng)
	var player: PlayerController = winner["player"]
	if winner["is_offense"]:
		player.trigger_catch_pose(0.28)
		_set_ballhandler(player)
		_show_feedback("BOARD!", Color(0.6, 0.9, 1.0))
		_change_state(GameState.State.LIVE_OFFENSE)
		_sync_ball_to_handler()
		log_writer.log_match("Offensive rebound by %s" % player.get_display_name())
	else:
		log_writer.log_match("Defensive rebound by %s" % player.get_display_name())
		_run_opponent_possession()


func _update_off_ball_offense(delta: float) -> void:
	var targets: Dictionary = route_controller.get_route_targets(offense_players, current_ballhandler, context.active_route_package, route_phase_time)
	for player in offense_players:
		if player == current_ballhandler:
			continue
		player.move_toward_target(targets.get(player, player.world_position), route_config.route_move_speed_multiplier, delta)
		_clamp_to_court(player)


func _update_defense(delta: float) -> void:
	defense_controller.update_defense(delta, offense_players, defense_players, current_ballhandler)
	for defender in defense_players:
		_clamp_to_court(defender)


func _on_movement_updated(direction: Vector2, magnitude: float) -> void:
	current_move_direction = direction
	current_move_magnitude = magnitude


func _on_pass_requested(target: PlayerController) -> void:
	if context.current_state != GameState.State.LIVE_OFFENSE:
		return
	if target == null or target == current_ballhandler:
		return
	log_writer.log_match("Pass requested to %s" % target.get_display_name())
	_change_state(GameState.State.PASS_IN_FLIGHT)
	current_ballhandler.set_has_ball(false)
	pass_controller.start_pass(current_ballhandler.world_position, target, defense_players, rng)


func _on_shot_aim_started(start_world: Vector2) -> void:
	if context.current_state != GameState.State.LIVE_OFFENSE:
		return
	if current_ballhandler == null or current_ballhandler.world_position.distance_to(start_world) > 140.0:
		return
	_change_state(GameState.State.SHOT_AIM)
	context.gameplay_time_scale = game_config.aim_time_scale
	shot_controller.begin_aim(current_ballhandler.world_position, rng)
	log_writer.log_match("Shot aim started")


func _on_shot_aim_updated(_current_world: Vector2, _drag_vector: Vector2) -> void:
	if context.current_state != GameState.State.SHOT_AIM:
		return


func _on_shot_aim_released(_release_screen: Vector2, _release_world: Vector2, _drag_vector: Vector2) -> void:
	if context.current_state != GameState.State.SHOT_AIM:
		return
	var contested: bool = defense_controller.is_contested(current_ballhandler)
	var action: Dictionary = shot_controller.release_action(current_ballhandler.world_position, current_ballhandler.get_player_data(), contested, rng)
	context.gameplay_time_scale = 1.0
	court_view.clear_shot_meter()
	match action["kind"]:
		"cancel":
			court_view.clear_preview()
			current_preview_points.clear()
			_change_state(GameState.State.LIVE_OFFENSE)
		"shot":
			court_view.clear_preview()
			current_preview_points.clear()
			if action["outcome"] == "miss" and contested and defense_controller.can_block_shot(current_ballhandler, rng):
				log_writer.log_match("Shot blocked on red release")
				_show_feedback("BLOCKED!", Color(1.0, 0.55, 0.34))
				_begin_rebound(current_ballhandler.world_position + Vector2(0.0, -36.0))
				return
			shot_owner = current_ballhandler
			current_ballhandler.trigger_shot_pose(0.28)
			context.shot_value_pending = action["shot_value"]
			current_ballhandler.set_has_ball(false)
			_clear_score_followthrough(false)
			ball_simulator.launch_shot_profile(action)
			shot_had_rim_contact = false
			_change_state(GameState.State.SHOT_IN_FLIGHT)
			log_writer.log_event(
				"shot_launch",
				{
					"profile_kind": action.get("profile_kind", "free_flight"),
					"quality": action["quality"],
					"outcome": action["outcome"],
					"flight_time": action["flight_time"],
					"apex_z": action["apex_z"],
					"launch_z": action["launch_z"],
					"target_xy": {
						"x": action["target_xy"].x,
						"y": action["target_xy"].y,
					},
				}
			)
			log_writer.log_match(
				"Shot released %s %s for %d apex=%0.1f flight=%0.2f" % [
					action["quality"],
					action["outcome"],
					context.shot_value_pending,
					float(action.get("apex_z", 0.0)),
					float(action.get("flight_time", 0.0)),
				]
			)


func _toggle_pause() -> void:
	if context.current_state == GameState.State.PAUSED:
		_resume_from_pause()
		return
	context.previous_state = context.current_state
	_change_state(GameState.State.PAUSED)
	pause_overlay.visible = true
	log_writer.log_match("Paused")


func _resume_from_pause() -> void:
	pause_overlay.visible = false
	_change_state(context.previous_state if context.previous_state != GameState.State.PAUSED else GameState.State.LIVE_OFFENSE)
	log_writer.log_match("Resumed")


func _run_opponent_possession() -> void:
	_change_state(GameState.State.OPPONENT_SIM)
	var result: Dictionary = opponent_sim_controller.run_possession(away_team, home_team, context.match_time_remaining, rng)
	for event_line in result["events"]:
		log_writer.log_sim(event_line)
	context.away_score += result["points_scored"]
	context.match_time_remaining = maxf(context.match_time_remaining - result["time_consumed"], 0.0)
	_update_hud()
	if context.match_time_remaining <= 0.0:
		_finish_game()
		return
	_reset_possession()
	_change_state(GameState.State.LIVE_OFFENSE)


func _begin_rebound(override_zone: Vector2 = Vector2.INF) -> void:
	active_rebound_zone = override_zone if override_zone != Vector2.INF else hoop_resolver.estimate_landing_position(ball_simulator)
	rebound_delay_timer = 0.0
	context.last_touch_offense = true
	_change_state(GameState.State.REBOUND_LIVE)


func _finish_game() -> void:
	context.gameplay_time_scale = 1.0
	_change_state(GameState.State.GAME_OVER)
	game_over_overlay.visible = true
	game_over_overlay.show_result(context.home_score, context.away_score)
	log_writer.log_match("Game over HOM %d AWY %d" % [context.home_score, context.away_score])


func _quit_game() -> void:
	get_tree().quit()


func _set_ballhandler(player: PlayerController) -> void:
	current_ballhandler = player
	for offense in offense_players:
		offense.set_controlled(offense == player)
		offense.set_has_ball(offense == player)
	input_controller.set_ballhandler(player)
	input_controller.set_offense_players(offense_players)
	log_writer.log_event("ballhandler_changed", {"player": player.get_display_name(), "role": player.get_position_role()})


func _sync_ball_to_handler() -> void:
	if current_ballhandler == null:
		return
	ball_simulator.reset_to_possession(current_ballhandler.world_position)
	var ground_anchor: Vector2 = court_projection.world_to_screen_ground(ball_simulator.position_xy)
	var shadow_anchor: Vector2 = court_projection.shadow_anchor(ball_simulator.position_xy)
	var render_context: Dictionary = _resolve_ball_render_context(ball_simulator.position_xy, ball_simulator.z, 0.0)
	var render_phase: String = str(render_context.get("render_phase", ""))
	var z_override: int = int(render_context.get("z_index_override", BallController.NO_Z_INDEX_OVERRIDE))
	current_ball_render_phase = render_phase
	ball_node.sync_visual(
		ball_simulator.position_xy,
		ball_simulator.z,
		{
			"ground_anchor": ground_anchor,
			"ball_anchor": current_ballhandler.get_ball_screen_anchor(),
			"shadow_anchor": shadow_anchor,
			"ball_radius": 16.0 * current_ballhandler.projected_scale,
			"shadow_scale": court_projection.shadow_scale(ball_simulator.position_xy, 0.0),
			"depth_key": court_projection.depth_key(ball_simulator.position_xy, 0.0),
		},
		z_override,
		render_phase
	)


func _update_hud() -> void:
	hud.update_display(home_team.abbreviation, context.home_score, away_team.abbreviation, context.away_score, context.match_time_remaining)


func _show_feedback(text_value: String, color_value: Color) -> void:
	context.last_feedback_text = text_value
	feedback_text.show_feedback(text_value, color_value, 1.0)
	log_writer.log_event("feedback", {"text": text_value})


func _clamp_to_court(player: PlayerController) -> void:
	player.world_position.x = clampf(player.world_position.x, court_config.court_rect.position.x, court_config.court_rect.end.x)
	player.world_position.y = clampf(player.world_position.y, court_config.court_rect.position.y, court_config.court_rect.end.y)


func _change_state(new_state: int) -> void:
	change_state(new_state)


func change_state(new_state: int) -> void:
	var old_state: int = context.current_state
	context.previous_state = old_state
	context.current_state = new_state
	log_writer.log_event("state_transition", {"from": GameState.state_name(old_state), "to": GameState.state_name(new_state)})


func _quality_color(quality: String) -> Color:
	match quality:
		"green":
			return Color(0.36, 1.0, 0.48, 0.95)
		"yellow":
			return Color(1.0, 0.86, 0.32, 0.95)
		_:
			return Color(1.0, 0.3, 0.28, 0.95)


func _load_or_default(path: String, fallback: Resource) -> Resource:
	var loaded: Resource = ResourceLoader.load(path)
	if loaded == null:
		return fallback
	return loaded


func _clear_entity_children() -> void:
	for child in entities_node.get_children():
		child.queue_free()
	offense_players.clear()
	defense_players.clear()


func _create_default_team(is_home: bool) -> TeamData:
	var team: TeamData = TeamData.new()
	team.team_name = "Home" if is_home else "Away"
	team.abbreviation = "HOM" if is_home else "AWY"
	team.primary_color = Color(0.23, 0.57, 0.95) if is_home else Color(0.92, 0.34, 0.3)
	var roles: PackedStringArray = PackedStringArray(["PG", "LW", "RW", "LC", "RC"])
	for role in roles:
		var player: PlayerData = PlayerData.new()
		player.player_id = "%s_%s" % [team.abbreviation.to_lower(), role.to_lower()]
		player.display_name = ("%s %s" % [team.abbreviation, role]).strip_edges()
		player.role = role
		if role == "PG":
			player.handle = 82
			player.pass_accuracy = 80
			player.sim_offense = 78
		elif role == "RC":
			player.shooting = 80
			player.release_consistency = 82
		team.players.append(player)
	return team


func get_debug_snapshot() -> Dictionary:
	var route_segments: Array[Dictionary] = []
	var targets: Dictionary = route_controller.get_route_targets(offense_players, current_ballhandler, context.active_route_package, route_phase_time)
	for player in targets.keys():
		route_segments.append({
			"a": court_projection.world_to_screen_ground(player.world_position),
			"b": court_projection.world_to_screen_ground(targets[player]),
		})
	var defender_segments: Array[Dictionary] = []
	for defender in defense_controller.assignments.keys():
		var assigned: PlayerController = defense_controller.assignments[defender]
		defender_segments.append({
			"a": court_projection.world_to_screen_ground(defender.world_position),
			"b": court_projection.world_to_screen_ground(assigned.world_position),
		})
	var contest_rings: Array[PackedVector2Array] = []
	if current_ballhandler != null:
		contest_rings.append(court_projection.project_circle(current_ballhandler.world_position, defense_config.contest_radius, 0.0, 28))
	var catch_rings: Array[PackedVector2Array] = []
	for player in offense_players:
		if player != current_ballhandler:
			catch_rings.append(court_projection.project_circle(player.world_position, pass_config.catch_radius, 0.0, 28))
	var intercept_corridor: PackedVector2Array = PackedVector2Array()
	var raw_corridor: PackedVector2Array = pass_controller.get_intercept_corridor()
	if raw_corridor.size() == 2:
		intercept_corridor = court_projection.project_polyline([raw_corridor[0], raw_corridor[1]])
	var rebound_zone: PackedVector2Array = PackedVector2Array()
	if context.current_state == GameState.State.REBOUND_LIVE:
		rebound_zone = court_projection.project_circle(active_rebound_zone, rebound_config.rebound_zone_radius, 0.0, 28)
	return {
		"state_name": GameState.state_name(context.current_state),
		"clock_text": _format_clock_text(context.match_time_remaining),
		"home_score": context.home_score,
		"away_score": context.away_score,
		"seed": context.current_seed,
		"route_segments": route_segments,
		"defender_segments": defender_segments,
		"contest_rings": contest_rings,
		"catch_rings": catch_rings,
		"intercept_corridor": intercept_corridor,
		"rebound_zone": rebound_zone,
		"shot_preview": current_preview_points,
	}


func begin_test_mode(seed: int) -> void:
	context.deterministic_mode = true
	context.current_seed = seed
	rng.reseed(seed)
	log_writer.set_prefix("test_%d" % seed)
	log_writer.clear_runtime_logs()


func apply_test_setup(home_score: int, away_score: int, time_remaining: float) -> void:
	context.home_score = home_score
	context.away_score = away_score
	context.match_time_remaining = time_remaining
	_update_hud()


func apply_scenario_setup(setup: Dictionary) -> void:
	if setup.is_empty():
		return
	if setup.has("route_package"):
		context.active_route_package = int(setup["route_package"])
	if setup.has("gameplay_time_scale"):
		context.gameplay_time_scale = float(setup["gameplay_time_scale"])
	if setup.has("offense_positions"):
		_apply_role_positions(offense_players, setup["offense_positions"])
	if setup.has("defense_positions"):
		_apply_role_positions(defense_players, setup["defense_positions"])
	defense_controller.setup_assignments(offense_players, defense_players)
	if setup.has("ballhandler_role"):
		var handler: PlayerController = get_offense_player_by_role(str(setup["ballhandler_role"]))
		if handler != null:
			_set_ballhandler(handler)
	if setup.has("shot_owner_role"):
		shot_owner = get_offense_player_by_role(str(setup["shot_owner_role"]))
	if setup.has("shot_value_pending"):
		context.shot_value_pending = int(setup["shot_value_pending"])
	if setup.has("rebound_zone"):
		active_rebound_zone = setup["rebound_zone"]
	if setup.has("ball"):
		_apply_ball_setup(setup["ball"])
	elif current_ballhandler != null and not String(setup.get("state", "")).contains("SHOT_IN_FLIGHT"):
		_sync_ball_to_handler()
	if setup.has("state"):
		change_state(GameState.from_name(str(setup["state"])))
	_update_hud()
	_sync_projection_visuals()
	if debug_overlay != null:
		debug_overlay.queue_redraw()


func get_state_name() -> String:
	return GameState.state_name(context.current_state)


func get_controlled_role() -> String:
	if current_ballhandler == null:
		return ""
	return current_ballhandler.get_position_role()


func get_last_log_line() -> String:
	if log_writer.match_lines.is_empty():
		return ""
	return log_writer.match_lines[-1]


func get_match_log_text() -> String:
	return "\n".join(log_writer.match_lines)


func match_log_contains(fragment: String) -> bool:
	for line in log_writer.match_lines:
		if line.contains(fragment):
			return true
	return false


func get_offense_player_by_role(role: String) -> PlayerController:
	for player in offense_players:
		if player.get_position_role() == role:
			return player
	return null


func get_defense_player_by_role(role: String) -> PlayerController:
	for player in defense_players:
		if player.get_position_role() == role:
			return player
	return null


func test_toggle_pause() -> void:
	_toggle_pause()


func test_force_scoring_shot(role: String = "", shot_value: int = 0) -> void:
	var shooter: PlayerController = current_ballhandler
	if role != "":
		shooter = get_offense_player_by_role(role)
	if shooter == null:
		return
	_set_ballhandler(shooter)
	shooter.set_has_ball(false)
	shooter.trigger_shot_pose(0.28)
	shot_owner = shooter
	var launch_profile: Dictionary = shot_controller.build_launch_profile(shooter.world_position, "green")
	if launch_profile.is_empty():
		return
	context.shot_value_pending = shot_value if shot_value > 0 else int(launch_profile.get("shot_value", 3 if court_config.is_three_point(shooter.world_position) else 2))
	shot_had_rim_contact = false
	_clear_score_followthrough(false)
	ball_simulator.launch_shot_profile(launch_profile)
	_sync_ball_world_visual(ball_simulator.position_xy, ball_simulator.z)
	change_state(GameState.State.SHOT_IN_FLIGHT)
	log_writer.log_match("Test scoring shot queued for %s" % shooter.get_display_name())


func test_force_rebound_state(zone: Vector2) -> void:
	active_rebound_zone = zone
	ball_simulator.is_in_flight = false
	ball_simulator.already_scored = false
	change_state(GameState.State.REBOUND_LIVE)
	log_writer.log_match("Test rebound queued")


func test_force_defensive_rebound(role: String = "") -> void:
	var defender: PlayerController = get_defense_player_by_role(role)
	if defender == null:
		defender = defense_controller.get_assigned_defender(current_ballhandler)
	if defender == null:
		return
	log_writer.log_match("Defensive rebound by %s" % defender.get_display_name())
	_run_opponent_possession()


func test_force_pass_interception() -> void:
	_show_feedback("STEAL!", Color(1.0, 0.45, 0.35))
	log_writer.log_match("Pass intercepted by scripted defender")
	_run_opponent_possession()


func test_force_pressure_turnover() -> void:
	_show_feedback("STEAL!", Color(1.0, 0.46, 0.36))
	log_writer.log_match("Pressure turnover")
	_run_opponent_possession()


func test_force_offensive_rebound(role: String) -> void:
	var player: PlayerController = get_offense_player_by_role(role)
	if player == null:
		return
	active_rebound_zone = player.world_position
	player.trigger_catch_pose(0.28)
	_set_ballhandler(player)
	_show_feedback("BOARD!", Color(0.6, 0.9, 1.0))
	change_state(GameState.State.LIVE_OFFENSE)
	_sync_ball_to_handler()
	log_writer.log_match("Offensive rebound by %s" % player.get_display_name())


func get_ball_render_phase() -> String:
	return current_ball_render_phase


func did_last_scored_shot_pass_through_net() -> bool:
	return last_scored_shot_passed_through_net


func get_score_followthrough_active() -> bool:
	return bool(score_followthrough_state.get("active", false))


func get_net_swish_active() -> bool:
	return hoop_node != null and hoop_node.has_method("is_net_swish_active") and bool(hoop_node.call("is_net_swish_active"))


func _apply_role_positions(players: Array[PlayerController], positions: Dictionary) -> void:
	for role in positions.keys():
		for player in players:
			if player.get_position_role() == str(role):
				player.world_position = positions[role]
				player.velocity = Vector2.ZERO
				break


func _apply_ball_setup(ball_setup: Dictionary) -> void:
	_clear_score_followthrough(false)
	ball_simulator.position_xy = ball_setup.get("position", ball_simulator.position_xy)
	ball_simulator.previous_position_xy = ball_setup.get("previous_position", ball_simulator.position_xy)
	ball_simulator.velocity_xy = ball_setup.get("velocity", ball_simulator.velocity_xy)
	ball_simulator.z = float(ball_setup.get("z", ball_simulator.z))
	ball_simulator.previous_z = float(ball_setup.get("previous_z", ball_simulator.z))
	ball_simulator.vz = float(ball_setup.get("vz", ball_simulator.vz))
	ball_simulator.is_in_flight = bool(ball_setup.get("in_flight", ball_simulator.is_in_flight))
	ball_simulator.already_scored = bool(ball_setup.get("already_scored", ball_simulator.already_scored))
	_sync_ball_world_visual(ball_simulator.position_xy, ball_simulator.z)


func _sync_projection_visuals(delta: float = 0.0) -> void:
	if court_projection == null:
		return
	if hoop_node != null:
		hoop_node.set_projection(court_projection)
		hoop_node.advance_visual_animation(delta)
	for player in offense_players + defense_players:
		var ground_anchor: Vector2 = court_projection.world_to_screen_ground(player.world_position)
		var shadow_offset: Vector2 = court_projection.shadow_anchor(player.world_position) - ground_anchor
		player.apply_projection(
			ground_anchor,
			court_projection.actor_scale(player.world_position),
			shadow_offset,
			court_projection.shadow_scale(player.world_position),
			court_projection.depth_key(player.world_position)
		)
		player.sync_visual_state(_resolve_player_visual_state(player), _resolve_player_facing(player), delta)
	if current_ballhandler != null and (context.current_state == GameState.State.LIVE_OFFENSE or context.current_state == GameState.State.SHOT_AIM):
		_sync_ball_to_handler()
	elif ball_node != null:
		_sync_ball_world_visual(ball_simulator.position_xy, ball_simulator.z)


func _sync_ball_world_visual(world_position: Vector2, z_value: float, render_context: Dictionary = {}) -> void:
	if ball_node == null or court_projection == null:
		return
	var resolved_render_context: Dictionary = render_context
	if resolved_render_context.is_empty():
		resolved_render_context = _resolve_ball_render_context(world_position, z_value, ball_simulator.vz)
	var ground_anchor: Vector2 = court_projection.world_to_screen_ground(world_position)
	var ball_anchor: Vector2 = court_projection.world_to_screen(world_position, z_value)
	var shadow_anchor: Vector2 = court_projection.shadow_anchor(world_position)
	var z_ratio: float = clampf(z_value / 620.0, 0.0, 1.0)
	var render_phase: String = str(resolved_render_context.get("render_phase", ""))
	var z_override: int = int(resolved_render_context.get("z_index_override", BallController.NO_Z_INDEX_OVERRIDE))
	current_ball_render_phase = render_phase
	ball_node.sync_visual(
		world_position,
		z_value,
		{
			"ground_anchor": ground_anchor,
			"ball_anchor": ball_anchor,
			"shadow_anchor": shadow_anchor,
			"ball_radius": lerpf(15.0, 30.0, pow(z_ratio, 0.82)),
			"shadow_scale": court_projection.shadow_scale(world_position, z_value),
			"depth_key": court_projection.depth_key(world_position, z_value),
		},
		z_override,
		render_phase
	)


func _clear_score_followthrough(reset_passed_flag: bool = true) -> void:
	score_followthrough_state.clear()
	current_ball_render_phase = ""
	if hoop_node != null and hoop_node.has_method("stop_net_swish"):
		hoop_node.call("stop_net_swish")
	if reset_passed_flag:
		last_scored_shot_passed_through_net = false


func _begin_score_followthrough(interaction: Dictionary) -> void:
	var start_xy: Vector2 = _clamp_score_followthrough_start(interaction.get("score_sample_xy", court_config.hoop_position))
	var entry_offset_x: float = start_xy.x - court_config.hoop_position.x
	score_followthrough_state = {
		"active": true,
		"score_sample_xy": start_xy,
		"entry_offset_x": entry_offset_x,
		"net_swish_started": bool(score_followthrough_state.get("net_swish_started", false)),
	}
	current_ball_render_phase = ball_simulator.get_render_phase_name()
	last_scored_shot_passed_through_net = true
	if hoop_node != null and hoop_node.has_method("trigger_net_swish") and not bool(score_followthrough_state.get("net_swish_started", false)):
		hoop_node.call("trigger_net_swish", entry_offset_x)
		score_followthrough_state["net_swish_started"] = true


func _advance_score_followthrough(delta: float) -> void:
	if score_followthrough_state.is_empty():
		return
	var phase: String = ball_simulator.get_render_phase_name()
	var is_active: bool = ball_simulator.is_guided_make_profile() and ball_simulator.is_in_flight and phase != ""
	score_followthrough_state["active"] = is_active
	if is_active:
		current_ball_render_phase = phase
		return
	current_ball_render_phase = HoopView.BALL_RENDER_PHASE_FRONT_OF_NET if last_scored_shot_passed_through_net else ""
	if hoop_node != null and hoop_node.has_method("stop_net_swish"):
		hoop_node.call("stop_net_swish")


func _maybe_begin_guided_make_net_swish() -> void:
	if not ball_simulator.is_guided_make_profile():
		return
	if ball_simulator.get_flight_phase() != BallSimulator.FLIGHT_PHASE_GUIDED_DESCENT:
		return
	if bool(score_followthrough_state.get("net_swish_started", false)):
		return
	var entry_offset_x: float = ball_simulator.position_xy.x - court_config.hoop_position.x
	score_followthrough_state["net_swish_started"] = true
	if hoop_node != null and hoop_node.has_method("trigger_net_swish"):
		hoop_node.call("trigger_net_swish", entry_offset_x)


func _build_score_followthrough_visual() -> Dictionary:
	if score_followthrough_state.is_empty() or hoop_node == null:
		return {}
	var render_phase: String = current_ball_render_phase if current_ball_render_phase != "" else HoopView.BALL_RENDER_PHASE_FRONT_OF_NET
	return {
		"position": ball_simulator.position_xy,
		"z": ball_simulator.z,
		"render_phase": render_phase,
		"z_index_override": hoop_node.get_ball_z_index_for_phase(render_phase),
	}


func _clamp_score_followthrough_start(sample_xy: Vector2) -> Vector2:
	var half_channel_width: float = maxf(minf(court_config.net_channel_radius * 0.5, court_config.rim_inner_radius * 0.5), 8.0)
	return Vector2(
		clampf(sample_xy.x, court_config.hoop_position.x - half_channel_width, court_config.hoop_position.x + half_channel_width),
		maxf(sample_xy.y, court_config.hoop_position.y + court_config.score_entry_min_front_offset)
	)


func _get_legal_score_entry_anchor() -> Vector2:
	return Vector2(
		court_config.hoop_position.x,
		court_config.hoop_position.y + maxf(court_config.made_shot_entry_depth, court_config.score_entry_min_front_offset)
	)


func _resolve_ball_render_context(world_position: Vector2, z_value: float, vz_value: float, forced_phase: String = "") -> Dictionary:
	if hoop_node == null or court_config == null:
		return {}
	var render_phase: String = forced_phase
	if render_phase == "":
		var guided_phase: String = ball_simulator.get_render_phase_name()
		if ball_simulator.is_guided_make_profile() and guided_phase != "":
			render_phase = guided_phase
	if render_phase == "" and made_shot_animation_timer > 0.0 and current_ball_render_phase != "":
		render_phase = current_ball_render_phase
	if render_phase == "":
		if not _is_ball_in_hoop_render_zone(world_position, z_value):
			return {}
		render_phase = hoop_node.get_ball_render_phase(world_position, z_value, vz_value < 0.0, false, ball_config.ball_radius)
	return {
		"render_phase": render_phase,
		"z_index_override": hoop_node.get_ball_z_index_for_phase(render_phase),
	}


func _is_ball_in_hoop_render_zone(world_position: Vector2, z_value: float) -> bool:
	var half_width: float = court_config.backboard_width * 0.5 + court_config.rim_radius + 56.0
	if absf(world_position.x - court_config.backboard_x_center) > half_width:
		return false
	if world_position.y <= court_config.backboard_y + 24.0:
		return true
	if world_position.y <= court_config.hoop_position.y + court_config.net_followthrough_depth + 132.0:
		return true
	return z_value >= court_config.net_exit_z


func _format_clock_text(time_remaining: float) -> String:
	var total_seconds: int = maxi(int(ceil(time_remaining)), 0)
	return "%d:%02d" % [total_seconds / 60, total_seconds % 60]


func _resolve_player_visual_state(player: PlayerController) -> String:
	if player.shot_pose_timer > 0.0:
		return "shoot"
	if player.catch_pose_timer > 0.0:
		return "catch"
	if player == current_ballhandler and context.current_state == GameState.State.SHOT_AIM:
		return "aim"
	if player.velocity.length() > 18.0:
		return "move"
	if player == current_ballhandler and context.current_state == GameState.State.LIVE_OFFENSE and current_move_magnitude > 0.08:
		return "move"
	return "idle"


func _resolve_player_facing(player: PlayerController) -> Vector2:
	if player == current_ballhandler:
		if context.current_state == GameState.State.SHOT_AIM or player.shot_pose_timer > 0.0:
			return (court_config.hoop_position - player.world_position).normalized()
		if context.current_state == GameState.State.LIVE_OFFENSE and current_move_direction.length() > 0.08:
			return current_move_direction.normalized()
	if player.velocity.length() > 1.0:
		return player.velocity.normalized()
	if player == shot_owner and context.current_state == GameState.State.SHOT_IN_FLIGHT:
		return (court_config.hoop_position - player.world_position).normalized()
	return Vector2.ZERO
