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
