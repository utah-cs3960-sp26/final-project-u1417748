class_name CourtProjection
extends RefCounted

var projection_config: ProjectionConfig
var court_config: CourtConfig


func _init(projection_config_value: ProjectionConfig = null, court_config_value: CourtConfig = null) -> void:
	projection_config = projection_config_value
	court_config = court_config_value


func set_configs(projection_config_value: ProjectionConfig, court_config_value: CourtConfig) -> void:
	projection_config = projection_config_value
	court_config = court_config_value


func world_to_screen_ground(world_xy: Vector2) -> Vector2:
	if projection_config == null or court_config == null:
		return world_xy
	var near_ratio: float = _get_near_ratio(world_xy.y)
	var lateral_scale: float = _get_ground_lateral_scale(near_ratio)
	var court_center_x: float = court_config.court_rect.get_center().x
	return Vector2(
		projection_config.screen_center_x + (world_xy.x - court_center_x) * lateral_scale,
		lerpf(projection_config.screen_horizon_y, projection_config.screen_floor_y, near_ratio)
	)


func world_to_screen(world_xy: Vector2, z: float) -> Vector2:
	var screen_ground: Vector2 = world_to_screen_ground(world_xy)
	if projection_config == null:
		return screen_ground
	return screen_ground + projection_config.z_lift_vector * z


func preview_world_to_screen(world_xy: Vector2, z: float) -> Vector2:
	var screen_ground: Vector2 = world_to_screen_ground(world_xy)
	if projection_config == null:
		return screen_ground
	return screen_ground + projection_config.z_lift_vector * z * projection_config.preview_projection_lift_multiplier


func guided_make_terminal_screen_drop(weight: float) -> float:
	if projection_config == null:
		return 0.0
	return projection_config.guided_make_terminal_screen_drop_px * clampf(weight, 0.0, 1.0)


func screen_to_world_ground(screen_xy: Vector2) -> Vector2:
	if projection_config == null or court_config == null:
		return screen_xy
	var near_ratio: float = _get_near_ratio_from_screen(screen_xy.y)
	var court_rect: Rect2 = court_config.court_rect
	var court_center_x: float = court_rect.get_center().x
	var lateral_scale: float = _get_ground_lateral_scale(near_ratio)
	return Vector2(
		court_center_x + (screen_xy.x - projection_config.screen_center_x) / maxf(lateral_scale, 0.001),
		court_rect.position.y + pow(near_ratio, 1.0 / _effective_tilt_exponent()) * court_rect.size.y
	)


func depth_key(world_xy: Vector2, z: float = 0.0) -> float:
	var screen_point: Vector2 = world_to_screen(world_xy, z)
	return screen_point.y


func actor_scale(world_xy: Vector2, z: float = 0.0) -> float:
	if projection_config == null or court_config == null:
		return 1.0
	var near_ratio: float = _get_near_ratio(world_xy.y)
	var hoop_distance_ratio: float = clampf(world_xy.distance_to(court_config.hoop_position) / maxf(court_config.court_rect.size.length(), 1.0), 0.0, 1.0)
	var base_scale: float = lerpf(projection_config.actor_scale_far, projection_config.actor_scale_near, near_ratio)
	var hoop_scale: float = lerpf(1.0, 1.0 - projection_config.actor_distance_to_hoop_scale_strength, hoop_distance_ratio)
	var z_scale: float = lerpf(1.0, 0.92, clampf(z / 900.0, 0.0, 1.0))
	return base_scale * hoop_scale * z_scale


func shadow_scale(world_xy: Vector2, z: float = 0.0) -> float:
	if projection_config == null:
		return 1.0
	var near_ratio: float = _get_near_ratio(world_xy.y)
	var ground_scale: float = lerpf(projection_config.shadow_scale_far, projection_config.shadow_scale_near, near_ratio)
	var z_scale: float = lerpf(1.0, 0.46, clampf(z / 820.0, 0.0, 1.0))
	return ground_scale * z_scale


func shadow_anchor(world_xy: Vector2) -> Vector2:
	return world_to_screen_ground(world_xy) + (projection_config.shadow_offset if projection_config != null else Vector2.ZERO)


func hoop_screen_anchor() -> Vector2:
	if court_config == null:
		return Vector2.ZERO
	return world_to_screen_ground(court_config.hoop_position) + (projection_config.hoop_render_offset if projection_config != null else Vector2.ZERO)


func project_polyline(points: Array[Vector2], z: float = 0.0) -> PackedVector2Array:
	var projected: PackedVector2Array = PackedVector2Array()
	for point in points:
		projected.append(world_to_screen(point, z))
	return projected


func project_circle(center: Vector2, radius: float, z: float = 0.0, sample_count: int = 24) -> PackedVector2Array:
	var projected: PackedVector2Array = PackedVector2Array()
	var count: int = maxi(sample_count, 8)
	for index in count:
		var angle: float = (float(index) / float(count)) * TAU
		var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		projected.append(world_to_screen(point, z))
	return projected


func project_screen_ring(center: Vector2, screen_radius: float, sample_count: int = 24) -> PackedVector2Array:
	var projected: PackedVector2Array = PackedVector2Array()
	var count: int = maxi(sample_count, 8)
	for index in count:
		var angle: float = (float(index) / float(count)) * TAU
		projected.append(center + Vector2(cos(angle), sin(angle)) * screen_radius)
	return projected


func _get_near_ratio(world_y: float) -> float:
	if court_config == null:
		return 0.0
	var court_rect: Rect2 = court_config.court_rect
	var normalized_y: float = clampf((world_y - court_rect.position.y) / maxf(court_rect.size.y, 1.0), 0.0, 1.0)
	return pow(normalized_y, _effective_tilt_exponent())


func _get_near_ratio_from_screen(screen_y: float) -> float:
	if projection_config == null:
		return 0.0
	var span: float = maxf(projection_config.screen_floor_y - projection_config.screen_horizon_y, 1.0)
	return clampf((screen_y - projection_config.screen_horizon_y) / span, 0.0, 1.0)


func _get_ground_lateral_scale(near_ratio: float) -> float:
	if projection_config == null:
		return 1.0
	return lerpf(projection_config.ground_lateral_scale_far, projection_config.ground_lateral_scale_near, near_ratio)


func _effective_tilt_exponent() -> float:
	if projection_config == null:
		return 1.0
	return lerpf(1.0, projection_config.depth_compression_exponent, projection_config.camera_tilt_strength)
