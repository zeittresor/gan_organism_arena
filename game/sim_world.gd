extends Node3D

const GenomeScript = preload("res://game/genome.gd")
const OrganismScript = preload("res://game/organism.gd")
const NutrientFieldScript = preload("res://game/nutrient_field.gd")
const EcologyScript = preload("res://game/ecology_system.gd")
const HabitatModelScript = preload("res://game/habitat_model.gd")
var habitat = HabitatModelScript.new()
var ecology = EcologyScript.new()
const BODY_PLAN_COUNT: int = 7

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
var failed_developments: int = 0
var crossover_births: int = 0
var mutation_births: int = 0
var habitat_level: int = 5
var waterline: float = 21.0
var ground_y: float = -21.0
var predation_events: int = 0
var courtship_events: int = 0
var hierarchy_events: int = 0

func initialize(seed_value: int = 1337) -> void:
    rng.seed = seed_value
    half_extent = float(SettingsStore.get_value("world_size", 144.0)) * 0.5
    view_mode = str(SettingsStore.get_value("view_mode", "natural"))
    visual_cap = int(SettingsStore.get_value("visual_cell_cap", 180))
    habitat.configure(int(SettingsStore.get_value("habitat_level", 5)), half_extent * 2.0)
    habitat_level = habitat.level
    waterline = habitat.waterline
    ground_y = habitat.ground_y
    ecology.configure(habitat, [])
    nutrient_field = NutrientFieldScript.new()
    add_child(nutrient_field)
    nutrient_field.initialize(int(SettingsStore.get_value("nutrient_count", 540)), half_extent, seed_value + 91)
    nutrient_field.set_habitat(habitat)
    var initial: int = int(SettingsStore.get_value("initial_organisms", 16))
    for i in range(initial):
        # The first population deliberately spans topology-space. Selection may
        # later remove any of these forms; the seed itself is not worm-biased.
        spawn_random(i % BODY_PLAN_COUNT)
    AppLog.info("3D simulation initialised: organisms=%d nutrients=%d extent=%.1f" % [organisms.size(), nutrient_field.points.size(), half_extent * 2.0])

func set_habitat(level: int, world_size: float, p_waterline: float, p_ground_y: float, shared_model = null, resource_positions: Array[Vector3] = []) -> void:
    habitat_level = clampi(level, 5, 9)
    half_extent = maxf(10.0, world_size * 0.5)
    waterline = p_waterline
    ground_y = p_ground_y
    if shared_model != null:
        habitat = shared_model
    else:
        habitat.configure(level, world_size)
    ecology.configure(habitat, resource_positions)
    if is_instance_valid(nutrient_field):
        nutrient_field.set_habitat(habitat)
    for org in organisms:
        if is_instance_valid(org):
            var p: Vector3 = org.global_position
            p.x = clampf(p.x, -half_extent, half_extent)
            p.y = clampf(p.y, -half_extent * 0.60, half_extent * 0.60)
            p.z = clampf(p.z, -half_extent, half_extent)
            p.y = maxf(p.y, habitat.floor_at(p) + org.body_clearance())
            org.global_position = p
            org.habitat = habitat
            org.rooted = false
            org.decision_timer = 0.0

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
    var spacing: float = float(SettingsStore.get_value("social_spacing", 4.5))
    var org_snapshot: Array = organisms.duplicate()
    ecology.predation_strength = float(SettingsStore.get_value("predation_strength", 0.45))
    ecology.group_strength = float(SettingsStore.get_value("group_strength", 0.55))
    ecology.begin_tick(org_snapshot, dt)
    for org in org_snapshot:
        if not is_instance_valid(org) or not org.alive:
            continue
        org.apply_environment(dt, habitat)
        if not org.alive:
            continue
        var nutrient_idx: int = nutrient_field.nearest_for(org)
        var nutrient_pos: Vector3 = org.global_position
        if nutrient_idx >= 0:
            nutrient_pos = nutrient_field.points[nutrient_idx]
            if org.grounded and not org.in_water:
                nutrient_pos.y = habitat.floor_at(nutrient_pos) + org.body_clearance()

        # Cohesion has a preferred distance instead of pulling two bodies into the
        # exact same point. Separation acts on every neighbour and eliminates the
        # alpha6 "permanent mating wobble" feedback loop.
        var social: Vector3 = Vector3.ZERO
        var threat: Vector3 = Vector3.ZERO
        var courtship: Vector3 = Vector3.ZERO
        for other in org_snapshot:
            if other == org or not is_instance_valid(other) or not other.alive:
                continue
            var offset: Vector3 = other.global_position - org.global_position
            var d2: float = maxf(offset.length_squared(), 0.0001)
            if d2 > 324.0:
                continue
            var distance: float = sqrt(d2)
            var direction: Vector3 = offset / distance
            var org_size: float = float(org.visual.get_body_size_hint()) if is_instance_valid(org.visual) and org.visual.has_method("get_body_size_hint") else 2.0
            var other_size: float = float(other.visual.get_body_size_hint()) if is_instance_valid(other.visual) and other.visual.has_method("get_body_size_hint") else 2.0
            var preferred: float = spacing + minf(3.0, (org_size + other_size) * 0.10)
            if distance < preferred:
                var push: float = (preferred - distance) / maxf(0.25, preferred)
                social -= direction * (0.95 + push * 2.2)
            elif distance < 16.0 and other.genome.family_id == org.genome.family_id:
                var pull: float = (16.0 - distance) / 16.0
                social += direction * pull * 0.34 * float(SettingsStore.get_value("group_strength", 0.55)) * (0.35 + float(org.genome.pack_drive))
                if absf(float(other.social_rank) - float(org.social_rank)) > 0.30 and distance < 8.0:
                    var rank_push: float = float(SettingsStore.get_value("hierarchy_strength", 0.35)) * 0.18
                    social += (-direction if org.social_rank < other.social_rank else direction) * rank_push
                    hierarchy_events += 1
            elif distance < 12.0 and (float(other.genome.cooperation) + float(org.genome.cooperation)) * 0.5 > 0.58:
                social += direction * 0.10 * float(SettingsStore.get_value("group_strength", 0.55))

            if org.can_reproduce() and other.can_reproduce() and distance < float(SettingsStore.get_value("mating_radius", 12.0)):
                var compatibility: float = 0.30 + (1.0 - absf(float(org.genome.courtship_drive) - float(other.genome.courtship_drive))) * 0.45
                if int(org.genome.body_plan) != int(other.genome.body_plan):
                    compatibility += 0.12
                var ritual_strength: float = compatibility * float(SettingsStore.get_value("courtship_strength", 0.75))
                courtship += direction * ritual_strength
                if distance < 8.0:
                    var tangent: Vector3 = Vector3.UP.cross(direction).normalized()
                    courtship += tangent * sin(elapsed_sim_time * 1.25 + float(org.organism_id)) * ritual_strength * 0.28
                if compatibility > 0.62:
                    org.pair_target_id = other.organism_id

            if other.genome.family_id != org.genome.family_id and float(other.genome.predator_drive) > 0.50 and distance < 13.0:
                threat += direction * ((13.0 - distance) / 13.0)

        social += courtship
        org.think_step(dt, nutrient_pos, social, threat, rng, evolution_rate)
        if courtship.length() > 0.4:
            org.behavior_state = "courtship"
            courtship_events += 1
        ecology.act(org, dt, rng)
        if nutrient_idx >= 0 and org.global_position.distance_squared_to(nutrient_pos) < 1.65:
            org.absorb_nutrient((0.18 + rng.randf_range(0.02, 0.14)) * (0.75 if org.rooted else 1.0))
            nutrient_field.respawn(nutrient_idx)

    predation_events = ecology.hunt_events
    _cleanup_dead()
    if bool(SettingsStore.get_value("auto_reproduce", true)):
        _reproduction_pass(dt)
    _cleanup_dead()

func _reproduction_pass(dt: float) -> void:
    var cap: int = int(SettingsStore.get_value("organism_cap", 28))
    # No complexity/intelligence ranking or forced culling: natural mortality
    # and finite resources open slots. Small, simple and sessile forms can win.
    if organisms.size() >= cap:
        return
    var candidates: Array = organisms.duplicate()
    for i in range(candidates.size() - 1, 0, -1):
        var j: int = rng.randi_range(0, i)
        var tmp = candidates[i]
        candidates[i] = candidates[j]
        candidates[j] = tmp
    var used: Dictionary = {}
    var mutation_strength: float = float(SettingsStore.get_value("mutation_strength", 0.14))
    var macro_rate: float = float(SettingsStore.get_value("macro_mutation_rate", 0.14))
    var crossover_rate: float = float(SettingsStore.get_value("crossover_rate", 0.82))

    for parent in candidates:
        if organisms.size() >= cap:
            break
        if not is_instance_valid(parent) or not parent.can_reproduce() or used.has(parent.organism_id):
            continue
        if rng.randf() >= parent.reproduction_probability(dt):
            continue

        var partner = _find_mate(parent, candidates, used)
        var child_genome = null
        var birth_mode: String = "mutation"
        var spawn_position: Vector3 = parent.global_position
        var inherited_complexity: float = parent.complexity
        var inherited_intelligence: float = parent.intelligence

        if is_instance_valid(partner) and rng.randf() < crossover_rate:
            var child_family: int = parent.genome.family_id
            if partner.genome.family_id != parent.genome.family_id or int(partner.genome.body_plan) != int(parent.genome.body_plan):
                child_family = next_family
                next_family += 1
            child_genome = parent.genome.crossover(partner.genome, rng, mutation_strength, macro_rate, child_family)
            birth_mode = "crossover"
            spawn_position = (parent.global_position + partner.global_position) * 0.5
            inherited_complexity = (parent.complexity + partner.complexity) * 0.5
            inherited_intelligence = (parent.intelligence + partner.intelligence) * 0.5
            parent.parent_cost()
            partner.parent_cost()
            used[parent.organism_id] = true
            used[partner.organism_id] = true
            crossover_births += 1
        else:
            child_genome = parent.genome.mutated(rng, mutation_strength, macro_rate)
            parent.parent_cost()
            used[parent.organism_id] = true
            mutation_births += 1

        spawn_position += Vector3(rng.randf_range(-3.4, 3.4), rng.randf_range(-2.0, 2.0), rng.randf_range(-3.4, 3.4))
        var child = spawn_genome(child_genome, spawn_position)
        if is_instance_valid(child):
            child.complexity = maxf(0.5, inherited_complexity * rng.randf_range(0.08, 0.24))
            child.intelligence = maxf(0.02, inherited_intelligence * rng.randf_range(0.14, 0.34))
            child.visual.rebuild(true)
            AppLog.info("birth id=%d mode=%s family=%d generation=%d plan=%s viability=%.3f" % [child.organism_id, birth_mode, child.genome.family_id, child.genome.generation, child.body_plan_name(), child.development_stability])

func _find_mate(parent, candidates: Array, used: Dictionary):
    var best = null
    var best_score: float = INF
    var mating_radius: float = float(SettingsStore.get_value("mating_radius", 12.0))
    for candidate in candidates:
        if candidate == parent or not is_instance_valid(candidate) or not candidate.can_reproduce():
            continue
        if used.has(candidate.organism_id):
            continue
        var distance: float = parent.global_position.distance_to(candidate.global_position)
        if distance > mating_radius:
            continue
        # Cross-family and cross-plan pairings are slightly favoured to keep the
        # gene pool from converging into one visual template.
        var diversity_bonus: float = 0.0
        if candidate.genome.family_id != parent.genome.family_id:
            diversity_bonus += 1.5
        if int(candidate.genome.body_plan) != int(parent.genome.body_plan):
            diversity_bonus += 2.0
        var score: float = distance - diversity_bonus
        if score < best_score:
            best_score = score
            best = candidate
    return best

func _cleanup_dead() -> void:
    for i in range(organisms.size() - 1, -1, -1):
        var org = organisms[i]
        if not is_instance_valid(org) or not org.alive:
            var oid: int = -1
            if is_instance_valid(org):
                oid = int(org.organism_id)
                if float(org.development_stability) < float(SettingsStore.get_value("viability_threshold", 0.18)):
                    failed_developments += 1
                    AppLog.info("development failed id=%d family=%d plan=%s viability=%.3f age=%.1f" % [org.organism_id, org.genome.family_id, org.body_plan_name(), org.development_stability, org.age_seconds])
            if selected == org:
                selected = null
            organisms.remove_at(i)
            if is_instance_valid(org):
                org.queue_free()
            organism_died.emit(oid)
            var minimum_population: int = maxi(6, int(int(SettingsStore.get_value("initial_organisms", 16)) / 2))
            if bool(SettingsStore.get_value("auto_reseed", false)) and organisms.size() < minimum_population:
                spawn_random()

func spawn_random(forced_plan: int = -1):
    var genome = GenomeScript.new()
    genome.randomize_from(rng, next_family, forced_plan)
    next_family += 1
    var spawn = Vector3(rng.randf_range(-half_extent * 0.75, half_extent * 0.75), -half_extent * 0.15, rng.randf_range(-half_extent * 0.75, half_extent * 0.75))
    # Seed aquatic ancestors in accessible water rather than dry air or rock.
    spawn = habitat.nearest_medium(spawn, true, 1.0)
    return spawn_genome(genome, spawn)

func spawn_genome(genome, spawn: Vector3):
    if organisms.size() >= int(SettingsStore.get_value("organism_cap", 28)):
        return null
    var org = OrganismScript.new()
    add_child(org)
    org.initialize(next_id, genome, spawn, visual_cap, view_mode)
    org.habitat = habitat
    var p: Vector3 = org.global_position
    p.x = clampf(p.x, -half_extent + 0.5, half_extent - 0.5)
    p.z = clampf(p.z, -half_extent + 0.5, half_extent - 0.5)
    p.y = maxf(p.y, habitat.floor_at(p) + org.body_clearance())
    org.global_position = p
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
    var plans: Dictionary = {}
    var min_stability: float = 1.0
    for org in organisms:
        if not is_instance_valid(org):
            continue
        max_complexity = maxf(max_complexity, float(org.complexity))
        max_intelligence = maxf(max_intelligence, float(org.intelligence))
        avg_complexity += float(org.complexity)
        min_stability = minf(min_stability, float(org.development_stability))
        var plan_name: String = str(org.body_plan_name())
        plans[plan_name] = int(plans.get(plan_name, 0)) + 1
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
        "nutrients": nutrient_field.points.size() if is_instance_valid(nutrient_field) else 0,
        "body_plan_count": plans.size(),
        "min_stability": min_stability,
        "crossover_births": crossover_births,
        "mutation_births": mutation_births,
        "failed_developments": failed_developments,
        "predation_events": predation_events,
        "courtship_events": courtship_events,
        "hierarchy_events": hierarchy_events,
        "habitat_level": habitat_level,
        "pack_events": ecology.pack_events,
        "tool_events": ecology.tool_events,
        "cleaning_events": ecology.cleaning_events,
        "parasitic_events": ecology.parasitic_events
    }
