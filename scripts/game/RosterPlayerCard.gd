class_name RosterPlayerCard
extends PanelContainer

signal action_pressed(player_id: String)
signal drag_handle_input(event: InputEvent)

const CHARACTER_TEXTURE: Texture2D = preload("res://assets/Character/Character1_NEW.png")
const FRAME_SIZE: Vector2i = Vector2i(64, 64)
const IDLE_ROW_INDEX: int = 1
const CARD_WIDTH: float = 420.0
const SPRITE_DISPLAY_SIZE: Vector2 = Vector2(320.0, 320.0)
const DRAG_HANDLE_HEIGHT: float = 60.0

var _card_state: Dictionary = {}
var _is_highlighted: bool = false
var _is_dragging_visual: bool = false

var _header_label: Label
var _drag_handle_button: Button
var _sprite: TextureRect
var _name_label: Label
var _role_label: Label
var _slot_label: Label
var _overall_label: Label
var _cost_label: Label
var _status_label: Label
var _action_button: Button


func _ready() -> void:
	_ensure_ui()
	_apply_state()


func setup_for_lineup(player_data: PlayerData, slot_role: String) -> void:
	_card_state = {
		"mode": "lineup",
		"player_data": player_data,
		"slot_role": slot_role,
		"button_text": "",
		"button_disabled": true,
		"status_text": "",
	}
	_ensure_ui()
	_apply_state()


func setup_for_bench(player_data: PlayerData) -> void:
	_card_state = {
		"mode": "bench",
		"player_data": player_data,
		"slot_role": "",
		"button_text": "",
		"button_disabled": true,
		"status_text": "",
	}
	_ensure_ui()
	_apply_state()


func setup_for_shop(
	player_data: PlayerData,
	button_text: String,
	button_disabled: bool,
	status_text: String = ""
) -> void:
	_card_state = {
		"mode": "shop",
		"player_data": player_data,
		"slot_role": "",
		"button_text": button_text,
		"button_disabled": button_disabled,
		"status_text": status_text,
	}
	_ensure_ui()
	_apply_state()


func set_highlighted(value: bool) -> void:
	_is_highlighted = value
	_refresh_panel_style()


func set_dragging_visual(value: bool) -> void:
	_is_dragging_visual = value
	modulate = Color(1.0, 1.0, 1.0, 0.38 if value else 1.0)


func create_overlay_copy():
	var copy = get_script().new()
	copy._card_state = _card_state.duplicate()
	copy._is_highlighted = false
	copy._is_dragging_visual = false
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.custom_minimum_size = size if size != Vector2.ZERO else Vector2(CARD_WIDTH, 0.0)
	copy.size = custom_minimum_size if custom_minimum_size != Vector2.ZERO else size
	return copy


func get_player_id() -> String:
	var player_data: PlayerData = _card_state.get("player_data", null) as PlayerData
	return player_data.player_id if player_data != null else ""


func get_slot_role() -> String:
	return str(_card_state.get("slot_role", ""))


func get_display_mode() -> String:
	return str(_card_state.get("mode", ""))


func get_card_snapshot() -> Dictionary:
	return {
		"mode": get_display_mode(),
		"player_id": get_player_id(),
		"slot_role": get_slot_role(),
		"has_drag_handle": has_drag_handle(),
		"button_text": str(_card_state.get("button_text", "")),
		"button_disabled": bool(_card_state.get("button_disabled", true)),
		"status_text": str(_card_state.get("status_text", "")),
	}


static func get_card_width() -> float:
	return CARD_WIDTH


static func get_sprite_display_size() -> Vector2:
	return SPRITE_DISPLAY_SIZE


func has_drag_handle() -> bool:
	return _drag_handle_button != null and _drag_handle_button.visible


func get_drag_handle_global_rect() -> Rect2:
	return _drag_handle_button.get_global_rect() if has_drag_handle() else Rect2()


func set_body_scroll_mode_enabled(value: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP


func uses_body_scroll_passthrough() -> bool:
	return mouse_filter == Control.MOUSE_FILTER_IGNORE


func debug_emit_drag_handle_input(event: InputEvent) -> void:
	if _drag_handle_button == null or not _drag_handle_button.visible:
		return
	_on_drag_handle_gui_input(event)


func _ensure_ui() -> void:
	if _action_button != null:
		return
	custom_minimum_size = Vector2(CARD_WIDTH, 0.0)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	_header_label = Label.new()
	_header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 20)
	_header_label.add_theme_color_override("font_color", Color(0.64, 0.84, 1.0))
	vbox.add_child(_header_label)

	var sprite_wrapper: CenterContainer = CenterContainer.new()
	sprite_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite_wrapper.custom_minimum_size = SPRITE_DISPLAY_SIZE
	vbox.add_child(sprite_wrapper)

	_sprite = TextureRect.new()
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.custom_minimum_size = SPRITE_DISPLAY_SIZE
	sprite_wrapper.add_child(_sprite)

	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 34)
	vbox.add_child(_name_label)

	_role_label = Label.new()
	_role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_role_label.add_theme_font_size_override("font_size", 24)
	_role_label.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0, 0.9))
	vbox.add_child(_role_label)

	_slot_label = Label.new()
	_slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_label.add_theme_font_size_override("font_size", 20)
	_slot_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.58, 0.95))
	vbox.add_child(_slot_label)

	_overall_label = Label.new()
	_overall_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overall_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overall_label.add_theme_font_size_override("font_size", 38)
	_overall_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	vbox.add_child(_overall_label)

	_drag_handle_button = Button.new()
	_drag_handle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_drag_handle_button.custom_minimum_size = Vector2(0.0, DRAG_HANDLE_HEIGHT)
	_drag_handle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drag_handle_button.text = "DRAG"
	_drag_handle_button.focus_mode = Control.FOCUS_NONE
	_drag_handle_button.add_theme_font_size_override("font_size", 20)
	_drag_handle_button.gui_input.connect(_on_drag_handle_gui_input)
	vbox.add_child(_drag_handle_button)

	_cost_label = Label.new()
	_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.add_theme_font_size_override("font_size", 26)
	_cost_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.34))
	vbox.add_child(_cost_label)

	_status_label = Label.new()
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 0.92))
	vbox.add_child(_status_label)

	_action_button = Button.new()
	_action_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_action_button.custom_minimum_size = Vector2(0.0, 74.0)
	_action_button.add_theme_font_size_override("font_size", 28)
	_action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_button.pressed.connect(_on_action_button_pressed)
	vbox.add_child(_action_button)

	_refresh_panel_style()


func _apply_state() -> void:
	if _action_button == null:
		return
	var player_data: PlayerData = _card_state.get("player_data", null) as PlayerData
	var mode: String = get_display_mode()
	if player_data == null:
		_header_label.text = "UNASSIGNED"
		_name_label.text = "Open Slot"
		_role_label.text = ""
		_slot_label.text = ""
		_overall_label.text = ""
		_cost_label.visible = false
		_status_label.visible = false
		_action_button.visible = false
		return

	var region: AtlasTexture = AtlasTexture.new()
	region.atlas = CHARACTER_TEXTURE
	region.region = Rect2(0, IDLE_ROW_INDEX * FRAME_SIZE.y, FRAME_SIZE.x, FRAME_SIZE.y)
	_sprite.texture = region

	_name_label.text = player_data.display_name
	_overall_label.text = "OVR %d" % TeamRoster.get_overall(player_data)
	_action_button.visible = false
	_cost_label.visible = false
	_status_label.visible = false
	_slot_label.visible = true
	_drag_handle_button.visible = false

	match mode:
		"lineup":
			_header_label.text = "STARTER"
			_role_label.text = "Natural %s" % player_data.role
			_slot_label.text = "Slot %s" % get_slot_role()
			_drag_handle_button.visible = true
		"bench":
			_header_label.text = "BENCH"
			_role_label.text = "Role %s" % player_data.role
			_slot_label.text = "Swap into any slot"
			_drag_handle_button.visible = true
		"shop":
			_header_label.text = "FEATURED PLAYER"
			_role_label.text = "Role %s" % player_data.role
			_slot_label.visible = false
			_cost_label.visible = true
			_status_label.visible = str(_card_state.get("status_text", "")).strip_edges() != ""
			_cost_label.text = "%d COINS" % player_data.purchase_cost
			_status_label.text = str(_card_state.get("status_text", ""))
			_action_button.visible = true
			_action_button.text = str(_card_state.get("button_text", "Buy"))
			_action_button.disabled = bool(_card_state.get("button_disabled", false))
		_:
			_header_label.text = "PLAYER"
			_role_label.text = "Role %s" % player_data.role
			_slot_label.visible = false

	_refresh_panel_style()


func _refresh_panel_style() -> void:
	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.12, 0.2, 0.92)
	style_box.border_width_left = 4
	style_box.border_width_top = 4
	style_box.border_width_right = 4
	style_box.border_width_bottom = 4
	style_box.corner_radius_top_left = 28
	style_box.corner_radius_top_right = 28
	style_box.corner_radius_bottom_right = 28
	style_box.corner_radius_bottom_left = 28
	style_box.border_color = Color(1.0, 0.82, 0.34, 0.95) if _is_highlighted else Color(0.33, 0.44, 0.62, 0.9)
	add_theme_stylebox_override("panel", style_box)


func _on_action_button_pressed() -> void:
	if get_player_id().strip_edges() == "":
		return
	action_pressed.emit(get_player_id())


func _on_drag_handle_gui_input(event: InputEvent) -> void:
	drag_handle_input.emit(event)
