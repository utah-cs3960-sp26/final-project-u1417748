class_name BallPhysicsConfig
extends Resource

@export var gravity: float = -920.0
@export var ball_radius: float = 18.0
@export var pass_height: float = 22.0
@export var made_shot_flight_time_near: float = 0.72
@export var made_shot_flight_time_far: float = 0.96
@export var miss_shot_flight_time_near: float = 0.68
@export var miss_shot_flight_time_far: float = 0.9
@export var miss_shot_side_offset: float = 112.0
@export var miss_shot_depth_offset: float = 26.0
@export var starter_forward_speed: float = 120.0
@export var max_forward_speed: float = 680.0
@export var starter_z_speed: float = 300.0
@export var max_z_speed: float = 1180.0
@export var forward_growth_curve_exponent: float = 2.15
@export var arc_growth_curve_exponent: float = 0.78
@export var preview_origin_offset: Vector2 = Vector2(0.0, 28.0)
@export var preview_sample_count: int = 30
@export var preview_sample_delta: float = 0.055
@export var preview_dot_radius_min: float = 3.5
@export var preview_dot_radius_max: float = 10.5
@export var preview_apex_emphasis_strength: float = 0.72
@export var rim_bounce_damping: float = 0.72
@export var backboard_bounce_damping: float = 0.78
@export var floor_bounce_damping: float = 0.38
@export var bank_assist: float = 0.22
