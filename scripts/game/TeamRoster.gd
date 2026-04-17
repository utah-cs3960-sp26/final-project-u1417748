extends Node

const PlayerRatingScript: GDScript = preload("res://scripts/entities/PlayerRating.gd")

const HOME_TEAM_PATH: String = "res://data/teams/HOM.tres"
const AWAY_TEAM_PATH: String = "res://data/teams/AWY.tres"

const NICKNAME_POOL: PackedStringArray = [
	"Ace", "Blaze", "Bolt", "Breeze", "Chip", "Comet", "Cyclone", "Dagger",
	"Dash", "Drift", "Echo", "Flash", "Flex", "Frost", "Ghost", "Hawk",
	"Hex", "Jet", "Jinx", "Knox", "Maverick", "Nitro", "Pixel", "Rogue",
	"Shade", "Sniper", "Spark", "Streak", "Tank", "Vortex",
]

var home_team: TeamData
var away_team: TeamData

var _overall_cache: Dictionary = {}


func _ready() -> void:
	home_team = load(HOME_TEAM_PATH) as TeamData
	away_team = load(AWAY_TEAM_PATH) as TeamData
	if home_team != null:
		_randomize_home_names()


func get_home_team() -> TeamData:
	return home_team


func get_away_team() -> TeamData:
	return away_team


func get_overall(player_data: PlayerData) -> int:
	if player_data == null:
		return 50
	if not _overall_cache.has(player_data):
		_overall_cache[player_data] = PlayerRatingScript.compute(player_data)
	return int(_overall_cache[player_data])


func _randomize_home_names() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(Time.get_unix_time_from_system())
	var pool: Array = []
	for name in NICKNAME_POOL:
		pool.append(name)
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for i in home_team.players.size():
		home_team.players[i].display_name = str(pool[i % pool.size()])
