extends Node

const Genome = preload("res://game/genome.gd")
const Life = preload("res://game/organism.gd")
const Contact = preload("res://game/body_contact.gd")
const Habitat = preload("res://game/habitat_model.gd")
const CellCycle = preload("res://game/cell_cycle.gd")
const Physiology = preload("res://game/physiology.gd")
const Speech = preload("res://game/tts_windows.gd")
const DNA = preload("res://game/dna_codec.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        printerr("SELFTEST ERROR: interaction: ", label)

func creature(id: int, plan: int = 0, cap: int = 180):
    var g = Genome.new()
    g.body_plan = plan
    g.seed = id
    g.limb_drive = 0.95
    g.limb_length = 0.85
    g.muscle_drive = 0.85
    g.branch_drive = 0.8
    g.sex_system = 0.9
    var org = Life.new()
    add_child(org)
    org.initialize(id, g, Vector3.ZERO, cap, "natural")
    org.development_progress = 1.0
    org.complexity = 60.0
    org.energy = 1.4
    org.velocity = Vector3(1.5, 0, 0)
    org.visual.rebuild(true)
    return org

func run_all() -> bool:
    for cap in [64, 180, 420]:
        for plan in range(7):
            var org = creature(500 + plan, plan, cap)
            var visual = org.visual
            check(visual.body_cells.size() <= cap, "tissue budget remains bounded")
            var before: Array = visual.posed_cells.duplicate()
            visual.animate_life(0.35)
            var moved: bool = false
            for i in range(1, visual.body_cells.size()):
                var cell: Dictionary = visual.body_cells[i]
                var parent: int = int(cell["parent"])
                check(parent >= 0 and parent < i, "every tissue has a connected acyclic attachment")
                var offset: Vector3 = cell["p"] - visual.body_cells[parent]["p"]
                var fraction: float = float(cell["joint_pivot"]) if cell["joint"] else 0.0
                var pivot: Vector3 = visual.posed_cells[parent] + visual.posed_bases[parent] * offset * fraction
                check(absf(visual.posed_cells[i].distance_to(pivot) - offset.length() * (1.0 - fraction)) < 0.00001, "joint motion preserves the distal rigid segment length")
                if before[i].distance_to(visual.posed_cells[i]) > 0.001: moved = true
            check(moved, "living body and appendages articulate")
            org.queue_free()
    var sensory = creature(780)
    var eye_tissues: Array = []
    for cell in sensory.visual.body_cells: eye_tissues.append(int(cell["t"]))
    check(eye_tissues.has(27) and eye_tissues.has(28), "eyes have a distinct iris and pupil")
    sensory.gaze_direction = Vector3(0.5, 0.2, -1.0).normalized()
    sensory.visual.animate_life(0.1)
    for i in range(sensory.visual.body_cells.size()):
        var cell: Dictionary = sensory.visual.body_cells[i]
        if not bool(cell.get("eye_surface", false)): continue
        var parent: int = int(cell["parent"])
        var direction: Vector3 = (sensory.visual.posed_cells[i] - sensory.visual.posed_cells[parent]).normalized()
        check(direction.dot(sensory.gaze_direction) > 0.99, "pupil follows a common local gaze target")
    sensory.genome.compound_eye_drive = 0.9
    sensory.visual.rebuild(true)
    var facets: int = 0
    for cell in sensory.visual.body_cells:
        if int(cell["t"]) == 29: facets += 1
    check(facets > 0, "heritable compound-eye anatomy produces facets")
    sensory.intelligence = 0.0
    sensory.complexity = 0.5
    check(sensory.Affect.capacity(sensory) == 0.0, "primitive organisms remain reflex-driven")
    sensory.intelligence = 4.0
    sensory.energy = 1.4
    sensory.fear = 0.0
    for i in range(20): sensory.Affect.advance(sensory, 0.5, Vector3.ZERO, Vector3.ZERO)
    check(sensory.affect_valence > 0.2 and sensory.emotion == "contentment", "developed cognition supports contentment")
    sensory.fear = 0.9
    sensory.Affect.advance(sensory, 1.0, Vector3.ZERO, Vector3.RIGHT * 2.0)
    check(sensory.emotion == "distress" and sensory.Affect.steering(sensory, Vector3.ZERO, Vector3.RIGHT).x < 0.0, "distress changes escape steering")
    sensory.queue_free()
    var a = creature(800)
    var b = creature(801)
    check(Contact.surface_gap(a, b) < -0.1, "overlap is detected")
    Contact.solve([a, b], 16)
    check(Contact.surface_gap(a, b) >= -0.025, "overlap resolves to compliant surface contact")
    check(Contact.surface_gap(a, b) <= 0.22, "resolved partners remain close enough to mate")
    a.visual.set_view_mode("cell")
    check(absf(Contact.surface_gap(a, b)) < 0.03, "cell view does not change collisions")
    var model = Habitat.new()
    model.configure(5, 144.0)
    a.habitat = model
    a.global_position = Vector3(0, model.ground_y, 0)
    Contact.ground(a, 72.0)
    check(a.global_position.y > model.ground_y and a.grounded, "whole-body floor contact corrects penetration")
    for i in range(a.visual.body_cells.size()):
        var cell: Dictionary = a.visual.body_cells[i]
        var bottom: float = a.global_position.y + a.visual.posed_cells[i].y - float(cell["r"]) * cell["s"].y
        check(bottom >= model.ground_y - 0.001, "visible anatomy stays above flat floor")
    var rng = RandomNumberGenerator.new()
    rng.seed = 572
    for stage in range(1, 10):
        a.language_stage = stage
        for state in ["hunger", "fear", "hunt", "social", "curious", "reproduce", "observe"]:
            a.last_thought_state = state
            a.last_thought_index = 0
            var de: String = a.thought_in_language("de")
            var fr: String = a.thought_in_language("fr")
            check(de != "" and fr != "" and (stage == 1 or de != fr), "localized vocabulary at every speaking stage")
    var voices: Array = [{"id": "english", "language": "en-US"}, {"id": "german", "language": "de-DE"}]
    check(Speech.select_voice(voices, "de", "english") == "german", "voice selection enforces spoken language")
    check(Speech.select_voice(voices, "fr", "default") == "", "missing voice never speaks another language")
    var g = Genome.new()
    g.ensure_diploid()
    for locus in g._continuous_gene_names(): g.alleles[locus] = [0.0, 1.0]
    g.express_diploid()
    var tetrad: Array = g.meiotic_products(rng, 0.0)
    check(tetrad.size() == 4, "meiosis creates four haploid products")
    for locus in g._continuous_gene_names():
        var sum: float = 0.0
        for product in tetrad:
            sum += product["values"][locus]
            check(product["ploidy"] == 1 and product["divisions"] == 2, "meiosis has reduction and two divisions")
        check(sum == 2.0, "reciprocal recombination conserves parental copies")
    var clone = g.mutated(rng, 0.0, 0.0)
    check(clone.alleles == g.alleles, "mitotic cloning preserves diploid homologs")
    a.genome.asexual_drive = 0.85
    a.egg_reserve = 0.0
    a.sperm_reserve = 0.0
    a.bud_reserve = 0.0
    for i in range(300):
        a.energy = 1.4
        Physiology.advance(a, 0.5)
    check(a.bud_reserve > 0.0 and a.egg_reserve > 0.0 and a.sperm_reserve > 0.0, "combined strategy pays for buds and meiotic gametes")
    check(a.meiosis_cycles > 0 and not a.egg_genomes.is_empty(), "mature gametes carry actual haploid genotypes")
    a.tissue_damage = 0.5
    a.energy = 1.4
    var divisions: int = a.mitotic_divisions
    Physiology.advance(a, 1.0)
    check(a.tissue_damage < 0.5 and a.mitotic_divisions > divisions, "energy-paid mitosis repairs tissue")
    a.development_progress = 0.0
    a.energy = 1.4
    var cells: int = a.somatic_cells
    Physiology.advance(a, 1.0)
    check(a.somatic_cells > cells, "juvenile growth increases somatic cells by mitosis")
    for value in [0.0, 0.123456, 0.5, 0.88, 1.0]:
        var sequence: String = DNA.encode(value)
        check(sequence.length() == 10 and absf(DNA.decode(sequence) - value) <= 0.0000005, "DNA allele coding round trip")
        check(DNA.complement(DNA.complement(sequence)) == sequence, "DNA base-pair complement is reversible")
    check(DNA.decode("INVALID") < 0.0, "invalid DNA is rejected")
    check(DNA.point_mutation(0.5, rng, 0.14) != DNA.decode(DNA.encode(0.5)), "nucleotide substitution changes expressed allele")
    var dna: Dictionary = g.dna_document()
    check(dna["ploidy"] == 2 and dna["chromosomes"].size() == 6, "every genome has paired mapped DNA chromosomes")
    a.queue_free()
    b.queue_free()
    performance_checks()
    print("INTERACTION SELFTEST: ", checks, " checks; ", failures, " failures")
    return failures == 0

func performance_checks() -> void:
    var terrain = Habitat.new()
    for level in range(5, 10):
        terrain.configure(level, 144.0)
        for x in [-73.0, -63.0, -0.01, 0.0, 63.0, 73.0]:
            for radius in [0.0, 0.5, 8.0, 20.0]:
                var p = Vector3(x, 0, x * 0.37)
                var ceiling: float = terrain.floor_upper_bound(p, radius)
                for dx in [-radius, 0.0, radius]:
                    for dz in [-radius, 0.0, radius]:
                        check(terrain.floor_at(p + Vector3(dx, 0, dz)) <= ceiling + 0.0001, "terrain broad phase bounds triangle heights and tile edges")
    terrain.configure(5, 144.0)
    var a = creature(880, 0, 64)
    var b = creature(881, 0, 64)
    a.habitat = terrain
    b.habitat = terrain
    a.global_position = Vector3(-25, 10, 0)
    b.global_position = Vector3(25, 10, 0)
    Contact.solve([a, b])
    check(a.visual.contact_builds == 0 and b.visual.contact_builds == 0, "distant bodies build no narrow-phase envelopes")
    Contact.ground(a, 72.0)
    check(a.visual.ground_fast_checks == 1 and a.visual.ground_detail_checks == 0, "free swimming avoids per-cell ground checks")
    Contact.ground(a, 72.0)
    check(a.visual.ground_cache_hits == 1, "unchanged contact reuses result")
    a.visual.animate_life(0.1)
    Contact.ground(a, 72.0)
    check(a.visual.ground_fast_checks == 2, "animated pose invalidates contact cache")
    a.contact_quality = 0
    Contact.ground(a, 72.0)
    check(a.visual.ground_fast_checks == 3, "quality changes invalidate contact cache")
    terrain.configure(5, 144.0)
    Contact.ground(a, 72.0)
    check(a.visual.ground_fast_checks == 4, "terrain rebuild invalidates contact cache")
    var pose_before: int = a.visual.pose_revision
    var uploads_before: int = a.visual.render_uploads
    a.visual.set_render_active(false)
    a.visual.animate_life(0.1)
    check(a.visual.pose_revision > pose_before and a.visual.render_uploads == uploads_before, "offscreen articulation continues without graphics uploads")
    check(a.visual.render_pending, "offscreen render data is marked pending")
    a.visual.set_render_active(true)
    check(not a.visual.render_pending and a.visual.render_uploads == uploads_before + 1, "re-entering view refreshes the current pose immediately")
    a.visual.set_render_active(false)
    a.visual.animate_life(0.1)
    a.visual.flush_render()
    check(not a.visual.render_pending, "explicit export can flush an offscreen pose")
    a.global_position = Vector3(0, terrain.ground_y - 2.0, 0)
    Contact.ground(a, 72.0)
    check(a.visual.ground_detail_checks == 1 and a.grounded, "lowest quality still corrects floor penetration")
    a.contact_quality = 100
    Contact.ground(a, 72.0)
    check(a.visual.ground_detail_checks == 2, "highest quality takes effect without movement")
    a.global_position = Vector3.ZERO
    b.global_position = Vector3.ZERO
    a.grounded = false
    b.grounded = false
    Contact.solve([a, b], 16)
    check(Contact.touching(a, b), "optimized proximity supports mating contact")
    var direction: Vector3 = (b.global_position - a.global_position).normalized()
    b.global_position -= direction * 0.05
    var before: Vector3 = b.global_position
    Contact.solve([a, b], 2, 0)
    check(b.global_position.distance_to(before) < 0.0001, "low quality tolerates slight body overlap")
    Contact.solve([a, b], 16, 100)
    check(Contact.surface_gap(a, b) >= -0.025, "highest quality resolves that overlap")
    a.queue_free()
    b.queue_free()
