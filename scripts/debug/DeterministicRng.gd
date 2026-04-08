class_name GameRng
extends RefCounted

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var seed: int = 0


func _init(p_seed: int = 0) -> void:
	reseed(p_seed)


func reseed(p_seed: int) -> void:
	seed = p_seed
	_rng.seed = p_seed


func randf() -> float:
	return _rng.randf()


func randf_range(min_value: float, max_value: float) -> float:
	return _rng.randf_range(min_value, max_value)


func randi_range(min_value: int, max_value: int) -> int:
	return _rng.randi_range(min_value, max_value)


func rand_weighted(weights: Array[float]) -> int:
	var total: float = 0.0
	for weight in weights:
		total += maxf(weight, 0.0)
	if total <= 0.0:
		return 0
	var roll: float = randf() * total
	var cumulative: float = 0.0
	for index in weights.size():
		cumulative += maxf(weights[index], 0.0)
		if roll <= cumulative:
			return index
	return maxi(weights.size() - 1, 0)
