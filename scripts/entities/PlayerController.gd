class_name PlayerController
extends Node2D

@onready var name_label: Label = $NameLabel

var player_data: PlayerData
var team_abbreviation: String = ""
var team_primary_color: Color = Color.WHITE
var team_secondary_color: Color = Color.BLACK
var offense_side: bool = true
var player_index: int = -1
var desired_position: Vector2 = Vector2.ZERO
var move_velocity: Vector2 = Vector2.ZERO
var controlled: bool = false
var has_ball: bool = false
var route_debug_target: Vector2 = Vector2.ZERO
var assignment_debug_target: Vector2 = Vector2.ZERO
var shadow_scale: float = 1.0

func setup(data: PlayerData, abbreviation: String, primary_color: Color, secondary_color: Color, is_offense: bool, index: int) -> void:
	player_data = data
	team_abbreviation = abbreviation
	team_primary_color = primary_color
	team_secondary_color = secondary_color
	offense_side = is_offense
	player_index = index
	var label_node: Label = get_node_or_null("NameLabel")
	if label_node != null:
		label_node.text = "%s %s" % [abbreviation, data.role.substr(0, min(2, data.role.length())).to_upper()]
	queue_redraw()

func set_controlled(value: bool) -> void:
	controlled = value
	queue_redraw()

func set_has_ball(value: bool) -> void:
	has_ball = value
	queue_redraw()

func get_speed_units() -> float:
	if player_data == null:
		return 300.0
	return lerpf(250.0, 430.0, float(player_data.speed) / 100.0)

func get_acceleration_units() -> float:
	if player_data == null:
		return 6.0
	return lerpf(5.0, 10.0, float(player_data.acceleration) / 100.0)

func get_rebound_score() -> float:
	if player_data == null:
		return 50.0
	return float(player_data.rebound)

func get_shooting_score() -> float:
	if player_data == null:
		return 50.0
	return float(player_data.shooting)

func get_handle_score() -> float:
	if player_data == null:
		return 50.0
	return float(player_data.handle)

func get_defense_score() -> float:
	if player_data == null:
		return 50.0
	return float(player_data.perimeter_defense)

func get_steal_score() -> float:
	if player_data == null:
		return 50.0
	return float(player_data.steal)

func get_block_score() -> float:
	if player_data == null:
		return 45.0
	return float(player_data.block)

func get_release_consistency() -> float:
	if player_data == null:
		return 50.0
	return float(player_data.release_consistency)

func get_pass_accuracy() -> float:
	if player_data == null:
		return 50.0
	return float(player_data.pass_accuracy)

func get_catch_score() -> float:
	if player_data == null:
		return 50.0
	return float(player_data.catch_rating)

func _ready() -> void:
	if name_label == null:
		return
	name_label.position = Vector2(-36.0, -66.0)
	name_label.size = Vector2(120.0, 24.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.text = "%s %s" % [team_abbreviation, player_data.role.substr(0, min(2, player_data.role.length())).to_upper()] if player_data != null else team_abbreviation
	name_label.modulate = Color.WHITE

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(0.0, 26.0), 22.0, Color(0, 0, 0, 0.22))
	var body_color: Color = team_primary_color if offense_side else team_secondary_color.lightened(0.18)
	var trim_color: Color = team_secondary_color if offense_side else team_primary_color
	draw_circle(Vector2.ZERO, 28.0, body_color)
	draw_circle(Vector2.ZERO, 28.0, Color(trim_color.r, trim_color.g, trim_color.b, 0.95), false, 6.0, true)
	if controlled:
		draw_arc(Vector2.ZERO, 38.0, 0.0, TAU, 32, Color("#fff4ba"), 4.0, true)
	if has_ball:
		draw_circle(Vector2(28, -8), 8.0, Color("#d66c25"))
		draw_circle(Vector2(28, -8), 8.0, Color("#2a1a10"), false, 2.0, true)
