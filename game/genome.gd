extends RefCounted

const DNA = preload("res://game/dna_codec.gd")

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
var eye_focus: float = 0.6
var compound_eye_drive: float = 0.2
var antenna_drive: float = 0.4
var affective_plasticity: float = 0.5
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

var sex_system: float = 0.2
var internal_fertilization: float = 0.2
var live_birth: float = 0.1
var maternal_nourishment: float = 0.25
var egg_protection: float = 0.2
var gestation_gene: float = 0.35
var maturation_gene: float = 0.2
var metamorphosis: float = 0.1
var aquatic_larva: float = 0.2
var asexual_drive: float = 0.05
var reproductive_anatomy: float = 0.6
var dimorphism: float = 0.25
var ornament_drive: float = 0.2
var gamete_code: float = 0.5
var development_code: float = 0.5
var brood_size: float = 0.25
var parental_care: float = 0.2
var burst_drive: float = 0.25
var reach_drive: float = 0.2
var dive_drive: float = 0.2
var fertility_factor: float = 1.0

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
    for gene_name in sensory_gene_names():
        set(gene_name, rng.randf())
    for gene_name in ecological_gene_names():
        set(gene_name, rng.randf())
    for gene_name in surface_gene_names():
        set(gene_name, rng.randf())
    for gene_name in life_cycle_gene_names():
        set(gene_name, rng.randf())
    # Initial respiratory traits broadly match the aquatic ancestors. Mutation
    # and recombination can later separate locomotion from respiration.
    gill_drive = clampf(aquatic_drive * 0.7 + rng.randf_range(0.1, 0.3), 0.0, 1.0)
    lung_drive = clampf(terrestrial_drive * 0.8 + rng.randf_range(0.0, 0.2), 0.0, 1.0)
    wing_area *= 0.45
    _bias_plan_genes(rng)
    seed_diploid(rng)

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
    names.append_array(life_cycle_gene_names())
    names.append_array(sensory_gene_names())
    return names

# Each locus carries two homologous alleles. Dictionary order is the fixed map.
var alleles: Dictionary = {}
var expressed_baseline: Dictionary = {}
var recessive_load: Array = []
var sex_chromosomes: Array = []
var mutation_events: int = 0
var crossover_events: int = 0
const LOCI_PER_CHROMOSOME: int = 16

func ensure_diploid() -> void:
    # Legacy/editor-created genomes become homozygous. Founders use seed variation.
    if sex_chromosomes.is_empty():
        sex_chromosomes = [0, int(seed) % 2]
    for locus in _continuous_gene_names():
        var value: float = float(get(locus))
        if not alleles.has(locus) or absf(value - float(expressed_baseline.get(locus, value))) > 0.000001:
            alleles[locus] = [value, value]
            expressed_baseline[locus] = value
    if recessive_load.is_empty():
        for i in range(8): recessive_load.append([0.0, 0.0])

func seed_diploid(rng: RandomNumberGenerator) -> void:
    ensure_diploid()
    for locus in _continuous_gene_names():
        var value: float = float(get(locus))
        var spread: float = minf(0.08, minf(value, 1.0 - value))
        var difference: float = rng.randf_range(-spread, spread)
        alleles[locus] = [value - difference, value + difference]
    for i in range(8):
        recessive_load[i] = [1.0 if rng.randf() < 0.10 else 0.0, 0.0]
    express_diploid()

func express_diploid() -> void:
    var index: int = 0
    for locus in _continuous_gene_names():
        var pair: Array = alleles[locus]
        # Additive loci plus partial dominance at every third locus. No acquired
        # skill is written back to this germ line.
        var value: float = (float(pair[0]) + float(pair[1])) * 0.5
        if index % 3 == 0 and locus != "hue":
            value += absf(float(pair[0]) - float(pair[1])) * 0.18
        set(locus, clampf(value, 0.0, 1.0))
        expressed_baseline[locus] = float(get(locus))
        index += 1

func meiotic_products(rng: RandomNumberGenerator, strength: float = 0.0) -> Array:
    ensure_diploid()
    # Four chromatids after S phase. Crossovers exchange reciprocal distal
    # segments between nonsister chromatids; each locus conserves a 2:2 ratio
    # in the tetrad unless a new mutation occurs.
    var products: Array = []
    for i in range(4): products.append({"values": {}, "load": [], "sex": 0, "mutations": 0, "switches": 0, "ploidy": 1, "divisions": 2})
    var chromatids: Array = [0, 0, 1, 1]
    var index: int = 0
    for locus in _continuous_gene_names():
        if index % LOCI_PER_CHROMOSOME == 0:
            chromatids = [0, 0, 1, 1] if rng.randf() < 0.5 else [1, 1, 0, 0]
        elif rng.randf() < 0.12:
            var a: int = rng.randi_range(0, 1)
            var b: int = rng.randi_range(2, 3)
            var saved: int = chromatids[a]
            chromatids[a] = chromatids[b]
            chromatids[b] = saved
            products[a]["switches"] += 1
            products[b]["switches"] += 1
        for i in range(4):
            var value: float = float(alleles[locus][chromatids[i]])
            if strength > 0.0 and rng.randf() < 0.015 + mutability * 0.10:
                value = DNA.point_mutation(value, rng, strength) if rng.randf() < 0.25 else clampf(value + rng.randfn(0.0, strength), 0.0, 1.0)
                products[i]["mutations"] += 1
            products[i]["values"][locus] = value
        index += 1
    for pair in recessive_load:
        var first: int = rng.randi_range(0, 1)
        for i in range(4):
            var value: float = float(pair[first if i < 2 else 1 - first])
            if strength > 0.0 and rng.randf() < strength * 0.008:
                value = 1.0 - value
                products[i]["mutations"] += 1
            products[i]["load"].append(value)
    var first_sex: int = rng.randi_range(0, 1)
    for i in range(4): products[i]["sex"] = sex_chromosomes[first_sex if i < 2 else 1 - first_sex]
    return products

func make_gamete(rng: RandomNumberGenerator, strength: float = 0.0) -> Dictionary:
    var products: Array = meiotic_products(rng, strength)
    return products[rng.randi_range(0, 3)]

func mutated(rng: RandomNumberGenerator, strength: float = 0.14, macro_rate: float = 0.014):
    ensure_diploid()
    var g = get_script().new()
    g.seed = int(rng.randi())
    g.generation = generation + 1
    g.family_id = family_id
    g.body_plan = body_plan
    g.alleles = alleles.duplicate(true)
    g.recessive_load = recessive_load.duplicate(true)
    g.sex_chromosomes = sex_chromosomes.duplicate()
    for locus in _continuous_gene_names():
        for side in range(2):
            if strength > 0.0 and rng.randf() < 0.015 + mutability * 0.10:
                g.alleles[locus][side] = DNA.point_mutation(g.alleles[locus][side], rng, strength) if rng.randf() < 0.25 else clampf(g.alleles[locus][side] + rng.randfn(0.0, strength), 0.0, 1.0)
                g.mutation_events += 1
    g.express_diploid()
    if macro_rate >= 1.0 or rng.randf() < macro_rate:
        g.body_plan = _different_plan(g.body_plan, rng)
        _macro_perturb(g, rng, strength)
        g.ensure_diploid()
    g.fertility_factor = g.genetic_health()
    return g

func crossover(other, rng: RandomNumberGenerator, strength: float = 0.12, macro_rate: float = 0.014, new_family_id: int = -1):
    var egg: Dictionary = make_gamete(rng, strength)
    var sperm: Dictionary = other.make_gamete(rng, strength)
    return fertilize(other, egg, sperm, rng, strength, macro_rate, new_family_id)

func fertilize(other, egg: Dictionary, sperm: Dictionary, rng: RandomNumberGenerator, strength: float = 0.12, macro_rate: float = 0.014, new_family_id: int = -1):
    var g = get_script().new()
    g.seed = int(rng.randi())
    g.generation = maxi(generation, int(other.generation)) + 1
    g.family_id = new_family_id if new_family_id >= 0 else family_id
    g.body_plan = body_plan if rng.randf() < 0.5 else int(other.body_plan)
    g.sex_chromosomes = [egg["sex"], sperm["sex"]]
    for locus in _continuous_gene_names():
        g.alleles[locus] = [egg["values"][locus], sperm["values"][locus]]
    for i in range(8):
        g.recessive_load.append([egg["load"][i], sperm["load"][i]])
    g.mutation_events = egg["mutations"] + sperm["mutations"]
    g.crossover_events = egg["switches"] + sperm["switches"]
    g.express_diploid()
    if macro_rate >= 1.0 or rng.randf() < macro_rate:
        g.body_plan = _different_plan(g.body_plan, rng)
        _macro_perturb(g, rng, strength)
        g.ensure_diploid()
    g.fertility_factor = g.genetic_health()
    return g

func genetic_health() -> float:
    var damage: float = 0.0
    for pair in recessive_load:
        damage += minf(float(pair[0]), float(pair[1])) * 0.09
    return clampf(1.0 - damage, 0.0, 1.0)

func heterozygosity() -> float:
    if alleles.is_empty(): return 0.0
    var mixed: int = 0
    for locus in alleles:
        if absf(alleles[locus][0] - alleles[locus][1]) > 0.000001: mixed += 1
    return float(mixed) / float(alleles.size())

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
    candidates.append_array(life_cycle_gene_names())
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
    return clampf(1.0 - support_penalty - energy_penalty - coherence_penalty, 0.0, 1.0) * genetic_health()

func base_color() -> Color:
    return Color.from_hsv(hue, 0.66, 0.92)

func ecological_gene_names() -> Array[String]:
    return ["gill_drive", "lung_drive", "skin_breathing", "breath_storage", "muscle_drive", "size_gene", "wing_area", "light_skeleton", "balance_drive", "manipulation", "tool_drive", "shyness", "camouflage", "cleaning_drive", "parasite_drive", "root_drive", "photosynthesis", "wood_drive", "moisture_need", "grazer_drive", "ambush_drive"]

func surface_gene_names() -> Array[String]:
    return ["skin_thickness", "scale_cover", "feather_cover", "fur_cover", "mucus_cover", "membrane_cover", "horn_drive", "beak_drive", "pattern_drive"]

func life_cycle_gene_names() -> Array[String]:
    return ["sex_system", "internal_fertilization", "live_birth", "maternal_nourishment", "egg_protection", "gestation_gene", "maturation_gene", "metamorphosis", "aquatic_larva", "asexual_drive", "reproductive_anatomy", "dimorphism", "ornament_drive", "gamete_code", "development_code", "brood_size", "parental_care", "burst_drive", "reach_drive", "dive_drive"]

func aquatic_founder() -> void:
    # Only founders/injected ancestors get these bounds, never their descendants.
    aquatic_drive = maxf(0.80, aquatic_drive)
    gill_drive = maxf(0.85, gill_drive)
    lung_drive = minf(0.10, lung_drive)
    skin_breathing = minf(0.18, skin_breathing)
    terrestrial_drive = minf(0.10, terrestrial_drive)
    flight_drive = minf(0.03, flight_drive)
    wing_area = minf(0.05, wing_area)
    burst_drive = minf(0.20, burst_drive)
    dive_drive = minf(0.20, dive_drive)
    root_drive = minf(0.25, root_drive)
    internal_fertilization = minf(0.25, internal_fertilization)
    live_birth = minf(0.20, live_birth)
    metamorphosis = minf(0.25, metamorphosis)
    asexual_drive = minf(0.20, asexual_drive)
    gamete_code = 0.40 + gamete_code * 0.20
    development_code = 0.40 + development_code * 0.20
    ensure_diploid()

func dna_chromosomes() -> Array:
    ensure_diploid()
    var chromosomes: Array = []
    var names: Array = _continuous_gene_names()
    for start in range(0, names.size(), LOCI_PER_CHROMOSOME):
        var a: String = ""
        var b: String = ""
        var loci: Array = []
        for index in range(start, mini(start + LOCI_PER_CHROMOSOME, names.size())):
            var locus: String = names[index]
            a += DNA.encode(float(alleles[locus][0]))
            b += DNA.encode(float(alleles[locus][1]))
            loci.append({"gene": locus, "offset": (index - start) * DNA.BASE_COUNT, "length": DNA.BASE_COUNT})
        chromosomes.append({"pair": chromosomes.size() + 1, "homolog_a": a, "homolog_b": b, "complement_a": DNA.complement(a), "complement_b": DNA.complement(b), "loci": loci})
    return chromosomes

func dna_document() -> Dictionary:
    return {"schema": "arena.dna/1", "code": "fictional base-4 regulatory allele code; not real protein codons", "ploidy": 2, "bases_per_locus": DNA.BASE_COUNT, "quantization_error_max": 0.5 / DNA.MAX_CODE, "chromosomes": dna_chromosomes(), "sex_chromosomes": sex_chromosomes.duplicate(), "recessive_load": recessive_load.duplicate(true)}

func sensory_gene_names() -> Array[String]:
    return ["eye_focus", "compound_eye_drive", "antenna_drive", "affective_plasticity"]
