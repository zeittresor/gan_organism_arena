extends Node

# No files, images or GPU textures are created until the option is enabled.
# CPU images are kept on each living/embryonic genome, never in the event log.
const SIZE: int = 128
const MAX_FILE_BYTES: int = 1048576
const SOURCES = {
    "ground": "res://textures/terrain/ground.png", "silt": "res://textures/terrain/silt.png",
    "rock": "res://textures/terrain/rock.png", "organic_ground": "res://textures/terrain/organic_ground.png",
    "seabed": "res://textures/terrain/seabed.png", "shore": "res://textures/terrain/shore.png",
    "sand": "res://textures/terrain/sand.png", "grass": "res://textures/terrain/grass.png",
    "skin": "res://textures/organisms/skin.png", "scales": "res://textures/organisms/scales.png",
    "fur": "res://textures/organisms/fur.png", "membrane": "res://textures/organisms/membrane.png",
    "plates": "res://textures/organisms/plates.png", "mottle": "res://textures/organisms/mottle.png",
    "bone": "res://textures/organisms/details/bone.png", "neural": "res://textures/organisms/details/neural.png",
    "eye": "res://textures/organisms/details/eye.png", "fin": "res://textures/organisms/details/fin.png",
    "leaf": "res://textures/organisms/details/leaf.png", "bark": "res://textures/organisms/details/bark.png",
    "wing": "res://textures/organisms/details/wing.png", "feather": "res://textures/organisms/details/feather.png",
    "horn": "res://textures/organisms/details/horn.png", "beak": "res://textures/organisms/details/beak.png",
    "claw": "res://textures/organisms/details/claw.png", "armor": "res://textures/organisms/details/armor.png",
    "reproductive": "res://textures/organisms/details/reproductive.png", "leather": "res://textures/organisms/details/leather.png",
    "adaptive": "res://textures/organisms/details/adaptive.png",
    "tool_wood": "res://textures/materials/wood.png", "tool_stone": "res://textures/materials/stone.png",
    "tool_metal": "res://textures/materials/metal.png", "tool_cloth": "res://textures/materials/cloth.png"
}
const TERRAIN_BY_HABITAT = {5: "silt", 6: "rock", 7: "ground", 8: "organic_ground", 9: "rock"}
const SPECIALIZED_KEYS: Array[String] = ["bone", "neural", "eye", "fin", "leaf", "bark", "wing", "feather", "horn", "beak", "claw", "armor", "reproductive", "leather", "adaptive"]
var enabled: bool = false
var sources: Dictionary = {}
var terrain_textures: Dictionary = {}
var auxiliary_textures: Dictionary = {}
var specialized_atlas: ImageTexture
var warnings: Array[String] = []
var images_built: int = 0
var load_error: String = ""

func _ready() -> void:
    set_enabled(bool(SettingsStore.get_value("textures_enabled", false)))

func set_enabled(value: bool) -> void:
    if not value:
        enabled = false
        load_error = ""
        return
    enabled = true
    if sources.is_empty() or terrain_textures.is_empty(): reload_sources()

func reload_sources() -> void:
    if not enabled: return
    warnings.clear()
    load_error = ""
    sources.clear()
    terrain_textures.clear()
    auxiliary_textures.clear()
    specialized_atlas = null
    for key in SOURCES:
        sources[key] = _load_png(SOURCES[key])
    for key in ["ground", "silt", "rock", "organic_ground", "seabed", "shore", "sand", "grass"]:
        var image: Image = sources[key].duplicate()
        image.generate_mipmaps()
        var texture := ImageTexture.create_from_image(image)
        if texture == null:
            load_error = "terrain texture creation failed: " + key
        else:
            terrain_textures[key] = texture
    if terrain_textures.size() < 8:
        load_error = "not all terrain textures could be created"

func terrain_texture_for(habitat_level: int) -> ImageTexture:
    if not enabled: return null
    if terrain_textures.is_empty(): reload_sources()
    var texture = terrain_textures.get(TERRAIN_BY_HABITAT.get(habitat_level, "ground"))
    return texture if texture is ImageTexture else null

func terrain_texture_named(texture_name: String) -> ImageTexture:
    if not enabled: return null
    if terrain_textures.is_empty(): reload_sources()
    var texture = terrain_textures.get(texture_name)
    return texture if texture is ImageTexture else null

func texture_named(texture_name: String) -> ImageTexture:
    if not enabled: return null
    if sources.is_empty(): reload_sources()
    if not sources.has(texture_name): return null
    if not auxiliary_textures.has(texture_name):
        var image: Image = sources[texture_name].duplicate()
        image.generate_mipmaps()
        var texture := ImageTexture.create_from_image(image)
        if texture == null: return null
        auxiliary_textures[texture_name] = texture
    return auxiliary_textures[texture_name]

func specialized_body_texture() -> ImageTexture:
    if not enabled: return null
    if sources.is_empty(): reload_sources()
    if specialized_atlas == null:
        var atlas: Image = Image.create_empty(SIZE * 4, SIZE * 4, false, Image.FORMAT_RGB8)
        atlas.fill(Color.WHITE)
        for index in range(SPECIALIZED_KEYS.size()):
            var slot: int = index + 1
            var destination = Vector2i((slot % 4) * SIZE, floori(float(slot) / 4.0) * SIZE)
            atlas.blit_rect(sources[SPECIALIZED_KEYS[index]], Rect2i(0, 0, SIZE, SIZE), destination)
        specialized_atlas = ImageTexture.create_from_image(atlas)
        if specialized_atlas == null:
            load_error = "specialized texture atlas creation failed"
    return specialized_atlas

func _load_png(path: String) -> Image:
    var result = Image.new()
    var file = FileAccess.open(path, FileAccess.READ)
    var valid: bool = file != null
    if file:
        valid = file.get_length() <= MAX_FILE_BYTES
        file.close()
    if valid:
        valid = result.load(ProjectSettings.globalize_path(path)) == OK and not result.is_empty()
    if not valid:
        warnings.append(path)
        AppLog.info("Optional texture unavailable; using neutral material: " + path)
        result = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
        result.fill(Color.WHITE)
    else:
        result.clear_mipmaps()
        result.convert(Image.FORMAT_RGB8)
        result.resize(SIZE, SIZE, Image.INTERPOLATE_BILINEAR)
    return result

func resolve_image(pattern) -> Image:
    if not enabled: return null
    if pattern == null:
        if sources.is_empty(): reload_sources()
        return sources.get("skin", _neutral_image()).duplicate()
    if pattern.image == null:
        if sources.is_empty(): reload_sources()
        pattern.image = mix_weighted(pattern.source_weights)
        images_built += 1
    return pattern.image

func body_texture(pattern) -> ImageTexture:
    if not enabled: return null
    if pattern == null:
        var neutral: Image = _neutral_image()
        neutral.generate_mipmaps()
        return ImageTexture.create_from_image(neutral)
    if pattern.texture == null:
        var pixels: Image = resolve_image(pattern).duplicate()
        pixels.generate_mipmaps()
        pattern.texture = ImageTexture.create_from_image(pixels)
    return pattern.texture

func mix_weighted(weights: Dictionary) -> Image:
    if weights == null:
        return sources.get("skin", _neutral_image()).duplicate()
    var normalized: Dictionary = {}
    var total: float = 0.0
    for key in weights:
        if sources.has(key) and float(weights[key]) > 0.0:
            normalized[key] = float(weights[key])
            total += float(weights[key])
    if total <= 0.0: return sources["skin"].duplicate()
    var bytes: Dictionary = {}
    for key in normalized: bytes[key] = sources[key].get_data()
    var result = PackedByteArray()
    result.resize(SIZE * SIZE * 3)
    for i in range(result.size()):
        var value: float = 0.0
        for key in normalized:
            value += float(bytes[key][i]) * float(normalized[key]) / total
        result[i] = int(round(value))
    return Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGB8, result)

func _neutral_image() -> Image:
    var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
    image.fill(Color.WHITE)
    return image

static func mix_images(first: Image, second: Image, second_share: float) -> Image:
    # The actual parent maps, including earlier generations, are the inputs.
    # Operate on packed CPU bytes once, never read back a GPU texture.
    var a: PackedByteArray = first.get_data()
    var b: PackedByteArray = second.get_data()
    var result = PackedByteArray()
    result.resize(SIZE * SIZE * 3)
    var weight: float = clampf(second_share, 0.0, 1.0)
    for i in range(result.size()):
        result[i] = int(round(lerpf(float(a[i]), float(b[i]), weight)))
    return Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGB8, result)
