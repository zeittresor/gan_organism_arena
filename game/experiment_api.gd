extends RefCounted

const CellCycle = preload("res://game/cell_cycle.gd")
const Cycle = preload("res://game/life_cycle.gd")
const MODEL_VERSION: String = "arena-biology-6"
const PARAM_LIMITS: Dictionary = {"gravity_scale": [0.2, 2.5], "mutation_strength": [0.0, 0.5], "macro_mutation_rate": [0.0, 0.2], "nutrient_renewal": [0.0, 4.0], "temperature_offset": [-12.0, 12.0], "predation_strength": [0.0, 1.0], "group_strength": [0.0, 1.0], "initial_organisms": [2.0, 60.0], "organism_cap": [2.0, 80.0], "nutrient_count": [16.0, 1000.0]}
var world = null

func configure(p_world) -> void:
    world = p_world

func model_description() -> Dictionary:
    return {"schema": "arena.observation/1", "model": MODEL_VERSION, "version": "1.0.0-alpha22", "step_seconds": 1.0 / 12.0,
        "units": {"time": "simulation seconds; no real species timescale", "energy": "dimensionless reserve units", "position": "world units", "temperature": "model Celsius"},
        "mechanisms": ["persistent exploration and foraging goals with progress-based replanning", "head-local nutrient capture and stage-aware food sensing", "compatible-partner approach before courtship","ploidy-preserving mitotic tissue growth and repair", "reciprocal meiotic tetrads and haploid gamete pools", "facultative clonal/sexual reproduction", "articulated body contacts", "passive vertical joint conformance and fractional-volume buoyancy", "adjustable model gravity", "load-sensitive support pitch and trailing-joint swimming response", "diploid loci", "linked segregation and recombination", "partial dominance", "recessive genetic load", "paid juvenile development", "finite gamete reserves", "embryo energy and temperature dependence", "predation", "finite food particles with measured external renewal"],
        "assumptions": ["Fictional genotype-to-body map and coefficients; not species-calibrated", "Gravity baseline is 9.8 world units/s^2; overlapping structural ellipsoids approximate displaced volume, without fluid dynamics or tissue stress simulation", "Basic animal developmental phases are abstractions, not cell simulation", "Resource renewal, light and ecological food production are external inputs; no closed carbon/nitrogen cycle", "Cognitive/complexity scores are model variables, not validated intelligence measures", "Deterministic stepping applies within this engine/build and configuration; cross-platform floating-point equivalence not promised"],
        "parameters": PARAM_LIMITS, "actions": ["observe", "organism", "events", "step", "reset", "parameters", "describe", "mode", "capture"]}

func observation() -> Dictionary:
    var items: Array = []
    for org in world.organisms:
        if is_instance_valid(org) and org.alive: items.append(organism_data(org, false))
    var broods: Array = []
    for brood in world.reproduction.broods:
        broods.append({"mother": brood["a"], "father": brood["b"], "route": brood["route"], "embryos": brood["genomes"].size(), "age": brood["age"], "stage": brood["stage"], "development": brood["development"], "energy": brood["energy"], "health": brood["health"]})
    return {"schema": "arena.observation/1", "model": MODEL_VERSION, "seed": world.run_seed, "revision": world.experiment_revision, "step": world.sim_steps, "time": world.elapsed_sim_time, "controlled": world.experiment_mode,
        "parameters": effective_parameters(), "configuration": world.experiment_settings.duplicate(true), "habitat": {"level": world.habitat.level, "size": world.half_extent * 2.0, "waterline": world.waterline},
        "organisms": items, "broods": broods, "births": world.reproduction.births, "conceptions": world.reproduction.conceptions, "brood_losses": world.reproduction.losses,
        "nutrient_energy": world.nutrient_field.stored_energy(), "external_nutrient_input": world.nutrient_input, "event_cursor": world.event_sequence}

func effective_parameters() -> Dictionary:
    var result: Dictionary = {}
    for key in PARAM_LIMITS:
        result[key] = world._setting(key, 1.0 if key in ["nutrient_renewal", "gravity_scale"] else 0.0)
    result["contact_quality"] = world.contact_quality
    result["auto_reproduce"] = world._setting("auto_reproduce", true)
    result["auto_reseed"] = world._setting("auto_reseed", false)
    return result

func organism_data(org, include_genome: bool) -> Dictionary:
    var p: Vector3 = org.global_position
    var item: Dictionary = {"id": org.organism_id, "parents": [org.parent_a, org.parent_b], "family": org.genome.family_id, "generation": org.genome.generation,
        "position": [p.x, p.y, p.z], "age": org.age_seconds, "stage": Cycle.stage(org), "development": org.development_progress, "energy": org.energy, "oxygen": org.oxygen,
        "temperature": org.ambient_temperature, "egg_reserve": org.egg_reserve, "sperm_reserve": org.sperm_reserve, "bud_reserve": org.bud_reserve, "growth_investment": org.growth_investment,
        "gamete_investment": org.gamete_investment, "sex_role": Cycle.sex_role(org.genome), "reproduction": org.reproduction_state, "offspring": org.children,
        "behavior": org.behavior_state, "genetic_health": org.genome.genetic_health(), "heterozygosity": org.genome.heterozygosity(), "in_water": org.in_water, "airborne": org.airborne}
    item["navigation"] = {"goal": org.navigation_goal, "target": [org.navigation_target.x, org.navigation_target.y, org.navigation_target.z], "speed": org.velocity.length(), "food_target": org.food_target_index, "mate_interest": org.mate_interest_id, "feeding_events": org.feeding_events, "replans": org.navigation_replans}
    item["affect"] = {"capacity": org.Affect.capacity(org), "state": org.emotion, "valence": org.affect_valence, "arousal": org.affect_arousal, "attachment": org.affect_bond, "subjective_consciousness_claim": false}
    item["anatomy"] = org.visual.anatomy_counts.duplicate()
    item["support"] = {"submerged_fraction": org.submerged_fraction, "near_ground": org.support_near_ground, "terrain_pitch_radians": org.support_pitch, "gravity_scale": org.Support.gravity_scale(org)}
    item["locomotion"] = {"yaw": org.heading_yaw, "pitch": org.heading_pitch, "yaw_rate": org.turn_yaw_speed, "pitch_rate": org.turn_pitch_speed}
    item["cell_cycle"] = {"somatic_ploidy": 2, "gamete_ploidy": 1, "strategy": CellCycle.strategy(org.genome), "somatic_cells": org.somatic_cells, "mitotic_divisions": org.mitotic_divisions, "meioses": org.meiosis_cycles, "polar_bodies": org.polar_bodies, "tissue_damage": org.tissue_damage, "repair_investment": org.repair_investment, "ready_eggs": org.egg_genomes.size(), "ready_sperm": org.sperm_genomes.size()}
    if include_genome:
        var joints: Array = []
        for i in range(org.visual.body_cells.size()):
            var cell: Dictionary = org.visual.body_cells[i]
            if not cell["joint"]: continue
            var axis: Vector3 = cell["joint_axis"]
            joints.append({"cell": i, "parent": cell["parent"], "mode": cell["joint_mode"], "axis": [axis.x, axis.y, axis.z], "limit_radians": cell["joint_limit"], "angle_radians": cell["joint_angle"], "vertical_limit_radians": cell["vertical_limit"], "vertical_angle_radians": cell["vertical_angle"], "muscle": cell["joint_muscle"]})
        item["joints"] = joints
        item["dna"] = org.genome.dna_document()
        item["gametes"] = {"eggs": org.egg_genomes.duplicate(true), "sperm": org.sperm_genomes.duplicate(true)}
        var phenotype: Dictionary = {}
        for locus in org.genome._continuous_gene_names(): phenotype[locus] = org.genome.get(locus)
        item["genome"] = {"alleles": org.genome.alleles.duplicate(true), "expression": phenotype, "recessive_load": org.genome.recessive_load.duplicate(true), "sex_chromosomes": org.genome.sex_chromosomes.duplicate(), "plan": org.genome.body_plan, "mutations": org.genome.mutation_events, "crossovers": org.genome.crossover_events}
    return item

func execute(action: String, arguments: Dictionary) -> Dictionary:
    if action == "describe": return model_description()
    if action == "capture":
        var genomes: Array = []
        for org in world.organisms:
            if is_instance_valid(org) and org.alive: genomes.append(organism_data(org, true))
        return {"model": model_description(), "observation": observation(), "genomes": genomes}
    if action == "mode":
        var mode = arguments.get("mode", "")
        if not mode is String or mode not in ["live", "stepped"]: return {"error": "mode must be live or stepped"}
        world.experiment_mode = mode == "stepped"
        world.sim_accumulator = 0.0
        world.record_event("mode", {"mode": mode, "source": "api"})
        return observation()
    if action == "observe": return observation()
    if action == "organism":
        var value = arguments.get("id", -1)
        if not valid_integer(value, 1, 2147483647): return {"error": "id must be a positive integer"}
        var org = world.reproduction.find_id(world, int(value))
        return {"error": "organism not found"} if org == null else organism_data(org, true)
    if action == "events":
        var value = arguments.get("after", 0)
        if not valid_integer(value, 0, 2147483647): return {"error": "after must be a nonnegative integer"}
        var items: Array = []
        for event in world.event_log:
            if event["sequence"] > int(value): items.append(event.duplicate(true))
        var first: int = world.event_log[0]["sequence"] if not world.event_log.is_empty() else 1
        return {"events": items, "cursor": world.event_sequence, "oldest": first, "gap": int(value) < first - 1, "revision": world.experiment_revision}
    if action == "step":
        if not world.experiment_mode: return {"error": "choose mode=stepped explicitly first"}
        var count = arguments.get("steps", 1)
        if not valid_integer(count, 1, 120): return {"error": "steps must be an integer from 1 to 120"}
        world.advance_experiment(int(count))
        return observation()
    if action == "parameters" or action == "reset":
        var params = arguments.get("parameters", {})
        if not params is Dictionary: return {"error": "parameters must be an object"}
        var provenance = arguments.get("provenance", {})
        if not provenance is Dictionary: return {"error": "provenance must be an object"}
        for key in provenance:
            if key not in ["source", "reference", "status"] or not provenance[key] is String: return {"error": "invalid provenance"}
            if str(provenance[key]).length() > 2000: return {"error": "provenance text too long"}
        var error: String = validate_parameters(params)
        if not error.is_empty(): return {"error": error}
        if action == "reset":
            var seed_value = arguments.get("seed", 1337)
            if not valid_integer(seed_value, 0, 2147483647): return {"error": "seed must be an integer from 0 to 2147483647"}
            # Full defaults prevent old UI preferences leaking into repeat trials.
            var clean: Dictionary = SettingsStore.defaults.duplicate(true)
            clean["auto_reseed"] = false
            clean["world_size"] = world.half_extent * 2.0
            clean["habitat_level"] = world.habitat_level
            for key in params: clean[key] = params[key]
            if int(clean["initial_organisms"]) > int(clean["organism_cap"]): return {"error": "initial_organisms exceeds organism_cap"}
            world.reset_experiment(int(seed_value), clean)
        else:
            for key in params:
                if key in ["initial_organisms", "organism_cap", "nutrient_count"]: return {"error": "population and particle counts require reset"}
            for key in params: world.experiment_settings[key] = params[key]
            world.temperature_offset = float(world.experiment_settings.get("temperature_offset", 0.0))
            world.record_event("intervention", {"parameters": params.duplicate(true), "provenance": provenance.duplicate(true)})
        return observation()
    return {"error": "unknown action"}

func valid_integer(value, minimum: int, maximum: int) -> bool:
    return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum

func validate_parameters(params: Dictionary) -> String:
    for key in params:
        if key in ["auto_reproduce", "auto_reseed"]:
            if not params[key] is bool: return key + " must be boolean"
            continue
        if not PARAM_LIMITS.has(key): return "unknown parameter: " + str(key)
        var value = params[key]
        if not (value is int or value is float) or not is_finite(float(value)): return str(key) + " must be finite numeric"
        var bounds: Array = PARAM_LIMITS[key]
        if float(value) < bounds[0] or float(value) > bounds[1]: return str(key) + " outside bounds"
        if key in ["initial_organisms", "organism_cap", "nutrient_count"] and float(value) != floor(float(value)): return str(key) + " must be integral"
    return ""
