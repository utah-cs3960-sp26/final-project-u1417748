class_name ProjectionConfig
extends Resource

@export var camera_tilt_strength: float = 0.0
@export var depth_compression_exponent: float = 1.0
@export var screen_center_x: float = 540.0
@export var screen_floor_y: float = 1780.0
@export var screen_horizon_y: float = 220.0
@export var ground_lateral_scale_near: float = 1.08
@export var ground_lateral_scale_far: float = 1.08
@export var z_lift_vector: Vector2 = Vector2(0.0, -0.42)
@export var preview_projection_lift_multiplier: float = 1.08
@export var guided_make_terminal_screen_drop_px: float = 60.0
@export var actor_scale_near: float = 1.26
@export var actor_scale_far: float = 1.16
@export var actor_distance_to_hoop_scale_strength: float = 0.02
@export var shadow_offset: Vector2 = Vector2(0.0, 18.0)
@export var shadow_scale_near: float = 0.88
@export var shadow_scale_far: float = 0.8
@export var hoop_render_offset: Vector2 = Vector2(0.0, -34.0)
@export var debug_projection_enabled: bool = true
