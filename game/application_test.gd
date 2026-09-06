extends Node

const World = preload("res://game/sim_world.gd")
const Save = preload("res://game/world_save.gd")
const Camera = preload("res://game/free_swim_camera.gd")
const HabitatVisual = preload("res://game/habitat_visual.gd")
var checks: int = 0
var failures: int = 0

func check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        printerr("APPLICATION SELFTEST ERROR: " + message)

func run_all() -> bool:
    var settings: Dictionary = SettingsStore.data.duplicate(true)
    var texture_enabled: bool = TextureAssets.enabled
    var mouse_mode = Input.mouse_mode
    var world = World.new()
    world.experiment_settings = {"initial_organisms": 2, "nutrient_count": 32, "auto_reseed": false, "visual_cell_cap": 64}
    world.process_mode = Node.PROCESS_MODE_DISABLED
    add_child(world)
    world.initialize(303003)
    var camera = Camera.new()
    add_child(camera)
    camera.enabled = false
    camera.place_safe_observer_start(world.habitat)
    # Startup and every free movement must use terrain at the final clamped XZ.
    check(camera.position.y >= world.habitat.floor_at(camera.position) + 1.14, "observer starts above terrain")
    var edge: Vector3 = camera._constrain_free_position(Vector3(9999, -9999, 9999))
    check(absf(edge.x) < world.half_extent and edge.y >= world.habitat.floor_at(edge) + 1.14, "camera bounds then terrain")
    camera.noclip_enabled = true
    var noclip: Vector3 = camera._constrain_free_position(Vector3(9999, world.habitat.bottom_y + 1.0, 9999))
    check(absf(noclip.x) < world.half_extent and noclip.y < world.habitat.floor_at(noclip), "noclip bypasses terrain but preserves world boundary")
    camera.noclip_enabled = false
    camera.rotation = Vector3(-0.23, 1.12, 0)
    camera.yaw = -2.0
    camera.pitch = 0.8
    var mouse = InputEventMouseMotion.new()
    mouse.relative = Vector2.ZERO
    camera.enabled = true
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    camera._unhandled_input(mouse)
    camera.enabled = false
    check(camera.rotation.distance_to(Vector3(-0.23, 1.12, 0)) < 0.001, "free look does not jump from stale angles")
    for bias in [0.0, 0.35, 1.0]:
        world.experiment_settings["plant_evolution_bias"] = bias
        check(not world.organisms[0].sessile_capable(), "founder remains motile at every plant bias")
    var parent = world.organisms[0]
    parent.genome.root_drive = 0.42
    parent.genome.photosynthesis = 0.45
    check(parent.sessile_capable() and parent.Cycle.mode(parent) == "propagule", "settlement and reproductive route agree under bias")
    parent.age_seconds = 30.0
    parent.development_progress = 0.63
    parent.energy = 0.72
    parent.growth_investment = 0.43
    parent.egg_reserve = 0.52
    parent.sperm_reserve = 0.11
    var cells = preload("res://game/cell_cycle.gd")
    cells.sync_gametes(parent)
    TextureAssets.set_enabled(true)
    parent.genome.skin_pattern = parent.genome.skin_pattern.offspring(world.organisms[1].genome.skin_pattern)
    world.selected = parent
    camera.follow_target = parent
    # Preserve an in-flight embryo and its immutable inherited coat as well.
    var embryo = parent.genome.mutated(world.rng, 0.1, 0.0)
    var marker = world.reproduction._make_marker(world, parent.position, "propagule")
    world.reproduction.broods.append({"genomes": [embryo], "position": parent.position, "route": "propagule", "internal": false, "marker": marker,
        "a": parent.organism_id, "b": -1, "age": 3.0, "duration": 20.0, "development": 0.15, "stage": "cleavage", "energy": 0.3, "health": 1.0, "wet": true, "protection": 0.5, "nourishment": 0.4, "hybrid": false, "viability": 1.0})
    world._register_remains(parent)
    world.nutrient_field.reserves[0] = 0.0
    var biomass: float = world.remains[0]["biomass"]
    world._age_remains(2.0)
    check(world.remains[0]["biomass"] < biomass, "finite detritus decays")
    check(world.recycled_energy > 0.0 and world.recycled_energy <= biomass - world.remains[0]["biomass"], "decomposition returns only paid biomass")
    parent.energy = 0.4
    parent.genome.cleaning_drive = 0.8
    parent.behavior_state = "forage"
    world.remains[0]["position"] = parent.Navigation.mouth_position(parent)
    biomass = world.remains[0]["biomass"]
    world._scavenge(parent, 0.1)
    check(world.scavenging_events == 1 and world.remains[0]["biomass"] < biomass and parent.energy > 0.4, "scavenger consumes finite nearby tissue")
    for plan in range(6):
        var g = world.GenomeScript.new()
        g.randomize_from(world.rng, 500 + plan, plan)
        g.aquatic_founder()
        g.head_drive = 1.0
        g.ensure_diploid()
        var body = world.OrganismScript.new()
        add_child(body)
        body.initialize(500 + plan, g, Vector3.ZERO, 180, "natural")
        body.complexity = 4.0
        body.development_progress = 1.0
        body.visual.rebuild(true)
        var head_cell: Dictionary = body.visual.body_cells[body.visual.focus_anchor_index]
        var head_width: float = head_cell["r"] * head_cell["s"].x
        var trunk_width: float = 0.0
        for i in range(body.visual.body_cells.size()):
            var part: Dictionary = body.visual.body_cells[i]
            if i != body.visual.focus_anchor_index and int(part["t"]) in [0, 1, 6]:
                trunk_width = maxf(trunk_width, float(part["r"]) * part["s"].x)
        check(head_width <= trunk_width * 1.15, "head supported plan=%d head=%.4f trunk=%.4f tissue=%d" % [plan, head_width, trunk_width, head_cell["t"]])
        g.head_drive = 0.0
        g.ensure_diploid()
        body.visual.rebuild(true)
        var small_head: Dictionary = body.visual.body_cells[body.visual.focus_anchor_index]
        check(float(small_head["r"]) < float(head_cell["r"]), "head proportions respond to inherited potential: " + str(plan))
        body.free()
    var codec = Save.new()
    var data: Dictionary = codec.capture(world, camera, settings)
    var path: String = "user://application-checkpoint-test.arena"
    check(codec.write_file(path, data), "checkpoint atomic write")
    var restored_data: Dictionary = codec.read_file(path)
    check(not restored_data.is_empty(), "checkpoint read")
    var restored = World.new()
    restored.process_mode = Node.PROCESS_MODE_DISABLED
    add_child(restored)
    var success: bool = codec.restore(restored, restored_data)
    check(success, "checkpoint restore: " + codec.last_error)
    if success:
        check(restored.organisms.size() == world.organisms.size(), "population restored without reseeding")
        var child = restored.organisms[0]
        check(child.genome.alleles == parent.genome.alleles and child.genome.seed == parent.genome.seed, "diploid genotype preserved")
        check(child.age_seconds == parent.age_seconds and child.development_progress == parent.development_progress and child.energy == parent.energy, "life stage and reserves preserved")
        check(child.egg_genomes == parent.egg_genomes and child.sperm_genomes == parent.sperm_genomes, "haploid gametes preserved")
        check(child.genome.skin_pattern.image.get_data() == parent.genome.skin_pattern.image.get_data(), "inherited coat pixels preserved")
        check(restored.reproduction.reserved_count() == 1 and restored.reproduction.broods[0]["age"] == 3.0, "developing embryo preserved")
        check(restored.nutrient_field.points == world.nutrient_field.points and restored.nutrient_field.reserves == world.nutrient_field.reserves, "food locations and stocks preserved")
        check(restored.remains == world.remains, "detritus preserved")
        check(restored.rng.randi() == world.rng.randi(), "simulation RNG continuation preserved")
        restored._simulation_tick(1.0 / 12.0)
        check(restored.sim_steps == world.sim_steps + 1, "restored world can advance")
    var damaged: PackedByteArray = FileAccess.get_file_as_bytes(path)
    damaged[damaged.size() - 1] = damaged[damaged.size() - 1] ^ 1
    var corrupt = FileAccess.open(path, FileAccess.WRITE)
    corrupt.store_buffer(damaged)
    corrupt.close()
    check(codec.read_file(path).is_empty(), "checksum rejects damaged payload before deserialization")
    var invalid = FileAccess.open(path, FileAccess.WRITE)
    invalid.store_var({"schema": "not-a-checkpoint"})
    invalid.close()
    check(codec.read_file(path).is_empty(), "invalid checkpoint rejected")
    check(not codec.write_file("user://missing-checkpoint-folder/world.arena", data), "write failure reported")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    # Every habitat can render seabed features, with no huge hidden instances.
    var visual = HabitatVisual.new()
    add_child(visual)
    for level in range(5, 10):
        visual.configure(level, 80.0)
        visual.update_remains(world.remains_snapshot())
        check(is_instance_valid(visual.reef_instance), "seabed rendering available in habitat " + str(level))
        check(visual.reef_instance.multimesh.visible_instance_count <= visual.REEF_CAPACITY, "bounded reef instances")
    var store = preload("res://game/settings_store.gd").new()
    store.path = "user://invalid-options-test.json"
    store.data = store.defaults.duplicate(true)
    var config = FileAccess.open(store.path, FileAccess.WRITE)
    var malformed: Dictionary = store.defaults.duplicate(true)
    malformed["simulation_speed"] = "broken"
    malformed["language"] = "de"
    malformed["mcp_enabled"] = "false"
    config.store_string(JSON.stringify(malformed))
    config.close()
    store.load_settings()
    check(store.get_value("simulation_speed") == 1.0 and store.get_value("language") == "de" and store.get_value("mcp_enabled") == false, "damaged config recovers valid values with safe defaults")
    check(store.export_profile("user://profile-test.json") == OK and store.read_profile("user://profile-test.json").has("settings"), "settings profile roundtrip")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://profile-test.json"))
    store.free()
    visual.free()
    restored.free()
    camera.free()
    world.free()
    TextureAssets.set_enabled(texture_enabled)
    SettingsStore.data = settings
    SettingsStore.save_settings()
    Input.mouse_mode = mouse_mode
    print("APPLICATION SELFTEST: %d checks; %d failures" % [checks, failures])
    return failures == 0
