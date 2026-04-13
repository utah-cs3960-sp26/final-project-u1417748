class_name TestRunner
extends Node

const COURT_PROJECTION_SCRIPT = preload("res://scripts/game/CourtProjection.gd")

var pure_logic_results: Array[Dictionary] = []
var scenario_results: Array[Dictionary] = []
var balance_results: Array[Dictionary] = []
var total_failed: int = 0
var logger: LogWriter = LogWriter.new("test_run")


func _ready() -> void:
	await get_tree().process_frame
	await run_all()
	_write_summary()
	get_tree().quit(1 if total_failed > 0 else 0)


func run_all() -> Array:
	pure_logic_results.clear()
	scenario_results.clear()
	balance_results.clear()
	total_failed = 0
	logger.set_prefix("test_run_%d" % Time.get_ticks_msec())
	logger.clear_runtime_logs()
	logger.log_test("Pocket Hoops tests starting")
	await _run_pure_logic()
	await _run_scenarios()
	_run_balance()
	return pure_logic_results


func _write_summary() -> void:
	var summary: PackedStringArray = PackedStringArray()
	summary.append("Pocket Hoops test summary")
	summary.append("Pure logic: %d" % pure_logic_results.size())
	summary.append("Scenarios: %d" % scenario_results.size())
	summary.append("Balance: %d" % balance_results.size())
	summary.append("Failures: %d" % total_failed)
	for result in pure_logic_results + scenario_results + balance_results:
		var status: String = "PASS" if result["passed"] else "FAIL"
		summary.append("[%s] %s %s" % [status, result["name"] if result.has("name") else result.get("display_name", result.get("batch_id", "unknown")), result.get("detail", "")])
	var summary_text: String = "\n".join(summary)
	logger.log_test(summary_text)
	print(summary_text)


func _run_pure_logic() -> void:
	var shot_controller: ShotController = ShotController.new()
	shot_controller.shot_config = ShotTimingConfig.new()
	shot_controller.ball_config = BallPhysicsConfig.new()
	shot_controller.court_config = CourtConfig.new()
	var projection_config: ProjectionConfig = ProjectionConfig.new()
	var projection = COURT_PROJECTION_SCRIPT.new(projection_config, shot_controller.court_config)
	shot_controller.projection = projection
	var rng: GameRng = GameRng.new()
	rng.reseed(42)
	var shooter: PlayerData = PlayerData.new()
	shooter.shooting = 82
	shooter.release_consistency = 80

	var green_window: Vector2 = shot_controller.get_green_window(false, shooter.release_consistency)
	var contested_green_window: Vector2 = shot_controller.get_green_window(true, shooter.release_consistency)
	var low_consistency_green_window: Vector2 = shot_controller.get_green_window(false, 12)
	var green_center: float = (green_window.x + green_window.y) * 0.5
	_assert_true(absf((contested_green_window.y - contested_green_window.x) - (green_window.y - green_window.x)) < 0.0001, "contest does not change meter green", "")
	_assert_true(absf((low_consistency_green_window.y - low_consistency_green_window.x) - (green_window.y - green_window.x)) < 0.0001, "ratings do not change meter green", "")
	_assert_true(shot_controller.classify_meter_progress(green_center, false, shooter.release_consistency) == "green", "meter green midpoint", "")
	_assert_true(shot_controller.classify_meter_progress(green_center, true, 10) == "green", "meter green midpoint holds under contest", "")
	_assert_true(shot_controller.classify_meter_progress(0.08, false, shooter.release_consistency) == "red", "meter red edge", "")

	shot_controller.begin_aim(Vector2.ZERO)
	shot_controller.update_aim(shot_controller.get_decision_duration_seconds() * green_center, Vector2.ZERO)
	var meter_snapshot: Dictionary = shot_controller.get_meter_snapshot(false, shooter.release_consistency)
	_assert_true(meter_snapshot["visible"] and meter_snapshot["quality"] == "green", "meter snapshot visible and green", "")
	var contested_snapshot: Dictionary = shot_controller.get_meter_snapshot(true, 10)
	_assert_true(absf(float(contested_snapshot["green_start"]) - float(meter_snapshot["green_start"])) < 0.0001 and absf(float(contested_snapshot["green_end"]) - float(meter_snapshot["green_end"])) < 0.0001, "meter snapshot green window stays fixed", "")
	var synced_probe: ShotController = ShotController.new()
	synced_probe.shot_config = shot_controller.shot_config
	synced_probe.ball_config = shot_controller.ball_config
	synced_probe.court_config = shot_controller.court_config
	synced_probe.begin_aim(Vector2.ZERO)
	synced_probe.update_aim(synced_probe.get_decision_duration_seconds() * 0.25, Vector2.ZERO)
	var synced_progress_1: float = synced_probe.get_meter_progress()
	synced_probe.update_aim(synced_probe.get_decision_duration_seconds() * 0.25, Vector2.ZERO)
	var synced_progress_2: float = synced_probe.get_meter_progress()
	synced_probe.update_aim(synced_probe.get_decision_duration_seconds() * 1.0, Vector2.ZERO)
	var synced_progress_3: float = synced_probe.get_meter_progress()
	_assert_true(synced_progress_1 > 0.0 and synced_progress_2 > synced_progress_1, "meter advances forward during one-way windup", "%0.3f %0.3f" % [synced_progress_1, synced_progress_2])
	_assert_true(synced_progress_3 >= synced_progress_2 and synced_progress_3 <= 1.0, "meter clamps instead of ping-ponging", "%0.3f" % synced_progress_3)
	var shot_timing_rows: Array[Dictionary] = [
		{"row": 4, "family": "set_shot_release", "release_after": 5},
		{"row": 8, "family": "jumper_release", "release_after": 11},
		{"row": 10, "family": "jumper_release", "release_after": 23},
		{"row": 13, "family": "close_finish_dunk", "release_after": 10},
		{"row": 14, "family": "close_finish_layup", "release_after": 9},
		{"row": 15, "family": "close_finish_dunk", "release_after": 11},
		{"row": 16, "family": "close_finish_side_dunk", "release_after": 11},
		{"row": 17, "family": "close_finish_layup", "release_after": 11},
	]
	for shot_timing_entry in shot_timing_rows:
		var shot_timing_profile: Dictionary = PlayerVisual.build_timing_profile_for_row(int(shot_timing_entry["row"]), str(shot_timing_entry["family"]))
		var shot_release_after: int = int(shot_timing_entry["release_after"])
		var shot_fps: float = float(shot_timing_profile.get("fps", 0.0))
		_assert_true(absf(shot_fps - 15.0) < 0.001, "row %d shot timing uses 15 fps" % int(shot_timing_entry["row"]), str(shot_fps))
		_assert_true(int(shot_timing_profile.get("release_after_frame", -1)) == shot_release_after, "row %d keeps authored release frame" % int(shot_timing_entry["row"]), str(shot_timing_profile.get("release_after_frame", -1)))
		_assert_true(absf(float(shot_timing_profile.get("release_time_seconds", 0.0)) - float(shot_release_after) / 15.0) < 0.001, "row %d release seconds derive from 15 fps" % int(shot_timing_entry["row"]), str(shot_timing_profile.get("release_time_seconds", 0.0)))
		var shot_total_frames: int = int(shot_timing_profile.get("total_frames", 0))
		_assert_true(absf(float(shot_timing_profile.get("full_animation_duration_seconds", 0.0)) - float(shot_total_frames) / 15.0) < 0.001, "row %d full duration derives from 15 fps" % int(shot_timing_entry["row"]), str(shot_timing_profile.get("full_animation_duration_seconds", 0.0)))
	var cadence_visual: PlayerVisual = PlayerVisual.new()
	var cadence_request: PlayerVisualRequest = PlayerVisualRequest.new("set_shot_release", 0, false, true, true)
	cadence_visual.apply_state(cadence_request, 1.0 / 15.0)
	var cadence_frame_before_commit: int = cadence_visual.get_debug_frame_number()
	cadence_visual.apply_state(PlayerVisualRequest.new("set_shot_release", 0, false, true, false), 1.0 / 15.0)
	var cadence_frame_after_commit: int = cadence_visual.get_debug_frame_number()
	_assert_true(cadence_frame_before_commit == 2 and cadence_frame_after_commit == 3, "shot continuation keeps the same 15 fps cadence", "%d %d" % [cadence_frame_before_commit, cadence_frame_after_commit])
	cadence_visual.free()
	var animation_config: PlayerAnimationConfig = PlayerAnimationConfig.new()
	_assert_true(absf(animation_config.dunk_momentum_speed_threshold - 95.0) < 0.001, "dunk momentum threshold metadata", str(animation_config.dunk_momentum_speed_threshold))
	_assert_true(animation_config.dunk_rating_min == 60, "dunk rating minimum metadata", str(animation_config.dunk_rating_min))
	_assert_true(animation_config.dunk_contact_frame_row_13 == 10, "row 13 contact frame metadata", str(animation_config.dunk_contact_frame_row_13))
	_assert_true(animation_config.dunk_contact_frame_row_15 == 11, "row 15 contact frame metadata", str(animation_config.dunk_contact_frame_row_15))
	_assert_true(animation_config.dunk_contact_frame_row_16 == 11, "row 16 contact frame metadata", str(animation_config.dunk_contact_frame_row_16))
	_assert_true(absf(animation_config.dunk_contact_hold_seconds - 0.5) < 0.001, "dunk contact hold duration metadata", str(animation_config.dunk_contact_hold_seconds))
	_assert_true(animation_config.dunk_contact_anchor_offset_row_13.distance_to(Vector2(0.0, 160.0)) < 0.001, "row 13 contact anchor metadata", str(animation_config.dunk_contact_anchor_offset_row_13))
	_assert_true(animation_config.dunk_contact_anchor_offset_row_15.distance_to(Vector2(-8.0, 141.0)) < 0.001, "row 15 contact anchor metadata", str(animation_config.dunk_contact_anchor_offset_row_15))
	_assert_true(animation_config.dunk_contact_anchor_offset_row_16.distance_to(Vector2(-42.0, 160.0)) < 0.001, "row 16 contact anchor metadata", str(animation_config.dunk_contact_anchor_offset_row_16))
	var home_team_data: TeamData = load("res://data/teams/HOM.tres") as TeamData
	var away_team_data: TeamData = load("res://data/teams/AWY.tres") as TeamData
	var expected_dunk_ratings: Dictionary = {
		"hom_pg": 40,
		"hom_lw": 68,
		"hom_rw": 58,
		"hom_lc": 92,
		"hom_rc": 35,
		"awy_pg": 38,
		"awy_lw": 65,
		"awy_rw": 56,
		"awy_lc": 90,
		"awy_rc": 33,
	}
	if home_team_data != null:
		for home_player in home_team_data.players:
			_assert_true(int(expected_dunk_ratings.get(home_player.player_id, -1)) == home_player.dunk, "home dunk rating seeded for %s" % home_player.player_id, str(home_player.dunk))
	if away_team_data != null:
		for away_player in away_team_data.players:
			_assert_true(int(expected_dunk_ratings.get(away_player.player_id, -1)) == away_player.dunk, "away dunk rating seeded for %s" % away_player.player_id, str(away_player.dunk))
	var defense_config: DefenseConfig = DefenseConfig.new()
	_assert_true(absf(defense_config.dunk_block_chance_min_multiplier - 0.55) < 0.001, "dunk block resistance metadata", str(defense_config.dunk_block_chance_min_multiplier))
	var defense_controller: DefenseController = DefenseController.new()
	defense_controller.defense_config = defense_config
	var low_dunk_data: PlayerData = PlayerData.new()
	low_dunk_data.dunk = 0
	var high_dunk_data: PlayerData = PlayerData.new()
	high_dunk_data.dunk = 100
	var block_defender_data: PlayerData = PlayerData.new()
	block_defender_data.block = 90
	var low_dunk_shooter: PlayerController = PlayerController.new()
	low_dunk_shooter.setup(low_dunk_data, true, Color.WHITE)
	low_dunk_shooter.world_position = Vector2(540.0, 520.0)
	var high_dunk_shooter: PlayerController = PlayerController.new()
	high_dunk_shooter.setup(high_dunk_data, true, Color.WHITE)
	high_dunk_shooter.world_position = low_dunk_shooter.world_position
	var block_defender: PlayerController = PlayerController.new()
	block_defender.setup(block_defender_data, false, Color.RED)
	block_defender.world_position = low_dunk_shooter.world_position + Vector2(0.0, 24.0)
	var low_dunk_block_chance: float = defense_controller.get_block_chance(low_dunk_shooter, block_defender, "close_finish_dunk")
	var high_dunk_block_chance: float = defense_controller.get_block_chance(high_dunk_shooter, block_defender, "close_finish_dunk")
	var low_layup_block_chance: float = defense_controller.get_block_chance(low_dunk_shooter, block_defender, "close_finish_layup")
	var high_layup_block_chance: float = defense_controller.get_block_chance(high_dunk_shooter, block_defender, "close_finish_layup")
	_assert_true(high_dunk_block_chance < low_dunk_block_chance, "dunk block chance drops as dunk rating rises", "%0.4f %0.4f" % [low_dunk_block_chance, high_dunk_block_chance])
	_assert_true(absf(low_layup_block_chance - high_layup_block_chance) < 0.0001, "layup block chance ignores dunk rating", "%0.4f %0.4f" % [low_layup_block_chance, high_layup_block_chance])
	low_dunk_shooter.queue_free()
	high_dunk_shooter.queue_free()
	block_defender.queue_free()
	var dunk_contact_visual: PlayerVisual = PlayerVisual.new()
	dunk_contact_visual.set_animation_config(animation_config)
	var dunk_hold_start_request: PlayerVisualRequest = PlayerVisualRequest.new("close_finish_dunk", 0, false, true, true, true)
	var dunk_hold_continue_request: PlayerVisualRequest = PlayerVisualRequest.new("close_finish_dunk", 0, false, true, false, true)
	dunk_contact_visual.apply_state(dunk_hold_start_request, 1.0 / 15.0)
	for _dunk_frame in 8:
		dunk_contact_visual.apply_state(dunk_hold_continue_request, 1.0 / 15.0)
	_assert_true(dunk_contact_visual.get_debug_dunk_contact_frame() == 10, "row 13 current visual exposes contact frame", str(dunk_contact_visual.get_debug_dunk_contact_frame()))
	_assert_true(dunk_contact_visual.get_debug_frame_number() == 10, "row 13 freezes on authored contact frame", str(dunk_contact_visual.get_debug_frame_number()))
	_assert_true(dunk_contact_visual.is_dunk_contact_hold_active(), "row 13 enters dunk contact hold", "")
	_assert_true(absf(dunk_contact_visual.get_debug_dunk_contact_hold_remaining() - animation_config.dunk_contact_hold_seconds) < 0.001, "row 13 contact hold starts at full duration", str(dunk_contact_visual.get_debug_dunk_contact_hold_remaining()))
	dunk_contact_visual.apply_state(dunk_hold_continue_request, animation_config.dunk_contact_hold_seconds * 0.5)
	_assert_true(dunk_contact_visual.is_dunk_contact_hold_active(), "row 13 hold persists mid-hang", str(dunk_contact_visual.get_debug_dunk_contact_hold_remaining()))
	dunk_contact_visual.apply_state(dunk_hold_continue_request, animation_config.dunk_contact_hold_seconds * 0.5)
	_assert_true(dunk_contact_visual.is_world_ball_release_ready(), "row 13 world-ball release waits for hold completion", "")
	dunk_contact_visual.free()

	var projection_screen_rect: Rect2 = Rect2(90.0, 208.0, 900.0, 1600.0)
	var projection_viewport_rect: Rect2 = Rect2(0.0, 0.0, 1080.0, 1920.0)
	projection.apply_screen_layout(projection_screen_rect, projection_screen_rect.size.x / 1080.0, projection_viewport_rect)
	_assert_true(absf(projection.get_camera_zoom() - 2.1) < 0.001, "projection uses retuned 2.1x close camera zoom", str(projection.get_camera_zoom()))
	var far_ground: Vector2 = projection.world_to_base_screen_ground(Vector2(540.0, 320.0))
	var near_ground: Vector2 = projection.world_to_base_screen_ground(Vector2(540.0, 1500.0))
	_assert_true(far_ground.y < near_ground.y, "projection orders up-court depth", "")
	var court_rect: Rect2 = shot_controller.court_config.court_rect
	var top_left: Vector2 = projection.world_to_base_screen_ground(court_rect.position)
	var top_right: Vector2 = projection.world_to_base_screen_ground(Vector2(court_rect.end.x, court_rect.position.y))
	var bottom_left: Vector2 = projection.world_to_base_screen_ground(Vector2(court_rect.position.x, court_rect.end.y))
	var bottom_right: Vector2 = projection.world_to_base_screen_ground(court_rect.end)
	_assert_true(absf(top_left.y - projection_screen_rect.position.y) < 0.001 and absf(top_right.y - projection_screen_rect.position.y) < 0.001, "projection maps court top to layout top", "")
	_assert_true(absf(bottom_left.y - projection_screen_rect.end.y) < 0.001 and absf(bottom_right.y - projection_screen_rect.end.y) < 0.001, "projection maps court bottom to layout bottom", "")
	_assert_true(absf(top_left.x - projection_screen_rect.position.x) < 0.001 and absf(bottom_left.x - projection_screen_rect.position.x) < 0.001, "projection maps left sideline to layout edge", "")
	_assert_true(absf(top_right.x - projection_screen_rect.end.x) < 0.001 and absf(bottom_right.x - projection_screen_rect.end.x) < 0.001, "projection maps right sideline to layout edge", "")
	_assert_true(absf((top_right.x - top_left.x) - (bottom_right.x - bottom_left.x)) < 0.001, "projection keeps court width constant", "")
	var mid_world_y: float = court_rect.position.y + court_rect.size.y * 0.5
	var mid_ground: Vector2 = projection.world_to_base_screen_ground(Vector2(court_rect.get_center().x, mid_world_y))
	var expected_mid_y: float = lerpf(projection_screen_rect.position.y, projection_screen_rect.end.y, 0.5)
	_assert_true(absf(mid_ground.y - expected_mid_y) < 0.001, "projection maps court depth linearly", "")
	var round_trip_world: Vector2 = Vector2(740.0, 1110.0)
	var tracked_player_world: Vector2 = Vector2(540.0, 1320.0)
	projection.update_camera_target(projection.player_tracking_anchor_base_screen(tracked_player_world), 0.0, true)
	var tracked_player_anchor: Vector2 = projection.player_tracking_anchor_screen(tracked_player_world)
	_assert_true(tracked_player_anchor.distance_to(projection_viewport_rect.get_center()) < 0.001, "projection centers tracked player anchor", str(tracked_player_anchor))
	var tracked_ball_world: Vector2 = Vector2(620.0, 980.0)
	var tracked_ball_z: float = 220.0
	var tracked_ball_post_offset: Vector2 = Vector2(0.0, projection.guided_make_terminal_screen_drop(0.4))
	projection.update_camera_target(projection.world_to_base_screen(tracked_ball_world, tracked_ball_z), 0.0, true, tracked_ball_post_offset)
	var tracked_ball_anchor: Vector2 = projection.world_to_screen(tracked_ball_world, tracked_ball_z) + tracked_ball_post_offset
	_assert_true(tracked_ball_anchor.distance_to(projection_viewport_rect.get_center()) < 0.001, "projection centers tracked in-flight ball anchor", str(tracked_ball_anchor))
	var round_trip_screen: Vector2 = projection.world_to_screen_ground(round_trip_world)
	_assert_true(projection.screen_to_world_ground(round_trip_screen).distance_to(round_trip_world) < 0.01, "projection round trips ground coordinates after camera transform", "")
	var lifted: Vector2 = projection.world_to_screen(Vector2(540.0, 1100.0), 180.0)
	var preview_lifted: Vector2 = projection.preview_world_to_screen(Vector2(540.0, 1100.0), 180.0)
	var ground: Vector2 = projection.world_to_screen_ground(Vector2(540.0, 1100.0))
	_assert_true(absf(lifted.x - ground.x) < 0.001 and lifted.y < ground.y, "projection lifts from ground anchor", "")
	_assert_true(ground.y - lifted.y > 60.0, "projection gives cinematic z lift", "")
	_assert_true(preview_lifted.y < lifted.y, "preview lift exceeds live ball lift", "")
	_assert_true(absf(projection.guided_make_terminal_screen_drop(1.0) - projection_config.guided_make_terminal_screen_drop_px * (projection_screen_rect.size.x / 1080.0) * projection.get_camera_zoom()) < 0.001, "projection exposes guided make terminal screen drop", "")
	_assert_true(projection.actor_scale(Vector2(540.0, 1500.0)) > projection.base_actor_scale(Vector2(540.0, 1500.0)) * 2.05, "camera zoom materially enlarges actor presentation", "")
	_assert_true(projection.get_hoop_visual_scale_multiplier() > projection_config.hoop_visual_scale_multiplier * projection.get_base_presentation_scale() * 2.05, "camera zoom materially enlarges hoop presentation", "")
	_assert_true(projection.actor_scale(Vector2(540.0, 1500.0)) > projection.actor_scale(Vector2(540.0, 420.0)), "near actors render larger", "")
	_assert_true(projection.depth_key(Vector2(540.0, 1500.0)) > projection.depth_key(Vector2(540.0, 420.0)), "near actors sort in front", "")
	var near_origin: Vector2 = Vector2(560.0, 760.0)
	var far_origin: Vector2 = Vector2(540.0, 1400.0)
	var near_green_profile: Dictionary = shot_controller.build_launch_profile(near_origin, "green")
	var far_green_profile: Dictionary = shot_controller.build_launch_profile(far_origin, "green")
	var expected_make_entry: Vector2 = shot_controller.get_current_make_entry_target()
	_assert_true(str(near_green_profile.get("profile_kind", "")) == ShotController.PROFILE_KIND_GUIDED_MAKE, "green launch uses guided make profile", "")
	_assert_true(near_green_profile["entry_xy"].distance_to(expected_make_entry) < 0.001, "green launch targets front rim entry", "")
	_assert_true(absf(float(near_green_profile["entry_z"]) - shot_controller.court_config.rim_height) < 0.001, "guided make handoff sits on rim plane", str(near_green_profile["entry_z"]))
	_assert_true(float(near_green_profile["score_gate_z"]) < shot_controller.court_config.rim_height, "guided make score gate starts below rim", str(near_green_profile["score_gate_z"]))
	_assert_true(float(near_green_profile["launch_z"]) > 0.0, "shots launch above floor", "")
	_assert_true(float(near_green_profile["flight_time"]) >= shot_controller.ball_config.made_shot_min_flight_time_near, "near shot meets cinematic airtime", "")
	_assert_true(float(far_green_profile["flight_time"]) >= shot_controller.ball_config.made_shot_min_flight_time_far, "far shot meets cinematic airtime", "")
	_assert_true(float(far_green_profile["apex_z"]) >= shot_controller.ball_config.made_shot_min_apex_far, "far shot meets cinematic apex", "")
	_assert_true(float(far_green_profile["flight_time"]) > float(near_green_profile["flight_time"]), "far shot hangs longer than near shot", "")
	_assert_true(float(far_green_profile["apex_z"]) > float(near_green_profile["apex_z"]), "far shot arcs higher than near shot", "")
	_assert_true(_is_legal_score_sample(near_green_profile["score_gate_xy"], shot_controller.court_config), "green score gate stays inside legal corridor", str(near_green_profile["score_gate_xy"]))
	var dunk_origin: Vector2 = shot_controller.court_config.hoop_position + Vector2(22.0, 118.0)
	var dunk_make_profile: Dictionary = shot_controller.build_launch_profile(dunk_origin, "green", "close_finish_dunk")
	var dunk_miss_profile: Dictionary = shot_controller.build_launch_profile(dunk_origin, "red", "close_finish_dunk")
	_assert_true(str(dunk_make_profile.get("release_mode", "")) == ShotController.RELEASE_MODE_DUNK_MAKE_DROP, "green dunk uses straight-through release mode", str(dunk_make_profile.get("release_mode", "")))
	_assert_true(str(dunk_make_profile.get("profile_kind", "")) == ShotController.PROFILE_KIND_GUIDED_MAKE, "green dunk still uses guided make profile", "")
	_assert_true(str(dunk_make_profile.get("start_phase", "")) == BallSimulator.FLIGHT_PHASE_GUIDED_DESCENT, "green dunk starts directly in guided descent", str(dunk_make_profile.get("start_phase", "")))
	_assert_true(absf(float(dunk_make_profile.get("launch_z", 0.0)) - shot_controller.court_config.rim_height) < 0.001, "green dunk launches from rim height", str(dunk_make_profile.get("launch_z", 0.0)))
	_assert_true(dunk_make_profile.get("launch_position", Vector2.ZERO).distance_to(expected_make_entry) < 0.001, "green dunk launches from the rim entry point", str(dunk_make_profile.get("launch_position", Vector2.ZERO)))
	_assert_true(str(dunk_miss_profile.get("release_mode", "")) == ShotController.RELEASE_MODE_DUNK_MISS_BOUNCE, "red dunk uses rim-bounce miss mode", str(dunk_miss_profile.get("release_mode", "")))
	_assert_true(str(dunk_miss_profile.get("profile_kind", "")) == ShotController.PROFILE_KIND_FREE_FLIGHT, "red dunk miss stays free-flight", "")
	_assert_true(absf(float(dunk_miss_profile.get("launch_z", 0.0)) - shot_controller.court_config.rim_height) < 0.001, "red dunk miss starts from rim height", str(dunk_miss_profile.get("launch_z", 0.0)))
	var dunk_make_sim: BallSimulator = _new_ball_simulator(shot_controller.ball_config)
	dunk_make_sim.launch_shot_profile(dunk_make_profile)
	_assert_true(dunk_make_sim.get_flight_phase() == BallSimulator.FLIGHT_PHASE_GUIDED_DESCENT, "green dunk simulator starts inside guided descent", str(dunk_make_sim.get_flight_phase()))
	var dunk_make_start_z: float = dunk_make_sim.z
	dunk_make_sim.step(1.0 / 60.0)
	_assert_true(dunk_make_sim.z <= dunk_make_start_z + 0.001, "green dunk first motion is downward or level", "%0.2f -> %0.2f" % [dunk_make_start_z, dunk_make_sim.z])
	var dunk_miss_sim: BallSimulator = _new_ball_simulator(shot_controller.ball_config)
	dunk_miss_sim.launch_shot_profile(dunk_miss_profile)
	var dunk_miss_start_z: float = dunk_miss_sim.z
	var dunk_miss_start_distance: float = dunk_miss_sim.position_xy.distance_to(shot_controller.court_config.hoop_position)
	dunk_miss_sim.step(1.0 / 60.0)
	_assert_true(dunk_miss_sim.z > dunk_miss_start_z, "red dunk miss first motion rises above the rim", "%0.2f -> %0.2f" % [dunk_miss_start_z, dunk_miss_sim.z])
	_assert_true(dunk_miss_sim.position_xy.distance_to(shot_controller.court_config.hoop_position) > dunk_miss_start_distance, "red dunk miss moves away from the hoop on first step", "%0.2f -> %0.2f" % [dunk_miss_start_distance, dunk_miss_sim.position_xy.distance_to(shot_controller.court_config.hoop_position)])
	var far_preview_points: Array[Dictionary] = shot_controller.create_preview(_new_ball_simulator(shot_controller.ball_config), far_green_profile)
	_assert_true(_max_preview_z(far_preview_points) >= float(far_green_profile["apex_z"]) - 56.0, "far preview stays close to cinematic apex", "")
	if not far_preview_points.is_empty():
		var preview_probe: BallSimulator = _new_ball_simulator(shot_controller.ball_config)
		preview_probe.launch_shot_profile(far_green_profile)
		for point in far_preview_points:
			preview_probe.step(point["sample_delta"])
		var far_preview_last: Dictionary = far_preview_points[maxi(far_preview_points.size() - 1, 0)]
		var expected_preview_screen: Vector2 = projection.preview_world_to_screen(preview_probe.position_xy, preview_probe.z)
		expected_preview_screen.y += projection.guided_make_terminal_screen_drop(preview_probe.get_terminal_visual_drop_weight())
		_assert_true(expected_preview_screen.distance_to(far_preview_last["screen_position"]) < 0.01, "guided make preview applies terminal drop", "")
	var make_sim: BallSimulator = _new_ball_simulator(shot_controller.ball_config)
	var resolver: HoopResolver = HoopResolver.new(CourtConfig.new(), BallPhysicsConfig.new())
	make_sim.launch_shot_profile(near_green_profile)
	var scored: bool = false
	var score_interaction: Dictionary = {}
	var first_score_interaction: Dictionary = {}
	var saw_guided_descent: bool = false
	var saw_net_exit: bool = false
	var pre_score_board_side: bool = false
	var max_descent_center_offset: float = 0.0
	var score_phase: String = ""
	var handoff_reached: bool = false
	var saw_above_rim_after_handoff: bool = false
	var first_guided_descent_z: float = INF
	var first_guided_descent_vz: float = 0.0
	var first_guided_drop_weight: float = 0.0
	for _frame in 300:
		make_sim.step(1.0 / 60.0)
		match make_sim.get_flight_phase():
			BallSimulator.FLIGHT_PHASE_GUIDED_DESCENT:
				saw_guided_descent = true
				if is_inf(first_guided_descent_z):
					first_guided_descent_z = make_sim.z
					first_guided_descent_vz = make_sim.vz
					first_guided_drop_weight = make_sim.get_terminal_visual_drop_weight()
			BallSimulator.FLIGHT_PHASE_NET_EXIT:
				saw_net_exit = true
		if make_sim.get_flight_phase() != BallSimulator.FLIGHT_PHASE_FREE_FLIGHT and make_sim.get_flight_phase() != BallSimulator.FLIGHT_PHASE_NONE:
			handoff_reached = true
		if handoff_reached and not scored and make_sim.z > shot_controller.court_config.rim_height + 0.01:
			saw_above_rim_after_handoff = true
		if not make_sim.has_passed_score_gate():
			if make_sim.z < shot_controller.court_config.over_backboard_z_threshold and make_sim.position_xy.y <= shot_controller.court_config.backboard_y + shot_controller.ball_config.ball_radius * 0.2:
				pre_score_board_side = true
		if make_sim.get_flight_phase() == BallSimulator.FLIGHT_PHASE_GUIDED_DESCENT or make_sim.get_flight_phase() == BallSimulator.FLIGHT_PHASE_NET_EXIT:
			max_descent_center_offset = maxf(max_descent_center_offset, absf(make_sim.position_xy.x - shot_controller.court_config.hoop_position.x))
		score_interaction = resolver.check_hoop_interaction(make_sim)
		if score_interaction["hit_type"] == "score" and not scored:
			scored = true
			score_phase = make_sim.get_flight_phase()
			first_score_interaction = score_interaction.duplicate(true)
		if scored and saw_net_exit and not make_sim.is_in_flight:
			break
	_assert_true(saw_guided_descent, "guided make enters guided descent", "")
	_assert_true(saw_net_exit, "guided make exits below net", "")
	_assert_true(not saw_above_rim_after_handoff, "guided make never rises above rim after handoff", "")
	_assert_true(not pre_score_board_side, "guided make never goes board-side before score", "")
	_assert_true(max_descent_center_offset <= shot_controller.ball_config.made_shot_descent_centering_tolerance + 0.5, "guided make descent stays centered", str(max_descent_center_offset))
	_assert_true(scored, "green launch scores through hoop", "")
	if scored:
		_assert_true(first_guided_descent_z <= shot_controller.court_config.rim_height + 0.01 and first_guided_descent_vz < 0.0, "first visible guided descent sample is already dropping from rim", "%0.2f %0.2f" % [first_guided_descent_z, first_guided_descent_vz])
		_assert_true(absf(projection.guided_make_terminal_screen_drop(first_guided_drop_weight) - projection_config.guided_make_terminal_screen_drop_px * (projection_screen_rect.size.x / 1080.0) * projection.get_camera_zoom()) < 0.001, "guided descent renders at full terminal drop", str(first_guided_drop_weight))
		_assert_true(score_phase == BallSimulator.FLIGHT_PHASE_GUIDED_DESCENT, "green score happens during guided descent", score_phase)
		_assert_true(_is_legal_score_sample(first_score_interaction["score_sample_xy"], shot_controller.court_config), "green score enters legal front-half corridor", str(first_score_interaction["score_sample_xy"]))
	shot_controller.begin_aim(Vector2(540.0, 1100.0), {}, rng)
	shot_controller.update_aim(0.04, Vector2.ZERO)
	var red_preview_profile: Dictionary = shot_controller.get_preview_profile(Vector2(540.0, 1100.0), shooter, false)
	var red_preview_points: Array[Dictionary] = shot_controller.create_preview(_new_ball_simulator(shot_controller.ball_config), red_preview_profile)
	var red_action: Dictionary = shot_controller.release_action(Vector2(540.0, 1100.0), shooter, false, rng)
	_assert_true(red_action["kind"] == "shot" and red_action["outcome"] == "miss" and red_action["quality"] == "red", "red release misses shot", "")
	_assert_true(str(red_action.get("profile_kind", "")) == ShotController.PROFILE_KIND_FREE_FLIGHT, "red release stays free-flight", "")
	_assert_true(_launch_profiles_match(red_preview_profile, red_action), "red preview matches release path", "")
	_assert_true(not red_preview_points.is_empty(), "red preview renders samples", "")
	if not red_preview_points.is_empty():
		var preview_probe: BallSimulator = _new_ball_simulator(shot_controller.ball_config)
		preview_probe.launch_shot_profile(red_action)
		for point in red_preview_points:
			preview_probe.step(point["sample_delta"])
		var red_preview_last: Dictionary = red_preview_points[maxi(red_preview_points.size() - 1, 0)]
		_assert_true(preview_probe.position_xy.distance_to(red_preview_last["position"]) < 0.01 and absf(preview_probe.z - float(red_preview_last["z"])) < 0.01, "preview samples mirror live simulation", "")
	var miss_sim: BallSimulator = _new_ball_simulator(shot_controller.ball_config)
	miss_sim.launch_shot_profile(red_action)
	var miss_scored: bool = false
	var miss_entered_guided_phase: bool = false
	for _miss_frame in 240:
		miss_sim.step(1.0 / 60.0)
		if miss_sim.get_flight_phase() == BallSimulator.FLIGHT_PHASE_MAKE_CAPTURE or miss_sim.get_flight_phase() == BallSimulator.FLIGHT_PHASE_GUIDED_DESCENT or miss_sim.get_flight_phase() == BallSimulator.FLIGHT_PHASE_NET_EXIT:
			miss_entered_guided_phase = true
		if resolver.check_hoop_interaction(miss_sim)["hit_type"] == "score":
			miss_scored = true
			break
	_assert_true(not miss_entered_guided_phase, "miss does not enter guided make phases", "")
	_assert_true(not miss_scored, "red launch misses rim center", "")

	var green_hold: float = shot_controller.get_decision_duration_seconds() * green_center
	shot_controller.begin_aim(Vector2(540.0, 1100.0), {}, rng)
	shot_controller.update_aim(green_hold, Vector2.ZERO)
	var green_preview_profile: Dictionary = shot_controller.get_preview_profile(Vector2(540.0, 1100.0), shooter, false)
	var green_action: Dictionary = shot_controller.release_action(Vector2(540.0, 1100.0), shooter, false, rng)
	_assert_true(green_action["kind"] == "shot" and green_action["outcome"] == "make" and green_action["quality"] == "green", "green release makes shot", "")
	_assert_true(_launch_profiles_match(green_preview_profile, green_action), "green preview matches release path", "")
	shot_controller.begin_aim(Vector2(540.0, 1100.0), {}, rng)
	shot_controller.update_aim(green_hold, Vector2.ZERO)
	var contested_green_action: Dictionary = shot_controller.release_action(Vector2(540.0, 1100.0), shooter, true, rng)
	_assert_true(contested_green_action["kind"] == "shot" and contested_green_action["outcome"] == "make" and contested_green_action["quality"] == "green", "green release stays make under contest", "")

	var simulator: BallSimulator = _new_ball_simulator(BallPhysicsConfig.new())
	simulator.launch(Vector2(540.0, 980.0), Vector2.UP * 700.0, shot_controller.ball_config.shot_release_height, 700.0)
	simulator.step(1.0 / 60.0)
	_assert_true(simulator.z > shot_controller.ball_config.shot_release_height, "ball gains z", "")
	_assert_true(simulator.vz < 700.0, "gravity reduces vz", "")

	var score_sim: BallSimulator = BallSimulator.new()
	score_sim.position_xy = shot_controller.court_config.hoop_position
	score_sim.previous_position_xy = shot_controller.court_config.hoop_position + Vector2(0.0, 12.0)
	score_sim.previous_z = 210.0
	score_sim.z = 160.0
	score_sim.vz = -100.0
	_assert_true(resolver.check_hoop_interaction(score_sim)["hit_type"] == "score", "descending score plane", "")
	var invalid_score_sim: BallSimulator = BallSimulator.new()
	invalid_score_sim.position_xy = shot_controller.court_config.hoop_position + Vector2(0.0, -6.0)
	invalid_score_sim.previous_position_xy = shot_controller.court_config.hoop_position + Vector2(0.0, -6.0)
	invalid_score_sim.previous_z = 210.0
	invalid_score_sim.z = 160.0
	invalid_score_sim.vz = -100.0
	_assert_true(resolver.check_hoop_interaction(invalid_score_sim)["hit_type"] != "score", "backboard-side crossing does not score", "")
	var invalid_forced_score_sim: BallSimulator = BallSimulator.new()
	invalid_forced_score_sim.position_xy = shot_controller.court_config.hoop_position + Vector2(0.0, -6.0)
	invalid_forced_score_sim.previous_position_xy = shot_controller.court_config.hoop_position + Vector2(0.0, -6.0)
	invalid_forced_score_sim.previous_z = 210.0
	invalid_forced_score_sim.z = 160.0
	invalid_forced_score_sim.vz = -100.0
	invalid_forced_score_sim.forced_make = true
	_assert_true(resolver.check_hoop_interaction(invalid_forced_score_sim)["hit_type"] != "score", "forced make does not score from invalid back-half entry", "")

	var court: CourtConfig = CourtConfig.new()
	_assert_true(absf(court.hoop_position.y - -50.0) < 0.001, "hoop anchor moved behind the court top", str(court.hoop_position))
	_assert_true(absf(court.three_point_radius - 840.0) < 0.001, "three-point radius preserves painted floor arc after negative hoop move", str(court.three_point_radius))
	_assert_true(absf(court.backboard_y - -120.0) < 0.001, "backboard plane moved behind the court top", str(court.backboard_y))
	_assert_true(not court.is_three_point(court.hoop_position + Vector2(0.0, 120.0)), "inside arc two", "")
	_assert_true(court.is_three_point(court.hoop_position + Vector2(0.0, 900.0)), "outside arc three", "")

	var pass_controller: PassController = PassController.new()
	pass_controller.pass_config = PassConfig.new()
	pass_controller.court_config = court
	pass_controller.difficulty_config = DifficultyConfig.new()
	var passer: PlayerController = PlayerController.new()
	var passer_data: PlayerData = PlayerData.new()
	passer_data.pass_accuracy = 88
	passer.setup(passer_data, true, Color.BLUE)
	var defender: PlayerController = PlayerController.new()
	var defender_data: PlayerData = PlayerData.new()
	defender_data.steal = 92
	defender_data.perimeter_defense = 88
	defender_data.speed = 84
	defender.setup(defender_data, false, Color.RED)
	defender.world_position = Vector2(540.0, 720.0)
	var short_target: PlayerController = PlayerController.new()
	var short_target_data: PlayerData = PlayerData.new()
	short_target_data.catch_rating = 86
	short_target_data.speed = 78
	short_target.setup(short_target_data, true, Color.BLUE)
	short_target.world_position = Vector2(600.0, 840.0)
	var long_target: PlayerController = PlayerController.new()
	var long_target_data: PlayerData = PlayerData.new()
	long_target_data.catch_rating = 54
	long_target_data.speed = 66
	long_target.setup(long_target_data, true, Color.BLUE)
	long_target.world_position = Vector2(820.0, 420.0)
	var race_target: PlayerController = PlayerController.new()
	var race_target_data: PlayerData = PlayerData.new()
	race_target_data.catch_rating = 84
	race_target_data.speed = 80
	race_target.setup(race_target_data, true, Color.BLUE)
	race_target.world_position = Vector2(720.0, 580.0)
	var normal_defense_scale: float = DifficultyConfig.new().get_defense_multiplier()
	var pass_rng: GameRng = GameRng.new()
	pass_rng.reseed(11)
	short_target.world_position = Vector2(612.0, 840.0)
	defender.world_position = Vector2(578.0, 820.0)
	var safe_result: Dictionary = _simulate_pass_race(
		pass_controller,
		Vector2(520.0, 900.0),
		short_target,
		[defender],
		Vector2(32.0, 44.0),
		1.0,
		normal_defense_scale,
		240,
		pass_rng,
		passer
	)
	var safe_snapshot: Dictionary = safe_result.get("start_snapshot", {})
	_assert_true(safe_snapshot.get("eligible_interceptor", null) != null, "eligible defender detected on short pass", JSON.stringify(safe_snapshot))
	_assert_true(not bool(safe_snapshot.get("commit_succeeded", true)), "eligible defender can fail commit roll", JSON.stringify(safe_snapshot))
	_assert_true(safe_result["state"] == "complete_offense", "receiver-first claim completes pass", JSON.stringify(safe_result))
	passer_data.pass_accuracy = 68
	var steal_seed: int = _find_commit_seed(
		pass_controller,
		Vector2(260.0, 1180.0),
		long_target,
		[defender],
		passer
	)
	_assert_true(steal_seed != -1, "risky pass finds deterministic commit seed", str(steal_seed))
	pass_rng.reseed(steal_seed)
	long_target.world_position = Vector2(820.0, 420.0)
	defender.world_position = Vector2(540.0, 720.0)
	var steal_result: Dictionary = _simulate_pass_race(
		pass_controller,
		Vector2(260.0, 1180.0),
		long_target,
		[defender],
		Vector2(120.0, 160.0),
		1.0,
		normal_defense_scale,
		240,
		pass_rng,
		passer
	)
	var steal_snapshot: Dictionary = steal_result.get("start_snapshot", {})
	_assert_true(bool(steal_snapshot.get("commit_succeeded", false)), "risky pass can trigger commit roll", JSON.stringify(steal_snapshot))
	_assert_true(steal_result["state"] == "complete_steal", "defender-first lane cut steals pass", JSON.stringify(steal_result))
	defender_data.steal = 48
	defender_data.perimeter_defense = 52
	defender_data.speed = 70
	defender.world_position = Vector2(760.0, 580.0)
	var committed_but_late_seed: int = _find_commit_seed(
		pass_controller,
		Vector2(320.0, 1140.0),
		race_target,
		[defender],
		passer
	)
	_assert_true(committed_but_late_seed != -1, "late-race pass finds deterministic commit seed", str(committed_but_late_seed))
	pass_rng.reseed(committed_but_late_seed)
	race_target.world_position = Vector2(720.0, 580.0)
	var committed_but_late_result: Dictionary = _simulate_pass_race(
		pass_controller,
		Vector2(320.0, 1140.0),
		race_target,
		[defender],
		Vector2.ZERO,
		1.0,
		normal_defense_scale,
		240,
		pass_rng,
		passer
	)
	var committed_but_late_snapshot: Dictionary = committed_but_late_result.get("start_snapshot", {})
	_assert_true(bool(committed_but_late_snapshot.get("commit_succeeded", false)), "committed defender test arms a lane cut", JSON.stringify(committed_but_late_snapshot))
	_assert_true(committed_but_late_result["state"] == "complete_offense", "committed defender can still lose live race", JSON.stringify(committed_but_late_result))
	defender_data.steal = 92
	defender_data.perimeter_defense = 88
	defender_data.speed = 84
	passer_data.pass_accuracy = 88
	pass_rng.reseed(11)
	short_target.world_position = Vector2(612.0, 840.0)
	defender.world_position = Vector2(578.0, 820.0)
	var forced_start_snapshot: Dictionary = pass_controller.start_pass(Vector2(520.0, 900.0), short_target, [defender], pass_rng, passer)
	_assert_true(not bool(forced_start_snapshot.get("commit_succeeded", true)), "force interception starts from a failed commit", JSON.stringify(forced_start_snapshot))
	var forced_pass: Dictionary = pass_controller.force_interception([defender])
	_assert_true(bool(forced_pass.get("commit_succeeded", false)), "force interception bypasses commit roll", JSON.stringify(forced_pass))
	var forced_release_target: Vector2 = pass_controller.get_active_pass_snapshot().get("end", short_target.world_position)
	short_target.world_position = forced_release_target + Vector2(32.0, 44.0)
	short_target.velocity = Vector2.ZERO
	var forced_result: Dictionary = {"state": "traveling"}
	for _forced_frame in 240:
		var forced_snapshot_live: Dictionary = pass_controller.get_active_pass_snapshot()
		if forced_snapshot_live.is_empty():
			break
		short_target.move_toward_target(forced_release_target, 1.0, 1.0 / 60.0)
		var forced_interceptor: PlayerController = forced_snapshot_live.get("active_interceptor", null) as PlayerController
		if forced_interceptor != null:
			forced_interceptor.move_toward_target(forced_snapshot_live.get("chase_point", forced_interceptor.world_position), normal_defense_scale, 1.0 / 60.0)
		forced_result = pass_controller.step_pass(1.0 / 60.0)
		if forced_result.get("state", "") != "traveling":
			break
	_assert_true(forced_result["state"] == "complete_steal", "forced interception still resolves through live steal path", JSON.stringify(forced_result))
	var out_target: PlayerController = PlayerController.new()
	var out_target_data: PlayerData = PlayerData.new()
	out_target_data.catch_rating = 74
	out_target.setup(out_target_data, true, Color.BLUE)
	out_target.world_position = Vector2(court.court_rect.end.x + 120.0, 860.0)
	pass_rng.reseed(7)
	defender.world_position = Vector2(700.0, 760.0)
	var out_result: Dictionary = _simulate_pass_race(
		pass_controller,
		Vector2(520.0, 900.0),
		out_target,
		[defender],
		Vector2.ZERO,
		1.0,
		normal_defense_scale,
		240,
		pass_rng,
		passer
	)
	_assert_true(out_result["state"] == "out_of_bounds", "out-of-bounds resolves before catch", JSON.stringify(out_result))
	var input_controller: InputController = InputController.new()
	var input_config = preload("res://scripts/config/InputConfig.gd").new()
	input_controller.setup(input_config, projection)
	input_controller.set_ballhandler(short_target)
	input_controller.set_offense_players([short_target, long_target, out_target])
	input_controller.set_interaction_mode(InputController.InteractionMode.LIVE_OFFENSE)
	short_target.apply_projection(projection.world_to_screen_ground(short_target.world_position), projection.actor_scale(short_target.world_position), projection.shadow_anchor(short_target.world_position) - projection.world_to_screen_ground(short_target.world_position), projection.shadow_scale(short_target.world_position), projection.depth_key(short_target.world_position))
	long_target.apply_projection(projection.world_to_screen_ground(long_target.world_position), projection.actor_scale(long_target.world_position), projection.shadow_anchor(long_target.world_position) - projection.world_to_screen_ground(long_target.world_position), projection.shadow_scale(long_target.world_position), projection.depth_key(long_target.world_position))
	out_target.apply_projection(projection.world_to_screen_ground(out_target.world_position), projection.actor_scale(out_target.world_position), projection.shadow_anchor(out_target.world_position) - projection.world_to_screen_ground(out_target.world_position), projection.shadow_scale(out_target.world_position), projection.depth_key(out_target.world_position))
	var movement_snapshot: Dictionary = input_controller.compute_movement_snapshot(Vector2.ZERO, Vector2(input_config.invisible_stick_max_radius, 0.0))
	_assert_true(movement_snapshot["direction"].is_equal_approx(Vector2.RIGHT), "invisible stick direction follows thumb vector", str(movement_snapshot))
	_assert_true(float(movement_snapshot["magnitude"]) > 0.99, "invisible stick reaches full magnitude at max radius", str(movement_snapshot["magnitude"]))
	var quick_tap: Dictionary = input_controller.classify_pass_tap(0.12, 10.0)
	_assert_true(bool(quick_tap.get("qualifies", false)), "quick tap qualifies for pass", JSON.stringify(quick_tap))
	var long_tap: Dictionary = input_controller.classify_pass_tap(input_config.pass_tap_max_duration_seconds + 0.05, 10.0)
	_assert_true(not bool(long_tap.get("qualifies", true)), "long hold does not qualify for pass", JSON.stringify(long_tap))
	var drag_tap: Dictionary = input_controller.classify_pass_tap(0.1, input_config.pass_tap_max_movement_pixels + 8.0)
	_assert_true(not bool(drag_tap.get("qualifies", true)), "dragged touch does not qualify for pass", JSON.stringify(drag_tap))
	var top_half_release_y: float = 720.0
	var swipe_up: Dictionary = input_controller.classify_vertical_shot_swipe(Vector2(540.0, 1200.0), Vector2(540.0, top_half_release_y))
	_assert_true(
		bool(swipe_up.get("qualifies", false))
			and swipe_up.get("swipe_direction", "") == "up"
			and bool(swipe_up.get("ends_in_top_half", false)),
		"upward swipe into the top half arms shot mode",
		JSON.stringify(swipe_up)
	)
	var low_upward_swipe: Dictionary = input_controller.classify_vertical_shot_swipe(Vector2(540.0, 1600.0), Vector2(540.0, 1180.0))
	_assert_true(
		not bool(low_upward_swipe.get("qualifies", true)) and not bool(low_upward_swipe.get("ends_in_top_half", true)),
		"upward swipe that stays in the lower half does not arm shot mode",
		JSON.stringify(low_upward_swipe)
	)
	var swipe_down: Dictionary = input_controller.classify_vertical_shot_swipe(Vector2(540.0, 640.0), Vector2(540.0, 640.0 + input_config.shot_swipe_min_distance_pixels + 24.0))
	_assert_true(not bool(swipe_down.get("qualifies", true)), "downward swipe does not arm shot mode", JSON.stringify(swipe_down))
	var short_swipe: Dictionary = input_controller.classify_vertical_shot_swipe(Vector2.ZERO, Vector2(0.0, -(input_config.shot_swipe_min_distance_pixels - 12.0)))
	_assert_true(not bool(short_swipe.get("qualifies", true)), "short swipe does not arm shot mode", JSON.stringify(short_swipe))
	var horizontal_swipe: Dictionary = input_controller.classify_vertical_shot_swipe(Vector2.ZERO, Vector2(input_config.shot_swipe_min_distance_pixels + 24.0, 0.0))
	_assert_true(not bool(horizontal_swipe.get("qualifies", true)), "horizontal swipe does not arm shot mode", JSON.stringify(horizontal_swipe))
	_assert_true(input_controller.find_tapped_teammate(long_target.get_screen_anchor()) == long_target, "tapping teammate hit-tests explicit receiver", long_target.get_position_role())
	_assert_true(input_controller.find_tapped_teammate(Vector2(540.0, 640.0)) == null, "empty tap does not falsely pick teammate", "")
	var pass_requests: Array[Dictionary] = []
	input_controller.pass_requested.connect(func(target: PlayerController, details: Dictionary) -> void:
		pass_requests.append({"target": target, "details": details.duplicate(true)})
	)
	var shot_mode_requests: Array[Dictionary] = []
	input_controller.shot_mode_requested.connect(func(details: Dictionary) -> void:
		shot_mode_requests.append(details.duplicate(true))
	)
	input_controller.tap_test_pass(Vector2(540.0, 640.0), 0.05)
	_assert_true(
		pass_requests.size() == 1
			and pass_requests[0].get("target", long_target) == null
			and not bool(pass_requests[0]["details"].get("started_in_movement_zone", true)),
		"quick tap outside the movement zone passes to default target",
		JSON.stringify(pass_requests[0]["details"] if not pass_requests.is_empty() else {})
	)
	input_controller.tap_test_pass(Vector2(540.0, 1800.0), 0.05)
	_assert_true(
		pass_requests.size() == 2
			and pass_requests[1].get("target", long_target) == null
			and bool(pass_requests[1]["details"].get("started_in_movement_zone", false)),
		"quick tap inside the movement zone also passes",
		JSON.stringify(pass_requests[1]["details"] if pass_requests.size() > 1 else {})
	)
	input_controller.tap_test_pass(long_target.get_screen_anchor(), 0.05)
	_assert_true(
		pass_requests.size() == 3
			and pass_requests[2].get("target", null) == long_target
			and str(pass_requests[2]["details"].get("release_reason", "")) == "direct_tap_pass",
		"direct teammate tap emits explicit pass target",
		JSON.stringify(pass_requests[2]["details"] if pass_requests.size() > 2 else {})
	)
	input_controller.swipe_test_shot_arm(Vector2(540.0, 1200.0), Vector2(540.0, top_half_release_y), 0.12)
	_assert_true(
		shot_mode_requests.size() == 1
			and str(shot_mode_requests[0].get("swipe_direction", "")) == "up"
			and bool(shot_mode_requests[0].get("ends_in_top_half", false))
			and not bool(shot_mode_requests[0].get("started_in_movement_zone", true)),
		"swipe up into the top half outside the movement zone arms shot mode",
		JSON.stringify(shot_mode_requests[0] if not shot_mode_requests.is_empty() else {})
	)
	input_controller.swipe_test_shot_arm(Vector2(540.0, 640.0), Vector2(540.0, 640.0 + input_config.shot_swipe_min_distance_pixels + 32.0), 0.12)
	_assert_true(
		shot_mode_requests.size() == 1,
		"swipe down does not arm shot mode",
		JSON.stringify(shot_mode_requests[0] if not shot_mode_requests.is_empty() else {})
	)
	input_controller.swipe_test_shot_arm(Vector2(540.0, 1800.0), Vector2(540.0, top_half_release_y), 0.12)
	_assert_true(
		shot_mode_requests.size() == 2
			and bool(shot_mode_requests[1].get("started_in_movement_zone", false))
			and bool(shot_mode_requests[1].get("ends_in_top_half", false)),
		"upward swipe into the top half from the movement zone wins over movement release",
		JSON.stringify(shot_mode_requests[1] if shot_mode_requests.size() > 1 else {})
	)
	input_controller.begin_test_live_gesture(Vector2(540.0, 1800.0))
	input_controller.tap_test_pass(Vector2(540.0, 640.0), 0.05)
	input_controller.swipe_test_shot_arm(Vector2(540.0, 1200.0), Vector2(540.0, top_half_release_y), 0.12)
	_assert_true(pass_requests.size() == 3 and shot_mode_requests.size() == 2, "additional touches are ignored while dragging", JSON.stringify({"passes": pass_requests.size(), "shots": shot_mode_requests.size()}))
	input_controller.end_test_live_gesture(Vector2(540.0, 1800.0))

	var route_controller: RouteController = RouteController.new()
	route_controller.route_config = RouteConfig.new()
	route_controller.court_config = court
	var players: Array[PlayerController] = []
	for role in ["PG", "LW", "RW", "LC", "RC"]:
		var player: PlayerController = PlayerController.new()
		var data: PlayerData = PlayerData.new()
		data.role = role
		player.setup(data, true, Color.BLUE)
		player.world_position = court.get_anchor_map()[role]
		players.append(player)
	var targets: Dictionary = route_controller.get_route_targets(players, players[0], 0, 1.2)
	_assert_true(targets.size() == 4, "route targets generated", "")
	route_controller.reset_runtime_state()
	players[0].world_position = Vector2(court.hoop_position.x - 16.0, court.get_anchor_map()["PG"].y)
	var strong_left_targets: Dictionary = route_controller.get_route_targets(players, players[0], 1, 0.8)
	players[0].world_position = Vector2(court.hoop_position.x + route_controller.route_config.side_switch_deadband * 0.5, court.get_anchor_map()["PG"].y)
	var strong_hold_targets: Dictionary = route_controller.get_route_targets(players, players[0], 1, 0.8)
	_assert_true(
		strong_left_targets.get(players[1], Vector2.ZERO).distance_to(strong_hold_targets.get(players[1], Vector2.ZERO)) < 0.01
			and strong_left_targets.get(players[4], Vector2.ZERO).distance_to(strong_hold_targets.get(players[4], Vector2.ZERO)) < 0.01,
		"route side holds inside hysteresis deadband",
		"%s %s" % [strong_left_targets.get(players[1], Vector2.ZERO), strong_hold_targets.get(players[1], Vector2.ZERO)]
	)
	players[0].world_position = Vector2(court.hoop_position.x + route_controller.route_config.side_switch_deadband + 18.0, court.get_anchor_map()["PG"].y)
	var strong_switched_targets: Dictionary = route_controller.get_route_targets(players, players[0], 1, 0.8)
	_assert_true(
		strong_left_targets.get(players[1], Vector2.ZERO).distance_to(strong_switched_targets.get(players[1], Vector2.ZERO)) > 20.0,
		"route side flips after hysteresis deadband",
		"%s %s" % [strong_left_targets.get(players[1], Vector2.ZERO), strong_switched_targets.get(players[1], Vector2.ZERO)]
	)
	route_controller.reset_runtime_state()
	players[0].world_position = Vector2(court.hoop_position.x - 16.0, court.get_anchor_map()["PG"].y)
	var weak_left_targets: Dictionary = route_controller.get_route_targets(players, players[0], 2, 0.8)
	players[0].world_position = Vector2(court.hoop_position.x + route_controller.route_config.side_switch_deadband * 0.5, court.get_anchor_map()["PG"].y)
	var weak_hold_targets: Dictionary = route_controller.get_route_targets(players, players[0], 2, 0.8)
	_assert_true(
		weak_left_targets.get(players[3], Vector2.ZERO).distance_to(weak_hold_targets.get(players[3], Vector2.ZERO)) < 0.01,
		"weak-side fill holds inside hysteresis deadband",
		"%s %s" % [weak_left_targets.get(players[3], Vector2.ZERO), weak_hold_targets.get(players[3], Vector2.ZERO)]
	)

	var smooth_player: PlayerController = PlayerController.new()
	var smooth_player_data: PlayerData = PlayerData.new()
	smooth_player_data.speed = 80
	smooth_player.setup(smooth_player_data, true, Color.BLUE)
	smooth_player.world_position = Vector2.ZERO
	smooth_player.velocity = Vector2.ZERO
	var near_target: Vector2 = Vector2(18.0, 0.0)
	var near_sign_changes: int = 0
	var previous_sign: float = signf(near_target.x - smooth_player.world_position.x)
	for _near_frame in 180:
		smooth_player.move_toward_target_smooth(
			near_target,
			route_controller.route_config.route_move_speed_multiplier,
			1.0 / 60.0,
			route_controller.route_config.steering_arrival_radius,
			route_controller.route_config.steering_stop_radius,
			route_controller.route_config.steering_acceleration,
			route_controller.route_config.steering_deceleration
		)
		var current_sign: float = signf(near_target.x - smooth_player.world_position.x)
		if current_sign != 0.0 and previous_sign != 0.0 and current_sign != previous_sign:
			near_sign_changes += 1
		if current_sign != 0.0:
			previous_sign = current_sign
	_assert_true(near_sign_changes == 0, "smooth steering does not oscillate near target", str(near_sign_changes))
	_assert_true(
		smooth_player.world_position.distance_to(near_target) <= route_controller.route_config.steering_stop_radius + 0.5 and smooth_player.velocity.length() <= 1.0,
		"smooth steering settles near target",
		"%0.2f %0.2f" % [smooth_player.world_position.distance_to(near_target), smooth_player.velocity.length()]
	)
	smooth_player.world_position = Vector2.ZERO
	smooth_player.velocity = Vector2.ZERO
	var far_target: Vector2 = Vector2(520.0, 0.0)
	var peak_smooth_speed: float = 0.0
	for _far_frame in 240:
		smooth_player.move_toward_target_smooth(
			far_target,
			route_controller.route_config.route_move_speed_multiplier,
			1.0 / 60.0,
			route_controller.route_config.steering_arrival_radius,
			route_controller.route_config.steering_stop_radius,
			route_controller.route_config.steering_acceleration,
			route_controller.route_config.steering_deceleration
		)
		peak_smooth_speed = maxf(peak_smooth_speed, smooth_player.velocity.length())
		if smooth_player.world_position.distance_to(far_target) <= route_controller.route_config.steering_stop_radius and smooth_player.velocity.length() <= 1.0:
			break
	var expected_peak_speed: float = (180.0 + float(smooth_player_data.speed) * 2.2) * route_controller.route_config.route_move_speed_multiplier
	_assert_true(smooth_player.world_position.distance_to(far_target) <= route_controller.route_config.steering_stop_radius + 1.0, "smooth steering reaches distant target", str(smooth_player.world_position.distance_to(far_target)))
	_assert_true(peak_smooth_speed >= expected_peak_speed * 0.82, "smooth steering preserves long-run pace", "%0.2f %0.2f" % [peak_smooth_speed, expected_peak_speed])

	var rebound_controller: ReboundController = ReboundController.new()
	rebound_controller.rebound_config = ReboundConfig.new()
	var candidates: Array[Dictionary] = rebound_controller.get_rebound_candidates(Vector2(540.0, 640.0), players.slice(0, 2), players.slice(2, 5))
	_assert_true(candidates.size() >= 2, "rebound fallback candidates", "")

	var sim_controller: OpponentSimController = OpponentSimController.new()
	sim_controller.sim_config = OpponentSimConfig.new()
	sim_controller.difficulty_config = DifficultyConfig.new()
	rng.reseed(9)
	var home_team: TeamData = load("res://data/teams/HOM.tres")
	var away_team: TeamData = load("res://data/teams/AWY.tres")
	var sim_result: Dictionary = sim_controller.run_possession(away_team, home_team, 180.0, rng)
	_assert_true(sim_result["points_scored"] >= 0 and sim_result["points_scored"] <= 3, "opponent sim valid score", "")
	_assert_true(sim_result["time_consumed"] > 0.0, "opponent sim consumes time", "")

	var log_writer: LogWriter = LogWriter.new()
	log_writer.set_prefix("test_check")
	log_writer.log_match("hello")
	var file_path: String = ProjectSettings.globalize_path("user://logs/test_check_match.log")
	_assert_true(FileAccess.file_exists(file_path), "logs written", file_path)
	_assert_true(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/GameRoot.tscn", "gameplay boot scene", "")
	var game_root_scene: PackedScene = load("res://scenes/GameRoot.tscn")
	var game_root: Node2D = game_root_scene.instantiate() as Node2D
	add_child(game_root)
	await get_tree().process_frame
	var smoke_court_view: CourtView = game_root.get_node("CourtView") as CourtView
	var smoke_coordinator: GameCoordinator = game_root.get_node("GameCoordinator") as GameCoordinator
	_assert_true(smoke_court_view != null and smoke_court_view.has_textured_court(), "court art smoke", "")
	_assert_true(smoke_coordinator != null and smoke_coordinator.hoop_node != null and smoke_coordinator.hoop_node.has_sprite_visuals(), "hoop art smoke", "")
	_assert_true(smoke_coordinator != null and smoke_coordinator.ball_node != null and smoke_coordinator.ball_node.has_sprite_visuals(), "ball art smoke", "")
	_assert_true(smoke_coordinator != null and smoke_coordinator.hoop_node != null and smoke_coordinator.hoop_node.has_method("get_ball_z_index_for_phase"), "hoop render-phase z accessor exists", "")
	_assert_true(smoke_coordinator != null and smoke_coordinator.hoop_node != null and smoke_coordinator.hoop_node.has_method("get_front_net_exit_screen_y"), "hoop net exit helper exists", "")
	var smoke_viewport_center: Vector2 = game_root.get_viewport().get_visible_rect().get_center()
	var home_visual_ok: bool = smoke_coordinator != null and smoke_coordinator.offense_players.size() == 5
	if home_visual_ok:
		for smoke_player in smoke_coordinator.offense_players + smoke_coordinator.defense_players:
			if not smoke_player.has_sprite_visuals():
				home_visual_ok = false
				break
	_assert_true(home_visual_ok, "player art smoke", "")
	if smoke_coordinator != null and smoke_coordinator.debug_overlay != null and smoke_coordinator.debug_config != null:
		_assert_true(not smoke_coordinator.debug_overlay.visible, "debug overlay defaults off in normal play", str(smoke_coordinator.debug_overlay.visible))
		_assert_true(not smoke_coordinator.debug_config.show_catch_radii, "default teammate catch rings stay hidden", str(smoke_coordinator.debug_config.show_catch_radii))
	if smoke_coordinator != null and smoke_coordinator.court_projection != null and smoke_coordinator.court_config != null:
		var smoke_layout: Dictionary = smoke_coordinator.get_layout_metrics_snapshot()
		var smoke_court_rect: Rect2 = smoke_layout.get("court_screen_rect", Rect2())
		var smoke_available_rect: Rect2 = smoke_layout.get("available_play_rect", Rect2())
		var smoke_rect: Rect2 = smoke_coordinator.court_config.court_rect
		var smoke_top_left: Vector2 = smoke_coordinator.court_projection.world_to_base_screen_ground(smoke_rect.position)
		var smoke_bottom_right: Vector2 = smoke_coordinator.court_projection.world_to_base_screen_ground(smoke_rect.end)
		_assert_true(smoke_top_left.distance_to(smoke_court_rect.position) < 0.01 and smoke_bottom_right.distance_to(smoke_court_rect.end) < 0.01, "court maps to responsive screen rect", "%s %s %s" % [smoke_top_left, smoke_bottom_right, smoke_court_rect])
		_assert_true(absf(smoke_court_rect.get_center().x - smoke_available_rect.get_center().x) < 0.01 and absf(smoke_court_rect.get_center().y - smoke_available_rect.get_center().y) < 0.01, "court stays centered below banner", "%s %s" % [smoke_court_rect, smoke_available_rect])
	if smoke_coordinator != null and smoke_coordinator.hud != null:
		var hud_snapshot: Dictionary = smoke_coordinator.hud.get_layout_snapshot()
		for snapshot_key in ["home_rect", "timer_rect", "pause_rect", "away_rect"]:
			_assert_true(_rect_contains_rect(hud_snapshot.get("banner_rect", Rect2()), hud_snapshot.get(snapshot_key, Rect2())), "%s fits inside hud banner" % snapshot_key, str(hud_snapshot.get(snapshot_key, Rect2())))
	if smoke_coordinator != null and smoke_coordinator.pause_overlay != null:
		smoke_coordinator.test_toggle_pause()
		_assert_true(smoke_coordinator.pause_overlay.visible, "pause overlay opens for debug toggles", str(smoke_coordinator.pause_overlay.visible))
		_assert_true(not smoke_coordinator.pause_overlay.is_no_defenders_enabled(), "no-defenders pause toggle starts disabled", str(smoke_coordinator.pause_overlay.is_no_defenders_enabled()))
		smoke_coordinator.test_set_defenders_disabled(true)
		_assert_true(smoke_coordinator.are_defenders_disabled(), "pause toggle disables defenders", str(smoke_coordinator.are_defenders_disabled()))
		var hidden_defenders: bool = true
		for smoke_defender in smoke_coordinator.defense_players:
			if smoke_defender.visible:
				hidden_defenders = false
				break
		_assert_true(hidden_defenders, "disabled defenders are removed from view", str(hidden_defenders))
		var no_defender_pg: PlayerController = smoke_coordinator.get_offense_player_by_role("PG")
		if no_defender_pg != null:
			no_defender_pg.world_position = smoke_coordinator.court_config.hoop_position + Vector2(20.0, 118.0)
			var no_defender_finish: Dictionary = smoke_coordinator._build_shot_release_visual_decision(no_defender_pg, Vector2.ZERO, INF)
			_assert_true(str(no_defender_finish.get("family", "")) == "close_finish_dunk", "no defenders force a close-range dunk", JSON.stringify(no_defender_finish))
			_assert_true(bool(no_defender_finish.get("force_no_defenders_dunk", false)), "no defenders mark the forced dunk override", JSON.stringify(no_defender_finish))
		smoke_coordinator.test_set_defenders_disabled(false)
		_assert_true(not smoke_coordinator.are_defenders_disabled(), "pause toggle re-enables defenders", str(smoke_coordinator.are_defenders_disabled()))
		var visible_defenders: bool = true
		for smoke_defender in smoke_coordinator.defense_players:
			if not smoke_defender.visible:
				visible_defenders = false
				break
		_assert_true(visible_defenders, "re-enabled defenders return to view", str(visible_defenders))
		smoke_coordinator.test_toggle_pause()
		_assert_true(smoke_coordinator.get_state_name() == "LIVE_OFFENSE", "pause overlay resumes after debug toggles", smoke_coordinator.get_state_name())
	if smoke_coordinator != null and smoke_coordinator.current_ballhandler != null:
		_assert_true(
			smoke_coordinator.current_ballhandler.projected_scale > smoke_coordinator.court_projection.base_actor_scale(smoke_coordinator.current_ballhandler.world_position) * 2.05,
			"players keep oversized close-camera scale",
			str(smoke_coordinator.current_ballhandler.projected_scale)
		)
		_assert_true(smoke_coordinator.current_ballhandler.get_screen_anchor().distance_to(smoke_viewport_center) < 0.01, "opening possession centers ballhandler", str(smoke_coordinator.current_ballhandler.get_screen_anchor()))
		_assert_true(not smoke_coordinator.ball_node.is_ball_visible(), "held ball hidden while possessed", str(smoke_coordinator.ball_node.is_ball_visible()))
		_assert_floor_marker_state(smoke_coordinator.current_ballhandler, true, "opening possession controlled floor marker")
	var smoke_live_offense_setup: Dictionary = {
		"ballhandler_role": "PG",
		"defense_positions": {
			"LC": Vector2(300, 620),
			"LW": Vector2(300, 1060),
			"PG": Vector2(320, 1460),
			"RC": Vector2(830, 640),
			"RW": Vector2(800, 1060),
		},
		"offense_positions": {
			"LC": Vector2(260, 640),
			"LW": Vector2(360, 1040),
			"PG": Vector2(520, 1360),
			"RC": Vector2(620, 900),
			"RW": Vector2(740, 1100),
		},
	}
	smoke_coordinator.begin_test_mode(2409)
	smoke_coordinator.apply_scenario_setup(smoke_live_offense_setup)
	var smoke_pass_target: PlayerController = smoke_coordinator.get_offense_player_by_role("RC")
	var pass_positions: Array[Vector2] = []
	var pass_world_positions: Array[Vector2] = []
	var pass_alignment_error: float = 0.0
	var pass_tracking_error: float = 0.0
	if smoke_pass_target != null:
		var idle_feedback: Dictionary = smoke_coordinator._build_court_input_feedback()
		var marked_pass_target: PlayerController = smoke_coordinator.default_pass_target
		_assert_true(marked_pass_target != null, "persistent default pass target exists", "")
		var expected_preview_screen: Vector2 = smoke_coordinator.court_projection.world_to_screen_ground(marked_pass_target.world_position) if marked_pass_target != null else Vector2.INF
		_assert_true(idle_feedback.get("pass_target_style", "") == "blue_ring", "persistent pass marker uses blue ring style", JSON.stringify(idle_feedback))
		_assert_true(
			idle_feedback.get("pass_target_screen", Vector2.INF) != Vector2.INF
				and idle_feedback.get("pass_target_screen", Vector2.ZERO).distance_to(expected_preview_screen) < 0.01,
			"persistent pass marker tracks the default target",
			str(idle_feedback.get("pass_target_screen", Vector2.INF))
		)
		_assert_true(not smoke_coordinator.ball_node.is_ball_visible(), "ball hidden before pass", str(smoke_coordinator.ball_node.is_ball_visible()))
		smoke_coordinator.input_controller.tap_test_pass(smoke_coordinator.current_ballhandler.get_screen_anchor(), 0.05)
		var default_pass_snapshot: Dictionary = smoke_coordinator.pass_controller.get_active_pass_snapshot()
		_assert_true(
			smoke_coordinator.context.current_state == GameState.State.PASS_IN_FLIGHT and default_pass_snapshot.get("intended_receiver", null) == marked_pass_target,
			"empty tap passes to the marked teammate",
			str(default_pass_snapshot.get("intended_receiver", null))
		)
		_assert_true(smoke_coordinator.ball_node.is_ball_visible(), "ball visible when pass starts", str(smoke_coordinator.ball_node.is_ball_visible()))
		for _pass_frame in 36:
			await get_tree().process_frame
			if smoke_coordinator.context.current_state == GameState.State.PASS_IN_FLIGHT:
				var visible_ball_anchor: Vector2 = smoke_coordinator.ball_node.global_position + smoke_coordinator.ball_node.ball_screen_offset
				pass_positions.append(visible_ball_anchor)
				pass_world_positions.append(smoke_coordinator.ball_simulator.position_xy)
				var expected_pass_anchor: Vector2 = smoke_coordinator.court_projection.world_to_screen(smoke_coordinator.ball_simulator.position_xy, smoke_coordinator.ball_simulator.z)
				pass_alignment_error = maxf(pass_alignment_error, visible_ball_anchor.distance_to(expected_pass_anchor))
				pass_tracking_error = maxf(pass_tracking_error, visible_ball_anchor.distance_to(smoke_viewport_center))
			elif not pass_positions.is_empty():
				break
	_assert_true(pass_positions.size() >= 3, "pass flight stays visible across frames", str(pass_positions.size()))
	if pass_positions.size() >= 3:
		_assert_true(pass_world_positions[0].distance_to(pass_world_positions[-1]) > 40.0, "pass flight advances in world space", "%0.2f" % pass_world_positions[0].distance_to(pass_world_positions[-1]))
		_assert_true(pass_alignment_error < 0.01, "in-flight ball stays aligned with projection", str(pass_alignment_error))
		_assert_true(pass_tracking_error < 180.0, "camera tracks the live pass ball", str(pass_tracking_error))
	_assert_true(not smoke_coordinator.ball_node.is_ball_visible(), "ball hides on catch", str(smoke_coordinator.ball_node.is_ball_visible()))
	smoke_coordinator.begin_test_mode(2409)
	smoke_coordinator.apply_scenario_setup(smoke_live_offense_setup)
	var direct_pass_target: PlayerController
	for candidate in smoke_coordinator.offense_players:
		if candidate != smoke_coordinator.current_ballhandler and candidate != smoke_coordinator.default_pass_target:
			direct_pass_target = candidate
			break
	if direct_pass_target != null:
		smoke_coordinator.input_controller.tap_test_pass(direct_pass_target.get_screen_anchor(), 0.05)
		var direct_pass_snapshot: Dictionary = smoke_coordinator.pass_controller.get_active_pass_snapshot()
		_assert_true(
			smoke_coordinator.context.current_state == GameState.State.PASS_IN_FLIGHT and direct_pass_snapshot.get("intended_receiver", null) == direct_pass_target,
			"direct teammate tap bypasses the marked target",
			str(direct_pass_snapshot.get("intended_receiver", null))
		)
	_reset_visual_test_state(smoke_coordinator)
	var smoke_viewport_size: Vector2 = game_root.get_viewport().get_visible_rect().size
	var smoke_top_half_release_y: float = smoke_viewport_size.y * float(smoke_coordinator.input_config.shot_swipe_max_release_y_ratio) - 24.0
	var upward_swipe_start: Vector2 = Vector2(smoke_viewport_size.x * 0.5, smoke_viewport_size.y * 0.88)
	var upward_swipe_end: Vector2 = Vector2(upward_swipe_start.x, smoke_top_half_release_y)
	smoke_coordinator.input_controller.swipe_test_shot_arm(upward_swipe_start, upward_swipe_end, 0.12)
	_assert_true(smoke_coordinator.context.current_state == GameState.State.SHOT_AIM, "upward swipe into the top half enters shot aim", smoke_coordinator.get_state_name())
	_reset_visual_test_state(smoke_coordinator)
	var downward_swipe_start: Vector2 = Vector2(smoke_viewport_size.x * 0.5, smoke_viewport_size.y * 0.56)
	var downward_swipe_end: Vector2 = downward_swipe_start + Vector2(0.0, maxf(float(smoke_coordinator.input_config.shot_swipe_min_distance_pixels) + 40.0, 132.0))
	smoke_coordinator.input_controller.swipe_test_shot_arm(downward_swipe_start, downward_swipe_end, 0.12)
	_assert_true(smoke_coordinator.context.current_state == GameState.State.LIVE_OFFENSE, "downward swipe does not enter shot aim", smoke_coordinator.get_state_name())
	_reset_visual_test_state(smoke_coordinator)
	var visual_pg: PlayerController = smoke_coordinator.get_offense_player_by_role("PG")
	var visual_rc: PlayerController = smoke_coordinator.get_offense_player_by_role("RC")
	var visual_pg_defender: PlayerController = smoke_coordinator.get_defense_player_by_role("PG")
	_assert_true(visual_pg != null and visual_pg.get_debug_fill_texture_path().contains("Character1_NEW.png"), "home player uses Character1 sheet", visual_pg.get_debug_fill_texture_path() if visual_pg != null else "")
	_assert_true(visual_pg_defender != null and visual_pg_defender.get_debug_fill_texture_path().contains("Character2_NEW.png"), "away player uses Character2 sheet", visual_pg_defender.get_debug_fill_texture_path() if visual_pg_defender != null else "")
	if visual_pg != null and visual_rc != null and visual_pg_defender != null:
		smoke_coordinator.player_visual_memory[visual_pg] = {"family": "ball_idle_open", "variant_index": 2, "mirror_west": false}
		smoke_coordinator._sync_projection_visuals(0.0)
		_assert_player_visual(visual_pg, "ball_idle_open", 11, false, true, "controlled open idle")
		_assert_true(not visual_rc.is_outline_visible(), "non-controlled offense outline hidden", "")
		_assert_true(not visual_pg_defender.is_outline_visible(), "defender outline hidden", "")

	_reset_visual_test_state(smoke_coordinator, "RC")
	visual_pg = smoke_coordinator.get_offense_player_by_role("PG")
	visual_rc = smoke_coordinator.get_offense_player_by_role("RC")
	if visual_pg != null and visual_rc != null:
		_assert_true(not visual_pg.is_outline_visible() and visual_rc.is_outline_visible(), "outline follows controlled player", "%s %s" % [visual_pg.is_outline_visible(), visual_rc.is_outline_visible()])
		_assert_floor_marker_state(visual_pg, false, "previous ballhandler floor marker hides")
		_assert_floor_marker_state(visual_rc, true, "new ballhandler floor marker shows")

	_reset_visual_test_state(smoke_coordinator)
	visual_pg = smoke_coordinator.get_offense_player_by_role("PG")
	visual_rc = smoke_coordinator.get_offense_player_by_role("RC")
	visual_pg_defender = smoke_coordinator.get_defense_player_by_role("PG")
	if visual_rc != null:
		smoke_coordinator._sync_projection_visuals(0.0)
		_assert_player_visual(visual_rc, "no_ball_idle", 1, false, false, "off-ball idle")
	if visual_pg != null and visual_pg_defender != null:
		smoke_coordinator.player_visual_memory[visual_pg] = {"family": "ball_idle_open", "variant_index": 2, "mirror_west": false}
		visual_pg_defender.world_position += Vector2(-180.0, 60.0)
		smoke_coordinator._sync_projection_visuals(0.0)
		_assert_player_visual(visual_pg, "ball_idle_open", 11, false, true, "stationary open dribble")
		smoke_coordinator.player_visual_memory[visual_pg] = {"family": "ball_idle_pressured", "variant_index": 1, "mirror_west": false}
		visual_pg_defender.world_position = visual_pg.world_position + Vector2(-24.0, 12.0)
		smoke_coordinator._sync_projection_visuals(0.0)
		_assert_player_visual(visual_pg, "ball_idle_pressured", 7, false, true, "pressured dribble idle")
		smoke_coordinator.current_move_direction = Vector2.RIGHT
		smoke_coordinator.current_move_magnitude = 0.6
		visual_pg.velocity = Vector2.RIGHT * 82.0
		smoke_coordinator._sync_projection_visuals(0.0)
		_assert_player_visual(visual_pg, "ball_move_small", 12, false, true, "slow dribble move")
		smoke_coordinator.current_move_direction = Vector2.LEFT
		smoke_coordinator.current_move_magnitude = 1.0
		visual_pg.velocity = Vector2.LEFT * 180.0
		smoke_coordinator._sync_projection_visuals(0.0)
		_assert_player_visual(visual_pg, "ball_move_run", 9, true, true, "run dribble west")
		smoke_coordinator.current_move_direction = Vector2.ZERO
		smoke_coordinator.current_move_magnitude = 0.0
		if visual_rc != null:
			visual_rc.velocity = Vector2.RIGHT * 140.0
			smoke_coordinator._sync_projection_visuals(0.0)
			_assert_player_visual(visual_rc, "off_ball_run", 20, false, false, "off-ball run")
			smoke_coordinator.player_visual_memory[visual_rc] = {"family": "no_ball_idle", "variant_index": 0, "mirror_west": false}
			visual_rc.velocity = Vector2.RIGHT * (smoke_coordinator.player_animation_config.stationary_speed_threshold - 2.0)
			smoke_coordinator._sync_projection_visuals(0.0)
			_assert_player_visual(visual_rc, "no_ball_idle", 1, false, false, "off-ball idle holds below move enter")
			smoke_coordinator.player_visual_memory[visual_rc] = {"family": "off_ball_run", "variant_index": 0, "mirror_west": false}
			visual_rc.velocity = Vector2.RIGHT * (smoke_coordinator.player_animation_config.stationary_speed_release_threshold + 2.0)
			smoke_coordinator._sync_projection_visuals(0.0)
			_assert_player_visual(visual_rc, "off_ball_run", 20, false, false, "off-ball run holds above move exit")
			smoke_coordinator.player_visual_memory[visual_rc] = {"family": "off_ball_run", "variant_index": 0, "mirror_west": false}
			visual_rc.velocity = Vector2.RIGHT * (smoke_coordinator.player_animation_config.stationary_speed_release_threshold - 1.0)
			smoke_coordinator._sync_projection_visuals(0.0)
			_assert_player_visual(visual_rc, "no_ball_idle", 1, false, false, "off-ball run releases to idle")
			smoke_coordinator.player_visual_memory[visual_rc] = {"family": "off_ball_run", "variant_index": 0, "mirror_west": false}
			visual_rc.velocity = Vector2(-12.0, -140.0)
			smoke_coordinator._sync_projection_visuals(0.0)
			_assert_player_visual(visual_rc, "off_ball_run", 20, false, false, "facing holds east through tiny west correction")
			smoke_coordinator.player_visual_memory[visual_rc] = {"family": "off_ball_run", "variant_index": 0, "mirror_west": true}
			visual_rc.velocity = Vector2(12.0, -140.0)
			smoke_coordinator._sync_projection_visuals(0.0)
			_assert_player_visual(visual_rc, "off_ball_run", 20, true, false, "facing holds west through tiny east correction")
			smoke_coordinator.player_visual_memory[visual_rc] = {"family": "off_ball_run", "variant_index": 0, "mirror_west": false}
			visual_rc.velocity = Vector2(-92.0, -140.0)
			smoke_coordinator._sync_projection_visuals(0.0)
			_assert_player_visual(visual_rc, "off_ball_run", 20, true, false, "facing flips only on strong west intent")
		var guard_target: Vector2 = smoke_coordinator._get_defender_guard_target(visual_pg_defender)
		smoke_coordinator.player_visual_memory[visual_pg_defender] = {"family": "guard_idle", "variant_index": 1, "mirror_west": false}
		visual_pg_defender.world_position = guard_target
		visual_pg_defender.velocity = Vector2.ZERO
		smoke_coordinator._sync_projection_visuals(0.0)
		_assert_player_visual(visual_pg_defender, "guard_idle", 21, false, false, "guard idle")
		smoke_coordinator.player_visual_memory[visual_pg_defender] = {"family": "guard_idle", "variant_index": 1, "mirror_west": false}
		visual_pg_defender.velocity = Vector2.RIGHT * (smoke_coordinator.player_animation_config.stationary_speed_threshold - 2.0)
		smoke_coordinator._sync_projection_visuals(0.0)
		_assert_player_visual(visual_pg_defender, "guard_idle", 21, false, false, "guard idle holds below shuffle enter")
		visual_pg_defender.velocity = Vector2.RIGHT * 44.0
		smoke_coordinator._sync_projection_visuals(0.0)
		_assert_player_visual(visual_pg_defender, "guard_shuffle", 19, false, false, "guard shuffle")
		smoke_coordinator.player_visual_memory[visual_pg_defender] = {"family": "guard_shuffle", "variant_index": 0, "mirror_west": false}
		visual_pg_defender.velocity = Vector2.RIGHT * (smoke_coordinator.player_animation_config.stationary_speed_release_threshold + 2.0)
		smoke_coordinator._sync_projection_visuals(0.0)
		_assert_player_visual(visual_pg_defender, "guard_shuffle", 19, false, false, "guard shuffle holds above idle exit")
		visual_pg_defender.world_position -= Vector2(120.0, 0.0)
		visual_pg_defender.velocity = Vector2.RIGHT * 180.0
		smoke_coordinator._sync_projection_visuals(0.0)
		_assert_player_visual(visual_pg_defender, "guard_run", 20, false, false, "guard run")
		smoke_coordinator.player_visual_memory[visual_pg_defender] = {"family": "guard_run", "variant_index": 0, "mirror_west": false}
		visual_pg_defender.velocity = Vector2.RIGHT * (smoke_coordinator.player_animation_config.small_move_speed_release_threshold + 4.0)
		smoke_coordinator._sync_projection_visuals(0.0)
		_assert_player_visual(visual_pg_defender, "guard_run", 20, false, false, "guard run holds above run exit")
		smoke_coordinator.player_visual_memory[visual_pg_defender] = {"family": "guard_shuffle", "variant_index": 0, "mirror_west": false}
		visual_pg_defender.velocity = Vector2.RIGHT * (smoke_coordinator.player_animation_config.small_move_speed_threshold - 4.0)
		smoke_coordinator._sync_projection_visuals(0.0)
		_assert_player_visual(visual_pg_defender, "guard_shuffle", 19, false, false, "guard shuffle holds below run enter")
		visual_pg.trigger_shot_pose(0.28)
		visual_pg.world_position = Vector2(520.0, 1360.0)
		visual_pg.velocity = Vector2.RIGHT * 120.0
		smoke_coordinator.current_move_direction = Vector2.RIGHT
		smoke_coordinator.current_move_magnitude = 1.0
		smoke_coordinator.player_visual_memory.erase(visual_pg)
		smoke_coordinator._sync_projection_visuals(0.0)
		var jumper_variant: int = visual_pg.get_debug_variant_index()
		var jumper_row: int = visual_pg.get_debug_row_index()
		_assert_true(visual_pg.get_debug_animation_family() == "jumper_release", "jumper release family", visual_pg.get_debug_animation_family())
		smoke_coordinator._sync_projection_visuals(0.1)
		_assert_true(visual_pg.get_debug_variant_index() == jumper_variant and visual_pg.get_debug_row_index() == jumper_row, "jumper release variant stays locked", "%s %s" % [visual_pg.get_debug_variant_index(), visual_pg.get_debug_row_index()])
		_reset_visual_test_state(smoke_coordinator)
		visual_pg = smoke_coordinator.get_offense_player_by_role("PG")
		if visual_pg != null:
			visual_pg.world_position = smoke_coordinator.court_config.hoop_position + Vector2(0.0, 170.0)
			visual_pg.trigger_shot_pose(0.28)
			smoke_coordinator.player_visual_memory.erase(visual_pg)
			smoke_coordinator._sync_projection_visuals(0.0)
			_assert_player_visual(visual_pg, "set_shot_release", 4, false, true, "near-rim set shot")
		_reset_visual_test_state(smoke_coordinator, "LC")
		var visual_lc_preview: PlayerController = smoke_coordinator.get_offense_player_by_role("LC")
		if visual_lc_preview != null:
			visual_lc_preview.world_position = smoke_coordinator.court_config.hoop_position + Vector2(20.0, 130.0)
			visual_lc_preview.velocity = (smoke_coordinator.court_config.hoop_position - visual_lc_preview.world_position).normalized() * 180.0
			smoke_coordinator.current_move_direction = (smoke_coordinator.court_config.hoop_position - visual_lc_preview.world_position).normalized()
			smoke_coordinator.current_move_magnitude = 1.0
			visual_lc_preview.trigger_shot_pose(0.28)
			smoke_coordinator.player_visual_memory.erase(visual_lc_preview)
			smoke_coordinator._sync_projection_visuals(0.0)
			_assert_player_visual(visual_lc_preview, "close_finish_dunk", 15, true, true, "straight dunk")
			visual_lc_preview.world_position = smoke_coordinator.court_config.hoop_position + Vector2(80.0, 80.0)
			visual_lc_preview.velocity = (smoke_coordinator.court_config.hoop_position - visual_lc_preview.world_position).normalized() * 190.0
			smoke_coordinator.current_move_direction = (smoke_coordinator.court_config.hoop_position - visual_lc_preview.world_position).normalized()
			smoke_coordinator.current_move_magnitude = 1.0
			visual_lc_preview.trigger_shot_pose(0.28)
			smoke_coordinator.player_visual_memory.erase(visual_lc_preview)
			smoke_coordinator._sync_projection_visuals(0.0)
			_assert_player_visual(visual_lc_preview, "close_finish_side_dunk", 16, true, true, "side dunk")
		_reset_visual_test_state(smoke_coordinator)
		visual_pg = smoke_coordinator.get_offense_player_by_role("PG")
		visual_pg_defender = smoke_coordinator.get_defense_player_by_role("PG")
		if visual_pg != null and visual_pg_defender != null:
			visual_pg.world_position = Vector2(520.0, 1360.0)
			visual_pg.velocity = Vector2.ZERO
			visual_pg_defender.world_position = visual_pg.world_position + Vector2(-220.0, -16.0)
			visual_pg.shot_pose_timer = 0.0
			visual_pg.catch_pose_timer = 0.0
			visual_pg.jump_pose_timer = 0.0
			visual_pg_defender.shot_pose_timer = 0.0
			visual_pg_defender.catch_pose_timer = 0.0
			visual_pg_defender.jump_pose_timer = 0.0
			smoke_coordinator.player_visual_memory.erase(visual_pg)
			smoke_coordinator.current_move_direction = Vector2.ZERO
			smoke_coordinator.current_move_magnitude = 0.0
			_arm_test_shot(smoke_coordinator)
			for _aim_frame in 4:
				await get_tree().process_frame
			_assert_true(smoke_coordinator.context.current_state == GameState.State.SHOT_AIM, "shot stays in aim while windup plays", smoke_coordinator.get_state_name())
			_assert_true(not smoke_coordinator.ball_node.is_ball_visible(), "held ball hidden during synced shot aim", str(smoke_coordinator.ball_node.is_ball_visible()))
			_assert_true(bool(smoke_court_view.shot_meter.get("visible", false)), "shot meter visible during synced shot aim", JSON.stringify(smoke_court_view.shot_meter))
			_assert_player_visual(visual_pg, "set_shot_release", 4, false, true, "set shot windup starts early")
			var windup_frame_before_release: int = visual_pg.get_debug_frame_number()
			var windup_meter_before_release: Dictionary = smoke_court_view.shot_meter.duplicate(true)
			_tap_test_meter(smoke_coordinator)
			await get_tree().process_frame
			_assert_true(smoke_coordinator.context.current_state == GameState.State.SHOT_RELEASE, "manual early release enters shot release", smoke_coordinator.get_state_name())
			_assert_true(visual_pg.get_debug_frame_number() >= windup_frame_before_release, "shot release continues without restarting animation", "%d %d" % [visual_pg.get_debug_frame_number(), windup_frame_before_release])
			_assert_release_profile(visual_pg, 5, "set shot")
			_assert_true(not smoke_coordinator.ball_node.is_ball_visible(), "ball remains hidden before authored release frame", str(smoke_coordinator.ball_node.is_ball_visible()))
			_assert_true(not bool(smoke_court_view.shot_meter.get("visible", false)), "meter hides after timing tap", JSON.stringify(smoke_court_view.shot_meter))
			var early_release_seen: bool = false
			var first_launch_tracking_error: float = INF
			for _release_frame in 90:
				await get_tree().process_frame
				if smoke_coordinator.context.current_state == GameState.State.SHOT_RELEASE:
					_assert_true(not smoke_coordinator.ball_node.is_ball_visible(), "ball stays hidden while the windup finishes", str(smoke_coordinator.ball_node.is_ball_visible()))
					_assert_true(not bool(smoke_court_view.shot_meter.get("visible", false)), "meter stays hidden through release followthrough", JSON.stringify(smoke_court_view.shot_meter))
				elif smoke_coordinator.context.current_state == GameState.State.SHOT_IN_FLIGHT:
					early_release_seen = true
					var launch_ball_anchor: Vector2 = smoke_coordinator.ball_node.global_position + smoke_coordinator.ball_node.ball_screen_offset
					first_launch_tracking_error = launch_ball_anchor.distance_to(smoke_viewport_center)
					break
			_assert_true(early_release_seen, "shot launches only after the authored release frame", smoke_coordinator.get_state_name())
			_assert_true(smoke_coordinator.ball_node.is_ball_visible(), "ball becomes visible at release", str(smoke_coordinator.ball_node.is_ball_visible()))
			_assert_true(first_launch_tracking_error < 120.0, "camera follows the ball on the first launch frame", str(first_launch_tracking_error))
			_assert_true(not bool(smoke_court_view.shot_meter.get("visible", false)), "meter stays hidden after launch", JSON.stringify(smoke_court_view.shot_meter))
			_assert_true(float(smoke_court_view.shot_meter.get("progress", 0.0)) <= 0.001, "meter progress resets once timing closes", "%0.3f" % float(smoke_court_view.shot_meter.get("progress", 0.0)))
			var launched_ball_tracking_error: float = 0.0
			for _tracking_frame in 6:
				if smoke_coordinator.context.current_state != GameState.State.SHOT_IN_FLIGHT:
					break
				var tracked_launch_ball_anchor: Vector2 = smoke_coordinator.ball_node.global_position + smoke_coordinator.ball_node.ball_screen_offset
				launched_ball_tracking_error = maxf(launched_ball_tracking_error, tracked_launch_ball_anchor.distance_to(smoke_viewport_center))
				await get_tree().process_frame
			_assert_true(launched_ball_tracking_error < 180.0, "camera keeps the launched ball near center", str(launched_ball_tracking_error))
		_reset_visual_test_state(smoke_coordinator)
		visual_pg_defender = smoke_coordinator.get_defense_player_by_role("PG")
		if visual_pg_defender != null:
			visual_pg_defender.trigger_jump_pose(0.22)
			smoke_coordinator._sync_projection_visuals(0.0)
			_assert_player_visual(visual_pg_defender, "jump_contest", 22, false, false, "jump contest")
		_reset_visual_test_state(smoke_coordinator)
		visual_pg = smoke_coordinator.get_offense_player_by_role("PG")
		visual_pg_defender = smoke_coordinator.get_defense_player_by_role("PG")
		if visual_pg != null and visual_pg_defender != null:
			visual_pg.world_position = Vector2(520.0, 1360.0)
			visual_pg.velocity = Vector2.ZERO
			visual_pg_defender.world_position = visual_pg.world_position + Vector2(-220.0, -16.0)
			await _begin_release_test_shot(smoke_coordinator, visual_pg)
			_assert_true(smoke_coordinator.context.current_state == GameState.State.SHOT_RELEASE, "shot enters shot release state", smoke_coordinator.get_state_name())
			_assert_player_visual(visual_pg, "set_shot_release", 4, false, true, "set shot release")
			_assert_true(visual_pg.get_debug_release_after_frame() == 5, "set shot release frame metadata", str(visual_pg.get_debug_release_after_frame()))
			_assert_true(not smoke_coordinator.ball_node.is_ball_visible(), "ball hidden during shot release", str(smoke_coordinator.ball_node.is_ball_visible()))
			var set_release_frame_seen: int = -1
			for _set_frame in 90:
				await get_tree().process_frame
				if smoke_coordinator.context.current_state == GameState.State.SHOT_RELEASE:
					_assert_true(not smoke_coordinator.ball_node.is_ball_visible(), "set shot keeps ball hidden before release", str(smoke_coordinator.ball_node.is_ball_visible()))
				elif smoke_coordinator.context.current_state == GameState.State.SHOT_IN_FLIGHT:
					set_release_frame_seen = visual_pg.get_debug_frame_number()
					break
			_assert_true(set_release_frame_seen > visual_pg.get_debug_release_after_frame(), "set shot launches after release frame", "%d %d" % [set_release_frame_seen, visual_pg.get_debug_release_after_frame()])
			_assert_true(smoke_coordinator.ball_node.is_ball_visible(), "ball visible after staged shot release", str(smoke_coordinator.ball_node.is_ball_visible()))

		var jumper_row_seed_a: int = -1
		_reset_visual_test_state(smoke_coordinator, "PG", 2411)
		visual_pg = smoke_coordinator.get_offense_player_by_role("PG")
		visual_pg_defender = smoke_coordinator.get_defense_player_by_role("PG")
		if visual_pg != null and visual_pg_defender != null:
			visual_pg.world_position = Vector2(760.0, 1360.0)
			visual_pg.velocity = Vector2.LEFT * 220.0
			visual_pg_defender.world_position = visual_pg.world_position + Vector2(-24.0, 8.0)
			smoke_coordinator.current_move_direction = Vector2.LEFT
			smoke_coordinator.current_move_magnitude = 1.0
			await _begin_release_test_shot(smoke_coordinator, visual_pg)
			jumper_row_seed_a = visual_pg.get_debug_row_index()
			_assert_true(visual_pg.get_debug_animation_family() == "jumper_release", "jumper family when set shot is denied", visual_pg.get_debug_animation_family())
			_assert_true(jumper_row_seed_a == 8, "moving jumper uses row 8", str(jumper_row_seed_a))
			_assert_true(visual_pg.get_debug_flip_h(), "jumper mirrors west when hoop is left", str(visual_pg.get_debug_flip_h()))
			_assert_release_profile(visual_pg, 11, "moving jumper")
			var locked_flip: bool = visual_pg.get_debug_flip_h()
			for _jumper_lock_frame in 8:
				await get_tree().process_frame
				if smoke_coordinator.context.current_state != GameState.State.SHOT_RELEASE:
					break
				_assert_true(not smoke_coordinator.ball_node.is_ball_visible(), "jumper keeps ball hidden before release", str(smoke_coordinator.ball_node.is_ball_visible()))
				_assert_true(visual_pg.get_debug_flip_h() == locked_flip, "jumper west mirror stays locked", str(visual_pg.get_debug_flip_h()))
		var stationary_jumper_found: bool = false
		for stationary_seed in [2412, 2413, 2414, 2415, 2416, 2417, 2418]:
			_reset_visual_test_state(smoke_coordinator, "PG", stationary_seed)
			visual_pg = smoke_coordinator.get_offense_player_by_role("PG")
			visual_pg_defender = smoke_coordinator.get_defense_player_by_role("PG")
			if visual_pg == null or visual_pg_defender == null:
				continue
			visual_pg.world_position = Vector2(760.0, 1360.0)
			visual_pg.velocity = Vector2.ZERO
			visual_pg_defender.world_position = visual_pg.world_position + Vector2(-24.0, 8.0)
			await _begin_release_test_shot(smoke_coordinator, visual_pg)
			if visual_pg.get_debug_row_index() == 10:
				stationary_jumper_found = true
				_assert_release_profile(visual_pg, 23, "stationary jumper")
				break
		_assert_true(stationary_jumper_found, "stationary jumper can use row 10", "")

		_reset_visual_test_state(smoke_coordinator, "PG", 2420)
		visual_pg = smoke_coordinator.get_offense_player_by_role("PG")
		visual_pg_defender = smoke_coordinator.get_defense_player_by_role("PG")
		if visual_pg != null and visual_pg_defender != null:
			visual_pg.world_position = smoke_coordinator.court_config.hoop_position + Vector2(18.0, 170.0)
			visual_pg.velocity = (smoke_coordinator.court_config.hoop_position - visual_pg.world_position).normalized() * 150.0
			await _begin_release_test_shot(smoke_coordinator, visual_pg)
			_assert_player_visual(visual_pg, "close_finish_layup", 14, false, true, "straight layup release")
			_assert_release_profile(visual_pg, 9, "straight layup")
		_reset_visual_test_state(smoke_coordinator, "PG", 2421)
		visual_pg = smoke_coordinator.get_offense_player_by_role("PG")
		visual_pg_defender = smoke_coordinator.get_defense_player_by_role("PG")
		if visual_pg != null and visual_pg_defender != null:
			visual_pg.world_position = smoke_coordinator.court_config.hoop_position + Vector2(86.0, 164.0)
			visual_pg.velocity = (smoke_coordinator.court_config.hoop_position - visual_pg.world_position).normalized() * 150.0
			await _begin_release_test_shot(smoke_coordinator, visual_pg)
			_assert_player_visual(visual_pg, "close_finish_layup", 17, true, true, "side layup release")
			_assert_release_profile(visual_pg, 11, "side layup")
		_reset_visual_test_state(smoke_coordinator, "PG", 2422)
		visual_pg = smoke_coordinator.get_offense_player_by_role("PG")
		if visual_pg != null:
			visual_pg.world_position = smoke_coordinator.court_config.hoop_position + Vector2(22.0, 118.0)
			visual_pg.velocity = (smoke_coordinator.court_config.hoop_position - visual_pg.world_position).normalized() * 190.0
			await _begin_release_test_shot(smoke_coordinator, visual_pg)
			_assert_player_visual(visual_pg, "close_finish_layup", 14, true, true, "low dunk rating falls back to layup")
			_assert_release_profile(visual_pg, 9, "low dunk straight layup")
		_reset_visual_test_state(smoke_coordinator, "LC", 2423)
		var visual_lc: PlayerController = smoke_coordinator.get_offense_player_by_role("LC")
		if visual_lc != null:
			visual_lc.world_position = smoke_coordinator.court_config.hoop_position + Vector2(22.0, 118.0)
			visual_lc.velocity = (smoke_coordinator.court_config.hoop_position - visual_lc.world_position).normalized() * 80.0
			await _begin_release_test_shot(smoke_coordinator, visual_lc)
			_assert_player_visual(visual_lc, "close_finish_layup", 14, true, true, "insufficient dunk speed falls back to layup")
			_assert_release_profile(visual_lc, 9, "slow straight layup")
		_reset_visual_test_state(smoke_coordinator, "LC", 2424)
		visual_lc = smoke_coordinator.get_offense_player_by_role("LC")
		if visual_lc != null:
			visual_lc.world_position = smoke_coordinator.court_config.hoop_position + Vector2(22.0, 118.0)
			var dunk_motion: Vector2 = (smoke_coordinator.court_config.hoop_position - visual_lc.world_position).normalized() * 190.0
			var far_defender_finish: Dictionary = smoke_coordinator._build_shot_release_visual_decision(visual_lc, dunk_motion, 260.0)
			var near_defender_finish: Dictionary = smoke_coordinator._build_shot_release_visual_decision(visual_lc, dunk_motion, 12.0)
			_assert_true(str(far_defender_finish.get("family", "")) == "close_finish_dunk", "high dunk player in dunk radius chooses dunk", JSON.stringify(far_defender_finish))
			_assert_true(bool(far_defender_finish.get("close_finish_eligible", false)), "high dunk player is close-finish eligible", JSON.stringify(far_defender_finish))
			_assert_true(bool(far_defender_finish.get("dunk_eligible", false)), "high dunk player is dunk eligible", JSON.stringify(far_defender_finish))
			_assert_true(str(near_defender_finish.get("family", "")) == str(far_defender_finish.get("family", "")), "defender distance does not change selected finish family", "%s %s" % [JSON.stringify(far_defender_finish), JSON.stringify(near_defender_finish)])

		var straight_dunk_profiles: Dictionary = {}
		for straight_dunk_seed in [2425, 2426, 2427, 2428, 2429, 2430, 2431, 2432, 2433, 2434]:
			_reset_visual_test_state(smoke_coordinator, "LC", straight_dunk_seed)
			visual_lc = smoke_coordinator.get_offense_player_by_role("LC")
			if visual_lc != null:
				visual_lc.world_position = smoke_coordinator.court_config.hoop_position + Vector2(22.0, 118.0)
				visual_lc.velocity = (smoke_coordinator.court_config.hoop_position - visual_lc.world_position).normalized() * 190.0
				await _begin_release_test_shot(smoke_coordinator, visual_lc)
				var committed_family: String = str(smoke_coordinator.active_shot_sequence.get("family", ""))
				var committed_variant: int = int(smoke_coordinator.active_shot_sequence.get("variant_index", 0))
				var committed_row: int = PlayerVisual.get_row_index_for_family_variant(committed_family, committed_variant)
				var committed_profile: Dictionary = smoke_coordinator.active_shot_sequence.get("timing_profile", {})
				straight_dunk_profiles[committed_row] = int(committed_profile.get("release_after_frame", -1))
				_assert_true(committed_family == "close_finish_dunk", "straight dunk family", committed_family)
				if straight_dunk_profiles.has(13) and straight_dunk_profiles.has(15):
					break
		_assert_true(straight_dunk_profiles.has(13), "straight dunk row 13 timing profile reachable", str(straight_dunk_profiles))
		_assert_true(straight_dunk_profiles.has(15), "straight dunk row 15 timing profile reachable", str(straight_dunk_profiles))
		_assert_true(int(straight_dunk_profiles[13]) == 10, "straight dunk row 13 release frame", str(straight_dunk_profiles[13]))
		_assert_true(int(straight_dunk_profiles[15]) == 11, "straight dunk row 15 release frame", str(straight_dunk_profiles[15]))
		_reset_visual_test_state(smoke_coordinator, "LC", 2426)
		visual_lc = smoke_coordinator.get_offense_player_by_role("LC")
		if visual_lc != null:
			visual_lc.world_position = smoke_coordinator.court_config.hoop_position + Vector2(90.0, 80.0)
			visual_lc.velocity = (smoke_coordinator.court_config.hoop_position - visual_lc.world_position).normalized() * 190.0
			await _begin_release_test_shot(smoke_coordinator, visual_lc)
			var side_dunk_family: String = str(smoke_coordinator.active_shot_sequence.get("family", ""))
			var side_dunk_variant: int = int(smoke_coordinator.active_shot_sequence.get("variant_index", 0))
			var side_dunk_row: int = PlayerVisual.get_row_index_for_family_variant(side_dunk_family, side_dunk_variant)
			var side_dunk_timing_profile: Dictionary = smoke_coordinator.active_shot_sequence.get("timing_profile", {})
			_assert_true(side_dunk_family == "close_finish_side_dunk", "side dunk family", side_dunk_family)
			_assert_true(side_dunk_row == 16, "side dunk row", str(side_dunk_row))
			_assert_true(bool(smoke_coordinator.active_shot_sequence.get("mirror_west", false)), "side dunk flip", str(smoke_coordinator.active_shot_sequence.get("mirror_west", false)))
			_assert_true(int(side_dunk_timing_profile.get("release_after_frame", -1)) == 11, "side dunk release frame", str(side_dunk_timing_profile.get("release_after_frame", -1)))
		await _assert_dunk_hold_anchor_consistency(smoke_coordinator, 13, "LC", [2425, 2426, 2427, 2428, 2429, 2430, 2431, 2432, 2433, 2434], [Vector2(22.0, 118.0), Vector2(28.0, 126.0)], "row 13 dunk hold")
		await _assert_dunk_hold_anchor_consistency(smoke_coordinator, 15, "LC", [2425, 2426, 2427, 2428, 2429, 2430, 2431, 2432, 2433, 2434], [Vector2(22.0, 118.0), Vector2(28.0, 126.0)], "row 15 dunk hold")
		await _assert_dunk_hold_anchor_consistency(smoke_coordinator, 16, "LC", [2426, 2427, 2428], [Vector2(90.0, 80.0), Vector2(104.0, 92.0)], "row 16 dunk hold")
		_reset_visual_test_state(smoke_coordinator, "LC", 2426)
		visual_lc = smoke_coordinator.get_offense_player_by_role("LC")
		if visual_lc != null:
			visual_lc.world_position = smoke_coordinator.court_config.hoop_position + Vector2(90.0, 80.0)
			visual_lc.velocity = (smoke_coordinator.court_config.hoop_position - visual_lc.world_position).normalized() * 190.0
			_arm_test_shot(smoke_coordinator)
			await get_tree().process_frame
			_assert_true(smoke_coordinator.context.current_state == GameState.State.SHOT_RELEASE, "side dunk skips shot aim and stages release immediately", smoke_coordinator.get_state_name())
			_assert_true(not bool(smoke_court_view.shot_meter.get("visible", false)), "side dunk never shows the shot meter", JSON.stringify(smoke_court_view.shot_meter))
			var side_dunk_auto_action: Dictionary = smoke_coordinator.pending_shot_release.get("action", {})
			_assert_true(str(side_dunk_auto_action.get("timing_result", "")) == "dunk_auto_make", "side dunk uses auto-make timing instead of green tap timing", JSON.stringify(side_dunk_auto_action))
			var dunk_make_hold_frames: int = 0
			var dunk_make_hold_started: bool = false
			var dunk_make_launch_seen: bool = false
			var dunk_make_release_phase: String = ""
			var dunk_make_release_mode: String = ""
			for _dunk_make_frame in 180:
				await get_tree().process_frame
				if smoke_coordinator.context.current_state == GameState.State.SHOT_RELEASE:
					_assert_true(not smoke_coordinator.ball_node.is_ball_visible(), "dunk make keeps ball hidden during contact hold", str(smoke_coordinator.ball_node.is_ball_visible()))
					if visual_lc.is_dunk_contact_hold_active():
						dunk_make_hold_started = true
						dunk_make_hold_frames += 1
				elif smoke_coordinator.context.current_state == GameState.State.SHOT_IN_FLIGHT:
					dunk_make_launch_seen = true
					dunk_make_release_phase = smoke_coordinator.ball_simulator.get_flight_phase()
					dunk_make_release_mode = str(smoke_coordinator.ball_simulator.shot_profile.get("release_mode", ""))
					break
			_assert_true(dunk_make_hold_started, "dunk make enters the contact hold", "")
			_assert_true(dunk_make_hold_frames >= 28 and dunk_make_hold_frames <= 31, "dunk make holds on the rim for about half a second", str(dunk_make_hold_frames))
			_assert_true(dunk_make_launch_seen, "dunk make launches after the contact hold", smoke_coordinator.get_state_name())
			_assert_true(dunk_make_release_phase == BallSimulator.FLIGHT_PHASE_GUIDED_DESCENT, "dunk make starts in guided descent after release", dunk_make_release_phase)
			_assert_true(dunk_make_release_mode == ShotController.RELEASE_MODE_DUNK_MAKE_DROP, "dunk make uses straight-through release mode in smoke", dunk_make_release_mode)
			var dunk_make_peak_z: float = smoke_coordinator.ball_simulator.z
			for _dunk_make_follow_frame in 8:
				if smoke_coordinator.context.current_state != GameState.State.SHOT_IN_FLIGHT:
					break
				dunk_make_peak_z = maxf(dunk_make_peak_z, smoke_coordinator.ball_simulator.z)
				await get_tree().process_frame
			_assert_true(dunk_make_peak_z <= smoke_coordinator.court_config.rim_height + 0.01, "dunk make never rises above the rim after release", str(dunk_make_peak_z))
		_reset_visual_test_state(smoke_coordinator, "LC", 2426)
		visual_lc = smoke_coordinator.get_offense_player_by_role("LC")
		if visual_lc != null:
			visual_lc.world_position = smoke_coordinator.court_config.hoop_position + Vector2(22.0, 118.0)
			visual_lc.velocity = (smoke_coordinator.court_config.hoop_position - visual_lc.world_position).normalized() * 190.0
			_arm_test_shot(smoke_coordinator)
			await get_tree().process_frame
			_assert_true(smoke_coordinator.context.current_state == GameState.State.SHOT_RELEASE, "straight dunk also skips shot aim and stages release immediately", smoke_coordinator.get_state_name())
			_assert_true(not bool(smoke_court_view.shot_meter.get("visible", false)), "straight dunk never shows the shot meter", JSON.stringify(smoke_court_view.shot_meter))
			var straight_dunk_auto_action: Dictionary = smoke_coordinator.pending_shot_release.get("action", {})
			_assert_true(str(straight_dunk_auto_action.get("timing_result", "")) == "dunk_auto_make", "straight dunk uses auto-make timing instead of green tap timing", JSON.stringify(straight_dunk_auto_action))
			_assert_true(str(straight_dunk_auto_action.get("release_mode", "")) == ShotController.RELEASE_MODE_DUNK_MAKE_DROP, "straight dunk queues the make-drop release mode before launch", JSON.stringify(straight_dunk_auto_action))
			var straight_dunk_hold_started: bool = false
			var straight_dunk_launch_seen: bool = false
			var straight_dunk_release_mode: String = ""
			for _straight_dunk_frame in 180:
				await get_tree().process_frame
				if smoke_coordinator.context.current_state == GameState.State.SHOT_RELEASE:
					_assert_true(not smoke_coordinator.ball_node.is_ball_visible(), "straight dunk keeps ball hidden during contact hold", str(smoke_coordinator.ball_node.is_ball_visible()))
					if visual_lc.is_dunk_contact_hold_active():
						straight_dunk_hold_started = true
				elif smoke_coordinator.context.current_state == GameState.State.SHOT_IN_FLIGHT:
					straight_dunk_launch_seen = true
					straight_dunk_release_mode = str(smoke_coordinator.ball_simulator.shot_profile.get("release_mode", ""))
					break
			_assert_true(straight_dunk_hold_started, "straight dunk still uses the contact hold before release", "")
			_assert_true(straight_dunk_launch_seen, "straight dunk launches after the contact hold", smoke_coordinator.get_state_name())
			_assert_true(straight_dunk_release_mode == ShotController.RELEASE_MODE_DUNK_MAKE_DROP, "straight dunk keeps the make-drop release mode in smoke", straight_dunk_release_mode)
			var straight_dunk_peak_z: float = smoke_coordinator.ball_simulator.z
			for _straight_dunk_follow_frame in 8:
				if smoke_coordinator.context.current_state != GameState.State.SHOT_IN_FLIGHT:
					break
				straight_dunk_peak_z = maxf(straight_dunk_peak_z, smoke_coordinator.ball_simulator.z)
				await get_tree().process_frame
			_assert_true(straight_dunk_peak_z <= smoke_coordinator.court_config.rim_height + 0.01, "straight dunk never rises above the rim after release", str(straight_dunk_peak_z))
		_reset_visual_test_state(smoke_coordinator, "LC", 2426)
		visual_lc = smoke_coordinator.get_offense_player_by_role("LC")
		var visual_lc_defender: PlayerController = smoke_coordinator.get_defense_player_by_role("LC")
		if visual_lc != null and visual_lc_defender != null:
			visual_lc.world_position = smoke_coordinator.court_config.hoop_position + Vector2(90.0, 80.0)
			visual_lc.velocity = (smoke_coordinator.court_config.hoop_position - visual_lc.world_position).normalized() * 190.0
			smoke_coordinator.current_move_direction = (smoke_coordinator.court_config.hoop_position - visual_lc.world_position).normalized()
			smoke_coordinator.current_move_magnitude = 1.0
			smoke_coordinator._begin_active_shot_sequence(visual_lc)
			var blocked_dunk_action: Dictionary = smoke_coordinator.shot_controller.build_action_for_quality(
				visual_lc.world_position,
				visual_lc.get_player_data(),
				"red",
				smoke_coordinator.rng,
				"red",
				false,
				"close_finish_side_dunk",
				true
			)
			smoke_coordinator._queue_shot_release(blocked_dunk_action, visual_lc_defender)
			_assert_true(not bool(smoke_coordinator.pending_shot_release.get("use_dunk_contact_hold", true)), "blocked dunk bypasses the contact hold", JSON.stringify(smoke_coordinator.pending_shot_release))

		_reset_visual_test_state(smoke_coordinator, "PG", 2428)
		visual_pg = smoke_coordinator.get_offense_player_by_role("PG")
		visual_pg_defender = smoke_coordinator.get_defense_player_by_role("PG")
		if visual_pg != null and visual_pg_defender != null:
			visual_pg.world_position = Vector2(760.0, 1360.0)
			visual_pg.velocity = Vector2.ZERO
			visual_pg_defender.world_position = visual_pg.world_position + Vector2(-220.0, -16.0)
			_arm_test_shot(smoke_coordinator)
			var overhold_auto_release_seen: bool = false
			var overhold_release_frame_seen: int = -1
			var overhold_resolved: bool = false
			for _overhold_frame in 150:
				await get_tree().process_frame
				if smoke_coordinator.context.current_state == GameState.State.SHOT_AIM:
					_assert_true(bool(smoke_court_view.shot_meter.get("visible", false)), "meter stays visible while overholding", JSON.stringify(smoke_court_view.shot_meter))
				elif smoke_coordinator.context.current_state == GameState.State.SHOT_RELEASE:
					overhold_auto_release_seen = true
					if overhold_release_frame_seen == -1:
						overhold_release_frame_seen = visual_pg.get_debug_frame_number()
					_assert_true(not smoke_coordinator.ball_node.is_ball_visible(), "overhold keeps ball hidden before forced launch", str(smoke_coordinator.ball_node.is_ball_visible()))
				elif smoke_coordinator.context.current_state == GameState.State.SHOT_IN_FLIGHT:
					overhold_auto_release_seen = true
					overhold_release_frame_seen = visual_pg.get_debug_frame_number()
					break
				elif overhold_auto_release_seen:
					overhold_resolved = true
					break
			_assert_true(overhold_auto_release_seen, "overhold auto-releases on authored frame", smoke_coordinator.get_state_name())
			_assert_true(overhold_release_frame_seen >= visual_pg.get_debug_release_after_frame() and overhold_release_frame_seen <= visual_pg.get_debug_release_after_frame() + 1, "overhold launches at the authored release frame", "%d %d" % [overhold_release_frame_seen, visual_pg.get_debug_release_after_frame()])
			for _overhold_resolve_frame in 420:
				await get_tree().process_frame
				if smoke_coordinator.context.current_state != GameState.State.SHOT_RELEASE and smoke_coordinator.context.current_state != GameState.State.SHOT_IN_FLIGHT:
					overhold_resolved = true
					break
			_assert_true(overhold_resolved, "overhold shot fully resolves", smoke_coordinator.get_state_name())
			_assert_true(not smoke_coordinator.did_last_scored_shot_pass_through_net(), "overhold resolves as a miss", "")
			_assert_true(smoke_coordinator.context.home_score == 0, "overhold does not score", str(smoke_coordinator.context.home_score))

		_reset_visual_test_state(smoke_coordinator, "PG", 2424)
		smoke_coordinator.test_force_offensive_rebound("RC")
		_assert_true(not smoke_coordinator.ball_node.is_ball_visible(), "ball hidden on offensive rebound", str(smoke_coordinator.ball_node.is_ball_visible()))
		_reset_visual_test_state(smoke_coordinator, "PG", 2425)
		visual_pg_defender = smoke_coordinator.get_defense_player_by_role("PG")
		if visual_pg_defender != null:
			smoke_coordinator._begin_steal_resolve(visual_pg_defender)
			_assert_true(smoke_coordinator.context.current_state == GameState.State.STEAL_RESOLVE, "steal resolve state smoke", smoke_coordinator.get_state_name())
			_assert_true(not smoke_coordinator.ball_node.is_ball_visible(), "ball hidden in steal resolve", str(smoke_coordinator.ball_node.is_ball_visible()))

		_reset_visual_test_state(smoke_coordinator, "PG", 2426)
		visual_pg = smoke_coordinator.get_offense_player_by_role("PG")
		visual_pg_defender = smoke_coordinator.get_defense_player_by_role("PG")
		if visual_pg != null and visual_pg_defender != null:
			visual_pg.world_position = Vector2(520.0, 1360.0)
			visual_pg.velocity = Vector2.ZERO
			visual_pg_defender.world_position = visual_pg.world_position + Vector2(-16.0, 8.0)
			await _begin_release_test_shot(smoke_coordinator, visual_pg, 1)
			_assert_true(smoke_coordinator.context.current_state == GameState.State.SHOT_RELEASE, "blocked shot also stages release", smoke_coordinator.get_state_name())
			var blocked_wait_frames: int = int(ceili(maxf(float(visual_pg.get_current_shot_timing_profile().get("release_time_seconds", 0.0)), 0.5) * 60.0)) + 30
			for _blocked_frame in blocked_wait_frames:
				await get_tree().process_frame
				if smoke_coordinator.context.current_state != GameState.State.SHOT_RELEASE:
					break
			_assert_true(smoke_coordinator.context.current_state == GameState.State.REBOUND_LIVE, "blocked shot resolves directly to rebound", smoke_coordinator.get_state_name())
			_assert_true(not smoke_coordinator.ball_node.is_ball_visible(), "blocked shot never reveals world ball", str(smoke_coordinator.ball_node.is_ball_visible()))
			await get_tree().process_frame
			_assert_true(visual_pg_defender.get_debug_animation_family() == "jump_contest", "blocker uses jump contest family", visual_pg_defender.get_debug_animation_family())
			_assert_true(visual_pg_defender.get_debug_row_index() == 22, "blocker uses jump contest row", str(visual_pg_defender.get_debug_row_index()))
	game_root.queue_free()
	smooth_player.free()
	for player in players:
		player.free()
	defender.free()
	short_target.free()
	long_target.free()
	out_target.free()
	await get_tree().process_frame
	await _run_hoop_render_phase_smoke()


func _run_scenarios() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://data/scenarios")):
		return
	var runner: ScenarioRunner = ScenarioRunner.new()
	for file_name in DirAccess.get_files_at("res://data/scenarios"):
		if not file_name.ends_with(".tres"):
			continue
		var definition: ScenarioDefinition = load("res://data/scenarios/%s" % file_name)
		var result: Dictionary = await runner.run_scenario(get_tree(), definition)
		scenario_results.append(result)
		logger.log_test("[%s] scenario %s %s" % ["PASS" if result["passed"] else "FAIL", result["name"], result["detail"]])
		if not result["passed"]:
			total_failed += 1


func _run_balance() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://data/balance")):
		return
	var runner: BalanceRunner = BalanceRunner.new()
	for file_name in DirAccess.get_files_at("res://data/balance"):
		if not file_name.ends_with(".tres"):
			continue
		var definition: BalanceBatchDefinition = load("res://data/balance/%s" % file_name)
		var result: Dictionary = runner.run_batch(definition)
		result["name"] = result["batch_id"]
		balance_results.append(result)
		logger.log_test("[%s] balance %s %s" % ["PASS" if result["passed"] else "FAIL", result["batch_id"], result["detail"]])
		if not result["passed"]:
			total_failed += 1


func _assert_true(condition: bool, name: String, detail: String) -> void:
	var result: Dictionary = {"name": name, "passed": condition, "detail": detail}
	pure_logic_results.append(result)
	if not condition:
		total_failed += 1


func _make_visual_test_setup(ballhandler_role: String = "PG") -> Dictionary:
	return {
		"ballhandler_role": ballhandler_role,
		"defense_positions": {
			"LC": Vector2(300, 620),
			"LW": Vector2(300, 1060),
			"PG": Vector2(320, 1460),
			"RC": Vector2(830, 640),
			"RW": Vector2(800, 1060),
		},
		"offense_positions": {
			"LC": Vector2(260, 640),
			"LW": Vector2(360, 1040),
			"PG": Vector2(520, 1360),
			"RC": Vector2(620, 900),
			"RW": Vector2(740, 1100),
		},
	}


func _reset_visual_test_state(coordinator: GameCoordinator, ballhandler_role: String = "PG", seed: int = 2409) -> void:
	coordinator.begin_test_mode(seed)
	var setup: Dictionary = _make_visual_test_setup(ballhandler_role)
	setup["state"] = "LIVE_OFFENSE"
	coordinator.apply_scenario_setup(setup)
	coordinator.apply_test_setup(0, 0, coordinator.game_config.match_length_seconds)
	for player in coordinator.offense_players + coordinator.defense_players:
		player.velocity = Vector2.ZERO
		player.shot_pose_timer = 0.0
		player.catch_pose_timer = 0.0
		player.jump_pose_timer = 0.0
	coordinator.current_move_direction = Vector2.ZERO
	coordinator.current_move_magnitude = 0.0
	coordinator.player_visual_memory.clear()
	coordinator._sync_projection_visuals(0.0)


func _assert_player_visual(
	player: PlayerController,
	expected_family: String,
	expected_row: int,
	expected_flip: bool,
	expected_outline: bool,
	name_prefix: String
) -> void:
	_assert_true(player.get_debug_animation_family() == expected_family, "%s family" % name_prefix, player.get_debug_animation_family())
	_assert_true(player.get_debug_row_index() == expected_row, "%s row" % name_prefix, str(player.get_debug_row_index()))
	_assert_true(player.get_debug_flip_h() == expected_flip, "%s flip" % name_prefix, str(player.get_debug_flip_h()))
	_assert_true(player.is_outline_visible() == expected_outline, "%s outline" % name_prefix, str(player.is_outline_visible()))


func _assert_floor_marker_state(player: PlayerController, expected_visible: bool, name_prefix: String) -> void:
	var snapshot: Dictionary = player.get_floor_marker_debug_snapshot()
	var center_local: Vector2 = snapshot.get("marker_center_local", Vector2.ZERO)
	var radii_local: Vector2 = snapshot.get("marker_radii_local", Vector2.ZERO)
	_assert_true(not bool(snapshot.get("shadow_enabled", true)), "%s shadow disabled" % name_prefix, str(snapshot))
	_assert_true(bool(snapshot.get("marker_visible", false)) == expected_visible, "%s visibility" % name_prefix, str(snapshot.get("marker_visible", false)))
	_assert_true(str(snapshot.get("marker_shape", "")) == "oval", "%s shape" % name_prefix, str(snapshot.get("marker_shape", "")))
	_assert_true(str(snapshot.get("marker_style", "")) == "outline", "%s style" % name_prefix, str(snapshot.get("marker_style", "")))
	_assert_true(center_local.distance_to(Vector2(0.0, 12.0)) < 0.001, "%s feet-centered marker offset" % name_prefix, str(center_local))
	_assert_true(radii_local.distance_to(Vector2(30.0, 14.0)) < 0.001, "%s marker radii" % name_prefix, str(radii_local))
	_assert_true(center_local.y > 0.0 and radii_local.x > radii_local.y, "%s uses horizontal oval under feet" % name_prefix, "%s %s" % [center_local, radii_local])


func _assert_release_profile(player: PlayerController, expected_release_after_frame: int, name_prefix: String, expected_fps: float = 15.0) -> void:
	_assert_true(player.get_debug_release_after_frame() == expected_release_after_frame, "%s release frame" % name_prefix, str(player.get_debug_release_after_frame()))
	var timing_profile: Dictionary = player.get_current_shot_timing_profile()
	var resolved_fps: float = float(timing_profile.get("fps", 0.0))
	_assert_true(absf(resolved_fps - expected_fps) < 0.001, "%s timing fps" % name_prefix, str(resolved_fps))
	_assert_true(absf(float(timing_profile.get("release_time_seconds", 0.0)) - float(expected_release_after_frame) / expected_fps) < 0.001, "%s release seconds" % name_prefix, str(timing_profile.get("release_time_seconds", 0.0)))
	var total_frames: int = int(timing_profile.get("total_frames", 0))
	_assert_true(absf(float(timing_profile.get("full_animation_duration_seconds", 0.0)) - float(total_frames) / expected_fps) < 0.001, "%s full duration seconds" % name_prefix, str(timing_profile.get("full_animation_duration_seconds", 0.0)))


func _collect_dunk_hold_snapshot(
	coordinator: GameCoordinator,
	ballhandler_role: String,
	seed: int,
	start_offset: Vector2
) -> Dictionary:
	_reset_visual_test_state(coordinator, ballhandler_role, seed)
	var shooter: PlayerController = coordinator.get_offense_player_by_role(ballhandler_role)
	if shooter == null:
		return {}
	var motion_vector: Vector2 = (coordinator.court_config.hoop_position - (coordinator.court_config.hoop_position + start_offset)).normalized() * 190.0
	shooter.world_position = coordinator.court_config.hoop_position + start_offset
	shooter.velocity = motion_vector
	coordinator.current_move_direction = motion_vector.normalized()
	coordinator.current_move_magnitude = 1.0
	_arm_test_shot(coordinator)
	for _frame in 180:
		await get_tree().process_frame
		if coordinator.context.current_state == GameState.State.SHOT_RELEASE and shooter.is_dunk_contact_hold_active():
			return {
				"row": shooter.get_debug_row_index(),
				"world_position": shooter.world_position,
				"ground_screen": shooter.global_position,
				"anchor_offset": shooter.world_position - coordinator.court_config.hoop_position,
			}
		if coordinator.context.current_state == GameState.State.SHOT_IN_FLIGHT:
			break
	return {}


func _assert_dunk_hold_anchor_consistency(
	coordinator: GameCoordinator,
	expected_row: int,
	ballhandler_role: String,
	seeds: Array,
	start_offsets: Array[Vector2],
	name_prefix: String
) -> void:
	var snapshots: Array[Dictionary] = []
	for start_offset in start_offsets:
		for seed in seeds:
			var snapshot: Dictionary = await _collect_dunk_hold_snapshot(coordinator, ballhandler_role, int(seed), start_offset)
			if snapshot.is_empty() or int(snapshot.get("row", -1)) != expected_row:
				continue
			snapshots.append(snapshot)
			if snapshots.size() >= 2:
				break
		if snapshots.size() >= 2:
			break
	_assert_true(snapshots.size() >= 2, "%s snapshots reachable" % name_prefix, JSON.stringify(snapshots))
	if snapshots.size() < 2:
		return
	var configured_anchor: Vector2 = coordinator.get_dunk_contact_anchor_offset_for_row(expected_row)
	var first_snapshot: Dictionary = snapshots[0]
	var first_world_position: Vector2 = first_snapshot.get("world_position", Vector2.INF)
	var first_ground_screen: Vector2 = first_snapshot.get("ground_screen", Vector2.INF)
	for snapshot in snapshots:
		var anchor_offset: Vector2 = snapshot.get("anchor_offset", Vector2.INF)
		var world_position: Vector2 = snapshot.get("world_position", Vector2.INF)
		var ground_screen: Vector2 = snapshot.get("ground_screen", Vector2.INF)
		_assert_true(int(snapshot.get("row", -1)) == expected_row, "%s row" % name_prefix, JSON.stringify(snapshot))
		_assert_true(anchor_offset.distance_to(configured_anchor) < 0.01, "%s snaps to configured anchor" % name_prefix, str(anchor_offset))
		_assert_true(world_position.distance_to(first_world_position) < 0.01, "%s world position stays deterministic" % name_prefix, "%s %s" % [world_position, first_world_position])
		_assert_true(ground_screen.distance_to(first_ground_screen) < 0.01, "%s screen anchor stays deterministic" % name_prefix, "%s %s" % [ground_screen, first_ground_screen])


func _begin_release_test_shot(coordinator: GameCoordinator, _shooter: PlayerController, aim_frames: int = 12) -> void:
	_arm_test_shot(coordinator)
	for _aim_frame in aim_frames:
		await get_tree().process_frame
	if coordinator.context.current_state == GameState.State.SHOT_AIM:
		_tap_test_meter(coordinator)
		await get_tree().process_frame


func _arm_test_shot(coordinator: GameCoordinator) -> void:
	if coordinator.input_controller == null:
		return
	var viewport_size: Vector2 = coordinator.get_viewport().get_visible_rect().size
	var swipe_start: Vector2 = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.88)
	var top_half_limit_y: float = viewport_size.y * float(coordinator.input_config.shot_swipe_max_release_y_ratio)
	var swipe_end: Vector2 = Vector2(swipe_start.x, minf(swipe_start.y - maxf(float(coordinator.input_config.shot_swipe_min_distance_pixels) + 48.0, 140.0), top_half_limit_y - 24.0))
	coordinator.input_controller.swipe_test_shot_arm(swipe_start, swipe_end, 0.12)


func _tap_test_meter(coordinator: GameCoordinator) -> void:
	if coordinator.input_controller == null:
		return
	var viewport_size: Vector2 = coordinator.get_viewport().get_visible_rect().size
	coordinator.input_controller.tap_test_shot_timing(Vector2(viewport_size.x * 0.5, viewport_size.y * 0.6))


func _run_hoop_render_phase_smoke() -> void:
	var game_root_scene: PackedScene = load("res://scenes/GameRoot.tscn")
	var game_root: Node2D = game_root_scene.instantiate() as Node2D
	add_child(game_root)
	await get_tree().process_frame
	await get_tree().process_frame
	var smoke_coordinator: GameCoordinator = game_root.get_node("GameCoordinator") as GameCoordinator
	_assert_true(smoke_coordinator != null, "through-net smoke coordinator exists", "")
	if smoke_coordinator == null:
		game_root.queue_free()
		await get_tree().process_frame
		return
	_assert_true(smoke_coordinator.has_method("get_ball_render_phase"), "ball render phase accessor exists", "")
	_assert_true(smoke_coordinator.has_method("did_last_scored_shot_pass_through_net"), "through-net score accessor exists", "")
	_assert_true(smoke_coordinator.has_method("get_net_swish_active"), "net swish accessor exists", "")
	if smoke_coordinator.hoop_node != null:
		if smoke_coordinator.hoop_node.has_method("supports_three_piece_visuals"):
			_assert_true(bool(smoke_coordinator.hoop_node.call("supports_three_piece_visuals")), "three-piece hoop visuals exist", "")
		var back_z: int = int(smoke_coordinator.hoop_node.call("get_ball_z_index_for_phase", "behind_backboard"))
		var rim_z: int = int(smoke_coordinator.hoop_node.call("get_ball_z_index_for_phase", "rim_mouth"))
		var channel_z: int = int(smoke_coordinator.hoop_node.call("get_ball_z_index_for_phase", "net_channel"))
		var front_z: int = int(smoke_coordinator.hoop_node.call("get_ball_z_index_for_phase", "front_of_net"))
		_assert_true(back_z < rim_z and rim_z < channel_z and channel_z < front_z, "hoop phase z-order increases frontward", "%d %d %d %d" % [back_z, rim_z, channel_z, front_z])
		if smoke_coordinator.hoop_node.has_method("is_net_swish_active"):
			_assert_true(not bool(smoke_coordinator.hoop_node.call("is_net_swish_active")), "net swish idle before score", "")
	smoke_coordinator.begin_test_mode(1708)
	smoke_coordinator.test_force_scoring_shot("RC", 2)
	var through_net: bool = false
	var score_seen: bool = false
	var score_phase: String = ""
	var swish_when_scored: bool = false
	var first_phase_frame: Dictionary = {}
	var front_after_net_frame: int = -1
	var score_z: float = INF
	for frame in 180:
		await get_tree().process_frame
		if smoke_coordinator.has_method("did_last_scored_shot_pass_through_net"):
			through_net = bool(smoke_coordinator.call("did_last_scored_shot_pass_through_net"))
		if smoke_coordinator.has_method("get_ball_render_phase"):
			var phase: String = str(smoke_coordinator.call("get_ball_render_phase"))
			if phase != "" and not first_phase_frame.has(phase):
				first_phase_frame[phase] = frame
			if phase == "front_of_net" and first_phase_frame.has("net_channel") and frame > int(first_phase_frame["net_channel"]) and front_after_net_frame == -1:
				front_after_net_frame = frame
			if smoke_coordinator.context.home_score > 0 and not score_seen:
				score_seen = true
				score_phase = phase
				score_z = smoke_coordinator.ball_simulator.z
				if smoke_coordinator.has_method("get_net_swish_active"):
					swish_when_scored = bool(smoke_coordinator.call("get_net_swish_active"))
		if score_seen and front_after_net_frame != -1:
			break
	_assert_true(first_phase_frame.has("net_channel"), "made shot enters net channel phase", str(first_phase_frame))
	_assert_true(front_after_net_frame != -1, "made shot emerges front of net", str(first_phase_frame))
	if first_phase_frame.has("rim_mouth") and first_phase_frame.has("net_channel"):
		_assert_true(int(first_phase_frame["rim_mouth"]) <= int(first_phase_frame["net_channel"]), "optional rim-mouth handoff occurs before net channel", str(first_phase_frame))
	if first_phase_frame.has("net_channel") and front_after_net_frame != -1:
		_assert_true(int(first_phase_frame["net_channel"]) < front_after_net_frame, "guided make phases stay ordered", str({"net_channel": first_phase_frame["net_channel"], "front_of_net": front_after_net_frame}))
	_assert_true(through_net, "made shot records through-net follow-through", "")
	_assert_true(score_seen, "made shot resolves during smoke test", "")
	_assert_true(score_phase == "net_channel", "scored frame occurs during guided descent", score_phase)
	_assert_true(score_z <= smoke_coordinator.court_config.rim_height + 0.01, "score cannot appear while ball is above rim", str(score_z))
	if smoke_coordinator.has_method("get_score_followthrough_active"):
		_assert_true(bool(smoke_coordinator.call("get_score_followthrough_active")) or score_phase == "front_of_net", "score follow-through activates after score", "")
	if smoke_coordinator.has_method("get_net_swish_active"):
		_assert_true(swish_when_scored, "net swish activates on score", "")
	game_root.queue_free()
	await get_tree().process_frame


func _max_preview_z(points: Array[Dictionary]) -> float:
	var max_z: float = 0.0
	for point in points:
		max_z = maxf(max_z, point["z"])
	return max_z


func _new_ball_simulator(config: BallPhysicsConfig) -> BallSimulator:
	var simulator: BallSimulator = BallSimulator.new()
	simulator.gravity = config.gravity
	simulator.ball_radius = config.ball_radius
	return simulator


func _launch_profiles_match(a: Dictionary, b: Dictionary, tolerance: float = 0.01) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	if str(a.get("profile_kind", "")) != str(b.get("profile_kind", "")):
		return false
	var matches: bool = a["launch_position"].distance_to(b["launch_position"]) <= tolerance \
		and a["target_xy"].distance_to(b["target_xy"]) <= tolerance \
		and a["velocity_xy"].distance_to(b["velocity_xy"]) <= tolerance \
		and absf(float(a["launch_z"]) - float(b["launch_z"])) <= tolerance \
		and absf(float(a["vz"]) - float(b["vz"])) <= tolerance \
		and absf(float(a["flight_time"]) - float(b["flight_time"])) <= tolerance
	if not matches:
		return false
	if str(a.get("profile_kind", "")) != ShotController.PROFILE_KIND_GUIDED_MAKE:
		return true
	return a["entry_xy"].distance_to(b["entry_xy"]) <= tolerance \
		and a["score_gate_xy"].distance_to(b["score_gate_xy"]) <= tolerance \
		and a["net_exit_xy"].distance_to(b["net_exit_xy"]) <= tolerance \
		and absf(float(a["entry_z"]) - float(b["entry_z"])) <= tolerance \
		and absf(float(a["entry_time"]) - float(b["entry_time"])) <= tolerance \
		and absf(float(a["descent_duration"]) - float(b["descent_duration"])) <= tolerance


func _rect_contains_rect(outer: Rect2, inner: Rect2, tolerance: float = 0.01) -> bool:
	if outer.size.x <= 0.0 or outer.size.y <= 0.0 or inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return false
	return inner.position.x >= outer.position.x - tolerance \
		and inner.position.y >= outer.position.y - tolerance \
		and inner.end.x <= outer.end.x + tolerance \
		and inner.end.y <= outer.end.y + tolerance


func _is_legal_score_sample(sample_pos: Vector2, court: CourtConfig) -> bool:
	if sample_pos.distance_to(court.hoop_position) > court.rim_inner_radius:
		return false
	return sample_pos.y >= court.hoop_position.y + court.score_entry_min_front_offset


func _simulate_pass_race(
	pass_controller: PassController,
	start_position: Vector2,
	target: PlayerController,
	defenders: Array[PlayerController],
	receiver_release_offset: Vector2 = Vector2.ZERO,
	receiver_speed_scale: float = 1.0,
	defender_speed_scale: float = 1.0,
	max_frames: int = 240,
	rng: GameRng = null,
	passer: PlayerController = null
) -> Dictionary:
	var start_snapshot: Dictionary = pass_controller.start_pass(start_position, target, defenders, rng, passer)
	var release_target: Vector2 = pass_controller.get_active_pass_snapshot().get("end", target.world_position)
	target.world_position = release_target + receiver_release_offset
	target.velocity = Vector2.ZERO
	for frame in max_frames:
		var snapshot: Dictionary = pass_controller.get_active_pass_snapshot()
		if snapshot.is_empty():
			break
		target.move_toward_target(release_target, receiver_speed_scale, 1.0 / 60.0)
		var interceptor: PlayerController = snapshot.get("active_interceptor", null) as PlayerController
		if interceptor != null:
			interceptor.move_toward_target(snapshot.get("chase_point", interceptor.world_position), defender_speed_scale, 1.0 / 60.0)
		var result: Dictionary = pass_controller.step_pass(1.0 / 60.0)
		if result.get("state", "") != "traveling":
			result["start_snapshot"] = start_snapshot
			return result
	return {"state": "traveling", "frames": max_frames, "start_snapshot": start_snapshot}


func _find_commit_seed(
	pass_controller: PassController,
	start_position: Vector2,
	target: PlayerController,
	defenders: Array[PlayerController],
	passer: PlayerController,
	min_seed: int = 1,
	max_seed: int = 128
) -> int:
	var rng: GameRng = GameRng.new()
	for seed in range(min_seed, max_seed + 1):
		rng.reseed(seed)
		var snapshot: Dictionary = pass_controller.start_pass(start_position, target, defenders, rng, passer)
		if bool(snapshot.get("commit_succeeded", false)):
			return seed
	return -1
