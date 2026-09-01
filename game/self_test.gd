extends Node

const GenomeScript = preload("res://game/genome.gd")
const OrganismScript = preload("res://game/organism.gd")
const TISSUE_NEURAL: int = 3
const TISSUE_SENSOR: int = 4

func _ready() -> void:
    call_deferred("_run")

func _finish(code: int) -> void:
    get_tree().quit(code)

func _run() -> void:
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 424242

    var settings_store = get_node_or_null("/root/SettingsStore")
    if settings_store == null or not settings_store.has_method("get_value"):
        printerr("SELFTEST ERROR: SettingsStore autoload unavailable in project-context self-test")
        _finish(15)
        return

    # Verify every topology can build a genuinely 3D visible body.
    var plan_signatures: Dictionary = {}
    var total_cells: int = 0
    for plan in range(7):
        var genome = GenomeScript.new()
        genome.randomize_from(rng, 100 + plan)
        genome.body_plan = plan
        genome.limb_drive = 0.88
        genome.limb_length = 0.82
        genome.branch_drive = 0.78
        genome.fin_drive = 0.66
        genome.sensory_drive = 0.88
        genome.neural_drive = 0.91
        genome.support_drive = 0.86
        genome.metabolism = 0.72
        genome.aquatic_drive = 0.72
        genome.terrestrial_drive = 0.62 if plan in [4, 5] else 0.22
        genome.flight_drive = 0.72 if plan in [1, 3] else 0.08

        var org = OrganismScript.new()
        add_child(org)
        org.initialize(plan + 1, genome, Vector3.ZERO, 300, "cell")
        org.complexity = 240.0
        org.intelligence = 3.4
        org.energy = 1.1
        org.visual.rebuild(true)

        var cell_count: int = org.visual.body_cells.size()
        if cell_count < 20:
            printerr("SELFTEST ERROR: morphology plan ", plan, " produced too few visible cells: ", cell_count)
            _finish(10)
            return
        total_cells += cell_count

        var min_p = Vector3(INF, INF, INF)
        var max_p = Vector3(-INF, -INF, -INF)
        var has_sensor: bool = false
        var has_neural: bool = false
        for cell_v in org.visual.body_cells:
            var cell: Dictionary = cell_v
            var p: Vector3 = cell["p"]
            min_p.x = minf(min_p.x, p.x)
            min_p.y = minf(min_p.y, p.y)
            min_p.z = minf(min_p.z, p.z)
            max_p.x = maxf(max_p.x, p.x)
            max_p.y = maxf(max_p.y, p.y)
            max_p.z = maxf(max_p.z, p.z)
            var tissue: int = int(cell["t"])
            if tissue == TISSUE_SENSOR:
                has_sensor = true
            if tissue == TISSUE_NEURAL:
                has_neural = true
        var extent: Vector3 = max_p - min_p
        var signature: String = "%d:%d:%d" % [int(round(extent.x * 4.0)), int(round(extent.y * 4.0)), int(round(extent.z * 4.0))]
        plan_signatures[signature] = true
        if extent.x < 0.5 or extent.y < 0.1 or extent.z < 0.5:
            printerr("SELFTEST ERROR: plan ", plan, " is not volumetric enough: extent=", extent)
            _finish(11)
            return
        if plan in [0, 1, 4, 5, 6] and (not has_sensor or not has_neural):
            printerr("SELFTEST ERROR: advanced morphology missing sensor/neural tissue for plan ", plan)
            _finish(12)
            return
        org.queue_free()

    if plan_signatures.size() < 5:
        printerr("SELFTEST ERROR: morphology plans collapsed to too few distinct proportions: ", plan_signatures.size())
        _finish(13)
        return

    # Sexual recombination must mix lineages and advance generation.
    var parent_a = GenomeScript.new()
    var parent_b = GenomeScript.new()
    parent_a.randomize_from(rng, 7)
    parent_b.randomize_from(rng, 8)
    parent_a.body_plan = 0
    parent_b.body_plan = 3
    parent_a.hue = 0.10
    parent_b.hue = 0.80
    var child_genome = parent_a.crossover(parent_b, rng, 0.10, 0.25, 99)
    if int(child_genome.generation) != 1 or int(child_genome.family_id) != 99:
        printerr("SELFTEST ERROR: crossover lineage metadata invalid")
        _finish(14)
        return

    var mutant = parent_a.mutated(rng, 0.16, 1.0)
    if int(mutant.generation) != 1:
        printerr("SELFTEST ERROR: mutation generation did not increment")
        _finish(16)
        return
    if int(mutant.body_plan) == int(parent_a.body_plan):
        printerr("SELFTEST ERROR: forced macro-mutation did not change body topology")
        _finish(20)
        return

    # Deliberately unsupported costly morphology should score worse than a coherent body.
    var coherent = GenomeScript.new()
    coherent.randomize_from(rng, 11)
    coherent.support_drive = 0.90
    coherent.metabolism = 0.78
    coherent.armor_drive = 0.25
    coherent.shell_drive = 0.15
    coherent.limb_length = 0.52
    coherent.limb_thickness = 0.48
    var unstable = GenomeScript.new()
    unstable.randomize_from(rng, 12)
    unstable.support_drive = 0.0
    unstable.metabolism = 0.05
    unstable.armor_drive = 1.0
    unstable.shell_drive = 1.0
    unstable.limb_drive = 1.0
    unstable.limb_length = 1.0
    unstable.limb_thickness = 0.02
    if float(unstable.viability_score()) >= float(coherent.viability_score()):
        printerr("SELFTEST ERROR: viability selection does not penalise incoherent construction")
        _finish(17)
        return

    var language_genome = GenomeScript.new()
    language_genome.randomize_from(rng, 20)
    language_genome.neural_drive = 0.95
    language_genome.vocal_drive = 0.95
    var language_org = OrganismScript.new()
    add_child(language_org)
    language_org.initialize(80, language_genome, Vector3.ZERO, 180, "natural")
    language_org.complexity = 260.0
    language_org.intelligence = 3.8
    language_org.language_stage = 8
    var thought: String = str(language_org.generate_thought(rng))
    if thought.length() < 16:
        printerr("SELFTEST ERROR: advanced language output too short: ", thought)
        _finish(18)
        return
    var follow_data: Dictionary = language_org.follow_camera_data()
    if not follow_data.has("rear") or not follow_data.has("focus") or float(follow_data.get("size", 0.0)) <= 0.0:
        printerr("SELFTEST ERROR: anatomical follow-camera anchors unavailable")
        _finish(19)
        return

    language_org.apply_habitat(0.1, 9, -5.0, -20.0, 36.0)
    if language_org.habitat_stress < 0.0 or language_org.habitat_stress > 1.0:
        printerr("SELFTEST ERROR: habitat adaptation stress outside 0..1")
        _finish(21)
        return

    var history_cap: int = int(settings_store.get_value("max_history_events", 32))
    var app_log = get_node_or_null("/root/AppLog")
    if app_log != null and app_log.has_method("info"):
        app_log.info("self-test alpha9: plans=%d total_cells=%d coherent=%.3f unstable=%.3f history_cap=%d" % [plan_signatures.size(), total_cells, coherent.viability_score(), unstable.viability_score(), history_cap])

    print("SELFTEST OK: morphology_signatures=", plan_signatures.size(), " total_cells=", total_cells, " crossover_family=", child_genome.family_id, " viable=", coherent.viability_score(), " unstable=", unstable.viability_score(), " thought=", thought)
    language_org.queue_free()
    _finish(0)
