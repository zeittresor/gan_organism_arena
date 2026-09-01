extends Node

const Genome = preload("res://game/genome.gd")
const Life = preload("res://game/organism.gd")
const Visual = preload("res://game/organism_visual.gd")
const Traits = preload("res://game/ecology_traits.gd")
var failures: int = 0
var checks: int = 0
var next_id: int = 9000

func check(ok: bool, label: String) -> void:
    checks += 1
    if ok:
        print("SURFACE OK: ", label)
    else:
        failures += 1
        printerr("SELFTEST ERROR: covering: ", label)

func plain_genome():
    var g = Genome.new()
    for gene_name in g.surface_gene_names():
        g.set(gene_name, 0.0)
    return g

func create_body(g, cap: int = 180):
    var org = Life.new()
    add_child(org)
    next_id += 1
    org.initialize(next_id, g, Vector3.ZERO, cap, "natural")
    org.age_seconds = 40.0
    org.complexity = 35.0
    org.visual.rebuild(true)
    return org

func count_tissue(org, tissue: int) -> int:
    var count: int = 0
    for cell in org.visual.body_cells:
        if int(cell["t"]) == tissue:
            count += 1
    return count

func run_all() -> bool:
    var plain = plain_genome()
    var feathered = plain_genome()
    feathered.feather_cover = 1.0
    feathered.fin_drive = 0.0
    feathered.flight_drive = 1.0
    feathered.wing_area = 0.0
    check(not Traits.flight_body(feathered), "feathers alone cannot supply wings or flight")
    var birdlike = create_body(feathered)
    check(count_tissue(birdlike, Visual.Tissue.FEATHER) > 0 and count_tissue(birdlike, Visual.Tissue.QUILL) > 0, "non-flying body grows feather vanes and quills without fins")
    check(count_tissue(birdlike, Visual.Tissue.WING) == 0, "feathered non-flyer does not sprout unsupported wings")
    check(Traits.insulation(feathered, false) > Traits.insulation(plain, false), "feathers provide insulation independently of flight")
    check(Traits.coat_drag(feathered) > Traits.coat_drag(plain), "feathers increase water drag independently of fin structure")

    var profiles: Dictionary = {
        "scale_cover": Visual.Tissue.SCALE,
        "fur_cover": Visual.Tissue.FUR,
        "mucus_cover": Visual.Tissue.MUCUS,
        "membrane_cover": Visual.Tissue.MEMBRANE,
        "horn_drive": Visual.Tissue.HORN,
        "beak_drive": Visual.Tissue.BEAK,
        "feather_cover": Visual.Tissue.FEATHER
    }
    for gene_name in profiles:
        for cap in [48, 180]:
            var g = plain_genome()
            g.set(gene_name, 1.0)
            var org = create_body(g, cap)
            check(count_tissue(org, int(profiles[gene_name])) > 0, "%s visible at budget %d" % [gene_name, cap])
            check(org.visual.body_cells.size() <= cap, "%s respects budget %d" % [gene_name, cap])
    var mixed = plain_genome()
    for gene_name in mixed.surface_gene_names():
        mixed.set(gene_name, 1.0)
    var hybrid = create_body(mixed)
    for gene_name in profiles:
        check(count_tissue(hybrid, int(profiles[gene_name])) > 0, "mixed body retains " + gene_name)
    check(count_tissue(hybrid, Visual.Tissue.SKIN) > 0, "mixed body keeps underlying skin")
    check(hybrid.visual.body_cells.size() <= 180, "all mixed coverings share one bounded body budget")
    var before: int = hybrid.visual.body_cells.size()
    hybrid.visual.rebuild(true)
    check(hybrid.visual.body_cells.size() == before, "body rebuild does not accumulate layers")

    var armored = plain_genome()
    armored.scale_cover = 1.0
    armored.skin_thickness = 1.0
    check(Traits.covering_protection(armored) > Traits.covering_protection(plain), "thick skin and scales protect against bites")
    check(Traits.water_loss(armored) < Traits.water_loss(plain), "protective integument slows drying")
    check(Traits.skin_permeability(armored) < Traits.skin_permeability(plain), "dense coverings limit skin gas exchange")
    var unprotected_body = create_body(plain)
    var protected_body = create_body(armored)
    check(protected_body.receive_predation(0.20, 1) < unprotected_body.receive_predation(0.20, 1), "covering protection actually reduces attack damage")
    var furry = plain_genome()
    furry.fur_cover = 1.0
    check(Traits.thermal_cost(furry, false, 4.0) < Traits.thermal_cost(plain, false, 4.0), "insulation lowers cold energy burden")
    check(Traits.thermal_cost(furry, false, 35.0) > Traits.thermal_cost(plain, false, 35.0), "dense coat increases heat burden")
    check(Traits.coat_drag(furry) > Traits.coat_drag(plain), "fur increases water resistance")
    var wet_drag: float = Traits.coat_drag(furry)
    var wet_insulation: float = Traits.insulation(furry, true)
    furry.mucus_cover = 1.0
    check(Traits.coat_drag(furry) < wet_drag, "surface secretion reduces water drag")
    check(Traits.insulation(furry, true) > wet_insulation, "water-repellent coating retains more wet insulation")
    check(Traits.covering_cost(mixed) > Traits.covering_cost(plain), "combined coverings have a maintenance cost")

    var rng = RandomNumberGenerator.new()
    rng.seed = 54321
    var child = mixed.mutated(rng, 0.0, 0.0)
    var hybrid_child = mixed.crossover(plain, rng, 0.0, 0.0, 900)
    var altered = mixed.mutated(rng, 0.6, 1.0)
    for gene_name in mixed.surface_gene_names():
        check(is_equal_approx(float(child.get(gene_name)), float(mixed.get(gene_name))), "cover inherited: " + gene_name)
        check(float(hybrid_child.get(gene_name)) >= 0.0 and float(hybrid_child.get(gene_name)) <= 1.0 and float(altered.get(gene_name)) >= 0.0 and float(altered.get(gene_name)) <= 1.0, "crossover/mutation keep covering gene bounded: " + gene_name)
    for node in get_children():
        node.queue_free()
    print("SURFACE SELFTEST: ", checks, " checks; ", failures, " failures")
    return failures == 0
