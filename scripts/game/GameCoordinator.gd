class_name GameCoordinator
extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/Player.tscn")
const BALL_SCENE: PackedScene = preload("res://scenes/entities/Ball.tscn")
const HOOP_SCENE: PackedScene = preload("res://scenes/entities/Hoop.tscn")
const OPPONENT_SIM_PRESENTATION_SCENE: PackedScene = preload("res://scenes/entities/OpponentSimPresentation.tscn")
const PLAYER_ANIMATION_CONFIG_SCRIPT = preload("res://scripts/config/PlayerAnimationConfig.gd")
const PLAYER_VISUAL_REQUEST_SCRIPT = preload("res://scripts/entities/PlayerVisualRequest.gd")
const INPUT_CONFIG_SCRIPT = preload("res://scripts/config/InputConfig.gd")
const COURT_PROJECTION_SCRIPT = preload("res://scripts/game/CourtProjection.gd")
const BASE_PRESENTATION_SIZE: Vector2 = Vector2(1080.0, 1920.0)
const SCOREBOARD_ART_SIZE: Vector2 = Vector2(1098.0, 248.0)
const SCORE_FOLLOWTHROUGH_HANDOFF_MIN_DURATION: float = 0.06
const SCORE_FOLLOWTHROUGH_HANDOFF_MAX_DURATION: float = 0.16
const SCORE_FOLLOWTHROUGH_HANDOFF_DURATION_RATIO: float = 0.5
const SCORE_FOLLOWTHROUGH_HANDOFF_CLEAR_EPSILON: float = 0.75
const SCORE_FOLLOWTHROUGH_PRE_BOUNCE_CONTINUITY_EPSILON: float = 0.1
const SHOT_TIMING_MODE_ANIMATION_GATED: String = "animation_gated"
const SHOT_TIMING_MODE_DIRECT_SHOOT_BUTTON: String = "direct_shoot_button"

enum BallVisualMode {
	HIDDEN_WHILE_OWNED,
	WORLD_VISIBLE,
}

var game_config: GameConfig
var court_config: CourtConfig
var projection_config: ProjectionConfig
var input_config
var ball_config: BallPhysicsConfig
var shot_config: ShotTimingConfig
var pass_config: PassConfig
var route_config: RouteConfig
var defense_config: DefenseConfig
var rebound_config: ReboundConfig
var opponent_sim_config: OpponentSimConfig
var difficulty_config: DifficultyConfig
var player_animation_config
var debug_config: DebugConfig

var home_team: TeamData
var away_team: TeamData

var context: MatchContext = MatchContext.new()
var rng: GameRng
var visual_rng: GameRng
var log_writer: LogWriter

var shot_controller: ShotController = ShotController.new()
var pass_controller: PassController = PassController.new()
var route_controller: RouteController = RouteController.new()
var defense_controller: DefenseController = DefenseController.new()
var rebound_controller: ReboundController = ReboundController.new()
var opponent_sim_controller: OpponentSimController = OpponentSimController.new()
var ball_simulator: BallSimulator = BallSimulator.new()
var hoop_resolver: HoopResolver
var court_projection

var court_view: CourtView
var entities_node: Node2D
var systems_node: Node
var ui_root: CanvasLayer
var input_controller: InputController
var hud: HUD
var control_panel: Control
var opponent_sim_banner
var pause_overlay: PauseOverlay
var game_over_overlay: GameOverOverlay
var feedback_text: FeedbackText
var debug_overlay: DebugOverlay

var offense_players: Array[PlayerController] = []
var defense_players: Array[PlayerController] = []
var ball_node: BallController
var hoop_node: HoopView
var opponent_sim_presentation: Node
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
var steal_resolve_timer: float = 0.0
var score_followthrough_state: Dictionary = {}
var current_ball_render_phase: String = ""
var last_scored_shot_passed_through_net: bool = false
var current_steal_holder: PlayerController
var last_pass_resolution_point: Vector2 = Vector2.INF
var last_pass_resolution_outcome: String = ""
var last_pass_commit_chance: float = 0.0
var last_pass_commit_succeeded: bool = false
var last_pass_eligible_interceptor_name: String = ""
var last_pass_committed_interceptor_name: String = ""
var player_visual_memory: Dictionary = {}
var shot_visual_locks: Dictionary = {}
var active_shot_sequence: Dictionary = {}
var active_dunk_root_motion: Dictionary = {}
var pending_shot_release: Dictionary = {}
var ball_visual_mode: int = BallVisualMode.HIDDEN_WHILE_OWNED
var ball_visual_owner: PlayerController
var default_pass_target: PlayerController
var default_pass_target_details: Dictionary = {}
var layout_metrics: Dictionary = {}
var camera_tracking_signature: String = ""
var finish_logic_center_world_cached: Vector2 = Vector2.INF
var finish_logic_center_screen_cached: Vector2 = Vector2.INF
var defenders_disabled: bool = false
var controls_visible: bool = true
var opponent_sim_match_ui_hidden: bool = false
var opponent_sim_live_entities_hidden: bool = false
var pending_opponent_sim_result: Dictionary = {}
var opponent_sim_visual_steps: Array[Dictionary] = []
var opponent_sim_visual_index: int = -1
var opponent_sim_visual_timer: float = 0.0


func _ready() -> void:
	_resolve_nodes()
	_connect_viewport_size_signal()
	_load_resources()
	_build_services()
	_apply_responsive_layout(false)
	_spawn_entities()
	_wire_input_and_ui()
	_start_new_match()


func _resolve_nodes() -> void:
	var root: Node = get_parent()
	court_view = root.get_node("CourtView") as CourtView
	entities_node = root.get_node("Entities") as Node2D
	systems_node = root.get_node("Systems")
	ui_root = root.get_node("UIRoot") as CanvasLayer
	hud = ui_root.get_node("HUD") as HUD
	control_panel = ui_root.get_node("ControlPanel") as Control
	opponent_sim_banner = ui_root.get_node("OpponentSimBanner")
	pause_overlay = ui_root.get_node("PauseOverlay") as PauseOverlay
	game_over_overlay = ui_root.get_node("GameOverOverlay") as GameOverOverlay
	feedback_text = ui_root.get_node("FeedbackText") as FeedbackText
	debug_overlay = root.get_node("DebugOverlay") as DebugOverlay
	input_controller = systems_node.get_node("InputController") as InputController


func _connect_viewport_size_signal() -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null or viewport.size_changed.is_connected(_on_viewport_size_changed):
		return
	viewport.size_changed.connect(_on_viewport_size_changed)


func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()


func _load_resources() -> void:
	game_config = _load_or_default("res://data/config/GameConfig.tres", GameConfig.new()) as GameConfig
	court_config = _load_or_default("res://data/config/CourtConfig.tres", CourtConfig.new()) as CourtConfig
	projection_config = _load_or_default("res://data/config/ProjectionConfig.tres", ProjectionConfig.new()) as ProjectionConfig
	input_config = _load_or_default("res://data/config/InputConfig.tres", INPUT_CONFIG_SCRIPT.new())
	ball_config = _load_or_default("res://data/config/BallPhysicsConfig.tres", BallPhysicsConfig.new()) as BallPhysicsConfig
	shot_config = _load_or_default("res://data/config/ShotTimingConfig.tres", ShotTimingConfig.new()) as ShotTimingConfig
	pass_config = _load_or_default("res://data/config/PassConfig.tres", PassConfig.new()) as PassConfig
	route_config = _load_or_default("res://data/config/RouteConfig.tres", RouteConfig.new()) as RouteConfig
	defense_config = _load_or_default("res://data/config/DefenseConfig.tres", DefenseConfig.new()) as DefenseConfig
	rebound_config = _load_or_default("res://data/config/ReboundConfig.tres", ReboundConfig.new()) as ReboundConfig
	opponent_sim_config = _load_or_default("res://data/config/OpponentSimConfig.tres", OpponentSimConfig.new()) as OpponentSimConfig
	difficulty_config = _load_or_default("res://data/config/DifficultyConfig.tres", DifficultyConfig.new()) as DifficultyConfig
	player_animation_config = _load_or_default("res://data/config/PlayerAnimationConfig.tres", PLAYER_ANIMATION_CONFIG_SCRIPT.new())
	debug_config = _load_or_default("res://data/config/DebugConfig.tres", DebugConfig.new()) as DebugConfig
	home_team = _resolve_team_from_roster(true)
	away_team = _resolve_team_from_roster(false)
	if home_team == null or home_team.players.is_empty():
		home_team = _create_default_team(true)
	if away_team == null or away_team.players.is_empty():
		away_team = _create_default_team(false)


func _apply_responsive_layout(sync_visuals: bool = true) -> void:
	layout_metrics = _build_layout_metrics()
	if court_projection != null:
		court_projection.apply_screen_layout(
			layout_metrics.get("court_screen_rect", Rect2(Vector2.ZERO, BASE_PRESENTATION_SIZE)),
			float(layout_metrics.get("presentation_scale", 1.0)),
			layout_metrics.get("viewport_rect", Rect2(Vector2.ZERO, BASE_PRESENTATION_SIZE))
		)
	if court_view != null:
		court_view.apply_layout(layout_metrics)
	if hud != null:
		hud.apply_layout(layout_metrics)
	if control_panel != null:
		control_panel.apply_layout(layout_metrics)
	if opponent_sim_banner != null:
		opponent_sim_banner.apply_layout(layout_metrics)
	if input_controller != null:
		input_controller.set_control_layout(layout_metrics)
	if sync_visuals:
		_sync_projection_visuals()
	elif court_view != null:
		court_view.queue_redraw()
	if debug_overlay != null:
		debug_overlay.queue_redraw()


func _build_layout_metrics() -> Dictionary:
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var safe_rect: Rect2 = _resolve_safe_rect(viewport_rect)
	var ui_scale: float = clampf(safe_rect.size.x / BASE_PRESENTATION_SIZE.x, 0.82, 1.0)
	var control_panel_rect: Rect2 = _build_control_panel_rect(safe_rect, ui_scale)
	var control_zone_rects: Dictionary = _build_control_zone_rects(control_panel_rect, ui_scale)
	var shoot_rect: Rect2 = control_zone_rects.get("shoot", Rect2())
	var board_width: float = maxf(shoot_rect.size.x, 1.0)
	var board_height: float = board_width * SCOREBOARD_ART_SIZE.y / SCOREBOARD_ART_SIZE.x
	var board_x: float = shoot_rect.position.x if shoot_rect.size.x > 0.0 else safe_rect.position.x + 12.0 * ui_scale
	var board_y: float = maxf(
		safe_rect.position.y + 8.0 * ui_scale,
		control_panel_rect.position.y - 12.0 * ui_scale - board_height
	)
	var banner_rect: Rect2 = Rect2(Vector2(board_x, board_y), Vector2(board_width, board_height))
	var pause_button_size: Vector2 = Vector2(board_height, board_height)
	var pause_button_x: float = clampf(
		control_panel_rect.end.x - pause_button_size.x,
		safe_rect.position.x,
		maxf(safe_rect.end.x - pause_button_size.x, safe_rect.position.x)
	)
	var pause_button_rect: Rect2 = Rect2(Vector2(pause_button_x, board_y), pause_button_size)
	var play_inset: float = 12.0 * ui_scale
	var play_top: float = safe_rect.position.y + play_inset
	var play_bottom: float = maxf(safe_rect.end.y - play_inset, play_top)
	var available_play_rect: Rect2 = Rect2(
		Vector2(safe_rect.position.x, play_top),
		Vector2(safe_rect.size.x, maxf(play_bottom - play_top, 1.0))
	)
	var court_screen_rect: Rect2 = _fit_rect_inside(available_play_rect, BASE_PRESENTATION_SIZE)
	var presentation_scale: float = maxf(court_screen_rect.size.x / BASE_PRESENTATION_SIZE.x, 0.01)
	return {
		"viewport_rect": viewport_rect,
		"safe_rect": safe_rect,
		"banner_rect": banner_rect,
		"pause_button_rect": pause_button_rect,
		"available_play_rect": available_play_rect,
		"court_screen_rect": court_screen_rect,
		"control_panel_rect": control_panel_rect,
		"control_zone_rects": control_zone_rects,
		"presentation_scale": presentation_scale,
		"ui_scale": ui_scale,
	}


func _build_control_panel_rect(safe_rect: Rect2, ui_scale: float) -> Rect2:
	var horizontal_margin: float = float(input_config.control_panel_horizontal_margin if input_config != null else 12.0) * ui_scale
	var bottom_margin: float = float(input_config.control_panel_bottom_margin if input_config != null else 16.0) * ui_scale
	var panel_height: float = safe_rect.size.y * float(input_config.control_panel_height_ratio if input_config != null else 0.24)
	return Rect2(
		Vector2(safe_rect.position.x + horizontal_margin, safe_rect.end.y - panel_height - bottom_margin),
		Vector2(maxf(safe_rect.size.x - horizontal_margin * 2.0, 1.0), maxf(panel_height, 1.0))
	)


func _build_control_zone_rects(control_panel_rect: Rect2, ui_scale: float) -> Dictionary:
	var gutter: float = float(input_config.control_panel_gutter if input_config != null else 10.0) * ui_scale
	var top_row_ratio: float = clampf(float(input_config.control_panel_top_row_height_ratio if input_config != null else 0.45), 0.3, 0.7)
	var top_row_height: float = maxf((control_panel_rect.size.y - gutter) * top_row_ratio, 1.0)
	var middle_height: float = maxf(control_panel_rect.size.y - top_row_height - gutter, 1.0)
	var top_row_rect: Rect2 = Rect2(control_panel_rect.position, Vector2(control_panel_rect.size.x, top_row_height))
	var middle_rect: Rect2 = Rect2(
		Vector2(control_panel_rect.position.x, top_row_rect.end.y + gutter),
		Vector2(control_panel_rect.size.x, middle_height)
	)
	var top_half_width: float = maxf(top_row_rect.size.x * 0.5, 1.0)
	var shoot_rect: Rect2 = Rect2(top_row_rect.position, Vector2(top_half_width, top_row_rect.size.y))
	var dunk_rect: Rect2 = Rect2(
		Vector2(top_row_rect.position.x + top_half_width, top_row_rect.position.y),
		Vector2(maxf(top_row_rect.size.x - top_half_width, 1.0), top_row_rect.size.y)
	)
	var side_ratio: float = clampf(float(input_config.control_panel_side_zone_width_ratio if input_config != null else 0.25), 0.15, 0.4)
	var available_middle_width: float = maxf(middle_rect.size.x - gutter * 2.0, 1.0)
	var side_width: float = available_middle_width * side_ratio
	var move_width: float = maxf(available_middle_width - side_width * 2.0, 1.0)
	var pass_left_rect: Rect2 = Rect2(middle_rect.position, Vector2(side_width, middle_rect.size.y))
	var move_rect: Rect2 = Rect2(Vector2(pass_left_rect.end.x + gutter, middle_rect.position.y), Vector2(move_width, middle_rect.size.y))
	var pass_right_rect: Rect2 = Rect2(Vector2(move_rect.end.x + gutter, middle_rect.position.y), Vector2(side_width, middle_rect.size.y))
	return {
		"shoot": shoot_rect,
		"pass_left": pass_left_rect,
		"move": move_rect,
		"pass_right": pass_right_rect,
		"dunk": dunk_rect,
	}


func _resolve_safe_rect(viewport_rect: Rect2) -> Rect2:
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	if safe_area.size.x <= 0 or safe_area.size.y <= 0:
		return viewport_rect
	var intersected: Rect2 = Rect2(Vector2(safe_area.position), Vector2(safe_area.size)).intersection(viewport_rect)
	if intersected.size.x <= 0.0 or intersected.size.y <= 0.0:
		return viewport_rect
	return intersected


func _fit_rect_inside(container_rect: Rect2, content_size: Vector2) -> Rect2:
	if container_rect.size.x <= 0.0 or container_rect.size.y <= 0.0:
		return Rect2(container_rect.position, Vector2.ZERO)
	if content_size.x <= 0.0 or content_size.y <= 0.0:
		return Rect2(container_rect.position, container_rect.size)
	var aspect_ratio: float = content_size.x / content_size.y
	var fitted_size: Vector2 = Vector2(container_rect.size.x, container_rect.size.x / aspect_ratio)
	if fitted_size.y > container_rect.size.y:
		fitted_size = Vector2(container_rect.size.y * aspect_ratio, container_rect.size.y)
	var fitted_position: Vector2 = container_rect.position + (container_rect.size - fitted_size) * 0.5
	return Rect2(fitted_position, fitted_size)


func _build_services() -> void:
	rng = GameRng.new()
	rng.reseed(game_config.default_seed)
	visual_rng = GameRng.new()
	_reseed_visual_rng(game_config.default_seed)
	log_writer = LogWriter.new()
	log_writer.set_prefix("match")
	context.difficulty_level = difficulty_config.level
	court_projection = COURT_PROJECTION_SCRIPT.new(projection_config, court_config)
	shot_controller.shot_config = shot_config
	shot_controller.ball_config = ball_config
	shot_controller.court_config = court_config
	shot_controller.projection = court_projection
	pass_controller.pass_config = pass_config
	pass_controller.court_config = court_config
	pass_controller.difficulty_config = difficulty_config
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
	player_visual_memory.clear()
	hoop_node = HOOP_SCENE.instantiate() as HoopView
	entities_node.add_child(hoop_node)
	hoop_node.setup(court_config, court_projection)
	for player_data in home_team.players:
		var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
		player.setup(player_data, true, home_team.primary_color, player_animation_config)
		entities_node.add_child(player)
		offense_players.append(player)
	for player_data in away_team.players:
		var defender: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
		defender.setup(player_data, false, Color(0.91, 0.34, 0.3), player_animation_config)
		entities_node.add_child(defender)
		defense_players.append(defender)
	ball_node = BALL_SCENE.instantiate() as BallController
	entities_node.add_child(ball_node)
	ball_node.z_index = 6
	opponent_sim_presentation = OPPONENT_SIM_PRESENTATION_SCENE.instantiate()
	opponent_sim_presentation.name = "OpponentSimPresentation"
	entities_node.add_child(opponent_sim_presentation)
	opponent_sim_presentation.call("setup", home_team, away_team, court_config, court_projection, player_animation_config)
	_sync_projection_visuals()


func _wire_input_and_ui() -> void:
	input_controller.setup(input_config, court_projection, game_config.input_debug_keyboard_enabled, game_config.allow_mouse_emulation)
	input_controller.set_control_layout(layout_metrics)
	input_controller.set_interaction_mode(InputController.InteractionMode.LIVE_OFFENSE)
	input_controller.movement_zone_started.connect(_on_movement_zone_started)
	input_controller.movement_zone_ended.connect(_on_movement_zone_ended)
	input_controller.movement_updated.connect(_on_movement_updated)
	input_controller.pass_requested.connect(_on_pass_requested)
	input_controller.shot_mode_requested.connect(_on_shot_mode_requested)
	input_controller.shot_timing_tapped.connect(_on_shot_timing_tapped)
	input_controller.pause_requested.connect(_toggle_pause)
	opponent_sim_banner.advance_requested.connect(_on_opponent_sim_advance_requested)
	hud.pause_pressed.connect(_toggle_pause)
	pause_overlay.resume_pressed.connect(_resume_from_pause)
	pause_overlay.restart_pressed.connect(_start_new_match)
	pause_overlay.quit_pressed.connect(_quit_game)
	game_over_overlay.restart_pressed.connect(_start_new_match)
	game_over_overlay.quit_pressed.connect(_quit_game)
	var settings_node: Node = get_node_or_null("/root/GameSettings")
	if settings_node != null and not settings_node.changed.is_connected(_on_game_settings_changed):
		settings_node.changed.connect(_on_game_settings_changed)
	_apply_game_settings()


func _start_new_match() -> void:
	context.reset(game_config.match_length_seconds, game_config.default_seed)
	rng.reseed(context.current_seed)
	_reseed_visual_rng(context.current_seed)
	if court_projection != null:
		court_projection.reset_camera_tracking()
	camera_tracking_signature = ""
	finish_logic_center_world_cached = Vector2.INF
	finish_logic_center_screen_cached = Vector2.INF
	log_writer.set_prefix("match_%d" % Time.get_ticks_msec())
	log_writer.clear_runtime_logs()
	player_visual_memory.clear()
	shot_visual_locks.clear()
	_clear_active_dunk_root_motion()
	route_controller.reset_runtime_state()
	route_phase_time = 0.0
	rebound_delay_timer = 0.0
	made_shot_animation_timer = 0.0
	steal_resolve_timer = 0.0
	current_steal_holder = null
	last_pass_resolution_point = Vector2.INF
	last_pass_resolution_outcome = ""
	last_pass_commit_chance = 0.0
	last_pass_commit_succeeded = false
	last_pass_eligible_interceptor_name = ""
	last_pass_committed_interceptor_name = ""
	default_pass_target = null
	default_pass_target_details.clear()
	_clear_pending_shot_release()
	_clear_active_shot_sequence()
	_clear_opponent_sim_sequence()
	_set_opponent_sim_match_ui_hidden(false)
	_set_ball_visual_hidden(null)
	_clear_score_followthrough()
	current_preview_points.clear()
	_change_state(GameState.State.MATCH_SETUP)
	_reset_possession()
	_change_state(GameState.State.LIVE_OFFENSE)
	_update_hud()
	pause_overlay.visible = false
	if pause_overlay.has_method("close_settings"):
		pause_overlay.close_settings()
	_apply_game_settings()
	game_over_overlay.visible = false


func _reset_possession() -> void:
	context.possession_count += 1
	context.active_route_package = (context.possession_count - 1) % 3
	current_move_direction = Vector2.ZERO
	current_move_magnitude = 0.0
	route_controller.reset_runtime_state()
	shot_owner = null
	context.gameplay_time_scale = 1.0
	finish_logic_center_world_cached = Vector2.INF
	finish_logic_center_screen_cached = Vector2.INF
	_clear_active_dunk_root_motion()
	_clear_pending_shot_release()
	_clear_active_shot_sequence()
	shot_visual_locks.clear()
	pass_controller.active_pass = {}
	shot_controller.cancel_aim()
	made_shot_animation_timer = 0.0
	_clear_steal_resolve()
	_clear_opponent_sim_sequence()
	_clear_score_followthrough(false)
	default_pass_target = null
	default_pass_target_details.clear()
	current_preview_points.clear()
	court_view.clear_preview()
	court_view.clear_shot_meter()
	var anchors: Dictionary = court_config.get_anchor_map()
	for player in offense_players:
		player.world_position = anchors[player.get_position_role()]
		player.velocity = Vector2.ZERO
		player.set_has_ball(false)
	for defender in defense_players:
		var match_anchor: Vector2 = anchors[defender.get_position_role()]
		var offset: Vector2 = (court_config.hoop_position - match_anchor).normalized() * defense_config.guard_distance
		defender.world_position = match_anchor + offset
		defender.velocity = Vector2.ZERO
		defender.set_has_ball(false)
	defense_controller.setup_assignments(offense_players, defense_players)
	_refresh_defender_mode()
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
		GameState.State.SHOT_RELEASE:
			_update_shot_release(scaled_delta)
		GameState.State.PASS_IN_FLIGHT:
			_update_pass_in_flight(scaled_delta)
		GameState.State.STEAL_RESOLVE:
			_update_steal_resolve(scaled_delta)
		GameState.State.SHOT_IN_FLIGHT:
			_update_shot_in_flight(scaled_delta)
		GameState.State.REBOUND_LIVE:
			_update_rebound_live(scaled_delta)
		GameState.State.OPPONENT_SIM:
			_update_opponent_sim_sequence(scaled_delta)
	_sync_projection_visuals(scaled_delta)


func _update_clock(delta: float) -> void:
	if context.current_state == GameState.State.OPPONENT_SIM or context.current_state == GameState.State.MATCH_SETUP:
		return
	context.match_time_remaining = maxf(context.match_time_remaining - delta, 0.0)
	_update_hud()
	if context.match_time_remaining > 0.0:
		return
	if context.current_state == GameState.State.SHOT_RELEASE or context.current_state == GameState.State.SHOT_IN_FLIGHT or context.current_state == GameState.State.REBOUND_LIVE:
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
	if not active_shot_sequence.is_empty():
		shot_controller.update_aim(delta)
	_update_off_ball_offense(delta)
	_update_defense(delta)
	if current_ballhandler == null:
		return
	var contested: bool = defense_controller.is_contested(current_ballhandler)
	var preview_profile: Dictionary = shot_controller.build_current_launch_profile(
		current_ballhandler.world_position,
		current_ballhandler.get_player_data(),
		contested,
		str(active_shot_sequence.get("family", "")),
		bool(active_shot_sequence.get("mirror_west", false))
	)
	if preview_profile.is_empty():
		current_preview_points.clear()
		court_view.clear_preview()
	else:
		current_preview_points = shot_controller.create_preview(ball_simulator, preview_profile)
		current_preview_color = _quality_color(str(preview_profile.get("quality", "red")))
		court_view.set_preview(current_preview_points, current_preview_color)
	_sync_ball_to_handler()


func _update_shot_release(delta: float) -> void:
	route_phase_time += delta
	if not active_shot_sequence.is_empty():
		shot_controller.update_aim(delta)
	_update_off_ball_offense(delta)
	_update_defense(delta)
	if current_ballhandler != null:
		current_ballhandler.velocity = Vector2.ZERO


func _update_pass_in_flight(delta: float) -> void:
	route_phase_time += delta
	var pass_snapshot: Dictionary = pass_controller.get_active_pass_snapshot()
	var intended_receiver: PlayerController = pass_snapshot.get("intended_receiver", null) as PlayerController
	var active_interceptor: PlayerController = pass_snapshot.get("active_interceptor", null) as PlayerController
	_update_off_ball_offense(delta, [intended_receiver])
	if intended_receiver != null:
		_move_offense_ai_toward_target(intended_receiver, pass_snapshot.get("end", intended_receiver.world_position), 1.0, delta)
		_clamp_to_court(intended_receiver)
	_update_defense(delta, [active_interceptor])
	if active_interceptor != null:
		_move_defense_ai_toward_target(active_interceptor, pass_snapshot.get("chase_point", active_interceptor.world_position), difficulty_config.get_defense_multiplier(), delta)
		_clamp_to_court(active_interceptor)
	var result: Dictionary = pass_controller.step_pass(delta)
	if result.get("state", "") == "traveling":
		_sync_pass_ball_visual(result["position"])
	elif result.get("state", "") == "out_of_bounds":
		last_pass_resolution_point = result.get("resolved_position", result.get("position", Vector2.ZERO))
		last_pass_resolution_outcome = "out_of_bounds"
		log_writer.log_event(
			"pass_resolved",
			{
				"outcome": "out_of_bounds",
				"catch_point": _vector2_payload(last_pass_resolution_point),
				"target_point": _vector2_payload(result.get("target_point", Vector2.ZERO)),
			}
		)
		log_writer.log_match("Pass out of bounds")
		_run_opponent_possession()
	elif result.get("state", "") == "complete_offense":
		var receiver: PlayerController = result.get("intended_receiver", null) as PlayerController
		last_pass_resolution_point = result.get("resolved_position", result.get("position", Vector2.ZERO))
		last_pass_resolution_outcome = "offense"
		log_writer.log_event(
			"pass_resolved",
			{
				"outcome": "offense",
				"receiver": receiver.get_display_name() if receiver != null else "",
				"catch_point": _vector2_payload(last_pass_resolution_point),
				"target_point": _vector2_payload(result.get("target_point", Vector2.ZERO)),
			}
		)
		if receiver == null:
			_change_state(GameState.State.LIVE_OFFENSE)
			return
		receiver.trigger_catch_pose(0.24)
		_set_ballhandler(receiver)
		_change_state(GameState.State.LIVE_OFFENSE)
		_sync_ball_to_handler()
		log_writer.log_match("Pass caught by %s" % receiver.get_display_name())
	elif result.get("state", "") == "complete_steal":
		var stealer: PlayerController = result.get("active_interceptor", null) as PlayerController
		last_pass_resolution_point = result.get("resolved_position", result.get("position", Vector2.ZERO))
		last_pass_resolution_outcome = "steal"
		log_writer.log_event(
			"pass_resolved",
			{
				"outcome": "steal",
				"stealer": stealer.get_display_name() if stealer != null else "",
				"catch_point": _vector2_payload(last_pass_resolution_point),
				"target_point": _vector2_payload(result.get("target_point", Vector2.ZERO)),
				"chase_point": _vector2_payload(result.get("chase_point", Vector2.ZERO)),
			}
		)
		if stealer == null:
			_run_opponent_possession()
			return
		log_writer.log_match("Pass intercepted by %s" % stealer.get_display_name())
		_begin_steal_resolve(stealer)


func _update_steal_resolve(delta: float) -> void:
	if current_steal_holder != null:
		current_steal_holder.velocity = Vector2.ZERO
		_sync_ball_to_player(current_steal_holder)
	steal_resolve_timer = maxf(steal_resolve_timer - delta, 0.0)
	if steal_resolve_timer <= 0.0:
		_run_opponent_possession()


func _update_shot_in_flight(delta: float) -> void:
	if not active_shot_sequence.is_empty():
		shot_controller.update_aim(delta)
	if made_shot_animation_timer > 0.0:
		ball_simulator.step(delta)
		if get_score_followthrough_active():
			_advance_score_followthrough(delta)
		_sync_ball_world_visual(ball_simulator.position_xy, ball_simulator.z)
		_trace_score_followthrough("made_shot_frame")
		if (context.buzzer_waiting_for_resolution or context.match_time_remaining <= 0.0) and not ball_simulator.is_in_flight:
			_trace_score_followthrough("made_shot_settled", {}, true)
			made_shot_animation_timer = 0.0
			_finish_game()
			return
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
			_trace_score_followthrough("score_begin", {}, true)
			made_shot_animation_timer = maxf(
				maxf(shot_config.made_shot_animation_duration, ball_simulator.get_remaining_visual_time() + 0.08),
				_get_active_dunk_root_motion_remaining_seconds()
			)
			return
	_sync_ball_world_visual(ball_simulator.position_xy, ball_simulator.z)
	if not ball_simulator.is_in_flight and not ball_simulator.already_scored:
		_show_feedback("BRICK!", Color(1.0, 0.76, 0.36))
		_begin_rebound()


func _update_rebound_live(delta: float) -> void:
	rebound_delay_timer += delta
	for player in offense_players:
		_move_offense_ai_toward_target(player, active_rebound_zone, rebound_config.pursuit_speed_bonus, delta)
		_clamp_to_court(player)
	var active_defenders: Array[PlayerController] = _get_active_defenders()
	for defender in active_defenders:
		_move_defense_ai_toward_target(defender, active_rebound_zone, rebound_config.pursuit_speed_bonus, delta)
		_clamp_to_court(defender)
	if rebound_delay_timer < rebound_config.rebound_reaction_delay:
		return
	if not court_config.is_in_bounds(active_rebound_zone):
		log_writer.log_match("Loose ball out of bounds")
		_run_opponent_possession()
		return
	var candidates: Array[Dictionary] = rebound_controller.get_rebound_candidates(active_rebound_zone, offense_players, active_defenders)
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


func _update_off_ball_offense(delta: float, excluded_players: Array = []) -> void:
	var targets: Dictionary = route_controller.get_route_targets(offense_players, current_ballhandler, context.active_route_package, route_phase_time)
	for player in offense_players:
		if player == current_ballhandler or excluded_players.has(player):
			continue
		_move_offense_ai_toward_target(player, targets.get(player, player.world_position), route_config.route_move_speed_multiplier, delta)
		_clamp_to_court(player)


func _update_defense(delta: float, excluded_defenders: Array = []) -> void:
	var active_defenders: Array[PlayerController] = _get_active_defenders(excluded_defenders)
	if active_defenders.is_empty():
		return
	defense_controller.update_defense(delta, offense_players, active_defenders, current_ballhandler)
	for defender in active_defenders:
		_clamp_to_court(defender)


func _on_movement_updated(direction: Vector2, magnitude: float) -> void:
	if context.current_state != GameState.State.LIVE_OFFENSE:
		return
	current_move_direction = direction
	current_move_magnitude = magnitude


func _on_movement_zone_started(anchor_screen: Vector2, anchor_world: Vector2) -> void:
	log_writer.log_event(
		"movement_zone_started",
		{
			"anchor_screen": _vector2_payload(anchor_screen),
			"anchor_world": _vector2_payload(anchor_world),
		}
	)


func _on_movement_zone_ended(release_screen: Vector2, release_world: Vector2, elapsed: float, reason: String, details: Dictionary = {}) -> void:
	log_writer.log_event(
		"movement_zone_ended",
		{
			"release_screen": _vector2_payload(release_screen),
			"release_world": _vector2_payload(release_world),
			"elapsed": elapsed,
			"reason": reason,
			"release_offset_screen": _vector2_payload(details.get("release_offset_screen", Vector2.ZERO)),
			"release_distance": float(details.get("release_distance", 0.0)),
			"tap_duration": float(details.get("tap_duration", 0.0)),
			"tap_max_distance": float(details.get("tap_max_distance", 0.0)),
		}
	)

func _on_pass_requested(target: PlayerController, details: Dictionary = {}) -> void:
	if context.current_state != GameState.State.LIVE_OFFENSE:
		return
	var resolved_target: PlayerController = target
	if resolved_target == null:
		resolved_target = default_pass_target
	if resolved_target == null or resolved_target == current_ballhandler:
		log_writer.log_event(
			"pass_request_ignored",
			{
				"reason": "no_default_target" if target == null else "invalid_target",
				"requested_target": _player_name_or_empty(target),
				"default_target": _player_name_or_empty(default_pass_target),
				"release_reason": str(details.get("release_reason", "")),
			}
		)
		return
	_begin_pass_to_target(resolved_target, details)


func _begin_pass_to_target(target: PlayerController, details: Dictionary = {}) -> void:
	if target == null or target == current_ballhandler:
		return
	_clear_pending_shot_release()
	_clear_active_shot_sequence()
	default_pass_target = null
	default_pass_target_details.clear()
	log_writer.log_match("Pass requested to %s" % target.get_display_name())
	_change_state(GameState.State.PASS_IN_FLIGHT)
	current_ballhandler.set_has_ball(false)
	last_pass_resolution_point = Vector2.INF
	last_pass_resolution_outcome = ""
	var pass_snapshot: Dictionary = pass_controller.start_pass(current_ballhandler.world_position, target, _get_active_defenders(), rng, current_ballhandler)
	last_pass_commit_chance = float(pass_snapshot.get("commit_chance", 0.0))
	last_pass_commit_succeeded = bool(pass_snapshot.get("commit_succeeded", false))
	last_pass_eligible_interceptor_name = _player_name_or_empty(pass_snapshot.get("eligible_interceptor", null))
	last_pass_committed_interceptor_name = _player_name_or_empty(pass_snapshot.get("active_interceptor", null))
	_set_ball_visual_world()
	log_writer.log_event(
		"pass_started",
		{
			"from": current_ballhandler.get_display_name(),
			"to": target.get_display_name(),
			"start": _vector2_payload(current_ballhandler.world_position),
			"target_point": _vector2_payload(pass_snapshot.get("end", target.world_position)),
			"eligible_interceptor": last_pass_eligible_interceptor_name,
			"interceptor": _player_name_or_empty(pass_snapshot.get("active_interceptor", null)),
			"commit_chance": last_pass_commit_chance,
			"commit_succeeded": last_pass_commit_succeeded,
			"chase_point": _vector2_payload(pass_snapshot.get("chase_point", target.world_position)),
			"gesture_release_offset_screen": _vector2_payload(details.get("release_offset_screen", Vector2.ZERO)),
			"gesture_release_distance": float(details.get("release_distance", 0.0)),
			"gesture_release_reason": str(details.get("release_reason", "")),
			"pass_target_source": str(details.get("pass_target_source", "")),
		}
	)
	_sync_pass_ball_visual(current_ballhandler.world_position)


func _build_shot_arm_log_payload(details: Dictionary) -> Dictionary:
	return {
		"arm_reason": str(details.get("arm_reason", "")),
		"control_intent": str(details.get("control_intent", "")),
		"tap_start_screen": _vector2_payload(details.get("tap_start_screen", details.get("anchor_screen", Vector2.ZERO))),
		"tap_end_screen": _vector2_payload(details.get("tap_end_screen", details.get("release_screen", Vector2.ZERO))),
		"tap_start_world": _vector2_payload(details.get("tap_start_world", details.get("anchor_world", current_ballhandler.world_position))),
		"tap_end_world": _vector2_payload(details.get("tap_end_world", details.get("release_world", current_ballhandler.world_position))),
		"tap_duration": float(details.get("tap_duration", 0.0)),
		"tap_max_distance": float(details.get("tap_max_distance", 0.0)),
		"started_in_movement_zone": bool(details.get("started_in_movement_zone", false)),
		"release_offset_screen": _vector2_payload(details.get("release_offset_screen", Vector2.ZERO)),
		"release_distance": float(details.get("release_distance", 0.0)),
		"release_reason": str(details.get("release_reason", "")),
	}


func _should_auto_commit_active_dunk() -> bool:
	return not active_shot_sequence.is_empty() and _is_dunk_family(str(active_shot_sequence.get("family", "")))


func _build_auto_dunk_make_action(shooter: PlayerController) -> Dictionary:
	if shooter == null:
		return {"kind": "cancel"}
	return shot_controller.build_action_for_quality(
		shooter.world_position,
		shooter.get_player_data(),
		"green",
		rng,
		"dunk_auto_make",
		false,
		str(active_shot_sequence.get("family", "")),
		bool(active_shot_sequence.get("mirror_west", false))
	)


func _should_use_direct_shoot_button_timing(details: Dictionary, control_intent: String) -> bool:
	return control_intent == "shot_layout" \
		and bool(details.get("direct_button_tap", false)) \
		and str(details.get("release_zone", "")) == "shoot"


func _configure_direct_shoot_button_timing(shooter: PlayerController) -> void:
	if active_shot_sequence.is_empty():
		return
	active_shot_sequence["shot_timing_mode"] = SHOT_TIMING_MODE_DIRECT_SHOOT_BUTTON
	active_shot_sequence["release_visual_deferred"] = true
	active_shot_sequence["release_visual_started"] = false
	var timing_profile: Dictionary = Dictionary(active_shot_sequence.get("timing_profile", {})).duplicate(true)
	var animation_release_time: float = maxf(float(timing_profile.get("release_time_seconds", 0.0)), 0.0)
	var button_meter_duration: float = maxf(float(shot_config.meter_cycle_duration if shot_config != null else 0.86), 0.1)
	timing_profile["animation_release_time_seconds"] = animation_release_time
	timing_profile["release_time_seconds"] = maxf(button_meter_duration, animation_release_time)
	active_shot_sequence["timing_profile"] = timing_profile
	if shooter != null:
		shot_visual_locks.erase(shooter)


func _active_shot_uses_direct_shoot_button_timing() -> bool:
	return not active_shot_sequence.is_empty() \
		and str(active_shot_sequence.get("shot_timing_mode", SHOT_TIMING_MODE_ANIMATION_GATED)) == SHOT_TIMING_MODE_DIRECT_SHOOT_BUTTON


func _ensure_active_shot_release_visual_lock(shooter: PlayerController) -> void:
	if shooter == null or active_shot_sequence.is_empty():
		return
	shot_visual_locks[shooter] = {
		"family": str(active_shot_sequence.get("family", "jumper_release")),
		"variant_index": int(active_shot_sequence.get("variant_index", 0)),
		"mirror_west": bool(active_shot_sequence.get("mirror_west", false)),
		"start_frame_override": int(active_shot_sequence.get("approach_start_frame", 1)),
	}
	active_shot_sequence["release_visual_deferred"] = false
	active_shot_sequence["release_visual_started"] = true


func _on_shot_mode_requested(details: Dictionary) -> void:
	if context.current_state != GameState.State.LIVE_OFFENSE:
		return
	if current_ballhandler == null:
		return
	var control_intent: String = str(details.get("control_intent", "shot_layout"))
	var use_direct_shoot_button_timing: bool = _should_use_direct_shoot_button_timing(details, control_intent)
	default_pass_target = null
	default_pass_target_details.clear()
	if not _begin_active_shot_sequence(current_ballhandler, control_intent):
		log_writer.log_event(
			"shot_mode_ignored",
			{
				"player": current_ballhandler.get_display_name(),
				"control_intent": control_intent,
				"release_reason": str(details.get("release_reason", "")),
			}
		)
		return
	current_move_direction = Vector2.ZERO
	current_move_magnitude = 0.0
	context.gameplay_time_scale = 1.0
	if use_direct_shoot_button_timing:
		_configure_direct_shoot_button_timing(current_ballhandler)
	var arm_payload: Dictionary = _build_shot_arm_log_payload(details)
	arm_payload["shot_timing_mode"] = str(active_shot_sequence.get("shot_timing_mode", SHOT_TIMING_MODE_ANIMATION_GATED))
	if _should_auto_commit_active_dunk():
		shot_controller.begin_aim(current_ballhandler.world_position, _get_active_shot_timing_profile(), rng)
		current_preview_points.clear()
		if court_view != null:
			court_view.clear_preview()
			court_view.clear_shot_meter()
		log_writer.log_match("Dunk auto-finish armed")
		log_writer.log_event(
			"dunk_auto_finish_armed",
			arm_payload.merged(
				{
					"player": current_ballhandler.get_display_name(),
					"family": str(active_shot_sequence.get("family", "")),
					"variant_index": int(active_shot_sequence.get("variant_index", 0)),
				},
				true
			)
		)
		_queue_shot_release(_build_auto_dunk_make_action(current_ballhandler), null)
		return
	_change_state(GameState.State.SHOT_AIM)
	shot_controller.begin_aim(current_ballhandler.world_position, _get_active_shot_timing_profile(), rng)
	log_writer.log_match("Shot mode armed")
	log_writer.log_event("shot_mode_armed", arm_payload)


func _on_shot_timing_tapped(screen_position: Vector2) -> void:
	if context.current_state != GameState.State.SHOT_AIM:
		return
	if current_ballhandler == null:
		return
	var contested: bool = defense_controller.is_contested(current_ballhandler)
	var quality: String = shot_controller.get_current_quality(contested, current_ballhandler.get_player_data().release_consistency)
	var action: Dictionary = shot_controller.build_action_for_quality(
		current_ballhandler.world_position,
		current_ballhandler.get_player_data(),
		quality,
		rng,
		quality,
		false,
		str(active_shot_sequence.get("family", "")),
		bool(active_shot_sequence.get("mirror_west", false))
	)
	context.gameplay_time_scale = 1.0
	log_writer.log_event(
		"shot_timing_tapped",
		{
			"screen_position": _vector2_payload(screen_position),
			"quality": quality,
			"meter_progress": shot_controller.get_meter_progress(),
		}
	)
	if quality == "green":
		_trigger_light_haptic()
	match action["kind"]:
		"cancel":
			court_view.clear_preview()
			current_preview_points.clear()
			_clear_active_shot_sequence()
			_change_state(GameState.State.LIVE_OFFENSE)
		"shot":
			court_view.clear_preview()
			current_preview_points.clear()
			var blocker: PlayerController = null
			var shot_family: String = str(active_shot_sequence.get("family", ""))
			if action["outcome"] == "miss" and contested:
				blocker = defense_controller.get_blocking_defender(current_ballhandler, rng, shot_family)
			_queue_shot_release(action, blocker)


func _toggle_pause() -> void:
	if context.current_state == GameState.State.PAUSED:
		_resume_from_pause()
		return
	context.previous_state = context.current_state
	_change_state(GameState.State.PAUSED)
	pause_overlay.visible = true
	log_writer.log_match("Paused")


func _resume_from_pause() -> void:
	if pause_overlay.has_method("close_settings"):
		pause_overlay.close_settings()
	pause_overlay.visible = false
	_change_state(context.previous_state if context.previous_state != GameState.State.PAUSED else GameState.State.LIVE_OFFENSE)
	log_writer.log_match("Resumed")


func _run_opponent_possession() -> void:
	_clear_steal_resolve()
	_clear_pending_shot_release()
	_clear_active_shot_sequence()
	_set_ball_visual_hidden(null)
	_change_state(GameState.State.OPPONENT_SIM)
	var result: Dictionary = opponent_sim_controller.run_possession(away_team, home_team, context.match_time_remaining, rng)
	for event_line in result["events"]:
		log_writer.log_sim(event_line)
	_begin_opponent_sim_sequence(result)


func _begin_opponent_sim_sequence(result: Dictionary) -> void:
	pending_opponent_sim_result = result.duplicate(true)
	opponent_sim_visual_steps = _normalize_opponent_sim_visual_steps(result.get("visual_steps", []))
	opponent_sim_visual_index = 0
	_set_opponent_sim_match_ui_hidden(true)
	_set_opponent_sim_live_entities_hidden(true)
	_show_current_opponent_sim_step()


func _normalize_opponent_sim_visual_steps(raw_steps: Variant) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	if raw_steps is Array:
		for raw_step in raw_steps:
			if raw_step is Dictionary:
				var step: Dictionary = raw_step.duplicate(true)
				var text_value: String = str(step.get("text", "")).strip_edges()
				if text_value == "":
					continue
				step["text"] = text_value
				_normalize_opponent_sim_visual_step_actor_fields(step)
				step["is_final"] = false
				steps.append(step)
	if steps.is_empty():
		steps.append({
			"text": "Turnover from AWY",
			"kind": "turnover",
			"player": "AWY",
			"points": 0,
			"is_final": true,
		})
	while steps.size() > 4:
		steps.pop_back()
	for index in steps.size():
		steps[index]["is_final"] = index == steps.size() - 1
	return steps


func _normalize_opponent_sim_visual_step_actor_fields(step: Dictionary) -> void:
	var kind_value: String = str(step.get("kind", ""))
	var actor_team: String = str(step.get("actor_team", "")).to_lower()
	if actor_team == "":
		actor_team = "home" if kind_value in ["steal", "blocked_shot", "defensive_board"] else "away"
	if actor_team == "hom":
		actor_team = "home"
	elif actor_team == "awy":
		actor_team = "away"
	var player_role: String = str(step.get("player_role", ""))
	if player_role == "" or not _is_known_player_role(player_role):
		player_role = _infer_opponent_sim_player_role(step)
	var player_id: String = str(step.get("player_id", ""))
	if player_id == "":
		player_id = "%s_%s" % ["hom" if actor_team == "home" else "awy", player_role.to_lower()]
	step["actor_team"] = actor_team
	step["player_role"] = player_role
	step["player_id"] = player_id


func _infer_opponent_sim_player_role(step: Dictionary) -> String:
	var player_name: String = str(step.get("player", ""))
	for player in away_team.players:
		if player != null and player.display_name == player_name and player.role != "":
			return player.role
	for player in home_team.players:
		if player != null and player.display_name == player_name and player.role != "":
			return player.role
	return "PG"


func _is_known_player_role(role: String) -> bool:
	return role in ["PG", "LW", "RW", "LC", "RC"]


func _show_current_opponent_sim_step() -> void:
	if opponent_sim_visual_steps.is_empty():
		_complete_opponent_sim_sequence()
		return
	opponent_sim_visual_index = clampi(opponent_sim_visual_index, 0, opponent_sim_visual_steps.size() - 1)
	var step: Dictionary = opponent_sim_visual_steps[opponent_sim_visual_index]
	var text_value: String = str(step.get("text", ""))
	opponent_sim_visual_timer = maxf(float(opponent_sim_config.visual_step_duration), 0.05)
	if opponent_sim_banner != null:
		opponent_sim_banner.show_action(text_value)
	if opponent_sim_presentation != null:
		opponent_sim_presentation.call("show_step", step)
	camera_tracking_signature = ""
	log_writer.log_event(
		"opponent_sim_visual_step",
		{
			"index": opponent_sim_visual_index,
			"count": opponent_sim_visual_steps.size(),
			"text": text_value,
			"kind": str(step.get("kind", "")),
			"points": int(step.get("points", 0)),
			"is_final": bool(step.get("is_final", false)),
		}
	)


func _update_opponent_sim_sequence(delta: float) -> void:
	if pending_opponent_sim_result.is_empty():
		return
	opponent_sim_visual_timer = maxf(opponent_sim_visual_timer - delta, 0.0)
	if opponent_sim_visual_timer <= 0.0:
		_advance_opponent_sim_sequence()


func _advance_opponent_sim_sequence() -> void:
	if pending_opponent_sim_result.is_empty():
		return
	if opponent_sim_visual_index >= opponent_sim_visual_steps.size() - 1:
		_complete_opponent_sim_sequence()
		return
	opponent_sim_visual_index += 1
	_show_current_opponent_sim_step()


func _on_opponent_sim_advance_requested() -> void:
	if context.current_state != GameState.State.OPPONENT_SIM:
		return
	_advance_opponent_sim_sequence()


func _complete_opponent_sim_sequence() -> void:
	if pending_opponent_sim_result.is_empty():
		_clear_opponent_sim_sequence()
		return
	var result: Dictionary = pending_opponent_sim_result.duplicate(true)
	var points_scored: int = int(result.get("points_scored", 0))
	var time_consumed: float = float(result.get("time_consumed", 0.0))
	context.away_score += points_scored
	context.match_time_remaining = maxf(context.match_time_remaining - time_consumed, 0.0)
	log_writer.log_event(
		"opponent_sim_visual_complete",
		{
			"points_scored": points_scored,
			"time_consumed": time_consumed,
			"step_count": opponent_sim_visual_steps.size(),
		}
	)
	_clear_opponent_sim_sequence()
	_update_hud()
	if context.match_time_remaining <= 0.0:
		_finish_game()
		return
	_reset_possession()
	_change_state(GameState.State.LIVE_OFFENSE)
	_set_opponent_sim_match_ui_hidden(false)


func _clear_opponent_sim_sequence() -> void:
	pending_opponent_sim_result.clear()
	opponent_sim_visual_steps.clear()
	opponent_sim_visual_index = -1
	opponent_sim_visual_timer = 0.0
	if opponent_sim_banner != null:
		opponent_sim_banner.hide_banner()
	if opponent_sim_presentation != null:
		opponent_sim_presentation.call("hide_presentation")
	_set_opponent_sim_live_entities_hidden(false)


func _set_opponent_sim_match_ui_hidden(hidden: bool) -> void:
	if opponent_sim_match_ui_hidden == hidden:
		_sync_match_ui_visibility()
		return
	opponent_sim_match_ui_hidden = hidden
	_sync_match_ui_visibility()
	log_writer.log_event("opponent_sim_match_ui_visibility", {"hidden": opponent_sim_match_ui_hidden})


func _sync_match_ui_visibility() -> void:
	if hud != null:
		hud.visible = not opponent_sim_match_ui_hidden
	if control_panel != null:
		if input_controller != null:
			control_panel.set_panel_state(_build_control_panel_state())
		else:
			control_panel.visible = controls_visible and not opponent_sim_match_ui_hidden


func _set_opponent_sim_live_entities_hidden(hidden: bool) -> void:
	opponent_sim_live_entities_hidden = hidden
	for player in offense_players + defense_players:
		if player != null:
			player.visible = not hidden
	if ball_node != null:
		if hidden and ball_node.has_method("set_ball_visible"):
			ball_node.call("set_ball_visible", false)
		elif not hidden:
			_sync_ball_visuals()


func _begin_rebound(override_zone: Vector2 = Vector2.INF) -> void:
	active_rebound_zone = override_zone if override_zone != Vector2.INF else hoop_resolver.estimate_landing_position(ball_simulator)
	rebound_delay_timer = 0.0
	context.last_touch_offense = true
	_clear_pending_shot_release()
	_clear_active_shot_sequence(true)
	_change_state(GameState.State.REBOUND_LIVE)


func _finish_game() -> void:
	context.gameplay_time_scale = 1.0
	_clear_opponent_sim_sequence()
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
	for defender in defense_players:
		defender.set_has_ball(false)
	input_controller.set_ballhandler(player)
	input_controller.set_offense_players(offense_players)
	_set_ball_visual_hidden(player)
	log_writer.log_event("ballhandler_changed", {"player": player.get_display_name(), "role": player.get_position_role()})


func _set_ball_visual_hidden(owner: PlayerController) -> void:
	ball_visual_mode = BallVisualMode.HIDDEN_WHILE_OWNED
	ball_visual_owner = owner
	_set_through_net_masks_active(false)
	if ball_node != null and ball_node.has_method("set_ball_visible"):
		ball_node.call("set_ball_visible", false)


func _set_ball_visual_world() -> void:
	ball_visual_mode = BallVisualMode.WORLD_VISIBLE
	ball_visual_owner = null
	if ball_node != null and ball_node.has_method("set_ball_visible"):
		ball_node.call("set_ball_visible", true)


func _sync_ball_to_handler() -> void:
	_sync_ball_to_player(current_ballhandler)


func _sync_ball_to_player(player: PlayerController) -> void:
	if player == null:
		return
	_set_through_net_masks_active(false)
	ball_simulator.reset_to_possession(player.world_position)
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
			"ball_anchor": player.get_ball_screen_anchor(),
			"shadow_anchor": shadow_anchor,
			"ball_radius": _get_held_ball_render_radius() * player.projected_scale,
			"shadow_scale": court_projection.shadow_scale(ball_simulator.position_xy, 0.0),
			"depth_key": court_projection.depth_key(ball_simulator.position_xy, 0.0),
		},
		z_override,
		render_phase
	)
	if ball_node != null and ball_node.has_method("set_ball_visible"):
		ball_node.call("set_ball_visible", ball_visual_mode == BallVisualMode.WORLD_VISIBLE)


func _sync_pass_ball_visual(world_position: Vector2) -> void:
	ball_simulator.previous_position_xy = ball_simulator.position_xy
	ball_simulator.position_xy = world_position
	ball_simulator.previous_z = ball_simulator.z
	ball_simulator.z = ball_config.pass_height
	ball_simulator.vz = 0.0
	ball_simulator.is_in_flight = false
	_set_ball_visual_world()
	_sync_ball_world_visual(world_position, ball_config.pass_height)


func _update_hud() -> void:
	hud.update_display(home_team.abbreviation, context.home_score, away_team.abbreviation, context.away_score, context.match_time_remaining)


func _show_feedback(text_value: String, color_value: Color) -> void:
	context.last_feedback_text = text_value
	feedback_text.show_feedback(text_value, color_value, 1.0)
	log_writer.log_event("feedback", {"text": text_value})


func _clamp_to_court(player: PlayerController) -> void:
	player.world_position.x = clampf(player.world_position.x, court_config.court_rect.position.x, court_config.court_rect.end.x)
	player.world_position.y = clampf(player.world_position.y, court_config.court_rect.position.y, court_config.court_rect.end.y)


func _move_offense_ai_toward_target(player: PlayerController, target: Vector2, speed_scale: float, delta: float) -> void:
	if player == null:
		return
	player.move_toward_target_smooth(
		target,
		speed_scale,
		delta,
		route_config.steering_arrival_radius,
		route_config.steering_stop_radius,
		route_config.steering_acceleration,
		route_config.steering_deceleration
	)


func _move_defense_ai_toward_target(player: PlayerController, target: Vector2, speed_scale: float, delta: float) -> void:
	if player == null:
		return
	player.move_toward_target_smooth(
		target,
		speed_scale,
		delta,
		defense_config.guard_arrival_radius,
		defense_config.guard_stop_radius,
		defense_config.guard_acceleration,
		defense_config.guard_deceleration
	)


func _change_state(new_state: int) -> void:
	change_state(new_state)


func change_state(new_state: int) -> void:
	var old_state: int = context.current_state
	context.previous_state = old_state
	context.current_state = new_state
	_apply_input_mode_for_state(new_state)
	log_writer.log_event("state_transition", {"from": GameState.state_name(old_state), "to": GameState.state_name(new_state)})


func _apply_input_mode_for_state(state_value: int) -> void:
	if input_controller == null:
		return
	match state_value:
		GameState.State.LIVE_OFFENSE:
			input_controller.set_interaction_mode(InputController.InteractionMode.LIVE_OFFENSE)
		GameState.State.SHOT_AIM:
			input_controller.set_interaction_mode(InputController.InteractionMode.SHOT_TIMING)
		_:
			input_controller.set_interaction_mode(InputController.InteractionMode.DISABLED)


func _trigger_light_haptic() -> void:
	if input_config == null or not input_config.enable_mobile_haptics:
		return
	if not OS.has_feature("mobile"):
		return
	Input.vibrate_handheld(20)


func _quality_color(quality: String) -> Color:
	match quality:
		"green":
			return Color(0.36, 1.0, 0.48, 0.95)
		"yellow":
			return Color(1.0, 0.86, 0.32, 0.95)
		_:
			return Color(1.0, 0.3, 0.28, 0.95)


func _reseed_visual_rng(seed: int) -> void:
	if visual_rng == null:
		visual_rng = GameRng.new()
	visual_rng.reseed(seed ^ 0x51A91E)


func _load_or_default(path: String, fallback: Resource) -> Resource:
	var loaded: Resource = ResourceLoader.load(path)
	if loaded == null:
		return fallback
	return loaded


func _resolve_team_from_roster(is_home: bool) -> TeamData:
	var roster: Node = get_node_or_null("/root/TeamRoster")
	if roster == null:
		var fallback_path: String = "res://data/teams/HOM.tres" if is_home else "res://data/teams/AWY.tres"
		return _load_or_default(fallback_path, TeamData.new()) as TeamData
	if is_home:
		return roster.get_home_team() as TeamData
	return roster.get_away_team() as TeamData


func _clear_entity_children() -> void:
	for child in entities_node.get_children():
		child.queue_free()
	offense_players.clear()
	defense_players.clear()
	opponent_sim_presentation = null
	opponent_sim_live_entities_hidden = false
	player_visual_memory.clear()


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
			catch_rings.append(court_projection.project_circle(player.world_position, pass_controller.get_offense_claim_radius(player), 0.0, 28))
	var intercept_corridor: PackedVector2Array = PackedVector2Array()
	var raw_corridor: PackedVector2Array = pass_controller.get_intercept_corridor()
	if raw_corridor.size() == 2:
		var corridor_points: Array[Vector2] = [raw_corridor[0], raw_corridor[1]]
		intercept_corridor = court_projection.project_polyline(corridor_points)
	var pass_snapshot: Dictionary = pass_controller.get_active_pass_snapshot()
	var pass_target_marker: Vector2 = Vector2.INF
	var pass_chase_marker: Vector2 = Vector2.INF
	var pass_resolution_marker: Vector2 = Vector2.INF
	var pass_receiver_name: String = ""
	var pass_eligible_interceptor_name: String = last_pass_eligible_interceptor_name
	var pass_interceptor_name: String = ""
	var pass_commit_chance: float = last_pass_commit_chance
	var pass_commit_succeeded: bool = last_pass_commit_succeeded
	if not pass_snapshot.is_empty():
		pass_target_marker = court_projection.world_to_screen_ground(pass_snapshot.get("end", Vector2.ZERO))
		pass_receiver_name = _player_name_or_empty(pass_snapshot.get("intended_receiver", null))
		pass_eligible_interceptor_name = _player_name_or_empty(pass_snapshot.get("eligible_interceptor", null))
		pass_interceptor_name = _player_name_or_empty(pass_snapshot.get("active_interceptor", null))
		pass_commit_chance = float(pass_snapshot.get("commit_chance", 0.0))
		pass_commit_succeeded = bool(pass_snapshot.get("commit_succeeded", false))
		var snapshot_interceptor: PlayerController = pass_snapshot.get("active_interceptor", null) as PlayerController
		if snapshot_interceptor != null:
			pass_chase_marker = court_projection.world_to_screen_ground(pass_snapshot.get("chase_point", pass_snapshot.get("end", Vector2.ZERO)))
			catch_rings.append(court_projection.project_circle(snapshot_interceptor.world_position, pass_controller.get_defense_claim_radius(snapshot_interceptor), 0.0, 28))
	if last_pass_resolution_point != Vector2.INF:
		pass_resolution_marker = court_projection.world_to_screen_ground(last_pass_resolution_point)
	var rebound_zone: PackedVector2Array = PackedVector2Array()
	if context.current_state == GameState.State.REBOUND_LIVE:
		rebound_zone = court_projection.project_circle(active_rebound_zone, rebound_config.rebound_zone_radius, 0.0, 28)
	var finish_radius_rings: Array[Dictionary] = []
	var finish_radius_center: Vector2 = Vector2.INF
	if court_projection != null and court_config != null and player_animation_config != null:
		var finish_center_world: Vector2 = get_finish_logic_center_world()
		finish_radius_center = court_projection.world_to_screen_ground(finish_center_world)
		var radius_specs: Array[Dictionary] = [
			{"name": "close_finish", "radius": player_animation_config.close_finish_radius},
			{"name": "dunk_max", "radius": player_animation_config.dunk_finish_radius},
			{"name": "dunk_medium", "radius": player_animation_config.dunk_smart_start_medium_distance},
			{"name": "dunk_short", "radius": player_animation_config.dunk_smart_start_short_distance},
		]
		for radius_spec in radius_specs:
			var radius_value: float = maxf(float(radius_spec.get("radius", 0.0)), 0.0)
			if radius_value <= 0.0:
				continue
			finish_radius_rings.append({
				"name": str(radius_spec.get("name", "")),
				"radius": radius_value,
				"points": court_projection.project_circle(finish_center_world, radius_value, 0.0, 72),
			})
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
		"pass_target_marker": pass_target_marker,
		"pass_chase_marker": pass_chase_marker,
		"pass_resolution_marker": pass_resolution_marker,
		"pass_receiver_name": pass_receiver_name,
		"pass_eligible_interceptor_name": pass_eligible_interceptor_name,
		"pass_interceptor_name": pass_interceptor_name,
		"pass_commit_chance": pass_commit_chance,
		"pass_commit_succeeded": pass_commit_succeeded,
		"pass_outcome": last_pass_resolution_outcome,
		"rebound_zone": rebound_zone,
		"shot_preview": current_preview_points,
		"finish_radius_rings": finish_radius_rings,
		"finish_radius_center": finish_radius_center,
	}


func get_finish_logic_center_world() -> Vector2:
	if court_config == null:
		return Vector2.ZERO
	if not is_inf(finish_logic_center_world_cached.x) and not is_inf(finish_logic_center_world_cached.y):
		return finish_logic_center_world_cached
	if _should_refresh_finish_logic_center_world_cache():
		_refresh_finish_logic_center_world_cache()
	if not is_inf(finish_logic_center_world_cached.x) and not is_inf(finish_logic_center_world_cached.y):
		return finish_logic_center_world_cached
	return _get_finish_logic_center_world_from_current_view()


func _refresh_finish_logic_center_world_cache() -> void:
	var finish_snapshot: Dictionary = _get_finish_logic_center_cache_snapshot()
	finish_logic_center_world_cached = finish_snapshot.get("world", court_config.hoop_position if court_config != null else Vector2.ZERO)
	finish_logic_center_screen_cached = finish_snapshot.get("screen", Vector2.INF)


func _maybe_refresh_finish_logic_center_world_cache() -> void:
	if not _should_refresh_finish_logic_center_world_cache():
		return
	_refresh_finish_logic_center_world_cache()


func _should_refresh_finish_logic_center_world_cache() -> bool:
	if court_projection == null or hoop_node == null:
		return false
	if camera_tracking_signature.begins_with("ball"):
		return false
	return context.current_state in [
		GameState.State.MATCH_SETUP,
		GameState.State.LIVE_OFFENSE,
		GameState.State.SHOT_AIM,
	]


func _get_finish_logic_center_world_from_current_view() -> Vector2:
	return _get_finish_logic_center_cache_snapshot().get("world", court_config.hoop_position if court_config != null else Vector2.ZERO)


func _get_finish_logic_center_cache_snapshot() -> Dictionary:
	if court_config == null:
		return {
			"world": Vector2.ZERO,
			"screen": Vector2.ZERO,
		}
	if court_projection == null or hoop_node == null or not hoop_node.has_method("get_debug_finish_radius_center_screen"):
		var fallback_world: Vector2 = court_config.hoop_position
		return {
			"world": fallback_world,
			"screen": court_projection.world_to_screen_ground(fallback_world) if court_projection != null else fallback_world,
		}
	if hoop_node.has_method("set_projection"):
		hoop_node.call("set_projection", court_projection)
	var finish_center_screen: Vector2 = hoop_node.call("get_debug_finish_radius_center_screen")
	return {
		"world": court_projection.screen_to_world_ground(finish_center_screen),
		"screen": finish_center_screen,
	}


func _get_finish_logic_center_screen_from_current_view() -> Vector2:
	return _get_finish_logic_center_cache_snapshot().get("screen", finish_logic_center_world_cached)


func _get_finish_logic_center_screen() -> Vector2:
	if not is_inf(finish_logic_center_screen_cached.x) and not is_inf(finish_logic_center_screen_cached.y):
		return finish_logic_center_screen_cached
	if _should_refresh_finish_logic_center_world_cache():
		_refresh_finish_logic_center_world_cache()
	if not is_inf(finish_logic_center_screen_cached.x) and not is_inf(finish_logic_center_screen_cached.y):
		return finish_logic_center_screen_cached
	return _get_finish_logic_center_screen_from_current_view()


func begin_test_mode(seed: int) -> void:
	context.deterministic_mode = true
	context.current_seed = seed
	rng.reseed(seed)
	_reseed_visual_rng(seed)
	player_visual_memory.clear()
	shot_visual_locks.clear()
	_clear_active_dunk_root_motion()
	_clear_pending_shot_release()
	_clear_active_shot_sequence()
	_clear_opponent_sim_sequence()
	_set_opponent_sim_match_ui_hidden(false)
	log_writer.set_prefix("test_%d" % seed)
	log_writer.clear_runtime_logs()


func apply_test_setup(home_score: int, away_score: int, time_remaining: float) -> void:
	_clear_score_followthrough()
	_clear_opponent_sim_sequence()
	_set_opponent_sim_match_ui_hidden(false)
	context.home_score = home_score
	context.away_score = away_score
	context.match_time_remaining = time_remaining
	_update_hud()


func apply_scenario_setup(setup: Dictionary) -> void:
	if setup.is_empty():
		return
	if court_projection != null:
		court_projection.reset_camera_tracking()
	camera_tracking_signature = ""
	finish_logic_center_world_cached = Vector2.INF
	finish_logic_center_screen_cached = Vector2.INF
	route_controller.reset_runtime_state()
	player_visual_memory.clear()
	shot_visual_locks.clear()
	_clear_active_dunk_root_motion()
	_clear_pending_shot_release()
	_clear_active_shot_sequence()
	if setup.has("route_package"):
		context.active_route_package = int(setup["route_package"])
	if setup.has("gameplay_time_scale"):
		context.gameplay_time_scale = float(setup["gameplay_time_scale"])
	if setup.has("offense_positions"):
		_apply_role_positions(offense_players, setup["offense_positions"])
	if setup.has("defense_positions"):
		_apply_role_positions(defense_players, setup["defense_positions"])
	defense_controller.setup_assignments(offense_players, defense_players)
	_refresh_defender_mode()
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
	var has_explicit_ball_setup: bool = setup.has("ball")
	if setup.has("ball"):
		_apply_ball_setup(setup["ball"])
	if setup.has("state"):
		change_state(GameState.from_name(str(setup["state"])))
	_restore_ball_visual_from_state(has_explicit_ball_setup)
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


func get_opponent_sim_sequence_snapshot() -> Dictionary:
	var current_text: String = ""
	if opponent_sim_visual_index >= 0 and opponent_sim_visual_index < opponent_sim_visual_steps.size():
		current_text = str(opponent_sim_visual_steps[opponent_sim_visual_index].get("text", ""))
	return {
		"active": not pending_opponent_sim_result.is_empty(),
		"current_index": opponent_sim_visual_index,
		"action_count": opponent_sim_visual_steps.size(),
		"current_text": current_text,
		"seconds_remaining": opponent_sim_visual_timer,
		"pending_points_scored": int(pending_opponent_sim_result.get("points_scored", 0)),
		"pending_time_consumed": float(pending_opponent_sim_result.get("time_consumed", 0.0)),
	}


func get_opponent_sim_visual_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	if opponent_sim_presentation != null:
		var raw_snapshot: Variant = opponent_sim_presentation.call("get_visual_snapshot")
		if raw_snapshot is Dictionary:
			snapshot = raw_snapshot
	var current_text: String = ""
	if opponent_sim_visual_index >= 0 and opponent_sim_visual_index < opponent_sim_visual_steps.size():
		current_text = str(opponent_sim_visual_steps[opponent_sim_visual_index].get("text", ""))
	snapshot["current_text"] = current_text
	snapshot["current_index"] = opponent_sim_visual_index
	snapshot["action_count"] = opponent_sim_visual_steps.size()
	snapshot["pending_points_scored"] = int(pending_opponent_sim_result.get("points_scored", 0))
	snapshot["pending_time_consumed"] = float(pending_opponent_sim_result.get("time_consumed", 0.0))
	snapshot["presentation_visible"] = opponent_sim_presentation != null and opponent_sim_presentation.visible
	snapshot["live_entities_hidden"] = opponent_sim_live_entities_hidden
	return snapshot


func get_opponent_sim_banner_snapshot() -> Dictionary:
	if opponent_sim_banner == null:
		return {}
	return opponent_sim_banner.get_layout_snapshot()


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


func are_defenders_disabled() -> bool:
	return defenders_disabled


func are_controls_visible() -> bool:
	return controls_visible


func test_toggle_pause() -> void:
	_toggle_pause()


func test_set_defenders_disabled(enabled: bool) -> void:
	_set_defenders_disabled(enabled)


func test_set_controls_visible(enabled: bool) -> void:
	_set_controls_visible(enabled)


func test_force_opponent_sim() -> void:
	_run_opponent_possession()


func test_force_opponent_sim_result(points_scored: int = 0, action_count: int = 1, time_consumed: float = 4.0) -> void:
	var clamped_count: int = clampi(action_count, 1, 4)
	var steps: Array[Dictionary] = []
	for index in maxi(clamped_count - 1, 0):
		var setup_text: String = "Pass to AWY" if index % 2 == 0 else "Drive by AWY"
		steps.append({
			"text": setup_text,
			"kind": "pass" if index % 2 == 0 else "drive",
			"player": "AWY",
			"points": 0,
			"is_final": false,
		})
	var final_text: String = "Turnover from AWY"
	var final_kind: String = "turnover"
	if points_scored == 2:
		final_text = "Layup from AWY"
		final_kind = "layup"
	elif points_scored == 3:
		final_text = "Corner three from AWY"
		final_kind = "corner_three"
	steps.append({
		"text": final_text,
		"kind": final_kind,
		"player": "AWY",
		"points": points_scored,
		"is_final": true,
	})
	_clear_steal_resolve()
	_clear_pending_shot_release()
	_clear_active_shot_sequence()
	_set_ball_visual_hidden(null)
	_change_state(GameState.State.OPPONENT_SIM)
	_begin_opponent_sim_sequence({
		"events": PackedStringArray(["test opponent sim"]),
		"points_scored": points_scored,
		"time_consumed": time_consumed,
		"visual_steps": steps,
	})


func test_advance_opponent_sim_sequence() -> void:
	_advance_opponent_sim_sequence()


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
	_clear_pending_shot_release()
	_clear_active_shot_sequence()
	_clear_score_followthrough(false)
	_set_ball_visual_world()
	ball_simulator.launch_shot_profile(_prepare_guided_make_profile_for_launch(launch_profile))
	_sync_ball_world_visual(ball_simulator.position_xy, ball_simulator.z)
	change_state(GameState.State.SHOT_IN_FLIGHT)
	log_writer.log_match("Test scoring shot queued for %s" % shooter.get_display_name())


func test_force_rebound_state(zone: Vector2) -> void:
	active_rebound_zone = zone
	ball_simulator.is_in_flight = false
	ball_simulator.already_scored = false
	_clear_pending_shot_release()
	_clear_active_shot_sequence()
	_set_ball_visual_world()
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
	var forced_pass: Dictionary = pass_controller.force_interception(_get_active_defenders())
	if forced_pass.is_empty():
		return
	log_writer.log_match("Scripted pass interception armed")
	log_writer.log_event(
		"pass_forced_interception",
		{
			"interceptor": _player_name_or_empty(forced_pass.get("active_interceptor", null)),
			"chase_point": _vector2_payload(forced_pass.get("chase_point", Vector2.ZERO)),
		}
	)


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


func get_ball_screen_anchor() -> Vector2:
	if ball_node == null:
		return Vector2.INF
	return ball_node.position + ball_node.ball_screen_offset


func get_score_followthrough_snapshot() -> Dictionary:
	return score_followthrough_state.duplicate(true)


func did_last_scored_shot_pass_through_net() -> bool:
	return last_scored_shot_passed_through_net


func get_score_followthrough_active() -> bool:
	return bool(score_followthrough_state.get("active", false))


func get_net_swish_active() -> bool:
	return hoop_node != null and hoop_node.has_method("is_net_swish_active") and bool(hoop_node.call("is_net_swish_active"))


func get_layout_metrics_snapshot() -> Dictionary:
	return layout_metrics.duplicate(true)


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
	_set_ball_visual_world()
	_sync_ball_world_visual(ball_simulator.position_xy, ball_simulator.z)


func _sync_projection_visuals(delta: float = 0.0) -> void:
	if court_projection == null:
		return
	for player in offense_players + defense_players:
		player.sync_visual_state(_build_player_visual_request(player), delta)
	_advance_active_dunk_root_motion(delta)
	_maybe_commit_pending_shot_release()
	_update_camera_tracking(delta)
	if opponent_sim_presentation != null:
		opponent_sim_presentation.call("sync_projection", delta)
	if hoop_node != null:
		hoop_node.set_projection(court_projection)
		hoop_node.advance_visual_animation(delta)
	_maybe_refresh_finish_logic_center_world_cache()
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
	_update_default_pass_target()
	_maybe_finish_active_shot_sequence()
	_sync_shot_meter_display()
	_sync_ball_visuals()
	if court_view != null and input_controller != null:
		court_view.set_input_feedback(_build_court_input_feedback())
	if control_panel != null and input_controller != null:
		control_panel.set_panel_state(_build_control_panel_state())


func _update_camera_tracking(delta: float) -> void:
	if court_projection == null:
		return
	var tracking_target: Dictionary = _build_camera_tracking_target()
	if tracking_target.is_empty():
		return
	var next_signature: String = str(tracking_target.get("signature", ""))
	var should_snap: bool = next_signature.begins_with("ball") \
		or next_signature.begins_with("opponent_sim") \
		or next_signature == "score_followthrough_finish"
	var base_target_screen: Vector2 = tracking_target.get("base_screen", court_projection.get_viewport_rect().get_center())
	var post_camera_offset: Vector2 = tracking_target.get("post_camera_offset", Vector2.ZERO)
	court_projection.update_camera_target(base_target_screen, delta, should_snap, post_camera_offset)
	camera_tracking_signature = next_signature


func _build_camera_tracking_target() -> Dictionary:
	if _should_use_score_followthrough_finish_camera():
		return _build_score_followthrough_finish_camera_target()
	match context.current_state:
		GameState.State.PASS_IN_FLIGHT, GameState.State.SHOT_IN_FLIGHT, GameState.State.REBOUND_LIVE:
			return _build_ball_camera_tracking_target()
		GameState.State.OPPONENT_SIM:
			return _build_opponent_sim_camera_tracking_target()
		GameState.State.STEAL_RESOLVE:
			if current_steal_holder != null:
				return _build_player_camera_tracking_target(current_steal_holder)
	if current_ballhandler != null:
		return _build_player_camera_tracking_target(current_ballhandler)
	if current_steal_holder != null:
		return _build_player_camera_tracking_target(current_steal_holder)
	return {}


func _should_use_score_followthrough_finish_camera() -> bool:
	if context.current_state != GameState.State.SHOT_IN_FLIGHT:
		return false
	if not ball_simulator.is_guided_make_profile():
		return false
	var phase: String = ball_simulator.get_flight_phase()
	if phase in [
		BallSimulator.FLIGHT_PHASE_FLOOR_DROP,
		BallSimulator.FLIGHT_PHASE_FLOOR_SETTLE,
	]:
		return true
	return (
		last_scored_shot_passed_through_net
		and not ball_simulator.is_in_flight
		and made_shot_animation_timer > 0.0
	)


func _build_score_followthrough_finish_camera_target() -> Dictionary:
	if court_projection == null:
		return {}
	var viewport_center: Vector2 = court_projection.get_viewport_rect().get_center()
	var finish_target_world: Vector2 = ball_simulator.shot_profile.get("floor_target_xy", get_finish_logic_center_world())
	var finish_target_screen_anchor: Vector2 = ball_simulator.shot_profile.get("floor_target_screen_anchor", Vector2.INF)
	if is_inf(finish_target_screen_anchor.x) or is_inf(finish_target_screen_anchor.y):
		finish_target_screen_anchor = _get_finish_logic_center_screen_from_current_view()
	return {
		"base_screen": court_projection.world_to_base_screen_ground(finish_target_world),
		"post_camera_offset": viewport_center - finish_target_screen_anchor,
		"signature": "score_followthrough_finish",
	}


func _build_player_camera_tracking_target(player: PlayerController) -> Dictionary:
	if player == null or court_projection == null:
		return {}
	return {
		"base_screen": court_projection.player_tracking_anchor_base_screen(player.world_position),
		"post_camera_offset": Vector2.ZERO,
		"signature": "player_%s" % player.get_instance_id(),
	}


func _build_opponent_sim_camera_tracking_target() -> Dictionary:
	if court_projection == null or court_config == null:
		return {}
	var camera_anchor_world: Vector2 = court_config.opposite_hoop_position
	if opponent_sim_presentation != null:
		camera_anchor_world = opponent_sim_presentation.call("get_camera_anchor_world")
	if camera_anchor_world == Vector2.ZERO:
		camera_anchor_world = court_config.opposite_hoop_position
	return {
		"base_screen": court_projection.player_tracking_anchor_base_screen(camera_anchor_world),
		"post_camera_offset": Vector2.ZERO,
		"signature": "opponent_sim_%d" % opponent_sim_visual_index,
	}


func _build_ball_camera_tracking_target() -> Dictionary:
	if court_projection == null:
		return {}
	if ball_visual_mode == BallVisualMode.HIDDEN_WHILE_OWNED and ball_visual_owner != null:
		return _build_player_camera_tracking_target(ball_visual_owner)
	var render_context: Dictionary = _resolve_ball_render_context(ball_simulator.position_xy, ball_simulator.z, ball_simulator.vz)
	return {
		"base_screen": court_projection.world_to_base_screen(ball_simulator.position_xy, ball_simulator.z),
		"post_camera_offset": _get_render_context_screen_offset(render_context),
		"signature": "ball",
	}


func _sync_ball_visuals() -> void:
	if ball_node == null:
		return
	if ball_visual_mode == BallVisualMode.HIDDEN_WHILE_OWNED:
		if ball_visual_owner != null:
			_sync_ball_to_player(ball_visual_owner)
		else:
			_set_through_net_masks_active(false)
			if ball_node.has_method("set_ball_visible"):
				ball_node.call("set_ball_visible", false)
		return
	_sync_ball_world_visual(ball_simulator.position_xy, ball_simulator.z)


func _sync_ball_world_visual(world_position: Vector2, z_value: float, render_context: Dictionary = {}) -> void:
	if ball_node == null or court_projection == null:
		return
	if ball_node.has_method("set_ball_visible"):
		ball_node.call("set_ball_visible", true)
	var resolved_render_context: Dictionary = render_context
	if resolved_render_context.is_empty():
		resolved_render_context = _resolve_ball_render_context(world_position, z_value, ball_simulator.vz)
	_set_through_net_masks_active(bool(resolved_render_context.get("through_net_masks_active", resolved_render_context.get("bottom_half_net_mask_active", false))))
	var ground_anchor: Vector2 = court_projection.world_to_screen_ground(world_position)
	var screen_offset: Vector2 = _get_render_context_screen_offset(resolved_render_context)
	var ball_anchor: Vector2 = _get_ball_screen_anchor_for_world(world_position, z_value, screen_offset)
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
			"ball_radius": _get_live_ball_render_radius(z_ratio),
			"shadow_scale": court_projection.shadow_scale(world_position, z_value),
			"depth_key": court_projection.depth_key(world_position, z_value),
		},
		z_override,
		render_phase
	)
	_record_score_followthrough_render_snapshot(render_phase, z_override, ball_anchor, resolved_render_context)


func _get_held_ball_render_radius() -> float:
	if projection_config == null:
		return 16.0
	var presentation_scale: float = court_projection.get_presentation_scale() if court_projection != null else 1.0
	return maxf(projection_config.held_ball_render_radius * presentation_scale, 1.0)


func _get_live_ball_render_radius(z_ratio: float) -> float:
	if projection_config == null:
		return lerpf(15.0, 30.0, pow(z_ratio, 0.82))
	var clamped_ratio: float = clampf(z_ratio, 0.0, 1.0)
	var scaled_ratio: float = pow(clamped_ratio, 0.82)
	var presentation_scale: float = court_projection.get_total_presentation_scale() if court_projection != null else 1.0
	var min_radius: float = maxf(projection_config.live_ball_render_radius_min * presentation_scale, 1.0)
	var max_radius: float = maxf(projection_config.live_ball_render_radius_max * presentation_scale, min_radius)
	return lerpf(min_radius, max_radius, scaled_ratio)


func _clear_score_followthrough(reset_passed_flag: bool = true) -> void:
	score_followthrough_state.clear()
	current_ball_render_phase = ""
	_set_through_net_masks_active(false)
	_stop_score_followthrough_net_swish()
	if reset_passed_flag:
		last_scored_shot_passed_through_net = false


func _begin_score_followthrough(interaction: Dictionary) -> void:
	var start_xy: Vector2 = _clamp_score_followthrough_start(interaction.get("score_sample_xy", court_config.hoop_position))
	var entry_offset_x: float = start_xy.x - court_config.hoop_position.x
	var initial_pre_bounce_anchor: Vector2 = get_ball_screen_anchor()
	score_followthrough_state = {
		"active": true,
		"score_sample_xy": start_xy,
		"entry_offset_x": entry_offset_x,
		"net_swish_started": bool(score_followthrough_state.get("net_swish_started", false)),
		"handoff_active": false,
		"handoff_cleared": false,
		"handoff_phase": "",
		"handoff_screen_offset": Vector2.ZERO,
		"handoff_initial_screen_offset": Vector2.ZERO,
		"handoff_release_screen_y": hoop_node.get_front_net_exit_screen_y() if hoop_node != null and hoop_node.has_method("get_front_net_exit_screen_y") else 0.0,
		"handoff_cleared_net": false,
		"handoff_elapsed": 0.0,
		"handoff_duration": _get_score_followthrough_handoff_duration(),
		"handoff_just_started": false,
		"last_forced_render_phase": "",
		"last_forced_z_override": BallController.NO_Z_INDEX_OVERRIDE,
		"last_rendered_ball_anchor": Vector2.INF,
		"pre_bounce_last_rendered_anchor": initial_pre_bounce_anchor,
		"trace_index": 0,
		"trace_last_process_frame": -1,
	}
	current_ball_render_phase = ball_simulator.get_render_phase_name()
	if current_ball_render_phase != "" and hoop_node != null:
		score_followthrough_state["last_forced_render_phase"] = current_ball_render_phase
		score_followthrough_state["last_forced_z_override"] = hoop_node.get_ball_z_index_for_phase(current_ball_render_phase)
	last_scored_shot_passed_through_net = true
	_announce_score_followthrough_trace_destination()
	if hoop_node != null and hoop_node.has_method("trigger_net_swish") and not bool(score_followthrough_state.get("net_swish_started", false)):
		hoop_node.call("trigger_net_swish", entry_offset_x)
		score_followthrough_state["net_swish_started"] = true


func _advance_score_followthrough(_delta: float) -> void:
	if score_followthrough_state.is_empty():
		return
	var phase: String = ball_simulator.get_render_phase_name()
	var terminal_drop_active: bool = ball_simulator.get_terminal_visual_drop_weight() > 0.001
	var keep_followthrough_active: bool = ball_simulator.is_guided_make_profile() and (
		(ball_simulator.is_in_flight and (phase != "" or terminal_drop_active))
		or terminal_drop_active
	)
	score_followthrough_state["handoff_active"] = false
	score_followthrough_state["handoff_cleared"] = false
	if keep_followthrough_active:
		score_followthrough_state["active"] = true
		current_ball_render_phase = phase
		return
	score_followthrough_state["active"] = false
	current_ball_render_phase = ""
	_stop_score_followthrough_net_swish()


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
	var render_context: Dictionary = _resolve_ball_render_context(ball_simulator.position_xy, ball_simulator.z, ball_simulator.vz)
	var render_phase: String = str(render_context.get("render_phase", current_ball_render_phase))
	return {
		"position": ball_simulator.position_xy,
		"z": ball_simulator.z,
		"render_phase": render_phase,
		"z_index_override": int(render_context.get("z_index_override", BallController.NO_Z_INDEX_OVERRIDE)),
		"bottom_half_net_mask_active": bool(render_context.get("bottom_half_net_mask_active", false)),
		"net_body_mask_active": bool(render_context.get("net_body_mask_active", false)),
		"through_net_masks_active": bool(render_context.get("through_net_masks_active", false)),
		"screen_offset": _get_render_context_screen_offset(render_context),
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
	var uses_explicit_hoop_phase: bool = false
	if render_phase == "":
		var guided_phase: String = ball_simulator.get_render_phase_name()
		if ball_simulator.is_guided_make_profile() and guided_phase != "":
			render_phase = guided_phase
			uses_explicit_hoop_phase = true
	var screen_drop_px: float = _get_guided_make_terminal_screen_drop_px()
	if render_phase == "" and _is_ball_in_hoop_render_zone(world_position, z_value):
		render_phase = hoop_node.get_ball_render_phase(world_position, z_value, vz_value < 0.0, false, ball_config.ball_radius)
	if render_phase == "" and screen_drop_px <= 0.001:
		return {}
	var through_net_masks_active: bool = _should_activate_through_net_masks(render_phase, uses_explicit_hoop_phase)
	var render_context: Dictionary = {
		"screen_drop_px": screen_drop_px,
		"screen_offset": Vector2(0.0, screen_drop_px),
		"is_followthrough_handoff": false,
		"uses_explicit_hoop_phase": uses_explicit_hoop_phase,
		"bottom_half_net_mask_active": through_net_masks_active,
		"net_body_mask_active": through_net_masks_active,
		"through_net_masks_active": through_net_masks_active,
	}
	if render_phase != "":
		render_context["render_phase"] = render_phase
		render_context["z_index_override"] = hoop_node.get_ball_z_index_for_phase(render_phase)
	return _apply_pre_bounce_render_continuity(world_position, z_value, render_context)


func _should_activate_through_net_masks(render_phase: String, uses_explicit_hoop_phase: bool) -> bool:
	if render_phase == HoopView.BALL_RENDER_PHASE_NET_CHANNEL:
		return true
	if render_phase != HoopView.BALL_RENDER_PHASE_FRONT_OF_NET:
		return false
	if uses_explicit_hoop_phase and ball_simulator.is_guided_make_profile():
		return true
	if bool(score_followthrough_state.get("active", false)) and last_scored_shot_passed_through_net:
		return true
	if bool(score_followthrough_state.get("handoff_active", false)):
		return true
	return false


func _get_guided_make_terminal_screen_drop_px() -> float:
	if court_projection == null or not ball_simulator.is_guided_make_profile():
		return 0.0
	return court_projection.guided_make_terminal_screen_drop(ball_simulator.get_terminal_visual_drop_weight())


func _prepare_guided_make_profile_for_launch(profile: Dictionary) -> Dictionary:
	if str(profile.get("profile_kind", "")) != ShotController.PROFILE_KIND_GUIDED_MAKE:
		return profile
	_maybe_refresh_finish_logic_center_world_cache()
	var prepared_profile: Dictionary = profile.duplicate(true)
	prepared_profile["floor_target_xy"] = get_finish_logic_center_world()
	prepared_profile["floor_target_screen_anchor"] = _get_finish_logic_center_screen()
	prepared_profile["floor_drop_duration"] = ball_config.made_shot_floor_drop_duration if ball_config != null else 0.46
	prepared_profile["floor_settle_hop_height"] = ball_config.made_shot_floor_settle_hop_height if ball_config != null else 12.0
	prepared_profile["floor_settle_duration"] = ball_config.made_shot_floor_settle_duration if ball_config != null else 0.12
	return prepared_profile


func _get_score_followthrough_handoff_duration() -> float:
	var base_duration: float = 0.09
	if ball_config != null:
		base_duration = ball_config.made_shot_floor_drop_duration * SCORE_FOLLOWTHROUGH_HANDOFF_DURATION_RATIO
	return clampf(base_duration, SCORE_FOLLOWTHROUGH_HANDOFF_MIN_DURATION, SCORE_FOLLOWTHROUGH_HANDOFF_MAX_DURATION)


func _is_score_followthrough_handoff_active() -> bool:
	return bool(score_followthrough_state.get("handoff_active", false))


func _stop_score_followthrough_net_swish() -> void:
	if hoop_node != null and hoop_node.has_method("stop_net_swish"):
		hoop_node.call("stop_net_swish")


func _get_render_context_screen_offset(render_context: Dictionary) -> Vector2:
	return render_context.get("screen_offset", Vector2(0.0, float(render_context.get("screen_drop_px", 0.0))))


func _get_ball_screen_anchor_for_world(world_position: Vector2, z_value: float, screen_offset: Vector2 = Vector2.ZERO) -> Vector2:
	if court_projection == null:
		return world_position + screen_offset
	return court_projection.world_to_screen(world_position, z_value) + screen_offset


func _should_enforce_pre_bounce_render_continuity() -> bool:
	if score_followthrough_state.is_empty() or not ball_simulator.is_guided_make_profile():
		return false
	return ball_simulator.get_flight_phase() in [
		BallSimulator.FLIGHT_PHASE_GUIDED_DESCENT,
		BallSimulator.FLIGHT_PHASE_NET_EXIT,
		BallSimulator.FLIGHT_PHASE_FLOOR_DROP,
	]


func _clamp_pre_bounce_render_offset(world_position: Vector2, z_value: float, screen_offset: Vector2) -> Dictionary:
	var resolved_offset: Vector2 = screen_offset
	var world_anchor: Vector2 = _get_ball_screen_anchor_for_world(world_position, z_value)
	var rendered_anchor: Vector2 = world_anchor + resolved_offset
	if not _should_enforce_pre_bounce_render_continuity():
		return {
			"screen_offset": resolved_offset,
			"rendered_anchor": rendered_anchor,
		}
	var last_anchor: Vector2 = score_followthrough_state.get("pre_bounce_last_rendered_anchor", Vector2.INF)
	if not is_inf(last_anchor.x) and not is_inf(last_anchor.y) and rendered_anchor.y < last_anchor.y - SCORE_FOLLOWTHROUGH_PRE_BOUNCE_CONTINUITY_EPSILON:
		resolved_offset.y = maxf(last_anchor.y - world_anchor.y, 0.0)
		rendered_anchor = world_anchor + resolved_offset
	score_followthrough_state["pre_bounce_last_rendered_anchor"] = rendered_anchor
	return {
		"screen_offset": resolved_offset,
		"rendered_anchor": rendered_anchor,
	}


func _apply_pre_bounce_render_continuity(world_position: Vector2, z_value: float, render_context: Dictionary) -> Dictionary:
	if render_context.is_empty():
		return render_context
	var resolved_context: Dictionary = render_context.duplicate(true)
	var continuity: Dictionary = _clamp_pre_bounce_render_offset(
		world_position,
		z_value,
		_get_render_context_screen_offset(resolved_context)
	)
	var resolved_offset: Vector2 = continuity.get("screen_offset", Vector2.ZERO)
	resolved_context["screen_offset"] = resolved_offset
	resolved_context["screen_drop_px"] = resolved_offset.y
	return resolved_context


func _record_score_followthrough_render_snapshot(render_phase: String, z_override: int, ball_anchor: Vector2, render_context: Dictionary) -> void:
	if score_followthrough_state.is_empty() or not bool(render_context.get("uses_explicit_hoop_phase", false)):
		return
	score_followthrough_state["last_forced_render_phase"] = render_phase
	score_followthrough_state["last_forced_z_override"] = z_override
	score_followthrough_state["last_rendered_ball_anchor"] = ball_anchor


func _begin_score_followthrough_handoff() -> void:
	if score_followthrough_state.is_empty() or hoop_node == null:
		return
	if bool(score_followthrough_state.get("handoff_active", false)) or bool(score_followthrough_state.get("handoff_cleared", false)):
		return
	var current_world_anchor: Vector2 = _get_ball_screen_anchor_for_world(ball_simulator.position_xy, ball_simulator.z)
	var last_rendered_anchor: Vector2 = score_followthrough_state.get("last_rendered_ball_anchor", Vector2.INF)
	if is_inf(last_rendered_anchor.x) or is_inf(last_rendered_anchor.y):
		last_rendered_anchor = current_world_anchor
	var handoff_offset: Vector2 = last_rendered_anchor - current_world_anchor
	if handoff_offset.y < 0.0:
		handoff_offset.y = 0.0
	var handoff_phase: String = HoopView.BALL_RENDER_PHASE_FRONT_OF_NET
	score_followthrough_state["handoff_active"] = true
	score_followthrough_state["handoff_cleared"] = false
	score_followthrough_state["handoff_phase"] = handoff_phase
	score_followthrough_state["handoff_screen_offset"] = handoff_offset
	score_followthrough_state["handoff_initial_screen_offset"] = handoff_offset
	score_followthrough_state["handoff_elapsed"] = 0.0
	score_followthrough_state["handoff_cleared_net"] = false
	score_followthrough_state["handoff_just_started"] = true
	score_followthrough_state["handoff_release_screen_y"] = hoop_node.get_front_net_exit_screen_y()
	score_followthrough_state["last_forced_render_phase"] = handoff_phase
	score_followthrough_state["last_forced_z_override"] = hoop_node.get_ball_z_index_for_phase(handoff_phase)
	score_followthrough_state["active"] = true
	current_ball_render_phase = handoff_phase
	_set_through_net_masks_active(true)
	_stop_score_followthrough_net_swish()
	_trace_score_followthrough("handoff_begin", {}, true)


func _advance_score_followthrough_handoff(delta: float) -> void:
	if score_followthrough_state.is_empty() or not bool(score_followthrough_state.get("handoff_active", false)):
		return
	var current_offset: Vector2 = score_followthrough_state.get("handoff_screen_offset", Vector2.ZERO)
	if bool(score_followthrough_state.get("handoff_just_started", false)):
		score_followthrough_state["handoff_just_started"] = false
	else:
		var handoff_duration: float = maxf(float(score_followthrough_state.get("handoff_duration", _get_score_followthrough_handoff_duration())), 0.001)
		var elapsed: float = minf(float(score_followthrough_state.get("handoff_elapsed", 0.0)) + delta, handoff_duration)
		var progress: float = clampf(elapsed / handoff_duration, 0.0, 1.0)
		var initial_offset: Vector2 = score_followthrough_state.get("handoff_initial_screen_offset", current_offset)
		current_offset = initial_offset * (1.0 - progress)
		if current_offset.length() <= SCORE_FOLLOWTHROUGH_HANDOFF_CLEAR_EPSILON or progress >= 1.0:
			current_offset = Vector2.ZERO
		score_followthrough_state["handoff_elapsed"] = elapsed
	var continuity: Dictionary = _clamp_pre_bounce_render_offset(ball_simulator.position_xy, ball_simulator.z, current_offset)
	current_offset = continuity.get("screen_offset", current_offset)
	score_followthrough_state["handoff_screen_offset"] = current_offset
	var rendered_anchor: Vector2 = continuity.get(
		"rendered_anchor",
		_get_ball_screen_anchor_for_world(ball_simulator.position_xy, ball_simulator.z, current_offset)
	)
	var release_screen_y: float = float(score_followthrough_state.get("handoff_release_screen_y", 0.0))
	if hoop_node != null and hoop_node.has_method("get_front_net_exit_screen_y"):
		release_screen_y = hoop_node.get_front_net_exit_screen_y()
		score_followthrough_state["handoff_release_screen_y"] = release_screen_y
	var cleared_net: bool = rendered_anchor.y >= release_screen_y - SCORE_FOLLOWTHROUGH_HANDOFF_CLEAR_EPSILON
	score_followthrough_state["handoff_cleared_net"] = cleared_net
	score_followthrough_state["active"] = true
	current_ball_render_phase = str(score_followthrough_state.get("handoff_phase", HoopView.BALL_RENDER_PHASE_FRONT_OF_NET))
	if cleared_net and current_offset.length() <= SCORE_FOLLOWTHROUGH_HANDOFF_CLEAR_EPSILON:
		score_followthrough_state["handoff_active"] = false
		score_followthrough_state["handoff_cleared"] = true
		score_followthrough_state["handoff_screen_offset"] = Vector2.ZERO
		score_followthrough_state["active"] = false
		current_ball_render_phase = ""
		_set_through_net_masks_active(false)
		_trace_score_followthrough("handoff_cleared", {}, true)


func _set_bottom_half_net_mask_active(active: bool) -> void:
	if hoop_node != null and hoop_node.has_method("set_bottom_half_net_mask_active"):
		hoop_node.call("set_bottom_half_net_mask_active", active)


func _set_net_body_mask_active(active: bool) -> void:
	if hoop_node != null and hoop_node.has_method("set_net_body_mask_active"):
		hoop_node.call("set_net_body_mask_active", active)


func _set_through_net_masks_active(active: bool) -> void:
	if hoop_node != null and hoop_node.has_method("set_through_net_masks_active"):
		hoop_node.call("set_through_net_masks_active", active)
		return
	_set_bottom_half_net_mask_active(active)
	_set_net_body_mask_active(active)


func _is_ball_in_hoop_render_zone(world_position: Vector2, z_value: float) -> bool:
	var half_width: float = court_config.backboard_width * 0.5 + court_config.rim_radius + 56.0
	if absf(world_position.x - court_config.backboard_x_center) > half_width:
		return false
	if world_position.y <= court_config.backboard_y + 24.0:
		return true
	if world_position.y <= court_config.hoop_position.y + court_config.net_followthrough_depth + 132.0:
		return true
	return z_value >= court_config.net_exit_z


func _update_default_pass_target() -> void:
	if context.current_state != GameState.State.LIVE_OFFENSE or current_ballhandler == null:
		default_pass_target = null
		default_pass_target_details.clear()
		return
	var active_defenders: Array[PlayerController] = _get_active_defenders()
	var best_target: PlayerController
	var best_details: Dictionary = {}
	for teammate in offense_players:
		if teammate == null or teammate == current_ballhandler:
			continue
		var candidate: Dictionary = pass_controller.evaluate_pass_target(
			current_ballhandler.world_position,
			teammate,
			active_defenders,
			current_ballhandler
		)
		if candidate.is_empty():
			continue
		if best_target == null:
			best_target = teammate
			best_details = candidate
			continue
		var candidate_commit: float = float(candidate.get("commit_chance", INF))
		var best_commit: float = float(best_details.get("commit_chance", INF))
		if candidate_commit < best_commit - 0.0001:
			best_target = teammate
			best_details = candidate
			continue
		if absf(candidate_commit - best_commit) <= 0.0001:
			var candidate_distance: float = float(candidate.get("distance", INF))
			var best_distance: float = float(best_details.get("distance", INF))
			if candidate_distance < best_distance - 0.0001:
				best_target = teammate
				best_details = candidate
				continue
			if absf(candidate_distance - best_distance) <= 0.0001 and teammate.world_position.y < best_target.world_position.y - 0.0001:
				best_target = teammate
				best_details = candidate
	default_pass_target = best_target
	default_pass_target_details = best_details.duplicate(true)


func _build_court_input_feedback() -> Dictionary:
	var feedback: Dictionary = {}
	if context.current_state == GameState.State.LIVE_OFFENSE and default_pass_target != null:
		feedback["pass_target_screen"] = court_projection.world_to_screen_ground(default_pass_target.world_position)
		feedback["pass_target_radius"] = maxf(22.0 * default_pass_target.projected_scale, 16.0)
		feedback["pass_target_style"] = "blue_ring"
	else:
		feedback["pass_target_screen"] = Vector2.INF
		feedback.erase("pass_target_style")
	return feedback


func _build_control_panel_state() -> Dictionary:
	var panel_state: Dictionary = input_controller.get_touch_feedback_snapshot() if input_controller != null else {}
	var dunk_button_state: Dictionary = _build_dunk_button_state()
	panel_state["controls_visible"] = controls_visible and not opponent_sim_match_ui_hidden
	panel_state["pass_available"] = context.current_state == GameState.State.LIVE_OFFENSE and default_pass_target != null
	panel_state["pass_target_role"] = default_pass_target.get_position_role() if default_pass_target != null else ""
	panel_state["pass_target_name"] = default_pass_target.get_display_name() if default_pass_target != null else ""
	panel_state["dunk_available"] = bool(dunk_button_state.get("available", false))
	panel_state["dunk_commits_dunk"] = bool(dunk_button_state.get("dunk_eligible", false))
	panel_state["interactive"] = context.current_state == GameState.State.LIVE_OFFENSE
	panel_state["shot_meter"] = _get_current_shot_meter_snapshot()
	return panel_state


func _build_dunk_button_state() -> Dictionary:
	if context.current_state != GameState.State.LIVE_OFFENSE or current_ballhandler == null:
		return {
			"available": false,
			"close_finish_eligible": false,
			"dunk_eligible": false,
		}
	var finish_gate_state: Dictionary = _build_close_finish_gate_state(current_ballhandler, Vector2.INF, "dunk")
	return {
		"available": bool(finish_gate_state.get("close_finish_eligible", false)),
		"close_finish_eligible": bool(finish_gate_state.get("close_finish_eligible", false)),
		"dunk_eligible": bool(finish_gate_state.get("dunk_eligible", false)),
	}


func _get_current_shot_meter_snapshot() -> Dictionary:
	if context.current_state != GameState.State.SHOT_AIM or active_shot_sequence.is_empty() or not shot_controller.is_aiming:
		return {}
	var shooter: PlayerController = active_shot_sequence.get("player", null) as PlayerController
	if shooter == null or shooter.get_player_data() == null:
		return {}
	var contested: bool = defense_controller.is_contested(shooter)
	return shot_controller.get_meter_snapshot(contested, shooter.get_player_data().release_consistency)


func _format_clock_text(time_remaining: float) -> String:
	var total_seconds: int = maxi(int(ceil(time_remaining)), 0)
	return "%d:%02d" % [total_seconds / 60, total_seconds % 60]


func _build_player_visual_request(player: PlayerController):
	if player.shot_pose_timer <= 0.0 and not _has_active_shot_sequence_for_player(player):
		shot_visual_locks.erase(player)
	var family: String = _resolve_player_animation_family(player)
	var memory: Dictionary = player_visual_memory.get(player, {})
	var locked_shot_visual: Dictionary = _get_locked_shot_visual(player)
	var variant_index: int = 0
	var mirror_west: bool = bool(memory.get("mirror_west", false))
	var start_frame_override: int = int(memory.get("start_frame_override", 1))
	if not locked_shot_visual.is_empty():
		variant_index = int(locked_shot_visual.get("variant_index", 0))
		mirror_west = bool(locked_shot_visual.get("mirror_west", false))
		start_frame_override = int(locked_shot_visual.get("start_frame_override", 1))
	else:
		variant_index = _resolve_variant_index_for_family(player, family, memory)
		var action_vector: Vector2 = _resolve_player_action_vector(player, family)
		mirror_west = _resolve_family_mirror_west(family, action_vector, mirror_west)
		start_frame_override = 1
	var force_restart: bool = str(memory.get("family", "")) != family or int(memory.get("variant_index", -1)) != variant_index
	force_restart = force_restart or int(memory.get("start_frame_override", 1)) != start_frame_override
	player_visual_memory[player] = {
		"family": family,
		"variant_index": variant_index,
		"mirror_west": mirror_west,
		"start_frame_override": start_frame_override,
	}
	return PLAYER_VISUAL_REQUEST_SCRIPT.new(
		family,
		variant_index,
		mirror_west,
		player.is_controlled,
		force_restart,
		_should_allow_dunk_contact_hold(player, family),
		start_frame_override
	)


func _resolve_player_animation_family(player: PlayerController) -> String:
	var memory: Dictionary = player_visual_memory.get(player, {})
	var previous_family: String = str(memory.get("family", ""))
	var speed: float = _get_player_visual_speed(player)
	if player.jump_pose_timer > 0.0:
		return "jump_contest"
	var locked_shot_visual: Dictionary = _get_locked_shot_visual(player)
	if not locked_shot_visual.is_empty():
		return str(locked_shot_visual.get("family", "jumper_release"))
	if player == current_ballhandler \
			and context.current_state == GameState.State.SHOT_AIM \
			and _has_active_shot_sequence_for_player(player) \
			and bool(active_shot_sequence.get("release_visual_deferred", false)):
		return "shot_aim"
	if player.shot_pose_timer > 0.0:
		return _resolve_shot_release_family(player)
	if player.catch_pose_timer > 0.0:
		return "ball_hold_secure"
	if player == current_ballhandler and context.current_state == GameState.State.SHOT_AIM:
		return "shot_aim"
	if player.has_ball:
		if _should_use_run_family(previous_family, speed):
			return "ball_move_run"
		if _should_use_move_family(previous_family, speed):
			return "ball_move_small"
		if _is_player_pressured(player):
			return "ball_idle_pressured"
		return "ball_idle_open"
	if not player.is_offense:
		return _resolve_defender_animation_family(previous_family, speed)
	if _should_use_run_family(previous_family, speed):
		return "off_ball_run"
	if speed > 0.0:
		return "off_ball_shuffle"
	return "no_ball_idle"


func _resolve_shot_release_family(player: PlayerController) -> String:
	return str(_resolve_shot_release_visual(player).get("family", "jumper_release"))


func _resolve_defender_animation_family(previous_family: String, speed: float) -> String:
	if _should_use_run_family(previous_family, speed):
		return "guard_run"
	if _should_use_move_family(previous_family, speed):
		return "guard_shuffle"
	return "guard_idle"


func _resolve_player_action_vector(player: PlayerController, family: String) -> Vector2:
	match family:
		"shot_aim":
			return get_finish_logic_center_world() - player.world_position
		"set_shot_release", "jumper_release", "close_finish_layup", "close_finish_dunk", "close_finish_side_dunk":
			return _resolve_shot_release_action_vector(player)
		"ball_move_small", "ball_move_run", "off_ball_shuffle", "off_ball_run":
			return _resolve_player_motion_vector(player)
		"ball_idle_open", "ball_idle_pressured":
			return get_finish_logic_center_world() - player.world_position
		"ball_hold_secure":
			if player.is_offense:
				return get_finish_logic_center_world() - player.world_position
			return _get_defender_assignment_vector(player)
		"guard_run":
			return _get_defender_guard_target(player) - player.world_position
		"guard_shuffle", "guard_idle", "jump_contest":
			return _get_defender_assignment_vector(player)
		_:
			return Vector2.ZERO


func _resolve_player_motion_vector(player: PlayerController) -> Vector2:
	if player == current_ballhandler and context.current_state == GameState.State.LIVE_OFFENSE and current_move_direction.length() > 0.08:
		return current_move_direction.normalized() * player.velocity.length()
	if player.velocity.length() > 1.0:
		return player.velocity
	return Vector2.ZERO


func _get_player_visual_speed(player: PlayerController) -> float:
	return _resolve_player_motion_vector(player).length()


func _get_locked_shot_visual(player: PlayerController) -> Dictionary:
	if player == null:
		return {}
	if _has_active_shot_sequence_for_player(player):
		if bool(active_shot_sequence.get("release_visual_deferred", false)):
			return {}
		return {
			"family": str(active_shot_sequence.get("family", "jumper_release")),
			"variant_index": int(active_shot_sequence.get("variant_index", 0)),
			"mirror_west": bool(active_shot_sequence.get("mirror_west", false)),
			"start_frame_override": int(active_shot_sequence.get("approach_start_frame", 1)),
		}
	if player.shot_pose_timer <= 0.0:
		return {}
	return shot_visual_locks.get(player, {})


func _should_use_move_family(previous_family: String, speed: float) -> bool:
	var move_enter_threshold: float = player_animation_config.stationary_speed_threshold
	var move_exit_threshold: float = minf(move_enter_threshold, player_animation_config.stationary_speed_release_threshold)
	if _is_run_family(previous_family):
		return speed > move_exit_threshold
	if _is_move_family(previous_family):
		return speed > move_exit_threshold
	return speed > move_enter_threshold


func _should_use_run_family(previous_family: String, speed: float) -> bool:
	var run_enter_threshold: float = player_animation_config.small_move_speed_threshold
	var run_exit_threshold: float = minf(run_enter_threshold, player_animation_config.small_move_speed_release_threshold)
	if _is_run_family(previous_family):
		return speed > run_exit_threshold
	return speed > run_enter_threshold


func _is_move_family(family: String) -> bool:
	return family == "ball_move_small" or family == "guard_shuffle" or family == "off_ball_shuffle"


func _is_run_family(family: String) -> bool:
	return family == "ball_move_run" or family == "guard_run" or family == "off_ball_run"


func _resolve_variant_index_for_family(player: PlayerController, family: String, memory: Dictionary) -> int:
	var variant_count: int = _get_variant_count_for_family(family)
	if variant_count <= 1:
		return 0
	if str(memory.get("family", "")) == family:
		return clampi(int(memory.get("variant_index", 0)), 0, variant_count - 1)
	match family:
		"close_finish_layup":
			return 1 if absf(player.world_position.x - court_config.hoop_position.x) >= player_animation_config.side_finish_lateral_threshold else 0
		"set_shot_release", "close_finish_side_dunk":
			return 0
		_:
			if visual_rng != null:
				return visual_rng.randi_range(0, variant_count - 1)
			return 0


func _resolve_mirror_west(action_vector: Vector2, current_mirror_west: bool) -> bool:
	if action_vector.length() < player_animation_config.facing_switch_min_vector_length:
		return current_mirror_west
	var normalized_x: float = action_vector.normalized().x
	if absf(normalized_x) < player_animation_config.facing_switch_normalized_x_threshold:
		return current_mirror_west
	return normalized_x < 0.0


func _resolve_family_mirror_west(family: String, action_vector: Vector2, current_mirror_west: bool) -> bool:
	if _should_apply_facing_hysteresis(family):
		return _resolve_mirror_west(action_vector, current_mirror_west)
	if action_vector.length_squared() <= 0.001:
		return current_mirror_west
	return action_vector.normalized().x < -0.12


func _should_apply_facing_hysteresis(family: String) -> bool:
	return family == "ball_move_small" \
		or family == "ball_move_run" \
		or family == "off_ball_shuffle" \
		or family == "off_ball_run" \
		or family == "guard_run" \
		or family == "guard_shuffle" \
		or family == "guard_idle"


func _is_dunk_family(family: String) -> bool:
	return family == "close_finish_dunk" or family == "close_finish_side_dunk"


func _should_allow_dunk_contact_hold(player: PlayerController, family: String) -> bool:
	if player == null or not _is_dunk_family(family):
		return false
	if context.current_state != GameState.State.SHOT_RELEASE:
		return false
	if pending_shot_release.is_empty():
		return false
	return pending_shot_release.get("player", null) == player and bool(pending_shot_release.get("use_dunk_contact_hold", false))


func _resolve_dunk_anchor_mirror_west(shooter: PlayerController) -> bool:
	if shooter == null:
		return false
	if _has_active_shot_sequence_for_player(shooter):
		return bool(active_shot_sequence.get("mirror_west", false))
	if not active_dunk_root_motion.is_empty() and active_dunk_root_motion.get("player", null) == shooter:
		return bool(active_dunk_root_motion.get("mirror_west", false))
	var locked_shot_visual: Dictionary = _get_locked_shot_visual(shooter)
	if not locked_shot_visual.is_empty():
		return bool(locked_shot_visual.get("mirror_west", false))
	var memory: Dictionary = player_visual_memory.get(shooter, {})
	if memory.has("mirror_west"):
		return bool(memory.get("mirror_west", false))
	return shooter.get_debug_flip_h()


func get_dunk_contact_anchor_offset_for_row(row_index: int, mirror_west: bool = false) -> Vector2:
	if player_animation_config != null:
		return player_animation_config.get_dunk_contact_anchor_offset(row_index, mirror_west)
	var default_offset: Vector2 = Vector2(0.0, 40.0)
	return Vector2(-default_offset.x, default_offset.y) if mirror_west else default_offset


func get_dunk_landing_anchor_offset_for_row(row_index: int, mirror_west: bool = false) -> Vector2:
	if player_animation_config != null:
		return player_animation_config.get_dunk_landing_anchor_offset(row_index, mirror_west)
	return get_dunk_contact_anchor_offset_for_row(row_index, mirror_west) + Vector2(0.0, 96.0)


func _get_dunk_contact_frame_for_row(row_index: int) -> int:
	if player_animation_config != null:
		return player_animation_config.get_dunk_contact_frame(row_index)
	match row_index:
		13:
			return 10
		15, 16:
			return 11
	return -1


func _get_dunk_run_end_frame_for_row(row_index: int) -> int:
	if player_animation_config != null:
		return player_animation_config.get_dunk_run_end_frame(row_index)
	match row_index:
		13, 15, 16:
			return 7
	return -1


func _get_dunk_jump_end_frame_for_row(row_index: int) -> int:
	if player_animation_config != null:
		return player_animation_config.get_dunk_jump_end_frame(row_index)
	match row_index:
		13:
			return 9
		15, 16:
			return 10
	return -1


func _get_dunk_contact_end_frame_for_row(row_index: int) -> int:
	if player_animation_config != null:
		return player_animation_config.get_dunk_contact_end_frame(row_index)
	match row_index:
		13:
			return 10
		15:
			return 11
		16:
			return 12
	return -1


func _get_dunk_jump_start_frame_for_row(row_index: int) -> int:
	if player_animation_config != null:
		return player_animation_config.get_dunk_jump_start_frame(row_index)
	return max(_get_dunk_run_end_frame_for_row(row_index) + 1, 1)


func _get_dunk_medium_start_frame_for_row(row_index: int) -> int:
	if player_animation_config != null:
		return player_animation_config.get_dunk_medium_start_frame(row_index)
	return max(_get_dunk_run_end_frame_for_row(row_index) - 2, 1)


func _get_dunk_smart_start_short_distance() -> float:
	if player_animation_config != null:
		return maxf(player_animation_config.dunk_smart_start_short_distance, 0.0)
	return 90.0


func _get_dunk_smart_start_medium_distance() -> float:
	if player_animation_config != null:
		return maxf(player_animation_config.dunk_smart_start_medium_distance, _get_dunk_smart_start_short_distance())
	return 120.0


func _resolve_dunk_approach_bucket(distance_to_hoop: float) -> String:
	if player_animation_config != null:
		return player_animation_config.get_dunk_approach_bucket(distance_to_hoop)
	if distance_to_hoop <= _get_dunk_smart_start_short_distance() + PlayerAnimationConfig.DUNK_SMART_START_DISTANCE_EPSILON:
		return "short"
	if distance_to_hoop < _get_dunk_smart_start_medium_distance() - PlayerAnimationConfig.DUNK_SMART_START_DISTANCE_EPSILON:
		return "medium"
	return "max"


func _resolve_dunk_approach_start_frame(row_index: int, distance_to_hoop: float) -> int:
	if player_animation_config != null:
		return player_animation_config.resolve_dunk_approach_start_frame(row_index, distance_to_hoop)
	var jump_start_frame: int = clampi(_get_dunk_jump_start_frame_for_row(row_index), 1, maxi(_get_dunk_contact_frame_for_row(row_index) - 1, 1))
	var medium_start_frame: int = clampi(_get_dunk_medium_start_frame_for_row(row_index), 1, jump_start_frame)
	var short_distance: float = _get_dunk_smart_start_short_distance()
	var medium_distance: float = _get_dunk_smart_start_medium_distance()
	var dunk_finish_radius: float = 135.0
	if distance_to_hoop >= dunk_finish_radius - PlayerAnimationConfig.DUNK_SMART_START_DISTANCE_EPSILON:
		return 1
	if distance_to_hoop <= short_distance + PlayerAnimationConfig.DUNK_SMART_START_DISTANCE_EPSILON:
		return jump_start_frame
	if distance_to_hoop < medium_distance - PlayerAnimationConfig.DUNK_SMART_START_DISTANCE_EPSILON:
		var medium_alpha: float = inverse_lerp(short_distance, medium_distance, clampf(distance_to_hoop, short_distance, medium_distance))
		return clampi(ceili(lerpf(float(jump_start_frame), float(medium_start_frame), medium_alpha)), 1, jump_start_frame)
	if distance_to_hoop <= dunk_finish_radius + PlayerAnimationConfig.DUNK_SMART_START_DISTANCE_EPSILON and dunk_finish_radius > medium_distance:
		var max_alpha: float = inverse_lerp(medium_distance, dunk_finish_radius, clampf(distance_to_hoop, medium_distance, dunk_finish_radius))
		return clampi(ceili(lerpf(float(medium_start_frame), 1.0, max_alpha)), 1, medium_start_frame)
	return 1


func _get_dunk_landing_ease_power() -> float:
	if player_animation_config != null:
		return maxf(player_animation_config.dunk_landing_ease_power, 0.01)
	return 1.8


func _get_active_dunk_root_motion_remaining_seconds() -> float:
	if active_dunk_root_motion.is_empty():
		return 0.0
	var shooter: PlayerController = active_dunk_root_motion.get("player", null) as PlayerController
	if shooter == null:
		return 0.0
	var total_frames: int = int(active_dunk_root_motion.get("total_frames", 0))
	if total_frames <= 0:
		return 0.0
	var fps: float = 15.0
	if _has_active_shot_sequence_for_player(shooter):
		fps = float(Dictionary(active_shot_sequence.get("timing_profile", {})).get("fps", fps))
	return maxf(float(total_frames) - shooter.get_debug_frame_progress(), 0.0) / maxf(fps, 0.001)


func _resolve_dunk_contact_row_index(shooter: PlayerController) -> int:
	if shooter == null:
		return -1
	if _has_active_shot_sequence_for_player(shooter):
		var active_row_index: int = PlayerVisual.get_row_index_for_family_variant(
			str(active_shot_sequence.get("family", "")),
			int(active_shot_sequence.get("variant_index", 0))
		)
		if active_row_index > 0:
			return active_row_index
	var visual_row_index: int = shooter.get_debug_row_index()
	if visual_row_index > 0:
		return visual_row_index
	return -1


func _build_dunk_contact_snap_snapshot(shooter: PlayerController) -> Dictionary:
	if shooter == null:
		return {}
	var row_index: int = _resolve_dunk_contact_row_index(shooter)
	var mirror_west: bool = _resolve_dunk_anchor_mirror_west(shooter)
	var anchor_offset: Vector2 = get_dunk_contact_anchor_offset_for_row(row_index, mirror_west)
	var snapped_world_position: Vector2 = court_config.hoop_position + anchor_offset
	var ground_screen: Vector2 = (
		court_projection.world_to_screen_ground(snapped_world_position)
		if court_projection != null
		else Vector2.ZERO
	)
	return {
		"row_index": row_index,
		"mirror_west": mirror_west,
		"anchor_offset": anchor_offset,
		"world_position": snapped_world_position,
		"ground_screen": ground_screen,
	}


func _begin_active_dunk_root_motion(shooter: PlayerController) -> void:
	_clear_active_dunk_root_motion(false)
	if shooter == null or court_config == null:
		return
	var row_index: int = _resolve_dunk_contact_row_index(shooter)
	if row_index <= 0:
		return
	var contact_start_frame: int = _get_dunk_contact_frame_for_row(row_index)
	var total_frames: int = PlayerVisual.ROW_FRAME_COUNTS[row_index - 1] if row_index >= 1 and row_index <= PlayerVisual.ROW_FRAME_COUNTS.size() else 0
	if contact_start_frame <= 1 or total_frames <= 0:
		return
	var approach_start_frame: int = clampi(int(active_shot_sequence.get("approach_start_frame", 1)), 1, contact_start_frame - 1)
	var run_end_frame: int = clampi(_get_dunk_run_end_frame_for_row(row_index), 1, contact_start_frame - 1)
	var jump_end_frame: int = clampi(_get_dunk_jump_end_frame_for_row(row_index), run_end_frame, contact_start_frame - 1)
	var contact_end_frame: int = clampi(_get_dunk_contact_end_frame_for_row(row_index), contact_start_frame, total_frames)
	var jump_start_frame: int = clampi(max(approach_start_frame, _get_dunk_jump_start_frame_for_row(row_index)), 1, contact_start_frame - 1)
	var visible_run_frame_count: int = max(run_end_frame - approach_start_frame + 1, 0) if approach_start_frame <= run_end_frame else 0
	var visible_jump_frame_count: int = max(contact_start_frame - jump_start_frame, 0)
	var release_start_world_position: Vector2 = shooter.world_position
	var mirror_west: bool = _resolve_dunk_anchor_mirror_west(shooter)
	var contact_anchor_world_position: Vector2 = court_config.hoop_position + get_dunk_contact_anchor_offset_for_row(row_index, mirror_west)
	var landing_anchor_world_position: Vector2 = court_config.hoop_position + get_dunk_landing_anchor_offset_for_row(row_index, mirror_west)
	var visible_approach_frame_count: int = visible_run_frame_count + visible_jump_frame_count
	var run_fraction: float = (
		clampf(float(visible_run_frame_count) / maxf(float(visible_approach_frame_count), 1.0), 0.0, 1.0)
		if visible_run_frame_count > 0
		else 0.0
	)
	var run_end_world_position: Vector2 = release_start_world_position.lerp(contact_anchor_world_position, run_fraction)
	var approach_distance_to_hoop: float = float(active_shot_sequence.get("approach_distance_to_hoop", release_start_world_position.distance_to(get_finish_logic_center_world())))
	var approach_bucket: String = str(active_shot_sequence.get("approach_bucket", _resolve_dunk_approach_bucket(approach_distance_to_hoop)))
	active_dunk_root_motion = {
		"player": shooter,
		"row_index": row_index,
		"mirror_west": mirror_west,
		"approach_start_frame": approach_start_frame,
		"approach_distance_to_hoop": approach_distance_to_hoop,
		"approach_bucket": approach_bucket,
		"release_start_world_position": release_start_world_position,
		"contact_anchor_world_position": contact_anchor_world_position,
		"landing_anchor_world_position": landing_anchor_world_position,
		"run_end_world_position": run_end_world_position,
		"jump_start_frame": jump_start_frame,
		"visible_run_frame_count": visible_run_frame_count,
		"visible_jump_frame_count": visible_jump_frame_count,
		"run_end_frame": run_end_frame,
		"jump_end_frame": jump_end_frame,
		"contact_start_frame": contact_start_frame,
		"contact_end_frame": contact_end_frame,
		"total_frames": total_frames,
		"last_applied_frame": 0,
		"last_phase": "",
	}
	var start_phase: String = _resolve_dunk_root_motion_phase(approach_start_frame, active_dunk_root_motion)
	log_writer.log_event(
		"dunk_root_motion_started",
		{
				"player": shooter.get_display_name(),
				"row": row_index,
				"mirror_west": mirror_west,
				"phase": start_phase,
				"frame": approach_start_frame,
			"distance_to_hoop": approach_distance_to_hoop,
			"approach_start_frame": approach_start_frame,
			"approach_bucket": approach_bucket,
			"release_start": _vector2_payload(release_start_world_position),
			"contact_anchor": _vector2_payload(contact_anchor_world_position),
			"landing_anchor": _vector2_payload(landing_anchor_world_position),
		}
	)


func _advance_active_dunk_root_motion(delta: float) -> void:
	if active_dunk_root_motion.is_empty():
		return
	var shooter: PlayerController = active_dunk_root_motion.get("player", null) as PlayerController
	if shooter == null:
		_clear_active_dunk_root_motion(false)
		return
	var current_frame: int = shooter.get_debug_frame_number()
	var current_frame_progress: float = shooter.get_debug_frame_progress()
	if current_frame <= 0:
		return
	var phase: String = _resolve_dunk_root_motion_phase(current_frame, active_dunk_root_motion)
	var resolved_position: Vector2 = _resolve_dunk_root_motion_world_position(current_frame_progress, active_dunk_root_motion)
	var total_frames: int = int(active_dunk_root_motion.get("total_frames", current_frame))
	var root_motion_completed: bool = current_frame >= total_frames and shooter.is_current_animation_complete()
	if root_motion_completed:
		phase = "landing"
		resolved_position = active_dunk_root_motion.get("landing_anchor_world_position", resolved_position)
	var previous_position: Vector2 = shooter.world_position
	shooter.world_position = resolved_position
	if delta > 0.0:
		var frame_delta: Vector2 = resolved_position - previous_position
		shooter.velocity = frame_delta / delta if frame_delta.length_squared() > 0.0001 else Vector2.ZERO
	else:
		shooter.velocity = Vector2.ZERO
	var last_phase: String = str(active_dunk_root_motion.get("last_phase", ""))
	var last_frame: int = int(active_dunk_root_motion.get("last_applied_frame", 0))
	if phase != last_phase or current_frame != last_frame:
		active_dunk_root_motion["last_phase"] = phase
		active_dunk_root_motion["last_applied_frame"] = current_frame
		if phase != last_phase:
			log_writer.log_event(
				"dunk_root_motion_phase",
				{
					"player": shooter.get_display_name(),
					"row": int(active_dunk_root_motion.get("row_index", shooter.get_debug_row_index())),
					"mirror_west": bool(active_dunk_root_motion.get("mirror_west", false)),
					"phase": phase,
					"frame": current_frame,
					"distance_to_hoop": active_dunk_root_motion.get("approach_distance_to_hoop", 0.0),
					"approach_start_frame": int(active_dunk_root_motion.get("approach_start_frame", 1)),
					"approach_bucket": str(active_dunk_root_motion.get("approach_bucket", "max")),
					"release_start": _vector2_payload(active_dunk_root_motion.get("release_start_world_position", Vector2.ZERO)),
					"contact_anchor": _vector2_payload(active_dunk_root_motion.get("contact_anchor_world_position", Vector2.ZERO)),
					"landing_anchor": _vector2_payload(active_dunk_root_motion.get("landing_anchor_world_position", Vector2.ZERO)),
				}
			)
	if root_motion_completed:
		_clear_active_dunk_root_motion()


func _resolve_dunk_root_motion_phase(frame_number: int, motion_snapshot: Dictionary) -> String:
	var approach_start_frame: int = int(motion_snapshot.get("approach_start_frame", 1))
	var run_end_frame: int = int(motion_snapshot.get("run_end_frame", 0))
	var jump_end_frame: int = int(motion_snapshot.get("jump_end_frame", run_end_frame))
	var contact_end_frame: int = int(motion_snapshot.get("contact_end_frame", jump_end_frame))
	if frame_number < approach_start_frame:
		return "run"
	if int(motion_snapshot.get("visible_run_frame_count", 0)) > 0 and frame_number <= run_end_frame:
		return "run"
	if frame_number <= jump_end_frame:
		return "jump"
	if frame_number <= contact_end_frame:
		return "contact"
	return "landing"


func _resolve_dunk_root_motion_world_position(frame_progress: float, motion_snapshot: Dictionary) -> Vector2:
	var release_start_world_position: Vector2 = motion_snapshot.get("release_start_world_position", Vector2.ZERO)
	var run_end_world_position: Vector2 = motion_snapshot.get("run_end_world_position", release_start_world_position)
	var contact_anchor_world_position: Vector2 = motion_snapshot.get("contact_anchor_world_position", release_start_world_position)
	var landing_anchor_world_position: Vector2 = motion_snapshot.get("landing_anchor_world_position", contact_anchor_world_position)
	var approach_start_frame: int = int(motion_snapshot.get("approach_start_frame", 1))
	var jump_start_frame: int = int(motion_snapshot.get("jump_start_frame", 1))
	var visible_run_frame_count: int = int(motion_snapshot.get("visible_run_frame_count", 0))
	var run_end_frame: int = int(motion_snapshot.get("run_end_frame", 0))
	var contact_start_frame: int = int(motion_snapshot.get("contact_start_frame", run_end_frame + 1))
	var contact_end_frame: int = int(motion_snapshot.get("contact_end_frame", contact_start_frame))
	var total_frames: int = int(motion_snapshot.get("total_frames", contact_end_frame))
	var resolved_progress: float = clampf(frame_progress, float(approach_start_frame), float(total_frames))
	if visible_run_frame_count > 0 and resolved_progress <= float(run_end_frame):
		var run_alpha: float = clampf(
			(resolved_progress - float(approach_start_frame) + 1.0) / maxf(float(visible_run_frame_count), 1.0),
			0.0,
			1.0
		)
		return release_start_world_position.lerp(run_end_world_position, run_alpha)
	if resolved_progress < float(contact_start_frame):
		var jump_alpha: float = clampf(
			(resolved_progress - float(jump_start_frame) + 1.0) / maxf(float(contact_start_frame - jump_start_frame + 1), 1.0),
			0.0,
			1.0
		)
		return run_end_world_position.lerp(contact_anchor_world_position, jump_alpha)
	if resolved_progress <= float(contact_end_frame):
		return contact_anchor_world_position
	var landing_start_frame: int = contact_end_frame + 1
	var landing_alpha: float = clampf(
		(resolved_progress - float(landing_start_frame)) / maxf(float(total_frames - landing_start_frame), 1.0),
		0.0,
		1.0
	)
	landing_alpha = pow(landing_alpha, _get_dunk_landing_ease_power())
	return contact_anchor_world_position.lerp(landing_anchor_world_position, landing_alpha)


func _resolve_shot_release_visual(player: PlayerController, motion_vector_override: Vector2 = Vector2.INF, defender_distance_override: float = -1.0) -> Dictionary:
	var decision: Dictionary = _build_shot_release_visual_decision(player, motion_vector_override, defender_distance_override, "shot_layout")
	return {
		"family": str(decision.get("family", "jumper_release")),
		"variant_index": int(decision.get("variant_index", 0)),
	}


func _build_close_finish_gate_state(
	player: PlayerController,
	motion_vector_override: Vector2 = Vector2.INF,
	control_intent: String = "shot_layout"
) -> Dictionary:
	if player == null:
		return {
			"distance_to_hoop": INF,
			"lateral_offset": INF,
			"speed": 0.0,
			"toward_hoop_dot": -1.0,
			"dunk_rating": 0,
			"close_finish_eligible": false,
			"dunk_eligible": false,
			"force_no_defenders_dunk": false,
			"control_intent": control_intent,
		}
	var motion_vector: Vector2 = motion_vector_override
	if motion_vector == Vector2.INF:
		motion_vector = _resolve_player_motion_vector(player)
	var speed: float = motion_vector.length()
	var finish_center_world: Vector2 = get_finish_logic_center_world()
	var to_hoop: Vector2 = finish_center_world - player.world_position
	var distance_to_hoop: float = to_hoop.length()
	var lateral_offset: float = absf(player.world_position.x - finish_center_world.x)
	var player_data: PlayerData = player.get_player_data() if player != null else null
	var dunk_rating: int = player_data.dunk if player_data != null else 0
	var force_no_defenders_dunk: bool = control_intent == "dunk" and not _has_active_defenders() and distance_to_hoop <= player_animation_config.close_finish_radius
	var toward_hoop_dot: float = -1.0
	if motion_vector.length_squared() > 0.001 and to_hoop.length_squared() > 0.001:
		toward_hoop_dot = motion_vector.normalized().dot(to_hoop.normalized())
	var toward_hoop: bool = speed >= player_animation_config.finish_momentum_speed_threshold and toward_hoop_dot >= player_animation_config.toward_hoop_dot_threshold
	var close_finish_eligible: bool = force_no_defenders_dunk or (toward_hoop and distance_to_hoop <= player_animation_config.close_finish_radius)
	var dunk_eligible: bool = force_no_defenders_dunk or (close_finish_eligible \
		and distance_to_hoop <= player_animation_config.dunk_finish_radius \
		and speed >= player_animation_config.dunk_momentum_speed_threshold \
		and dunk_rating >= player_animation_config.dunk_rating_min)
	return {
		"distance_to_hoop": distance_to_hoop,
		"lateral_offset": lateral_offset,
		"speed": speed,
		"toward_hoop_dot": toward_hoop_dot,
		"dunk_rating": dunk_rating,
		"close_finish_eligible": close_finish_eligible,
		"dunk_eligible": dunk_eligible,
		"force_no_defenders_dunk": force_no_defenders_dunk,
		"control_intent": control_intent,
	}


func _build_shot_release_visual_decision(
	player: PlayerController,
	motion_vector_override: Vector2 = Vector2.INF,
	defender_distance_override: float = -1.0,
	control_intent: String = "shot_layout"
) -> Dictionary:
	if player == null:
		return {
			"allowed": false,
			"distance_to_hoop": INF,
			"lateral_offset": INF,
			"speed": 0.0,
			"toward_hoop_dot": -1.0,
			"dunk_rating": 0,
			"close_finish_eligible": false,
			"dunk_eligible": false,
			"force_no_defenders_dunk": false,
			"control_intent": control_intent,
			"family": "jumper_release",
			"variant_index": 1,
		}
	var finish_gate_state: Dictionary = _build_close_finish_gate_state(player, motion_vector_override, control_intent)
	var speed: float = float(finish_gate_state.get("speed", 0.0))
	var defender_distance: float = defender_distance_override
	if defender_distance < 0.0:
		defender_distance = _get_primary_defender_distance(player)
	var distance_to_hoop: float = float(finish_gate_state.get("distance_to_hoop", INF))
	var lateral_offset: float = float(finish_gate_state.get("lateral_offset", INF))
	var toward_hoop_dot: float = float(finish_gate_state.get("toward_hoop_dot", -1.0))
	var dunk_rating: int = int(finish_gate_state.get("dunk_rating", 0))
	var close_finish_eligible: bool = bool(finish_gate_state.get("close_finish_eligible", false))
	var dunk_eligible: bool = bool(finish_gate_state.get("dunk_eligible", false))
	var force_no_defenders_dunk: bool = bool(finish_gate_state.get("force_no_defenders_dunk", false))
	var decision: Dictionary = {
		"allowed": true,
		"distance_to_hoop": distance_to_hoop,
		"lateral_offset": lateral_offset,
		"speed": speed,
		"toward_hoop_dot": toward_hoop_dot,
		"dunk_rating": dunk_rating,
		"close_finish_eligible": close_finish_eligible,
		"dunk_eligible": dunk_eligible,
		"force_no_defenders_dunk": force_no_defenders_dunk,
		"control_intent": control_intent,
		"family": "jumper_release",
		"variant_index": 0,
	}
	if control_intent == "dunk":
		if not close_finish_eligible:
			decision["allowed"] = false
			decision["ignore_reason"] = "dunk_not_available"
			return decision
		if dunk_eligible:
			if lateral_offset >= player_animation_config.side_finish_lateral_threshold:
				decision["family"] = "close_finish_side_dunk"
				decision["variant_index"] = 0
				return decision
			decision["family"] = "close_finish_dunk"
			decision["variant_index"] = visual_rng.randi_range(0, 1) if visual_rng != null else 0
			return decision
		decision["family"] = "close_finish_layup"
		decision["variant_index"] = 1 if lateral_offset >= player_animation_config.side_finish_lateral_threshold else 0
		return decision
	if not close_finish_eligible and speed < player_animation_config.finish_momentum_speed_threshold and defender_distance >= player_animation_config.set_shot_space_radius:
		decision["family"] = "set_shot_release"
		decision["variant_index"] = 0
		return decision
	if close_finish_eligible:
		decision["family"] = "close_finish_layup"
		decision["variant_index"] = 1 if lateral_offset >= player_animation_config.side_finish_lateral_threshold else 0
		return decision
	decision["family"] = "jumper_release"
	decision["variant_index"] = 0 if speed > player_animation_config.stationary_speed_threshold else 1
	return decision


func _resolve_shot_release_action_vector(player: PlayerController, motion_vector_override: Vector2 = Vector2.INF) -> Vector2:
	var motion_vector: Vector2 = motion_vector_override
	if motion_vector == Vector2.INF:
		motion_vector = _resolve_player_motion_vector(player)
	if motion_vector.length_squared() > 0.001:
		return motion_vector
	return get_finish_logic_center_world() - player.world_position


func _get_primary_defender_distance(player: PlayerController) -> float:
	var defender: PlayerController = defense_controller.get_assigned_defender(player)
	if defender == null:
		return INF
	return defender.world_position.distance_to(player.world_position)


func _is_player_pressured(player: PlayerController) -> bool:
	var defender: PlayerController = defense_controller.get_assigned_defender(player)
	return defender != null and defender.world_position.distance_to(player.world_position) <= defense_config.pressure_radius


func _get_defender_guard_target(defender: PlayerController) -> Vector2:
	var assignment: PlayerController = defense_controller.assignments.get(defender, null) as PlayerController
	if assignment == null:
		return defender.world_position
	var to_hoop: Vector2 = court_config.hoop_position - assignment.world_position
	if to_hoop.length_squared() <= 0.001:
		return assignment.world_position
	return assignment.world_position + to_hoop.normalized() * defense_config.guard_distance


func _get_defender_assignment_vector(defender: PlayerController) -> Vector2:
	var assignment: PlayerController = defense_controller.assignments.get(defender, null) as PlayerController
	if assignment == null:
		return Vector2.ZERO
	return assignment.world_position - defender.world_position


func _get_variant_count_for_family(family: String) -> int:
	var rows: Array = PlayerVisual.FAMILY_ROWS.get(family, [1])
	return rows.size()


func _has_active_shot_sequence_for_player(player: PlayerController) -> bool:
	return player != null and not active_shot_sequence.is_empty() and active_shot_sequence.get("player", null) == player


func _get_active_shot_timing_profile() -> Dictionary:
	if active_shot_sequence.is_empty():
		return {}
	return Dictionary(active_shot_sequence.get("timing_profile", {})).duplicate(true)


func _begin_active_shot_sequence(shooter: PlayerController, control_intent: String = "shot_layout") -> bool:
	_clear_pending_shot_release()
	_clear_active_shot_sequence()
	if shooter == null:
		return false
	var motion_vector: Vector2 = _resolve_player_motion_vector(shooter)
	var defender_distance: float = _get_primary_defender_distance(shooter)
	var shot_visual_decision: Dictionary = _build_shot_release_visual_decision(shooter, motion_vector, defender_distance, control_intent)
	if not bool(shot_visual_decision.get("allowed", true)):
		return false
	var shot_family: String = str(shot_visual_decision.get("family", "jumper_release"))
	var variant_index: int = int(shot_visual_decision.get("variant_index", 0))
	var action_vector: Vector2 = _resolve_shot_release_action_vector(shooter, motion_vector)
	var mirror_west: bool = _resolve_family_mirror_west(shot_family, action_vector, false)
	var timing_profile: Dictionary = PlayerVisual.build_timing_profile_for_family_variant(shot_family, variant_index)
	var selected_row: int = int(timing_profile.get("row_index", _get_row_index_for_family_variant(shot_family, variant_index)))
	var approach_distance_to_hoop: float = float(shot_visual_decision.get("distance_to_hoop", INF))
	var approach_start_frame: int = 1
	var approach_bucket: String = "max"
	if _is_dunk_family(shot_family):
		approach_bucket = _resolve_dunk_approach_bucket(approach_distance_to_hoop)
		approach_start_frame = _resolve_dunk_approach_start_frame(selected_row, approach_distance_to_hoop)
		shot_visual_decision["approach_start_frame"] = approach_start_frame
		shot_visual_decision["approach_distance_to_hoop"] = approach_distance_to_hoop
		shot_visual_decision["approach_bucket"] = approach_bucket
	active_shot_sequence = {
		"player": shooter,
		"control_intent": control_intent,
		"family": shot_family,
		"variant_index": variant_index,
		"mirror_west": mirror_west,
		"timing_profile": timing_profile,
		"approach_start_frame": approach_start_frame,
		"approach_distance_to_hoop": approach_distance_to_hoop,
		"approach_bucket": approach_bucket,
		"committed": false,
		"launched": false,
		"timing_result": "",
		"shot_timing_mode": SHOT_TIMING_MODE_ANIMATION_GATED,
		"release_visual_deferred": false,
		"release_visual_started": true,
		"finish_decision": shot_visual_decision.duplicate(true),
	}
	shot_visual_locks[shooter] = {
		"family": shot_family,
		"variant_index": variant_index,
		"mirror_west": mirror_west,
		"start_frame_override": approach_start_frame,
	}
	log_writer.log_event(
		"shot_finish_selected",
		{
			"player": shooter.get_display_name(),
			"role": shooter.get_position_role(),
			"distance_to_hoop": shot_visual_decision.get("distance_to_hoop", 0.0),
			"lateral_offset": shot_visual_decision.get("lateral_offset", 0.0),
			"speed": shot_visual_decision.get("speed", 0.0),
			"toward_hoop_dot": shot_visual_decision.get("toward_hoop_dot", -1.0),
			"dunk_rating": shot_visual_decision.get("dunk_rating", 0),
			"close_finish_eligible": shot_visual_decision.get("close_finish_eligible", false),
			"dunk_eligible": shot_visual_decision.get("dunk_eligible", false),
			"force_no_defenders_dunk": shot_visual_decision.get("force_no_defenders_dunk", false),
			"control_intent": control_intent,
			"selected_family": shot_family,
			"selected_row": selected_row,
			"approach_start_frame": approach_start_frame,
			"approach_distance_to_hoop": approach_distance_to_hoop,
			"approach_bucket": approach_bucket,
		}
	)
	shot_owner = shooter
	return true


func _get_active_defenders(excluded_defenders: Array = []) -> Array[PlayerController]:
	if defenders_disabled:
		return []
	var active_defenders: Array[PlayerController] = []
	for defender in defense_players:
		if excluded_defenders.has(defender):
			continue
		active_defenders.append(defender)
	return active_defenders


func _has_active_defenders() -> bool:
	return not _get_active_defenders().is_empty()


func _on_game_settings_changed(key: String, value: bool) -> void:
	match key:
		"show_controls":
			_set_controls_visible(value)
		"no_defenders":
			_set_defenders_disabled(value)
		"show_debug":
			if debug_config != null:
				debug_config.debug_overlay_enabled = value
			if debug_overlay != null:
				debug_overlay.visible = value
				debug_overlay.queue_redraw()


func _apply_game_settings() -> void:
	var settings_node: Node = get_node_or_null("/root/GameSettings")
	if settings_node == null:
		return
	_set_controls_visible(bool(settings_node.show_controls))
	_set_defenders_disabled(bool(settings_node.no_defenders))
	if debug_config != null:
		debug_config.debug_overlay_enabled = bool(settings_node.show_debug)
	if debug_overlay != null:
		debug_overlay.visible = bool(settings_node.show_debug)
		debug_overlay.queue_redraw()


func _set_defenders_disabled(enabled: bool) -> void:
	if defenders_disabled == enabled:
		return
	defenders_disabled = enabled
	_refresh_defender_mode(not defenders_disabled)
	_update_default_pass_target()
	log_writer.log_event("defenders_toggled", {"defenders_disabled": defenders_disabled})
	log_writer.log_match("Defenders %s" % ("disabled" if defenders_disabled else "enabled"))


func _refresh_defender_mode(reposition_defenders: bool = false) -> void:
	if defenders_disabled:
		defense_controller.assignments.clear()
		_clear_active_pass_interceptor()
	for defender in defense_players:
		defender.visible = not defenders_disabled
		defender.velocity = Vector2.ZERO
		defender.set_has_ball(false)
	if not defenders_disabled:
		defense_controller.setup_assignments(offense_players, defense_players)
		if reposition_defenders:
			for defender in defense_players:
				defender.world_position = _get_defender_guard_target(defender)
	if debug_overlay != null:
		debug_overlay.queue_redraw()


func _set_controls_visible(enabled: bool) -> void:
	if controls_visible == enabled:
		_sync_match_ui_visibility()
		return
	controls_visible = enabled
	_sync_match_ui_visibility()
	log_writer.log_event("controls_visibility_toggled", {"controls_visible": controls_visible})
	log_writer.log_match("Controls %s" % ("shown" if controls_visible else "hidden"))


func _clear_active_pass_interceptor() -> void:
	if pass_controller == null or pass_controller.active_pass.is_empty():
		return
	var target_point: Vector2 = pass_controller.active_pass.get("end", Vector2.ZERO)
	pass_controller.active_pass["eligible_interceptor"] = null
	pass_controller.active_pass["active_interceptor"] = null
	pass_controller.active_pass["eligible_chase_point"] = target_point
	pass_controller.active_pass["chase_point"] = target_point
	pass_controller.active_pass["interceptor_claim_radius"] = 0.0
	pass_controller.active_pass["commit_chance"] = 0.0
	pass_controller.active_pass["commit_succeeded"] = false
	pass_controller.active_pass["force_steal"] = false


func _clear_active_shot_sequence(preserve_visual_lock: bool = false, clear_dunk_root_motion: bool = true) -> void:
	var shooter: PlayerController = active_shot_sequence.get("player", null) as PlayerController
	active_shot_sequence.clear()
	if clear_dunk_root_motion:
		_clear_active_dunk_root_motion(true, shooter)
	shot_controller.cancel_aim()
	if court_view != null:
		court_view.clear_shot_meter()
	if not preserve_visual_lock and shooter != null:
		shot_visual_locks.erase(shooter)


func _clear_active_dunk_root_motion(reset_velocity: bool = true, player_override: PlayerController = null) -> void:
	var shooter: PlayerController = player_override
	if shooter == null:
		shooter = active_dunk_root_motion.get("player", null) as PlayerController
	active_dunk_root_motion.clear()
	if reset_velocity and shooter != null:
		shooter.velocity = Vector2.ZERO


func _sync_shot_meter_display() -> void:
	if court_view == null:
		return
	var meter_snapshot: Dictionary = _get_current_shot_meter_snapshot()
	if meter_snapshot.is_empty():
		court_view.clear_shot_meter()
	else:
		court_view.set_shot_meter(meter_snapshot)


func _maybe_finish_active_shot_sequence() -> void:
	if active_shot_sequence.is_empty():
		return
	var shooter: PlayerController = active_shot_sequence.get("player", null) as PlayerController
	if shooter == null:
		_clear_active_shot_sequence()
		return
	if shooter.is_current_animation_complete() and shot_controller.get_meter_progress() >= 0.999:
		_clear_active_shot_sequence(true, false)


func _get_remaining_shot_pose_duration() -> float:
	var full_duration: float = maxf(shot_controller.get_full_animation_duration_seconds(), 0.0)
	if _active_shot_uses_direct_shoot_button_timing():
		return maxf(full_duration + 0.02, 0.08)
	var elapsed: float = 0.0
	if not active_shot_sequence.is_empty():
		var shooter: PlayerController = active_shot_sequence.get("player", null) as PlayerController
		if shooter != null:
			elapsed = shooter.get_current_animation_elapsed_time()
	return maxf(full_duration - elapsed + 0.02, 0.08)


func _queue_auto_late_miss_release(shooter: PlayerController) -> void:
	if shooter == null or not _has_active_shot_sequence_for_player(shooter):
		return
	var action: Dictionary = shot_controller.build_action_for_quality(
		shooter.world_position,
		shooter.get_player_data(),
		"red",
		rng,
		"late_miss",
		true,
		str(active_shot_sequence.get("family", "")),
		bool(active_shot_sequence.get("mirror_west", false))
	)
	action["late_miss_forced"] = true
	log_writer.log_match("Shot timing expired late")
	log_writer.log_event(
		"shot_timing_timeout",
		{
			"player": shooter.get_display_name(),
			"meter_progress": shot_controller.get_meter_progress(),
		}
	)
	_queue_shot_release(action, null)


func _queue_shot_release(action: Dictionary, blocker: PlayerController = null) -> void:
	if current_ballhandler == null:
		return
	var shooter: PlayerController = current_ballhandler
	if active_shot_sequence.is_empty() or active_shot_sequence.get("player", null) != shooter:
		_begin_active_shot_sequence(shooter)
		shot_controller.begin_aim(shooter.world_position, _get_active_shot_timing_profile(), rng)
	_ensure_active_shot_release_visual_lock(shooter)
	var shot_pose_duration: float = _get_remaining_shot_pose_duration()
	shot_owner = shooter
	context.shot_value_pending = int(action.get("shot_value", 0))
	shot_had_rim_contact = false
	shooter.trigger_shot_pose(shot_pose_duration)
	shooter.velocity = Vector2.ZERO
	current_move_direction = Vector2.ZERO
	current_move_magnitude = 0.0
	if not active_shot_sequence.is_empty():
		active_shot_sequence["committed"] = true
		active_shot_sequence["timing_result"] = str(action.get("timing_result", action.get("quality", "red")))
	var shot_family: String = str(active_shot_sequence.get("family", ""))
	var use_dunk_contact_hold: bool = blocker == null and _is_dunk_family(shot_family)
	if use_dunk_contact_hold:
		_begin_active_dunk_root_motion(shooter)
	else:
		_clear_active_dunk_root_motion()
	pending_shot_release = {
		"player": shooter,
		"action": action,
		"blocked": action.get("outcome", "") == "miss" and blocker != null,
		"blocker": blocker,
		"use_dunk_contact_hold": use_dunk_contact_hold,
		"dunk_hold_started_logged": false,
		"dunk_hold_finished_logged": false,
	}
	_clear_score_followthrough(false)
	_set_ball_visual_hidden(shooter)
	_change_state(GameState.State.SHOT_RELEASE)


func _get_release_pose_duration(family: String, variant_index: int) -> float:
	var row_index: int = _get_row_index_for_family_variant(family, variant_index)
	var frame_count: int = PlayerVisual.ROW_FRAME_COUNTS[row_index - 1] if row_index >= 1 and row_index <= PlayerVisual.ROW_FRAME_COUNTS.size() else 1
	var fps: float = float(PlayerVisual.FAMILY_FPS.get(family, 15.0))
	return maxf(float(frame_count) / maxf(fps, 0.001) + 0.06, 0.3)


func _get_row_index_for_family_variant(family: String, variant_index: int) -> int:
	var rows: Array = PlayerVisual.FAMILY_ROWS.get(family, [1])
	var clamped_variant: int = clampi(variant_index, 0, maxi(rows.size() - 1, 0))
	return int(rows[clamped_variant])


func _maybe_commit_pending_shot_release() -> void:
	var shooter: PlayerController = active_shot_sequence.get("player", null) as PlayerController
	if shooter == null:
		if not pending_shot_release.is_empty():
			_clear_pending_shot_release()
		return
	if context.current_state == GameState.State.SHOT_AIM and pending_shot_release.is_empty():
		if _active_shot_uses_direct_shoot_button_timing():
			if shot_controller.get_meter_progress() >= 0.999:
				_queue_auto_late_miss_release(shooter)
		elif shooter.is_ball_release_ready():
			_queue_auto_late_miss_release(shooter)
	if context.current_state != GameState.State.SHOT_RELEASE or pending_shot_release.is_empty():
		return
	shooter = pending_shot_release.get("player", null) as PlayerController
	if shooter == null:
		_clear_pending_shot_release()
		return
	var use_dunk_contact_hold: bool = bool(pending_shot_release.get("use_dunk_contact_hold", false))
	if use_dunk_contact_hold and shooter.is_dunk_contact_hold_active() and not bool(pending_shot_release.get("dunk_hold_started_logged", false)):
		pending_shot_release["dunk_hold_started_logged"] = true
		var snap_snapshot: Dictionary = _build_dunk_contact_snap_snapshot(shooter)
		shooter.world_position = snap_snapshot.get("world_position", shooter.world_position)
		shooter.velocity = Vector2.ZERO
		if court_projection != null:
			var snap_screen: Vector2 = court_projection.player_tracking_anchor_base_screen(shooter.world_position)
			court_projection.update_camera_target(snap_screen, 0.0, true)
		log_writer.log_match("Dunk contact hold started")
		log_writer.log_event(
			"dunk_contact_hold_start",
			{
				"player": shooter.get_display_name(),
				"row": int(snap_snapshot.get("row_index", shooter.get_debug_row_index())),
				"contact_frame": shooter.get_debug_dunk_contact_frame(),
				"hold_remaining": shooter.get_debug_dunk_contact_hold_remaining(),
				"release_mode": pending_shot_release.get("action", {}).get("release_mode", ""),
				"contact_anchor_offset": _vector2_payload(snap_snapshot.get("anchor_offset", Vector2.ZERO)),
				"snapped_to": {"x": shooter.world_position.x, "y": shooter.world_position.y},
				"snapped_ground_screen": _vector2_payload(snap_snapshot.get("ground_screen", Vector2.ZERO)),
			}
		)
	if not shooter.is_world_ball_release_ready():
		return
	if use_dunk_contact_hold and not bool(pending_shot_release.get("dunk_hold_finished_logged", false)):
		pending_shot_release["dunk_hold_finished_logged"] = true
		log_writer.log_match("Dunk contact hold finished")
		log_writer.log_event(
			"dunk_contact_hold_end",
			{
				"player": shooter.get_display_name(),
				"row": shooter.get_debug_row_index(),
				"contact_frame": shooter.get_debug_dunk_contact_frame(),
				"release_mode": pending_shot_release.get("action", {}).get("release_mode", ""),
			}
		)
	_commit_pending_shot_release(shooter)


func _commit_pending_shot_release(shooter: PlayerController) -> void:
	var action: Dictionary = pending_shot_release.get("action", {})
	var blocker: PlayerController = pending_shot_release.get("blocker", null) as PlayerController
	var is_blocked: bool = bool(pending_shot_release.get("blocked", false))
	shooter.set_has_ball(false)
	if not active_shot_sequence.is_empty():
		active_shot_sequence["launched"] = true
	_clear_pending_shot_release()
	if is_blocked and blocker != null:
		blocker.trigger_jump_pose(0.22)
		log_writer.log_match("Shot blocked on release")
		_show_feedback("BLOCKED!", Color(1.0, 0.55, 0.34))
		_begin_rebound(shooter.world_position + Vector2(0.0, -36.0))
		_set_ball_visual_hidden(null)
		return
	_set_ball_visual_world()
	ball_simulator.launch_shot_profile(_prepare_guided_make_profile_for_launch(action))
	_change_state(GameState.State.SHOT_IN_FLIGHT)
	log_writer.log_event(
		"shot_launch",
		{
			"profile_kind": action.get("profile_kind", "free_flight"),
			"release_mode": action.get("release_mode", ""),
			"quality": action.get("quality", "red"),
			"timing_result": action.get("timing_result", action.get("quality", "red")),
			"outcome": action.get("outcome", "miss"),
			"flight_time": action.get("flight_time", 0.0),
			"apex_z": action.get("apex_z", 0.0),
			"launch_z": action.get("launch_z", 0.0),
			"target_xy": {
				"x": action.get("target_xy", Vector2.ZERO).x,
				"y": action.get("target_xy", Vector2.ZERO).y,
			},
		}
	)
	log_writer.log_match(
		"Shot released %s %s for %d mode=%s apex=%0.1f flight=%0.2f" % [
			str(action.get("timing_result", action.get("quality", "red"))),
			str(action.get("outcome", "miss")),
			context.shot_value_pending,
			str(action.get("release_mode", "")),
			float(action.get("apex_z", 0.0)),
			float(action.get("flight_time", 0.0)),
		]
	)


func _clear_pending_shot_release() -> void:
	pending_shot_release.clear()


func _restore_ball_visual_from_state(has_explicit_ball_setup: bool) -> void:
	if has_explicit_ball_setup:
		_set_ball_visual_world()
		return
	if context.current_state == GameState.State.STEAL_RESOLVE and current_steal_holder != null:
		_set_ball_visual_hidden(current_steal_holder)
		return
	if current_ballhandler != null and (
		context.current_state == GameState.State.LIVE_OFFENSE
		or context.current_state == GameState.State.SHOT_AIM
		or context.current_state == GameState.State.SHOT_RELEASE
		or context.current_state == GameState.State.MATCH_SETUP
		or context.current_state == GameState.State.PAUSED
	):
		_set_ball_visual_hidden(current_ballhandler)
		return
	_set_ball_visual_world()


func _begin_steal_resolve(stealer: PlayerController) -> void:
	_clear_steal_resolve()
	_clear_pending_shot_release()
	_clear_active_shot_sequence()
	current_steal_holder = stealer
	steal_resolve_timer = pass_config.steal_resolve_hold_duration
	for offense in offense_players:
		offense.set_has_ball(false)
	for defender in defense_players:
		defender.set_has_ball(defender == stealer)
	stealer.trigger_catch_pose(0.28)
	stealer.velocity = Vector2.ZERO
	_change_state(GameState.State.STEAL_RESOLVE)
	_show_feedback("STEAL!", Color(1.0, 0.45, 0.35))
	ball_simulator.reset_to_possession(stealer.world_position)
	_set_ball_visual_hidden(stealer)
	_sync_ball_to_player(stealer)


func _clear_steal_resolve() -> void:
	steal_resolve_timer = 0.0
	if current_steal_holder != null:
		current_steal_holder.set_has_ball(false)
	current_steal_holder = null
	if ball_visual_mode == BallVisualMode.HIDDEN_WHILE_OWNED and ball_visual_owner != current_ballhandler:
		ball_visual_owner = null


func _vector2_payload(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _optional_vector2_payload(value: Vector2) -> Variant:
	if is_inf(value.x) or is_inf(value.y):
		return null
	return _vector2_payload(value)


func _trace_float(value: float) -> float:
	return snappedf(value, 0.001)


func _get_score_followthrough_event_log_path() -> String:
	if log_writer == null:
		return ""
	return ProjectSettings.globalize_path("%s/%s_event.jsonl" % [log_writer.log_dir, log_writer.session_prefix])


func _announce_score_followthrough_trace_destination() -> void:
	var trace_path: String = _get_score_followthrough_event_log_path()
	if trace_path == "":
		return
	var message: String = "Score followthrough trace -> %s" % trace_path
	print("[score_followthrough_trace] %s" % message)
	if log_writer != null:
		log_writer.log_match(message)


func _trace_score_followthrough(reason: String, render_context: Dictionary = {}, force: bool = false) -> void:
	if log_writer == null or not ball_simulator.is_guided_make_profile():
		return
	if score_followthrough_state.is_empty() and not ball_simulator.already_scored:
		return
	var process_frame: int = Engine.get_process_frames()
	var last_process_frame: int = int(score_followthrough_state.get("trace_last_process_frame", -1))
	if not force and last_process_frame == process_frame:
		return
	score_followthrough_state["trace_last_process_frame"] = process_frame
	var trace_index: int = int(score_followthrough_state.get("trace_index", 0))
	score_followthrough_state["trace_index"] = trace_index + 1
	var resolved_render_context: Dictionary = render_context
	if resolved_render_context.is_empty():
		resolved_render_context = _resolve_ball_render_context(ball_simulator.position_xy, ball_simulator.z, ball_simulator.vz)
	var screen_offset: Vector2 = _get_render_context_screen_offset(resolved_render_context)
	var world_anchor: Vector2 = _get_ball_screen_anchor_for_world(ball_simulator.position_xy, ball_simulator.z)
	var rendered_anchor: Vector2 = world_anchor + screen_offset
	var live_ball_anchor: Vector2 = get_ball_screen_anchor()
	if is_inf(live_ball_anchor.x) or is_inf(live_ball_anchor.y):
		live_ball_anchor = rendered_anchor
	var release_screen_y: float = 0.0
	if hoop_node != null and hoop_node.has_method("get_front_net_exit_screen_y"):
		release_screen_y = hoop_node.get_front_net_exit_screen_y()
	var payload: Dictionary = {
		"reason": reason,
		"trace_index": trace_index,
		"process_frame": process_frame,
		"state": GameState.state_name(context.current_state),
		"session_prefix": log_writer.session_prefix,
		"sim_phase": ball_simulator.get_flight_phase(),
		"sim_render_phase": ball_simulator.get_render_phase_name(),
		"render_context_phase": str(resolved_render_context.get("render_phase", "")),
		"current_ball_render_phase": current_ball_render_phase,
		"ball_visible": ball_node != null and ball_node.is_ball_visible(),
		"ball_z_index": ball_node.z_index if ball_node != null else 0,
		"position_xy": _vector2_payload(ball_simulator.position_xy),
		"z": _trace_float(ball_simulator.z),
		"vz": _trace_float(ball_simulator.vz),
		"made_shot_animation_timer": _trace_float(made_shot_animation_timer),
		"world_anchor": _optional_vector2_payload(world_anchor),
		"rendered_anchor": _optional_vector2_payload(rendered_anchor),
		"live_ball_anchor": _optional_vector2_payload(live_ball_anchor),
		"screen_offset": _optional_vector2_payload(screen_offset),
		"screen_drop_px": _trace_float(float(resolved_render_context.get("screen_drop_px", 0.0))),
		"live_front_net_exit_screen_y": _trace_float(release_screen_y),
		"anchor_minus_exit_y": _trace_float(live_ball_anchor.y - release_screen_y),
		"handoff_active": bool(score_followthrough_state.get("handoff_active", false)),
		"handoff_phase": str(score_followthrough_state.get("handoff_phase", "")),
		"handoff_offset": _optional_vector2_payload(score_followthrough_state.get("handoff_screen_offset", Vector2.ZERO)),
		"handoff_cleared": bool(score_followthrough_state.get("handoff_cleared", false)),
		"handoff_cleared_net": bool(score_followthrough_state.get("handoff_cleared_net", false)),
		"handoff_release_screen_y": _trace_float(float(score_followthrough_state.get("handoff_release_screen_y", release_screen_y))),
		"net_swish_active": get_net_swish_active(),
		"uses_explicit_hoop_phase": bool(resolved_render_context.get("uses_explicit_hoop_phase", false)),
		"is_followthrough_handoff": bool(resolved_render_context.get("is_followthrough_handoff", false)),
	}
	log_writer.log_event("score_followthrough_trace", payload)
	print("[score_followthrough_trace] %s" % JSON.stringify(payload))


func _player_name_or_empty(player: Variant) -> String:
	var resolved_player: PlayerController = player as PlayerController
	if resolved_player == null:
		return ""
	return resolved_player.get_display_name()
