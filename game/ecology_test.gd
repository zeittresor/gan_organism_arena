extends Node

const Genome = preload("res://game/genome.gd")
const Life = preload("res://game/organism.gd")
const Habitat = preload("res://game/habitat_model.gd")
const Ecology = preload("res://game/ecology_system.gd")
const Traits = preload("res://game/ecology_traits.gd")
var failed: int = 0
var checks: int = 0
var next_id: int = 1000

func check(condition: bool, label: String) -> void:
    checks += 1
    if condition:
        print("ECOLOGY OK: ", label)
    else:
        failed += 1
        printerr("SELFTEST ERROR: ecology: ", label)

func creature(g, p: Vector3 = Vector3.ZERO):
    var org = Life.new()
    add_child(org)
    next_id += 1
    org.initialize(next_id, g, p, 180, "natural")
    org.age_seconds = 40.0
    org.complexity = 35.0
    org.intelligence = 0.6
    org.energy = 1.0
    return org

func run_all() -> bool:
    var model = Habitat.new()
    model.configure(5, 144.0)
    check(is_equal_approx(model.half_extent * 2.0, 144.0) and is_equal_approx(model.half_extent * 1.2, 86.4), "doubled world dimensions")
    check(not model.has_sky(), "aquarium has no usable sky")
    check(is_equal_approx(model.floor_at(Vector3.ZERO), model.ground_y), "aquarium floor agrees with model")
    model.configure(9, 144.0)
    var land: Vector3 = model.nearest_medium(Vector3(40, 0, 0), false)
    var water: Vector3 = model.nearest_medium(Vector3(-40, -15, 0), true)
    check(model.floor_at(land) > model.waterline and model.is_water(water), "land and submerged niches coexist")
    var x: int = 40
    var z: int = 23
    var sample: Vector3 = model.vertex(x, z) * 0.5 + model.vertex(x + 1, z) * 0.25 + model.vertex(x, z + 1) * 0.25
    check(absf(model.floor_at(sample) - sample.y) < 0.001, "floor query matches rendered triangle interpolation")

    var g = Genome.new()
    g.gill_drive = 0.0
    g.skin_breathing = 0.0
    g.lung_drive = 1.0
    g.breath_storage = 0.0
    var air_breather = creature(g, water)
    air_breather.energy = 1.4
    for i in range(12): air_breather.apply_environment(0.5, model)
    check(air_breather.oxygen < 0.05, "lung specialist exhausts breath under water")
    var amphibian_genome = Genome.new()
    amphibian_genome.gill_drive = 0.9
    amphibian_genome.lung_drive = 0.9
    amphibian_genome.terrestrial_drive = 0.8
    amphibian_genome.support_drive = 0.8
    amphibian_genome.limb_drive = 0.8
    check(Traits.amphibious(amphibian_genome), "dual respiration plus walking enables amphibious life")
    var amphibian = creature(amphibian_genome, water)
    for i in range(12): amphibian.apply_environment(0.5, model)
    check(amphibian.oxygen > 0.99, "amphibian breathes in water")
    amphibian.global_position = land
    for i in range(12): amphibian.apply_environment(0.5, model)
    check(amphibian.oxygen > 0.99, "amphibian breathes on land")

    var flyer_genome = Genome.new()
    flyer_genome.flight_drive = 1.0
    flyer_genome.wing_area = 1.0
    flyer_genome.light_skeleton = 1.0
    flyer_genome.support_drive = 1.0
    flyer_genome.limb_drive = 1.0
    flyer_genome.lung_drive = 1.0
    flyer_genome.size_gene = 0.1
    flyer_genome.armor_drive = 0.0
    flyer_genome.shell_drive = 0.0
    check(Traits.flight_body(flyer_genome), "coherent light winged body can support flight")
    var flyer = creature(flyer_genome, land + Vector3.UP * 2.0)
    flyer.flight_skill = 0.8
    flyer.apply_environment(0.1, model)
    check(flyer.airborne, "practised flyer flies in sky habitat")
    var aquarium = Habitat.new()
    aquarium.configure(5, 144.0)
    flyer.apply_environment(0.1, aquarium)
    check(not flyer.can_fly and not flyer.airborne, "flight forbidden without sky even with learned skill")
    flyer_genome.support_drive = 0.1
    check(not Traits.flight_body(flyer_genome), "unsupported skeleton cannot fly")
    flyer_genome.support_drive = 1.0
    flyer_genome.size_gene = 1.0
    flyer_genome.armor_drive = 1.0
    flyer_genome.shell_drive = 1.0
    flyer_genome.light_skeleton = 0.0
    check(not Traits.flight_body(flyer_genome), "heavy loading prevents flight")

    var slow = Genome.new()
    var fast = Genome.new()
    fast.muscle_drive = 1.0
    fast.fin_drive = 1.0
    fast.aquatic_drive = 1.0
    fast.tail_drive = 1.0
    check(Traits.swim_speed(fast) > Traits.swim_speed(slow), "propulsion and muscles increase swim speed")
    check(Traits.maintenance(fast) > Traits.maintenance(slow), "powerful swimming has maintenance cost")

    var eco = Ecology.new()
    var patch: Vector3 = land
    patch.y = model.floor_at(patch)
    eco.configure(model, [patch])
    var tree_g = Genome.new()
    tree_g.root_drive = 1.0
    tree_g.photosynthesis = 1.0
    tree_g.wood_drive = 1.0
    tree_g.support_drive = 1.0
    tree_g.lung_drive = 1.0
    var tree = creature(tree_g, patch)
    tree.apply_environment(0.1, model)
    tree.visual.rebuild(true)
    check(tree.rooted and tree.ecology_labels().has("tree"), "supported terrestrial autotroph roots and becomes tree-like")
    var before: float = tree.energy
    eco.begin_tick([tree], 0.1)
    eco.act(tree, 1.0, RandomNumberGenerator.new())
    check(tree.energy > before, "rooted photosynthesis supplies energy")
    tree.velocity = Vector3(10, 5, 10)
    var start: Vector3 = tree.global_position
    tree.motion_step(0.1, model.half_extent)
    check(absf(tree.global_position.x - start.x) < 0.001 and absf(tree.global_position.z - start.z) < 0.001, "roots prevent drifting")
    check(tree.visual.body_cells.size() <= 180, "sessile morphology respects render budget")
    var upright_g = Genome.new()
    upright_g.terrestrial_drive = 1.0
    upright_g.support_drive = 1.0
    upright_g.limb_drive = 1.0
    upright_g.balance_drive = 1.0
    upright_g.neural_drive = 1.0
    upright_g.lung_drive = 1.0
    var upright = creature(upright_g, land)
    upright.apply_environment(0.1, model)
    upright.visual.rebuild(true)
    check(upright.stand_upright and upright.visual.focus_anchor_local.y > upright.visual.rear_anchor_local.y, "upright gait creates vertical anatomy")

    var tool_g = Genome.new()
    tool_g.manipulation = 1.0
    tool_g.neural_drive = 1.0
    tool_g.limb_drive = 1.0
    tool_g.tool_drive = 1.0
    tool_g.lung_drive = 1.0
    tool_g.root_drive = 0.0
    tool_g.cleaning_drive = 0.0
    tool_g.parasite_drive = 0.0
    var user = creature(tool_g, land)
    user.global_position.y = patch.y + user.body_clearance()
    user.apply_environment(0.1, model)
    user.energy = 0.60
    eco.begin_tick([user], 0.1)
    eco.act(user, 0.5, RandomNumberGenerator.new())
    check(user.tool_durability > 0.0, "manipulator collects a physical tool")
    before = user.energy
    var stock: float = eco.stocks[0]
    eco.act(user, 0.5, RandomNumberGenerator.new())
    check(user.energy > before and eco.stocks[0] < stock and user.tool_durability < 1.0, "tool yields finite food and wears out")
    check(user.tool_skill > 0.0, "tool practice improves skill")

    var host_g = Genome.new()
    host_g.size_gene = 1.0
    host_g.gill_drive = 1.0
    var host = creature(host_g, water)
    var cleaner_g = Genome.new()
    cleaner_g.size_gene = 0.1
    cleaner_g.cleaning_drive = 1.0
    cleaner_g.gill_drive = 1.0
    var cleaner = creature(cleaner_g, water + Vector3.RIGHT * 0.2)
    host.parasite_load = 0.7
    host.surface_food = 0.0
    cleaner.energy = 0.6
    eco.begin_tick([host, cleaner], 0.1)
    before = host.energy
    eco._symbiosis(cleaner, 1.0, false)
    check(host.parasite_load < 0.7 and is_equal_approx(host.energy, before) and cleaner.energy > 0.6, "cleaning removes parasites without stealing host energy")
    cleaner_genome_parasite(cleaner)
    before = host.energy + cleaner.energy
    eco._symbiosis(cleaner, 1.0, true)
    check(host.energy < 1.0 and host.energy + cleaner.energy <= before, "parasitism damages host without creating energy")

    var hunter_g = Genome.new()
    hunter_g.predator_drive = 1.0
    hunter_g.pack_drive = 1.0
    hunter_g.cooperation = 1.0
    hunter_g.gill_drive = 1.0
    hunter_g.shyness = 0.0
    hunter_g.family_id = 50
    var hunter = creature(hunter_g, water)
    var ally_g = hunter_g.mutated(RandomNumberGenerator.new(), 0.0, 0.0)
    var ally = creature(ally_g, water + Vector3.RIGHT * 2.0)
    host.genome.family_id = 51
    host.global_position = water + Vector3.FORWARD * 5.0
    eco.begin_tick([hunter, ally, host], 0.1)
    check(hunter.prey_id == host.organism_id and ally.prey_id == hunter.prey_id, "pack chooses a shared prey target")
    eco._hunt(hunter, 0.1, RandomNumberGenerator.new())
    eco._hunt(ally, 0.1, RandomNumberGenerator.new())
    check(hunter.hunt_tactic == "flank" and ally.hunt_tactic == "flank", "pack members execute coordinated hunting")

    var rng = RandomNumberGenerator.new()
    rng.seed = 421
    var offspring = tool_g.mutated(rng, 0.0, 0.0)
    for key in tool_g.ecological_gene_names():
        check(is_equal_approx(float(tool_g.get(key)), float(offspring.get(key))), "heritable trait: " + key)
    var baby = creature(offspring, land)
    check(baby.tool_skill == 0.0 and baby.flight_skill == 0.0 and baby.hunting_skill == 0.0, "learned skills are not inherited as memories")
    var a_rng = RandomNumberGenerator.new()
    var b_rng = RandomNumberGenerator.new()
    a_rng.seed = 912
    b_rng.seed = 912
    var a = tool_g.mutated(a_rng, 0.18, 1.0)
    var b = tool_g.mutated(b_rng, 0.18, 1.0)
    check(a.seed == b.seed and a.body_plan == b.body_plan and is_equal_approx(a.root_drive, b.root_drive), "seeded macro mutations are reproducible")
    for node in get_children():
        node.queue_free()
    print("ECOLOGY SELFTEST: ", checks, " checks; ", failed, " failures")
    return failed == 0

func cleaner_genome_parasite(org) -> void:
    org.genome.parasite_drive = 1.0
