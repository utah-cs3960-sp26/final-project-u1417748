class_name TeamScreen
extends Control

const MENU_BACKGROUND_SCRIPT: GDScript = preload("res://scripts/game/MenuBackground.gd")
const ROSTER_PLAYER_CARD_SCRIPT: GDScript = preload("res://scripts/game/RosterPlayerCard.gd")
const MAIN_MENU_SCENE_PATH: String = "res://scenes/MainMenu.tscn"
const SHOP_SCENE_PATH: String = "res://scenes/ShopScreen.tscn"
const PHONE_LAYOUT_WIDTH: float = 1080.0
const BOTTOM_BAR_BOTTOM_GAP: float = 50.0
const BOTTOM_BAR_SIDE_INSET: float = 30.0
const SUBTITLE_TO_SECTION_GAP: float = 20.0
const DRAG_HOVER_PADDING: float = 72.0
const SWAP_ANIMATION_DURATION: float = 0.24
const CANCEL_ANIMATION_DURATION: float = 0.16

@onready var _court_background: TextureRect = $CourtBackground
@onready var _title_label: Label = $Title
@onready var _subtitle_label: Label = $Subtitle
@onready var _starters_scroll: ScrollContainer = %StartersScroll
@onready var _starters_container: HBoxContainer = %StartersContainer
@onready var _bench_content: Control = %BenchContent
@onready var _bench_scroll: ScrollContainer = %BenchScroll
@onready var _bench_container: HBoxContainer = %BenchContainer
@onready var _bench_empty_label: Label = %BenchEmptyLabel
@onready var _starters_header_label: Label = %StartersHeader
@onready var _bench_header_label: Label = %BenchHeader
@onready var _coins_badge = %CoinsBadge
@onready var _bottom_bar: HBoxContainer = %BottomBar
@onready var _back_button: Button = %BackButton
@onready var _shop_button: Button = %ShopButton
@onready var _overlay_layer: Control = %OverlayLayer

var _lineup_cards_by_slot: Dictionary = {}
var _bench_cards_by_player_id: Dictionary = {}
var _active_drag: Dictionary = {}
var _active_strip_scroll: Dictionary = {}
var _hover_card
var _is_animating_drag: bool = false


func _ready() -> void:
	MENU_BACKGROUND_SCRIPT.apply_to(_court_background)
	_back_button.pressed.connect(_on_back_pressed)
	_shop_button.pressed.connect(_on_shop_pressed)
	if not TeamRoster.coins_changed.is_connected(_on_coins_changed):
		TeamRoster.coins_changed.connect(_on_coins_changed)
	if not TeamRoster.home_roster_changed.is_connected(_on_home_roster_changed):
		TeamRoster.home_roster_changed.connect(_on_home_roster_changed)
	_starters_scroll.gui_input.connect(_on_strip_gui_input.bind("starters", _starters_scroll))
	_bench_scroll.gui_input.connect(_on_strip_gui_input.bind("bench", _bench_scroll))
	_refresh_coin_badge()
	refresh_from_roster()
	call_deferred("_update_bench_placeholder_layout")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_update_bench_placeholder_layout")


func refresh_from_roster() -> void:
	_refresh_coin_badge()
	_rebuild_lineup_cards()
	_rebuild_bench_cards()
	_sync_strip_content_width(_starters_scroll, _starters_container)
	_sync_strip_content_width(_bench_scroll, _bench_container)
	call_deferred("_update_bench_placeholder_layout")


func get_card_layout_snapshot() -> Dictionary:
	_update_bench_placeholder_layout()
	var phone_column_width: float = $SectionsRoot.get_global_rect().size.x if has_node("SectionsRoot") else PHONE_LAYOUT_WIDTH
	return {
		"card_width": ROSTER_PLAYER_CARD_SCRIPT.get_card_width(),
		"sprite_display_size": ROSTER_PLAYER_CARD_SCRIPT.get_sprite_display_size(),
		"starter_card_count": _lineup_cards_by_slot.size(),
		"bench_count": _bench_cards_by_player_id.size(),
		"bench_placeholder_visible": _bench_empty_label.visible,
		"starters_horizontal_scroll": _uses_horizontal_scroll(_starters_scroll),
		"bench_horizontal_scroll": _uses_horizontal_scroll(_bench_scroll),
		"has_shop_button": _shop_button != null,
		"coin_balance_text": _coins_badge.get_value_text() if _coins_badge != null else "",
		"drag_hover_padding": DRAG_HOVER_PADDING,
		"bottom_bar_gap": _get_bottom_bar_gap(),
		"bottom_bar_side_inset": _get_bottom_bar_side_inset(),
		"drag_requires_handle": true,
		"body_swipe_scroll_passthrough": _cards_use_body_scroll_passthrough(),
		"carousel_matches_phone_width": absf(_starters_scroll.get_global_rect().size.x - phone_column_width) < 0.5 \
			and absf(_bench_scroll.get_global_rect().size.x - phone_column_width) < 0.5,
		"headers_align_with_title": _headers_align_with_title(),
		"subtitle_to_starters_gap": _get_subtitle_to_starters_gap(),
		"bench_placeholder_centered": _is_bench_placeholder_centered(),
		"starters_viewport_fits_card": _viewport_fits_card(_starters_scroll, _lineup_cards_by_slot.values()),
		"bench_viewport_fits_card": _viewport_fits_card(_bench_scroll, _bench_cards_by_player_id.values()),
	}


func debug_get_card_global_rect(card_kind: String, identifier: String) -> Rect2:
	var card = _get_card(card_kind, identifier)
	return card.get_global_rect() if card != null else Rect2()


func debug_resolve_drop_target(global_point: Vector2, source_kind: String, source_id: String) -> Dictionary:
	var target: Dictionary = _resolve_drop_target(source_kind, source_id, global_point)
	return {
		"kind": str(target.get("kind", "")),
		"id": str(target.get("id", "")),
	}


func debug_get_drag_handle_global_rect(card_kind: String, identifier: String) -> Rect2:
	var card = _get_card(card_kind, identifier)
	return card.get_drag_handle_global_rect() if card != null else Rect2()


func debug_simulate_strip_swipe(strip_kind: String, drag_delta_x: float) -> float:
	var scroll_container: ScrollContainer = _get_strip_scroll_container(strip_kind)
	if scroll_container == null:
		return -1.0
	_sync_strip_content_width(scroll_container, _get_strip_content_container(strip_kind))
	var original_scroll: float = _get_strip_scroll_value(scroll_container)
	var center: Vector2 = scroll_container.get_global_rect().get_center()
	_begin_strip_scroll(scroll_container, center, "mouse", -1)
	if _active_strip_scroll.is_empty():
		return original_scroll
	_update_strip_scroll(center + Vector2(drag_delta_x, 0.0))
	var scrolled_to: float = _get_strip_scroll_value(scroll_container)
	_finish_strip_scroll()
	_set_strip_scroll(scroll_container, original_scroll)
	return scrolled_to


func debug_simulate_body_press(card_kind: String, identifier: String) -> bool:
	_debug_reset_drag_state()
	var card = _get_card(card_kind, identifier)
	if card == null:
		return false
	var press_event: InputEventMouseButton = InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	press_event.position = card.size * 0.5 if card.size != Vector2.ZERO else Vector2(12.0, 12.0)
	card.gui_input.emit(press_event)
	var drag_started: bool = not _active_drag.is_empty()
	_debug_reset_drag_state()
	return drag_started


func debug_simulate_handle_press(card_kind: String, identifier: String) -> bool:
	_debug_reset_drag_state()
	var card = _get_card(card_kind, identifier)
	if card == null or not card.has_drag_handle():
		return false
	var press_event: InputEventMouseButton = InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	card.debug_emit_drag_handle_input(press_event)
	var drag_started: bool = not _active_drag.is_empty()
	_debug_reset_drag_state()
	return drag_started


func _input(event: InputEvent) -> void:
	if not _active_strip_scroll.is_empty():
		if event is InputEventMouseMotion and str(_active_strip_scroll.get("pointer_kind", "")) == "mouse":
			_update_strip_scroll((event as InputEventMouseMotion).position)
			return
		elif event is InputEventMouseButton and str(_active_strip_scroll.get("pointer_kind", "")) == "mouse":
			var strip_mouse_button: InputEventMouseButton = event as InputEventMouseButton
			if strip_mouse_button.button_index == MOUSE_BUTTON_LEFT and not strip_mouse_button.pressed:
				_finish_strip_scroll()
				return
		elif event is InputEventScreenDrag and str(_active_strip_scroll.get("pointer_kind", "")) == "touch":
			var strip_touch_drag: InputEventScreenDrag = event as InputEventScreenDrag
			if int(_active_strip_scroll.get("pointer_index", -1)) == strip_touch_drag.index:
				_update_strip_scroll(strip_touch_drag.position)
				return
		elif event is InputEventScreenTouch and str(_active_strip_scroll.get("pointer_kind", "")) == "touch":
			var strip_touch_event: InputEventScreenTouch = event as InputEventScreenTouch
			if int(_active_strip_scroll.get("pointer_index", -1)) == strip_touch_event.index and not strip_touch_event.pressed:
				_finish_strip_scroll()
				return
	if _active_drag.is_empty():
		return
	if event is InputEventMouseMotion and str(_active_drag.get("pointer_kind", "")) == "mouse":
		_update_drag((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and str(_active_drag.get("pointer_kind", "")) == "mouse":
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			_finish_drag(mouse_button.position)
	elif event is InputEventScreenDrag and str(_active_drag.get("pointer_kind", "")) == "touch":
		var touch_drag: InputEventScreenDrag = event as InputEventScreenDrag
		if int(_active_drag.get("pointer_index", -1)) == touch_drag.index:
			_update_drag(touch_drag.position)
	elif event is InputEventScreenTouch and str(_active_drag.get("pointer_kind", "")) == "touch":
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if int(_active_drag.get("pointer_index", -1)) == touch_event.index and not touch_event.pressed:
			_finish_drag(touch_event.position)


func _on_card_drag_handle_input(
	event: InputEvent,
	card,
	card_kind: String,
	identifier: String
) -> void:
	if _is_animating_drag or not _active_drag.is_empty() or not _active_strip_scroll.is_empty():
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_begin_drag(card, card_kind, identifier, card.get_drag_handle_global_rect().get_center(), "mouse", -1)
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_begin_drag(card, card_kind, identifier, card.get_drag_handle_global_rect().get_center(), "touch", touch_event.index)


func _begin_drag(
	card,
	card_kind: String,
	identifier: String,
	global_position: Vector2,
	pointer_kind: String,
	pointer_index: int
) -> void:
	if card == null or card.get_player_id().strip_edges() == "":
		return
	_finish_strip_scroll()
	var source_rect: Rect2 = card.get_global_rect()
	var ghost = _build_overlay_copy(card, source_rect)
	card.set_dragging_visual(true)
	_active_drag = {
		"source_kind": card_kind,
		"source_id": identifier,
		"source_player_id": card.get_player_id(),
		"source_rect": source_rect,
		"source_card": card,
		"ghost": ghost,
		"drag_offset": global_position - source_rect.position,
		"pointer_kind": pointer_kind,
		"pointer_index": pointer_index,
	}
	_update_drag(global_position)


func _on_strip_gui_input(
	event: InputEvent,
	_strip_kind: String,
	scroll_container: ScrollContainer
) -> void:
	if _is_animating_drag or not _active_drag.is_empty():
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_begin_strip_scroll(
					scroll_container,
					_scroll_container_local_to_global(scroll_container, mouse_event.position),
					"mouse",
					-1
				)
			else:
				_finish_strip_scroll()
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_begin_strip_scroll(
				scroll_container,
				_scroll_container_local_to_global(scroll_container, touch_event.position),
				"touch",
				touch_event.index
			)
		else:
			_finish_strip_scroll()


func _begin_strip_scroll(
	scroll_container: ScrollContainer,
	global_position: Vector2,
	pointer_kind: String,
	pointer_index: int
) -> void:
	var max_scroll: float = _get_strip_max_scroll(scroll_container)
	if scroll_container == null or max_scroll <= 0.5:
		_finish_strip_scroll()
		return
	_active_strip_scroll = {
		"scroll_container": scroll_container,
		"start_position": global_position,
		"start_scroll": _get_strip_scroll_value(scroll_container),
		"max_scroll": max_scroll,
		"pointer_kind": pointer_kind,
		"pointer_index": pointer_index,
	}


func _update_strip_scroll(global_position: Vector2) -> void:
	var scroll_container: ScrollContainer = _active_strip_scroll.get("scroll_container", null) as ScrollContainer
	if scroll_container == null:
		return
	var start_position: Vector2 = _active_strip_scroll.get("start_position", Vector2.ZERO)
	var start_scroll: float = float(_active_strip_scroll.get("start_scroll", 0.0))
	var max_scroll: float = float(_active_strip_scroll.get("max_scroll", 0.0))
	var next_scroll: float = clampf(start_scroll + (start_position.x - global_position.x), 0.0, max_scroll)
	_set_strip_scroll(scroll_container, next_scroll)


func _finish_strip_scroll() -> void:
	_active_strip_scroll.clear()


func _update_drag(global_position: Vector2) -> void:
	var ghost = _active_drag.get("ghost", null)
	if ghost == null:
		return
	var drag_offset: Vector2 = _active_drag.get("drag_offset", Vector2.ZERO)
	ghost.position = global_position - drag_offset
	var target: Dictionary = _resolve_drop_target(
		str(_active_drag.get("source_kind", "")),
		str(_active_drag.get("source_id", "")),
		global_position
	)
	_set_hover_card(target.get("card", null))


func _finish_drag(global_position: Vector2) -> void:
	var source_kind: String = str(_active_drag.get("source_kind", ""))
	var source_id: String = str(_active_drag.get("source_id", ""))
	var target: Dictionary = _resolve_drop_target(source_kind, source_id, global_position)
	if target.is_empty():
		_cancel_drag_animation()
		return
	_commit_swap(target)


func _commit_swap(target: Dictionary) -> void:
	_is_animating_drag = true
	_set_hover_card(null)
	var source_kind: String = str(_active_drag.get("source_kind", ""))
	var source_id: String = str(_active_drag.get("source_id", ""))
	var source_player_id: String = str(_active_drag.get("source_player_id", ""))
	var drag_ghost = _active_drag.get("ghost", null)
	var target_card = target.get("card", null)
	if drag_ghost == null or target_card == null:
		_cancel_drag_animation()
		return
	var target_rect: Rect2 = target_card.get_global_rect()
	var target_player_id: String = target_card.get_player_id()
	var target_ghost = _build_overlay_copy(target_card, target_rect)
	var swap_success: bool = false
	if source_kind == "lineup":
		swap_success = TeamRoster.swap_lineup_slot_with_bench(source_id, str(target.get("id", "")))
	else:
		swap_success = TeamRoster.swap_lineup_slot_with_bench(str(target.get("id", "")), source_id)
	if not swap_success:
		if is_instance_valid(target_ghost):
			target_ghost.queue_free()
		_is_animating_drag = false
		_cancel_drag_animation()
		return
	var animation_data: Dictionary = {
		"source_kind": source_kind,
		"source_id": source_id,
		"source_player_id": source_player_id,
		"target_id": str(target.get("id", "")),
		"target_player_id": target_player_id,
		"drag_ghost": drag_ghost,
		"target_ghost": target_ghost,
	}
	get_tree().process_frame.connect(_continue_swap_animation.bind(animation_data), CONNECT_ONE_SHOT)


func _continue_swap_animation(animation_data: Dictionary) -> void:
	var drag_ghost = animation_data.get("drag_ghost", null)
	var target_ghost = animation_data.get("target_ghost", null)
	var source_final_card = _resolve_source_final_card(animation_data)
	var target_final_card = _resolve_target_final_card(animation_data)
	if drag_ghost == null or target_ghost == null or source_final_card == null or target_final_card == null:
		_complete_drag_cleanup(drag_ghost, target_ghost)
		return
	var source_final_rect: Rect2 = source_final_card.get_global_rect()
	var target_final_rect: Rect2 = target_final_card.get_global_rect()
	source_final_card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	target_final_card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(drag_ghost, "position", source_final_rect.position, SWAP_ANIMATION_DURATION)
	tween.tween_property(drag_ghost, "size", source_final_rect.size, SWAP_ANIMATION_DURATION)
	tween.tween_property(target_ghost, "position", target_final_rect.position, SWAP_ANIMATION_DURATION)
	tween.tween_property(target_ghost, "size", target_final_rect.size, SWAP_ANIMATION_DURATION)
	tween.tween_property(source_final_card, "modulate:a", 1.0, SWAP_ANIMATION_DURATION * 0.8)
	tween.tween_property(target_final_card, "modulate:a", 1.0, SWAP_ANIMATION_DURATION * 0.8)
	tween.finished.connect(
		_complete_swap_animation.bind(drag_ghost, target_ghost, source_final_card, target_final_card),
		CONNECT_ONE_SHOT
	)


func _cancel_drag_animation() -> void:
	_is_animating_drag = true
	_set_hover_card(null)
	var drag_ghost = _active_drag.get("ghost", null)
	var source_card = _active_drag.get("source_card", null)
	var source_rect: Rect2 = _active_drag.get("source_rect", Rect2())
	if drag_ghost == null:
		_complete_drag_cleanup(null, null)
		return
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(drag_ghost, "position", source_rect.position, CANCEL_ANIMATION_DURATION)
	tween.tween_property(drag_ghost, "size", source_rect.size, CANCEL_ANIMATION_DURATION)
	tween.finished.connect(_complete_cancel_animation.bind(source_card, drag_ghost), CONNECT_ONE_SHOT)


func _complete_cancel_animation(source_card, drag_ghost) -> void:
	if source_card != null and is_instance_valid(source_card):
		source_card.set_dragging_visual(false)
	_complete_drag_cleanup(drag_ghost, null)


func _complete_swap_animation(
	drag_ghost,
	target_ghost,
	source_final_card,
	target_final_card
) -> void:
	if source_final_card != null and is_instance_valid(source_final_card):
		source_final_card.modulate = Color.WHITE
	if target_final_card != null and is_instance_valid(target_final_card):
		target_final_card.modulate = Color.WHITE
	_complete_drag_cleanup(drag_ghost, target_ghost)


func _complete_drag_cleanup(drag_ghost, target_ghost) -> void:
	if drag_ghost != null and is_instance_valid(drag_ghost):
		drag_ghost.queue_free()
	if target_ghost != null and is_instance_valid(target_ghost):
		target_ghost.queue_free()
	var source_card = _active_drag.get("source_card", null)
	if source_card != null and is_instance_valid(source_card):
		source_card.set_dragging_visual(false)
	_active_drag.clear()
	_is_animating_drag = false


func _resolve_source_final_card(animation_data: Dictionary):
	if str(animation_data.get("source_kind", "")) == "lineup":
		return _bench_cards_by_player_id.get(str(animation_data.get("source_player_id", "")), null)
	return _lineup_cards_by_slot.get(str(animation_data.get("target_id", "")), null)


func _resolve_target_final_card(animation_data: Dictionary):
	if str(animation_data.get("source_kind", "")) == "lineup":
		return _lineup_cards_by_slot.get(str(animation_data.get("source_id", "")), null)
	return _bench_cards_by_player_id.get(str(animation_data.get("target_player_id", "")), null)


func _resolve_drop_target(source_kind: String, source_id: String, global_point: Vector2) -> Dictionary:
	var candidates: Dictionary = _bench_cards_by_player_id if source_kind == "lineup" else _lineup_cards_by_slot
	var best_target: Dictionary = {}
	var best_distance: float = INF
	for candidate_id in candidates.keys():
		if str(candidate_id) == source_id:
			continue
		var card = candidates.get(candidate_id, null)
		if card == null or not card.visible:
			continue
		var card_rect: Rect2 = card.get_global_rect()
		if not card_rect.grow(DRAG_HOVER_PADDING).has_point(global_point):
			continue
		var candidate_distance: float = card_rect.get_center().distance_to(global_point)
		if candidate_distance < best_distance:
			best_distance = candidate_distance
			best_target = {
				"kind": "bench" if source_kind == "lineup" else "lineup",
				"id": str(candidate_id),
				"card": card,
			}
	return best_target


func _set_hover_card(next_card) -> void:
	if _hover_card == next_card:
		return
	if _hover_card != null and is_instance_valid(_hover_card):
		_hover_card.set_highlighted(false)
	_hover_card = next_card
	if _hover_card != null and is_instance_valid(_hover_card):
		_hover_card.set_highlighted(true)


func _get_card(card_kind: String, identifier: String):
	if card_kind == "lineup":
		return _lineup_cards_by_slot.get(identifier, null)
	return _bench_cards_by_player_id.get(identifier, null)


func _build_overlay_copy(card, global_rect: Rect2):
	var copy = card.create_overlay_copy()
	copy.position = global_rect.position
	copy.size = global_rect.size
	copy.custom_minimum_size = global_rect.size
	_overlay_layer.add_child(copy)
	return copy


func _rebuild_lineup_cards() -> void:
	for child in _starters_container.get_children():
		child.queue_free()
	_lineup_cards_by_slot.clear()
	for slot_data in TeamRoster.get_home_lineup_slots():
		var slot_role: String = str(slot_data.get("slot_role", ""))
		var player_data: PlayerData = slot_data.get("player", null) as PlayerData
		if player_data == null:
			continue
		var card = ROSTER_PLAYER_CARD_SCRIPT.new()
		card.focus_mode = Control.FOCUS_NONE
		card.setup_for_lineup(player_data, slot_role)
		card.set_body_scroll_mode_enabled(true)
		card.drag_handle_input.connect(_on_card_drag_handle_input.bind(card, "lineup", slot_role))
		_lineup_cards_by_slot[slot_role] = card
		_starters_container.add_child(card)
	_sync_strip_content_width(_starters_scroll, _starters_container)


func _rebuild_bench_cards() -> void:
	for child in _bench_container.get_children():
		child.queue_free()
	_bench_cards_by_player_id.clear()
	var bench_players: Array[PlayerData] = TeamRoster.get_home_bench_players()
	var has_bench_players: bool = not bench_players.is_empty()
	_bench_empty_label.visible = not has_bench_players
	_bench_scroll.visible = has_bench_players
	if not has_bench_players:
		_sync_strip_content_width(_bench_scroll, _bench_container)
		return
	for player_data in bench_players:
		if player_data == null:
			continue
		var card = ROSTER_PLAYER_CARD_SCRIPT.new()
		card.focus_mode = Control.FOCUS_NONE
		card.setup_for_bench(player_data)
		card.set_body_scroll_mode_enabled(true)
		card.drag_handle_input.connect(_on_card_drag_handle_input.bind(card, "bench", player_data.player_id))
		_bench_cards_by_player_id[player_data.player_id] = card
		_bench_container.add_child(card)
	_sync_strip_content_width(_bench_scroll, _bench_container)
	_update_bench_placeholder_layout()


func _uses_horizontal_scroll(scroll_container: ScrollContainer) -> bool:
	return scroll_container != null \
		and scroll_container.horizontal_scroll_mode != 2 \
		and scroll_container.vertical_scroll_mode == 2


func _cards_use_body_scroll_passthrough() -> bool:
	if _lineup_cards_by_slot.is_empty():
		return false
	var sample_card = _lineup_cards_by_slot.values()[0]
	return sample_card != null and sample_card.uses_body_scroll_passthrough()


func _headers_align_with_title() -> bool:
	if _title_label == null or _starters_header_label == null or _bench_header_label == null:
		return false
	var title_x: float = _title_label.get_global_rect().position.x
	return absf(_starters_header_label.get_global_rect().position.x - title_x) < 0.5 \
		and absf(_bench_header_label.get_global_rect().position.x - title_x) < 0.5


func _viewport_fits_card(scroll_container: ScrollContainer, cards: Array) -> bool:
	if scroll_container == null or cards.is_empty():
		return true
	var sample_card = cards[0]
	if sample_card == null:
		return true
	return scroll_container.get_global_rect().size.y + 0.5 >= sample_card.get_global_rect().size.y


func _get_subtitle_to_starters_gap() -> float:
	if _subtitle_label == null or _starters_header_label == null:
		return 0.0
	return _starters_header_label.get_global_rect().position.y - _subtitle_label.get_global_rect().end.y


func _is_bench_placeholder_centered() -> bool:
	if _bench_empty_label == null:
		return false
	var viewport_rect: Rect2 = get_viewport_rect()
	var label_rect: Rect2 = _bench_empty_label.get_global_rect()
	return _bench_empty_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER \
		and absf(label_rect.position.x - viewport_rect.position.x) < 0.5 \
		and absf(label_rect.size.x - viewport_rect.size.x) < 0.5 \
		and absf(label_rect.get_center().x - viewport_rect.get_center().x) < 0.5


func _update_bench_placeholder_layout() -> void:
	if _bench_empty_label == null or _bench_content == null or _overlay_layer == null:
		return
	var viewport_rect: Rect2 = get_viewport_rect()
	var bench_rect: Rect2 = _bench_content.get_global_rect()
	var overlay_rect: Rect2 = _overlay_layer.get_global_rect()
	_bench_empty_label.position = Vector2(
		viewport_rect.position.x - overlay_rect.position.x,
		bench_rect.position.y - overlay_rect.position.y
	)
	_bench_empty_label.size = Vector2(viewport_rect.size.x, bench_rect.size.y)
	_bench_empty_label.custom_minimum_size = _bench_empty_label.size


func _sync_strip_content_width(scroll_container: ScrollContainer, container: HBoxContainer) -> void:
	if scroll_container == null or container == null:
		return
	scroll_container.custom_minimum_size.x = PHONE_LAYOUT_WIDTH
	var child_count: int = container.get_child_count()
	var separation: float = float(container.get_theme_constant("separation"))
	var content_width: float = PHONE_LAYOUT_WIDTH
	if child_count > 0:
		content_width = maxf(
			PHONE_LAYOUT_WIDTH,
			child_count * ROSTER_PLAYER_CARD_SCRIPT.get_card_width() + maxf(0.0, child_count - 1.0) * separation
		)
	container.custom_minimum_size.x = content_width
	_set_strip_scroll(scroll_container, minf(_get_strip_scroll_value(scroll_container), _get_strip_max_scroll(scroll_container)))


func _get_strip_max_scroll(scroll_container: ScrollContainer) -> float:
	if scroll_container == null:
		return 0.0
	var content = scroll_container.get_child(0) as Control
	if content == null:
		return 0.0
	var content_width: float = maxf(content.custom_minimum_size.x, maxf(content.size.x, content.get_combined_minimum_size().x))
	return maxf(0.0, content_width - PHONE_LAYOUT_WIDTH)


func _get_strip_scroll_value(scroll_container: ScrollContainer) -> float:
	if scroll_container == null:
		return 0.0
	var content = scroll_container.get_child(0) as Control
	if content == null:
		return 0.0
	return maxf(0.0, -content.position.x)


func _set_strip_scroll(scroll_container: ScrollContainer, scroll_value: float) -> void:
	if scroll_container == null:
		return
	var content = scroll_container.get_child(0) as Control
	if content == null:
		return
	var clamped_scroll: float = clampf(scroll_value, 0.0, _get_strip_max_scroll(scroll_container))
	content.position = Vector2(-clamped_scroll, content.position.y)
	scroll_container.scroll_horizontal = 0


func _get_strip_scroll_container(strip_kind: String) -> ScrollContainer:
	if strip_kind == "starters":
		return _starters_scroll
	if strip_kind == "bench":
		return _bench_scroll
	return null


func _get_strip_content_container(strip_kind: String) -> HBoxContainer:
	if strip_kind == "starters":
		return _starters_container
	if strip_kind == "bench":
		return _bench_container
	return null


func _scroll_container_local_to_global(scroll_container: ScrollContainer, local_position: Vector2) -> Vector2:
	return scroll_container.get_global_rect().position + local_position


func _get_bottom_bar_gap() -> float:
	if _bottom_bar == null:
		return 0.0
	return get_viewport_rect().end.y - _bottom_bar.get_global_rect().end.y


func _get_bottom_bar_side_inset() -> float:
	if _bottom_bar == null:
		return 0.0
	var rect: Rect2 = _bottom_bar.get_global_rect()
	return minf(rect.position.x, get_viewport_rect().size.x - rect.end.x)


func _refresh_coin_badge() -> void:
	if _coins_badge != null:
		_coins_badge.set_coins(TeamRoster.get_coin_balance())


func _debug_reset_drag_state() -> void:
	_finish_strip_scroll()
	_set_hover_card(null)
	var drag_ghost = _active_drag.get("ghost", null)
	if drag_ghost != null and is_instance_valid(drag_ghost):
		drag_ghost.queue_free()
	var source_card = _active_drag.get("source_card", null)
	if source_card != null and is_instance_valid(source_card):
		source_card.set_dragging_visual(false)
	_active_drag.clear()
	_is_animating_drag = false


func _on_coins_changed(_new_value: int) -> void:
	_refresh_coin_badge()


func _on_home_roster_changed() -> void:
	refresh_from_roster()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _on_shop_pressed() -> void:
	get_tree().change_scene_to_file(SHOP_SCENE_PATH)
