extends Node

const Genome = preload("res://game/genome.gd")
const History = preload("res://game/evolution_history.gd")
const LifeTest = preload("res://game/life_cycle_test.gd")
const API = preload("res://game/experiment_api.gd")
const Nutrients = preload("res://game/nutrient_field.gd")
var checks: int = 0
var failed: int = 0

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failed += 1
        printerr("SELFTEST ERROR: evolution: ", label)

func _entry(oid: int, plan: String, natural: bool = true) -> Dictionary:
    return {"id": oid, "parents": [1, 2] if natural else [-1, -1], "generation": 1 if natural else 0, "plan": plan, "mutations": 2 if natural else 0, "macro_mutations": 1 if natural else 0}

func run_all() -> bool:
    var rng = RandomNumberGenerator.new()
    rng.seed = 25092026
    var parent = Genome.new()
    parent.ensure_diploid()
    for locus in parent._continuous_gene_names():
        parent.alleles[locus] = [0.24, 0.76]
    parent.express_diploid()
    var original: Dictionary = parent.alleles.duplicate(true)
    var child = parent.mutated(rng, 0.0, 1.0)
    check(parent.alleles == original, "macro mutation cannot edit parent DNA")
    var differences: int = 0
    for locus in parent._continuous_gene_names():
        var changed_copies: int = 0
        for side in range(2):
            if parent.alleles[locus][side] != child.alleles[locus][side]: changed_copies += 1
        check(changed_copies <= 1, "macro mutation preserves the other homolog: " + locus)
        differences += changed_copies
    check(differences > 0 and child.mutation_events == differences and child.macro_mutation_events == differences, "macro counts match actual DNA changes")
    check(child.mutation_log.size() == differences, "each macro allele change has provenance")
    for change in child.mutation_log:
        check(change["before"] == original[change["gene"]][change["copy"]] and change["after"] == child.alleles[change["gene"]][change["copy"]], "macro log reconstructs the inherited change")
    var count: int = child.mutation_events
    child._change_allele("hue", 0, child.alleles["hue"][0], "small")
    check(child.mutation_events == count, "unchanged/clamped values are not mutation events")
    var unmutated = parent.mutated(rng, 0.0, 0.0)
    check(unmutated.mutation_events == 0 and unmutated.mutation_log.is_empty() and unmutated.alleles == original, "disabled mutation leaves a faithful diploid clone")
    for i in range(30):
        var small = parent.mutated(rng, 0.15, 0.0)
        check(small.mutation_events == small.mutation_log.size() and small.macro_mutation_events == 0, "small mutation accounting")
        var sexual = parent.crossover(parent, rng, 0.15, 0.8)
        check(sexual.mutation_events == sexual.mutation_log.size(), "gamete and later macro mutations have complete provenance")
    for pair in [[0.0, 0.5], [0.1, 0.6], [0.97, 0.03], [0.2, 0.8]]:
        check(is_equal_approx(Genome.blend_hue(pair[0], pair[1]), Genome.blend_hue(pair[1], pair[0])), "pigment hue is independent of parent ordering")
    check(Genome.blend_hue(0.97, 0.03) < 0.04, "red hues across wraparound remain red")
    var mother = Genome.new()
    var father = Genome.new()
    mother.ensure_diploid()
    father.ensure_diploid()
    for locus in ["pigment_saturation", "pigment_value"]:
        mother.alleles[locus] = [0.2, 0.2]
        father.alleles[locus] = [0.8, 0.8]
    mother.express_diploid()
    father.express_diploid()
    var pigmented = mother.crossover(father, rng, 0.0, 0.0)
    check(is_equal_approx(pigmented.pigment_saturation, 0.5) and is_equal_approx(pigmented.pigment_value, 0.5), "saturation and brightness are inherited from both parents")
    check(pigmented.alleles["pigment_value"] == [0.2, 0.8], "blended pigment expression preserves both parental alleles")
    mother.alleles["pigment_saturation"] = [0.0, 0.0]
    father.alleles["pigment_saturation"] = [0.0, 0.0]
    mother.express_diploid()
    father.express_diploid()
    var gray_child = mother.crossover(father, rng, 0.0, 0.0)
    var color: Color = gray_child.base_color()
    check(is_equal_approx(color.r, 0.5) and is_equal_approx(color.g, 0.5) and is_equal_approx(color.b, 0.5), "inherited pigment expression reaches rendered base RGB")
    color = mother.base_color()
    check(is_equal_approx(color.r, 0.2) and is_equal_approx(color.g, 0.2) and is_equal_approx(color.b, 0.2), "rendered brightness is not a fixed body constant")
    var names: Array = parent._continuous_gene_names()
    check(names.size() == 91 and names[1] == "symmetry" and names[88] == "body_plan_code", "new loci preserve the original 88-locus linkage map")
    parent.alleles["root_drive"] = [0.04, 0.72]
    parent.express_diploid()
    check(is_equal_approx(parent.root_drive, 0.38), "a latent anchoring allele remains additive and cryptic")

    var history = History.new()
    var initial: Dictionary = {"reason": "initial", "lineage": _entry(1, "serpentine", false)}
    history.record("founder_injection", initial, 0, 0.0)
    history.record("founder_injection", {"reason": "population_rescue", "lineage": _entry(2, "fusiform", false)}, 1, 1.0)
    history.record("founder_injection", {"reason": "manual", "lineage": _entry(3, "radial", false)}, 2, 2.0)
    history.record("birth", {"lineage": _entry(4, "radial")}, 3, 3.0)
    history.record("birth", {"lineage": _entry(5, "branching")}, 4, 4.0)
    var clonal: Dictionary = _entry(6, "branching")
    clonal["parents"] = [5, -1]
    history.record("birth", {"lineage": clonal}, 5, 5.0)
    history.record("death", {"id": 1}, 6, 6.0)
    var report: Dictionary = history.snapshot()
    var totals: Dictionary = report["totals"]
    check(totals["births"] == 3 and totals["sexual_births"] == 2 and totals["clonal_births"] == 1, "natural births separated by reproduction route")
    check(totals["initial_founders"] == 1 and totals["rescue_founders"] == 1 and totals["manual_founders"] == 1, "injected founders cannot inflate natural births")
    check(totals["new_topologies"] == 1 and report["discoveries"][0]["plan"] == "branching", "manually injected plans are not recorded as evolutionary discoveries")
    check(totals["deaths"] == 1 and not report["records"][0]["alive"] and report["records"][0]["death_step"] == 6, "lineage survives death with timestamp")
    report["records"][0]["parents"][0] = 999
    check(history.records[0]["parents"][0] == -1, "exported history is isolated from live state")
    for i in range(7, History.RECORD_LIMIT + 12):
        history.record("birth", {"lineage": _entry(i, "branching")}, i, float(i))
    check(history.records.size() == History.RECORD_LIMIT and history.by_id.size() == History.RECORD_LIMIT, "genealogy storage is bounded")
    check(history.totals["dropped_records"] == 11 and history.totals["births"] == History.RECORD_LIMIT + 8, "summary survives record eviction and reports missing history")

    var helper = LifeTest.new()
    add_child(helper)
    var world = helper.make_world()
    world.experiment_settings = {"auto_reseed": true, "minimum_population": 5}
    world.nutrient_field = Nutrients.new()
    world.add_child(world.nutrient_field)
    world.nutrient_field.initialize(32, world.half_extent, 9025)
    check(world.refresh_population_floor() == 5, "an empty paused world is replenished immediately")
    for org in world.organisms: org.alive = false
    check(world.refresh_population_floor() == 5 and world.organisms.size() == 5, "dead-but-not-yet-cleaned nodes do not block rescue")
    check(world.evolution_report()["totals"]["rescue_founders"] == 10, "rescue accounting survives repeated extinction")
    world.experiment_settings["auto_reseed"] = false
    for org in world.organisms: org.alive = false
    check(world.refresh_population_floor() == 0 and world.organisms.is_empty(), "disabled rescue permits extinction")
    var api = API.new()
    api.configure(world)
    var step: int = world.sim_steps
    var response: Dictionary = api.execute("parameters", {"parameters": {"auto_reseed": true}})
    check(not response.has("error") and world.organisms.size() == 5 and world.sim_steps == step, "protocol activation restores empty stepped world without advancing time")
    world.reset_experiment(925, {"auto_reseed": false, "initial_organisms": 2, "nutrient_count": 32})
    var fresh: Dictionary = world.evolution_report()
    check(fresh["records"].size() == 2 and fresh["totals"]["initial_founders"] == 2 and fresh["totals"]["rescue_founders"] == 0 and fresh["totals"]["deaths"] == 0 and fresh["seed"] == 925, "world reset starts a fresh, correctly attributed genealogy")
    world.queue_free()
    helper.queue_free()
    print("EVOLUTION SELFTEST: ", checks, " checks; ", failed, " failures")
    return failed == 0
