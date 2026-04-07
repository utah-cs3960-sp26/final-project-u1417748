class_name GameCoordinator
extends Node2D

const PLAYER_SCENE := preload("res://scenes/entities/Player.tscn")

@onready var court_view: CourtView = $Court
@onready var hoop_view: HoopView = $Hoop
@onready var players_root: Node2D = $Players
@onready var ball_view: BallView = $Ball
@onready var input_controller: InputController = $InputController
@onready var hud: HUD = $UILayer/HUD
@onready var pause_overlay: PauseOverlay = $UILayer/PauseOverlay
@onready var game_over_overlay: GameOverOverlay = $UILayer/GameOverOverlay
@onready var debug_overlay: DebugOverlay = $UILayer/DebugOverlay
@onready var joystick_control: JoystickControl = $UILayer/Joystick
@onready var feedback_label: Label = $UILayer/FeedbackLabel

var game_config: GameConfig = preload("res://data/config/GameConfig.tres")
var court_config: CourtConfig = preload("res://data/config/CourtConfig.tres")
var ball_physics_config: BallPhysicsConfig = preload("res://data/config/BallPhysicsConfig.tres")
var shot_timing_config: ShotTimingConfig = preload("res://data/config/ShotTimingConfig.tres")
var pass_config: PassConfig = preload("res://data/config/PassConfig.tres")
var route_config: RouteConfig = preload("res://data/config/RouteConfig.tres")
var defense_config: DefenseConfig = preload("res://data/config/DefenseConfig.tres")
var rebound_config: ReboundConfig = preload("res://data/config/ReboundConfig.tres")
var opponent_sim_config: OpponentSimConfig = preload("res://data/config/OpponentSimConfig.tres")
var difficulty_config: DifficultyConfig = preload("res://data/config/DifficultyConfig.tres")
var debug_config: DebugConfig = preload("res://data/config/DebugConfig.tres")

var home_team: TeamData
var away_team: TeamData
var offense_players: Array[PlayerController] = []
var defense_players: Array[PlayerController] = []
var route_targets: Array[Vector2] = []
var preview_points: Array[Vector2] = []
var joystick_vector: Vector2 = Vector2.ZERO
var current_state: int = GameState.Value.BOOT
var previous_live_state: int = GameState.Value.LIVE_OFFENSE
var current_time_scale: float = 1.0
var controlled_offense_index: int = 0
var clock_remaining: float = 180.0
var home_score: int = 0
var away_score: int = 0
var possession_elapsed: float = 0.0
var stationary_pressure_time: float = 0.0
var pressure_check_accumulator: float = 0.0
var shot_hold_time: float = 0.0
var active_drag_vector: Vector2 = Vector2.ZERO
var current_shot_quality: Dictionary = {}
var active_pass_state: Dictionary = {}
var active_ball_state: Dictionary = {}
var rebound_target: Vector2 = Vector2.ZERO
var rebound_timer: float = 0.0
var pending_game_over: bool = false
var feedback_timer: float = 0.0
var feedback_color: Color = Color.WHITE
var route_debug_pairs: Array[PackedVector2Array] = []
var difficulty_profile: Dictionary = {}
var rng := RandomNumberGenerator.new()
var log_writer: LogWriter
var debug_overlay_visible: bool = true
var recent_log_lines: Array[String] = []
var shot_action_armed: bool = false
var test_mode_enabled: bool = false
var last_event_name: String = "boot"
var last_turnover_type: String = ""
var last_possession_result: String = ""
var last_feedback_text: String = ""
var pause_hidden_clock_advanced: bool = false
var paused_clock_reference: float = 0.0
var missing_controlled_player: bool = false
var duplicate_score_detected: bool = false

func _ready() -> void:
	home_team = load(game_config.offense_team_path)
	away_team = load(game_config.defense_team_path)
	clock_remaining = game_config.match_length_seconds
	difficulty_profile = difficulty_config.get_profile(game_config.default_difficulty)
	rng.randomize()
	log_writer = LogWriter.new("pocket_hoops")
	court_view.configure(court_config)
	hoop_view.position = court_config.get_hoop_world_position()
	hoop_view.configure(court_config.hoop_radius, court_config.backboard_half_width, court_config.backboard_offset)
	joystick_control.set_input_controller(input_controller)
	debug_overlay.config = debug_config
	_wire_signals()
	_spawn_players()
	feedback_label.visible = false
	pause_overlay.visible = false
	game_over_overlay.visible = false
	debug_overlay_visible = debug_config.overlay_enabled_by_default
	debug_overlay.visible = debug_overlay_visible
	enter_state(GameState.Value.MATCH_SETUP, "initial boot")
	start_match()

func _wire_signals() -> void:
	input_controller.joystick_vector_changed.connect(_on_joystick_vector_changed)
	input_controller.action_started.connect(_on_action_started)
	input_controller.action_dragged.connect(_on_action_dragged)
	input_controller.action_released.connect(_on_action_released)
	input_controller.pause_requested.connect(_on_pause_requested)
	input_controller.debug_overlay_toggled.connect(_on_debug_toggled)
	hud.pause_pressed.connect(_on_pause_requested)
	pause_overlay.resume_requested.connect(_resume_from_pause)
	pause_overlay.restart_requested.connect(restart_match)
	pause_overlay.menu_requested.connect(_return_to_menu)
	game_over_overlay.restart_requested.connect(restart_match)
	game_over_overlay.menu_requested.connect(_return_to_menu)

func _spawn_players() -> void:
	for child: Node in players_root.get_children():
		child.queue_free()
	offense_players.clear()
	defense_players.clear()
	for index: int in range(home_team.players.size()):
		var offense_player: PlayerController = PLAYER_SCENE.instantiate()
		offense_player.setup(home_team.players[index], home_team.abbreviation, home_team.primary_color, home_team.secondary_color, true, index)
		players_root.add_child(offense_player)
		offense_players.append(offense_player)
		var defense_player: PlayerController = PLAYER_SCENE.instantiate()
		defense_player.setup(away_team.players[index], away_team.abbreviation, away_team.primary_color, away_team.secondary_color, false, index)
		players_root.add_child(defense_player)
		defense_players.append(defense_player)

func start_match() -> void:
	home_score = 0
	away_score = 0
	clock_remaining = game_config.match_length_seconds
	pending_game_over = false
	last_event_name = "match_start"
	last_turnover_type = ""
	last_possession_result = "live_offense"
	pause_hidden_clock_advanced = false
	missing_controlled_player = false
	duplicate_score_detected = false
	recent_log_lines.clear()
	_log("match start")
	_apply_scoreboard()
	_reset_possession(true)

func restart_match() -> void:
	pause_overlay.visible = false
	game_over_overlay.visible = false
	enter_state(GameState.Value.MATCH_SETUP, "restart")
	start_match()

func _return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func enter_state(next_state: int, reason: String) -> void:
	if current_state == next_state:
		return
	if next_state == GameState.Value.PAUSED:
		previous_live_state = current_state
	current_state = next_state
	match current_state:
		GameState.Value.SHOT_AIM:
			current_time_scale = game_config.aim_time_scale
		GameState.Value.PAUSED:
			current_time_scale = 0.0
			pause_overlay.visible = true
		GameState.Value.GAME_OVER:
			current_time_scale = 0.0
			pause_overlay.visible = false
			game_over_overlay.visible = true
		_:
			current_time_scale = game_config.base_time_scale
			pause_overlay.visible = false
	_log("state %s (%s)" % [GameState.label_for(current_state), reason])
	log_writer.log_event("state_transition", {"state": GameState.label_for(current_state), "reason": reason})
	_update_debug_overlay()

func _physics_process(delta: float) -> void:
	if current_state == GameState.Value.PAUSED or current_state == GameState.Value.GAME_OVER:
		_update_feedback(delta)
		_update_debug_overlay()
		return
	var scaled_delta: float = delta * current_time_scale
	_update_feedback(delta)
	if current_state != GameState.Value.MATCH_SETUP:
		_clock_tick(scaled_delta)
	match current_state:
		GameState.Value.MATCH_SETUP:
			_reset_possession(true)
		GameState.Value.LIVE_OFFENSE:
			_update_live_offense(scaled_delta)
		GameState.Value.SHOT_AIM:
			_update_shot_aim(scaled_delta)
		GameState.Value.PASS_IN_FLIGHT:
			_update_pass_flight(scaled_delta)
		GameState.Value.SHOT_IN_FLIGHT:
			_update_shot_flight(scaled_delta)
		GameState.Value.REBOUND_LIVE:
			_update_rebound_live(scaled_delta)
		GameState.Value.OPPONENT_SIM:
			_finalize_opponent_sim()
	_update_debug_overlay()

func _clock_tick(delta: float) -> void:
	if delta <= 0.0:
		return
	clock_remaining = maxf(0.0, clock_remaining - delta)
	hud.set_clock(clock_remaining)
	if clock_remaining <= 0.0 and not pending_game_over:
		if current_state in [GameState.Value.SHOT_IN_FLIGHT, GameState.Value.REBOUND_LIVE, GameState.Value.PASS_IN_FLIGHT]:
			pending_game_over = true
			_log("clock expired while resolving live ball")
		else:
			_finish_game_over()

func _reset_possession(from_setup: bool) -> void:
	pending_game_over = false if from_setup else pending_game_over
	possession_elapsed = 0.0
	stationary_pressure_time = 0.0
	pressure_check_accumulator = 0.0
	shot_hold_time = 0.0
	active_drag_vector = Vector2.ZERO
	preview_points.clear()
	active_pass_state.clear()
	active_ball_state.clear()
	rebound_timer = 0.0
	var anchors: Array[Vector2] = court_config.get_default_anchors()
	for index: int in range(offense_players.size()):
		offense_players[index].global_position = anchors[index]
		offense_players[index].desired_position = anchors[index]
		offense_players[index].set_controlled(false)
		offense_players[index].set_has_ball(false)
		var guard_target: Vector2 = DefenseController.get_guard_target(offense_players[index], court_config.get_hoop_world_position(), index == 0, defense_config)
		defense_players[index].global_position = guard_target
		defense_players[index].desired_position = guard_target
		defense_players[index].set_controlled(false)
		defense_players[index].set_has_ball(false)
	controlled_offense_index = 0
	get_controlled_player().set_controlled(true)
	get_controlled_player().set_has_ball(true)
	ball_view.set_ball_state(get_controlled_player().global_position, 34.0, ball_physics_config.ball_radius)
	last_event_name = "possession_reset"
	last_possession_result = "live_offense"
	last_turnover_type = ""
	_apply_scoreboard()
	enter_state(GameState.Value.LIVE_OFFENSE, "possession reset")
	_log("human possession reset")
	log_writer.log_event("possession_reset", {"controlled_player": get_controlled_player().player_data.player_id})

func _update_live_offense(delta: float) -> void:
	possession_elapsed += delta
	_update_route_targets()
	_update_offense_positions(delta, false)
	_update_defense_positions(delta)
	_sync_ball_to_controlled_player()
	_check_ballhandler_bounds()
	_check_pressure_turnover(delta)

func _update_shot_aim(delta: float) -> void:
	possession_elapsed += delta
	shot_hold_time += delta
	_update_route_targets()
	_update_offense_positions(delta, true)
	_update_defense_positions(delta)
	_update_shot_preview()
	_sync_ball_to_controlled_player()

func _update_pass_flight(delta: float) -> void:
	possession_elapsed += delta
	_update_route_targets()
	_update_offense_positions(delta, false)
	_update_defense_positions(delta)
	var result: Dictionary = PassController.advance_pass(active_pass_state, delta, court_config.get_playable_rect())
	ball_view.set_ball_state(active_pass_state["position"], 28.0, ball_physics_config.ball_radius)
	match result.get("type", "flying"):
		"caught":
			_control_player(int(result["player_index"]))
			get_controlled_player().set_has_ball(true)
			last_event_name = "pass_caught"
			last_possession_result = "continued_live"
			_log("pass caught by %s" % get_controlled_player().player_data.display_name)
			log_writer.log_event("pass_caught", {"receiver": get_controlled_player().player_data.player_id})
			enter_state(GameState.Value.LIVE_OFFENSE, "pass completed")
		"intercepted":
			last_event_name = "steal"
			last_turnover_type = "interception"
			last_possession_result = "turnover"
			_show_feedback("STEAL!", Color("#ff7a7a"))
			_log("pass intercepted by AWY %d" % int(result["player_index"]))
			log_writer.log_event("pass_intercepted", result)
			_start_opponent_sim("pass interception")
		"out_of_bounds":
			last_event_name = "out_of_bounds"
			last_turnover_type = "out_of_bounds"
			last_possession_result = "turnover"
			_log("pass out of bounds")
			log_writer.log_event("pass_out_of_bounds", result)
			_start_opponent_sim("pass out of bounds")

func _update_shot_flight(delta: float) -> void:
	possession_elapsed += delta
	_update_route_targets()
	_update_offense_positions(delta, false)
	_update_defense_positions(delta)
	var events: Array[Dictionary] = BallSimulator.advance_shot(active_ball_state, delta, court_config, ball_physics_config)
	ball_view.set_ball_state(active_ball_state["position_xy"], active_ball_state["z"], ball_physics_config.ball_radius)
	for event: Dictionary in events:
		match event.get("type", ""):
			"rim":
				_log("rim collision")
				log_writer.log_event("rim_collision", event)
			"backboard":
				_log("backboard collision")
				log_writer.log_event("backboard_collision", event)
			"score":
				if last_event_name == "score":
					duplicate_score_detected = true
				last_event_name = "score"
				last_possession_result = "made_basket"
				home_score += int(event["value"])
				_apply_scoreboard()
				var clean_make: bool = bool(event.get("clean", false))
				_show_feedback("SWISH!" if clean_make else "+%d" % int(event["value"]), Color("#7CFF97"))
				_log("made shot for %d" % int(event["value"]))
				log_writer.log_event("score", event)
				_start_opponent_sim("made basket")
				return
			"out_of_bounds":
				last_event_name = "out_of_bounds"
				last_turnover_type = "out_of_bounds"
				last_possession_result = "turnover"
				_start_opponent_sim("shot out of bounds")
				return
			"landed":
				last_event_name = "shot_miss"
				last_possession_result = "rebound_pending"
				_show_feedback("BRICK!", Color("#ffd166"))
				_begin_rebound(BallSimulator.build_ball_state(active_ball_state["position_xy"], Vector2.ZERO, 0.0, 0.0), false)
				return

func _update_rebound_live(delta: float) -> void:
	rebound_timer += delta
	for player: PlayerController in offense_players:
		_move_player_toward(player, rebound_target, delta, rebound_config.pursuit_speed_multiplier)
	for player: PlayerController in defense_players:
		_move_player_toward(player, rebound_target, delta, rebound_config.pursuit_speed_multiplier)
	ball_view.set_ball_state(rebound_target, 0.0, ball_physics_config.ball_radius)
	if rebound_timer >= rebound_config.resolve_delay:
		var result: Dictionary = ReboundController.choose_winner(offense_players, defense_players, rebound_target, rebound_config, difficulty_profile, rng)
		_log("rebound won by %s %d" % [result["side"], int(result["index"])])
		log_writer.log_event("rebound_result", result)
		if result["side"] == "offense":
			last_event_name = "offensive_rebound"
			last_possession_result = "offensive_rebound"
			_control_player(int(result["index"]))
			get_controlled_player().global_position = rebound_target
			get_controlled_player().set_has_ball(true)
			ball_view.set_ball_state(rebound_target, 34.0, ball_physics_config.ball_radius)
			enter_state(GameState.Value.LIVE_OFFENSE, "offensive rebound")
		else:
			last_event_name = "defensive_rebound"
			last_possession_result = "defensive_rebound"
			_start_opponent_sim("defensive rebound")

func _update_route_targets() -> void:
	route_targets = RouteController.get_route_targets(court_config, get_controlled_player().global_position, possession_elapsed, route_config)

func _update_offense_positions(delta: float, freeze_ballhandler: bool) -> void:
	var movement_input: Vector2 = joystick_vector
	if OS.is_debug_build():
		movement_input += input_controller.get_keyboard_vector() * game_config.keyboard_debug_speed_factor
	movement_input = movement_input.limit_length(1.0)
	for player: PlayerController in offense_players:
		if player.player_index == controlled_offense_index:
			if freeze_ballhandler:
				player.desired_position = player.global_position
			else:
				var target := player.global_position + movement_input * player.get_speed_units() * delta
				player.global_position = target
				player.desired_position = player.global_position
		else:
			var target_pos: Vector2 = route_targets[player.player_index]
			player.route_debug_target = target_pos
			_move_player_toward(player, target_pos, delta)

func _update_defense_positions(delta: float) -> void:
	route_debug_pairs.clear()
	var hoop_pos: Vector2 = court_config.get_hoop_world_position()
	for index: int in range(defense_players.size()):
		var is_on_ball: bool = index == controlled_offense_index
		var defense_target: Vector2 = DefenseController.get_guard_target(offense_players[index], hoop_pos, is_on_ball, defense_config)
		defense_players[index].assignment_debug_target = offense_players[index].global_position
		_move_player_toward(defense_players[index], defense_target, delta, difficulty_profile.get("defense", 1.0))
		var pair := PackedVector2Array([defense_players[index].global_position, offense_players[index].global_position])
		route_debug_pairs.append(pair)

func _move_player_toward(player: PlayerController, target_pos: Vector2, delta: float, speed_multiplier: float = 1.0) -> void:
	var speed: float = player.get_speed_units() * speed_multiplier
	player.global_position = _clamp_to_court(player.global_position.move_toward(target_pos, speed * delta))
	player.desired_position = target_pos

func _sync_ball_to_controlled_player() -> void:
	ball_view.set_ball_state(get_controlled_player().global_position, 34.0, ball_physics_config.ball_radius)
	for player: PlayerController in offense_players:
		player.set_has_ball(player.player_index == controlled_offense_index and current_state in [GameState.Value.LIVE_OFFENSE, GameState.Value.SHOT_AIM])

func _check_ballhandler_bounds() -> void:
	if not court_config.get_playable_rect().has_point(get_controlled_player().global_position):
		last_event_name = "out_of_bounds"
		last_turnover_type = "out_of_bounds"
		last_possession_result = "turnover"
		_log("ballhandler out of bounds")
		log_writer.log_event("ballhandler_out_of_bounds", {"player": get_controlled_player().player_data.player_id})
		_start_opponent_sim("ballhandler out of bounds")

func _check_pressure_turnover(delta: float) -> void:
	if joystick_vector.length() <= 0.1 and input_controller.get_keyboard_vector().length() <= 0.1:
		stationary_pressure_time += delta
	else:
		stationary_pressure_time = 0.0
	pressure_check_accumulator += delta
	if pressure_check_accumulator < defense_config.pressure_check_interval:
		return
	pressure_check_accumulator = 0.0
	var on_ball_defender: PlayerController = defense_players[controlled_offense_index]
	if DefenseController.should_force_pressure_turnover(get_controlled_player(), on_ball_defender, stationary_pressure_time, defense_config, difficulty_profile.get("defense", 1.0), rng):
		last_event_name = "steal"
		last_turnover_type = "pressure_turnover"
		last_possession_result = "turnover"
		_show_feedback("STEAL!", Color("#ff7a7a"))
		_log("pressure turnover")
		log_writer.log_event("pressure_turnover", {"player": get_controlled_player().player_data.player_id})
		_start_opponent_sim("pressure turnover")

func _update_shot_preview() -> void:
	var contest_info: Dictionary = DefenseController.get_contest_info(get_controlled_player(), defense_players, court_config.get_hoop_world_position(), defense_config)
	current_shot_quality = ShotController.get_release_quality(shot_hold_time, get_controlled_player().get_release_consistency(), contest_info["strength"], shot_timing_config)
	var direction: Vector2 = -active_drag_vector.normalized() if active_drag_vector.length() > 0.001 else Vector2.UP
	var power_ratio: float = ShotController.drag_to_power_ratio(active_drag_vector.length(), shot_timing_config)
	var velocity_xy: Vector2 = direction * lerpf(ball_physics_config.shot_min_speed, ball_physics_config.shot_max_speed, power_ratio)
	var z_velocity: float = lerpf(ball_physics_config.shot_min_vz, ball_physics_config.shot_max_vz, power_ratio)
	var shot_value: int = _get_shot_value(get_controlled_player().global_position)
	preview_points = BallSimulator.generate_preview_points(get_controlled_player().global_position, velocity_xy, z_velocity, shot_value, court_config, ball_physics_config)

func _begin_rebound(ball_state: Dictionary, was_blocked: bool) -> void:
	rebound_target = ReboundController.estimate_landing_zone(ball_state)
	rebound_timer = 0.0
	preview_points.clear()
	active_ball_state.clear()
	if was_blocked:
		last_event_name = "block"
		last_possession_result = "rebound_pending"
		log_writer.log_event("shot_blocked", {"target": rebound_target})
	enter_state(GameState.Value.REBOUND_LIVE, "rebound live")

func _start_opponent_sim(reason: String) -> void:
	preview_points.clear()
	active_pass_state.clear()
	active_ball_state.clear()
	enter_state(GameState.Value.OPPONENT_SIM, reason)

func _finalize_opponent_sim() -> void:
	var result: Dictionary = OpponentSimController.simulate_possession(away_team, home_team, opponent_sim_config, difficulty_profile, clock_remaining, rng)
	away_score += int(result["score_delta"])
	clock_remaining = maxf(0.0, clock_remaining - float(result["time_used"]))
	_apply_scoreboard()
	hud.set_clock(clock_remaining)
	for event_line: String in result["events"]:
		log_writer.log_sim_line(event_line)
		_log(event_line)
	last_event_name = "opponent_sim"
	log_writer.log_event("opponent_sim", result)
	if clock_remaining <= 0.0:
		_finish_game_over()
		return
	_reset_possession(false)

func _finish_game_over() -> void:
	enter_state(GameState.Value.GAME_OVER, "clock expired")
	var result_text: String = "TIE GAME"
	if home_score > away_score:
		result_text = "HOME WINS"
	elif away_score > home_score:
		result_text = "AWAY WINS"
	game_over_overlay.set_summary(result_text, "%s %d - %s %d" % [home_team.abbreviation, home_score, away_team.abbreviation, away_score])
	log_writer.log_event("game_over", {"home": home_score, "away": away_score})

func _on_joystick_vector_changed(vector: Vector2) -> void:
	joystick_vector = vector
	log_writer.log_event("joystick", {"vector": {"x": vector.x, "y": vector.y}})

func _on_action_started(world_pos: Vector2) -> void:
	if current_state != GameState.Value.LIVE_OFFENSE:
		return
	shot_action_armed = world_pos.distance_to(get_controlled_player().global_position) <= game_config.player_radius * 1.35

func _on_action_dragged(start_pos: Vector2, current_pos: Vector2) -> void:
	if current_state == GameState.Value.LIVE_OFFENSE and shot_action_armed:
		var drag_distance: float = start_pos.distance_to(current_pos)
		if drag_distance >= shot_timing_config.activation_drag_distance:
			shot_hold_time = 0.0
			active_drag_vector = current_pos - get_controlled_player().global_position
			enter_state(GameState.Value.SHOT_AIM, "shot aim start")
			log_writer.log_event("shot_aim_start", {"player": get_controlled_player().player_data.player_id})
	elif current_state == GameState.Value.SHOT_AIM:
		active_drag_vector = current_pos - get_controlled_player().global_position
		_update_shot_preview()
		log_writer.log_event("shot_aim_update", {"drag_length": active_drag_vector.length(), "quality": current_shot_quality.get("label", "red")})

func _on_action_released(start_pos: Vector2, end_pos: Vector2, moved_distance: float) -> void:
	if current_state == GameState.Value.SHOT_AIM:
		_resolve_shot_aim_release(end_pos)
		shot_action_armed = false
		return
	if current_state != GameState.Value.LIVE_OFFENSE:
		return
	if moved_distance <= pass_config.tap_max_motion:
		var teammate_index: int = PassController.get_tapped_teammate(offense_players, end_pos, controlled_offense_index, pass_config.catch_radius)
		if teammate_index >= 0:
			_start_pass(teammate_index)
	shot_action_armed = false

func _resolve_shot_aim_release(release_pos: Vector2) -> void:
	var pass_target: int = ShotController.release_endpoint_pass_target(release_pos, offense_players, controlled_offense_index, shot_timing_config.pass_conversion_catch_radius)
	if pass_target >= 0 and pass_config.release_endpoint_pass_conversion:
		_start_pass(pass_target)
		return
	if active_drag_vector.length() < shot_timing_config.min_shot_drag_distance:
		preview_points.clear()
		enter_state(GameState.Value.LIVE_OFFENSE, "shot aim cancel")
		log_writer.log_event("shot_cancel", {})
		return
	_release_shot()

func _release_shot() -> void:
	var contest_info: Dictionary = DefenseController.get_contest_info(get_controlled_player(), defense_players, court_config.get_hoop_world_position(), defense_config)
	current_shot_quality = ShotController.get_release_quality(shot_hold_time, get_controlled_player().get_release_consistency(), contest_info["strength"], shot_timing_config)
	var block_candidate: int = DefenseController.get_block_candidate(get_controlled_player(), defense_players, defense_config)
	var block_strength: float = float(contest_info["strength"])
	if block_candidate >= 0 and block_strength > 0.74 and rng.randf() <= 0.22 * block_strength:
		_show_feedback("BLOCK!", Color("#8ecae6"))
		_begin_rebound(BallSimulator.build_ball_state(get_controlled_player().global_position + Vector2(0.0, -22.0), Vector2(0.0, 90.0), 0.0, 0.0), true)
		return
	var shot_value: int = _get_shot_value(get_controlled_player().global_position)
	var launch: Dictionary = ShotController.build_launch(get_controlled_player().global_position, active_drag_vector, get_controlled_player(), contest_info["strength"], current_shot_quality, shot_timing_config, ball_physics_config, rng)
	active_ball_state = BallSimulator.build_ball_state(launch["origin"], launch["velocity_xy"], 34.0, launch["vz"], shot_value)
	preview_points.clear()
	last_event_name = "shot_release"
	log_writer.log_event("shot_release", {
		"player": get_controlled_player().player_data.player_id,
		"quality": current_shot_quality["label"],
		"power_ratio": launch["power_ratio"],
		"shot_value": shot_value,
		"angle_error": launch["angle_error"],
		"power_error": launch["power_error"],
	})
	enter_state(GameState.Value.SHOT_IN_FLIGHT, "shot released")

func _start_pass(receiver_index: int) -> void:
	if receiver_index < 0 or receiver_index >= offense_players.size():
		return
	preview_points.clear()
	var start_pos: Vector2 = get_controlled_player().global_position
	var receiver: PlayerController = offense_players[receiver_index]
	var interceptor: Dictionary = PassController.find_best_interceptor(start_pos, receiver.global_position, defense_players, pass_config, difficulty_profile.get("defense", 1.0))
	active_pass_state = PassController.build_pass(start_pos, receiver.global_position, controlled_offense_index, receiver_index, pass_config.speed, interceptor["index"], interceptor["point"])
	for player: PlayerController in offense_players:
		player.set_has_ball(false)
		player.set_controlled(false)
	last_event_name = "pass_start"
	log_writer.log_event("pass_start", {
		"passer": offense_players[controlled_offense_index].player_data.player_id,
		"receiver": receiver.player_data.player_id,
		"distance": start_pos.distance_to(receiver.global_position),
		"interceptor_index": interceptor["index"],
	})
	_log("pass from %s to %s" % [offense_players[controlled_offense_index].player_data.display_name, receiver.player_data.display_name])
	enter_state(GameState.Value.PASS_IN_FLIGHT, "pass start")

func _control_player(index: int) -> void:
	controlled_offense_index = index
	for player: PlayerController in offense_players:
		player.set_controlled(player.player_index == controlled_offense_index)
		player.set_has_ball(player.player_index == controlled_offense_index)

func _get_shot_value(release_position: Vector2) -> int:
	return 3 if release_position.distance_to(court_config.get_hoop_world_position()) >= court_config.three_point_radius else 2

func _apply_scoreboard() -> void:
	hud.set_score(home_team.abbreviation, home_score, away_team.abbreviation, away_score)
	hud.set_clock(clock_remaining)

func _on_pause_requested() -> void:
	if current_state == GameState.Value.GAME_OVER:
		return
	if current_state == GameState.Value.PAUSED:
		_resume_from_pause()
	else:
		paused_clock_reference = clock_remaining
		enter_state(GameState.Value.PAUSED, "pause requested")
		last_event_name = "pause"
		log_writer.log_event("pause", {})

func _resume_from_pause() -> void:
	if current_state != GameState.Value.PAUSED:
		return
	pause_overlay.visible = false
	enter_state(previous_live_state, "resume")
	last_event_name = "resume"
	log_writer.log_event("resume", {})

func _on_debug_toggled() -> void:
	debug_overlay_visible = not debug_overlay_visible
	debug_overlay.visible = debug_overlay_visible

func _show_feedback(text: String, color: Color) -> void:
	feedback_timer = game_config.feedback_duration
	feedback_color = color
	last_feedback_text = text
	feedback_label.text = text
	feedback_label.modulate = color
	feedback_label.visible = true

func _update_feedback(delta: float) -> void:
	if feedback_timer <= 0.0:
		feedback_label.visible = false
		return
	feedback_timer -= delta
	feedback_label.visible = true
	feedback_label.modulate = Color(feedback_color.r, feedback_color.g, feedback_color.b, clampf(feedback_timer / game_config.feedback_duration, 0.35, 1.0))

func _update_debug_overlay() -> void:
	var snapshot: Dictionary = get_debug_snapshot()
	snapshot["lines"] = []
	snapshot["circles"] = []
	snapshot["points"] = []
	debug_overlay.update_snapshot(snapshot)
	court_view.update_debug(route_targets, route_debug_pairs, rebound_target, current_state == GameState.Value.REBOUND_LIVE, preview_points, debug_overlay_visible and debug_config.show_route_geometry, debug_overlay_visible and debug_config.show_defender_assignments)

func _clamp_to_court(position_value: Vector2) -> Vector2:
	var rect: Rect2 = court_config.get_playable_rect()
	return Vector2(clampf(position_value.x, rect.position.x, rect.end.x), clampf(position_value.y, rect.position.y, rect.end.y))

func _log(line: String) -> void:
	recent_log_lines.append(line)
	if recent_log_lines.size() > 16:
		recent_log_lines.pop_front()
	log_writer.log_line(line)

func get_recent_logs() -> Array[String]:
	return recent_log_lines.duplicate()

func get_controlled_player() -> PlayerController:
	return offense_players[controlled_offense_index]

func get_state_name() -> String:
	return GameState.label_for(current_state).to_lower()

func get_home_score() -> int:
	return home_score

func get_away_score() -> int:
	return away_score

func get_time_scale() -> float:
	return current_time_scale

func get_clock_remaining() -> float:
	return clock_remaining

func get_player_by_id(player_id: String) -> PlayerController:
	for player: PlayerController in offense_players:
		if player.player_data.player_id == player_id:
			return player
	for player: PlayerController in defense_players:
		if player.player_data.player_id == player_id:
			return player
	return null

func request_pass_to_player_id(player_id: String) -> void:
	var player: PlayerController = get_player_by_id(player_id)
	if player != null and offense_players.has(player) and player.player_index != controlled_offense_index:
		_start_pass(player.player_index)

func start_debug_shot_drag(offset: Vector2) -> void:
	shot_action_armed = true
	active_drag_vector = offset
	shot_hold_time = 0.0
	enter_state(GameState.Value.SHOT_AIM, "debug shot start")
	_update_shot_preview()

func update_debug_shot_drag(offset: Vector2) -> void:
	active_drag_vector = offset
	_update_shot_preview()

func release_debug_shot_drag(release_point: Vector2) -> void:
	_resolve_shot_aim_release(release_point)

func simulate_for(duration: float, step: float = 1.0 / 60.0) -> void:
	var remaining: float = duration
	while remaining > 0.0:
		var frame: float = minf(step, remaining)
		_physics_process(frame)
		remaining -= frame

func begin_test_mode(options: Dictionary = {}) -> void:
	var setup_data: Dictionary = options.get("setup_data", {})
	test_mode_enabled = true
	rng.seed = int(options.get("seed", 3960))
	start_match()
	clock_remaining = float(setup_data.get("clock_seconds", options.get("clock_seconds", clock_remaining)))
	_apply_scoreboard()
	var ballhandler_alias: String = String(setup_data.get("ballhandler", options.get("ballhandler", "pg")))
	var ballhandler_index: int = _alias_to_offense_index(ballhandler_alias)
	_control_player(ballhandler_index)
	if setup_data.get("pressure", options.get("pressure", "")) == "smothered":
		defense_players[controlled_offense_index].global_position = get_controlled_player().global_position + Vector2(20.0, 20.0)
	if setup_data.get("contest_preset", options.get("contest_preset", "")) == "tight_closeout":
		defense_players[controlled_offense_index].global_position = get_controlled_player().global_position + Vector2(12.0, -18.0)
	if setup_data.get("boundary", options.get("boundary", "")) == "left_sideline":
		get_controlled_player().global_position.x = court_config.get_playable_rect().position.x + 24.0
	if setup_data.get("state", options.get("state", "")) == "shot_aim":
		start_debug_shot_drag(Vector2(0.0, 180.0))
		_update_shot_preview()
	last_event_name = "test_mode_begin"

func apply_bot_action(action: ScenarioAction) -> Dictionary:
	match action.action_type:
		ScenarioAction.ActionType.WAIT:
			_simulate_until(action.duration_seconds, [GameState.Value.OPPONENT_SIM, GameState.Value.GAME_OVER])
		ScenarioAction.ActionType.JOYSTICK:
			joystick_vector = action.vector
			_simulate_until(action.duration_seconds, [GameState.Value.OPPONENT_SIM, GameState.Value.GAME_OVER])
			joystick_vector = Vector2.ZERO
		ScenarioAction.ActionType.TAP_TEAMMATE:
			var target_alias: String = String(action.payload.get("target_id", "sg"))
			if String(action.payload.get("lane", "")) == "covered_cross_court":
				var lane_target: PlayerController = offense_players[_alias_to_offense_index(target_alias)]
				defense_players[min(2, defense_players.size() - 1)].global_position = get_controlled_player().global_position.lerp(lane_target.global_position, 0.52)
			request_pass_to_player_id(_alias_to_player_id(target_alias))
			_simulate_until(1.2, [GameState.Value.LIVE_OFFENSE, GameState.Value.OPPONENT_SIM, GameState.Value.GAME_OVER])
		ScenarioAction.ActionType.HOLD_SHOT:
			if String(action.payload.get("contest_level", "")) == "high":
				defense_players[controlled_offense_index].global_position = get_controlled_player().global_position + Vector2(10.0, -16.0)
			start_debug_shot_drag(action.vector if action.vector.length() > 0.01 else Vector2(0.0, 180.0))
			_simulate_until(action.duration_seconds, [GameState.Value.OPPONENT_SIM, GameState.Value.GAME_OVER])
		ScenarioAction.ActionType.RELEASE_SHOT:
			if action.payload.has("release_quality"):
				_force_release_quality(String(action.payload["release_quality"]))
			release_debug_shot_drag(get_controlled_player().global_position + active_drag_vector)
			_simulate_until(3.0, [GameState.Value.OPPONENT_SIM, GameState.Value.REBOUND_LIVE, GameState.Value.GAME_OVER])
		ScenarioAction.ActionType.PAUSE:
			if String(action.payload.get("state_before_pause", "")) == "shot_aim" and current_state != GameState.Value.SHOT_AIM:
				start_debug_shot_drag(Vector2(0.0, 180.0))
				_simulate_until(0.15, [])
			paused_clock_reference = clock_remaining
			_on_pause_requested()
		ScenarioAction.ActionType.RESUME:
			_resume_from_pause()
		ScenarioAction.ActionType.CUSTOM:
			_run_custom_bot_loop(action.payload)
	return get_debug_snapshot()

func get_debug_snapshot() -> Dictionary:
	var controlled_id: String = get_controlled_player().player_data.player_id if offense_players.size() > 0 else "none"
	return {
		"state": get_state_name(),
		"score": {"home": home_score, "away": away_score},
		"last_event": last_event_name,
		"turnover": {"type": last_turnover_type},
		"possession": {"result": last_possession_result},
		"feedback_text": last_feedback_text,
		"time_scale": current_time_scale,
		"pause": {"hidden_clock_advanced": pause_hidden_clock_advanced},
		"stability": {
			"softlock_detected": false,
			"missing_controlled_player": missing_controlled_player,
			"duplicate_score_detected": duplicate_score_detected,
		},
		"game_state": get_state_name(),
		"rng_seed": rng.seed,
		"seed": rng.seed,
		"controlled_player": controlled_id,
		"shot_preview": preview_points.size(),
		"route_geometry": route_targets.size(),
		"defender_assignments": route_debug_pairs.size(),
		"contest_radii": defense_config.contest_radius,
		"catch_radii": pass_config.catch_radius,
		"intercept_corridors": pass_config.intercept_lane_width,
		"rebound_zone": rebound_target,
	}

func get_match_log_context() -> Dictionary:
	return {
		"recent_logs": get_recent_logs(),
		"snapshot": get_debug_snapshot(),
	}

func _simulate_until(duration: float, stop_states: Array[int]) -> void:
	var remaining: float = duration
	while remaining > 0.0:
		var frame: float = minf(1.0 / 60.0, remaining)
		var before_clock: float = clock_remaining
		_physics_process(frame)
		if current_state == GameState.Value.PAUSED and absf(clock_remaining - before_clock) > 0.0001:
			pause_hidden_clock_advanced = true
		remaining -= frame
		if stop_states.has(current_state):
			break

func _alias_to_offense_index(alias: String) -> int:
	match alias:
		"pg":
			return 0
		"sg", "wing_left":
			return 1
		"sf", "wing_right":
			return 2
		"pf", "corner_left":
			return 3
		"c", "corner_right":
			return 4
		_:
			return 0

func _alias_to_player_id(alias: String) -> String:
	return home_team.players[_alias_to_offense_index(alias)].player_id

func _force_release_quality(target: String) -> void:
	var contest_info: Dictionary = DefenseController.get_contest_info(get_controlled_player(), defense_players, court_config.get_hoop_world_position(), defense_config)
	var preview_quality: Dictionary = ShotController.get_release_quality(shot_hold_time, get_controlled_player().get_release_consistency(), contest_info["strength"], shot_timing_config)
	var center: float = float(preview_quality["center"])
	var width: float = float(preview_quality["width"])
	match target.to_lower():
		"green":
			shot_hold_time = center
		"yellow":
			shot_hold_time = center + width * 0.18
		_:
			shot_hold_time = center + width * 0.42

func _run_custom_bot_loop(payload: Dictionary) -> void:
	var possessions: int = int(payload.get("possessions", 20))
	for index: int in range(possessions):
		if current_state == GameState.Value.GAME_OVER:
			break
		start_debug_shot_drag(Vector2(0.0, 170.0 + float(index % 3) * 18.0))
		_force_release_quality("green" if index % 2 == 0 else "yellow")
		release_debug_shot_drag(get_controlled_player().global_position + active_drag_vector)
		_simulate_until(3.5, [GameState.Value.OPPONENT_SIM, GameState.Value.GAME_OVER])
		if current_state == GameState.Value.OPPONENT_SIM:
			_physics_process(1.0 / 60.0)
		if offense_players.is_empty() or get_controlled_player() == null:
			missing_controlled_player = true
			break
