extends Node3D

const Contact = preload("res://game/body_contact.gd")
const GenomeScript = preload("res://game/genome.gd")
const OrganismScript = preload("res://game/organism.gd")
const NutrientFieldScript = preload("res://game/nutrient_field.gd")
const EcologyScript = preload("res://game/ecology_system.gd")
const HabitatModelScript = preload("res://game/habitat_model.gd")
const ReproductionScript = preload("res://game/reproduction_system.gd")
const Cycle = preload("res://game/life_cycle.gd")
var reproduction = ReproductionScript.new()
var habitat = HabitatModelScript.new()
var ecology = EcologyScript.new()
const BODY_PLAN_COUNT: int = 7

signal organism_born(organism)
signal organism_died(organism_id: int)

var run_seed: int = 1337
var experiment_mode: bool = false
var experiment_settings: Dictionary = {}
var event_log: Array = []
var event_sequence: int = 0
var experiment_revision: int = 0
var nutrient_input: float = 0.0
var temperature_offset: float = 0.0

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
var habitat_level: int = 7
var waterline: float = 21.0
var ground_y: float = -21.0
var predation_events: int = 0
var courtship_events: int = 0
var hierarchy_events: int = 0
var contact_quality: int = 85
var perf_frames: int = 0
var perf_motion_usec: int = 0
var perf_biology_usec: int = 0
var perf_contact_usec: int = 0
var perf_peak_usec: int = 0
var observer_camera = null

func initialize(seed_value: int = 1337) -> void:
    contact_quality = clampi(int(_setting("contact_quality", 85)), 0, 100)
    temperature_offset = float(_setting("temperature_offset", 0.0))
    run_seed = seed_value
    rng.seed = seed_value
    half_extent = float(_setting("world_size", 144.0)) * 0.5
    view_mode = str(_setting("view_mode", "natural"))
    visual_cap = int(_setting("visual_cell_cap", 180))
    habitat.configure(int(_setting("habitat_level", 7)), half_extent * 2.0)
    habitat_level = habitat.level
    waterline = habitat.waterline
    ground_y = habitat.ground_y
    var empty_resources: Array[Vector3] = []
    ecology.configure(habitat, empty_resources)
    nutrient_field = NutrientFieldScript.new()
    add_child(nutrient_field)
    nutrient_field.initialize(int(_setting("nutrient_count", 540)), half_extent, seed_value + 91)
    nutrient_field.set_habitat(habitat)
    var initial: int = int(_setting("initial_organisms", 16))
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
            if sim_steps == 0 and org.genome.generation == 0:
                p = habitat.nearest_medium(p, true, org.body_clearance() + 0.5)
            org.global_position = p
            org.habitat = habitat
            org.rooted = false
            org.decision_timer = 0.0

func _process(delta: float) -> void:
    if experiment_mode: return
    var started: int = Time.get_ticks_usec()
    _update_render_visibility(delta)
    var speed: float = float(_setting("simulation_speed", 1.0))
    for org in organisms:
        if is_instance_valid(org):
            org.motion_step(delta * speed, half_extent)
    var after_motion: int = Time.get_ticks_usec()
    perf_motion_usec += after_motion - started
    _resolve_contacts()
    var before_biology: int = Time.get_ticks_usec()
    sim_accumulator += delta * speed
    var hz: float = clampf(float(_setting("simulation_tick_hz", 12.0)), 2.0, 30.0)
    var tick: float = 1.0 / hz
    var guard: int = 0
    while sim_accumulator >= tick and guard < 4:
        sim_accumulator -= tick
        _simulation_tick(tick, true)
        guard += 1
    var elapsed: int = Time.get_ticks_usec() - started
    perf_biology_usec += Time.get_ticks_usec() - before_biology
    perf_peak_usec = maxi(perf_peak_usec, elapsed)
    perf_frames += 1

func _simulation_tick(dt: float, contacts_ready: bool = false) -> void:
    sim_steps += 1
    elapsed_sim_time += dt
    var evolution_rate: float = float(_setting("evolution_rate", 1.0))
    var spacing: float = float(_setting("social_spacing", 4.5))
    var org_snapshot: Array = organisms.duplicate()
    ecology.predation_strength = float(_setting("predation_strength", 0.45))
    ecology.group_strength = float(_setting("group_strength", 0.55))
    ecology.begin_tick(org_snapshot, dt)
    nutrient_input += nutrient_field.replenish(dt, float(_setting("nutrient_renewal", 1.0)))
    for org in org_snapshot:
        if not is_instance_valid(org) or not org.alive:
            continue
        org.apply_environment(dt, habitat)
        if not org.alive:
            continue
        var nutrient_idx: int = nutrient_field.nearest_for(org, dt)
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
            if other.organism_id == org.pair_target_id:
                continue
            if distance < preferred:
                var push: float = (preferred - distance) / maxf(0.25, preferred)
                social -= direction * (0.95 + push * 2.2)
            elif distance < 16.0 and other.genome.family_id == org.genome.family_id:
                var pull: float = (16.0 - distance) / 16.0
                social += direction * pull * 0.34 * float(_setting("group_strength", 0.55)) * (0.35 + float(org.genome.pack_drive))
                if absf(float(other.social_rank) - float(org.social_rank)) > 0.30 and distance < 8.0:
                    var rank_push: float = float(_setting("hierarchy_strength", 0.35)) * 0.18
                    social += (-direction if org.social_rank < other.social_rank else direction) * rank_push
                    hierarchy_events += 1
            elif distance < 12.0 and (float(other.genome.cooperation) + float(org.genome.cooperation)) * 0.5 > 0.58:
                social += direction * 0.10 * float(_setting("group_strength", 0.55))

            if other.organism_id != org.pair_target_id and other.genome.family_id != org.genome.family_id and float(other.genome.predator_drive) > 0.50 and distance < 13.0:
                threat += direction * ((13.0 - distance) / 13.0)

        org.think_step(dt, nutrient_pos, social, threat, rng, evolution_rate)
        ecology.act(org, dt, rng)
        if nutrient_idx >= 0 and Cycle.stage(org) != "pupa" and org.global_position.distance_squared_to(nutrient_pos) < 1.65:
            org.absorb_nutrient(nutrient_field.consume(nutrient_idx) * (0.75 if org.rooted else 1.0))

    # Live frames already resolved motion. Decisions change velocities; they
    # do not move bodies. Explicit experiment/test stepping resolves here.
    if not contacts_ready: _resolve_contacts()
    predation_events = ecology.hunt_events
    _cleanup_dead()
    var population_before: int = organisms.size()
    _reproduction_pass(dt)
    if organisms.size() != population_before: _resolve_contacts()
    courtship_events = reproduction.mating_events
    _cleanup_dead()

func _reproduction_pass(dt: float) -> void:
    # Existing embryos continue developing when new reproduction is disabled.
    reproduction.step(self, dt, bool(_setting("auto_reproduce", true)))

func population_cap() -> int:
    return int(_setting("organism_cap", 28))

func mating_radius() -> float:
    return float(_setting("mating_radius", 18.0))

func mate_delay() -> float:
    return float(_setting("mate_cooldown", 16.0))

func courtship_strength() -> float:
    return float(_setting("courtship_strength", 0.75))

func sexual_attempt_rate() -> float:
    return float(_setting("crossover_rate", 0.90))

func mutation_strength() -> float:
    return float(_setting("mutation_strength", 0.14))

func macro_rate() -> float:
    return float(_setting("macro_mutation_rate", 0.014))

func viability_threshold() -> float:
    return float(_setting("viability_threshold", 0.18))

func _cleanup_dead() -> void:
    for i in range(organisms.size() - 1, -1, -1):
        var org = organisms[i]
        if not is_instance_valid(org) or not org.alive:
            var oid: int = -1
            if is_instance_valid(org):
                oid = int(org.organism_id)
                record_event("death", {"id": oid, "age": org.age_seconds, "energy": org.energy, "oxygen": org.oxygen, "offspring": org.children, "genetic_health": org.genome.genetic_health()})
                if float(org.development_stability) < float(_setting("viability_threshold", 0.18)):
                    failed_developments += 1
                    AppLog.info("development failed id=%d family=%d plan=%s viability=%.3f age=%.1f" % [org.organism_id, org.genome.family_id, org.body_plan_name(), org.development_stability, org.age_seconds])
            if selected == org:
                selected = null
            organisms.remove_at(i)
            if is_instance_valid(org):
                org.queue_free()
            organism_died.emit(oid)
            var minimum_population: int = maxi(6, int(int(_setting("initial_organisms", 16)) / 2))
            if bool(_setting("auto_reseed", false)) and organisms.size() < minimum_population:
                spawn_random()

func spawn_random(forced_plan: int = -1):
    if reproduction.available_slots(self) <= 0:
        return null
    var genome = GenomeScript.new()
    genome.randomize_from(rng, next_family, forced_plan)
    genome.aquatic_founder()
    next_family += 1
    var spawn = Vector3(rng.randf_range(-half_extent * 0.75, half_extent * 0.75), -half_extent * 0.15, rng.randf_range(-half_extent * 0.75, half_extent * 0.75))
    # Seed aquatic ancestors in accessible water rather than dry air or rock.
    spawn = habitat.nearest_medium(spawn, true, 1.0)
    var founder = spawn_genome(genome, spawn)
    if is_instance_valid(founder):
        founder.global_position = habitat.nearest_medium(founder.global_position, true, founder.body_clearance() + 0.5)
        founder.in_water = true
        record_event("founder_injection", {"id": founder.organism_id, "family": genome.family_id, "plan": genome.body_plan})
    return founder

func spawn_genome(genome, spawn: Vector3):
    if organisms.size() >= population_cap():
        return null
    var org = OrganismScript.new()
    add_child(org)
    org.initialize(next_id, genome, spawn, visual_cap, view_mode)
    org.contact_quality = contact_quality
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
        "parasitic_events": ecology.parasitic_events,
        "embryos": reproduction.reserved_count(),
        "conceptions": reproduction.conceptions,
        "brood_losses": reproduction.losses
    }

func _setting(key: String, fallback = null):
    return experiment_settings.get(key, SettingsStore.get_value(key, fallback))

func record_event(kind: String, details: Dictionary) -> void:
    event_sequence += 1
    event_log.append({"sequence": event_sequence, "step": sim_steps, "time": elapsed_sim_time, "kind": kind, "data": details})
    if event_log.size() > 2048: event_log.pop_front()

func advance_experiment(steps: int) -> void:
    var dt: float = 1.0 / 12.0
    for i in range(steps):
        for org in organisms:
            if is_instance_valid(org): org.motion_step(dt, half_extent)
        _simulation_tick(dt)

func reset_experiment(seed_value: int, parameters: Dictionary) -> void:
    for brood in reproduction.broods:
        brood["marker"].queue_free()
    for org in organisms:
        org.queue_free()
    organisms.clear()
    if is_instance_valid(nutrient_field): nutrient_field.queue_free()
    selected = null
    var resources: Array[Vector3] = ecology.resources.duplicate()
    reproduction = ReproductionScript.new()
    ecology = EcologyScript.new()
    next_id = 1
    next_family = 1
    sim_steps = 0
    sim_accumulator = 0.0
    elapsed_sim_time = 0.0
    failed_developments = 0
    crossover_births = 0
    mutation_births = 0
    predation_events = 0
    courtship_events = 0
    hierarchy_events = 0
    nutrient_input = 0.0
    event_log.clear()
    event_sequence = 0
    experiment_revision += 1
    experiment_settings = parameters.duplicate(true)
    temperature_offset = float(parameters.get("temperature_offset", 0.0))
    initialize(seed_value)
    ecology.configure(habitat, resources)
    record_event("reset", {"seed": seed_value, "parameters": parameters.duplicate(true)})

func _resolve_contacts() -> void:
    var started: int = Time.get_ticks_usec()
    var iterations: int = 2 + int(round(float(contact_quality) * 0.06))
    Contact.solve(organisms, iterations, contact_quality)
    for org in organisms:
        if is_instance_valid(org) and org.alive: Contact.ground(org, half_extent)
    perf_contact_usec += Time.get_ticks_usec() - started

func set_contact_quality(value: int) -> void:
    contact_quality = clampi(value, 0, 100)
    for org in organisms:
        if is_instance_valid(org): org.contact_quality = contact_quality

func take_performance() -> Dictionary:
    var frames: float = float(maxi(1, perf_frames))
    var report: Dictionary = {"motion_ms": perf_motion_usec / frames / 1000.0, "biology_ms": perf_biology_usec / frames / 1000.0, "contacts_ms": perf_contact_usec / frames / 1000.0, "peak_world_ms": perf_peak_usec / 1000.0, "ground_detail": 0, "ground_fast": 0, "ground_cached": 0, "envelopes": 0, "quality": contact_quality}
    report["render_uploads"] = 0
    report["skipped_uploads"] = 0
    for org in organisms:
        if not is_instance_valid(org) or not is_instance_valid(org.visual): continue
        var visual = org.visual
        report["ground_detail"] += visual.ground_detail_checks
        report["ground_fast"] += visual.ground_fast_checks
        report["ground_cached"] += visual.ground_cache_hits
        report["envelopes"] += visual.contact_builds
        report["render_uploads"] += visual.render_uploads
        report["skipped_uploads"] += visual.skipped_uploads
        visual.ground_detail_checks = 0
        visual.ground_fast_checks = 0
        visual.ground_cache_hits = 0
        visual.contact_builds = 0
        visual.render_uploads = 0
        visual.skipped_uploads = 0
    perf_frames = 0
    perf_motion_usec = 0
    perf_biology_usec = 0
    perf_contact_usec = 0
    perf_peak_usec = 0
    return report

func _update_render_visibility(delta: float) -> void:
    if not is_instance_valid(observer_camera): return
    var planes: Array = observer_camera.get_frustum()
    var screen_center: Vector2 = observer_camera.get_viewport().get_visible_rect().size * 0.5
    var inside: Vector3 = observer_camera.project_position(screen_center, (observer_camera.near + observer_camera.far) * 0.5)
    # Orient towards the exterior explicitly, independent of plane ordering.
    for i in range(planes.size()):
        if planes[i].distance_to(inside) > 0.0: planes[i] = -planes[i]
    for org in organisms:
        if not is_instance_valid(org) or not is_instance_valid(org.visual): continue
        var radius: float = org.visual.contact_radius + org.velocity.length() * delta * 3.0 + 1.0
        org.visual.set_render_active(sphere_visible(org.global_position, radius, planes))

static func sphere_visible(center: Vector3, radius: float, planes: Array) -> bool:
    for plane in planes:
        if plane.distance_to(center) > radius: return false
    return true
