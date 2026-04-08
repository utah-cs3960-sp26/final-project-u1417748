class_name ProjectionConfig
extends Resource

@export var camera_tilt_strength: float = 0.82
@export var depth_compression_exponent: float = 1.45
@export var screen_center_x: float = 540.0
@export var screen_floor_y: float = 1600.0
@export var screen_horizon_y: float = 320.0
@export var ground_lateral_scale_near: float = 1.0
@export var ground_lateral_scale_far: float = 0.66
@export var z_lift_vector: Vector2 = Vector2(0.0, -0.16)
@export var preview_projection_lift_multiplier: float = 1.0
@export var actor_scale_near: float = 1.08
@export var actor_scale_far: float = 0.82
@export var actor_distance_to_hoop_scale_strength: float = 0.10
@export var shadow_offset: Vector2 = Vector2(0.0, 18.0)
@export var shadow_scale_near: float = 1.0
@export var shadow_scale_far: float = 0.45
@export var hoop_render_offset: Vector2 = Vector2(0.0, -34.0)
@export var debug_projection_enabled: bool = true
