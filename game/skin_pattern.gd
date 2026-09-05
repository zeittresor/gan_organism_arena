extends RefCounted

# A bounded appearance record, not a reference to the whole family tree.
# Images become immutable snapshots; descendants never modify parent pixels.
const TEMPLATE_KEYS: Array[String] = ["skin", "scales", "fur", "membrane", "plates", "mottle"]
var source_weights: Dictionary = {"skin": 0.5, "scales": 0.5}
var inherited: bool = false
var parent_count: int = 0
var image: Image
var texture: ImageTexture

func configure_founder(p_seed: int, scale_value: float, fur_value: float, membrane_value: float, armor_value: float, pattern_value: float) -> void:
    var index_a: int = posmod(p_seed, TEMPLATE_KEYS.size())
    var index_b: int = posmod(floori(float(p_seed) / float(TEMPLATE_KEYS.size())) + 1, TEMPLATE_KEYS.size())
    if index_b == index_a: index_b = (index_a + 1) % TEMPLATE_KEYS.size()
    var traits: Array[float] = [1.0 - scale_value, scale_value, fur_value, membrane_value, armor_value, pattern_value]
    var trait_index: int = 0
    var strongest: float = -1.0
    for i in range(traits.size()):
        if traits[i] > strongest:
            strongest = traits[i]
            trait_index = i
    index_a = trait_index
    if index_b == index_a: index_b = (index_a + 1 + posmod(p_seed, TEMPLATE_KEYS.size() - 1)) % TEMPLATE_KEYS.size()
    var second_share: float = clampf(0.20 + pattern_value * 0.45, 0.20, 0.65)
    source_weights = {TEMPLATE_KEYS[index_a]: 1.0 - second_share, TEMPLATE_KEYS[index_b]: second_share}

func offspring(other = null):
    var child = get_script().new()
    child.inherited = true
    child.parent_count = 1 if other == null else 2
    child.source_weights = source_weights.duplicate(true) if other == null else _combine_weights(source_weights, other.source_weights)
    if TextureAssets.enabled:
        var first: Image = TextureAssets.resolve_image(self)
        if other == null:
            child.image = first.duplicate()
        else:
            child.image = TextureAssets.mix_images(first, TextureAssets.resolve_image(other), 0.5)
    return child

static func _combine_weights(first: Dictionary, second: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for key in first: result[key] = float(result.get(key, 0.0)) + float(first[key]) * 0.5
    for key in second: result[key] = float(result.get(key, 0.0)) + float(second[key]) * 0.5
    return result

func summary() -> Dictionary:
    var weights: Array = [0.5, 0.5] if parent_count == 2 else ([1.0] if parent_count == 1 else [])
    return {"schema": "arena.skin/2", "template_weights": source_weights.duplicate(true), "inherited": inherited, "has_pixel_snapshot": image != null, "size": 128, "parent_weights": weights, "color": "pattern modulates inherited tissue pigment; not a DNA locus"}
