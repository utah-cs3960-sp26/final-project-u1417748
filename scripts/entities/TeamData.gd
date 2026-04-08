class_name TeamData
extends Resource

@export var team_name: String = "Home"
@export var abbreviation: String = "HOM"
@export var primary_color: Color = Color(0.25, 0.6, 0.95)
@export var secondary_color: Color = Color(0.12, 0.16, 0.25)
@export var players: Array[PlayerData] = []


func get_player_by_role(role: String) -> PlayerData:
	for player in players:
		if player.role == role:
			return player
	return null
