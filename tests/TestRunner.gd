class_name TestRunner
extends Node

const COURT_PROJECTION_SCRIPT = preload("res://scripts/game/CourtProjection.gd")
const MENU_BACKGROUND_SCRIPT: GDScript = preload("res://scripts/game/MenuBackground.gd")

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
	_assert_true(animation_config.dunk_run_end_frame_row_13 == 7, "row 13 run-end frame metadata", str(animation_config.dunk_run_end_frame_row_13))
	_assert_true(animation_config.dunk_run_end_frame_row_15 == 7, "row 15 run-end frame metadata", str(animation_config.dunk_run_end_frame_row_15))
	_assert_true(animation_config.dunk_run_end_frame_row_16 == 7, "row 16 run-end frame metadata", str(animation_config.dunk_run_end_frame_row_16))
	_assert_true(animation_config.dunk_jump_end_frame_row_13 == 9, "row 13 jump-end frame metadata", str(animation_config.dunk_jump_end_frame_row_13))
	_assert_true(animation_config.dunk_jump_end_frame_row_15 == 10, "row 15 jump-end frame metadata", str(animation_config.dunk_jump_end_frame_row_15))
	_assert_true(animation_config.dunk_jump_end_frame_row_16 == 10, "row 16 jump-end frame metadata", str(animation_config.dunk_jump_end_frame_row_16))
	_assert_true(animation_config.dunk_contact_end_frame_row_13 == 10, "row 13 contact-end frame metadata", str(animation_config.dunk_contact_end_frame_row_13))
	_assert_true(animation_config.dunk_contact_end_frame_row_15 == 11, "row 15 contact-end frame metadata", str(animation_config.dunk_contact_end_frame_row_15))
	_assert_true(animation_config.dunk_contact_end_frame_row_16 == 12, "row 16 contact-end frame metadata", str(animation_config.dunk_contact_end_frame_row_16))
	_assert_true(absf(animation_config.dunk_smart_start_short_distance - 90.0) < 0.001, "dunk smart short distance metadata", str(animation_config.dunk_smart_start_short_distance))
	_assert_true(absf(animation_config.dunk_smart_start_medium_distance - 120.0) < 0.001, "dunk smart medium distance metadata", str(animation_config.dunk_smart_start_medium_distance))
	_assert_true(absf(animation_config.dunk_contact_hold_seconds - 0.18) < 0.001, "dunk contact hold duration metadata", str(animation_config.dunk_contact_hold_seconds))
	_assert_true(animation_config.dunk_contact_anchor_offset_row_13_east.distance_to(Vector2(-20.0, 172.0)) < 0.001, "row 13 east contact anchor metadata", str(animation_config.dunk_contact_anchor_offset_row_13_east))
	_assert_true(animation_config.dunk_contact_anchor_offset_row_13_west.distance_to(Vector2(20.0, 172.0)) < 0.001, "row 13 west contact anchor metadata", str(animation_config.dunk_contact_anchor_offset_row_13_west))
	_assert_true(animation_config.dunk_contact_anchor_offset_row_15_east.distance_to(Vector2(-30.0, 162.0)) < 0.001, "row 15 east contact anchor metadata", str(animation_config.dunk_contact_anchor_offset_row_15_east))
	_assert_true(animation_config.dunk_contact_anchor_offset_row_15_west.distance_to(Vector2(30.0, 162.0)) < 0.001, "row 15 west contact anchor metadata", str(animation_config.dunk_contact_anchor_offset_row_15_west))
	_assert_true(animation_config.dunk_contact_anchor_offset_row_16_east.distance_to(Vector2(-42.0, 160.0)) < 0.001, "row 16 east contact anchor metadata", str(animation_config.dunk_contact_anchor_offset_row_16_east))
	_assert_true(animation_config.dunk_contact_anchor_offset_row_16_west.distance_to(Vector2(42.0, 160.0)) < 0.001, "row 16 west contact anchor metadata", str(animation_config.dunk_contact_anchor_offset_row_16_west))
	_assert_true(animation_config.dunk_landing_anchor_offset_row_13_east.distance_to(Vector2(-20.0, 268.0)) < 0.001, "row 13 east landing anchor metadata", str(animation_config.dunk_landing_anchor_offset_row_13_east))
	_assert_true(animation_config.dunk_landing_anchor_offset_row_13_west.distance_to(Vector2(20.0, 268.0)) < 0.001, "row 13 west landing anchor metadata", str(animation_config.dunk_landing_anchor_offset_row_13_west))
	_assert_true(animation_config.dunk_landing_anchor_offset_row_15_east.distance_to(Vector2(-30.0, 258.0)) < 0.001, "row 15 east landing anchor metadata", str(animation_config.dunk_landing_anchor_offset_row_15_east))
	_assert_true(animation_config.dunk_landing_anchor_offset_row_15_west.distance_to(Vector2(30.0, 258.0)) < 0.001, "row 15 west landing anchor metadata", str(animation_config.dunk_landing_anchor_offset_row_15_west))
	_assert_true(animation_config.dunk_landing_anchor_offset_row_16_east.distance_to(Vector2(-42.0, 256.0)) < 0.001, "row 16 east landing anchor metadata", str(animation_config.dunk_landing_anchor_offset_row_16_east))
	_assert_true(animation_config.dunk_landing_anchor_offset_row_16_west.distance_to(Vector2(42.0, 256.0)) < 0.001, "row 16 west landing anchor metadata", str(animation_config.dunk_landing_anchor_offset_row_16_west))
	_assert_true(animation_config.get_dunk_contact_anchor_offset(16, false).distance_to(Vector2(-42.0, 160.0)) < 0.001, "east-facing anchor lookup stays on authored east contact anchor", str(animation_config.get_dunk_contact_anchor_offset(16, false)))
	_assert_true(animation_config.get_dunk_contact_anchor_offset(16, true).distance_to(Vector2(42.0, 160.0)) < 0.001, "west-facing anchor lookup switches to authored west contact anchor", str(animation_config.get_dunk_contact_anchor_offset(16, true)))
	_assert_true(absf(animation_config.dunk_landing_ease_power - 1.8) < 0.001, "dunk landing ease metadata", str(animation_config.dunk_landing_ease_power))
	_assert_true(animation_config.get_dunk_jump_start_frame(13) == 8, "row 13 jump-start frame metadata", str(animation_config.get_dunk_jump_start_frame(13)))
	_assert_true(animation_config.get_dunk_medium_start_frame(13) == 5, "row 13 medium-start frame metadata", str(animation_config.get_dunk_medium_start_frame(13)))
	_assert_true(animation_config.get_dunk_approach_bucket(84.0) == "short", "dunk short bucket resolver", animation_config.get_dunk_approach_bucket(84.0))
	_assert_true(animation_config.get_dunk_approach_bucket(105.0) == "medium", "dunk medium bucket resolver", animation_config.get_dunk_approach_bucket(105.0))
	_assert_true(animation_config.get_dunk_approach_bucket(130.0) == "max", "dunk max bucket resolver", animation_config.get_dunk_approach_bucket(130.0))
	_assert_true(animation_config.resolve_dunk_approach_start_frame(13, 90.0) == 8, "dunk short distance resolves to jump start", str(animation_config.resolve_dunk_approach_start_frame(13, 90.0)))
	_assert_true(animation_config.resolve_dunk_approach_start_frame(13, 105.0) == 7, "dunk medium blend resolves later than frame 5", str(animation_config.resolve_dunk_approach_start_frame(13, 105.0)))
	_assert_true(animation_config.resolve_dunk_approach_start_frame(13, 120.0) == 5, "dunk medium edge resolves to frame 5", str(animation_config.resolve_dunk_approach_start_frame(13, 120.0)))
	_assert_true(animation_config.resolve_dunk_approach_start_frame(13, 127.5) == 3, "dunk max blend resolves earlier than frame 5", str(animation_config.resolve_dunk_approach_start_frame(13, 127.5)))
	_assert_true(animation_config.resolve_dunk_approach_start_frame(13, animation_config.dunk_finish_radius) == 1, "dunk max edge resolves to frame 1", str(animation_config.resolve_dunk_approach_start_frame(13, animation_config.dunk_finish_radius)))
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
	var dunk_smart_start_visual: PlayerVisual = PlayerVisual.new()
	dunk_smart_start_visual.set_animation_config(animation_config)
	var dunk_smart_start_request: PlayerVisualRequest = PlayerVisualRequest.new("close_finish_dunk", 0, false, true, true, false, 5)
	dunk_smart_start_visual.apply_state(dunk_smart_start_request, 0.0)
	_assert_true(dunk_smart_start_visual.get_debug_frame_number() == 5, "smart dunk start frame override applies on restart", str(dunk_smart_start_visual.get_debug_frame_number()))
	dunk_smart_start_visual.apply_state(PlayerVisualRequest.new("close_finish_dunk", 0, false, true, false, false, 5), 1.0 / 15.0)
	_assert_true(dunk_smart_start_visual.get_debug_frame_number() == 6, "smart dunk start frame keeps animating forward", str(dunk_smart_start_visual.get_debug_frame_number()))
	dunk_smart_start_visual.free()

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
	var guided_floor_target: Vector2 = Vector2(shot_controller.court_config.hoop_position.x, shot_controller.court_config.hoop_position.y + 228.0)
	var near_green_finished_profile: Dictionary = _with_floor_finish(near_green_profile, guided_floor_target, shot_controller.ball_config)
	var dunk_make_finished_profile: Dictionary = _with_floor_finish(dunk_make_profile, guided_floor_target, shot_controller.ball_config)
	_assert_true(str(dunk_make_profile.get("release_mode", "")) == ShotController.RELEASE_MODE_DUNK_MAKE_DROP, "green dunk uses straight-through release mode", str(dunk_make_profile.get("release_mode", "")))
	_assert_true(str(dunk_make_profile.get("profile_kind", "")) == ShotController.PROFILE_KIND_GUIDED_MAKE, "green dunk still uses guided make profile", "")
	_assert_true(str(dunk_make_profile.get("start_phase", "")) == BallSimulator.FLIGHT_PHASE_GUIDED_DESCENT, "green dunk starts directly in guided descent", str(dunk_make_profile.get("start_phase", "")))
	_assert_true(absf(float(dunk_make_profile.get("launch_z", 0.0)) - shot_controller.court_config.rim_height) < 0.001, "green dunk launches from rim height", str(dunk_make_profile.get("launch_z", 0.0)))
	_assert_true(dunk_make_profile.get("launch_position", Vector2.ZERO).distance_to(expected_make_entry) < 0.001, "green dunk launches from the rim entry point", str(dunk_make_profile.get("launch_position", Vector2.ZERO)))
	_assert_true(str(dunk_miss_profile.get("release_mode", "")) == ShotController.RELEASE_MODE_DUNK_MISS_BOUNCE, "red dunk uses rim-bounce miss mode", str(dunk_miss_profile.get("release_mode", "")))
	_assert_true(str(dunk_miss_profile.get("profile_kind", "")) == ShotController.PROFILE_KIND_FREE_FLIGHT, "red dunk miss stays free-flight", "")
	_assert_true(absf(float(dunk_miss_profile.get("launch_z", 0.0)) - shot_controller.court_config.rim_height) < 0.001, "red dunk miss starts from rim height", str(dunk_miss_profile.get("launch_z", 0.0)))
	var dunk_make_sim: BallSimulator = _new_ball_simulator(shot_controller.ball_config)
	dunk_make_sim.launch_shot_profile(dunk_make_finished_profile)
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
	make_sim.launch_shot_profile(near_green_finished_profile)
	var scored: bool = false
	var score_interaction: Dictionary = {}
	var first_score_interaction: Dictionary = {}
	var saw_guided_descent: bool = false
	var saw_net_exit: bool = false
	var saw_floor_drop: bool = false
	var saw_floor_settle: bool = false
	var pre_score_board_side: bool = false
	var max_descent_center_offset: float = 0.0
	var score_phase: String = ""
	var handoff_reached: bool = false
	var saw_above_rim_after_handoff: bool = false
	var first_guided_descent_z: float = INF
	var first_guided_descent_vz: float = 0.0
	var first_guided_drop_weight: float = 0.0
	var last_net_exit_vz: float = 0.0
	var first_floor_drop_vz: float = INF
	var net_exit_drop_weight_min: float = INF
	var net_exit_drop_weight_max: float = -INF
	var last_floor_drop_z: float = INF
	var floor_settle_started_from_ground: bool = false
	var floor_settle_peak_z: float = 0.0
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
				last_net_exit_vz = make_sim.vz
				var net_exit_drop_weight: float = make_sim.get_terminal_visual_drop_weight()
				net_exit_drop_weight_min = minf(net_exit_drop_weight_min, net_exit_drop_weight)
				net_exit_drop_weight_max = maxf(net_exit_drop_weight_max, net_exit_drop_weight)
			BallSimulator.FLIGHT_PHASE_FLOOR_DROP:
				saw_floor_drop = true
				if is_inf(first_floor_drop_vz):
					first_floor_drop_vz = make_sim.vz
				last_floor_drop_z = make_sim.z
			BallSimulator.FLIGHT_PHASE_FLOOR_SETTLE:
				if not saw_floor_settle:
					floor_settle_started_from_ground = not is_inf(last_floor_drop_z) and last_floor_drop_z <= 0.5
				saw_floor_settle = true
				floor_settle_peak_z = maxf(floor_settle_peak_z, make_sim.z)
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
	_assert_true(saw_floor_drop, "guided make continues into floor drop", "")
	_assert_true(saw_floor_settle, "guided make continues into floor settle", "")
	_assert_true(not saw_above_rim_after_handoff, "guided make never rises above rim after handoff", "")
	_assert_true(not pre_score_board_side, "guided make never goes board-side before score", "")
	_assert_true(max_descent_center_offset <= shot_controller.ball_config.made_shot_descent_centering_tolerance + 0.5, "guided make descent stays centered", str(max_descent_center_offset))
	_assert_true(scored, "green launch scores through hoop", "")
	_assert_true(absf(net_exit_drop_weight_min - 1.0) < 0.001 and absf(net_exit_drop_weight_max - 1.0) < 0.001, "guided make net exit keeps full terminal drop", "%0.3f %0.3f" % [net_exit_drop_weight_min, net_exit_drop_weight_max])
	_assert_true(not is_inf(first_floor_drop_vz), "guided make samples floor-drop speed", "")
	_assert_true(first_floor_drop_vz < 0.0 and absf(first_floor_drop_vz) <= absf(last_net_exit_vz) + 1.0, "guided make floor drop does not spike faster than net exit", "%0.2f %0.2f" % [last_net_exit_vz, first_floor_drop_vz])
	_assert_true(floor_settle_started_from_ground, "guided make bounce starts only after floor contact", str(last_floor_drop_z))
	_assert_true(floor_settle_peak_z > 0.0 and floor_settle_peak_z <= shot_controller.ball_config.made_shot_floor_settle_hop_height + 0.5, "guided make settle stays a small single hop", str(floor_settle_peak_z))
	_assert_true(make_sim.position_xy.distance_to(guided_floor_target) < 0.01, "guided make lands on supplied floor target", str(make_sim.position_xy))
	_assert_true(absf(make_sim.z) < 0.01, "guided make finishes grounded", str(make_sim.z))
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
	var control_layout: Dictionary = input_controller.get_control_layout_snapshot()
	var control_panel_rect: Rect2 = control_layout.get("control_panel_rect", Rect2())
	var zone_rects: Dictionary = control_layout.get("control_zone_rects", {})
	var move_center: Vector2 = zone_rects.get("move", Rect2()).get_center()
	var left_pass_center: Vector2 = zone_rects.get("pass_left", Rect2()).get_center()
	var right_pass_center: Vector2 = zone_rects.get("pass_right", Rect2()).get_center()
	var shoot_center: Vector2 = zone_rects.get("shoot", Rect2()).get_center()
	var dunk_center: Vector2 = zone_rects.get("dunk", Rect2()).get_center()
	var movement_snapshot: Dictionary = input_controller.compute_movement_snapshot(Vector2.ZERO, Vector2(input_config.invisible_stick_max_radius, 0.0))
	_assert_true(movement_snapshot["direction"].is_equal_approx(Vector2.RIGHT), "invisible stick direction follows thumb vector", str(movement_snapshot))
	_assert_true(float(movement_snapshot["magnitude"]) > 0.99, "invisible stick reaches full magnitude at max radius", str(movement_snapshot["magnitude"]))
	var left_pass_release: Dictionary = input_controller.classify_control_release(move_center, left_pass_center)
	_assert_true(bool(left_pass_release.get("qualifies", false)) and str(left_pass_release.get("action_type", "")) == "pass" and str(left_pass_release.get("release_zone", "")) == "pass_left", "left pass release resolves through left control lane", JSON.stringify(left_pass_release))
	var right_pass_release: Dictionary = input_controller.classify_control_release(move_center, right_pass_center)
	_assert_true(bool(right_pass_release.get("qualifies", false)) and str(right_pass_release.get("action_type", "")) == "pass" and str(right_pass_release.get("release_zone", "")) == "pass_right", "right pass release resolves through right control lane", JSON.stringify(right_pass_release))
	var shoot_release: Dictionary = input_controller.classify_control_release(move_center, shoot_center)
	_assert_true(bool(shoot_release.get("qualifies", false)) and str(shoot_release.get("control_intent", "")) == "shot_layout", "top-left shoot release requests shot-layout intent", JSON.stringify(shoot_release))
	var dunk_release: Dictionary = input_controller.classify_control_release(move_center, dunk_center)
	_assert_true(bool(dunk_release.get("qualifies", false)) and str(dunk_release.get("control_intent", "")) == "dunk", "top-right dunk release requests dunk intent", JSON.stringify(dunk_release))
	var center_release: Dictionary = input_controller.classify_control_release(move_center, move_center)
	_assert_true(not bool(center_release.get("qualifies", true)) and str(center_release.get("release_reason", "")) == "center_cancel", "release in move zone cancels instead of firing an action", JSON.stringify(center_release))
	var short_shoot_release: Dictionary = input_controller.classify_control_release(move_center, move_center.lerp(shoot_center, 0.12))
	_assert_true(not bool(short_shoot_release.get("qualifies", true)), "short drag into an action lane does not qualify", JSON.stringify(short_shoot_release))
	input_controller.begin_test_live_gesture(move_center)
	input_controller.update_test_live_gesture(shoot_center)
	var hover_feedback_snapshot: Dictionary = input_controller.get_touch_feedback_snapshot()
	_assert_true(
		str(hover_feedback_snapshot.get("highlight_zone", "")) == "shoot",
		"dragging into a control zone marks it as the active hover highlight",
		JSON.stringify(hover_feedback_snapshot)
	)
	input_controller.end_test_live_gesture(move_center)
	var removed_bottom_dunk_release: Dictionary = input_controller.classify_control_release(
		move_center,
		Vector2(control_panel_rect.get_center().x, control_panel_rect.end.y - 8.0)
	)
	_assert_true(
		not bool(removed_bottom_dunk_release.get("qualifies", true))
			and str(removed_bottom_dunk_release.get("control_intent", "")) == "",
		"the removed bottom dunk strip no longer triggers a dunk action",
		JSON.stringify(removed_bottom_dunk_release)
	)
	var off_panel_release: Dictionary = input_controller.classify_control_release(move_center, long_target.get_screen_anchor())
	_assert_true(not bool(off_panel_release.get("qualifies", true)) and str(off_panel_release.get("release_zone", "")) == "none", "open-court release outside the control panel does not map to a gameplay action", JSON.stringify(off_panel_release))
	var pass_requests: Array[Dictionary] = []
	input_controller.pass_requested.connect(func(target: PlayerController, details: Dictionary) -> void:
		pass_requests.append({"target": target, "details": details.duplicate(true)})
	)
	var shot_mode_requests: Array[Dictionary] = []
	input_controller.shot_mode_requested.connect(func(details: Dictionary) -> void:
		shot_mode_requests.append(details.duplicate(true))
	)
	input_controller.tap_test_pass(Vector2(180.0, 640.0), 0.05)
	_assert_true(
		pass_requests.size() == 1
			and pass_requests[0].get("target", long_target) == null
			and str(pass_requests[0]["details"].get("release_reason", "")) == "pass_left_button_tap"
			and str(pass_requests[0]["details"].get("pass_target_source", "")) == "focused_target",
		"left pass button tap routes to the focused pass target",
		JSON.stringify(pass_requests[0]["details"] if not pass_requests.is_empty() else {})
	)
	input_controller.tap_test_pass(Vector2(900.0, 640.0), 0.05)
	_assert_true(
		pass_requests.size() == 2
			and pass_requests[1].get("target", long_target) == null
			and str(pass_requests[1]["details"].get("release_reason", "")) == "pass_right_button_tap",
		"right pass button tap also routes to the focused pass target",
		JSON.stringify(pass_requests[1]["details"] if pass_requests.size() > 1 else {})
	)
	input_controller.tap_test_pass(long_target.get_screen_anchor(), 0.05)
	_assert_true(
		pass_requests.size() == 3
			and pass_requests[2].get("target", long_target) == null
			and str(pass_requests[2]["details"].get("pass_target_source", "")) == "focused_target",
		"teammate screen coordinates still resolve to the focused pass buttons",
		JSON.stringify(pass_requests[2]["details"] if pass_requests.size() > 2 else {})
	)
	input_controller.swipe_test_shot_arm(move_center, shoot_center, 0.12)
	_assert_true(
		shot_mode_requests.size() == 1
			and str(shot_mode_requests[0].get("control_intent", "")) == "shot_layout"
			and str(shot_mode_requests[0].get("release_zone", "")) == "shoot",
		"release into the shoot band arms shot mode with shot-layout intent",
		JSON.stringify(shot_mode_requests[0] if not shot_mode_requests.is_empty() else {})
	)
	input_controller.swipe_test_shot_arm(move_center, dunk_center, 0.12)
	_assert_true(
		shot_mode_requests.size() == 2
			and str(shot_mode_requests[1].get("control_intent", "")) == "dunk"
			and str(shot_mode_requests[1].get("release_zone", "")) == "dunk",
		"release into the dunk band arms dunk intent",
		JSON.stringify(shot_mode_requests[1] if shot_mode_requests.size() > 1 else {})
	)
	input_controller.swipe_test_shot_arm(move_center, move_center + Vector2(160.0, 0.0), 0.12)
	_assert_true(
		shot_mode_requests.size() == 2,
		"sideways release back into the move lane does not arm a shot",
		JSON.stringify({"shots": shot_mode_requests.size()})
	)
	input_controller.tap_test_control_button("shoot", 0.05, -94)
	var direct_tap_feedback_snapshot: Dictionary = input_controller.get_touch_feedback_snapshot()
	_assert_true(
		shot_mode_requests.size() == 3
			and str(shot_mode_requests[2].get("control_intent", "")) == "shot_layout"
			and bool(shot_mode_requests[2].get("direct_button_tap", false))
			and str(shot_mode_requests[2].get("release_reason", "")) == "shoot_button_tap",
		"direct shoot button tap arms shot mode without movement",
		JSON.stringify(shot_mode_requests[2] if shot_mode_requests.size() > 2 else {})
	)
	_assert_true(
		str(direct_tap_feedback_snapshot.get("highlight_zone", "")) == "shoot",
		"direct button taps leave a short-lived pressed highlight for panel feedback",
		JSON.stringify(direct_tap_feedback_snapshot)
	)
	input_controller.tap_test_dunk_button(0.05)
	_assert_true(
		shot_mode_requests.size() == 4
			and str(shot_mode_requests[3].get("control_intent", "")) == "dunk"
			and bool(shot_mode_requests[3].get("direct_button_tap", false))
			and str(shot_mode_requests[3].get("release_reason", "")) == "dunk_button_tap",
		"direct dunk button tap arms dunk intent without movement",
		JSON.stringify(shot_mode_requests[3] if shot_mode_requests.size() > 3 else {})
	)
	input_controller.begin_test_live_gesture(move_center)
	input_controller.tap_test_pass(Vector2(900.0, 640.0), 0.05)
	_assert_true(
		pass_requests.size() == 4
			and str(pass_requests[3]["details"].get("release_reason", "")) == "pass_right_button_tap"
			and bool(pass_requests[3]["details"].get("direct_button_tap", false)),
		"second-finger pass button tap works while dragging",
		JSON.stringify(pass_requests[3]["details"] if pass_requests.size() > 3 else {})
	)
	input_controller.end_test_live_gesture(move_center)
	input_controller.begin_test_live_gesture(move_center)
	input_controller.tap_test_control_button("shoot", 0.05, -93)
	_assert_true(
		shot_mode_requests.size() == 5
			and str(shot_mode_requests[4].get("release_reason", "")) == "shoot_button_tap"
			and bool(shot_mode_requests[4].get("direct_button_tap", false)),
		"second-finger shoot button tap works while dragging",
		JSON.stringify(shot_mode_requests[4] if shot_mode_requests.size() > 4 else {})
	)
	input_controller.end_test_live_gesture(move_center)

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
	_assert_true(sim_result.has("visual_steps"), "opponent sim returns visual steps", JSON.stringify(sim_result))
	var visual_steps: Array = sim_result.get("visual_steps", [])
	_assert_true(visual_steps.size() >= 1 and visual_steps.size() <= 5, "opponent sim visual step count is 1-5", str(visual_steps.size()))
	if not visual_steps.is_empty():
		for visual_step_value in visual_steps:
			var visual_step: Dictionary = visual_step_value
			var step_text: String = str(visual_step.get("text", ""))
			var step_kind: String = str(visual_step.get("kind", ""))
			var step_player_id: String = str(visual_step.get("player_id", ""))
			var step_player_role: String = str(visual_step.get("player_role", ""))
			var step_actor_team: String = str(visual_step.get("actor_team", ""))
			_assert_true(step_kind.strip_edges() != "", "opponent sim visual step has kind", JSON.stringify(visual_step))
			_assert_true(step_player_id.strip_edges() != "", "opponent sim visual step has player id", JSON.stringify(visual_step))
			_assert_true(step_player_role.strip_edges() != "", "opponent sim visual step has player role", JSON.stringify(visual_step))
			_assert_true(step_actor_team.strip_edges() != "", "opponent sim visual step has actor team", JSON.stringify(visual_step))
			_assert_true(step_text.strip_edges() != "", "opponent sim visual step has text", JSON.stringify(visual_step))
			_assert_true(not step_text.to_lower().contains("clock"), "opponent sim visual step omits clock text", step_text)
			_assert_true(not step_text.to_lower().contains("debug"), "opponent sim visual step omits debug text", step_text)
			_assert_true(not step_text.to_lower().contains("seed"), "opponent sim visual step omits seed text", step_text)
		var final_step: Dictionary = visual_steps[-1]
		_assert_true(bool(final_step.get("is_final", false)), "opponent sim final visual step marked final", JSON.stringify(final_step))
		_assert_true(int(final_step.get("points", 0)) == int(sim_result.get("points_scored", 0)), "opponent sim final visual step matches points", JSON.stringify({"final": final_step, "result": sim_result}))
		if int(sim_result.get("points_scored", 0)) > 0:
			_assert_true(str(final_step.get("kind", "")) == "score", "scoring opponent sim ends with score step", JSON.stringify(final_step))
			_assert_true(str(final_step.get("text", "")) == "%d points!" % int(sim_result.get("points_scored", 0)), "scoring opponent sim score step text matches points", JSON.stringify(final_step))
	rng.reseed(9)
	var repeat_sim_result: Dictionary = sim_controller.run_possession(away_team, home_team, 180.0, rng)
	_assert_true(JSON.stringify(repeat_sim_result.get("visual_steps", [])) == JSON.stringify(sim_result.get("visual_steps", [])), "opponent sim visual steps are deterministic by seed", "")

	var log_writer: LogWriter = LogWriter.new()
	log_writer.set_prefix("test_check")
	log_writer.log_match("hello")
	var file_path: String = ProjectSettings.globalize_path("user://logs/test_check_match.log")
	_assert_true(FileAccess.file_exists(file_path), "logs written", file_path)
	_assert_true(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/MainMenu.tscn", "boot scene is main menu", str(ProjectSettings.get_setting("application/run/main_scene")))
	TeamRoster.reset_demo_state()
	_assert_true(TeamRoster.get_coin_balance() == 1000, "team roster starts with 1000 demo coins", str(TeamRoster.get_coin_balance()))
	var initial_lineup_slots: Array[Dictionary] = TeamRoster.get_home_lineup_slots()
	var initial_slot_roles: Array[String] = []
	for slot_data in initial_lineup_slots:
		initial_slot_roles.append(str(slot_data.get("slot_role", "")))
	_assert_true(
		initial_lineup_slots.size() == 5 and JSON.stringify(initial_slot_roles) == JSON.stringify(["PG", "LW", "RW", "LC", "RC"]),
		"team roster seeds five fixed starter slots",
		JSON.stringify(initial_slot_roles)
	)
	_assert_true(TeamRoster.get_home_bench_players().is_empty(), "team roster starts with an empty bench", "")
	var initial_shop_players: Array[PlayerData] = TeamRoster.get_shop_players()
	var titan_offer: PlayerData = _find_roster_player_by_id(initial_shop_players, "shop_lc_titan")
	_assert_true(initial_shop_players.size() == 4, "team roster loads four featured shop players", str(initial_shop_players.size()))
	_assert_true(titan_offer != null and titan_offer.purchase_cost == 250, "best featured player costs 250 coins", str(titan_offer.purchase_cost if titan_offer != null else -1))
	var purchase_result: Dictionary = TeamRoster.purchase_shop_player("shop_lc_titan")
	_assert_true(bool(purchase_result.get("success", false)), "shop purchase succeeds once for a valid player", JSON.stringify(purchase_result))
	_assert_true(TeamRoster.get_coin_balance() == 750, "successful purchase deducts coins", str(TeamRoster.get_coin_balance()))
	var purchased_bench: Array[PlayerData] = TeamRoster.get_home_bench_players()
	_assert_true(
		purchased_bench.size() == 1 and purchased_bench[0].player_id == "shop_lc_titan",
		"purchased player is added to the bench",
		purchased_bench[0].player_id if not purchased_bench.is_empty() else ""
	)
	var duplicate_purchase_result: Dictionary = TeamRoster.purchase_shop_player("shop_lc_titan")
	_assert_true(
		not bool(duplicate_purchase_result.get("success", true)) and str(duplicate_purchase_result.get("reason", "")) == "already_purchased",
		"duplicate shop purchase fails cleanly",
		JSON.stringify(duplicate_purchase_result)
	)
	TeamRoster.reset_demo_state()
	for spend_id in ["shop_lc_titan", "shop_pg_nova", "shop_rw_orbit"]:
		TeamRoster.purchase_shop_player(spend_id)
	var insufficient_purchase_result: Dictionary = TeamRoster.purchase_shop_player("shop_lw_glitch")
	_assert_true(
		not bool(insufficient_purchase_result.get("success", true)) and str(insufficient_purchase_result.get("reason", "")) == "insufficient_funds",
		"insufficient funds purchase fails cleanly",
		JSON.stringify(insufficient_purchase_result)
	)
	TeamRoster.reset_demo_state()
	var original_pg_slot: Dictionary = _find_roster_slot_by_role(TeamRoster.get_home_lineup_slots(), "PG")
	var original_pg_player: PlayerData = original_pg_slot.get("player", null) as PlayerData
	TeamRoster.purchase_shop_player("shop_lc_titan")
	var lineup_swap_succeeded: bool = TeamRoster.swap_lineup_slot_with_bench("PG", "shop_lc_titan")
	_assert_true(lineup_swap_succeeded, "bench player can swap into a starter slot", "")
	var swapped_pg_slot: Dictionary = _find_roster_slot_by_role(TeamRoster.get_home_lineup_slots(), "PG")
	var swapped_pg_player: PlayerData = swapped_pg_slot.get("player", null) as PlayerData
	var swapped_bench: Array[PlayerData] = TeamRoster.get_home_bench_players()
	_assert_true(swapped_pg_player != null and swapped_pg_player.player_id == "shop_lc_titan", "starter slot now holds the swapped bench player", swapped_pg_player.player_id if swapped_pg_player != null else "")
	_assert_true(
		swapped_bench.size() == 1 and original_pg_player != null and swapped_bench[0].player_id == original_pg_player.player_id,
		"displaced starter returns to the bench at the same bench index",
		swapped_bench[0].player_id if not swapped_bench.is_empty() else ""
	)
	var runtime_home_team: TeamData = TeamRoster.get_home_team()
	var runtime_home_roles: Array[String] = []
	for player_data in runtime_home_team.players:
		runtime_home_roles.append(player_data.role)
	_assert_true(
		runtime_home_team.players.size() == 5 and JSON.stringify(runtime_home_roles) == JSON.stringify(["PG", "LW", "RW", "LC", "RC"]),
		"derived gameplay team always stays in fixed PG/LW/RW/LC/RC slot order",
		JSON.stringify(runtime_home_roles)
	)
	var runtime_pg_player: PlayerData = runtime_home_team.get_player_by_role("PG")
	_assert_true(
		runtime_pg_player != null and runtime_pg_player.display_name == "Titan" and runtime_pg_player.role == "PG" and runtime_pg_player.dunk == titan_offer.dunk,
		"derived gameplay team keeps fixed slot role while inheriting the swapped player's identity and ratings",
		JSON.stringify({
			"display_name": runtime_pg_player.display_name if runtime_pg_player != null else "",
			"role": runtime_pg_player.role if runtime_pg_player != null else "",
			"dunk": runtime_pg_player.dunk if runtime_pg_player != null else -1,
		})
	)
	TeamRoster.reset_demo_state()
	MENU_BACKGROUND_SCRIPT.reset_for_tests()
	var main_menu_scene: PackedScene = load("res://scenes/MainMenu.tscn")
	var main_menu: Control = main_menu_scene.instantiate() as Control
	add_child(main_menu)
	await get_tree().process_frame
	var main_menu_background: TextureRect = main_menu.get_node_or_null("CourtBackground") as TextureRect
	var main_menu_texture: Texture2D = main_menu_background.texture if main_menu_background != null else null
	var shared_menu_source_path: String = MENU_BACKGROUND_SCRIPT.get_source_path()
	_assert_true(main_menu_background != null, "main menu exposes a court background node", "")
	_assert_true(main_menu_texture != null, "main menu background texture exists", "")
	_assert_true(main_menu.get_node_or_null("ButtonStack/QuitButton") == null, "main menu omits a quit button", "")
	_assert_true(not shared_menu_source_path.is_empty(), "shared menu background chooses a source image", shared_menu_source_path)
	var team_screen_scene: PackedScene = load("res://scenes/TeamScreen.tscn")
	var team_screen: TeamScreen = team_screen_scene.instantiate() as TeamScreen
	add_child(team_screen)
	await get_tree().process_frame
	var team_background: TextureRect = team_screen.get_node_or_null("CourtBackground") as TextureRect
	var team_texture: Texture2D = team_background.texture if team_background != null else null
	_assert_true(team_background != null, "team screen exposes a court background node", "")
	_assert_true(
		team_texture != null and main_menu_texture != null and team_texture.get_rid() == main_menu_texture.get_rid(),
		"team screen reuses the main menu background texture",
		"%s %s" % [team_texture.get_rid() if team_texture != null else RID(), main_menu_texture.get_rid() if main_menu_texture != null else RID()]
	)
	_assert_true(MENU_BACKGROUND_SCRIPT.get_source_path() == shared_menu_source_path, "team screen keeps the shared menu background selection", MENU_BACKGROUND_SCRIPT.get_source_path())
	var team_layout_snapshot: Dictionary = team_screen.get_card_layout_snapshot() if team_screen != null else {}
	var team_sprite_display_size: Vector2 = team_layout_snapshot.get("sprite_display_size", Vector2.ZERO)
	_assert_true(
		bool(team_layout_snapshot.get("starters_horizontal_scroll", false)) and bool(team_layout_snapshot.get("bench_horizontal_scroll", false)),
		"team screen uses horizontal starter and bench strips",
		JSON.stringify(team_layout_snapshot)
	)
	_assert_true(
		bool(team_layout_snapshot.get("carousel_matches_phone_width", false)),
		"team screen stretches the roster carousels to the phone width",
		JSON.stringify(team_layout_snapshot)
	)
	_assert_true(
		team_sprite_display_size.x >= 320.0 and team_sprite_display_size.y >= 320.0,
		"team screen keeps enlarged player sprite slots",
		str(team_sprite_display_size)
	)
	_assert_true(int(team_layout_snapshot.get("starter_card_count", 0)) == 5, "team screen renders five starters", JSON.stringify(team_layout_snapshot))
	_assert_true(int(team_layout_snapshot.get("bench_count", -1)) == 0 and bool(team_layout_snapshot.get("bench_placeholder_visible", false)), "team screen shows an empty-bench placeholder before purchases", JSON.stringify(team_layout_snapshot))
	_assert_true(bool(team_layout_snapshot.get("has_shop_button", false)), "team screen exposes a shop button", JSON.stringify(team_layout_snapshot))
	_assert_true(str(team_layout_snapshot.get("coin_balance_text", "")) == "1000", "team screen coin badge starts at 1000", JSON.stringify(team_layout_snapshot))
	_assert_true(absf(float(team_layout_snapshot.get("bottom_bar_gap", -1.0)) - 50.0) < 0.5, "team screen keeps the bottom action bar 50px above the screen edge", JSON.stringify(team_layout_snapshot))
	_assert_true(absf(float(team_layout_snapshot.get("bottom_bar_side_inset", -1.0)) - 30.0) < 0.5, "team screen keeps the bottom action bar 30px from the screen sides", JSON.stringify(team_layout_snapshot))
	_assert_true(bool(team_layout_snapshot.get("headers_align_with_title", false)), "team screen section headers align with the title column", JSON.stringify(team_layout_snapshot))
	_assert_true(float(team_layout_snapshot.get("subtitle_to_starters_gap", 0.0)) >= 19.5, "team screen keeps at least 20px between the subtitle and STARTERS", JSON.stringify(team_layout_snapshot))
	_assert_true(bool(team_layout_snapshot.get("bench_placeholder_centered", false)), "team screen centers the empty bench placeholder against the screen", JSON.stringify(team_layout_snapshot))
	_assert_true(bool(team_layout_snapshot.get("starters_viewport_fits_card", false)), "team screen starters section is tall enough to show a full card", JSON.stringify(team_layout_snapshot))
	_assert_true(bool(team_layout_snapshot.get("body_swipe_scroll_passthrough", false)), "team screen lets card bodies pass swipe input through to the carousel", JSON.stringify(team_layout_snapshot))
	_assert_true(team_screen.debug_simulate_strip_swipe("starters", -240.0) > 0.0, "team screen starters carousel actually scrolls on swipe", JSON.stringify(team_layout_snapshot))
	var shop_screen_scene: PackedScene = load("res://scenes/ShopScreen.tscn")
	var shop_screen = shop_screen_scene.instantiate()
	add_child(shop_screen)
	await get_tree().process_frame
	var shop_background: TextureRect = shop_screen.get_node_or_null("CourtBackground") as TextureRect
	var shop_texture: Texture2D = shop_background.texture if shop_background != null else null
	_assert_true(shop_background != null, "shop screen exposes a court background node", "")
	_assert_true(
		shop_texture != null and main_menu_texture != null and shop_texture.get_rid() == main_menu_texture.get_rid(),
		"shop screen reuses the main menu background texture",
		"%s %s" % [shop_texture.get_rid() if shop_texture != null else RID(), main_menu_texture.get_rid() if main_menu_texture != null else RID()]
	)
	_assert_true(MENU_BACKGROUND_SCRIPT.get_source_path() == shared_menu_source_path, "shop screen keeps the shared menu background selection", MENU_BACKGROUND_SCRIPT.get_source_path())
	var shop_layout_snapshot: Dictionary = shop_screen.get_layout_snapshot()
	_assert_true(int(shop_layout_snapshot.get("offer_count", 0)) == 4, "shop screen renders four featured players", JSON.stringify(shop_layout_snapshot))
	_assert_true(
		int(shop_layout_snapshot.get("row_count", 0)) == 2 and JSON.stringify(shop_layout_snapshot.get("row_card_counts", [])) == JSON.stringify([2, 2]),
		"shop screen wraps the featured catalog into two rows",
		JSON.stringify(shop_layout_snapshot)
	)
	_assert_true(str(shop_layout_snapshot.get("coin_balance_text", "")) == "1000", "shop screen coin badge starts at 1000", JSON.stringify(shop_layout_snapshot))
	_assert_true(absf(float(shop_layout_snapshot.get("bottom_button_gap", -1.0)) - 50.0) < 0.5, "shop screen keeps Back To Team 50px above the screen edge", JSON.stringify(shop_layout_snapshot))
	_assert_true(absf(float(shop_layout_snapshot.get("bottom_button_side_inset", -1.0)) - 30.0) < 0.5, "shop screen keeps Back To Team 30px from the screen sides", JSON.stringify(shop_layout_snapshot))
	TeamRoster.purchase_shop_player("shop_lc_titan")
	await get_tree().process_frame
	var purchased_team_layout: Dictionary = team_screen.get_card_layout_snapshot()
	_assert_true(
		int(purchased_team_layout.get("bench_count", 0)) == 1 and not bool(purchased_team_layout.get("bench_placeholder_visible", true)),
		"team screen bench updates immediately after a purchase",
		JSON.stringify(purchased_team_layout)
	)
	_assert_true(bool(purchased_team_layout.get("bench_viewport_fits_card", false)), "team screen bench section is tall enough to show a full card", JSON.stringify(purchased_team_layout))
	_assert_true(str(purchased_team_layout.get("coin_balance_text", "")) == "750", "team screen coin badge updates after a purchase", JSON.stringify(purchased_team_layout))
	var purchased_shop_layout: Dictionary = shop_screen.get_layout_snapshot()
	var purchased_titan_state: Dictionary = _find_roster_card_state_by_id(purchased_shop_layout.get("states", []), "shop_lc_titan")
	_assert_true(
		str(purchased_shop_layout.get("coin_balance_text", "")) == "750",
		"shop screen coin badge updates after a purchase",
		JSON.stringify(purchased_shop_layout)
	)
	_assert_true(
		str(purchased_titan_state.get("button_text", "")) == "Purchased" and bool(purchased_titan_state.get("button_disabled", false)),
		"shop screen marks bought players as purchased",
		JSON.stringify(purchased_titan_state)
	)
	var bench_drag_handle_rect: Rect2 = team_screen.debug_get_drag_handle_global_rect("bench", "shop_lc_titan")
	_assert_true(
		bench_drag_handle_rect.size.x >= float(purchased_team_layout.get("card_width", 0.0)) - 60.0,
		"team screen uses a near-full-width drag handle under the player details",
		JSON.stringify({"handle_rect": bench_drag_handle_rect, "layout": purchased_team_layout})
	)
	_assert_true(
		not team_screen.debug_simulate_body_press("bench", "shop_lc_titan"),
		"team screen does not start a drag from the card body",
		JSON.stringify(purchased_team_layout)
	)
	_assert_true(
		team_screen.debug_simulate_handle_press("bench", "shop_lc_titan"),
		"team screen starts a drag from the card handle",
		JSON.stringify(purchased_team_layout)
	)
	var rc_rect: Rect2 = team_screen.debug_get_card_global_rect("lineup", "RC")
	var hover_padding: float = float(purchased_team_layout.get("drag_hover_padding", 0.0))
	var near_hover_point: Vector2 = rc_rect.get_center() + Vector2(0.0, rc_rect.size.y * 0.5 + hover_padding - 8.0)
	var near_hover_target: Dictionary = team_screen.debug_resolve_drop_target(near_hover_point, "bench", "shop_lc_titan")
	_assert_true(
		str(near_hover_target.get("kind", "")) == "lineup" and str(near_hover_target.get("id", "")) == "RC",
		"team screen accepts padded near-hover drag targets",
		JSON.stringify({"point": near_hover_point, "target": near_hover_target, "rect": rc_rect})
	)
	var far_hover_point: Vector2 = rc_rect.get_center() + Vector2(0.0, rc_rect.size.y * 0.5 + hover_padding + 40.0)
	var far_hover_target: Dictionary = team_screen.debug_resolve_drop_target(far_hover_point, "bench", "shop_lc_titan")
	_assert_true(
		str(far_hover_target.get("id", "")) == "",
		"team screen rejects drops outside the padded hover threshold",
		JSON.stringify({"point": far_hover_point, "target": far_hover_target, "rect": rc_rect})
	)
	var settings_screen_scene: PackedScene = load("res://scenes/SettingsScreen.tscn")
	var settings_screen: Control = settings_screen_scene.instantiate() as Control
	add_child(settings_screen)
	await get_tree().process_frame
	var settings_background: TextureRect = settings_screen.get_node_or_null("CourtBackground") as TextureRect
	var settings_texture: Texture2D = settings_background.texture if settings_background != null else null
	_assert_true(settings_background != null, "settings screen exposes a court background node", "")
	_assert_true(
		settings_texture != null and main_menu_texture != null and settings_texture.get_rid() == main_menu_texture.get_rid(),
		"settings screen reuses the main menu background texture",
		"%s %s" % [settings_texture.get_rid() if settings_texture != null else RID(), main_menu_texture.get_rid() if main_menu_texture != null else RID()]
	)
	_assert_true(MENU_BACKGROUND_SCRIPT.get_source_path() == shared_menu_source_path, "settings screen keeps the shared menu background selection", MENU_BACKGROUND_SCRIPT.get_source_path())
	TeamRoster.reset_demo_state()
	main_menu.queue_free()
	team_screen.queue_free()
	shop_screen.queue_free()
	settings_screen.queue_free()
	await get_tree().process_frame
	var game_root_scene: PackedScene = load("res://scenes/GameRoot.tscn")
	var game_root: Node2D = game_root_scene.instantiate() as Node2D
	add_child(game_root)
	await get_tree().process_frame
	var smoke_court_view: CourtView = game_root.get_node("CourtView") as CourtView
	var smoke_coordinator: GameCoordinator = game_root.get_node("GameCoordinator") as GameCoordinator
	_assert_true(smoke_court_view != null and smoke_court_view.has_textured_court(), "court art smoke", "")
	_assert_true(smoke_coordinator != null and smoke_coordinator.hoop_node != null and smoke_coordinator.hoop_node.has_sprite_visuals(), "hoop art smoke", "")
	_assert_true(smoke_coordinator != null and smoke_coordinator.ball_node != null and smoke_coordinator.ball_node.has_sprite_visuals(), "ball art smoke", "")
	if smoke_coordinator != null and smoke_coordinator.projection_config != null:
		_assert_true(
			smoke_coordinator.projection_config.held_ball_render_radius >= 24.0 \
				and smoke_coordinator.projection_config.live_ball_render_radius_min >= 26.785715 \
				and smoke_coordinator.projection_config.live_ball_render_radius_max >= 53.57143,
			"ball projection config keeps the 1.5x enlarged render sizing",
			"%s %s %s" % [
				smoke_coordinator.projection_config.held_ball_render_radius,
				smoke_coordinator.projection_config.live_ball_render_radius_min,
				smoke_coordinator.projection_config.live_ball_render_radius_max,
			]
		)
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
		_assert_true(not smoke_coordinator.debug_overlay.visible, "debug overlay defaults off (settings-controlled)", str(smoke_coordinator.debug_overlay.visible))
		_assert_true(not smoke_coordinator.debug_config.show_catch_radii, "default teammate catch rings stay hidden", str(smoke_coordinator.debug_config.show_catch_radii))
		_assert_true(smoke_coordinator.debug_config.show_finish_radii, "finish radius debug rings default on when overlay is shown", str(smoke_coordinator.debug_config.show_finish_radii))
		var finish_ring_snapshot: Dictionary = smoke_coordinator.get_debug_snapshot()
		var finish_radius_rings: Array = finish_ring_snapshot.get("finish_radius_rings", [])
		var finish_ring_names: PackedStringArray = PackedStringArray()
		for finish_ring in finish_radius_rings:
			finish_ring_names.append(str(finish_ring.get("name", "")))
		_assert_true(finish_radius_rings.size() == 4, "debug snapshot exposes four finish radius rings", JSON.stringify(finish_ring_names))
		_assert_true(
			finish_ring_names.has("close_finish") and finish_ring_names.has("dunk_max") and finish_ring_names.has("dunk_medium") and finish_ring_names.has("dunk_short"),
			"debug snapshot names all finish radius rings",
			JSON.stringify(finish_ring_names)
		)
		if smoke_coordinator.hoop_node != null and smoke_coordinator.hoop_node.has_method("get_debug_finish_radius_center_screen"):
			var finish_radius_center: Vector2 = finish_ring_snapshot.get("finish_radius_center", Vector2.INF)
			var expected_finish_center: Vector2 = smoke_coordinator.hoop_node.call("get_debug_finish_radius_center_screen")
			_assert_true(
				finish_radius_center.distance_to(expected_finish_center) < 0.01,
				"finish radius center aligns to hoop debug anchor",
				"%s %s" % [finish_radius_center, expected_finish_center]
			)
	var smoke_layout: Dictionary = {}
	if smoke_coordinator != null and smoke_coordinator.court_projection != null and smoke_coordinator.court_config != null:
		smoke_layout = smoke_coordinator.get_layout_metrics_snapshot()
		var smoke_court_rect: Rect2 = smoke_layout.get("court_screen_rect", Rect2())
		var smoke_available_rect: Rect2 = smoke_layout.get("available_play_rect", Rect2())
		var smoke_rect: Rect2 = smoke_coordinator.court_config.court_rect
		var smoke_top_left: Vector2 = smoke_coordinator.court_projection.world_to_base_screen_ground(smoke_rect.position)
		var smoke_bottom_right: Vector2 = smoke_coordinator.court_projection.world_to_base_screen_ground(smoke_rect.end)
		_assert_true(smoke_top_left.distance_to(smoke_court_rect.position) < 0.01 and smoke_bottom_right.distance_to(smoke_court_rect.end) < 0.01, "court maps to responsive screen rect", "%s %s %s" % [smoke_top_left, smoke_bottom_right, smoke_court_rect])
		_assert_true(absf(smoke_court_rect.get_center().x - smoke_available_rect.get_center().x) < 0.01 and absf(smoke_court_rect.get_center().y - smoke_available_rect.get_center().y) < 0.01, "court stays centered in the available play rect", "%s %s" % [smoke_court_rect, smoke_available_rect])
	if smoke_coordinator != null and smoke_coordinator.hud != null:
		var hud_snapshot: Dictionary = smoke_coordinator.hud.get_layout_snapshot()
		var scoreboard_rect: Rect2 = hud_snapshot.get("scoreboard_rect", hud_snapshot.get("banner_rect", Rect2()))
		var home_rect: Rect2 = hud_snapshot.get("home_rect", Rect2())
		var timer_rect: Rect2 = hud_snapshot.get("timer_rect", Rect2())
		var pause_rect: Rect2 = hud_snapshot.get("pause_rect", Rect2())
		var away_rect: Rect2 = hud_snapshot.get("away_rect", Rect2())
		for snapshot_key in ["home_rect", "timer_rect", "away_rect"]:
			_assert_true(_rect_contains_rect(scoreboard_rect, hud_snapshot.get(snapshot_key, Rect2())), "%s fits inside scoreboard" % snapshot_key, str(hud_snapshot.get(snapshot_key, Rect2())))
		_assert_true(pause_rect.size.x > 0.0 and pause_rect.size.y > 0.0, "pause button rect is populated", str(pause_rect))
		_assert_true(not _rect_contains_rect(scoreboard_rect, pause_rect), "pause button no longer lives inside the scoreboard", "%s %s" % [scoreboard_rect, pause_rect])
		_assert_true(home_rect.get_center().x < timer_rect.get_center().x, "home score stays left of timer", "%s %s" % [home_rect, timer_rect])
		_assert_true(away_rect.get_center().x > timer_rect.get_center().x, "away score stays right of timer", "%s %s" % [away_rect, timer_rect])
		if not smoke_layout.is_empty():
			var smoke_safe_rect: Rect2 = smoke_layout.get("safe_rect", Rect2())
			var smoke_control_rect_for_board: Rect2 = smoke_layout.get("control_panel_rect", Rect2())
			var smoke_control_zones_for_board: Dictionary = smoke_layout.get("control_zone_rects", {})
			var smoke_shoot_rect_for_board: Rect2 = smoke_control_zones_for_board.get("shoot", Rect2())
			var smoke_dunk_rect_for_pause: Rect2 = smoke_control_zones_for_board.get("dunk", Rect2())
			_assert_true(_rect_contains_rect(smoke_safe_rect, scoreboard_rect), "scoreboard stays inside the safe area", "%s %s" % [scoreboard_rect, smoke_safe_rect])
			_assert_true(_rect_contains_rect(smoke_safe_rect, pause_rect), "pause button stays inside the safe area", "%s %s" % [pause_rect, smoke_safe_rect])
			_assert_true(absf(scoreboard_rect.position.x - smoke_shoot_rect_for_board.position.x) < 0.01, "scoreboard aligns to the shoot lane on the left edge", "%s %s" % [scoreboard_rect, smoke_shoot_rect_for_board])
			_assert_true(absf(scoreboard_rect.size.x - smoke_shoot_rect_for_board.size.x) < 0.01, "scoreboard width matches the shoot lane", "%s %s" % [scoreboard_rect, smoke_shoot_rect_for_board])
			_assert_true(scoreboard_rect.end.y <= smoke_control_rect_for_board.position.y - 0.01, "scoreboard sits above the control panel", "%s %s" % [scoreboard_rect, smoke_control_rect_for_board])
			_assert_true(pause_rect.end.y <= smoke_control_rect_for_board.position.y - 0.01, "pause button sits above the control panel", "%s %s" % [pause_rect, smoke_control_rect_for_board])
			_assert_true(absf(pause_rect.end.x - smoke_control_rect_for_board.end.x) < 0.01, "pause button aligns to the right edge of the control panel", "%s %s" % [pause_rect, smoke_control_rect_for_board])
			_assert_true(absf(pause_rect.position.y - scoreboard_rect.position.y) < 0.01, "pause button shares the scoreboard top alignment", "%s %s" % [pause_rect, scoreboard_rect])
			_assert_true(absf(pause_rect.size.y - scoreboard_rect.size.y) < 0.01, "pause button height matches the scoreboard card", "%s %s" % [pause_rect, scoreboard_rect])
			_assert_true(pause_rect.position.x >= smoke_dunk_rect_for_pause.position.x - 0.01, "pause button sits on the dunk-side half", "%s %s" % [pause_rect, smoke_dunk_rect_for_pause])
		var scoreboard_texture_size: Vector2 = smoke_coordinator.hud.get_scoreboard_texture_size()
		var exact_trimmed_size: bool = scoreboard_texture_size.distance_to(Vector2(1098.0, 248.0)) < 0.01
		var trimmed_aspect_matches: bool = scoreboard_texture_size.y > 0.0 and absf(scoreboard_texture_size.x / scoreboard_texture_size.y - (1098.0 / 248.0)) < 0.001
		_assert_true(exact_trimmed_size or trimmed_aspect_matches, "scoreboard texture keeps trimmed art dimensions", str(scoreboard_texture_size))
	if smoke_coordinator != null and smoke_coordinator.pause_overlay != null:
		smoke_coordinator.test_toggle_pause()
		_assert_true(smoke_coordinator.pause_overlay.visible, "pause overlay opens for debug toggles", str(smoke_coordinator.pause_overlay.visible))
		_assert_true(
			smoke_coordinator.test_get_quit_scene_path() == "res://scenes/MainMenu.tscn",
			"pause quit targets the main menu scene",
			smoke_coordinator.test_get_quit_scene_path()
		)
		var pause_overlay_snapshot: Dictionary = smoke_coordinator.pause_overlay.get_layout_snapshot()
		var pause_root_rect: Rect2 = pause_overlay_snapshot.get("root_rect", Rect2())
		var pause_panel_rect: Rect2 = pause_overlay_snapshot.get("panel_rect", Rect2())
		var pause_safe_rect: Rect2 = pause_overlay_snapshot.get("safe_rect", Rect2())
		if not smoke_layout.is_empty():
			var pause_viewport_rect: Rect2 = smoke_layout.get("viewport_rect", Rect2())
			var expected_pause_safe_rect: Rect2 = smoke_layout.get("safe_rect", pause_viewport_rect)
			_assert_true(
				pause_root_rect.position.distance_to(pause_viewport_rect.position) < 0.01 and pause_root_rect.size.distance_to(pause_viewport_rect.size) < 0.01,
				"pause overlay root matches the viewport",
				"%s %s" % [pause_root_rect, pause_viewport_rect]
			)
			_assert_true(
				pause_safe_rect.position.distance_to(expected_pause_safe_rect.position) < 0.01 and pause_safe_rect.size.distance_to(expected_pause_safe_rect.size) < 0.01,
				"pause overlay tracks the responsive safe rect",
				"%s %s" % [pause_safe_rect, expected_pause_safe_rect]
			)
			_assert_true(_rect_contains_rect(expected_pause_safe_rect, pause_panel_rect), "pause panel stays inside the safe area", "%s %s" % [pause_panel_rect, expected_pause_safe_rect])
			var expected_pause_panel_center: Vector2 = expected_pause_safe_rect.get_center() - Vector2(0.0, 100.0)
			_assert_true(
				absf(pause_panel_rect.get_center().x - expected_pause_panel_center.x) <= 1.0 and absf(pause_panel_rect.get_center().y - expected_pause_panel_center.y) <= 1.0,
				"pause panel stays centered on screen with the raised offset",
				"%s %s" % [pause_panel_rect, expected_pause_panel_center]
			)
		_assert_true(smoke_coordinator.are_controls_visible(), "show-controls defaults on", str(smoke_coordinator.are_controls_visible()))
		_assert_true(not smoke_coordinator.are_defenders_disabled(), "no-defenders defaults off", str(smoke_coordinator.are_defenders_disabled()))
		smoke_coordinator.test_set_controls_visible(false)
		_assert_true(not smoke_coordinator.are_controls_visible(), "pause toggle hides visible controls", str(smoke_coordinator.are_controls_visible()))
		_assert_true(smoke_coordinator.control_panel != null and not smoke_coordinator.control_panel.visible, "control panel hides when show-controls is off", str(smoke_coordinator.control_panel.visible if smoke_coordinator.control_panel != null else true))
		_assert_true(smoke_coordinator.hud != null and smoke_coordinator.hud.visible and smoke_coordinator.hud.get_layout_snapshot().get("scoreboard_rect", Rect2()).size.x > 0.0, "show-controls toggle leaves the scoreboard visible", str(smoke_coordinator.hud.get_layout_snapshot().get("scoreboard_rect", Rect2()) if smoke_coordinator.hud != null else Rect2()))
		_assert_true(smoke_coordinator.hud != null and smoke_coordinator.hud.visible and smoke_coordinator.hud.get_layout_snapshot().get("pause_rect", Rect2()).size.x > 0.0, "show-controls toggle leaves the pause button visible", str(smoke_coordinator.hud.get_layout_snapshot().get("pause_rect", Rect2()) if smoke_coordinator.hud != null else Rect2()))
		smoke_coordinator.test_set_controls_visible(true)
		_assert_true(smoke_coordinator.are_controls_visible(), "pause toggle re-shows visible controls", str(smoke_coordinator.are_controls_visible()))
		_assert_true(smoke_coordinator.control_panel != null and smoke_coordinator.control_panel.visible, "control panel shows again after the pause toggle", str(smoke_coordinator.control_panel.visible if smoke_coordinator.control_panel != null else false))
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
			var finish_center_world: Vector2 = _get_finish_logic_center_world(smoke_coordinator)
			no_defender_pg.world_position = finish_center_world + Vector2(20.0, 118.0)
			var no_defender_layout: Dictionary = smoke_coordinator._build_shot_release_visual_decision(no_defender_pg, Vector2(0.0, -140.0), INF, "shot_layout")
			var no_defender_dunk: Dictionary = smoke_coordinator._build_shot_release_visual_decision(no_defender_pg, Vector2(0.0, -140.0), INF, "dunk")
			_assert_true(str(no_defender_layout.get("family", "")) == "close_finish_layup", "shoot intent stays on layup even with no defenders", JSON.stringify(no_defender_layout))
			_assert_true(bool(no_defender_dunk.get("force_no_defenders_dunk", false)), "dunk intent still records the no-defenders dunk override", JSON.stringify(no_defender_dunk))
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
		var smoke_layout_snapshot: Dictionary = smoke_coordinator.get_layout_metrics_snapshot()
		var smoke_control_rect: Rect2 = smoke_layout_snapshot.get("control_panel_rect", Rect2())
		var smoke_control_zones: Dictionary = smoke_layout_snapshot.get("control_zone_rects", {})
		var smoke_viewport_rect: Rect2 = smoke_layout_snapshot.get("viewport_rect", Rect2())
		var smoke_safe_rect_for_controls: Rect2 = smoke_layout_snapshot.get("safe_rect", smoke_viewport_rect)
		var smoke_pass_left_rect: Rect2 = smoke_control_zones.get("pass_left", Rect2())
		var smoke_pass_right_rect: Rect2 = smoke_control_zones.get("pass_right", Rect2())
		var smoke_shoot_rect: Rect2 = smoke_control_zones.get("shoot", Rect2())
		var smoke_dunk_rect: Rect2 = smoke_control_zones.get("dunk", Rect2())
		var smoke_move_rect: Rect2 = smoke_control_zones.get("move", Rect2())
		_assert_true(smoke_coordinator.control_panel != null and smoke_coordinator.control_panel.visible, "bottom control panel is visible by default", str(smoke_coordinator.control_panel.visible if smoke_coordinator.control_panel != null else false))
		var expected_compact_control_height: float = smoke_safe_rect_for_controls.size.y * 0.24
		var expected_compact_bottom_gap: float = 16.0 * float(smoke_layout_snapshot.get("ui_scale", 1.0))
		_assert_true(absf(smoke_control_rect.size.y - expected_compact_control_height) <= maxf(1.0, smoke_safe_rect_for_controls.size.y * 0.01), "control panel occupies the compact lower quarter of the safe viewport", "%s %s" % [smoke_control_rect, smoke_safe_rect_for_controls])
		_assert_true(absf(smoke_safe_rect_for_controls.end.y - smoke_control_rect.end.y - expected_compact_bottom_gap) <= 1.0, "control panel remains bottom anchored above the safe margin", "%s %s" % [smoke_control_rect, smoke_safe_rect_for_controls])
		_assert_true(not smoke_control_zones.is_empty() and smoke_control_zones.has("move") and smoke_control_zones.has("shoot") and smoke_control_zones.has("dunk"), "control panel exposes authored zone rects", JSON.stringify(smoke_control_zones.keys()))
		_assert_true(absf(smoke_shoot_rect.size.x - smoke_dunk_rect.size.x) < 0.01, "shoot and dunk split the top row evenly", "%s %s" % [smoke_shoot_rect, smoke_dunk_rect])
		_assert_true(absf(smoke_shoot_rect.position.y - smoke_dunk_rect.position.y) < 0.01 and absf(smoke_shoot_rect.size.y - smoke_dunk_rect.size.y) < 0.01, "shoot and dunk share the same top-row band", "%s %s" % [smoke_shoot_rect, smoke_dunk_rect])
		_assert_true(absf(smoke_shoot_rect.end.x - smoke_dunk_rect.position.x) < 0.01, "shoot and dunk meet directly with no bottom-band carryover gap", "%s %s" % [smoke_shoot_rect, smoke_dunk_rect])
		_assert_true(smoke_dunk_rect.position.y < smoke_move_rect.position.y, "dunk stays in the top row above the move lane", "%s %s" % [smoke_dunk_rect, smoke_move_rect])
		_assert_true(smoke_move_rect.size.y > smoke_shoot_rect.size.y, "move row is taller than the shoot and dunk row", "%s %s" % [smoke_move_rect, smoke_shoot_rect])
		_assert_true(absf(smoke_pass_left_rect.size.x - smoke_pass_right_rect.size.x) < 0.01, "pass lanes keep matched widths", "%s %s" % [smoke_pass_left_rect, smoke_pass_right_rect])
		_assert_true(smoke_move_rect.size.x > smoke_pass_left_rect.size.x and smoke_move_rect.size.x > smoke_pass_right_rect.size.x, "move lane is wider than either pass lane", "%s %s %s" % [smoke_move_rect, smoke_pass_left_rect, smoke_pass_right_rect])
		if smoke_coordinator.control_panel != null and smoke_coordinator.control_panel.has_method("get_label_font_size_snapshot"):
			var compact_label_fonts: Dictionary = smoke_coordinator.control_panel.call("get_label_font_size_snapshot")
			var main_label_fonts_capped: bool = true
			for label_key in ["shoot", "move", "pass_left", "pass_right", "dunk"]:
				main_label_fonts_capped = main_label_fonts_capped and int(compact_label_fonts.get(label_key, 999)) <= 34
			var focus_label_fonts_capped: bool = int(compact_label_fonts.get("pass_left_focus", 999)) <= 16 and int(compact_label_fonts.get("pass_right_focus", 999)) <= 16
			_assert_true(main_label_fonts_capped, "main control labels stay capped for compact controls", JSON.stringify(compact_label_fonts))
			_assert_true(focus_label_fonts_capped, "pass focus labels stay capped for compact controls", JSON.stringify(compact_label_fonts))
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
	var hidden_controls_target: PlayerController = smoke_coordinator.default_pass_target
	smoke_coordinator.test_set_controls_visible(false)
	_assert_true(not smoke_coordinator.control_panel.visible, "hidden controls only affect presentation", str(smoke_coordinator.control_panel.visible))
	smoke_coordinator.input_controller.tap_test_pass(Vector2(900.0, 640.0), 0.05)
	var hidden_controls_pass_snapshot: Dictionary = smoke_coordinator.pass_controller.get_active_pass_snapshot()
	_assert_true(
		smoke_coordinator.context.current_state == GameState.State.PASS_IN_FLIGHT and hidden_controls_pass_snapshot.get("intended_receiver", null) == hidden_controls_target,
		"pass hitboxes stay active while the visible controls are hidden",
		str(hidden_controls_pass_snapshot.get("intended_receiver", null))
	)
	smoke_coordinator.test_set_controls_visible(true)
	_reset_visual_test_state(smoke_coordinator)
	var smoke_control_layout: Dictionary = smoke_coordinator.input_controller.get_control_layout_snapshot()
	var smoke_layout_for_meter: Dictionary = smoke_coordinator.get_layout_metrics_snapshot()
	var smoke_safe_rect_for_meter: Rect2 = smoke_layout_for_meter.get("safe_rect", Rect2())
	var smoke_control_zone_rects: Dictionary = smoke_control_layout.get("control_zone_rects", {})
	var smoke_move_center: Vector2 = smoke_control_zone_rects.get("move", Rect2()).get_center()
	var smoke_shoot_center: Vector2 = smoke_control_zone_rects.get("shoot", Rect2()).get_center()
	var smoke_shoot_rect_for_meter: Rect2 = smoke_control_zone_rects.get("shoot", Rect2())
	if smoke_coordinator.control_panel != null:
		smoke_coordinator.control_panel.set_panel_state(smoke_coordinator._build_control_panel_state())
		var neutral_shoot_visual: Dictionary = smoke_coordinator.control_panel.get_zone_visual_state_snapshot("shoot")
		var neutral_move_visual: Dictionary = smoke_coordinator.control_panel.get_zone_visual_state_snapshot("move")
		var neutral_pass_visual: Dictionary = smoke_coordinator.control_panel.get_zone_visual_state_snapshot("pass_right")
		var neutral_dunk_visual: Dictionary = smoke_coordinator.control_panel.get_zone_visual_state_snapshot("dunk")
		_assert_true(
			str(neutral_shoot_visual.get("base_color_html", "")) == "1b1d3a"
				and str(neutral_move_visual.get("base_color_html", "")) == "1b1d3a"
				and str(neutral_pass_visual.get("base_color_html", "")) == "1b1d3a"
				and bool(neutral_dunk_visual.get("disabled", false))
				and str(neutral_dunk_visual.get("base_color_html", "")) != "1b1d3a",
			"control panel keeps active buttons neutral while tinting dunk disabled when no close finish is available",
			str({
				"shoot": neutral_shoot_visual,
				"move": neutral_move_visual,
				"pass": neutral_pass_visual,
				"dunk": neutral_dunk_visual,
			})
		)
	smoke_coordinator.input_controller.begin_test_live_gesture(smoke_move_center)
	smoke_coordinator.input_controller.update_test_live_gesture(smoke_shoot_center)
	if smoke_coordinator.control_panel != null:
		smoke_coordinator.control_panel.set_panel_state(smoke_coordinator._build_control_panel_state())
		var hover_shoot_visual: Dictionary = smoke_coordinator.control_panel.get_zone_visual_state_snapshot("shoot")
		_assert_true(
			bool(hover_shoot_visual.get("highlighted", false))
				and str(hover_shoot_visual.get("base_color_html", "")) != "1b1d3a",
			"drag-hover swaps the hovered action button from the neutral base into its colored state",
			str(hover_shoot_visual)
		)
	smoke_coordinator.input_controller.end_test_live_gesture(smoke_move_center)
	var direct_pass_target: PlayerController = smoke_coordinator.default_pass_target
	smoke_coordinator.input_controller.tap_test_control_button("pass_right", 0.05, -92)
	var direct_pass_snapshot: Dictionary = smoke_coordinator.pass_controller.get_active_pass_snapshot()
	_assert_true(
		smoke_coordinator.context.current_state == GameState.State.PASS_IN_FLIGHT and direct_pass_snapshot.get("intended_receiver", null) == direct_pass_target,
		"direct pass button tap starts a live pass without movement",
		str(direct_pass_snapshot.get("intended_receiver", null))
	)
	_reset_visual_test_state(smoke_coordinator)
	smoke_coordinator.input_controller.begin_test_live_gesture(smoke_move_center)
	var second_finger_pass_target: PlayerController = smoke_coordinator.default_pass_target
	smoke_coordinator.input_controller.tap_test_control_button("pass_right", 0.05, -91)
	var second_finger_pass_snapshot: Dictionary = smoke_coordinator.pass_controller.get_active_pass_snapshot()
	_assert_true(
		smoke_coordinator.context.current_state == GameState.State.PASS_IN_FLIGHT and second_finger_pass_snapshot.get("intended_receiver", null) == second_finger_pass_target,
		"second-finger pass button tap works while the move drag is active",
		str(second_finger_pass_snapshot.get("intended_receiver", null))
	)
	_reset_visual_test_state(smoke_coordinator)
	smoke_coordinator.input_controller.tap_test_control_button("shoot", 0.05, -90)
	await get_tree().process_frame
	_assert_true(smoke_coordinator.context.current_state == GameState.State.SHOT_AIM, "shoot button tap enters shot aim without movement", smoke_coordinator.get_state_name())
	var direct_shoot_player: PlayerController = smoke_coordinator.current_ballhandler
	if direct_shoot_player != null:
		_assert_true(direct_shoot_player.get_debug_animation_family() == "shot_aim", "direct shoot button first tap holds aim pose instead of starting the release row", direct_shoot_player.get_debug_animation_family())
	_assert_true(smoke_coordinator.pending_shot_release.is_empty(), "direct shoot button first tap does not stage a shot release", JSON.stringify(smoke_coordinator.pending_shot_release))
	_assert_true(bool(smoke_court_view.shot_meter.get("visible", false)), "direct shoot button first tap shows the timing meter", JSON.stringify(smoke_court_view.shot_meter))
	if smoke_coordinator.control_panel != null:
		smoke_coordinator.control_panel.set_panel_state(smoke_coordinator._build_control_panel_state())
		var pressed_shoot_visual: Dictionary = smoke_coordinator.control_panel.get_zone_visual_state_snapshot("shoot")
		_assert_true(
			bool(pressed_shoot_visual.get("highlighted", false))
				and str(pressed_shoot_visual.get("base_color_html", "")) != "1b1d3a",
			"direct button taps briefly paint the pressed action button with its colored state",
			str(pressed_shoot_visual)
		)
		var panel_meter_rect: Rect2 = smoke_coordinator.control_panel.get_shot_meter_bar_rect_snapshot()
		_assert_true(panel_meter_rect.size.x > smoke_shoot_rect_for_meter.size.x, "control-panel shot meter spans beyond the shoot button into the dunk half", "%s %s" % [panel_meter_rect, smoke_shoot_rect_for_meter])
		_assert_true(_rect_contains_rect(smoke_safe_rect_for_meter, panel_meter_rect), "control-panel shot meter stays inside the safe area", "%s %s" % [panel_meter_rect, smoke_safe_rect_for_meter])
		_assert_true(absf(panel_meter_rect.get_center().x - smoke_safe_rect_for_meter.get_center().x) <= 1.0 and absf(panel_meter_rect.get_center().y - smoke_safe_rect_for_meter.get_center().y) <= 1.0, "control-panel shot meter centers in the middle of the safe viewport during shot aim", "%s %s" % [panel_meter_rect, smoke_safe_rect_for_meter])
	for _direct_shoot_hold_frame in 25:
		await get_tree().process_frame
	_assert_true(smoke_coordinator.context.current_state == GameState.State.SHOT_AIM, "direct shoot button timing waits for a second tap past the authored release frame", smoke_coordinator.get_state_name())
	_assert_true(smoke_coordinator.pending_shot_release.is_empty(), "direct shoot button timing still has no pending release before the second tap", JSON.stringify(smoke_coordinator.pending_shot_release))
	smoke_coordinator.input_controller.tap_test_shot_timing(smoke_shoot_center)
	await get_tree().process_frame
	_assert_true(smoke_coordinator.context.current_state == GameState.State.SHOT_RELEASE, "direct shoot button second tap commits the shot release", smoke_coordinator.get_state_name())
	_assert_true(not smoke_coordinator.pending_shot_release.is_empty(), "direct shoot button second tap stages a pending shot release", JSON.stringify(smoke_coordinator.pending_shot_release))
	_assert_true(str(smoke_coordinator.active_shot_sequence.get("shot_timing_mode", "")) == "direct_shoot_button", "direct shoot button keeps its isolated timing mode through release", JSON.stringify(smoke_coordinator.active_shot_sequence))
	_reset_visual_test_state(smoke_coordinator)
	smoke_coordinator.input_controller.swipe_test_shot_arm(smoke_move_center, smoke_shoot_center, 0.12)
	_assert_true(smoke_coordinator.context.current_state == GameState.State.SHOT_AIM, "shoot-band release enters shot aim", smoke_coordinator.get_state_name())
	_reset_visual_test_state(smoke_coordinator)
	smoke_coordinator.input_controller.swipe_test_dunk_arm(0.12)
	_assert_true(smoke_coordinator.context.current_state == GameState.State.LIVE_OFFENSE, "dunk-band release far from the hoop is ignored", smoke_coordinator.get_state_name())
	var finish_logic_center_world: Vector2 = _get_finish_logic_center_world(smoke_coordinator)
	var layout_lc: PlayerController = smoke_coordinator.get_offense_player_by_role("LC")
	var layout_pg: PlayerController = smoke_coordinator.get_offense_player_by_role("PG")
	if layout_lc != null:
		layout_lc.world_position = finish_logic_center_world + Vector2(18.0, 108.0)
		layout_lc.velocity = (finish_logic_center_world - layout_lc.world_position).normalized() * 150.0
		smoke_coordinator._set_ballhandler(layout_lc)
		if smoke_coordinator.control_panel != null:
			smoke_coordinator.control_panel.set_panel_state(smoke_coordinator._build_control_panel_state())
			var available_dunk_visual: Dictionary = smoke_coordinator.control_panel.get_zone_visual_state_snapshot("dunk")
			_assert_true(
				not bool(available_dunk_visual.get("disabled", true)),
				"dunk button re-enables when the current ballhandler has a live close-finish action",
				str(available_dunk_visual)
			)
		var layup_from_shoot: Dictionary = smoke_coordinator._build_shot_release_visual_decision(layout_lc, Vector2(0.0, -150.0), INF, "shot_layout")
		var dunk_from_dunk: Dictionary = smoke_coordinator._build_shot_release_visual_decision(layout_lc, Vector2(0.0, -150.0), INF, "dunk")
		_assert_true(str(layup_from_shoot.get("family", "")) == "close_finish_layup", "shoot intent near the rim resolves as a layup instead of a dunk", JSON.stringify(layup_from_shoot))
		_assert_true(str(dunk_from_dunk.get("family", "")) == "close_finish_dunk", "dunk intent near the rim resolves as a dunk when eligible", JSON.stringify(dunk_from_dunk))
	if layout_pg != null:
		smoke_coordinator._set_ballhandler(layout_pg)
		layout_pg.world_position = finish_logic_center_world + Vector2(18.0, 118.0)
		var fallback_layup: Dictionary = smoke_coordinator._build_shot_release_visual_decision(layout_pg, Vector2(0.0, -140.0), INF, "dunk")
		var far_dunk_ignored: Dictionary
		layout_pg.world_position = Vector2(540.0, 1360.0)
		far_dunk_ignored = smoke_coordinator._build_shot_release_visual_decision(layout_pg, Vector2(0.0, -140.0), INF, "dunk")
		_assert_true(str(fallback_layup.get("family", "")) == "close_finish_layup", "dunk intent falls back to layup when only the close-finish gates pass", JSON.stringify(fallback_layup))
		_assert_true(not bool(far_dunk_ignored.get("allowed", true)), "dunk intent far from the hoop does not arm a jumper", JSON.stringify(far_dunk_ignored))
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
		visual_rc.velocity = Vector2.ZERO
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
			_assert_player_visual(visual_rc, "off_ball_shuffle", 19, false, false, "off-ball shuffle starts on any movement")
			visual_rc.velocity = Vector2.ZERO
			smoke_coordinator._sync_projection_visuals(0.0)
			_assert_player_visual(visual_rc, "no_ball_idle", 1, false, false, "off-ball idle only when fully stopped")
			visual_rc.velocity = Vector2.RIGHT * 44.0
			smoke_coordinator._sync_projection_visuals(0.0)
			_assert_player_visual(visual_rc, "off_ball_shuffle", 19, false, false, "off-ball shuffle")
			smoke_coordinator.player_visual_memory[visual_rc] = {"family": "off_ball_shuffle", "variant_index": 0, "mirror_west": false}
			visual_rc.velocity = Vector2.RIGHT * (smoke_coordinator.player_animation_config.stationary_speed_release_threshold + 2.0)
			smoke_coordinator._sync_projection_visuals(0.0)
			_assert_player_visual(visual_rc, "off_ball_shuffle", 19, false, false, "off-ball shuffle holds above idle exit")
			smoke_coordinator.player_visual_memory[visual_rc] = {"family": "off_ball_shuffle", "variant_index": 0, "mirror_west": false}
			visual_rc.velocity = Vector2.RIGHT * (smoke_coordinator.player_animation_config.stationary_speed_release_threshold - 1.0)
			smoke_coordinator._sync_projection_visuals(0.0)
			_assert_player_visual(visual_rc, "off_ball_shuffle", 19, false, false, "off-ball shuffle persists on sub-threshold movement")
			smoke_coordinator.player_visual_memory[visual_rc] = {"family": "off_ball_run", "variant_index": 0, "mirror_west": false}
			visual_rc.velocity = Vector2.RIGHT * (smoke_coordinator.player_animation_config.small_move_speed_release_threshold + 4.0)
			smoke_coordinator._sync_projection_visuals(0.0)
			_assert_player_visual(visual_rc, "off_ball_run", 20, false, false, "off-ball run holds above run exit")
			smoke_coordinator.player_visual_memory[visual_rc] = {"family": "off_ball_shuffle", "variant_index": 0, "mirror_west": false}
			visual_rc.velocity = Vector2.RIGHT * (smoke_coordinator.player_animation_config.small_move_speed_threshold - 4.0)
			smoke_coordinator._sync_projection_visuals(0.0)
			_assert_player_visual(visual_rc, "off_ball_shuffle", 19, false, false, "off-ball shuffle holds below run enter")
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
			var finish_center_world: Vector2 = _get_finish_logic_center_world(smoke_coordinator)
			visual_lc_preview.world_position = finish_center_world + Vector2(20.0, 130.0)
			visual_lc_preview.velocity = (finish_center_world - visual_lc_preview.world_position).normalized() * 180.0
			smoke_coordinator.current_move_direction = (finish_center_world - visual_lc_preview.world_position).normalized()
			smoke_coordinator.current_move_magnitude = 1.0
			visual_lc_preview.trigger_shot_pose(0.28)
			smoke_coordinator.player_visual_memory.erase(visual_lc_preview)
			smoke_coordinator._sync_projection_visuals(0.0)
			_assert_player_visual(visual_lc_preview, "close_finish_layup", 14, true, true, "straight layup")
			visual_lc_preview.world_position = finish_center_world + Vector2(80.0, 80.0)
			visual_lc_preview.velocity = (finish_center_world - visual_lc_preview.world_position).normalized() * 190.0
			smoke_coordinator.current_move_direction = (finish_center_world - visual_lc_preview.world_position).normalized()
			smoke_coordinator.current_move_magnitude = 1.0
			visual_lc_preview.trigger_shot_pose(0.28)
			smoke_coordinator.player_visual_memory.erase(visual_lc_preview)
			smoke_coordinator._sync_projection_visuals(0.0)
			_assert_player_visual(visual_lc_preview, "close_finish_layup", 17, true, true, "side layup")
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
			var finish_center_world: Vector2 = _get_finish_logic_center_world(smoke_coordinator)
			visual_pg.world_position = finish_center_world + Vector2(18.0, 170.0)
			visual_pg.velocity = (finish_center_world - visual_pg.world_position).normalized() * 150.0
			await _begin_release_test_shot(smoke_coordinator, visual_pg)
			_assert_player_visual(visual_pg, "close_finish_layup", 14, false, true, "straight layup release")
			_assert_release_profile(visual_pg, 9, "straight layup")
		_reset_visual_test_state(smoke_coordinator, "PG", 2421)
		visual_pg = smoke_coordinator.get_offense_player_by_role("PG")
		visual_pg_defender = smoke_coordinator.get_defense_player_by_role("PG")
		if visual_pg != null and visual_pg_defender != null:
			var finish_center_world: Vector2 = _get_finish_logic_center_world(smoke_coordinator)
			visual_pg.world_position = finish_center_world + Vector2(86.0, 164.0)
			visual_pg.velocity = (finish_center_world - visual_pg.world_position).normalized() * 150.0
			await _begin_release_test_shot(smoke_coordinator, visual_pg)
			_assert_player_visual(visual_pg, "close_finish_layup", 17, true, true, "side layup release")
			_assert_release_profile(visual_pg, 11, "side layup")
		_reset_visual_test_state(smoke_coordinator, "PG", 2422)
		visual_pg = smoke_coordinator.get_offense_player_by_role("PG")
		if visual_pg != null:
			var finish_center_world: Vector2 = _get_finish_logic_center_world(smoke_coordinator)
			visual_pg.world_position = finish_center_world + Vector2(22.0, 118.0)
			visual_pg.velocity = (finish_center_world - visual_pg.world_position).normalized() * 190.0
			await _begin_release_test_shot(smoke_coordinator, visual_pg)
			_assert_player_visual(visual_pg, "close_finish_layup", 14, true, true, "low dunk rating falls back to layup")
			_assert_release_profile(visual_pg, 9, "low dunk straight layup")
		_reset_visual_test_state(smoke_coordinator, "LC", 2423)
		var visual_lc: PlayerController = smoke_coordinator.get_offense_player_by_role("LC")
		if visual_lc != null:
			var finish_center_world: Vector2 = _get_finish_logic_center_world(smoke_coordinator)
			visual_lc.world_position = finish_center_world + Vector2(22.0, 118.0)
			visual_lc.velocity = (finish_center_world - visual_lc.world_position).normalized() * 80.0
			await _begin_release_test_shot(smoke_coordinator, visual_lc)
			_assert_player_visual(visual_lc, "close_finish_layup", 14, true, true, "insufficient dunk speed falls back to layup")
			_assert_release_profile(visual_lc, 9, "slow straight layup")
		_reset_visual_test_state(smoke_coordinator, "LC", 2424)
		visual_lc = smoke_coordinator.get_offense_player_by_role("LC")
		if visual_lc != null:
			var finish_center_world: Vector2 = _get_finish_logic_center_world(smoke_coordinator)
			visual_lc.world_position = finish_center_world + Vector2(22.0, 118.0)
			var dunk_motion: Vector2 = (finish_center_world - visual_lc.world_position).normalized() * 190.0
			var far_defender_finish: Dictionary = smoke_coordinator._build_shot_release_visual_decision(visual_lc, dunk_motion, 260.0, "dunk")
			var near_defender_finish: Dictionary = smoke_coordinator._build_shot_release_visual_decision(visual_lc, dunk_motion, 12.0, "dunk")
			_assert_true(str(far_defender_finish.get("family", "")) == "close_finish_dunk", "high dunk player in dunk radius chooses dunk", JSON.stringify(far_defender_finish))
			_assert_true(bool(far_defender_finish.get("close_finish_eligible", false)), "high dunk player is close-finish eligible", JSON.stringify(far_defender_finish))
			_assert_true(bool(far_defender_finish.get("dunk_eligible", false)), "high dunk player is dunk eligible", JSON.stringify(far_defender_finish))
			_assert_true(str(near_defender_finish.get("family", "")) == str(far_defender_finish.get("family", "")), "defender distance does not change selected finish family", "%s %s" % [JSON.stringify(far_defender_finish), JSON.stringify(near_defender_finish)])

		var straight_dunk_profiles: Dictionary = {}
		for straight_dunk_seed in [2425, 2426, 2427, 2428, 2429, 2430, 2431, 2432, 2433, 2434]:
			_reset_visual_test_state(smoke_coordinator, "LC", straight_dunk_seed)
			visual_lc = smoke_coordinator.get_offense_player_by_role("LC")
			if visual_lc != null:
				var finish_center_world: Vector2 = _get_finish_logic_center_world(smoke_coordinator)
				visual_lc.world_position = finish_center_world + Vector2(22.0, 118.0)
				visual_lc.velocity = (finish_center_world - visual_lc.world_position).normalized() * 190.0
				await _begin_release_test_shot(smoke_coordinator, visual_lc, 12, "dunk")
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
		if straight_dunk_profiles.has(13):
			_assert_true(int(straight_dunk_profiles[13]) == 10, "straight dunk row 13 release frame", str(straight_dunk_profiles[13]))
		if straight_dunk_profiles.has(15):
			_assert_true(int(straight_dunk_profiles[15]) == 11, "straight dunk row 15 release frame", str(straight_dunk_profiles[15]))
		_reset_visual_test_state(smoke_coordinator, "LC", 2426)
		visual_lc = smoke_coordinator.get_offense_player_by_role("LC")
		if visual_lc != null:
			var finish_center_world: Vector2 = _get_finish_logic_center_world(smoke_coordinator)
			visual_lc.world_position = finish_center_world + Vector2(0.0, 90.0)
			visual_lc.velocity = (finish_center_world - visual_lc.world_position).normalized() * 190.0
			await _begin_release_test_shot(smoke_coordinator, visual_lc, 12, "dunk")
			_assert_true(int(smoke_coordinator.active_shot_sequence.get("approach_start_frame", -1)) == 8, "short straight dunk starts at jump frames", JSON.stringify(smoke_coordinator.active_shot_sequence))
			_assert_true(str(smoke_coordinator.active_shot_sequence.get("approach_bucket", "")) == "short", "short straight dunk bucket", JSON.stringify(smoke_coordinator.active_shot_sequence))
		_reset_visual_test_state(smoke_coordinator, "LC", 2426)
		visual_lc = smoke_coordinator.get_offense_player_by_role("LC")
		if visual_lc != null:
			var finish_center_world: Vector2 = _get_finish_logic_center_world(smoke_coordinator)
			visual_lc.world_position = finish_center_world + Vector2(0.0, 120.0)
			visual_lc.velocity = (finish_center_world - visual_lc.world_position).normalized() * 190.0
			await _begin_release_test_shot(smoke_coordinator, visual_lc, 12, "dunk")
			_assert_true(int(smoke_coordinator.active_shot_sequence.get("approach_start_frame", -1)) == 5, "medium straight dunk starts with three run frames", JSON.stringify(smoke_coordinator.active_shot_sequence))
			_assert_true(str(smoke_coordinator.active_shot_sequence.get("approach_bucket", "")) == "max", "medium straight dunk threshold bucket", JSON.stringify(smoke_coordinator.active_shot_sequence))
		_reset_visual_test_state(smoke_coordinator, "LC", 2426)
		visual_lc = smoke_coordinator.get_offense_player_by_role("LC")
		if visual_lc != null:
			var finish_center_world: Vector2 = _get_finish_logic_center_world(smoke_coordinator)
			visual_lc.world_position = finish_center_world + Vector2(80.0, 108.7428)
			visual_lc.velocity = (finish_center_world - visual_lc.world_position).normalized() * 190.0
			await _begin_release_test_shot(smoke_coordinator, visual_lc, 12, "dunk")
			var side_dunk_family: String = str(smoke_coordinator.active_shot_sequence.get("family", ""))
			var side_dunk_variant: int = int(smoke_coordinator.active_shot_sequence.get("variant_index", 0))
			var side_dunk_row: int = PlayerVisual.get_row_index_for_family_variant(side_dunk_family, side_dunk_variant)
			var side_dunk_timing_profile: Dictionary = smoke_coordinator.active_shot_sequence.get("timing_profile", {})
			_assert_true(side_dunk_family == "close_finish_side_dunk", "side dunk family", side_dunk_family)
			_assert_true(side_dunk_row == 16, "side dunk row", str(side_dunk_row))
			_assert_true(bool(smoke_coordinator.active_shot_sequence.get("mirror_west", false)), "side dunk flip", str(smoke_coordinator.active_shot_sequence.get("mirror_west", false)))
			_assert_true(int(side_dunk_timing_profile.get("release_after_frame", -1)) == 11, "side dunk release frame", str(side_dunk_timing_profile.get("release_after_frame", -1)))
			_assert_true(int(smoke_coordinator.active_shot_sequence.get("approach_start_frame", -1)) == 1, "max side dunk keeps full approach", JSON.stringify(smoke_coordinator.active_shot_sequence))
			_assert_true(str(smoke_coordinator.active_shot_sequence.get("approach_bucket", "")) == "max", "max side dunk bucket", JSON.stringify(smoke_coordinator.active_shot_sequence))
		await _assert_dunk_hold_anchor_consistency(smoke_coordinator, 13, "LC", [2425, 2426, 2427, 2428, 2429, 2430, 2431, 2432, 2433, 2434], [Vector2(0.0, 135.0), Vector2(0.0, 120.0), Vector2(0.0, 90.0)], "row 13 dunk hold")
		await _assert_dunk_hold_anchor_consistency(smoke_coordinator, 15, "LC", [2425, 2426, 2427, 2428, 2429, 2430, 2431, 2432, 2433, 2434], [Vector2(0.0, 135.0), Vector2(0.0, 120.0), Vector2(0.0, 90.0)], "row 15 dunk hold")
		await _assert_dunk_hold_anchor_consistency(smoke_coordinator, 16, "LC", [2426, 2427, 2428], [Vector2(80.0, 108.7428), Vector2(80.0, 89.4427), Vector2(80.0, 41.2311)], "row 16 dunk hold")
		await _assert_dunk_root_motion_trace_consistency(smoke_coordinator, 13, "LC", [2425, 2426, 2427, 2428, 2429, 2430, 2431, 2432, 2433, 2434], [Vector2(0.0, 135.0)], "row 13 max root motion", 1, "max", 2)
		await _assert_dunk_root_motion_trace_consistency(smoke_coordinator, 13, "LC", [2425, 2426, 2427, 2428, 2429, 2430, 2431, 2432, 2433, 2434], [Vector2(0.0, 120.0)], "row 13 medium root motion", 5, "max", 2)
		await _assert_dunk_root_motion_trace_consistency(smoke_coordinator, 13, "LC", [2425, 2426, 2427, 2428, 2429, 2430, 2431, 2432, 2433, 2434], [Vector2(0.0, 90.0)], "row 13 short root motion", 8, "short", 2)
		await _assert_dunk_root_motion_trace_consistency(smoke_coordinator, 15, "LC", [2425, 2426, 2427, 2428, 2429, 2430, 2431, 2432, 2433, 2434], [Vector2(0.0, 135.0)], "row 15 max root motion", 1, "max", 2)
		await _assert_dunk_root_motion_trace_consistency(smoke_coordinator, 15, "LC", [2425, 2426, 2427, 2428, 2429, 2430, 2431, 2432, 2433, 2434], [Vector2(0.0, 120.0)], "row 15 medium root motion", 5, "max", 2)
		await _assert_dunk_root_motion_trace_consistency(smoke_coordinator, 15, "LC", [2425, 2426, 2427, 2428, 2429, 2430, 2431, 2432, 2433, 2434], [Vector2(0.0, 90.0)], "row 15 short root motion", 8, "short", 2)
		await _assert_dunk_root_motion_trace_consistency(smoke_coordinator, 16, "LC", [2426, 2427, 2428], [Vector2(80.0, 108.7428)], "row 16 max root motion", 1, "max")
		await _assert_dunk_root_motion_trace_consistency(smoke_coordinator, 16, "LC", [2426, 2427, 2428], [Vector2(80.0, 89.4427)], "row 16 medium root motion", 5, "max")
		await _assert_dunk_root_motion_trace_consistency(smoke_coordinator, 16, "LC", [2426, 2427, 2428], [Vector2(80.0, 41.2311)], "row 16 short root motion", 8, "short")
		_reset_visual_test_state(smoke_coordinator, "LC", 2426)
		visual_lc = smoke_coordinator.get_offense_player_by_role("LC")
		if visual_lc != null:
			var finish_center_world: Vector2 = _get_finish_logic_center_world(smoke_coordinator)
			visual_lc.world_position = finish_center_world + Vector2(78.0, 110.0)
			visual_lc.velocity = (finish_center_world - visual_lc.world_position).normalized() * 190.0
			_arm_test_shot(smoke_coordinator, "dunk")
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
			var dunk_make_landing_motion_seen: bool = false
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
			_assert_true(dunk_make_hold_frames >= 10 and dunk_make_hold_frames <= 13, "dunk make keeps only a brief rim hold", str(dunk_make_hold_frames))
			_assert_true(dunk_make_launch_seen, "dunk make launches after the contact hold", smoke_coordinator.get_state_name())
			_assert_true(dunk_make_release_phase == BallSimulator.FLIGHT_PHASE_GUIDED_DESCENT, "dunk make starts in guided descent after release", dunk_make_release_phase)
			_assert_true(dunk_make_release_mode == ShotController.RELEASE_MODE_DUNK_MAKE_DROP, "dunk make uses straight-through release mode in smoke", dunk_make_release_mode)
			var dunk_make_peak_z: float = smoke_coordinator.ball_simulator.z
			var previous_dunk_make_world: Vector2 = visual_lc.world_position
			for _dunk_make_follow_frame in 32:
				if smoke_coordinator.context.current_state != GameState.State.SHOT_IN_FLIGHT:
					break
				dunk_make_peak_z = maxf(dunk_make_peak_z, smoke_coordinator.ball_simulator.z)
				await get_tree().process_frame
				if visual_lc.world_position.distance_to(previous_dunk_make_world) > 0.01:
					dunk_make_landing_motion_seen = true
				previous_dunk_make_world = visual_lc.world_position
			_assert_true(dunk_make_peak_z <= smoke_coordinator.court_config.rim_height + 0.01, "dunk make never rises above the rim after release", str(dunk_make_peak_z))
			_assert_true(dunk_make_landing_motion_seen, "dunk make keeps moving through the landing after launch", str(visual_lc.world_position))
		_reset_visual_test_state(smoke_coordinator, "LC", 2426)
		visual_lc = smoke_coordinator.get_offense_player_by_role("LC")
		if visual_lc != null:
			var finish_center_world: Vector2 = _get_finish_logic_center_world(smoke_coordinator)
			visual_lc.world_position = finish_center_world + Vector2(22.0, 118.0)
			visual_lc.velocity = (finish_center_world - visual_lc.world_position).normalized() * 190.0
			_arm_test_shot(smoke_coordinator, "dunk")
			await get_tree().process_frame
			_assert_true(smoke_coordinator.context.current_state == GameState.State.SHOT_RELEASE, "straight dunk also skips shot aim and stages release immediately", smoke_coordinator.get_state_name())
			_assert_true(not bool(smoke_court_view.shot_meter.get("visible", false)), "straight dunk never shows the shot meter", JSON.stringify(smoke_court_view.shot_meter))
			var straight_dunk_auto_action: Dictionary = smoke_coordinator.pending_shot_release.get("action", {})
			_assert_true(str(straight_dunk_auto_action.get("timing_result", "")) == "dunk_auto_make", "straight dunk uses auto-make timing instead of green tap timing", JSON.stringify(straight_dunk_auto_action))
			_assert_true(str(straight_dunk_auto_action.get("release_mode", "")) == ShotController.RELEASE_MODE_DUNK_MAKE_DROP, "straight dunk queues the make-drop release mode before launch", JSON.stringify(straight_dunk_auto_action))
			var straight_dunk_hold_started: bool = false
			var straight_dunk_launch_seen: bool = false
			var straight_dunk_release_mode: String = ""
			var straight_dunk_landing_motion_seen: bool = false
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
			var previous_straight_dunk_world: Vector2 = visual_lc.world_position
			for _straight_dunk_follow_frame in 32:
				if smoke_coordinator.context.current_state != GameState.State.SHOT_IN_FLIGHT:
					break
				straight_dunk_peak_z = maxf(straight_dunk_peak_z, smoke_coordinator.ball_simulator.z)
				await get_tree().process_frame
				if visual_lc.world_position.distance_to(previous_straight_dunk_world) > 0.01:
					straight_dunk_landing_motion_seen = true
				previous_straight_dunk_world = visual_lc.world_position
			_assert_true(straight_dunk_peak_z <= smoke_coordinator.court_config.rim_height + 0.01, "straight dunk never rises above the rim after release", str(straight_dunk_peak_z))
			_assert_true(straight_dunk_landing_motion_seen, "straight dunk keeps moving through the landing after launch", str(visual_lc.world_position))
		_reset_visual_test_state(smoke_coordinator, "LC", 2426)
		visual_lc = smoke_coordinator.get_offense_player_by_role("LC")
		var visual_lc_defender: PlayerController = smoke_coordinator.get_defense_player_by_role("LC")
		if visual_lc != null and visual_lc_defender != null:
			var finish_center_world: Vector2 = _get_finish_logic_center_world(smoke_coordinator)
			visual_lc.world_position = finish_center_world + Vector2(90.0, 80.0)
			visual_lc.velocity = (finish_center_world - visual_lc.world_position).normalized() * 190.0
			smoke_coordinator.current_move_direction = (finish_center_world - visual_lc.world_position).normalized()
			smoke_coordinator.current_move_magnitude = 1.0
			smoke_coordinator._begin_active_shot_sequence(visual_lc, "dunk")
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
	await _run_dunk_auto_finish_floor_smoke()
	await _run_opponent_sim_banner_smoke()
	await _run_score_banner_smoke()


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


func _run_opponent_sim_banner_smoke() -> void:
	var game_root_scene: PackedScene = load("res://scenes/GameRoot.tscn")
	var game_root: Node2D = game_root_scene.instantiate() as Node2D
	add_child(game_root)
	await get_tree().process_frame
	await get_tree().process_frame
	var smoke_coordinator: GameCoordinator = game_root.get_node("GameCoordinator") as GameCoordinator
	_assert_true(smoke_coordinator != null, "opponent sim banner smoke coordinator exists", "")
	if smoke_coordinator == null:
		game_root.queue_free()
		await get_tree().process_frame
		return
	smoke_coordinator.begin_test_mode(2206)
	smoke_coordinator.apply_test_setup(4, 6, 30.0)
	smoke_coordinator.opponent_sim_config.visual_step_min = 3
	smoke_coordinator.opponent_sim_config.visual_step_max = 3
	smoke_coordinator.opponent_sim_config.visual_step_duration = 1.0
	var away_before: int = smoke_coordinator.context.away_score
	var clock_before: float = smoke_coordinator.context.match_time_remaining
	smoke_coordinator.test_force_opponent_sim()
	await get_tree().process_frame
	var smoke_court_view: CourtView = game_root.get_node("CourtView") as CourtView
	_assert_true(smoke_court_view != null and smoke_court_view.has_method("get_bottom_hoop_snapshot"), "bottom hoop snapshot accessor exists", "")
	_assert_true(smoke_coordinator.has_method("get_opponent_sim_visual_snapshot"), "opponent sim visual snapshot accessor exists", "")
	var sequence_snapshot: Dictionary = smoke_coordinator.get_opponent_sim_sequence_snapshot()
	var visual_snapshot: Dictionary = _get_opponent_visual_snapshot(smoke_coordinator)
	var presentation_node: Node = game_root.get_node_or_null("Entities/OpponentSimPresentation")
	var bottom_hoop_snapshot: Dictionary = _get_bottom_hoop_snapshot(smoke_court_view)
	_assert_true(smoke_coordinator.context.current_state == GameState.State.OPPONENT_SIM, "opponent sim banner holds opponent sim state", smoke_coordinator.get_state_name())
	_assert_true(bool(sequence_snapshot.get("active", false)), "opponent sim banner sequence active", JSON.stringify(sequence_snapshot))
	var expected_action_count: int = 3 + (1 if int(sequence_snapshot.get("pending_points_scored", 0)) > 0 else 0)
	_assert_true(int(sequence_snapshot.get("action_count", 0)) == expected_action_count, "opponent sim banner uses configured step count", JSON.stringify(sequence_snapshot))
	_assert_true(int(sequence_snapshot.get("current_index", -1)) == 0, "opponent sim banner starts at first step", JSON.stringify(sequence_snapshot))
	_assert_true(smoke_coordinator.context.away_score == away_before, "opponent sim score deferred during banner", str(smoke_coordinator.context.away_score))
	_assert_true(absf(smoke_coordinator.context.match_time_remaining - clock_before) < 0.001, "opponent sim clock deferred during banner", str(smoke_coordinator.context.match_time_remaining))
	_assert_true(bool(visual_snapshot.get("active", false)), "opponent sim visual snapshot active", JSON.stringify(visual_snapshot))
	var visual_kind: String = str(visual_snapshot.get("current_kind", visual_snapshot.get("kind", "")))
	var visual_actor_role: String = str(visual_snapshot.get("current_actor_role", visual_snapshot.get("actor_role", "")))
	var visual_actor_team: String = str(visual_snapshot.get("current_actor_team", visual_snapshot.get("actor_team", "")))
	_assert_true(visual_kind.strip_edges() != "", "opponent sim visual snapshot exposes current kind", JSON.stringify(visual_snapshot))
	_assert_true(visual_actor_role.strip_edges() != "", "opponent sim visual snapshot exposes current actor role", JSON.stringify(visual_snapshot))
	_assert_true(visual_actor_team.strip_edges() != "", "opponent sim visual snapshot exposes current actor team", JSON.stringify(visual_snapshot))
	_assert_true(bool(visual_snapshot.get("presentation_visible", presentation_node != null and presentation_node.visible)), "opponent sim presentation visible", JSON.stringify(visual_snapshot))
	_assert_true(_opponent_visual_snapshot_positions_are_bottom_half(visual_snapshot, smoke_coordinator), "opponent sim tableau stays on bottom half", JSON.stringify(visual_snapshot))
	_assert_true(_bottom_hoop_snapshot_is_valid(bottom_hoop_snapshot, smoke_coordinator), "bottom hoop snapshot is visible and anchored", JSON.stringify(bottom_hoop_snapshot))
	_assert_true(float(bottom_hoop_snapshot.get("scale_multiplier", 0.0)) >= 2.0, "bottom hoop uses doubled visual scale", JSON.stringify(bottom_hoop_snapshot))
	_assert_true(_bottom_hoop_z_order_above_entity_sprites(bottom_hoop_snapshot, smoke_coordinator, presentation_node), "bottom hoop renders above entity sprites", JSON.stringify(bottom_hoop_snapshot))
	for player in smoke_coordinator.offense_players:
		_assert_true(not player.visible, "opponent sim hides live offense players", player.name)
	for player in smoke_coordinator.defense_players:
		_assert_true(not player.visible, "opponent sim hides live defense players", player.name)
	var banner_snapshot: Dictionary = smoke_coordinator.get_opponent_sim_banner_snapshot()
	var safe_rect: Rect2 = smoke_coordinator.layout_metrics.get("safe_rect", Rect2(Vector2.ZERO, Vector2(1080.0, 1920.0)))
	var banner_rect: Rect2 = banner_snapshot.get("banner_rect", Rect2())
	var background_color: Color = banner_snapshot.get("background_color", Color.TRANSPARENT)
	_assert_true(bool(banner_snapshot.get("visible", false)), "opponent sim banner visible", JSON.stringify(banner_snapshot))
	_assert_true(smoke_coordinator.hud != null and not smoke_coordinator.hud.visible, "opponent sim banner hides scoreboard while visible", str(smoke_coordinator.hud.visible if smoke_coordinator.hud != null else true))
	_assert_true(smoke_coordinator.control_panel != null and not smoke_coordinator.control_panel.visible, "opponent sim banner hides controls while visible", str(smoke_coordinator.control_panel.visible if smoke_coordinator.control_panel != null else true))
	_assert_true(absf(background_color.a - 0.8) < 0.01, "opponent sim banner opacity is 80 percent", str(background_color))
	_assert_true(str(banner_snapshot.get("text", "")) == str(sequence_snapshot.get("current_text", "")), "opponent sim banner text matches sequence", JSON.stringify({"banner": banner_snapshot, "sequence": sequence_snapshot}))
	_assert_true(absf(banner_rect.position.x - safe_rect.position.x) <= 1.0 and absf(banner_rect.size.x - safe_rect.size.x) <= 1.0, "opponent sim banner spans safe width", "%s %s" % [banner_rect, safe_rect])
	_assert_true(absf(banner_rect.get_center().y - safe_rect.get_center().y) <= 2.0, "opponent sim banner centered vertically", "%s %s" % [banner_rect, safe_rect])
	var initial_visual_text: String = str(visual_snapshot.get("current_text", ""))
	var initial_visual_kind: String = visual_kind

	for _auto_frame in 61:
		await get_tree().process_frame
	sequence_snapshot = smoke_coordinator.get_opponent_sim_sequence_snapshot()
	visual_snapshot = _get_opponent_visual_snapshot(smoke_coordinator)
	var auto_visual_text: String = str(visual_snapshot.get("current_text", ""))
	var auto_visual_kind: String = str(visual_snapshot.get("current_kind", visual_snapshot.get("kind", "")))
	_assert_true(int(sequence_snapshot.get("current_index", -1)) == 1, "opponent sim banner auto advances after one second", JSON.stringify(sequence_snapshot))
	_assert_true(auto_visual_text != initial_visual_text or auto_visual_kind != initial_visual_kind, "opponent sim tableau changes after auto advance", JSON.stringify(visual_snapshot))
	smoke_coordinator.test_advance_opponent_sim_sequence()
	await get_tree().process_frame
	sequence_snapshot = smoke_coordinator.get_opponent_sim_sequence_snapshot()
	visual_snapshot = _get_opponent_visual_snapshot(smoke_coordinator)
	var tapped_visual_text: String = str(visual_snapshot.get("current_text", ""))
	var tapped_visual_kind: String = str(visual_snapshot.get("current_kind", visual_snapshot.get("kind", "")))
	_assert_true(int(sequence_snapshot.get("current_index", -1)) == 2, "opponent sim banner tap advances one step", JSON.stringify(sequence_snapshot))
	_assert_true(tapped_visual_text != auto_visual_text or tapped_visual_kind != auto_visual_kind, "opponent sim tableau changes on tap advance", JSON.stringify(visual_snapshot))
	var pending_points: int = int(sequence_snapshot.get("pending_points_scored", 0))
	var pending_time: float = float(sequence_snapshot.get("pending_time_consumed", 0.0))
	var timer_before_pause: float = float(sequence_snapshot.get("seconds_remaining", 0.0))
	var paused_visual_text: String = tapped_visual_text
	smoke_coordinator.test_toggle_pause()
	for _paused_frame in 30:
		await get_tree().process_frame
	var paused_snapshot: Dictionary = smoke_coordinator.get_opponent_sim_sequence_snapshot()
	visual_snapshot = _get_opponent_visual_snapshot(smoke_coordinator)
	_assert_true(absf(float(paused_snapshot.get("seconds_remaining", 0.0)) - timer_before_pause) < 0.001, "opponent sim banner timer freezes during pause", JSON.stringify(paused_snapshot))
	_assert_true(str(visual_snapshot.get("current_text", "")) == paused_visual_text, "opponent sim tableau freezes during pause", JSON.stringify(visual_snapshot))
	smoke_coordinator.test_toggle_pause()
	await get_tree().process_frame
	_assert_true(smoke_coordinator.context.current_state == GameState.State.OPPONENT_SIM, "opponent sim banner resumes opponent sim state", smoke_coordinator.get_state_name())
	var advance_guard: int = 0
	while smoke_coordinator.context.current_state == GameState.State.OPPONENT_SIM and advance_guard < 6:
		smoke_coordinator.test_advance_opponent_sim_sequence()
		advance_guard += 1
	_assert_true(smoke_coordinator.context.current_state == GameState.State.LIVE_OFFENSE, "opponent sim banner final tap returns to offense", smoke_coordinator.get_state_name())
	visual_snapshot = _get_opponent_visual_snapshot(smoke_coordinator)
	_assert_true(smoke_coordinator.context.away_score == away_before + pending_points, "opponent sim banner applies pending score once", "%d + %d -> %d" % [away_before, pending_points, smoke_coordinator.context.away_score])
	_assert_true(absf(smoke_coordinator.context.match_time_remaining - maxf(clock_before - pending_time, 0.0)) < 0.001, "opponent sim banner applies pending clock once", "%0.3f - %0.3f -> %0.3f" % [clock_before, pending_time, smoke_coordinator.context.match_time_remaining])
	_assert_true(not bool(smoke_coordinator.get_opponent_sim_banner_snapshot().get("visible", true)), "opponent sim banner hides after completion", JSON.stringify(smoke_coordinator.get_opponent_sim_banner_snapshot()))
	_assert_true(not bool(visual_snapshot.get("active", true)), "opponent sim visual snapshot clears after completion", JSON.stringify(visual_snapshot))
	_assert_true(not bool(visual_snapshot.get("presentation_visible", presentation_node != null and presentation_node.visible)), "opponent sim presentation hides after completion", JSON.stringify(visual_snapshot))
	for player in smoke_coordinator.offense_players:
		_assert_true(player.visible, "opponent sim restores live offense players", player.name)
	for player in smoke_coordinator.defense_players:
		_assert_true(player.visible, "opponent sim restores live defense players", player.name)
	_assert_true(_bottom_hoop_snapshot_is_valid(_get_bottom_hoop_snapshot(smoke_court_view), smoke_coordinator), "bottom hoop stays anchored after cleanup", "")
	_assert_true(smoke_coordinator.hud != null and smoke_coordinator.hud.visible, "opponent sim banner restores scoreboard when offense resumes", str(smoke_coordinator.hud.visible if smoke_coordinator.hud != null else false))
	_assert_true(smoke_coordinator.control_panel != null and smoke_coordinator.control_panel.visible, "opponent sim banner restores controls when offense resumes", str(smoke_coordinator.control_panel.visible if smoke_coordinator.control_panel != null else false))
	game_root.queue_free()
	await get_tree().process_frame
	TeamRoster.reset_demo_state()
	var titan_live_offer: PlayerData = _find_roster_player_by_id(TeamRoster.get_shop_players(), "shop_lc_titan")
	TeamRoster.purchase_shop_player("shop_lc_titan")
	var live_swap_result: bool = TeamRoster.swap_lineup_slot_with_bench("PG", "shop_lc_titan")
	_assert_true(live_swap_result, "live roster swap setup succeeds before game boot", "")
	var custom_game_root_scene: PackedScene = load("res://scenes/GameRoot.tscn")
	var custom_game_root: Node2D = custom_game_root_scene.instantiate() as Node2D
	add_child(custom_game_root)
	await get_tree().process_frame
	var custom_coordinator: GameCoordinator = custom_game_root.get_node("GameCoordinator") as GameCoordinator
	var custom_pg: PlayerController = custom_coordinator.get_offense_player_by_role("PG") if custom_coordinator != null else null
	_assert_true(
		custom_pg != null and titan_live_offer != null and custom_pg.get_display_name() == titan_live_offer.display_name,
		"game boot uses the swapped starter identity for the fixed PG slot",
		custom_pg.get_display_name() if custom_pg != null else ""
	)
	_assert_true(
		custom_pg != null and custom_pg.get_player_data() != null and custom_pg.get_player_data().role == "PG" and custom_pg.get_player_data().dunk == titan_live_offer.dunk,
		"game boot keeps the fixed PG role while inheriting the swapped player's ratings",
		JSON.stringify({
			"role": custom_pg.get_player_data().role if custom_pg != null and custom_pg.get_player_data() != null else "",
			"dunk": custom_pg.get_player_data().dunk if custom_pg != null and custom_pg.get_player_data() != null else -1,
		})
	)
	custom_game_root.queue_free()
	await get_tree().process_frame
	TeamRoster.reset_demo_state()


func _run_score_banner_smoke() -> void:
	var game_root_scene: PackedScene = load("res://scenes/GameRoot.tscn")
	var game_root: Node2D = game_root_scene.instantiate() as Node2D
	add_child(game_root)
	await get_tree().process_frame
	await get_tree().process_frame
	var smoke_coordinator: GameCoordinator = game_root.get_node("GameCoordinator") as GameCoordinator
	_assert_true(smoke_coordinator != null and smoke_coordinator.opponent_sim_banner != null, "score banner smoke coordinator exists", "")
	if smoke_coordinator == null or smoke_coordinator.opponent_sim_banner == null:
		game_root.queue_free()
		await get_tree().process_frame
		return
	smoke_coordinator.begin_test_mode(4242)
	smoke_coordinator.apply_test_setup(4, 6, 30.0)
	var away_before: int = smoke_coordinator.context.away_score
	smoke_coordinator.test_force_opponent_sim_result(3, 2, 4.0)
	await get_tree().process_frame
	var sequence_snapshot: Dictionary = smoke_coordinator.get_opponent_sim_sequence_snapshot()
	_assert_true(int(sequence_snapshot.get("action_count", 0)) == 3, "forced scoring sim appends score step", JSON.stringify(sequence_snapshot))
	var advance_guard: int = 0
	while smoke_coordinator.context.current_state == GameState.State.OPPONENT_SIM and advance_guard < 8:
		var before_snapshot: Dictionary = smoke_coordinator.get_opponent_sim_sequence_snapshot()
		var is_last_step: bool = int(before_snapshot.get("current_index", -1)) == int(before_snapshot.get("action_count", 0)) - 1
		if is_last_step:
			var final_banner: Dictionary = smoke_coordinator.get_opponent_sim_banner_snapshot()
			_assert_true(bool(final_banner.get("is_score", false)), "opponent sim final banner uses score mode", JSON.stringify(final_banner))
			_assert_true(str(final_banner.get("text", "")) == "3 points!", "opponent sim score banner shows 3 points", JSON.stringify(final_banner))
			_assert_true(bool(final_banner.get("jitter_enabled", false)), "opponent sim 3pt score banner enables jitter", JSON.stringify(final_banner))
		smoke_coordinator.test_advance_opponent_sim_sequence()
		advance_guard += 1
	_assert_true(smoke_coordinator.context.current_state == GameState.State.LIVE_OFFENSE, "forced scoring sim returns to offense", smoke_coordinator.get_state_name())
	_assert_true(smoke_coordinator.context.away_score == away_before + 3, "forced scoring sim applies 3 points", "%d -> %d" % [away_before, smoke_coordinator.context.away_score])
	_assert_true(not bool(smoke_coordinator.get_opponent_sim_banner_snapshot().get("visible", true)), "forced scoring sim banner hides after completion", JSON.stringify(smoke_coordinator.get_opponent_sim_banner_snapshot()))

	var banner: OpponentSimBanner = smoke_coordinator.opponent_sim_banner
	banner.show_score(2, false)
	await get_tree().process_frame
	var two_pt_snapshot: Dictionary = banner.get_layout_snapshot()
	_assert_true(bool(two_pt_snapshot.get("visible", false)), "player 2pt score banner visible", JSON.stringify(two_pt_snapshot))
	_assert_true(bool(two_pt_snapshot.get("is_score", false)), "player 2pt score banner uses score mode", JSON.stringify(two_pt_snapshot))
	_assert_true(str(two_pt_snapshot.get("text", "")) == "2 points!", "player 2pt score banner text matches", JSON.stringify(two_pt_snapshot))
	_assert_true(not bool(two_pt_snapshot.get("jitter_enabled", true)), "player 2pt score banner does not jitter", JSON.stringify(two_pt_snapshot))
	banner.hide_banner()

	banner.show_score(3, false)
	await get_tree().process_frame
	var three_pt_snapshot: Dictionary = banner.get_layout_snapshot()
	_assert_true(bool(three_pt_snapshot.get("jitter_enabled", false)) and banner.is_jitter_active(), "player 3pt score banner enables jitter", JSON.stringify(three_pt_snapshot))
	_assert_true(str(three_pt_snapshot.get("text", "")) == "3 points!", "player 3pt score banner text matches", JSON.stringify(three_pt_snapshot))
	banner.hide_banner()
	var hidden_snapshot: Dictionary = banner.get_layout_snapshot()
	_assert_true(not bool(hidden_snapshot.get("visible", true)), "score banner hides on request", JSON.stringify(hidden_snapshot))
	game_root.queue_free()
	await get_tree().process_frame


func _opponent_visual_snapshot_positions_are_bottom_half(snapshot: Dictionary, coordinator: GameCoordinator) -> bool:
	if snapshot.is_empty() or coordinator == null or coordinator.court_config == null:
		return false
	var positions: Array[Vector2] = []
	_collect_snapshot_positions(snapshot.get("ghost_positions_by_team", {}), positions)
	_collect_snapshot_positions(snapshot.get("ghost_positions_by_role", {}), positions)
	_collect_snapshot_positions(snapshot.get("ghost_positions", {}), positions)
	_collect_snapshot_positions(snapshot.get("away_positions", []), positions)
	_collect_snapshot_positions(snapshot.get("home_positions", []), positions)
	_collect_snapshot_positions(snapshot.get("away_ghost_positions", []), positions)
	_collect_snapshot_positions(snapshot.get("home_ghost_positions", []), positions)
	_collect_snapshot_positions(snapshot.get("actor_position", Vector2.INF), positions)
	_collect_snapshot_positions(snapshot.get("ball_anchor", Vector2.INF), positions)
	_collect_snapshot_positions(snapshot.get("ball_position", Vector2.INF), positions)
	if positions.is_empty():
		return false
	var minimum_y: float = coordinator.court_config.court_rect.position.y + coordinator.court_config.court_rect.size.y * 0.5 - 0.01
	for position in positions:
		if position == Vector2.INF:
			continue
		if position.y < minimum_y:
			return false
	return true


func _bottom_hoop_snapshot_is_valid(snapshot: Dictionary, coordinator: GameCoordinator) -> bool:
	if snapshot.is_empty() or coordinator == null or coordinator.court_config == null:
		return false
	var visible: bool = bool(snapshot.get("visible", snapshot.get("is_visible", false)))
	if not visible:
		return false
	var texture_size: Vector2 = snapshot.get("texture_size", snapshot.get("source_size", snapshot.get("image_size", Vector2.ZERO)))
	if absf(texture_size.x - 144.0) > 0.01 or absf(texture_size.y - 170.0) > 0.01:
		return false
	var anchor_value: Variant = snapshot.get("anchor_screen", snapshot.get("screen_anchor", snapshot.get("anchor", Vector2.INF)))
	if anchor_value is Vector2 and anchor_value != Vector2.INF:
		return anchor_value.y >= coordinator.court_config.court_rect.position.y + coordinator.court_config.court_rect.size.y * 0.5
	var rect_value: Variant = snapshot.get("screen_rect", snapshot.get("bottom_hoop_rect", snapshot.get("rect", Rect2())))
	if rect_value is Rect2:
		var hoop_rect: Rect2 = rect_value
		if hoop_rect.size.x <= 0.0 or hoop_rect.size.y <= 0.0:
			return false
		return hoop_rect.get_center().y >= coordinator.court_config.court_rect.position.y + coordinator.court_config.court_rect.size.y * 0.5
	return false


func _bottom_hoop_z_order_above_entity_sprites(snapshot: Dictionary, coordinator: GameCoordinator, presentation_node: Node) -> bool:
	if snapshot.is_empty() or coordinator == null:
		return false
	var hoop_z: int = int(snapshot.get("z_index", -999999))
	if hoop_z <= -999999:
		return false
	if bool(snapshot.get("z_as_relative", true)):
		return false
	var entity_nodes: Array[Node] = []
	for player in coordinator.offense_players:
		entity_nodes.append(player)
	for player in coordinator.defense_players:
		entity_nodes.append(player)
	if coordinator.ball_node != null:
		entity_nodes.append(coordinator.ball_node)
	if coordinator.hoop_node != null:
		entity_nodes.append(coordinator.hoop_node)
	_collect_canvas_children(presentation_node, entity_nodes)
	for node in entity_nodes:
		var canvas_item: CanvasItem = node as CanvasItem
		if canvas_item == null:
			continue
		if canvas_item.z_index >= hoop_z:
			return false
	return true


func _collect_canvas_children(node: Node, output: Array[Node]) -> void:
	if node == null:
		return
	for child in node.get_children():
		output.append(child)
		_collect_canvas_children(child, output)


func _get_opponent_visual_snapshot(coordinator: GameCoordinator) -> Dictionary:
	if coordinator == null or not coordinator.has_method("get_opponent_sim_visual_snapshot"):
		return {}
	var snapshot: Variant = coordinator.call("get_opponent_sim_visual_snapshot")
	return snapshot if snapshot is Dictionary else {}


func _get_bottom_hoop_snapshot(court_view: CourtView) -> Dictionary:
	if court_view == null or not court_view.has_method("get_bottom_hoop_snapshot"):
		return {}
	var snapshot: Variant = court_view.call("get_bottom_hoop_snapshot")
	return snapshot if snapshot is Dictionary else {}


func _collect_snapshot_positions(value: Variant, positions: Array[Vector2]) -> void:
	if value is Vector2:
		positions.append(value)
	elif value is Array:
		for item in value:
			_collect_snapshot_positions(item, positions)
	elif value is Dictionary:
		for key in value.keys():
			var key_name: String = str(key).to_lower()
			if key_name.contains("position"):
				_collect_snapshot_positions(value[key], positions)


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


func _get_finish_logic_center_world(coordinator: GameCoordinator) -> Vector2:
	if coordinator == null:
		return Vector2.ZERO
	if coordinator.has_method("get_finish_logic_center_world"):
		return coordinator.call("get_finish_logic_center_world")
	return coordinator.court_config.hoop_position if coordinator.court_config != null else Vector2.ZERO


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
	var finish_center_world: Vector2 = _get_finish_logic_center_world(coordinator)
	var motion_vector: Vector2 = (finish_center_world - (finish_center_world + start_offset)).normalized() * 190.0
	shooter.world_position = finish_center_world + start_offset
	shooter.velocity = motion_vector
	coordinator.current_move_direction = motion_vector.normalized()
	coordinator.current_move_magnitude = 1.0
	_arm_test_shot(coordinator, "dunk")
	for _frame in 180:
		await get_tree().process_frame
		if coordinator.context.current_state == GameState.State.SHOT_RELEASE and shooter.is_dunk_contact_hold_active():
			return {
				"row": shooter.get_debug_row_index(),
				"mirror_west": bool(coordinator.active_shot_sequence.get("mirror_west", shooter.get_debug_flip_h())),
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
	var first_snapshot: Dictionary = snapshots[0]
	var first_world_position: Vector2 = first_snapshot.get("world_position", Vector2.INF)
	var first_ground_screen: Vector2 = first_snapshot.get("ground_screen", Vector2.INF)
	var first_mirror_west: bool = bool(first_snapshot.get("mirror_west", false))
	for snapshot in snapshots:
		var mirror_west: bool = bool(snapshot.get("mirror_west", false))
		var configured_anchor: Vector2 = coordinator.get_dunk_contact_anchor_offset_for_row(expected_row, mirror_west)
		var anchor_offset: Vector2 = snapshot.get("anchor_offset", Vector2.INF)
		var world_position: Vector2 = snapshot.get("world_position", Vector2.INF)
		var ground_screen: Vector2 = snapshot.get("ground_screen", Vector2.INF)
		_assert_true(int(snapshot.get("row", -1)) == expected_row, "%s row" % name_prefix, JSON.stringify(snapshot))
		_assert_true(mirror_west == first_mirror_west, "%s mirror state stays deterministic" % name_prefix, JSON.stringify(snapshot))
		_assert_true(anchor_offset.distance_to(configured_anchor) < 0.01, "%s snaps to configured anchor" % name_prefix, str(anchor_offset))
		_assert_true(world_position.distance_to(first_world_position) < 0.01, "%s world position stays deterministic" % name_prefix, "%s %s" % [world_position, first_world_position])
		_assert_true(ground_screen.distance_to(first_ground_screen) < 0.01, "%s screen anchor stays deterministic" % name_prefix, "%s %s" % [ground_screen, first_ground_screen])


func _collect_dunk_motion_trace(
	coordinator: GameCoordinator,
	ballhandler_role: String,
	seed: int,
	start_offset: Vector2
) -> Dictionary:
	_reset_visual_test_state(coordinator, ballhandler_role, seed)
	var shooter: PlayerController = coordinator.get_offense_player_by_role(ballhandler_role)
	if shooter == null:
		return {}
	var finish_center_world: Vector2 = _get_finish_logic_center_world(coordinator)
	var motion_vector: Vector2 = (finish_center_world - (finish_center_world + start_offset)).normalized() * 190.0
	shooter.world_position = finish_center_world + start_offset
	shooter.velocity = motion_vector
	coordinator.current_move_direction = motion_vector.normalized()
	coordinator.current_move_magnitude = 1.0
	_arm_test_shot(coordinator, "dunk")
	var frames: Array[Dictionary] = []
	var samples: Array[Dictionary] = []
	var resolved_row: int = -1
	var started: bool = false
	var approach_start_frame: int = 1
	var approach_bucket: String = "max"
	var approach_distance_to_hoop: float = INF
	var mirror_west: bool = false
	for _frame in 360:
		await get_tree().process_frame
		var root_motion_active: bool = not coordinator.active_dunk_root_motion.is_empty()
		if not coordinator.active_shot_sequence.is_empty():
			resolved_row = PlayerVisual.get_row_index_for_family_variant(
				str(coordinator.active_shot_sequence.get("family", "")),
				int(coordinator.active_shot_sequence.get("variant_index", 0))
			)
			approach_start_frame = int(coordinator.active_shot_sequence.get("approach_start_frame", approach_start_frame))
			approach_bucket = str(coordinator.active_shot_sequence.get("approach_bucket", approach_bucket))
			approach_distance_to_hoop = float(coordinator.active_shot_sequence.get("approach_distance_to_hoop", approach_distance_to_hoop))
			mirror_west = bool(coordinator.active_shot_sequence.get("mirror_west", mirror_west))
		elif root_motion_active:
			resolved_row = int(coordinator.active_dunk_root_motion.get("row_index", resolved_row))
			approach_start_frame = int(coordinator.active_dunk_root_motion.get("approach_start_frame", approach_start_frame))
			approach_bucket = str(coordinator.active_dunk_root_motion.get("approach_bucket", approach_bucket))
			approach_distance_to_hoop = float(coordinator.active_dunk_root_motion.get("approach_distance_to_hoop", approach_distance_to_hoop))
			mirror_west = bool(coordinator.active_dunk_root_motion.get("mirror_west", mirror_west))
		elif resolved_row <= 0:
			resolved_row = shooter.get_debug_row_index()
			mirror_west = shooter.get_debug_flip_h()
		var in_dunk_sequence: bool = root_motion_active \
			or coordinator.context.current_state == GameState.State.SHOT_RELEASE \
			or coordinator.context.current_state == GameState.State.SHOT_IN_FLIGHT \
			or not samples.is_empty()
		if not in_dunk_sequence:
			continue
		started = true
		var frame_number: int = shooter.get_debug_frame_number()
		if resolved_row <= 0 or frame_number <= 0:
			if started and not root_motion_active and not samples.is_empty():
				break
			continue
		var landing_anchor_world: Vector2 = coordinator.court_config.hoop_position + coordinator.get_dunk_landing_anchor_offset_for_row(resolved_row, mirror_west)
		var outside_release_states: bool = coordinator.context.current_state != GameState.State.SHOT_RELEASE \
			and coordinator.context.current_state != GameState.State.SHOT_IN_FLIGHT
		if not root_motion_active and outside_release_states and shooter.world_position.distance_to(landing_anchor_world) >= 0.01:
			break
		var sample_snapshot: Dictionary = {
			"frame": frame_number,
			"frame_progress": shooter.get_debug_frame_progress(),
			"state": coordinator.get_state_name(),
			"world_position": shooter.world_position,
			"ground_screen": shooter.global_position,
			"base_ground_screen": coordinator.court_projection.world_to_base_screen_ground(shooter.world_position) if coordinator.court_projection != null else shooter.global_position,
			"velocity": shooter.velocity,
			"hold_active": shooter.is_dunk_contact_hold_active(),
			"root_motion_active": root_motion_active,
		}
		samples.append(sample_snapshot)
		var should_append: bool = frames.is_empty() or int(frames[-1].get("frame", -1)) != frame_number
		if should_append:
			frames.append(sample_snapshot.duplicate(true))
		if not root_motion_active and shooter.world_position.distance_to(landing_anchor_world) < 0.01:
			break
		if not root_motion_active and outside_release_states:
			break
	return {
		"row": resolved_row,
		"mirror_west": mirror_west,
		"approach_start_frame": approach_start_frame,
		"approach_bucket": approach_bucket,
		"approach_distance_to_hoop": approach_distance_to_hoop,
		"frames": frames,
		"samples": samples,
	}


func _collect_matching_dunk_motion_traces(
	coordinator: GameCoordinator,
	expected_row: int,
	ballhandler_role: String,
	seeds: Array,
	start_offsets: Array[Vector2],
	required_count: int = 2,
	expected_start_frame: int = -1
) -> Array[Dictionary]:
	var traces: Array[Dictionary] = []
	for start_offset in start_offsets:
		for seed in seeds:
			var trace: Dictionary = await _collect_dunk_motion_trace(coordinator, ballhandler_role, int(seed), start_offset)
			if trace.is_empty() or int(trace.get("row", -1)) != expected_row:
				continue
			if expected_start_frame > 0 and int(trace.get("approach_start_frame", -1)) != expected_start_frame:
				continue
			var trace_samples: Array = trace.get("samples", [])
			if trace_samples.is_empty():
				continue
			var trace_mirror_west: bool = bool(trace.get("mirror_west", false))
			var landing_anchor_world: Vector2 = coordinator.court_config.hoop_position + coordinator.get_dunk_landing_anchor_offset_for_row(expected_row, trace_mirror_west)
			var final_world: Vector2 = trace_samples[-1].get("world_position", Vector2.INF)
			if final_world.distance_to(landing_anchor_world) >= 0.01:
				continue
			traces.append(trace)
			if traces.size() >= required_count:
				return traces
	return traces


func _find_dunk_motion_frame_snapshot(trace_frames: Array, frame_number: int) -> Dictionary:
	for snapshot in trace_frames:
		if int(snapshot.get("frame", -1)) == frame_number:
			return snapshot
	return {}


func _assert_dunk_root_motion_trace_consistency(
	coordinator: GameCoordinator,
	expected_row: int,
	ballhandler_role: String,
	seeds: Array,
	start_offsets: Array[Vector2],
	name_prefix: String,
	expected_start_frame: int,
	expected_bucket: String,
	required_trace_count: int = 1
) -> void:
	var traces: Array[Dictionary] = await _collect_matching_dunk_motion_traces(
		coordinator,
		expected_row,
		ballhandler_role,
		seeds,
		start_offsets,
		required_trace_count,
		expected_start_frame
	)
	_assert_true(traces.size() >= required_trace_count, "%s traces reachable" % name_prefix, JSON.stringify(traces))
	if traces.is_empty():
		return
	var first_trace_mirror_west: bool = bool(traces[0].get("mirror_west", false))
	var run_end_frame: int = coordinator.player_animation_config.get_dunk_run_end_frame(expected_row)
	var jump_end_frame: int = coordinator.player_animation_config.get_dunk_jump_end_frame(expected_row)
	var jump_start_frame: int = coordinator.player_animation_config.get_dunk_jump_start_frame(expected_row)
	var contact_start_frame: int = coordinator.player_animation_config.get_dunk_contact_frame(expected_row)
	var contact_end_frame: int = coordinator.player_animation_config.get_dunk_contact_end_frame(expected_row)
	var first_trace_frames: Array = traces[0].get("frames", [])
	var first_trace_samples: Array = traces[0].get("samples", [])
	var first_contact_snapshot: Dictionary = _find_dunk_motion_frame_snapshot(first_trace_frames, contact_start_frame)
	var first_final_snapshot: Dictionary = first_trace_samples[-1] if not first_trace_samples.is_empty() else {}
	for trace in traces:
		var trace_frames: Array = trace.get("frames", [])
		var trace_samples: Array = trace.get("samples", [])
		var trace_mirror_west: bool = bool(trace.get("mirror_west", false))
		var contact_anchor_world: Vector2 = coordinator.court_config.hoop_position + coordinator.get_dunk_contact_anchor_offset_for_row(expected_row, trace_mirror_west)
		var landing_anchor_world: Vector2 = coordinator.court_config.hoop_position + coordinator.get_dunk_landing_anchor_offset_for_row(expected_row, trace_mirror_west)
		_assert_true(not trace_samples.is_empty(), "%s captured root-motion samples" % name_prefix, JSON.stringify(trace))
		_assert_true(trace_mirror_west == first_trace_mirror_west, "%s mirror state stays deterministic" % name_prefix, JSON.stringify(trace))
		_assert_true(int(trace.get("approach_start_frame", -1)) == expected_start_frame, "%s uses expected smart start frame" % name_prefix, JSON.stringify(trace))
		_assert_true(str(trace.get("approach_bucket", "")) == expected_bucket, "%s uses expected approach bucket" % name_prefix, JSON.stringify(trace))
		var first_visible_snapshot: Dictionary = _find_dunk_motion_frame_snapshot(trace_frames, expected_start_frame)
		_assert_true(not first_visible_snapshot.is_empty(), "%s start frame %d exists" % [name_prefix, expected_start_frame], JSON.stringify(trace_frames))
		if expected_start_frame > 1:
			_assert_true(_find_dunk_motion_frame_snapshot(trace_frames, expected_start_frame - 1).is_empty(), "%s skips earlier pre-start frame" % name_prefix, JSON.stringify(trace_frames))
		var previous_distance_to_contact: float = INF
		var previous_world_position: Vector2 = Vector2.INF
		for frame_number in range(expected_start_frame, run_end_frame + 1):
			var run_snapshot: Dictionary = _find_dunk_motion_frame_snapshot(trace_frames, frame_number)
			_assert_true(not run_snapshot.is_empty(), "%s run frame %d exists" % [name_prefix, frame_number], JSON.stringify(trace_frames))
			if run_snapshot.is_empty():
				continue
			var run_world: Vector2 = run_snapshot.get("world_position", Vector2.INF)
			if previous_world_position != Vector2.INF:
				_assert_true(run_world.distance_to(previous_world_position) > 0.01, "%s run frame %d keeps moving" % [name_prefix, frame_number], "%s %s" % [run_world, previous_world_position])
			var run_distance_to_contact: float = run_world.distance_to(contact_anchor_world)
			_assert_true(run_distance_to_contact <= previous_distance_to_contact + 0.01, "%s run frame %d moves toward contact" % [name_prefix, frame_number], "%0.3f %0.3f" % [run_distance_to_contact, previous_distance_to_contact])
			previous_distance_to_contact = run_distance_to_contact
			previous_world_position = run_world
		if expected_start_frame >= jump_start_frame:
			for skipped_run_frame in range(1, run_end_frame + 1):
				_assert_true(_find_dunk_motion_frame_snapshot(trace_frames, skipped_run_frame).is_empty(), "%s short start skips run frame %d" % [name_prefix, skipped_run_frame], JSON.stringify(trace_frames))
		for frame_number in range(max(expected_start_frame, jump_start_frame), jump_end_frame + 1):
			var jump_snapshot: Dictionary = _find_dunk_motion_frame_snapshot(trace_frames, frame_number)
			_assert_true(not jump_snapshot.is_empty(), "%s jump frame %d exists" % [name_prefix, frame_number], JSON.stringify(trace_frames))
			if jump_snapshot.is_empty():
				continue
			var jump_world: Vector2 = jump_snapshot.get("world_position", Vector2.INF)
			if previous_world_position != Vector2.INF:
				_assert_true(jump_world.distance_to(previous_world_position) > 0.01, "%s jump frame %d keeps moving" % [name_prefix, frame_number], "%s %s" % [jump_world, previous_world_position])
			var jump_distance_to_contact: float = jump_world.distance_to(contact_anchor_world)
			_assert_true(jump_distance_to_contact <= previous_distance_to_contact + 0.01, "%s jump frame %d keeps moving toward contact" % [name_prefix, frame_number], "%0.3f %0.3f" % [jump_distance_to_contact, previous_distance_to_contact])
			previous_distance_to_contact = jump_distance_to_contact
			previous_world_position = jump_world
		for frame_number in range(contact_start_frame, contact_end_frame + 1):
			var contact_snapshot: Dictionary = _find_dunk_motion_frame_snapshot(trace_frames, frame_number)
			_assert_true(not contact_snapshot.is_empty(), "%s contact frame %d exists" % [name_prefix, frame_number], JSON.stringify(trace_frames))
			if contact_snapshot.is_empty():
				continue
			var contact_world: Vector2 = contact_snapshot.get("world_position", Vector2.INF)
			_assert_true(contact_world.distance_to(contact_anchor_world) < 0.01, "%s contact frame %d pins to contact anchor" % [name_prefix, frame_number], str(contact_world))
		if expected_row == 16:
			var row16_contact_a: Dictionary = _find_dunk_motion_frame_snapshot(trace_frames, 11)
			var row16_contact_b: Dictionary = _find_dunk_motion_frame_snapshot(trace_frames, 12)
			_assert_true(not row16_contact_a.is_empty() and not row16_contact_b.is_empty(), "%s row 16 captures both dunk frames" % name_prefix, JSON.stringify(trace_frames))
			if not row16_contact_a.is_empty() and not row16_contact_b.is_empty():
				_assert_true(
					row16_contact_a.get("world_position", Vector2.INF).distance_to(row16_contact_b.get("world_position", Vector2.INF)) < 0.01,
					"%s row 16 stays pinned across both contact frames" % name_prefix,
					"%s %s" % [row16_contact_a.get("world_position", Vector2.ZERO), row16_contact_b.get("world_position", Vector2.ZERO)]
				)
		var landing_start_index: int = -1
		for sample_index in range(trace_samples.size()):
			if str(trace_samples[sample_index].get("state", "")) == "SHOT_IN_FLIGHT":
				landing_start_index = sample_index
				break
		_assert_true(landing_start_index >= 0, "%s landing starts after launch" % name_prefix, JSON.stringify(trace_samples))
		if landing_start_index >= 0:
			var landing_start_snapshot: Dictionary = trace_samples[landing_start_index]
			var landing_start_world: Vector2 = landing_start_snapshot.get("world_position", Vector2.INF)
			_assert_true(landing_start_world.distance_to(contact_anchor_world) < 0.01, "%s landing starts on contact anchor" % name_prefix, str(landing_start_world))
			var previous_landing_world: Vector2 = landing_start_world
			var previous_landing_distance: float = landing_start_world.distance_to(landing_anchor_world)
			var landing_motion_seen: bool = false
			for sample_index in range(landing_start_index + 1, trace_samples.size()):
				var landing_snapshot: Dictionary = trace_samples[sample_index]
				var landing_world: Vector2 = landing_snapshot.get("world_position", Vector2.INF)
				if landing_world.distance_to(previous_landing_world) > 0.01:
					landing_motion_seen = true
				var landing_distance: float = landing_world.distance_to(landing_anchor_world)
				_assert_true(landing_distance <= previous_landing_distance + 0.01, "%s landing keeps descending to landing anchor" % name_prefix, "%0.3f %0.3f" % [landing_distance, previous_landing_distance])
				previous_landing_world = landing_world
				previous_landing_distance = landing_distance
			_assert_true(landing_motion_seen, "%s landing keeps moving after launch" % name_prefix, JSON.stringify(trace_samples))
			var final_snapshot: Dictionary = trace_samples[-1]
			var final_world: Vector2 = final_snapshot.get("world_position", Vector2.INF)
			_assert_true(final_world.distance_to(landing_anchor_world) < 0.01, "%s final landing sample reaches landing anchor" % name_prefix, str(final_world))
		var contact_snapshot: Dictionary = _find_dunk_motion_frame_snapshot(trace_frames, contact_start_frame)
		var final_snapshot_again: Dictionary = trace_samples[-1] if not trace_samples.is_empty() else {}
		_assert_true(not contact_snapshot.is_empty(), "%s contact snapshot available for determinism" % name_prefix, JSON.stringify(trace_frames))
		_assert_true(not final_snapshot_again.is_empty(), "%s final snapshot available for determinism" % name_prefix, JSON.stringify(trace_frames))
		if not contact_snapshot.is_empty() and not first_contact_snapshot.is_empty():
			_assert_true(
				contact_snapshot.get("world_position", Vector2.INF).distance_to(first_contact_snapshot.get("world_position", Vector2.INF)) < 0.01,
				"%s contact world position stays deterministic" % name_prefix,
				"%s %s" % [contact_snapshot.get("world_position", Vector2.ZERO), first_contact_snapshot.get("world_position", Vector2.ZERO)]
			)
			_assert_true(
				contact_snapshot.get("ground_screen", Vector2.INF).distance_to(first_contact_snapshot.get("ground_screen", Vector2.INF)) < 0.01,
				"%s contact screen anchor stays deterministic" % name_prefix,
				"%s %s" % [contact_snapshot.get("ground_screen", Vector2.ZERO), first_contact_snapshot.get("ground_screen", Vector2.ZERO)]
			)
		if not final_snapshot_again.is_empty() and not first_final_snapshot.is_empty():
			_assert_true(
				final_snapshot_again.get("world_position", Vector2.INF).distance_to(first_final_snapshot.get("world_position", Vector2.INF)) < 0.01,
				"%s landing world position stays deterministic" % name_prefix,
				"%s %s" % [final_snapshot_again.get("world_position", Vector2.ZERO), first_final_snapshot.get("world_position", Vector2.ZERO)]
			)
			_assert_true(
				final_snapshot_again.get("base_ground_screen", Vector2.INF).distance_to(first_final_snapshot.get("base_ground_screen", Vector2.INF)) < 0.01,
				"%s landing base screen anchor stays deterministic" % name_prefix,
				"%s %s" % [final_snapshot_again.get("base_ground_screen", Vector2.ZERO), first_final_snapshot.get("base_ground_screen", Vector2.ZERO)]
			)


func _begin_release_test_shot(coordinator: GameCoordinator, _shooter: PlayerController, aim_frames: int = 12, control_intent: String = "shot_layout") -> void:
	_arm_test_shot(coordinator, control_intent)
	for _aim_frame in aim_frames:
		await get_tree().process_frame
	if coordinator.context.current_state == GameState.State.SHOT_AIM:
		_tap_test_meter(coordinator)
		await get_tree().process_frame


func _arm_test_shot(coordinator: GameCoordinator, control_intent: String = "shot_layout") -> void:
	if coordinator.input_controller == null:
		return
	var control_layout: Dictionary = coordinator.input_controller.get_control_layout_snapshot()
	var zone_rects: Dictionary = control_layout.get("control_zone_rects", {})
	var swipe_start: Vector2 = zone_rects.get("move", Rect2()).get_center()
	var swipe_end: Vector2 = zone_rects.get("dunk", Rect2()).get_center() if control_intent == "dunk" else zone_rects.get("shoot", Rect2()).get_center()
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
	_assert_true(smoke_coordinator.has_method("get_ball_screen_anchor"), "ball screen-anchor accessor exists", "")
	_assert_true(smoke_coordinator.has_method("did_last_scored_shot_pass_through_net"), "through-net score accessor exists", "")
	_assert_true(smoke_coordinator.has_method("get_net_swish_active"), "net swish accessor exists", "")
	if smoke_coordinator.hoop_node != null:
		if smoke_coordinator.hoop_node.has_method("supports_three_piece_visuals"):
			_assert_true(bool(smoke_coordinator.hoop_node.call("supports_three_piece_visuals")), "three-piece hoop visuals exist", "")
		if smoke_coordinator.hoop_node.has_method("supports_four_layer_visuals"):
			_assert_true(bool(smoke_coordinator.hoop_node.call("supports_four_layer_visuals")), "four-layer net visuals exist", "")
		var back_z: int = int(smoke_coordinator.hoop_node.call("get_ball_z_index_for_phase", "behind_backboard"))
		var rim_z: int = int(smoke_coordinator.hoop_node.call("get_ball_z_index_for_phase", "rim_mouth"))
		var channel_z: int = int(smoke_coordinator.hoop_node.call("get_ball_z_index_for_phase", "net_channel"))
		var front_z: int = int(smoke_coordinator.hoop_node.call("get_ball_z_index_for_phase", "front_of_net"))
		_assert_true(back_z < rim_z and rim_z < channel_z and channel_z < front_z, "hoop phase z-order increases frontward", "%d %d %d %d" % [back_z, rim_z, channel_z, front_z])
		if smoke_coordinator.hoop_node.has_method("get_layering_snapshot"):
			var layering_snapshot: Dictionary = smoke_coordinator.hoop_node.call("get_layering_snapshot")
			var layers: Dictionary = layering_snapshot.get("layers", {})
			var phases: Dictionary = layering_snapshot.get("ball_phases", {})
			var body_snapshot: Dictionary = layers.get("hoop_body", {})
			var net_snapshot: Dictionary = layers.get("net", {})
			var clean_snapshot: Dictionary = layers.get("net_clean", {})
			var bottom_half_snapshot: Dictionary = layers.get("net_clean_bottom_half", {})
			var net_body_snapshot: Dictionary = layers.get("net_body", {})
			var body_z: int = int(body_snapshot.get("effective_z_index", -999999))
			var net_z: int = int(net_snapshot.get("effective_z_index", -999999))
			var clean_z: int = int(clean_snapshot.get("effective_z_index", -999999))
			var bottom_half_z: int = int(bottom_half_snapshot.get("effective_z_index", -999999))
			var net_body_z: int = int(net_body_snapshot.get("effective_z_index", -999999))
			var phase_z_values: Array[int] = [
				int(phases.get("rim_mouth", -999999)),
				int(phases.get("net_channel", -999999)),
				int(phases.get("front_of_net", -999999)),
			]
			var phases_above_clean: bool = true
			var inactive_phases_above_bottom_half: bool = true
			var inactive_phases_above_net_body: bool = true
			for phase_z in phase_z_values:
				phases_above_clean = phases_above_clean and phase_z > clean_z
				inactive_phases_above_bottom_half = inactive_phases_above_bottom_half and phase_z > bottom_half_z
				inactive_phases_above_net_body = inactive_phases_above_net_body and phase_z > net_body_z
			_assert_true(bool(layering_snapshot.get("supports_four_layer_visuals", false)), "layering snapshot reports four-layer net", JSON.stringify(layering_snapshot))
			_assert_true(back_z < body_z and body_z < net_z and net_z < clean_z, "rear hoop layers sit behind shot phases", JSON.stringify(layering_snapshot))
			_assert_true(not bool(layering_snapshot.get("bottom_half_mask_active", true)), "bottom-half net mask starts inactive", JSON.stringify(layering_snapshot))
			_assert_true(not bool(layering_snapshot.get("net_body_mask_active", true)), "NetBody mask starts inactive", JSON.stringify(layering_snapshot))
			_assert_true(phases_above_clean, "shot ball phases render in front of NetClean", JSON.stringify(layering_snapshot))
			_assert_true(inactive_phases_above_bottom_half, "inactive bottom-half net renders below airborne shot phases", JSON.stringify(layering_snapshot))
			_assert_true(inactive_phases_above_net_body, "inactive NetBody renders below airborne shot phases", JSON.stringify(layering_snapshot))
			_assert_true(clean_z < bottom_half_z and clean_z < net_body_z and bottom_half_z <= net_body_z, "inactive net masks sit above NetClean and below shot phases", JSON.stringify(layering_snapshot))
			_assert_true(_net_layer_texture_sizes_are_registered(layers), "four net layers share 30x28 registration", JSON.stringify(layering_snapshot))
			if smoke_coordinator.hoop_node.has_method("set_through_net_masks_active"):
				smoke_coordinator.hoop_node.call("set_through_net_masks_active", true)
				var active_snapshot: Dictionary = smoke_coordinator.hoop_node.call("get_layering_snapshot")
				var active_layers: Dictionary = active_snapshot.get("layers", {})
				var active_phases: Dictionary = active_snapshot.get("ball_phases", {})
				var active_bottom_half_z: int = int(active_layers.get("net_clean_bottom_half", {}).get("effective_z_index", -999999))
				var active_net_body_z: int = int(active_layers.get("net_body", {}).get("effective_z_index", -999999))
				var active_channel_z: int = int(active_phases.get("net_channel", -999999))
				var active_front_z: int = int(active_phases.get("front_of_net", -999999))
				_assert_true(bool(active_snapshot.get("bottom_half_mask_active", false)), "bottom-half net mask toggles active", JSON.stringify(active_snapshot))
				_assert_true(bool(active_snapshot.get("net_body_mask_active", false)), "NetBody mask toggles active", JSON.stringify(active_snapshot))
				_assert_true(active_channel_z < active_bottom_half_z and active_front_z < active_bottom_half_z, "active bottom-half net masks through-net ball phases", JSON.stringify(active_snapshot))
				_assert_true(active_channel_z < active_net_body_z and active_front_z < active_net_body_z, "active NetBody masks through-net ball phases", JSON.stringify(active_snapshot))
				_assert_true(active_bottom_half_z < active_net_body_z, "active NetCleanBottomHalf stays below NetBody", JSON.stringify(active_snapshot))
				smoke_coordinator.hoop_node.call("set_through_net_masks_active", false)
		if smoke_coordinator.hoop_node.has_method("is_net_swish_active"):
			_assert_true(not bool(smoke_coordinator.hoop_node.call("is_net_swish_active")), "net swish idle before score", "")
	smoke_coordinator.begin_test_mode(1708)
	await get_tree().process_frame
	if smoke_coordinator.hoop_node != null and smoke_coordinator.hoop_node.has_method("get_layering_snapshot"):
		var airborne_world: Vector2 = smoke_coordinator.court_config.hoop_position + Vector2(0.0, smoke_coordinator.court_config.score_entry_min_front_offset)
		var airborne_z: float = smoke_coordinator.court_config.rim_height + 72.0
		smoke_coordinator.ball_simulator.position_xy = airborne_world
		smoke_coordinator.ball_simulator.previous_position_xy = airborne_world
		smoke_coordinator.ball_simulator.z = airborne_z
		smoke_coordinator.ball_simulator.previous_z = airborne_z
		smoke_coordinator.ball_simulator.vz = 120.0
		smoke_coordinator.ball_simulator.is_guided_make = false
		smoke_coordinator.ball_simulator.profile_kind = BallSimulator.PROFILE_KIND_FREE_FLIGHT
		smoke_coordinator.ball_simulator.flight_phase = BallSimulator.FLIGHT_PHASE_FREE_FLIGHT
		smoke_coordinator._sync_ball_world_visual(airborne_world, airborne_z)
		var airborne_phase: String = smoke_coordinator.get_ball_render_phase()
		var airborne_snapshot: Dictionary = smoke_coordinator.hoop_node.call("get_layering_snapshot")
		var airborne_layers: Dictionary = airborne_snapshot.get("layers", {})
		var airborne_phases: Dictionary = airborne_snapshot.get("ball_phases", {})
		var airborne_bottom_half_z: int = int(airborne_layers.get("net_clean_bottom_half", {}).get("effective_z_index", -999999))
		var airborne_net_body_z: int = int(airborne_layers.get("net_body", {}).get("effective_z_index", -999999))
		var airborne_ball_z: int = int(airborne_phases.get(airborne_phase, -999999))
		_assert_true(airborne_phase == "front_of_net", "non-descending airborne ball near hoop uses front phase", airborne_phase)
		_assert_true(not bool(airborne_snapshot.get("bottom_half_mask_active", true)), "non-descending airborne ball keeps bottom-half mask inactive", JSON.stringify(airborne_snapshot))
		_assert_true(not bool(airborne_snapshot.get("net_body_mask_active", true)), "non-descending airborne ball keeps NetBody mask inactive", JSON.stringify(airborne_snapshot))
		_assert_true(airborne_bottom_half_z < airborne_ball_z and airborne_net_body_z < airborne_ball_z, "airborne front-phase ball renders above inactive net masks", JSON.stringify(airborne_snapshot))
	var finish_center_screen_before_shot: Vector2 = Vector2.INF
	if smoke_coordinator.hoop_node != null and smoke_coordinator.hoop_node.has_method("get_debug_finish_radius_center_screen"):
		finish_center_screen_before_shot = smoke_coordinator.hoop_node.call("get_debug_finish_radius_center_screen")
	smoke_coordinator.test_force_scoring_shot("RC", 2)
	var through_net: bool = false
	var score_seen: bool = false
	var score_phase: String = ""
	var swish_when_scored: bool = false
	var first_phase_frame: Dictionary = {}
	var front_after_net_frame: int = -1
	var score_z: float = INF
	var finish_center_world: Vector2 = smoke_coordinator.get_finish_logic_center_world()
	var finish_center_world_after_landing: Vector2 = Vector2.INF
	var floor_phase_cleared: bool = false
	var floor_phase_cleared_anchor: Vector2 = Vector2.INF
	var floor_phase_cleared_release_y: float = INF
	var landed_before_reset: bool = false
	var landed_position: Vector2 = Vector2.INF
	var landed_screen_anchor: Vector2 = Vector2.INF
	var front_window_count: int = 0
	var front_window_active: bool = false
	var reentered_hoop_render_after_clear: bool = false
	var last_explicit_hoop_anchor: Vector2 = Vector2.INF
	var first_floor_drop_anchor: Vector2 = Vector2.INF
	var first_floor_drop_recorded: bool = false
	var saw_pre_bounce_upward: bool = false
	var first_upward_phase: String = ""
	var first_upward_delta: float = 0.0
	var pre_bounce_upward_phase: String = ""
	var pre_bounce_upward_delta: float = 0.0
	var last_followthrough_anchor_y: float = INF
	var net_channel_mask_active_seen: bool = false
	var through_front_mask_active_seen: bool = false
	var net_channel_net_body_active_seen: bool = false
	var through_front_net_body_active_seen: bool = false
	var active_mask_order_ok: bool = true
	var active_mask_order_failure: Dictionary = {}
	for frame in 180:
		await get_tree().process_frame
		if smoke_coordinator.has_method("did_last_scored_shot_pass_through_net"):
			through_net = bool(smoke_coordinator.call("did_last_scored_shot_pass_through_net"))
		if smoke_coordinator.has_method("get_ball_render_phase"):
			var phase: String = str(smoke_coordinator.call("get_ball_render_phase"))
			var ball_anchor: Vector2 = smoke_coordinator.call("get_ball_screen_anchor")
			var sim_phase: String = smoke_coordinator.ball_simulator.get_flight_phase()
			if phase != "" and not first_phase_frame.has(phase):
				first_phase_frame[phase] = frame
			if smoke_coordinator.hoop_node != null and smoke_coordinator.hoop_node.has_method("get_layering_snapshot") and phase in ["net_channel", "front_of_net"]:
				var dynamic_layering_snapshot: Dictionary = smoke_coordinator.hoop_node.call("get_layering_snapshot")
				var dynamic_layers: Dictionary = dynamic_layering_snapshot.get("layers", {})
				var dynamic_phases: Dictionary = dynamic_layering_snapshot.get("ball_phases", {})
				var dynamic_ball_z: int = int(dynamic_phases.get(phase, -999999))
				var dynamic_bottom_half_z: int = int(dynamic_layers.get("net_clean_bottom_half", {}).get("effective_z_index", -999999))
				var dynamic_net_body_z: int = int(dynamic_layers.get("net_body", {}).get("effective_z_index", -999999))
				var dynamic_mask_active: bool = bool(dynamic_layering_snapshot.get("bottom_half_mask_active", false))
				var dynamic_net_body_active: bool = bool(dynamic_layering_snapshot.get("net_body_mask_active", false))
				if phase == "net_channel":
					net_channel_mask_active_seen = net_channel_mask_active_seen or dynamic_mask_active
					net_channel_net_body_active_seen = net_channel_net_body_active_seen or dynamic_net_body_active
					if not dynamic_mask_active or not dynamic_net_body_active or not (dynamic_ball_z < dynamic_bottom_half_z and dynamic_ball_z < dynamic_net_body_z):
						active_mask_order_ok = false
						active_mask_order_failure = dynamic_layering_snapshot
				if phase == "front_of_net" and first_phase_frame.has("net_channel"):
					through_front_mask_active_seen = through_front_mask_active_seen or dynamic_mask_active
					through_front_net_body_active_seen = through_front_net_body_active_seen or dynamic_net_body_active
					if not dynamic_mask_active or not dynamic_net_body_active or not (dynamic_ball_z < dynamic_bottom_half_z and dynamic_ball_z < dynamic_net_body_z):
						active_mask_order_ok = false
						active_mask_order_failure = dynamic_layering_snapshot
			if first_phase_frame.has("net_channel") and not is_inf(ball_anchor.y):
				if not is_inf(last_followthrough_anchor_y):
					var anchor_delta_y: float = ball_anchor.y - last_followthrough_anchor_y
					if anchor_delta_y < -0.25:
						if first_upward_phase == "":
							first_upward_phase = sim_phase
							first_upward_delta = anchor_delta_y
						if sim_phase != BallSimulator.FLIGHT_PHASE_FLOOR_SETTLE and not saw_pre_bounce_upward:
							saw_pre_bounce_upward = true
							pre_bounce_upward_phase = sim_phase
							pre_bounce_upward_delta = anchor_delta_y
				last_followthrough_anchor_y = ball_anchor.y
			if smoke_coordinator.ball_simulator.get_render_phase_name() != "":
				last_explicit_hoop_anchor = ball_anchor
			if not first_floor_drop_recorded and sim_phase == BallSimulator.FLIGHT_PHASE_FLOOR_DROP:
				first_floor_drop_recorded = true
				first_floor_drop_anchor = ball_anchor
			if phase == "front_of_net" and first_phase_frame.has("net_channel") and frame > int(first_phase_frame["net_channel"]) and front_after_net_frame == -1:
				front_after_net_frame = frame
			if phase == "front_of_net" and first_phase_frame.has("net_channel"):
				if not front_window_active:
					front_window_active = true
					front_window_count += 1
			elif front_window_active:
				front_window_active = false
			if front_after_net_frame != -1 and phase == "" and not floor_phase_cleared:
				floor_phase_cleared = true
				floor_phase_cleared_anchor = ball_anchor
				if smoke_coordinator.hoop_node != null and smoke_coordinator.hoop_node.has_method("get_front_net_exit_screen_y"):
					floor_phase_cleared_release_y = smoke_coordinator.hoop_node.call("get_front_net_exit_screen_y")
			if floor_phase_cleared and phase in ["net_channel", "front_of_net"]:
				reentered_hoop_render_after_clear = true
			if smoke_coordinator.context.home_score > 0 and not score_seen:
				score_seen = true
				score_phase = phase
				score_z = smoke_coordinator.ball_simulator.z
				if smoke_coordinator.has_method("get_net_swish_active"):
					swish_when_scored = bool(smoke_coordinator.call("get_net_swish_active"))
		if score_seen and smoke_coordinator.context.current_state == GameState.State.SHOT_IN_FLIGHT and not smoke_coordinator.ball_simulator.is_in_flight and smoke_coordinator.ball_simulator.z <= 0.01:
			landed_before_reset = true
			landed_position = smoke_coordinator.ball_simulator.position_xy
			landed_screen_anchor = smoke_coordinator.call("get_ball_screen_anchor")
			finish_center_world_after_landing = smoke_coordinator.get_finish_logic_center_world()
		if score_seen and front_after_net_frame != -1:
			if landed_before_reset:
				break
	_assert_true(first_phase_frame.has("net_channel"), "made shot enters net channel phase", str(first_phase_frame))
	_assert_true(front_after_net_frame != -1, "made shot emerges front of net", str(first_phase_frame))
	if first_phase_frame.has("rim_mouth") and first_phase_frame.has("net_channel"):
		_assert_true(int(first_phase_frame["rim_mouth"]) <= int(first_phase_frame["net_channel"]), "optional rim-mouth handoff occurs before net channel", str(first_phase_frame))
	if first_phase_frame.has("net_channel") and front_after_net_frame != -1:
		_assert_true(int(first_phase_frame["net_channel"]) < front_after_net_frame, "guided make phases stay ordered", str({"net_channel": first_phase_frame["net_channel"], "front_of_net": front_after_net_frame}))
	_assert_true(net_channel_mask_active_seen, "bottom-half mask activates during net channel", str(first_phase_frame))
	_assert_true(through_front_mask_active_seen, "bottom-half mask stays active during through-net front exit", str(first_phase_frame))
	_assert_true(net_channel_net_body_active_seen, "NetBody mask activates during net channel", str(first_phase_frame))
	_assert_true(through_front_net_body_active_seen, "NetBody mask stays active during through-net front exit", str(first_phase_frame))
	_assert_true(active_mask_order_ok, "active net masks render above through-net ball phases", JSON.stringify(active_mask_order_failure))
	_assert_true(front_window_count <= 1, "made shot uses one contiguous front-of-net window", str(front_window_count))
	_assert_true(through_net, "made shot records through-net follow-through", "")
	_assert_true(score_seen, "made shot resolves during smoke test", "")
	_assert_true(score_phase == "net_channel", "scored frame occurs during guided descent", score_phase)
	_assert_true(score_z <= smoke_coordinator.court_config.rim_height + 0.01, "score cannot appear while ball is above rim", str(score_z))
	_assert_true(floor_phase_cleared, "forced hoop render clears after net exit", str(first_phase_frame))
	_assert_true(not reentered_hoop_render_after_clear, "made shot never re-enters hoop render after clear", str(first_phase_frame))
	_assert_true(not saw_pre_bounce_upward, "made shot never moves upward before floor bounce", str({"phase": pre_bounce_upward_phase, "delta": pre_bounce_upward_delta}))
	if first_upward_phase != "":
		_assert_true(first_upward_phase == BallSimulator.FLIGHT_PHASE_FLOOR_SETTLE, "first upward motion appears only during floor bounce", str({"phase": first_upward_phase, "delta": first_upward_delta}))
	if first_floor_drop_recorded and not is_inf(last_explicit_hoop_anchor.y):
		_assert_true(first_floor_drop_anchor.y >= last_explicit_hoop_anchor.y - 0.75, "first floor-drop frame does not jump above hoop exit", "%0.2f %0.2f" % [first_floor_drop_anchor.y, last_explicit_hoop_anchor.y])
	if floor_phase_cleared and not is_inf(floor_phase_cleared_anchor.y) and not is_inf(floor_phase_cleared_release_y):
		_assert_true(floor_phase_cleared_anchor.y >= floor_phase_cleared_release_y - 0.75, "hoop render clears only after passing front-net exit threshold", "%0.2f %0.2f" % [floor_phase_cleared_anchor.y, floor_phase_cleared_release_y])
	_assert_true(landed_before_reset, "made shot lands before opponent sim begins", str({"state": smoke_coordinator.get_state_name(), "z": smoke_coordinator.ball_simulator.z}))
	_assert_true(landed_position.distance_to(finish_center_world) < 0.01, "made shot lands at finish-radius center", str(landed_position))
	if not is_inf(finish_center_screen_before_shot.x) and not is_inf(finish_center_screen_before_shot.y) and not is_inf(landed_screen_anchor.x) and not is_inf(landed_screen_anchor.y):
		_assert_true(landed_screen_anchor.distance_to(finish_center_screen_before_shot) <= 4.0, "made shot lands on the same visible finish-radius marker center", "%s %s" % [landed_screen_anchor, finish_center_screen_before_shot])
	if not is_inf(finish_center_world_after_landing.x) and not is_inf(finish_center_world_after_landing.y):
		_assert_true(finish_center_world_after_landing.distance_to(finish_center_world) < 0.01, "finish-radius center stays stable through score follow-through", "%s %s" % [finish_center_world, finish_center_world_after_landing])
	if smoke_coordinator.has_method("get_score_followthrough_active"):
		_assert_true(bool(smoke_coordinator.call("get_score_followthrough_active")) or floor_phase_cleared, "score follow-through activates through hoop exit then clears", "")
	if smoke_coordinator.has_method("get_net_swish_active"):
		_assert_true(swish_when_scored, "net swish activates on score", "")
	game_root.queue_free()
	await get_tree().process_frame


func _net_layer_texture_sizes_are_registered(layers: Dictionary) -> bool:
	var layer_names: Array[String] = ["net", "net_clean", "net_clean_bottom_half", "net_body"]
	var expected_size: Vector2 = Vector2(30.0, 28.0)
	var expected_position: Vector2 = Vector2.INF
	var expected_scale: Vector2 = Vector2.INF
	for layer_name in layer_names:
		var layer: Dictionary = layers.get(layer_name, {})
		if layer.is_empty() or not bool(layer.get("visible", false)):
			return false
		var texture_size: Vector2 = layer.get("texture_size", Vector2.ZERO)
		if texture_size.distance_to(expected_size) > 0.01:
			return false
		var position: Vector2 = layer.get("position", Vector2.INF)
		var scale: Vector2 = layer.get("scale", Vector2.INF)
		if expected_position == Vector2.INF:
			expected_position = position
			expected_scale = scale
			continue
		if position.distance_to(expected_position) > 0.01:
			return false
		if scale.distance_to(expected_scale) > 0.01:
			return false
	return true


func _run_dunk_auto_finish_floor_smoke() -> void:
	var game_root_scene: PackedScene = load("res://scenes/GameRoot.tscn")
	var game_root: Node2D = game_root_scene.instantiate() as Node2D
	add_child(game_root)
	await get_tree().process_frame
	await get_tree().process_frame
	var smoke_coordinator: GameCoordinator = game_root.get_node("GameCoordinator") as GameCoordinator
	_assert_true(smoke_coordinator != null, "dunk floor-finish smoke coordinator exists", "")
	if smoke_coordinator == null:
		game_root.queue_free()
		await get_tree().process_frame
		return
	smoke_coordinator.begin_test_mode(1811)
	smoke_coordinator.test_set_defenders_disabled(true)
	var dunker: PlayerController = smoke_coordinator.get_offense_player_by_role("LC")
	_assert_true(dunker != null, "dunk floor-finish smoke has dunker", "")
	if dunker != null:
		var finish_center_world: Vector2 = smoke_coordinator.get_finish_logic_center_world()
		dunker.world_position = finish_center_world + Vector2(-14.0, 92.0)
		dunker.velocity = Vector2.ZERO
		smoke_coordinator.test_force_offensive_rebound("LC")
		await _begin_release_test_shot(smoke_coordinator, dunker, 1, "dunk")
		var dunk_through_net: bool = false
		var dunk_landed: bool = false
		var dunk_landing_position: Vector2 = Vector2.INF
		for _frame in 240:
			await get_tree().process_frame
			if smoke_coordinator.has_method("did_last_scored_shot_pass_through_net"):
				dunk_through_net = bool(smoke_coordinator.call("did_last_scored_shot_pass_through_net"))
			if smoke_coordinator.context.home_score > 0 and smoke_coordinator.context.current_state == GameState.State.SHOT_IN_FLIGHT and not smoke_coordinator.ball_simulator.is_in_flight and smoke_coordinator.ball_simulator.z <= 0.01:
				dunk_landed = true
				dunk_landing_position = smoke_coordinator.ball_simulator.position_xy
				break
		_assert_true(dunk_through_net, "dunk auto-make still passes through net", "")
		_assert_true(dunk_landed, "dunk auto-make lands before reset", str({"state": smoke_coordinator.get_state_name(), "z": smoke_coordinator.ball_simulator.z}))
		_assert_true(dunk_landing_position.distance_to(finish_center_world) < 0.01, "dunk auto-make uses finish-radius floor target", str(dunk_landing_position))
	game_root.queue_free()
	await get_tree().process_frame


func _max_preview_z(points: Array[Dictionary]) -> float:
	var max_z: float = 0.0
	for point in points:
		max_z = maxf(max_z, point["z"])
	return max_z


func _find_roster_player_by_id(players: Array[PlayerData], player_id: String) -> PlayerData:
	for player_data in players:
		if player_data != null and player_data.player_id == player_id:
			return player_data
	return null


func _find_roster_slot_by_role(slots: Array[Dictionary], slot_role: String) -> Dictionary:
	for slot_data in slots:
		if str(slot_data.get("slot_role", "")) == slot_role:
			return slot_data
	return {}


func _find_roster_card_state_by_id(states: Array, player_id: String) -> Dictionary:
	for state in states:
		if state is Dictionary and str(state.get("player_id", "")) == player_id:
			return state
	return {}


func _new_ball_simulator(config: BallPhysicsConfig) -> BallSimulator:
	var simulator: BallSimulator = BallSimulator.new()
	simulator.gravity = config.gravity
	simulator.ball_radius = config.ball_radius
	return simulator


func _with_floor_finish(profile: Dictionary, floor_target_xy: Vector2, config: BallPhysicsConfig) -> Dictionary:
	var finished_profile: Dictionary = profile.duplicate(true)
	finished_profile["floor_target_xy"] = floor_target_xy
	finished_profile["floor_drop_duration"] = config.made_shot_floor_drop_duration
	finished_profile["floor_settle_hop_height"] = config.made_shot_floor_settle_hop_height
	finished_profile["floor_settle_duration"] = config.made_shot_floor_settle_duration
	return finished_profile


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
