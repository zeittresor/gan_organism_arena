extends RefCounted

# Morphology plans deliberately describe topology, not a fixed animal species.
# Continuous genes below still reshape each topology strongly, and macro-mutation
# can move descendants into a different topology over evolutionary time.
const PLAN_SERPENTINE := 0
const PLAN_FUSIFORM := 1
const PLAN_RADIAL := 2
const PLAN_RAY := 3
const PLAN_BRANCHING := 4
const PLAN_CRUSTACEAN := 5
const PLAN_CEPHALOPOD := 6
const PLAN_COUNT := 7

var seed: int = 1
var generation: int = 0
var family_id: int = 0
var body_plan: int = PLAN_SERPENTINE

var hue: float = 0.45
var symmetry: float = 0.75
var elongation: float = 0.55
var body_width: float = 0.50
var flattening: float = 0.25
var head_drive: float = 0.50
var tail_drive: float = 0.50
var limb_drive: float = 0.55
var limb_length: float = 0.50
var limb_thickness: float = 0.45
var limb_position: float = 0.50
var branch_drive: float = 0.35
var fin_drive: float = 0.35
var armor_drive: float = 0.25
var shell_drive: float = 0.12
var support_drive: float = 0.50
var sensory_drive: float = 0.55
var neural_drive: float = 0.50
var cooperation: float = 0.45
var aggression: float = 0.25
var curiosity: float = 0.55
var metabolism: float = 0.50
var buoyancy: float = 0.50
var reproduction: float = 0.50
var longevity: float = 0.50
var vocal_drive: float = 0.35
var mutability: float = 0.50
var aquatic_drive: float = 0.72
var terrestrial_drive: float = 0.18
var flight_drive: float = 0.08
var predator_drive: float = 0.20
var courtship_drive: float = 0.45
var pack_drive: float = 0.40
var dominance_drive: float = 0.35

var gill_drive: float = 0.75
var lung_drive: float = 0.15
var skin_breathing: float = 0.2
var breath_storage: float = 0.35
var muscle_drive: float = 0.45
var size_gene: float = 0.5
var wing_area: float = 0.15
var light_skeleton: float = 0.35
var balance_drive: float = 0.3
var manipulation: float = 0.2
var tool_drive: float = 0.15
var shyness: float = 0.4
var camouflage: float = 0.3
var cleaning_drive: float = 0.2
var parasite_drive: float = 0.15
var root_drive: float = 0.2
var photosynthesis: float = 0.15
var wood_drive: float = 0.15
var moisture_need: float = 0.35
var grazer_drive: float = 0.3
var ambush_drive: float = 0.3

var skin_thickness: float = 0.45
var scale_cover: float = 0.12
var feather_cover: float = 0.06
var fur_cover: float = 0.05
var mucus_cover: float = 0.18
var membrane_cover: float = 0.15
var horn_drive: float = 0.08
var beak_drive: float = 0.10
var pattern_drive: float = 0.35

func randomize_from(rng: RandomNumberGenerator, p_family_id: int, forced_plan: int = -1) -> void:
    seed = int(rng.randi())
    family_id = p_family_id
    generation = 0
    body_plan = forced_plan % PLAN_COUNT if forced_plan >= 0 else rng.randi_range(0, PLAN_COUNT - 1)
    hue = rng.randf()
    symmetry = rng.randf_range(0.18, 1.0)
    elongation = rng.randf_range(0.05, 0.98)
    body_width = rng.randf_range(0.08, 0.98)
    flattening = rng.randf_range(0.0, 1.0)
    head_drive = rng.randf_range(0.05, 1.0)
    tail_drive = rng.randf_range(0.0, 1.0)
    limb_drive = rng.randf_range(0.02, 1.0)
    limb_length = rng.randf_range(0.05, 1.0)
    limb_thickness = rng.randf_range(0.05, 1.0)
    limb_position = rng.randf()
    branch_drive = rng.randf_range(0.0, 1.0)
    fin_drive = rng.randf_range(0.0, 1.0)
    armor_drive = rng.randf_range(0.0, 1.0)
    shell_drive = rng.randf_range(0.0, 1.0)
    support_drive = rng.randf_range(0.08, 1.0)
    sensory_drive = rng.randf_range(0.08, 1.0)
    neural_drive = rng.randf_range(0.05, 1.0)
    cooperation = rng.randf()
    aggression = rng.randf()
    curiosity = rng.randf_range(0.05, 1.0)
    metabolism = rng.randf_range(0.18, 0.95)
    buoyancy = rng.randf_range(0.05, 0.95)
    reproduction = rng.randf_range(0.15, 0.95)
    longevity = rng.randf_range(0.08, 1.0)
    vocal_drive = rng.randf_range(0.02, 1.0)
    mutability = rng.randf_range(0.18, 0.95)
    aquatic_drive = rng.randf_range(0.35, 1.0)
    terrestrial_drive = rng.randf_range(0.0, 0.45)
    flight_drive = rng.randf_range(0.0, 0.20)
    predator_drive = rng.randf_range(0.0, 0.65)
    courtship_drive = rng.randf_range(0.10, 1.0)
    pack_drive = rng.randf_range(0.0, 1.0)
    dominance_drive = rng.randf_range(0.0, 1.0)
    for gene_name in ecological_gene_names():
        set(gene_name, rng.randf())
    for gene_name in surface_gene_names():
        set(gene_name, rng.randf())
    # Initial respiratory traits broadly match the aquatic ancestors. Mutation
    # and recombination can later separate locomotion from respiration.
    gill_drive = clampf(aquatic_drive * 0.7 + rng.randf_range(0.1, 0.3), 0.0, 1.0)
    lung_drive = clampf(terrestrial_drive * 0.8 + rng.randf_range(0.0, 0.2), 0.0, 1.0)
    wing_area *= 0.45
    _bias_plan_genes(rng)

func _continuous_gene_names() -> Array[String]:
    var names: Array[String] = [
        "hue", "symmetry", "elongation", "body_width", "flattening",
        "head_drive", "tail_drive", "limb_drive", "limb_length",
        "limb_thickness", "limb_position", "branch_drive", "fin_drive",
        "armor_drive", "shell_drive", "support_drive", "sensory_drive",
        "neural_drive", "cooperation", "aggression", "curiosity",
        "metabolism", "buoyancy", "reproduction", "longevity", "vocal_drive", "mutability",
        "aquatic_drive", "terrestrial_drive", "flight_drive", "predator_drive",
        "courtship_drive", "pack_drive", "dominance_drive"
    ]
    names.append_array(ecological_gene_names())
    names.append_array(surface_gene_names())
    return names

func mutated(rng: RandomNumberGenerator, strength: float = 0.14, macro_rate: float = 0.14):
    var script_resource = get_script()
    var g = script_resource.new()
    g.seed = int(rng.randi())
    g.generation = generation + 1
    g.family_id = family_id
    g.body_plan = body_plan
    var local_strength: float = strength * lerpf(0.65, 1.55, mutability)
    for property_name in _continuous_gene_names():
        var value: float = float(get(property_name)) + rng.randfn(0.0, local_strength)
        if property_name == "hue":
            value = fposmod(value, 1.0)
        else:
            value = clampf(value, 0.0, 1.0)
        g.set(property_name, value)
    # A macro mutation is intentionally rare but large. This prevents lineages
    # from being trapped forever in the topology of their first ancestor.
    if macro_rate >= 1.0 or rng.randf() < macro_rate * lerpf(0.65, 1.45, mutability):
        g.body_plan = _different_plan(g.body_plan, rng)
        _macro_perturb(g, rng, local_strength)
    return g

func crossover(other, rng: RandomNumberGenerator, strength: float = 0.12, macro_rate: float = 0.16, new_family_id: int = -1):
    var script_resource = get_script()
    var g = script_resource.new()
    g.seed = int(rng.randi())
    g.generation = maxi(generation, int(other.generation)) + 1
    g.family_id = new_family_id if new_family_id >= 0 else family_id

    # Topology is heritable but not immutable. Cross-plan matings occasionally
    # produce a third topology, which is the main source of large morphological leaps.
    if rng.randf() < 0.46:
        g.body_plan = body_plan
    else:
        g.body_plan = int(other.body_plan)
    if int(other.body_plan) != body_plan and rng.randf() < 0.28:
        g.body_plan = rng.randi_range(0, PLAN_COUNT - 1)

    var local_mutability: float = clampf((mutability + float(other.mutability)) * 0.5, 0.0, 1.0)
    var local_strength: float = strength * lerpf(0.70, 1.60, local_mutability)
    for property_name in _continuous_gene_names():
        var a: float = float(get(property_name))
        var b: float = float(other.get(property_name))
        var value: float
        var inheritance_roll: float = rng.randf()
        if inheritance_roll < 0.38:
            value = a
        elif inheritance_roll < 0.76:
            value = b
        else:
            value = lerpf(a, b, rng.randf())
        value += rng.randfn(0.0, local_strength)
        if property_name == "hue":
            value = fposmod(value, 1.0)
        else:
            value = clampf(value, 0.0, 1.0)
        g.set(property_name, value)

    if macro_rate >= 1.0 or rng.randf() < macro_rate * lerpf(0.70, 1.50, local_mutability):
        g.body_plan = _different_plan(g.body_plan, rng)
        _macro_perturb(g, rng, local_strength)
    return g

func _different_plan(current_plan: int, rng: RandomNumberGenerator) -> int:
    var shift: int = rng.randi_range(1, PLAN_COUNT - 1)
    return (current_plan + shift) % PLAN_COUNT

func _macro_perturb(g, rng: RandomNumberGenerator, strength: float) -> void:
    var candidates: Array[String] = [
        "elongation", "body_width", "flattening", "head_drive", "tail_drive",
        "limb_drive", "limb_length", "limb_thickness", "branch_drive",
        "fin_drive", "armor_drive", "shell_drive", "support_drive",
        "aquatic_drive", "terrestrial_drive", "flight_drive", "predator_drive"
    ]
    # Use the simulation RNG, including shuffle, for reproducible evolution.
    candidates.append_array(ecological_gene_names())
    candidates.append_array(surface_gene_names())
    for i in range(candidates.size() - 1, 0, -1):
        var j: int = rng.randi_range(0, i)
        var old: String = candidates[i]
        candidates[i] = candidates[j]
        candidates[j] = old
    var count: int = rng.randi_range(3, 6)
    for i in range(mini(count, candidates.size())):
        var property_name: String = candidates[i]
        var current: float = float(g.get(property_name))
        var jump: float = rng.randf_range(-0.48, 0.48) + rng.randfn(0.0, strength * 1.8)
        g.set(property_name, clampf(current + jump, 0.0, 1.0))

func _bias_plan_genes(rng: RandomNumberGenerator) -> void:
    # Initial organisms start far apart in morphology-space rather than being
    # recoloured copies of a common worm template.
    match body_plan:
        PLAN_SERPENTINE:
            elongation = rng.randf_range(0.72, 1.0)
            body_width = rng.randf_range(0.10, 0.48)
            tail_drive = rng.randf_range(0.65, 1.0)
        PLAN_FUSIFORM:
            elongation = rng.randf_range(0.35, 0.70)
            body_width = rng.randf_range(0.55, 0.95)
            limb_drive = rng.randf_range(0.45, 1.0)
        PLAN_RADIAL:
            elongation = rng.randf_range(0.02, 0.30)
            body_width = rng.randf_range(0.55, 1.0)
            branch_drive = rng.randf_range(0.55, 1.0)
            symmetry = rng.randf_range(0.65, 1.0)
        PLAN_RAY:
            aquatic_drive = rng.randf_range(0.70, 1.0)
            flattening = rng.randf_range(0.72, 1.0)
            fin_drive = rng.randf_range(0.72, 1.0)
            body_width = rng.randf_range(0.58, 1.0)
        PLAN_BRANCHING:
            branch_drive = rng.randf_range(0.72, 1.0)
            limb_drive = rng.randf_range(0.42, 0.92)
            elongation = rng.randf_range(0.15, 0.58)
        PLAN_CRUSTACEAN:
            terrestrial_drive = rng.randf_range(0.18, 0.60)
            armor_drive = rng.randf_range(0.62, 1.0)
            support_drive = rng.randf_range(0.62, 1.0)
            body_width = rng.randf_range(0.58, 1.0)
            limb_drive = rng.randf_range(0.58, 1.0)
        PLAN_CEPHALOPOD:
            aquatic_drive = rng.randf_range(0.72, 1.0)
            head_drive = rng.randf_range(0.72, 1.0)
            branch_drive = rng.randf_range(0.62, 1.0)
            tail_drive = rng.randf_range(0.0, 0.35)
            elongation = rng.randf_range(0.08, 0.42)

func body_plan_name() -> String:
    match body_plan:
        PLAN_SERPENTINE: return "serpentine"
        PLAN_FUSIFORM: return "fusiform"
        PLAN_RADIAL: return "radial"
        PLAN_RAY: return "ray"
        PLAN_BRANCHING: return "branching"
        PLAN_CRUSTACEAN: return "crustacean"
        PLAN_CEPHALOPOD: return "cephalopod"
        _: return "unknown"

func viability_score() -> float:
    # Viability is not an aesthetic score. It estimates whether the inherited
    # construction has enough metabolism/support to maintain its own costly traits.
    var appendage_load: float = limb_drive * limb_length * (0.34 + 0.36 * limb_thickness)
    appendage_load += branch_drive * 0.14 + fin_drive * flattening * 0.10
    var structural_load: float = appendage_load + armor_drive * 0.22 + shell_drive * 0.24 + body_width * 0.10
    var available_support: float = 0.20 + support_drive * 0.82 + metabolism * 0.22
    var support_penalty: float = maxf(0.0, structural_load - available_support) * 0.92

    var energy_load: float = 0.16 + armor_drive * 0.14 + shell_drive * 0.12 + neural_drive * 0.13 + head_drive * 0.08
    energy_load += limb_drive * limb_length * 0.12
    var available_energy: float = 0.18 + metabolism * 0.72
    var energy_penalty: float = maxf(0.0, energy_load - available_energy) * 0.82

    var coherence_penalty: float = 0.0
    var niche_sum: float = aquatic_drive + terrestrial_drive + flight_drive
    if niche_sum < 0.18:
        coherence_penalty += 0.28
    if flight_drive > 0.70 and support_drive < 0.30:
        coherence_penalty += (flight_drive - support_drive) * 0.22
    if terrestrial_drive > 0.70 and limb_drive < 0.18:
        coherence_penalty += 0.18
    if sensory_drive > neural_drive + 0.72:
        coherence_penalty += 0.08
    if armor_drive > 0.90 and support_drive < 0.18:
        coherence_penalty += 0.15
    if limb_length > 0.90 and limb_thickness < 0.10 and support_drive < 0.28:
        coherence_penalty += 0.20
    return clampf(1.0 - support_penalty - energy_penalty - coherence_penalty, 0.0, 1.0)

func base_color() -> Color:
    return Color.from_hsv(hue, 0.66, 0.92)

func ecological_gene_names() -> Array[String]:
    return ["gill_drive", "lung_drive", "skin_breathing", "breath_storage", "muscle_drive", "size_gene", "wing_area", "light_skeleton", "balance_drive", "manipulation", "tool_drive", "shyness", "camouflage", "cleaning_drive", "parasite_drive", "root_drive", "photosynthesis", "wood_drive", "moisture_need", "grazer_drive", "ambush_drive"]

func surface_gene_names() -> Array[String]:
    return ["skin_thickness", "scale_cover", "feather_cover", "fur_cover", "mucus_cover", "membrane_cover", "horn_drive", "beak_drive", "pattern_drive"]
