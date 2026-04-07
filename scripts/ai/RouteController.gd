class_name RouteController
extends RefCounted

enum Package {
	WING_SWAP,
	STRONG_SIDE_SLASH,
	WEAK_SIDE_FILL,
}

static func get_active_package(possession_time: float, config: RouteConfig) -> int:
	return int(floor(possession_time / config.package_duration)) % 3

static func get_route_targets(court_config: CourtConfig, ballhandler_position: Vector2, possession_time: float, config: RouteConfig) -> Array[Vector2]:
	var anchors: Array[Vector2] = court_config.get_default_anchors()
	var targets: Array[Vector2] = anchors.duplicate()
	var package_index: int = get_active_package(possession_time, config)
	var phase: float = fposmod(possession_time, config.package_duration) / config.package_duration
	var hoop_pos: Vector2 = court_config.get_hoop_world_position()
	var slot_left: Vector2 = Vector2(anchors[1].x + 80.0, anchors[1].y - config.slot_lift)
	var slot_right: Vector2 = Vector2(anchors[2].x - 80.0, anchors[2].y - config.slot_lift)
	match package_index:
		Package.WING_SWAP:
			targets[1] = _two_segment_path(anchors[1], slot_left, anchors[2], phase)
			targets[2] = _two_segment_path(anchors[2], slot_right, anchors[1], phase)
			targets[3] = anchors[3] + Vector2(18.0 * sin(phase * TAU), -config.corner_lift * 0.3)
			targets[4] = anchors[4] + Vector2(-18.0 * sin(phase * TAU), config.corner_lift * 0.25)
		Package.STRONG_SIDE_SLASH:
			var left_side: bool = ballhandler_position.x <= anchors[0].x
			var strong_wing: int = 1 if left_side else 2
			var weak_wing: int = 2 if left_side else 1
			var strong_corner: int = 3 if left_side else 4
			var weak_corner: int = 4 if left_side else 3
			var middle_high: Vector2 = Vector2(anchors[0].x, anchors[1].y - config.lane_cut_offset)
			targets[strong_wing] = _two_segment_path(anchors[strong_wing], middle_high, anchors[weak_wing], phase)
			targets[weak_wing] = anchors[strong_wing].lerp(anchors[weak_wing], phase)
			targets[strong_corner] = anchors[strong_corner] + Vector2(0.0, -config.corner_lift * 0.6)
			targets[weak_corner] = anchors[weak_corner] + Vector2(0.0, 24.0 * sin(phase * PI))
		Package.WEAK_SIDE_FILL:
			var left_weak: bool = ballhandler_position.x > anchors[0].x
			var weak_wing_idx: int = 1 if left_weak else 2
			var weak_corner_idx: int = 3 if left_weak else 4
			var strong_wing_idx: int = 2 if left_weak else 1
			var strong_corner_idx: int = 4 if left_weak else 3
			var opposite_corner: Vector2 = anchors[4] if left_weak else anchors[3]
			var lane_center: Vector2 = Vector2(anchors[0].x, hoop_pos.y + 220.0)
			targets[weak_wing_idx] = _two_segment_path(anchors[weak_wing_idx], lane_center, opposite_corner, phase)
			targets[weak_corner_idx] = anchors[weak_wing_idx].lerp(anchors[weak_corner_idx], 1.0 - phase)
			targets[strong_wing_idx] = anchors[strong_wing_idx] + Vector2(0.0, -config.slot_lift * 0.6)
			targets[strong_corner_idx] = anchors[strong_corner_idx] + Vector2(0.0, -config.corner_lift * 0.25)
	_apply_spacing(targets, ballhandler_position, config)
	return targets

static func _two_segment_path(start: Vector2, midpoint: Vector2, finish: Vector2, phase: float) -> Vector2:
	if phase < 0.5:
		return start.lerp(midpoint, phase * 2.0)
	return midpoint.lerp(finish, (phase - 0.5) * 2.0)

static func _apply_spacing(targets: Array[Vector2], ballhandler_position: Vector2, config: RouteConfig) -> void:
	for index: int in range(1, targets.size()):
		var offset_from_ballhandler: Vector2 = targets[index] - ballhandler_position
		if offset_from_ballhandler.length() < config.ballhandler_lane_buffer:
			var push_dir: Vector2 = offset_from_ballhandler.normalized()
			if push_dir.length_squared() < 0.001:
				push_dir = Vector2.RIGHT.rotated(float(index))
			targets[index] += push_dir * (config.ballhandler_lane_buffer - offset_from_ballhandler.length())
	for i: int in range(1, targets.size()):
		for j: int in range(i + 1, targets.size()):
			var delta: Vector2 = targets[i] - targets[j]
			var distance: float = delta.length()
			if distance < config.spacing_push_radius:
				var push: Vector2 = delta.normalized()
				if push.length_squared() < 0.001:
					push = Vector2.RIGHT.rotated(float(i + j))
				var amount: float = (config.spacing_push_radius - distance) / config.spacing_push_radius * config.spacing_push_strength
				targets[i] += push * amount
				targets[j] -= push * amount
