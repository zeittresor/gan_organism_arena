extends Node3D

const Traits = preload("res://game/ecology_traits.gd")

const OrganismVisualScript = preload("res://game/organism_visual.gd")

var organism_id = 0
var genome = null
var visual = null
var energy = 0.72
var age_seconds = 0.0
var complexity = 0.0
var intelligence = 0.0
var experience = 0.0
var children = 0
var velocity = Vector3.ZERO
var desired_velocity = Vector3.ZERO
var hunger = 0.0
var fear = 0.0
var curiosity_state = 0.5
var social_state = 0.5
var language_stage = 0
var last_thought = ""
var thought_counter = 0
var alive = true
var selected = false
var family_name = ""
var event_history: Array[String] = []
var _body_timer = 0.0
var development_stability = 1.0
var mate_cooldown = 0.0
var wander_direction = Vector3(0.0, 0.0, -1.0)
var wander_timer = 0.0
var senescence = 0.0
var behavior_state: String = "forage"
var social_rank: float = 0.5
var pair_target_id: int = -1
var habitat_stress: float = 0.0

var habitat = null
var oxygen: float = 1.0
var ambient_temperature: float = 22.0
var moisture: float = 1.0
var stamina: float = 1.0
var flight_skill: float = 0.0
var tool_skill: float = 0.0
var hunting_skill: float = 0.0
var tool_durability: float = 0.0
var parasite_load: float = 0.0
var surface_food: float = 0.12
var in_water: bool = true
var grounded: bool = false
var rooted: bool = false
var airborne: bool = false
var hiding: bool = false
var can_fly: bool = false
var stand_upright: bool = false
var medium_timer: float = 0.0
var decision_timer: float = 0.0
var refuge = Vector3.ZERO
var prey_id: int = -1
var pack_leader_id: int = -1
var hunt_tactic: String = "pursuit"
var ambush_point = Vector3.ZERO
var ambush_timer: float = 0.0
var tactic_scores: Dictionary = {"pursuit": 0.0, "ambush": 0.0, "flank": 0.0}
var last_medium: bool = true
var medium_changes: int = 0
var tool_uses: int = 0
var feeding_events: int = 0


func _setting(key: String, fallback):
    # Keep the organism core usable in deterministic/headless tests as well as
    # the normal project. In the real game SettingsStore is an autoload; tests
    # fall back cleanly if that singleton is intentionally absent.
    var store = get_node_or_null("/root/SettingsStore")
    if store != null and store.has_method("get_value"):
        return store.get_value(key, fallback)
    return fallback

func initialize(p_id: int, p_genome, spawn: Vector3, visual_cap: int, view_mode: String) -> void:
    organism_id = p_id
    genome = p_genome
    position = spawn
    family_name = "F%03d" % genome.family_id
    energy = 0.58 + genome.metabolism * 0.28
    complexity = maxf(0.5, float(genome.generation) * 0.35)
    intelligence = 0.05 + genome.neural_drive * 0.08
    development_stability = float(genome.viability_score()) if genome.has_method("viability_score") else 1.0
    social_rank = clampf(float(genome.dominance_drive) * 0.65 + float(genome.aggression) * 0.20 + development_stability * 0.15, 0.0, 1.0)
    desired_velocity = Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, float(genome.seed % 628) / 100.0)
    wander_direction = desired_velocity.normalized()
    velocity = desired_velocity * (1.2 + genome.metabolism)
    if development_stability < float(_setting("viability_threshold", 0.18)):
        energy *= lerpf(0.12, 0.52, development_stability)
        _remember("unstable development")
    visual = OrganismVisualScript.new()
    add_child(visual)
    visual.configure(self, visual_cap, view_mode)

func think_step(dt: float, nutrient_pos: Vector3, social_vector: Vector3, threat_vector: Vector3, rng: RandomNumberGenerator, evolution_rate: float) -> void:
    if not alive:
        return
    age_seconds += dt
    mate_cooldown = maxf(0.0, mate_cooldown - dt)
    hunger = clampf(1.0 - energy, 0.0, 1.0)
    curiosity_state = clampf(0.25 + genome.curiosity * 0.65 + sin(age_seconds * 0.17 + float(organism_id)) * 0.10, 0.0, 1.0)
    social_state = clampf(genome.cooperation * (0.55 + energy * 0.45), 0.0, 1.0)
    fear = lerpf(fear, clampf(threat_vector.length() * 0.12, 0.0, 1.0), 0.08)
    if threat_vector.length() > 0.8:
        behavior_state = "flee"
    elif social_vector.length() > 0.75 and genome.cooperation > 0.55:
        behavior_state = "social"
    elif hunger > 0.55:
        behavior_state = "forage"
    else:
        behavior_state = "explore"

    # Persistent wander avoids the rapid left-right steering noise of alpha6.
    wander_timer -= dt
    if wander_timer <= 0.0:
        wander_timer = rng.randf_range(1.4, 4.6)
        var candidate = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.65, 0.65), rng.randf_range(-1.0, 1.0))
        if candidate.length_squared() > 0.001:
            wander_direction = candidate.normalized()

    var food_delta: Vector3 = nutrient_pos - global_position
    var food_dir: Vector3 = food_delta.normalized() if food_delta.length_squared() > 0.001 else Vector3.ZERO
    var steer = food_dir * (0.30 + hunger * 1.35)
    steer += social_vector * genome.cooperation * 0.42
    steer -= threat_vector * (0.28 + genome.aggression * 0.34)
    steer += wander_direction * (0.14 + genome.curiosity * 0.24)
    steer.y += (genome.buoyancy - 0.5) * 0.18
    if steer.length_squared() < 0.001:
        steer = -global_transform.basis.z

    var morphology_drag: float = 0.82 + float(genome.flattening) * 0.12 + float(genome.armor_drive) * 0.10
    var target_speed: float = Traits.swim_speed(genome) if in_water else (0.6 + Traits.walking(genome) * 3.0)
    if airborne:
        target_speed = 2.0 + Traits.lift(genome) * 5.0
    target_speed *= (0.40 + stamina * 0.60) / morphology_drag
    if rooted:
        target_speed = 0.0
    desired_velocity = steer.normalized() * target_speed
    var steering_response: float = 0.28 + genome.neural_drive * 0.42
    velocity = velocity.lerp(desired_velocity, clampf(dt * steering_response, 0.0, 0.22))

    var morphology_cost: float = 0.00020 * (float(genome.armor_drive) + float(genome.shell_drive))
    morphology_cost += 0.00016 * float(genome.limb_drive) * float(genome.limb_length)
    var instability_cost: float = pow(maxf(0.0, 1.0 - development_stability), 2.0) * 0.010
    var senescence_start: float = 150.0 + float(genome.longevity) * 540.0 + float(genome.support_drive) * 90.0
    senescence = maxf(0.0, (age_seconds - senescence_start) / maxf(60.0, senescence_start))
    var senescence_cost: float = senescence * senescence * 0.0045
    var metabolic_cost: float = dt * (0.0018 + float(genome.metabolism) * 0.0020 + velocity.length() * 0.00042 + morphology_cost + instability_cost + senescence_cost)
    metabolic_cost *= 0.45 + float(genome.size_gene) * float(genome.size_gene) * 1.30
    if rooted:
        metabolic_cost *= 0.30
    energy = maxf(0.0, energy - metabolic_cost - dt * Traits.maintenance(genome) * (0.4 if rooted else 1.0))
    experience += dt * (0.035 + curiosity_state * 0.022 + social_state * 0.012)

    # Open-ended state: no semantic maximum. Visual cost stays bounded separately.
    var survival_factor: float = (0.32 + energy * 0.70 + float(genome.curiosity) * 0.16) * lerpf(0.25, 1.0, development_stability)
    complexity += dt * evolution_rate * survival_factor * (0.14 + log(1.0 + age_seconds) * 0.018)
    intelligence += dt * evolution_rate * (0.0007 + genome.neural_drive * 0.00135 + genome.sensory_drive * 0.00055 + experience * 0.0000025) * lerpf(0.30, 1.0, development_stability)
    intelligence = maxf(0.0, intelligence)
    language_stage = _language_stage()
    if energy <= 0.0001:
        alive = false
        _remember("energy collapse")

func motion_step(delta: float, world_half_extent: float) -> void:
    if not alive:
        return
    if rooted:
        velocity = Vector3.ZERO
    global_position += velocity * delta
    var p = global_position
    var bounced = false
    if absf(p.x) > world_half_extent:
        p.x = clampf(p.x, -world_half_extent, world_half_extent)
        velocity.x *= -0.82
        bounced = true
    if absf(p.y) > world_half_extent * 0.60:
        p.y = clampf(p.y, -world_half_extent * 0.60, world_half_extent * 0.60)
        velocity.y *= -0.82
        bounced = true
    if absf(p.z) > world_half_extent:
        p.z = clampf(p.z, -world_half_extent, world_half_extent)
        velocity.z *= -0.82
        bounced = true
    if habitat != null:
        var clearance: float = body_clearance()
        var floor_y: float = habitat.floor_at(p) + clearance
        if p.y < floor_y or rooted:
            p.y = floor_y
            velocity.y = maxf(0.0, velocity.y) if not rooted else 0.0
        if habitat.level == 5:
            p.y = minf(p.y, habitat.waterline - 0.10)
    global_position = p
    if rooted:
        rotation = Vector3.ZERO
    elif velocity.length_squared() > 0.01:
        var facing: Vector3 = velocity.normalized()
        if grounded and not in_water:
            facing.y = 0.0
        if facing.length_squared() > 0.001 and absf(facing.normalized().dot(Vector3.UP)) < 0.98:
            look_at(global_position + facing, Vector3.UP)
    if is_instance_valid(visual):
        visual.animate_life(delta)
    if bounced:
        fear = minf(1.0, fear + 0.08)
    _body_timer += delta
    if _body_timer >= float(_setting("body_rebuild_interval", 1.0)):
        _body_timer = 0.0
        visual.maybe_rebuild()


func body_clearance() -> float:
    if rooted:
        return 0.12
    if is_instance_valid(visual):
        return maxf(0.25, -float(visual.lowest_point) + 0.12)
    return 0.65

func apply_environment(dt: float, model) -> void:
    habitat = model
    in_water = model.is_water(global_position)
    var floor_y: float = model.floor_at(global_position)
    grounded = global_position.y <= floor_y + body_clearance() + 0.35
    medium_timer += dt
    if last_medium != in_water:
        medium_changes += 1
        medium_timer = 0.0
        last_medium = in_water
    if Traits.sessile(genome) and age_seconds > 12.0 and grounded:
        rooted = true
    stand_upright = not in_water and not rooted and Traits.upright(genome) and age_seconds > 20.0
    can_fly = not rooted and model.has_sky() and Traits.flight_body(genome) and age_seconds > 18.0
    if can_fly and not in_water and energy > 0.35:
        flight_skill = minf(1.0, flight_skill + dt * 0.020 * (0.4 + genome.neural_drive))
    airborne = can_fly and flight_skill > 0.22 and not in_water and stamina > 0.18 and energy > 0.25
    var efficiency: float = Traits.water_breathing(genome) if in_water else Traits.air_breathing(genome)
    var exertion: float = 0.06 if rooted else 0.12 + velocity.length() * 0.012
    var reserve: float = 4.0 + float(genome.breath_storage) * 24.0
    if efficiency >= 0.42:
        oxygen = minf(1.0, oxygen + dt * efficiency * 0.22)
    else:
        oxygen = maxf(0.0, oxygen - dt * (1.0 - efficiency / 0.42) / reserve)
    if in_water:
        moisture = minf(1.0, moisture + dt * 0.10)
    else:
        moisture = maxf(0.0, moisture - dt * float(genome.moisture_need) * 0.007 * (1.0 if rooted else Traits.water_loss(genome)))
    ambient_temperature = model.temperature_at(global_position)
    if not rooted:
        energy = maxf(0.0, energy - dt * (Traits.covering_cost(genome) + Traits.thermal_cost(genome, in_water, ambient_temperature)))
    var drying: float = maxf(0.0, 0.30 - moisture) * float(genome.skin_breathing)
    habitat_stress = clampf((1.0 - oxygen) * 0.80 + drying, 0.0, 1.0)
    energy = maxf(0.0, energy - dt * (maxf(0.0, 0.20 - oxygen) * 0.16 + drying * 0.025 + parasite_load * 0.003))
    stamina = clampf(stamina + dt * (0.07 - exertion * (0.90 if airborne else 0.25)), 0.0, 1.0)
    if not in_water and not grounded and not airborne:
        velocity.y -= dt * 4.5
    if rooted:
        velocity = Vector3.ZERO
    elif airborne:
        var cruise: float = maxf(floor_y + body_clearance() + 3.0, model.waterline + 3.5)
        cruise = minf(cruise, model.half_extent * 0.55)
        velocity.y = lerpf(velocity.y, clampf(cruise - global_position.y, -2.0, 2.0), minf(1.0, dt * 2.0))
    elif grounded and not in_water:
        velocity.y = maxf(0.0, velocity.y)
    if energy <= 0.0001:
        alive = false
        _remember("respiration or energy collapse")

# Compatibility entry point for previous self-tests.
func apply_habitat(dt: float, habitat_level: int, waterline: float, ground_y: float, world_half_extent: float) -> void:
    var model = preload("res://game/habitat_model.gd").new()
    model.configure(habitat_level, world_half_extent * 2.0)
    model.waterline = waterline
    model.ground_y = ground_y
    apply_environment(dt, model)

func steer_towards(target: Vector3, weight: float = 1.0, speed_multiplier: float = 1.0) -> void:
    if rooted:
        return
    var direction: Vector3 = target - global_position
    if grounded and not in_water and not airborne:
        direction.y = 0.0
    if direction.length_squared() < 0.01:
        velocity *= 0.8
        return
    var speed: float = Traits.swim_speed(genome) if in_water else (0.6 + Traits.walking(genome) * 3.0)
    if airborne:
        speed = 2.0 + Traits.lift(genome) * 5.0
    var steering: Vector3 = direction.normalized() * speed * speed_multiplier * (0.4 + stamina * 0.6)
    velocity = velocity.lerp(steering, clampf(weight, 0.0, 1.0))

func ecology_labels() -> Array[String]:
    var labels: Array[String] = []
    if rooted:
        labels.append("tree" if not in_water and genome.wood_drive > 0.60 and genome.support_drive > 0.55 else "sessile")
    if Traits.amphibious(genome): labels.append("amphibious")
    if Traits.swim_speed(genome) > 3.0: labels.append("fast_swimmer")
    if can_fly: labels.append("flight" if flight_skill > 0.22 else "flight_practice")
    if stand_upright: labels.append("upright")
    if genome.size_gene < 0.28 and genome.limb_drive > 0.55 and genome.armor_drive > 0.45: labels.append("insectoid")
    if Traits.tools(genome) and age_seconds > 25.0: labels.append("tool_user")
    if genome.pack_drive * genome.cooperation > 0.34 and genome.predator_drive > 0.45: labels.append("pack_hunter")
    if genome.cleaning_drive > 0.66: labels.append("cleaner")
    if genome.parasite_drive > 0.72: labels.append("parasite")
    if genome.shyness > 0.62: labels.append("shy")
    if not rooted:
        if genome.skin_thickness > 0.30: labels.append("skin")
        if genome.feather_cover > 0.45: labels.append("feathers")
        if genome.scale_cover > 0.48: labels.append("scales")
        if genome.fur_cover > 0.50: labels.append("fur")
        if genome.mucus_cover > 0.55: labels.append("mucus")
        if genome.membrane_cover > 0.55: labels.append("membranes")
        if genome.horn_drive > 0.55 and genome.support_drive > 0.35: labels.append("horns")
        if genome.beak_drive > 0.55: labels.append("beak")
    if labels.is_empty(): labels.append("generalist")
    return labels

func receive_predation(amount: float, attacker_id: int) -> float:
    if not alive:
        return 0.0
    var protection: float = 0.20 + float(genome.armor_drive) * 0.36 + float(genome.shell_drive) * 0.36 + development_stability * 0.12
    protection += Traits.covering_protection(genome) if not rooted else float(genome.wood_drive) * 0.10
    var loss: float = maxf(0.0, amount * (1.0 - clampf(protection, 0.0, 0.88)))
    energy = maxf(0.0, energy - loss)
    fear = minf(1.0, fear + 0.45)
    if fear < 0.75:
        _remember("attacked by %d" % attacker_id)
    if energy <= 0.0001:
        alive = false
    return loss

func absorb_nutrient(value: float) -> void:
    energy = minf(1.45, energy + value)
    experience += value * 4.0
    feeding_events += 1
    _remember("fed")

func can_reproduce() -> bool:
    var threshold: float = float(_setting("viability_threshold", 0.18))
    return alive and mate_cooldown <= 0.0 and age_seconds > 18.0 and energy > 1.02 and genome.reproduction > 0.28 and development_stability >= threshold

func reproduction_probability(dt: float) -> float:
    return dt * (0.008 + genome.reproduction * 0.035) * clampf(energy - 0.86, 0.0, 0.7)

func parent_cost() -> void:
    energy *= 0.68
    children += 1
    mate_cooldown = float(_setting("mate_cooldown", 24.0))
    _remember("offspring %d" % children)

func body_plan_name() -> String:
    if genome != null and genome.has_method("body_plan_name"):
        return str(genome.body_plan_name())
    return "unknown"

func follow_camera_data() -> Dictionary:
    var rear: Vector3 = global_position + global_transform.basis.z * 1.5
    var focus: Vector3 = global_position - global_transform.basis.z * 0.8
    var size_hint: float = 2.0
    if is_instance_valid(visual):
        if visual.has_method("get_rear_anchor_local"):
            rear = visual.to_global(visual.get_rear_anchor_local())
        if visual.has_method("get_focus_anchor_local"):
            focus = visual.to_global(visual.get_focus_anchor_local())
        if visual.has_method("get_body_size_hint"):
            size_hint = float(visual.get_body_size_hint())
    return {
        "rear": rear,
        "focus": focus,
        "size": size_hint,
        "forward": (-global_transform.basis.z).normalized()
    }

func evolutionary_score() -> float:
    return energy + oxygen * 0.2 - senescence * 0.2

func _language_stage() -> int:
    var language_signal: float = intelligence + log(1.0 + complexity) * 0.10 + float(genome.vocal_drive) * 0.32 + float(genome.generation) * 0.008
    if language_signal < 0.32:
        return 0
    if language_signal < 0.62:
        return 1
    if language_signal < 1.02:
        return 2
    if language_signal < 1.55:
        return 3
    if language_signal < 2.30:
        return 4
    return 5 + int(floor((language_signal - 2.30) / 0.65))

func generate_thought(rng: RandomNumberGenerator) -> String:
    thought_counter += 1
    var state = _dominant_state()
    var options: Array = []
    match language_stage:
        0:
            options = _proto_sounds(state)
        1:
            options = _syllables(state)
        2:
            options = _tokens(state)
        3:
            options = _phrases(state)
        4:
            options = _sentences(state)
        _:
            options = _advanced_sentences(state)
    if options.is_empty():
        options = ["..."]
    var index = abs((thought_counter * 7 + organism_id * 13 + rng.randi()) % options.size())
    last_thought = options[index]
    return last_thought

func _dominant_state() -> String:
    if energy < 0.32:
        return "hunger"
    if fear > 0.55:
        return "fear"
    if float(genome.aggression) > 0.72 and energy > 0.50:
        return "hunt"
    if social_state > 0.58:
        return "social"
    if curiosity_state > 0.65:
        return "curious"
    if energy > 1.10:
        return "reproduce"
    return "observe"

func _proto_sounds(state: String) -> Array:
    var map = {
        "hunger": ["mm...", "uu-uu", "mrr"],
        "fear": ["tik!", "krr!", "ii!"],
        "hunt": ["rrr", "tak", "khh"],
        "social": ["laa", "woo", "lu-lu"],
        "curious": ["oo?", "tik-oo", "hm?"],
        "reproduce": ["la-la", "woo-aa", "rru"],
        "observe": ["hum", "oo", "...ah"]
    }
    return map.get(state, ["hum"])

func _syllables(state: String) -> Array:
    var map = {
        "hunger": ["na-ma", "food-aa", "mm-na"],
        "fear": ["ka-danger", "go-go", "no-ka"],
        "hunt": ["seek-ra", "move-ka", "prey-ta"],
        "social": ["kin-la", "near-us", "come-la"],
        "curious": ["what-oo", "new-ka", "see-na"],
        "reproduce": ["new-kin", "make-la", "grow-us"],
        "observe": ["see", "move", "here"]
    }
    return map.get(state, ["see"])

func _tokens(state: String) -> Array:
    var map = {
        "hunger": ["ENERGY LOW", "FOOD NEAR?", "SEEK FOOD"],
        "fear": ["DANGER NEAR", "MOVE AWAY", "HIDE / TURN"],
        "hunt": ["TRACK PREY", "CLOSE DISTANCE", "CLAIM SPACE"],
        "social": ["KIN NEAR", "FOLLOW FAMILY", "SHARE SPACE"],
        "curious": ["NEW SIGNAL", "INSPECT LIGHT", "UNKNOWN FORM"],
        "reproduce": ["ENERGY HIGH / DIVIDE", "MAKE OFFSPRING", "PASS PATTERN"],
        "observe": ["DRIFT / WATCH", "STABLE WATER", "SCAN AROUND"]
    }
    return map.get(state, ["SCAN"])

func _phrases(state: String) -> Array:
    var map = {
        "hunger": ["Need energy nearby.", "Search where the nutrient field is dense.", "I should feed before moving farther."],
        "fear": ["Something nearby feels dangerous.", "Turn away from that motion.", "Keep distance and preserve energy."],
        "hunt": ["That weaker signal may be useful.", "Approach carefully, then take the resource.", "I can dominate this patch."],
        "social": ["My kin are close.", "Stay near the familiar signals.", "Moving together may be safer."],
        "curious": ["There is a pattern I have not sampled.", "I want to inspect the unfamiliar motion.", "The water changes in that direction."],
        "reproduce": ["I have enough energy to divide.", "A descendant could survive here.", "This body pattern may be worth passing on."],
        "observe": ["The currents are quiet here.", "I will keep scanning while I drift.", "Nothing urgent is changing nearby."]
    }
    return map.get(state, ["I observe."])

func _sentences(state: String) -> Array:
    var base = _phrases(state)
    base.append("I remember %s, and that changes what I do next." % _memory_fragment())
    base.append("My body has reached complexity %.1f while my cognition is %.2f." % [complexity, intelligence])
    return base

func _advanced_sentences(state: String) -> Array:
    var base = _sentences(state)
    base.append("I compare the present with earlier events: %s. The difference matters." % _memory_fragment())
    base.append("I can separate hunger, danger, kin and novelty; right now '%s' dominates my decision." % state)
    base.append("My descendants do not need to resemble me exactly; variation may solve this environment differently.")
    if language_stage >= 6:
        base.append("I notice that my own signals are becoming compositional: I can combine an object, a direction and an intention instead of making a single call.")
    if language_stage >= 7:
        base.append("I am beginning to model what another organism may sense, not only what I sense myself; cooperation and deception are becoming distinct possibilities.")
    # Higher stages do not map to one fixed sentence table. They compose more clauses
    # from current state, memory and lineage so long runs keep producing new forms.
    var clauses: Array[String] = [
        "my energy is %.2f" % energy,
        "my body complexity is %.1f" % complexity,
        "my current motive is %s" % state,
        "my latest memory is %s" % _memory_fragment(),
        "I have produced %d descendants" % children,
        "I belong to %s generation %d" % [family_name, genome.generation],
        "my curiosity is %.2f" % curiosity_state,
        "my social drive is %.2f" % social_state
    ]
    var clause_count = clampi(2 + int((language_stage - 5) / 2), 2, 6)
    var start = abs((thought_counter * 3 + organism_id) % clauses.size())
    var composed = "I integrate several observations: "
    for i in range(clause_count):
        if i > 0:
            composed += ", and " if i == clause_count - 1 else "; "
        composed += clauses[(start + i) % clauses.size()]
    composed += "."
    base.append(composed)
    return base

func _memory_fragment() -> String:
    if event_history.is_empty():
        return "no strong event yet"
    return event_history[event_history.size() - 1]

func _remember(event: String) -> void:
    event_history.append(event)
    var cap = int(_setting("max_history_events", 32))
    while event_history.size() > cap:
        event_history.pop_front()
