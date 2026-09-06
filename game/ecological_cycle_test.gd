extends Node

const World = preload("res://game/reproduction_test_world.gd")
const Genome = preload("res://game/genome.gd")
const Cycle = preload("res://game/life_cycle.gd")
const Visual = preload("res://game/organism_visual.gd")
var checks: int = 0
var failed: int = 0

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failed += 1
        printerr("SELFTEST ERROR: ecological cycle: " + label)

func make_world():
    var world = World.new()
    add_child(world)
    world.process_mode = Node.PROCESS_MODE_DISABLED
    world.half_extent = 72.0
    world.habitat.configure(7, 144.0)
    world.rng.seed = 73191
    var resources: Array[Vector3] = []
    world.ecology.configure(world.habitat, resources)
    world.experiment_settings = {"auto_reseed": false, "visual_cell_cap": 240}
    return world

func make_adult(world, seed_value: int):
    var genome = Genome.new()
    genome.randomize_from(world.rng, seed_value, Genome.PLAN_RADIAL)
    genome.aquatic_founder()
    var org = world.spawn_genome(genome, world.habitat.nearest_medium(Vector3(-35, 0, seed_value % 5), true, 2.0))
    org.age_seconds = 100.0
    org.development_progress = 1.0
    org.energy = 1.2
    org.egg_reserve = 0.78 if Cycle.produces_eggs(org) else 0.0
    org.sperm_reserve = 0.14 if Cycle.produces_sperm(org) else 0.0
    return org

func run_all() -> bool:
    var world = make_world()
    var founder_genome = Genome.new()
    founder_genome.randomize_from(world.rng, 10, Genome.PLAN_SERPENTINE)
    founder_genome.aquatic_founder()
    var founder = world.spawn_genome(founder_genome, world.habitat.nearest_medium(Vector3(-20, 0, 2), true, 1.0))
    check(founder_genome.generation == 0 and founder_genome.mutation_events == 0 and founder_genome.macro_mutation_events == 0, "initial founder carries no mutation history")
    check(is_equal_approx(founder.complexity, 0.5), "initial founder starts at embryo complexity")
    var late_genome = founder_genome.mutated(world.rng, 0.0, 0.0)
    late_genome.generation = 20
    var late_descendant = world.spawn_genome(late_genome, world.habitat.nearest_medium(Vector3(-15, 0, 2), true, 1.0))
    check(is_equal_approx(late_descendant.complexity, founder.complexity), "generation count does not pre-age a newborn body")
    world.organisms.erase(founder)
    world.organisms.erase(late_descendant)
    founder.queue_free()
    late_descendant.queue_free()
    var trauma_genome = Genome.new()
    var trauma = world.spawn_genome(trauma_genome, world.habitat.nearest_medium(Vector3(-12, 0, 2), true, 1.0))
    trauma.age_seconds = 100.0
    trauma.development_progress = 1.0
    trauma.tissue_damage = 0.90
    trauma.energy = 0.35
    trauma.apply_environment(0.1, world.habitat)
    check(not trauma.alive and trauma.death_cause == "trauma_collapse", "unrepaired critical trauma causes physical collapse")
    world.organisms.erase(trauma)
    trauma.queue_free()
    var org = make_adult(world, 11)
    var body_complexity: float = org.complexity
    var mind: float = org.intelligence
    org.think_step(2.0, org.global_position, Vector3.ZERO, Vector3.ZERO, world.rng, 1.0)
    check(is_equal_approx(org.complexity, body_complexity) and org.intelligence > mind, "adult learning continues without post-maturity body construction")

    org.age_seconds = org.natural_lifespan()
    org.apply_environment(0.1, world.habitat)
    check(not org.alive and org.death_cause == "senescence", "finite inherited lifespan causes senescent death")
    var death_position: Vector3 = org.global_position
    world._cleanup_dead(false)
    check(world.organisms.is_empty() and world.remains.size() == 1 and world.remains[0]["stage"] == "corpse", "dead body becomes visible finite carrion")
    check(world.remains[0]["position"] == death_position and world.remains[0]["cause"] == "senescence", "remains retain death position and cause")
    var start_y: float = world.remains[0]["position"].y
    world._age_remains(12.0)
    check(world.remains[0]["position"].y < start_y and world.remains[0]["biomass"] < 3.0, "aquatic corpse sinks and decomposes after a fresh interval")

    org = make_adult(world, 12)
    org.age_seconds = 10.0
    org.global_position = world.habitat.nearest_medium(Vector3(38, 0, 0), false, org.body_clearance())
    org.oxygen = 0.0
    org.anoxia_seconds = 6.0 + org.genome.breath_storage * 8.0
    var exposed: Vector3 = org.global_position
    org.apply_environment(0.1, world.habitat)
    check(not org.alive and org.death_cause == "anoxia" and org.global_position.distance_to(exposed) < 0.01, "unadapted older aquatic body is not rescued from lethal air exposure")

    var patterned = TextureAssets.procedural_fallback("unforeseen_nematocyst")
    var other_pattern = TextureAssets.procedural_fallback("unforeseen_shell")
    var mirrored: bool = patterned.get_pixel(0, 17) == patterned.get_pixel(127, 17) and patterned.get_pixel(23, 0) == patterned.get_pixel(23, 127)
    check(patterned.get_width() == 128 and patterned.get_height() == 128 and mirrored, "procedural missing texture is bounded and seamless on both axes")
    check(patterned.get_data() != other_pattern.get_data(), "different missing materials receive distinct deterministic patterns")

    var feeder = make_adult(world, 13)
    feeder.genome.size_gene = 1.0
    feeder.genome.reach_drive = 1.0
    feeder.genome.grazer_drive = 1.0
    feeder.visual.rebuild(true)
    var mouth: Vector3 = feeder.Navigation.mouth_position(feeder)
    var ground_food = Vector3(mouth.x, world.habitat.floor_at(mouth) + 0.4, mouth.z)
    feeder.global_position.y += maxf(0.0, ground_food.y + feeder.body_clearance() - feeder.global_position.y)
    check(feeder.Navigation.can_feed(feeder, ground_food), "large body can lower a flexible feeding region to ground food")

    var jelly = make_adult(world, 14)
    jelly.genome.body_plan = Genome.PLAN_RADIAL
    jelly.genome.mucus_cover = 1.0
    jelly.genome.membrane_cover = 1.0
    jelly.genome.support_drive = 0.0
    jelly.genome.armor_drive = 0.0
    jelly.genome.shell_drive = 0.0
    jelly.genome.scale_cover = 0.0
    jelly.genome.predator_drive = 1.0
    jelly.genome.ambush_drive = 1.0
    jelly.genome.pattern_drive = 1.0
    jelly.genome.pigment_value = 1.0
    jelly.genome.sensory_drive = 1.0
    jelly.genome.camouflage = 1.0
    jelly.genome.beak_drive = 1.0
    jelly.genome.aggression = 1.0
    jelly.complexity = 12.0
    jelly.visual.rebuild(true)
    var tissues: Dictionary = {}
    for cell in jelly.visual.body_cells: tissues[int(cell["t"])] = true
    check(tissues.has(Visual.Tissue.GEL) and tissues.has(Visual.Tissue.NEMATOCYST), "distributed traits can express a gelatinous stinging body")
    check(tissues.has(Visual.Tissue.LIGHT_ORGAN) and tissues.has(Visual.Tissue.FANG), "inherited combinations can express light organs and fangs")

    var mother = make_adult(world, 15)
    var donor = make_adult(world, 16)
    mother.genome.internal_fertilization = 0.0
    donor.genome.internal_fertilization = 0.0
    mother.genome.sex_system = 0.9
    donor.genome.sex_system = 0.9
    mother.global_position = world.habitat.nearest_medium(Vector3(-32, 0, 0), true, 2.0)
    donor.global_position = mother.global_position
    mother.in_water = true
    donor.in_water = true
    mother.egg_reserve = 0.78
    donor.sperm_reserve = 0.14
    check(world.reproduction._release_spawn_cloud(world, mother), "external egg producer releases a finite spawn cloud")
    check(mother.carrying_count == 0 and world.reproduction.broods.is_empty(), "external spawning is not represented as pregnancy")
    world.reproduction._advance_spawn_clouds(world, 0.1)
    check(world.reproduction.spawn_clouds.is_empty() and world.reproduction.broods.size() == 1, "compatible swimmer fertilizes spawn by contacting the cloud")
    check(world.reproduction.broods[0]["route"] == "spawn" and not world.reproduction.broods[0]["internal"], "fertilized spawn develops outside both parents")

    world.free()
    print("ECOLOGICAL CYCLE SELFTEST: %d checks; %d failures" % [checks, failed])
    return failed == 0
