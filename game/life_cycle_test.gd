extends Node
const World = preload("res://game/reproduction_test_world.gd")
const Genome = preload("res://game/genome.gd")
const Cycle = preload("res://game/life_cycle.gd")
const Traits = preload("res://game/ecology_traits.gd")
const Visual = preload("res://game/organism_visual.gd")
var checks: int = 0
var failed: int = 0

func check(ok: bool, label: String) -> void:
    checks += 1
    if ok: print("LIFE CYCLE OK: ", label)
    else:
        failed += 1
        printerr("SELFTEST ERROR: life cycle: ", label)

func make_world():
    var world = World.new()
    add_child(world)
    world.set_process(false)
    world.half_extent = 72.0
    world.habitat.configure(7, 144.0)
    world.rng.seed = 3321
    var empty_resources: Array[Vector3] = []
    world.ecology.configure(world.habitat, empty_resources)
    return world

func make_parent(world, seed_value: int, route: String = "spawn"):
    var g = Genome.new()
    g.seed = seed_value
    g.family_id = seed_value
    g.brood_size = 0.0
    g.gestation_gene = 0.0
    g.sex_system = 0.2
    g.asexual_drive = 0.0
    g.internal_fertilization = 0.2 if route == "spawn" else 0.8
    g.live_birth = 0.8 if route in ["live_birth", "retained_egg"] else 0.1
    g.maternal_nourishment = 0.9 if route == "live_birth" else 0.1
    g.egg_protection = 0.9
    var p: Vector3 = world.habitat.nearest_medium(Vector3(-40, 0, 0), true, 3.0)
    var org = world.spawn_genome(g, p)
    org.age_seconds = 100.0
    org.development_progress = 1.0
    org.energy = 1.4
    org.egg_reserve = 0.78 if Cycle.produces_eggs(org) else 0.0
    org.sperm_reserve = 0.11 if Cycle.produces_sperm(org) else 0.0
    org.bud_reserve = 0.32
    org.complexity = 25.0
    org.in_water = true
    org.visual.rebuild(true)
    return org

func tissue_count(org, kind: int) -> int:
    var count: int = 0
    for cell in org.visual.body_cells:
        if int(cell["t"]) == kind: count += 1
    return count

func run_all() -> bool:
    var w = make_world()
    check(w.habitat.has_sky(), "coast habitat has usable sky")
    for plan in range(7):
        var founder = w.spawn_random(plan)
        check(w.habitat.is_water(founder.global_position) and founder.global_position.y > w.habitat.floor_at(founder.global_position), "founder in accessible water: %d" % plan)
        check(Traits.water_breathing(founder.genome) >= 0.85 and Traits.walking(founder.genome) < 0.18 and not Traits.flight_body(founder.genome), "aquatic founder cannot already walk/fly: %d" % plan)
    w.habitat.configure(7, 146.0)
    var empty_resources: Array[Vector3] = []
    w.set_habitat(7, 146.0, w.habitat.waterline, w.habitat.ground_y, w.habitat, empty_resources)
    var founders_wet: bool = true
    for founder in w.organisms:
        founders_wet = founders_wet and w.habitat.is_water(founder.global_position)
    check(founders_wet, "final shared coastal geometry keeps every founder underwater")
    w.queue_free()

    w = make_world()
    var a = make_parent(w, 2)
    var b = make_parent(w, 3)
    check(w.reproduction.compatibility(a, b) > 0.99, "different lineage labels may share compatible genes")
    b.genome.body_plan = 6
    check(w.reproduction.compatibility(a, b) > 0.99, "silhouette is not an automatic species barrier")
    b.genome.seed = 4
    b.genome.sex_chromosomes = [0, 0]
    check(w.reproduction.compatibility(a, b) == 0.0, "two egg-only roles cannot fertilize each other")
    b.genome.seed = 3
    b.genome.sex_chromosomes = [0, 1]
    b.age_seconds = 0.0
    b.development_progress = clampf(0.0 / (24.0 + b.genome.maturation_gene * 60.0), 0.0, 1.0)
    check(not b.can_reproduce() and w.reproduction.compatibility(a, b) == 0.0, "newborns cannot mate")
    b.age_seconds = 100.0
    b.development_progress = 1.0
    a.genome.gamete_code = 0.0
    a.genome.development_code = 0.0
    b.genome.gamete_code = 1.0
    b.genome.development_code = 1.0
    check(w.reproduction.compatibility(a, b) == 0.0, "genetic isolation prevents distant hybridization")
    a.genome.gamete_code = 0.5
    a.genome.development_code = 0.5
    b.genome.gamete_code = 0.5
    b.genome.development_code = 0.5
    a.genome.sex_system = 0.9
    b.genome.sex_system = 0.9
    check(w.reproduction.compatibility(a, b) > 0.0, "two compatible hermaphrodites can cross")
    check(w.reproduction.compatibility(a, a) == 0.0, "sexual self-fertilization is not a fallback")
    check(not w.reproduction._conceive(w, a, null), "missing mate does not silently clone a sexual organism")
    b.global_position += Vector3(50, 0, 0)
    check(not w.reproduction._conceive(w, a, b), "fertilization requires spatial contact")
    b.global_position = a.global_position
    a.in_water = false
    check(not w.reproduction._conceive(w, a, b), "external spawning requires water")
    a.in_water = true
    var energy_before: float = a.energy + b.energy + a.egg_reserve + b.sperm_reserve
    check(w.reproduction._conceive(w, a, b), "compatible external fertilization creates a brood")
    check(w.organisms.size() == 2 and w.reproduction.reserved_count() == 1, "conception does not immediately spawn a newborn")
    check(a.children == 0 and b.children == 0, "offspring count waits for birth")
    check(a.energy + b.energy + a.egg_reserve + b.sperm_reserve + float(w.reproduction.broods[0]["energy"]) <= energy_before, "embryo reserves are funded by parents")
    w.reproduction._develop_broods(w, 6.0)
    check(w.organisms.size() == 2, "eggs require incubation")
    w.reproduction._develop_broods(w, 20.0)
    check(w.organisms.size() == 3 and w.reproduction.reserved_count() == 0, "incubated egg hatches and releases reservation")
    var child = w.organisms[2]
    check(child.age_seconds == 0.0 and not child.can_reproduce(), "hatchling begins at age zero and is immature")
    check(child.flight_skill == 0.0 and child.tool_skill == 0.0 and child.hunting_skill == 0.0, "learned parental skills are not inherited")
    check(child.parent_a == a.organism_id and child.parent_b == b.organism_id and a.children == 1 and b.children == 1, "birth records both parents")
    check(child.energy < 0.50, "hatching does not mint default initialization energy")
    w.queue_free()

    for route in ["live_birth", "retained_egg", "egg"]:
        w = make_world()
        a = make_parent(w, 2, route)
        b = make_parent(w, 3, route)
        check(w.reproduction._conceive(w, a, b), "internal fertilization route: " + route)
        check(a.carrying_count == 1 and not a.can_reproduce(), "carrier cannot start overlapping brood: " + route)
        var carrier_energy: float = a.energy
        w.reproduction._develop_broods(w, 4.0)
        if route == "live_birth":
            check(a.energy < carrier_energy, "viviparous embryo receives maternal nutrition")
        else:
            check(is_equal_approx(a.energy, carrier_energy), "yolk-dependent embryo does not draw maternal food: " + route)
        w.reproduction._develop_broods(w, 0.1)
        if route == "egg":
            check(a.carrying_count == 0 and not w.reproduction.broods[0]["internal"], "oviparous parent lays eggs before hatching")
        else:
            check(a.carrying_count == 1, "retained embryo stays in carrier: " + route)
        w.reproduction.step(w, 20.0, false)
        check(w.organisms.size() == 3 and a.carrying_count == 0, "development continues with new reproduction off: " + route)
        w.queue_free()

    w = make_world()
    a = make_parent(w, 2, "live_birth")
    b = make_parent(w, 3, "live_birth")
    w.reproduction._conceive(w, a, b)
    a.alive = false
    w.reproduction._develop_broods(w, 30.0)
    check(w.reproduction.reserved_count() == 0 and w.reproduction.losses == 1 and w.organisms.size() == 2, "carrier death terminates internal brood")
    w.queue_free()

    w = make_world()
    a = make_parent(w, 2)
    b = make_parent(w, 3)
    w.reproduction._conceive(w, a, b)
    w.reproduction.broods[0]["position"] = w.habitat.nearest_medium(Vector3(40, 0, 0), false)
    w.reproduction._develop_broods(w, 30.0)
    check(w.reproduction.losses == 1 and w.organisms.size() == 2, "aquatic eggs cannot hatch after lethal desiccation")
    w.queue_free()

    w = make_world()
    w.test_cap = 3
    a = make_parent(w, 2)
    b = make_parent(w, 3)
    w.reproduction._conceive(w, a, b)
    check(w.reproduction.available_slots(w) == 0 and w.spawn_random() == null, "embryo reservation prevents manual injection stealing birth slot")
    w.reproduction._develop_broods(w, 30.0)
    check(w.organisms.size() == 3, "reserved birth respects population limit")
    w.queue_free()

    w = make_world()
    a = make_parent(w, 2, "live_birth")
    b = make_parent(w, 3, "live_birth")
    a.pair_target_id = b.organism_id
    b.pair_target_id = a.organism_id
    w.reproduction.pairs.append({"a": a.organism_id, "b": b.organism_id, "contact": 0.0, "elapsed": 0.0})
    w.reproduction.step(w, 0.5, true)
    check(a.reproduction_state == "copulating" and w.reproduction.conceptions == 0, "internal mating has a timed contact phase")
    b.global_position += Vector3(10, 0, 0)
    w.reproduction.step(w, 0.5, true)
    check(w.reproduction.pairs[0]["contact"] == 0.0, "separation resets coupling progress")
    b.global_position = a.global_position
    for i in range(12): w.reproduction.step(w, 0.5, true)
    check(w.reproduction.conceptions == 1 and a.carrying_count == 1 and w.organisms.size() == 2, "sustained coupling proceeds to gestation")
    w.queue_free()

    w = make_world()
    a = make_parent(w, 2)
    a.age_seconds = 0.0
    a.development_progress = clampf(0.0 / (24.0 + a.genome.maturation_gene * 60.0), 0.0, 1.0)
    a.visual.rebuild(true)
    var newborn_size: float = a.visual.get_body_size_hint()
    check(tissue_count(a, Visual.Tissue.GONAD) == 0 and tissue_count(a, Visual.Tissue.CLASPER) == 0, "immature body lacks developed reproductive anatomy")
    a.age_seconds = 100.0
    a.development_progress = 1.0
    a.visual.rebuild(true)
    check(a.visual.get_body_size_hint() > newborn_size * 2.0 and tissue_count(a, Visual.Tissue.GONAD) > 0, "maturity grows body and primary anatomy")
    a.genome.metamorphosis = 1.0
    a.genome.armor_drive = 0.8
    a.genome.size_gene = 0.25
    a.genome.aquatic_larva = 1.0
    var maturity: float = Cycle.maturity_age(a.genome)
    a.age_seconds = maturity * 0.2
    a.development_progress = 0.2
    check(Cycle.stage(a) == "larva" and Cycle.water_breathing(a) >= 0.75, "aquatic larval physiology")
    a.age_seconds = maturity * 0.7
    a.development_progress = 0.7
    a.visual.rebuild(true)
    a.apply_environment(0.1, w.habitat)
    check(Cycle.stage(a) == "pupa" and not a.can_fly and tissue_count(a, Visual.Tissue.COCOON) > 0, "pupa changes shape and cannot fly")
    var before_food: float = a.energy
    w.ecology.act(a, 0.1, w.rng)
    check(a.behavior_state == "metamorphosing" and a.energy <= before_food, "pupa does not forage")
    a.age_seconds = maturity + 1.0
    a.development_progress = 1.0
    a.visual.rebuild(true)
    check(Cycle.stage(a) == "adult" and tissue_count(a, Visual.Tissue.COCOON) == 0, "metamorphosis releases adult body")
    w.queue_free()

    w = make_world()
    a = make_parent(w, 2)
    a.genome.muscle_drive = 1.0
    a.genome.burst_drive = 1.0
    a.genome.lung_drive = 0.0
    a.genome.skin_breathing = 0.0
    a.global_position = Vector3(-40, w.habitat.waterline - 0.25, 0)
    var target: Vector3 = a.global_position + Vector3(0, 2.0, 0)
    check(w.ecology.strike_mode(a, target) == "breach", "strong swimmer can target low aerial prey")
    check(not w.ecology.hunt_reachable(a, target + Vector3.UP * 30.0), "breaching cannot reach high flyers")
    check(a.begin_burst(target, "breach") and a.velocity.y > 0.0 and a.stamina < 0.8, "breach uses upward momentum and stamina")
    for i in range(40):
        a.apply_environment(0.1, w.habitat)
        a.motion_step(0.1, w.half_extent)
    check(a.burst_time == 0.0 and a.burst_cooldown > 0.0 and a.global_position.y < w.habitat.waterline, "ballistic breach returns to water and has cooldown")
    a.genome.dive_drive = 1.0
    a.in_water = false
    a.airborne = true
    a.global_position = Vector3(-40, w.habitat.waterline + 2.0, 0)
    check(w.ecology.strike_mode(a, Vector3(-40, w.habitat.waterline - 2.0, 0)) == "dive", "aerial hunter can target shallow water prey")
    check(w.ecology.strike_mode(a, Vector3(-40, w.habitat.waterline - 20.0, 0)) == "", "dive depth remains bounded")
    w.queue_free()
    w = make_world()
    a = make_parent(w, 2)
    b = make_parent(w, 3)
    a.genome.lung_drive = 1.0
    a.genome.gill_drive = 0.0
    a.genome.skin_breathing = 0.0
    a.genome.reach_drive = 1.0
    a.energy = 0.6
    var lo: float = -72.0
    var hi: float = 72.0
    for i in range(24):
        var middle: float = (lo + hi) * 0.5
        if w.habitat.floor_at(Vector3(middle, 0, 0)) < w.habitat.waterline: lo = middle
        else: hi = middle
    var shore: float = (lo + hi) * 0.5
    a.global_position = Vector3(shore + 0.2, 0, 0)
    a.global_position.y = w.habitat.floor_at(a.global_position) + a.body_clearance()
    b.global_position = Vector3(shore - 0.4, w.habitat.waterline - 0.15, 0)
    a.in_water = false
    a.airborne = false
    check(w.ecology.strike_mode(a, b.global_position) == "shore_snap", "land hunter can reach an adjacent surface swimmer")
    var predator_energy: float = a.energy
    var prey_energy: float = b.energy
    w.ecology._cross_bite(a, b, 0.5)
    check(b.energy < prey_energy and a.energy > predator_energy and a.energy + b.energy < predator_energy + prey_energy, "shore bite consumes real prey and loses conversion energy")
    b.global_position.x -= 40.0
    var remote_energy: float = b.energy
    w.ecology._cross_bite(a, b, 0.5)
    check(b.energy == remote_energy, "distant prey cannot be bitten through space")
    w.queue_free()

    w = make_world()
    a = make_parent(w, 2, "egg")
    b = make_parent(w, 3, "egg")
    a.global_position = Vector3(-40, w.habitat.waterline - 0.20, 0)
    b.global_position = Vector3(-40, w.habitat.waterline + 0.20, 0)
    a.in_water = true
    b.in_water = false
    b.genome.lung_drive = 1.0
    b.genome.gill_drive = 0.0
    check(w.reproduction._conceive(w, a, b), "compatible shoreline parents can reproduce across the water boundary")
    w.queue_free()

    w = make_world()
    a = make_parent(w, 2)
    a.genome.asexual_drive = 1.0
    check(w.reproduction._conceive(w, a, null) and w.reproduction.reserved_count() == 1, "clonal reproduction requires its own inherited capability")
    w.queue_free()

    var original = Genome.new()
    var other = Genome.new()
    var rng = RandomNumberGenerator.new()
    rng.seed = 91
    for gene_name in original.life_cycle_gene_names():
        original.set(gene_name, 0.63)
        other.set(gene_name, 0.21)
    var inherited = original.mutated(rng, 0.0, 0.0)
    var crossed = original.crossover(other, rng, 0.20, 1.0)
    for gene_name in original.life_cycle_gene_names():
        check(is_equal_approx(float(inherited.get(gene_name)), 0.63), "life-cycle gene inherited: " + gene_name)
        check(float(crossed.get(gene_name)) >= 0.0 and float(crossed.get(gene_name)) <= 1.0, "life-cycle crossover/mutation bounded: " + gene_name)
    print("LIFE CYCLE SELFTEST: ", checks, " checks; ", failed, " failures")
    return failed == 0
