class_name SpacingSolver
extends RefCounted


func apply_spacing(
	desired_targets: Dictionary,
	players: Array[PlayerController],
	ballhandler: PlayerController,
	repulsion_radius: float,
	slide_strength: float
) -> Dictionary:
	var result: Dictionary = {}
	for player in players:
		if player == ballhandler:
			continue
		var target: Vector2 = desired_targets.get(player, player.world_position)
		var offset: Vector2 = Vector2.ZERO
		for other in players:
			if other == player:
				continue
			var diff: Vector2 = target - other.world_position
			var distance_value: float = diff.length()
			if distance_value <= 0.001 or distance_value > repulsion_radius:
				continue
			offset += diff.normalized() * (1.0 - distance_value / repulsion_radius) * slide_strength
		result[player] = target + offset
	return result
