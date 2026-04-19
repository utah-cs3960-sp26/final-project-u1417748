class_name ShopScreen
extends Control

const MENU_BACKGROUND_SCRIPT: GDScript = preload("res://scripts/game/MenuBackground.gd")
const ROSTER_PLAYER_CARD_SCRIPT: GDScript = preload("res://scripts/game/RosterPlayerCard.gd")
const TEAM_SCENE_PATH: String = "res://scenes/TeamScreen.tscn"
const CARDS_PER_ROW: int = 2

@onready var _court_background: TextureRect = $CourtBackground
@onready var _coins_badge = %CoinsBadge
@onready var _cards_container: VBoxContainer = %CardsContainer
@onready var _back_button: Button = %BackButton

var _row_counts: Array[int] = []
var _card_states: Array[Dictionary] = []


func _ready() -> void:
	MENU_BACKGROUND_SCRIPT.apply_to(_court_background)
	_back_button.pressed.connect(_on_back_pressed)
	if not TeamRoster.coins_changed.is_connected(_on_roster_data_changed):
		TeamRoster.coins_changed.connect(_on_roster_data_changed)
	if not TeamRoster.home_roster_changed.is_connected(_on_roster_data_changed):
		TeamRoster.home_roster_changed.connect(_on_roster_data_changed)
	_refresh_coin_badge()
	_refresh_cards()


func get_layout_snapshot() -> Dictionary:
	return {
		"offer_count": _card_states.size(),
		"row_count": _row_counts.size(),
		"row_card_counts": _row_counts.duplicate(),
		"coin_balance_text": _coins_badge.get_value_text() if _coins_badge != null else "",
		"bottom_button_gap": _get_bottom_button_gap(),
		"bottom_button_side_inset": _get_bottom_button_side_inset(),
		"states": _card_states.duplicate(true),
	}


func _refresh_coin_badge() -> void:
	if _coins_badge != null:
		_coins_badge.set_coins(TeamRoster.get_coin_balance())


func _refresh_cards() -> void:
	for child in _cards_container.get_children():
		child.queue_free()
	_row_counts.clear()
	_card_states.clear()
	var cards: Array[Control] = []
	for player_data in TeamRoster.get_shop_players():
		if player_data == null:
			continue
		var purchased: bool = TeamRoster.is_shop_player_purchased(player_data.player_id)
		var can_afford: bool = TeamRoster.get_coin_balance() >= player_data.purchase_cost
		var button_text: String = "Buy"
		var status_text: String = ""
		var button_disabled: bool = false
		if purchased:
			button_text = "Purchased"
			button_disabled = true
			status_text = "Added to bench"
		elif not can_afford:
			button_text = "Too Expensive"
			button_disabled = true
			status_text = "%d more coins needed" % (player_data.purchase_cost - TeamRoster.get_coin_balance())
		var card = ROSTER_PLAYER_CARD_SCRIPT.new()
		card.focus_mode = Control.FOCUS_NONE
		card.setup_for_shop(player_data, button_text, button_disabled, status_text)
		card.action_pressed.connect(_on_card_action_pressed)
		_card_states.append({
			"player_id": player_data.player_id,
			"button_text": button_text,
			"button_disabled": button_disabled,
			"status_text": status_text,
		})
		cards.append(card)
	_row_counts = _build_wrapped_rows(cards)


func _build_wrapped_rows(cards: Array[Control]) -> Array[int]:
	var row_counts: Array[int] = []
	var current_row: HBoxContainer
	for index in range(cards.size()):
		if index % CARDS_PER_ROW == 0:
			current_row = HBoxContainer.new()
			current_row.alignment = BoxContainer.ALIGNMENT_CENTER
			current_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			current_row.add_theme_constant_override("separation", 24)
			_cards_container.add_child(current_row)
			row_counts.append(0)
		current_row.add_child(cards[index])
		row_counts[row_counts.size() - 1] += 1
	return row_counts


func _on_card_action_pressed(player_id: String) -> void:
	TeamRoster.purchase_shop_player(player_id)


func _on_roster_data_changed(_value = null) -> void:
	_refresh_coin_badge()
	_refresh_cards()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(TEAM_SCENE_PATH)


func _get_bottom_button_gap() -> float:
	if _back_button == null:
		return 0.0
	return get_viewport_rect().end.y - _back_button.get_global_rect().end.y


func _get_bottom_button_side_inset() -> float:
	if _back_button == null:
		return 0.0
	var rect: Rect2 = _back_button.get_global_rect()
	return minf(rect.position.x, get_viewport_rect().size.x - rect.end.x)
