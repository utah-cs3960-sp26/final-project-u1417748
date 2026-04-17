class_name TeamScreen
extends Control

const CHARACTER_TEXTURE: Texture2D = preload("res://assets/Character/Character1_NEW.png")
const MENU_BACKGROUND_SCRIPT: GDScript = preload("res://scripts/game/MenuBackground.gd")
const FRAME_SIZE: Vector2i = Vector2i(64, 64)
const IDLE_ROW_INDEX: int = 1
const SPRITE_DISPLAY_SIZE: Vector2 = Vector2(160, 160)
const CARD_WIDTH: float = 192.0

@onready var _court_background: TextureRect = $CourtBackground
@onready var _cards_container: HBoxContainer = %CardsContainer
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	MENU_BACKGROUND_SCRIPT.apply_to(_court_background)
	_back_button.pressed.connect(_on_back_pressed)
	_populate_cards()


func _populate_cards() -> void:
	for child in _cards_container.get_children():
		child.queue_free()
	var team: TeamData = TeamRoster.get_home_team()
	if team == null:
		return
	for player_data in team.players:
		_cards_container.add_child(_build_card(player_data))


func _build_card(player_data: PlayerData) -> Control:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0.0)

	var inner: MarginContainer = MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 16)
	inner.add_theme_constant_override("margin_right", 16)
	inner.add_theme_constant_override("margin_top", 20)
	inner.add_theme_constant_override("margin_bottom", 20)
	card.add_child(inner)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	inner.add_child(vbox)

	var sprite_wrapper: CenterContainer = CenterContainer.new()
	sprite_wrapper.custom_minimum_size = SPRITE_DISPLAY_SIZE
	vbox.add_child(sprite_wrapper)

	var sprite: TextureRect = TextureRect.new()
	sprite.texture = CHARACTER_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.custom_minimum_size = SPRITE_DISPLAY_SIZE
	var region: AtlasTexture = AtlasTexture.new()
	region.atlas = CHARACTER_TEXTURE
	region.region = Rect2(0, IDLE_ROW_INDEX * FRAME_SIZE.y, FRAME_SIZE.x, FRAME_SIZE.y)
	sprite.texture = region
	sprite_wrapper.add_child(sprite)

	var name_label: Label = Label.new()
	name_label.text = player_data.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 30)
	vbox.add_child(name_label)

	var role_label: Label = Label.new()
	role_label.text = player_data.role
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.add_theme_font_size_override("font_size", 22)
	role_label.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0, 0.85))
	vbox.add_child(role_label)

	var overall_label: Label = Label.new()
	overall_label.text = "OVR %d" % TeamRoster.get_overall(player_data)
	overall_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overall_label.add_theme_font_size_override("font_size", 32)
	overall_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	vbox.add_child(overall_label)

	return card


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
