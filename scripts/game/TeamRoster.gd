extends Node

const PlayerRatingScript: GDScript = preload("res://scripts/entities/PlayerRating.gd")

const HOME_TEAM_PATH: String = "res://data/teams/HOM.tres"
const AWAY_TEAM_PATH: String = "res://data/teams/AWY.tres"
const SHOP_CATALOG_PATH: String = "res://data/teams/ShopCatalog.tres"
const STARTING_COINS: int = 1000
const LINEUP_SLOT_ROLES := ["PG", "LW", "RW", "LC", "RC"]

const NICKNAME_POOL: PackedStringArray = [
	"Ace", "Blaze", "Bolt", "Breeze", "Chip", "Comet", "Cyclone", "Dagger",
	"Dash", "Drift", "Echo", "Flash", "Flex", "Frost", "Ghost", "Hawk",
	"Hex", "Jet", "Jinx", "Knox", "Maverick", "Nitro", "Pixel", "Rogue",
	"Shade", "Sniper", "Spark", "Streak", "Tank", "Vortex",
]

signal coins_changed(new_value: int)
signal home_roster_changed()

var _authored_home_team: TeamData
var _authored_away_team: TeamData
var _shop_catalog

var _runtime_home_lineup: Dictionary = {}
var _runtime_home_bench: Array[PlayerData] = []
var _runtime_shop_players: Array[PlayerData] = []
var _purchased_shop_ids: Dictionary = {}
var _coin_balance: int = STARTING_COINS

var _overall_cache: Dictionary = {}


func _ready() -> void:
	_authored_home_team = load(HOME_TEAM_PATH) as TeamData
	_authored_away_team = load(AWAY_TEAM_PATH) as TeamData
	_shop_catalog = load(SHOP_CATALOG_PATH)
	reset_demo_state()


func get_home_team() -> TeamData:
	var template: TeamData = _authored_home_team if _authored_home_team != null else TeamData.new()
	var runtime_team: TeamData = _clone_team_data(template)
	runtime_team.players.clear()
	for slot_role in LINEUP_SLOT_ROLES:
		var slot_player: PlayerData = _runtime_home_lineup.get(slot_role, null) as PlayerData
		if slot_player == null:
			continue
		var gameplay_player: PlayerData = _clone_player_data(slot_player)
		gameplay_player.role = slot_role
		if gameplay_player.player_id.strip_edges() == "":
			gameplay_player.player_id = "hom_%s_runtime" % slot_role.to_lower()
		runtime_team.players.append(gameplay_player)
	return runtime_team


func get_away_team() -> TeamData:
	return _authored_away_team


func get_overall(player_data: PlayerData) -> int:
	if player_data == null:
		return 50
	if not _overall_cache.has(player_data):
		_overall_cache[player_data] = PlayerRatingScript.compute(player_data)
	return int(_overall_cache[player_data])


func get_coin_balance() -> int:
	return _coin_balance


func get_shop_players() -> Array[PlayerData]:
	var players: Array[PlayerData] = []
	players.append_array(_runtime_shop_players)
	return players


func get_home_lineup_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for slot_role in LINEUP_SLOT_ROLES:
		slots.append({
			"slot_role": slot_role,
			"player": _runtime_home_lineup.get(slot_role, null) as PlayerData,
		})
	return slots


func get_home_bench_players() -> Array[PlayerData]:
	var players: Array[PlayerData] = []
	players.append_array(_runtime_home_bench)
	return players


func is_shop_player_purchased(player_id: String) -> bool:
	return bool(_purchased_shop_ids.get(player_id, false))


func purchase_shop_player(player_id: String) -> Dictionary:
	var catalog_player: PlayerData = _find_player_by_id(_runtime_shop_players, player_id)
	if catalog_player == null:
		return {"success": false, "reason": "missing_player"}
	if is_shop_player_purchased(player_id):
		return {"success": false, "reason": "already_purchased"}
	if _coin_balance < catalog_player.purchase_cost:
		return {"success": false, "reason": "insufficient_funds"}
	_coin_balance -= catalog_player.purchase_cost
	_purchased_shop_ids[player_id] = true
	_runtime_home_bench.append(_clone_player_data(catalog_player))
	coins_changed.emit(_coin_balance)
	home_roster_changed.emit()
	return {
		"success": true,
		"reason": "purchased",
		"player_id": player_id,
		"coins_remaining": _coin_balance,
	}


func swap_lineup_slot_with_bench(slot_role: String, bench_player_id: String) -> bool:
	if not LINEUP_SLOT_ROLES.has(slot_role):
		return false
	var bench_index: int = _find_player_index_by_id(_runtime_home_bench, bench_player_id)
	if bench_index < 0:
		return false
	var lineup_player: PlayerData = _runtime_home_lineup.get(slot_role, null) as PlayerData
	var bench_player: PlayerData = _runtime_home_bench[bench_index]
	if lineup_player == null or bench_player == null:
		return false
	_runtime_home_lineup[slot_role] = bench_player
	_runtime_home_bench[bench_index] = lineup_player
	home_roster_changed.emit()
	return true


func reset_demo_state() -> void:
	_runtime_home_lineup.clear()
	_runtime_home_bench.clear()
	_runtime_shop_players.clear()
	_purchased_shop_ids.clear()
	_coin_balance = STARTING_COINS
	_overall_cache.clear()
	_seed_home_lineup_from_authored_team()
	_seed_shop_from_catalog()
	_randomize_home_names()
	coins_changed.emit(_coin_balance)
	home_roster_changed.emit()


func _seed_home_lineup_from_authored_team() -> void:
	if _authored_home_team == null:
		return
	for slot_role in LINEUP_SLOT_ROLES:
		var authored_player: PlayerData = _authored_home_team.get_player_by_role(slot_role)
		if authored_player != null:
			_runtime_home_lineup[slot_role] = _clone_player_data(authored_player)


func _seed_shop_from_catalog() -> void:
	if _shop_catalog == null:
		return
	for player_data in _shop_catalog.players:
		if player_data == null:
			continue
		_runtime_shop_players.append(_clone_player_data(player_data))


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
	for index in LINEUP_SLOT_ROLES.size():
		var slot_role: String = LINEUP_SLOT_ROLES[index]
		var lineup_player: PlayerData = _runtime_home_lineup.get(slot_role, null) as PlayerData
		if lineup_player == null:
			continue
		lineup_player.display_name = str(pool[index % pool.size()])


func _find_player_by_id(players: Array[PlayerData], player_id: String) -> PlayerData:
	for player_data in players:
		if player_data != null and player_data.player_id == player_id:
			return player_data
	return null


func _find_player_index_by_id(players: Array[PlayerData], player_id: String) -> int:
	for index in range(players.size()):
		var player_data: PlayerData = players[index]
		if player_data != null and player_data.player_id == player_id:
			return index
	return -1


func _clone_team_data(source_team: TeamData) -> TeamData:
	var cloned_team: TeamData = TeamData.new()
	cloned_team.team_name = source_team.team_name
	cloned_team.abbreviation = source_team.abbreviation
	cloned_team.primary_color = source_team.primary_color
	cloned_team.secondary_color = source_team.secondary_color
	cloned_team.players = []
	return cloned_team


func _clone_player_data(source_player: PlayerData) -> PlayerData:
	var cloned_player: PlayerData = PlayerData.new()
	cloned_player.player_id = source_player.player_id
	cloned_player.display_name = source_player.display_name
	cloned_player.role = source_player.role
	cloned_player.purchase_cost = source_player.purchase_cost
	cloned_player.speed = source_player.speed
	cloned_player.acceleration = source_player.acceleration
	cloned_player.handle = source_player.handle
	cloned_player.pass_accuracy = source_player.pass_accuracy
	cloned_player.catch_rating = source_player.catch_rating
	cloned_player.shooting = source_player.shooting
	cloned_player.release_consistency = source_player.release_consistency
	cloned_player.perimeter_defense = source_player.perimeter_defense
	cloned_player.steal = source_player.steal
	cloned_player.dunk = source_player.dunk
	cloned_player.block = source_player.block
	cloned_player.rebound = source_player.rebound
	cloned_player.sim_offense = source_player.sim_offense
	return cloned_player
