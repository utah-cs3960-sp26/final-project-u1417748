extends RefCounted
class_name DeterministicRng

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _seed: int = 0

func _init(seed_value: int = 0) -> void:
	reseed(seed_value)

func reseed(seed_value: int) -> void:
	_seed = seed_value
	_rng.seed = seed_value

func next_float() -> float:
	return _rng.randf()

func next_range(min_value: float, max_value: float) -> float:
	return _rng.randf_range(min_value, max_value)

func next_int(min_value: int, max_value: int) -> int:
	return _rng.randi_range(min_value, max_value)

func pick_index(count: int) -> int:
	if count <= 0:
		return -1
	return _rng.randi_range(0, count - 1)

func snapshot() -> Dictionary:
	return {
		"seed": _seed,
		"state": _rng.state,
	}

func restore(snapshot: Dictionary) -> void:
	_seed = int(snapshot.get("seed", _seed))
	_rng.seed = _seed
	if snapshot.has("state"):
		_rng.state = int(snapshot["state"])
