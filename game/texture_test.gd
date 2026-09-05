extends Node

const Genome = preload("res://game/genome.gd")
const Pattern = preload("res://game/skin_pattern.gd")
var checks: int = 0
var failed: int = 0

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failed += 1
        printerr("SELFTEST ERROR: textures: ", label)

func _solid(color: Color) -> Image:
    var result = Image.create_empty(128, 128, false, Image.FORMAT_RGB8)
    result.fill(color)
    return result

func _near(pixel: Color, r: float, g: float, b: float) -> bool:
    return absf(pixel.r - r) <= 0.008 and absf(pixel.g - g) <= 0.008 and absf(pixel.b - b) <= 0.008

func run_all() -> bool:
    var previous_enabled: bool = TextureAssets.enabled
    var previous_sources: Dictionary = TextureAssets.sources.duplicate()
    var previous_terrain: Dictionary = TextureAssets.terrain_textures.duplicate()
    var previous_auxiliary: Dictionary = TextureAssets.auxiliary_textures.duplicate()
    var previous_atlas = TextureAssets.specialized_atlas
    var previous_built: int = TextureAssets.images_built
    TextureAssets.enabled = true
    TextureAssets.reload_sources()
    check(TextureAssets.sources.size() == 33 and TextureAssets.warnings.is_empty(), "all terrain, tissue and material PNG sources load")
    var specialized = TextureAssets.specialized_body_texture()
    check(specialized != null and specialized.get_width() == 512 and specialized.get_height() == 512, "fifteen tissue fallbacks occupy a bounded 4x4 atlas")
    check(TextureAssets.terrain_texture_named("seabed") != null and TextureAssets.terrain_texture_named("shore") != null and TextureAssets.terrain_texture_named("sand") != null and TextureAssets.terrain_texture_named("grass") != null and TextureAssets.texture_named("tool_wood") != null, "terrain transitions and tool material are addressable")
    TextureAssets.enabled = false
    TextureAssets.sources.clear()
    var a = Genome.new()
    var b = Genome.new()
    a.skin_pattern.source_weights = {"skin": 1.0}
    b.skin_pattern.source_weights = {"scales": 1.0}
    var rng = RandomNumberGenerator.new()
    rng.seed = 251289
    var without = a.crossover(b, rng, 0.12, 0.1)
    check(without.skin_pattern.image == null and without.skin_pattern.texture == null, "disabled option creates no child image or GPU texture")
    check(TextureAssets.resolve_image(a.skin_pattern) == null and TextureAssets.body_texture(b.skin_pattern) == null, "disabled loader performs no image work")
    check(TextureAssets.sources.is_empty() and TextureAssets.images_built == previous_built, "disabled option never loads files or builds maps")
    check(is_equal_approx(float(without.skin_pattern.source_weights["skin"]), 0.5) and is_equal_approx(float(without.skin_pattern.source_weights["scales"]), 0.5), "disabled offspring retains lightweight mixed appearance recipe")
    TextureAssets.sources = {"skin": _solid(Color(1.0, 0.0, 0.0)), "scales": _solid(Color(0.0, 0.0, 1.0))}
    TextureAssets.enabled = true
    rng.seed = 251289
    var child = a.crossover(b, rng, 0.12, 0.1)
    check(child.alleles == without.alleles and child.seed == without.seed and child.mutation_log == without.mutation_log, "texture option cannot consume biological RNG or alter heredity")
    check(child.skin_pattern != a.skin_pattern and child.skin_pattern != b.skin_pattern, "child owns its appearance record")
    check(child.skin_pattern.image != a.skin_pattern.image and child.skin_pattern.image != b.skin_pattern.image, "child owns a new bitmap")
    check(_near(child.skin_pattern.image.get_pixel(13, 59), 0.5, 0.0, 0.5), "sexual child blends actual parent pixels 50/50")
    check(_near(a.skin_pattern.image.get_pixel(13, 59), 1.0, 0.0, 0.0) and _near(b.skin_pattern.image.get_pixel(13, 59), 0.0, 0.0, 1.0), "parent maps remain unchanged")
    check(child.skin_pattern.image.get_width() == 128 and child.skin_pattern.image.get_height() == 128 and not child.skin_pattern.image.has_mipmaps(), "CPU maps have bounded size and no GPU mip data")
    # Replacing templates must not rewrite existing coats or ancestral pixels.
    TextureAssets.sources = {"skin": _solid(Color.WHITE), "scales": _solid(Color.WHITE)}
    var grandchild = child.crossover(a, rng, 0.0, 0.0)
    check(_near(grandchild.skin_pattern.image.get_pixel(13, 59), 0.75, 0.0, 0.25), "grandchild carries 75/25 ancestral pixels after template replacement")
    var clone = child.mutated(rng, 0.0, 0.0)
    check(clone.skin_pattern.image != child.skin_pattern.image and clone.skin_pattern.image.get_data() == child.skin_pattern.image.get_data(), "clonal offspring owns an unchanged copy")
    check(clone.skin_pattern.summary()["parent_weights"] == [1.0] and child.skin_pattern.summary()["parent_weights"] == [0.5, 0.5], "appearance provenance distinguishes clonal and sexual inheritance")
    var saved: Image = child.skin_pattern.image
    TextureAssets.enabled = false
    check(TextureAssets.resolve_image(child.skin_pattern) == null, "disabling hides texture access")
    TextureAssets.enabled = true
    check(TextureAssets.resolve_image(child.skin_pattern) == saved, "re-enabling preserves established coat")
    a = null
    b = null
    child = null
    check(_near(grandchild.skin_pattern.image.get_pixel(13, 59), 0.75, 0.0, 0.25), "descendant pixels survive destruction of parent genomes")
    var fresh = Pattern.new()
    check(_near(TextureAssets.resolve_image(fresh).get_pixel(13, 59), 1.0, 1.0, 1.0), "new founders use replaced templates")
    TextureAssets.enabled = previous_enabled
    TextureAssets.sources = previous_sources
    TextureAssets.terrain_textures = previous_terrain
    TextureAssets.auxiliary_textures = previous_auxiliary
    TextureAssets.specialized_atlas = previous_atlas
    TextureAssets.images_built = previous_built
    print("TEXTURE SELFTEST: %d checks; %d failures" % [checks, failed])
    return failed == 0
