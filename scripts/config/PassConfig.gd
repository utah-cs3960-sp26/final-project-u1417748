class_name PassConfig
extends Resource

@export var pass_speed: float = 820.0
@export var catch_radius: float = 54.0
@export var offense_catch_radius_multiplier_min: float = 0.88
@export var offense_catch_radius_multiplier_max: float = 1.12
@export var defense_intercept_radius_multiplier_min: float = 0.8
@export var defense_intercept_radius_multiplier_max: float = 1.18
@export var long_pass_threshold: float = 360.0
@export var cross_court_x_delta: float = 260.0
@export var base_interception_chance: float = 0.06
@export var long_pass_bonus: float = 0.11
@export var cross_court_bonus: float = 0.1
@export var lane_bonus: float = 0.18
@export var commit_chance_min: float = 0.0
@export var commit_chance_max: float = 0.65
@export var pass_accuracy_resistance_scale: float = 0.12
@export var catch_security_scale: float = 0.08
@export var defender_pressure_scale: float = 0.14
@export var steal_resolve_hold_duration: float = 0.36
@export var release_endpoint_pass_conversion: bool = true
