extends Node
const Genome = preload("res://game/genome.gd")
const Physiology = preload("res://game/physiology.gd")
const Cycle = preload("res://game/life_cycle.gd")
const LifeTest = preload("res://game/life_cycle_test.gd")
var checks: int = 0
var failed: int = 0

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failed += 1
        printerr("SELFTEST ERROR: biology: ", label)

func run_all() -> bool:
    var rng = RandomNumberGenerator.new()
    rng.seed = 91342
    var a = Genome.new()
    var b = Genome.new()
    a.ensure_diploid()
    b.ensure_diploid()
    a.alleles["skin_thickness"] = [0.0, 1.0]
    b.alleles["skin_thickness"] = [0.0, 1.0]
    a.express_diploid()
    b.express_diploid()
    var counts: Array = [0, 0, 0]
    for i in range(600):
        var child = a.crossover(b, rng, 0.0, 0.0)
        var pair: Array = child.alleles["skin_thickness"]
        counts[int(pair[0] + pair[1])] += 1
        check(pair[0] in [0.0, 1.0] and pair[1] in [0.0, 1.0], "meiosis never invents a blended allele without mutation")
    check(counts[0] > 105 and counts[0] < 200 and counts[1] > 240 and counts[1] < 360 and counts[2] > 105 and counts[2] < 200, "heterozygote cross approximates Mendelian 1:2:1 segregation")
    a.recessive_load[0] = [1.0, 0.0]
    check(is_equal_approx(a.genetic_health(), 1.0), "recessive carrier has no expressed damage")
    a.recessive_load[0] = [1.0, 1.0]
    check(a.genetic_health() < 1.0, "two harmful alleles express recessive load")
    var clone = a.mutated(rng, 0.0, 0.0)
    check(clone.alleles["skin_thickness"] == a.alleles["skin_thickness"], "cloning preserves both homologs")
    clone.alleles["skin_thickness"][0] = 0.33
    check(a.alleles["skin_thickness"][0] == 0.0, "offspring alleles never alias parent memory")
    a.sex_chromosomes = [0, 1]
    a.seed = 2
    check(Cycle.sex_role(a) == "male", "sex follows inherited chromosomes rather than display/random seed")
    var names: Array = a._continuous_gene_names()
    for locus in names: a.alleles[locus] = [0.0, 1.0]
    a.express_diploid()
    var linked: int = 0
    for i in range(400):
        var gamete: Dictionary = a.make_gamete(rng)
        if gamete["values"][names[0]] == gamete["values"][names[1]]: linked += 1
    check(linked > 340 and linked < 400, "adjacent loci remain linked with occasional recombination")

    # A sexual child receives one real allele from each parent across anatomy,
    # tissue, physiology and behavioural disposition. Pigment hue needs circular
    # blending because 0.0 and 1.0 describe the same red on an HSV wheel.
    var maternal = Genome.new()
    var paternal = Genome.new()
    maternal.ensure_diploid()
    paternal.ensure_diploid()
    var inherited_loci: Array[String] = ["support_drive", "light_skeleton", "limb_drive", "muscle_drive", "skin_thickness", "shell_drive", "fur_cover", "aggression", "curiosity"]
    for locus in inherited_loci:
        maternal.alleles[locus] = [0.18, 0.18]
        paternal.alleles[locus] = [0.82, 0.82]
    maternal.alleles["hue"] = [0.97, 0.97]
    paternal.alleles["hue"] = [0.03, 0.03]
    maternal.express_diploid()
    paternal.express_diploid()
    var maternal_gamete: Dictionary = maternal.make_gamete(rng, 0.0)
    var paternal_gamete: Dictionary = paternal.make_gamete(rng, 0.0)
    var mixed_child = maternal.fertilize(paternal, maternal_gamete, paternal_gamete, rng, 0.0, 0.0)
    for locus in inherited_loci:
        check(is_equal_approx(float(mixed_child.alleles[locus][0]), 0.18) and is_equal_approx(float(mixed_child.alleles[locus][1]), 0.82), "two-parent allele provenance: " + locus)
    check(mixed_child.hue < 0.06 or mixed_child.hue > 0.94, "parental red hues blend across the circular pigment boundary")
    var topology_is_encoded: bool = false
    for chromosome in mixed_child.dna_document()["chromosomes"]:
        for encoded_locus in chromosome["loci"]:
            if encoded_locus["gene"] == "body_plan_code": topology_is_encoded = true
    check(topology_is_encoded, "body topology is encoded in the exported diploid DNA")

    # Injected ancestors use only a small ancestral topology set. DNA-changing
    # macro mutations can open body plans that did not exist in that population.
    var ancestor = Genome.new()
    ancestor.randomize_from(rng, 91, 0)
    var novelty_seen: bool = false
    for i in range(24):
        var descendant = ancestor.mutated(rng, 0.18, 1.0)
        if int(descendant.body_plan) not in [0, 1, 3]:
            novelty_seen = true
            break
    check(novelty_seen, "macro mutation reaches a topology absent from the ancestral founder pool")
    var helper = LifeTest.new()
    add_child(helper)
    var world = helper.make_world()
    var fed = helper.make_parent(world, 2)
    var hungry = helper.make_parent(world, 4)
    for org in [fed, hungry]:
        org.development_progress = 0.0
        org.egg_reserve = 0.0
        org.sperm_reserve = 0.0
        org.bud_reserve = 0.0
    fed.energy = 1.2
    hungry.energy = 0.10
    var before: float = fed.energy
    Physiology.advance(fed, 10.0)
    Physiology.advance(hungry, 10.0)
    check(fed.development_progress > 0.0 and hungry.development_progress == 0.0, "development stalls without surplus food")
    check(is_equal_approx(before, fed.energy + fed.growth_investment), "growth investment is deducted from reserves")
    check(fed.egg_reserve == 0.0, "juvenile cannot manufacture mature gametes")
    fed.development_progress = 1.0
    before = fed.energy
    Physiology.advance(fed, 10.0)
    check(fed.egg_reserve > 0.0 and fed.energy < before and fed.energy + fed.egg_reserve <= before, "oogenesis spends energy and loses conversion heat")
    check(not fed.can_reproduce(), "adult age alone cannot substitute for enough eggs")
    fed.egg_reserve = 0.78
    var male = helper.make_parent(world, 3)
    male.global_position = fed.global_position
    fed.energy = 1.2
    fed.genome.gestation_gene = 0.4
    check(world.reproduction._conceive(world, fed, male), "gamete-funded reproduction works")
    var egg_after: float = fed.egg_reserve
    check(egg_after < 0.78 and male.sperm_reserve < 0.11, "fertilization consumes each gamete pool")
    world.reproduction._develop_broods(world, 1.0)
    var warm: float = world.reproduction.broods[0]["development"]
    world.temperature_offset = -10.0
    world.reproduction._develop_broods(world, 1.0)
    var cold: float = world.reproduction.broods[0]["development"] - warm
    check(cold < warm, "colder incubation slows embryo development")
    check(Physiology.embryo_stage(0.1) == "cleavage" and Physiology.embryo_stage(0.3) == "gastrulation" and Physiology.embryo_stage(0.5) == "organogenesis", "embryonic phases are explicit")
    check(world.event_log[0]["kind"] == "conception", "conception has machine-readable provenance")
    world.queue_free()
    helper.queue_free()
    print("BIOLOGY SELFTEST: ", checks, " checks; ", failed, " failures")
    return failed == 0
