class_name ProjectionConfig
extends Resource

@export var camera_tilt_strength: float = 0.0
@export var depth_compression_exponent: float = 1.0
@export var camera_zoom_multiplier: float = 2.1
@export var camera_tracking_smoothing_seconds: float = 0.10
@export var player_tracking_anchor_offset: Vector2 = Vector2(0.0, -44.0)
@export var screen_center_x: float = 540.0
@export var screen_floor_y: float = 1920.0
@export var screen_horizon_y: float = 0.0
@export var ground_lateral_scale_near: float = 1.2857143
@export var ground_lateral_scale_far: float = 1.2857143
@export var z_lift_vector: Vector2 = Vector2(0.0, -0.42)
@export var preview_projection_lift_multiplier: float = 1.08
@export var guided_make_terminal_screen_drop_px: float = 60.0
@export var actor_scale_near: float = 1.5
@export var actor_scale_far: float = 1.3809524
@export var actor_distance_to_hoop_scale_strength: float = 0.02
@export var held_ball_render_radius: float = 24.0
@export var live_ball_render_radius_min: float = 26.785715
@export var live_ball_render_radius_max: float = 53.57143
@export var shadow_offset: Vector2 = Vector2(0.0, 18.0)
@export var shadow_scale_near: float = 0.88
@export var shadow_scale_far: float = 0.8
@export var hoop_render_offset: Vector2 = Vector2(0.0, 8.0)
@export var hoop_visual_scale_multiplier: float = 1.1904762
@export var debug_projection_enabled: bool = true
