extends Node3D

const GenomeScript = preload("res://game/genome.gd")
const OrganismScript = preload("res://game/organism.gd")
const NutrientFieldScript = preload("res://game/nutrient_field.gd")

signal organism_born(organism)
signal organism_died(organism_id: int)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var organisms: Array = []
var nutrient_field = null
var next_id: int = 1
var next_family: int = 1
var half_extent: float = 36.0
var sim_accumulator: float = 0.0
var sim_steps: int = 0
var elapsed_sim_time: float = 0.0
var selected = null
var view_mode: String = "natural"
var visual_cap: int = 180

func initialize(seed_value: int = 1337) -> void:
    rng.seed = seed_value
    half_extent = float(SettingsStore.get_value("world_size", 72.0)) * 0.5
    view_mode = str(SettingsStore.get_value("view_mode", "natural"))
    visual_cap = int(SettingsStore.get_value("visual_cell_cap", 180))
    nutrient_field = NutrientFieldScript.new()
    add_child(nutrient_field)
    nutrient_field.initialize(int(SettingsStore.get_value("nutrient_count", 180)), half_extent, seed_value + 91)
    var initial: int = int(SettingsStore.get_value("initial_organisms", 16))
    for _i in range(initial):
        spawn_random()
    AppLog.info("3D simulation initialised: organisms=%d nutrients=%d extent=%.1f" % [organisms.size(), nutrient_field.points.size(), half_extent * 2.0])

func _process(delta: float) -> void:
    var speed: float = float(SettingsStore.get_value("simulation_speed", 1.0))
    for org in organisms:
        if is_instance_valid(org):
            org.motion_step(delta * speed, half_extent)
    sim_accumulator += delta * speed
    var hz: float = clampf(float(SettingsStore.get_value("simulation_tick_hz", 12.0)), 2.0, 30.0)
    var tick: float = 1.0 / hz
    var guard: int = 0
    while sim_accumulator >= tick and guard < 4:
        sim_accumulator -= tick
        _simulation_tick(tick)
        guard += 1

func _simulation_tick(dt: float) -> void:
    sim_steps += 1
    elapsed_sim_time += dt
    var evolution_rate: float = float(SettingsStore.get_value("evolution_rate", 1.0))
    var org_snapshot: Array = organisms.duplicate()
    for org in org_snapshot:
        if not is_instance_valid(org) or not org.alive:
            continue
        var nutrient_idx: int = nutrient_field.nearest_index(org.global_position)
        var nutrient_pos: Vector3 = org.global_position
        if nutrient_idx >= 0:
            nutrient_pos = nutrient_field.points[nutrient_idx]
        var social: Vector3 = Vector3.ZERO
        var threat: Vector3 = Vector3.ZERO
        for other in org_snapshot:
            if other == org or not is_instance_valid(other) or not other.alive:
                continue
            var offset: Vector3 = other.global_position - org.global_position
            var d2: float = maxf(offset.length_squared(), 0.01)
            if d2 < 180.0:
                if other.genome.family_id == org.genome.family_id:
                    social += offset.normalized() / maxf(1.0, sqrt(d2) * 0.25)
                elif other.genome.aggression > 0.55:
                    threat += offset.normalized() / maxf(1.0, sqrt(d2) * 0.22)
        org.think_step(dt, nutrient_pos, social, threat, rng, evolution_rate)
        if nutrient_idx >= 0 and org.global_position.distance_squared_to(nutrient_pos) < 1.65:
            org.absorb_nutrient(0.18 + rng.randf_range(0.02, 0.14))
            nutrient_field.respawn(nutrient_idx)

    if bool(SettingsStore.get_value("auto_reproduce", true)):
        _reproduction_pass(dt)
    _cleanup_dead()

func _reproduction_pass(dt: float) -> void:
    var cap: int = int(SettingsStore.get_value("organism_cap", 28))
    if organisms.size() >= cap:
        return
    var candidates: Array = organisms.duplicate()
    candidates.sort_custom(func(a, b):
        return a.evolutionary_score() > b.evolutionary_score()
    )
    for parent in candidates:
        if organisms.size() >= cap:
            break
        if not is_instance_valid(parent) or not parent.can_reproduce():
            continue
        if rng.randf() < parent.reproduction_probability(dt):
            var child_genome = parent.genome.mutated(rng, 0.07 + 0.05 * parent.genome.curiosity)
            var offset: Vector3 = Vector3(rng.randf_range(-4.0, 4.0), rng.randf_range(-2.0, 2.0), rng.randf_range(-4.0, 4.0))
            var child = spawn_genome(child_genome, parent.global_position + offset)
            if is_instance_valid(child):
                child.complexity = maxf(0.5, parent.complexity * rng.randf_range(0.06, 0.18))
                child.intelligence = maxf(0.02, parent.intelligence * rng.randf_range(0.12, 0.30))
                parent.parent_cost()

func _cleanup_dead() -> void:
    for i in range(organisms.size() - 1, -1, -1):
        var org = organisms[i]
        if not is_instance_valid(org) or not org.alive:
            var oid: int = -1
            if is_instance_valid(org):
                oid = int(org.organism_id)
            if selected == org:
                selected = null
            organisms.remove_at(i)
            if is_instance_valid(org):
                org.queue_free()
            organism_died.emit(oid)
            var minimum_population: int = maxi(6, int(int(SettingsStore.get_value("initial_organisms", 16)) / 2))
            if organisms.size() < minimum_population:
                spawn_random()

func spawn_random():
    var genome = GenomeScript.new()
    genome.randomize_from(rng, next_family)
    next_family += 1
    var spawn: Vector3 = Vector3(
        rng.randf_range(-half_extent * 0.75, half_extent * 0.75),
        rng.randf_range(-half_extent * 0.40, half_extent * 0.40),
        rng.randf_range(-half_extent * 0.75, half_extent * 0.75)
    )
    return spawn_genome(genome, spawn)

func spawn_genome(genome, spawn: Vector3):
    if organisms.size() >= int(SettingsStore.get_value("organism_cap", 28)):
        return null
    var org = OrganismScript.new()
    add_child(org)
    org.initialize(next_id, genome, spawn, visual_cap, view_mode)
    next_id += 1
    organisms.append(org)
    organism_born.emit(org)
    return org

func set_view_mode(mode: String) -> void:
    view_mode = mode
    SettingsStore.set_value("view_mode", mode)
    for org in organisms:
        if is_instance_valid(org) and is_instance_valid(org.visual):
            org.visual.set_view_mode(mode)

func set_visual_cap(cap: int) -> void:
    visual_cap = clampi(cap, 48, 500)
    SettingsStore.set_value("visual_cell_cap", visual_cap)
    for org in organisms:
        if is_instance_valid(org) and is_instance_valid(org.visual):
            org.visual.set_visual_cap(visual_cap)

func set_nutrient_count(count: int) -> void:
    SettingsStore.set_value("nutrient_count", count)
    if is_instance_valid(nutrient_field):
        nutrient_field.set_count(count)

func top_speakers(limit: int = 8) -> Array:
    var list: Array = organisms.duplicate()
    list.sort_custom(func(a, b):
        var ascore: float = a.intelligence * 1.7 + log(1.0 + a.complexity) * 0.6 + a.genome.vocal_drive * 0.35
        var bscore: float = b.intelligence * 1.7 + log(1.0 + b.complexity) * 0.6 + b.genome.vocal_drive * 0.35
        return ascore > bscore
    )
    if list.size() > limit:
        list.resize(limit)
    return list

func metrics() -> Dictionary:
    var max_complexity: float = 0.0
    var max_intelligence: float = 0.0
    var avg_complexity: float = 0.0
    var cells: int = 0
    for org in organisms:
        if not is_instance_valid(org):
            continue
        max_complexity = maxf(max_complexity, float(org.complexity))
        max_intelligence = maxf(max_intelligence, float(org.intelligence))
        avg_complexity += float(org.complexity)
        if is_instance_valid(org.visual):
            cells += int(org.visual.body_cells.size())
    if not organisms.is_empty():
        avg_complexity /= float(organisms.size())
    return {
        "organisms": organisms.size(),
        "steps": sim_steps,
        "time": elapsed_sim_time,
        "max_complexity": max_complexity,
        "avg_complexity": avg_complexity,
        "max_intelligence": max_intelligence,
        "visual_cells": cells,
        "nutrients": nutrient_field.points.size() if is_instance_valid(nutrient_field) else 0
    }
