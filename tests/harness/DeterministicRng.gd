class_name HarnessDeterministicRng
extends RefCounted

var seed: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func reset(new_seed: int) -> void:
	seed = new_seed
	_rng.seed = seed


func randf() -> float:
	return _rng.randf()


func randi() -> int:
	return _rng.randi()


func randf_range(min_value: float, max_value: float) -> float:
	return _rng.randf_range(min_value, max_value)


func rand_index(size: int) -> int:
	if size <= 0:
		return -1
	return _rng.randi_range(0, size - 1)
