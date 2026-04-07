class_name TeamData
extends Resource

@export var team_name: String = "Home"
@export var abbreviation: String = "HOM"
@export var primary_color: Color = Color("#f6d365")
@export var secondary_color: Color = Color("#11172a")
@export var players: Array[PlayerData] = []

func get_player(index: int) -> PlayerData:
	if index < 0 or index >= players.size():
		return null
	return players[index]
