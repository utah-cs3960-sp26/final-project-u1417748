class_name BallPhysicsConfig
extends Resource

@export var gravity: float = -920.0
@export var ball_radius: float = 18.0
@export var pass_height: float = 22.0
@export var shot_release_height: float = 44.0
@export var made_shot_min_apex_near: float = 320.0
@export var made_shot_min_apex_far: float = 540.0
@export var made_shot_min_flight_time_near: float = 1.2
@export var made_shot_min_flight_time_far: float = 1.6
@export var made_shot_entry_front_depth: float = 18.0
@export var made_shot_capture_radius: float = 24.0
@export var made_shot_descent_duration: float = 0.24
@export var made_shot_descent_centering_tolerance: float = 8.0
@export var made_shot_min_descent_angle_deg: float = 70.0
@export var made_shot_backboard_clearance: float = 18.0
@export var dunk_make_descent_duration: float = 0.2
@export var dunk_miss_bounce_vertical_speed: float = 360.0
@export var dunk_miss_bounce_lateral_speed: float = 240.0
@export var miss_apex_scale: float = 0.94
@export var miss_min_flight_time_scale: float = 0.97
@export var miss_shot_side_offset: float = 112.0
@export var miss_shot_depth_offset: float = 26.0
@export var preview_origin_offset: Vector2 = Vector2(0.0, 28.0)
@export var preview_sample_count: int = 42
@export var preview_sample_delta: float = 0.06
@export var preview_dot_radius_min: float = 4.0
@export var preview_dot_radius_max: float = 12.0
@export var preview_apex_emphasis_strength: float = 0.84
@export var rim_bounce_damping: float = 0.72
@export var backboard_bounce_damping: float = 0.78
@export var floor_bounce_damping: float = 0.38
@export var bank_assist: float = 0.22
