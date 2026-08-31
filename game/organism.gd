extends Node3D

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
    desired_velocity = Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, float(genome.seed % 628) / 100.0)
    velocity = desired_velocity * (1.2 + genome.metabolism)
    visual = OrganismVisualScript.new()
    add_child(visual)
    visual.configure(self, visual_cap, view_mode)

func think_step(dt: float, nutrient_pos: Vector3, social_vector: Vector3, threat_vector: Vector3, rng: RandomNumberGenerator, evolution_rate: float) -> void:
    if not alive:
        return
    age_seconds += dt
    hunger = clampf(1.0 - energy, 0.0, 1.0)
    curiosity_state = clampf(0.25 + genome.curiosity * 0.65 + sin(age_seconds * 0.17 + float(organism_id)) * 0.10, 0.0, 1.0)
    social_state = clampf(genome.cooperation * (0.55 + energy * 0.45), 0.0, 1.0)
    fear = lerpf(fear, clampf(threat_vector.length() * 0.12, 0.0, 1.0), 0.12)

    var food_dir = (nutrient_pos - global_position).normalized()
    var wander = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.7, 0.7), rng.randf_range(-1.0, 1.0)).normalized()
    var steer = food_dir * (0.35 + hunger * 1.45)
    steer += social_vector * genome.cooperation * 0.58
    steer -= threat_vector * genome.aggression * 0.34
    steer += wander * (0.16 + genome.curiosity * 0.30)
    steer.y += (genome.buoyancy - 0.5) * 0.20
    if steer.length_squared() < 0.001:
        steer = -global_transform.basis.z
    desired_velocity = steer.normalized() * (1.25 + genome.metabolism * 2.1 + minf(2.5, log(1.0 + complexity) * 0.20))
    velocity = velocity.lerp(desired_velocity, clampf(dt * (0.8 + genome.neural_drive), 0.0, 1.0))

    var metabolic_cost: float = dt * (0.0018 + float(genome.metabolism) * 0.0020 + velocity.length() * 0.00042)
    energy = maxf(0.0, energy - metabolic_cost)
    experience += dt * (0.035 + curiosity_state * 0.022 + social_state * 0.012)

    # Open-ended state: no semantic maximum. Visual cost stays bounded separately.
    var survival_factor: float = 0.45 + energy * 0.75 + float(genome.curiosity) * 0.18
    complexity += dt * evolution_rate * survival_factor * (0.14 + log(1.0 + age_seconds) * 0.018)
    intelligence += dt * evolution_rate * (0.0007 + genome.neural_drive * 0.00135 + genome.sensory_drive * 0.00055 + experience * 0.0000025)
    intelligence = maxf(0.0, intelligence)
    language_stage = _language_stage()
    if energy <= 0.0001:
        alive = false
        _remember("energy collapse")

func motion_step(delta: float, world_half_extent: float) -> void:
    if not alive:
        return
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
    global_position = p
    if velocity.length_squared() > 0.01:
        var target = global_position + velocity.normalized()
        look_at(target, Vector3.UP)
    if bounced:
        fear = minf(1.0, fear + 0.08)
    _body_timer += delta
    if _body_timer >= float(_setting("body_rebuild_interval", 1.0)):
        _body_timer = 0.0
        visual.maybe_rebuild()

func absorb_nutrient(value: float) -> void:
    energy = minf(1.45, energy + value)
    experience += value * 4.0
    _remember("fed")

func can_reproduce() -> bool:
    return alive and age_seconds > 18.0 and energy > 1.02 and genome.reproduction > 0.28

func reproduction_probability(dt: float) -> float:
    return dt * (0.0012 + genome.reproduction * 0.0045) * clampf(energy - 0.86, 0.0, 0.7)

func parent_cost() -> void:
    energy *= 0.63
    children += 1
    _remember("offspring %d" % children)

func evolutionary_score() -> float:
    return log(1.0 + age_seconds) * 0.22 + log(1.0 + complexity) * 0.38 + intelligence * 0.60 + children * 0.12 + energy * 0.20

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
