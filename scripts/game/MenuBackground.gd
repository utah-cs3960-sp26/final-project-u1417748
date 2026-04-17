class_name MenuBackground
extends RefCounted

const BACKGROUND_PATHS: Array[String] = [
	"res://assets/Court/backgrounds/001.png",
	"res://assets/Court/backgrounds/002.png",
	"res://assets/Court/backgrounds/003.png",
	"res://assets/Court/backgrounds/004.png",
]

static var _cached_source_path: String = ""
static var _cached_texture: Texture2D


static func apply_to(texture_rect: TextureRect) -> void:
	if texture_rect == null:
		return
	var background_texture: Texture2D = get_texture()
	if background_texture != null:
		texture_rect.texture = background_texture


static func get_texture() -> Texture2D:
	if _cached_texture != null:
		return _cached_texture
	_cached_source_path = _choose_background_path()
	_cached_texture = _load_rotated_texture(_cached_source_path)
	return _cached_texture


static func get_source_path() -> String:
	return _cached_source_path


static func reset_for_tests() -> void:
	_cached_source_path = ""
	_cached_texture = null


static func _choose_background_path() -> String:
	if BACKGROUND_PATHS.is_empty():
		return ""
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return BACKGROUND_PATHS[rng.randi_range(0, BACKGROUND_PATHS.size() - 1)]


static func _load_rotated_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var source: Texture2D = load(path) as Texture2D
	if source == null:
		return null
	var source_image: Image = source.get_image()
	if source_image == null:
		return null
	var rotated: Image = Image.new()
	rotated.copy_from(source_image)
	rotated.rotate_90(CLOCKWISE)
	return ImageTexture.create_from_image(rotated)
