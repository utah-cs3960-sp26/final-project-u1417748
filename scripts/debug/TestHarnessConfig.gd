extends Resource
class_name TestHarnessConfig

@export var deterministic_seed: int = 3960
@export var logs_directory: String = "user://logs"
@export var event_log_name: String = "structured_events.ndjson"
@export var test_log_name: String = "test_run.log"
@export var scenario_log_name: String = "scenario_run.ndjson"
@export var replay_log_name: String = "replay_frames.ndjson"
@export var sim_log_name: String = "opponent_sim.ndjson"
@export var pure_logic_test_directory: String = "res://tests/pure_logic"
@export var scenario_directory: String = "res://data/scenarios"
@export var balance_directory: String = "res://data/balance"
@export var auto_discover_tests: bool = true
@export var required_scenarios: PackedStringArray = PackedStringArray([
	"clean_pass_and_shoot_make",
	"contested_miss_defensive_rebound",
	"bad_cross_court_pass_steal",
	"stationary_pressure_turnover",
	"out_of_bounds_turnover",
	"offensive_rebound_continuation",
	"buzzer_shot_resolution",
	"pause_resume_safety",
	"long_run_stability"
])
@export var required_balance_batches: PackedStringArray = PackedStringArray([
	"open_green_reward",
	"timing_gradient",
	"contest_impact",
	"pass_risk_separation",
	"rebound_distribution",
	"difficulty_separation"
])
