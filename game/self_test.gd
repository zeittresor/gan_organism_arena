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
    var genome = GenomeScript.new()
    genome.randomize_from(rng, 7)
    genome.limb_drive = 0.92
    genome.branch_drive = 0.82
    genome.fin_drive = 0.35
    genome.sensory_drive = 0.88
    genome.neural_drive = 0.91

    var org = OrganismScript.new()
    add_child(org)
    org.initialize(1, genome, Vector3.ZERO, 260, "cell")
    org.complexity = 240.0
    org.intelligence = 3.4
    org.energy = 1.1
    org.visual.rebuild(true)

    var cell_count: int = org.visual.body_cells.size()
    if cell_count < 80:
        printerr("SELFTEST ERROR: advanced morphology produced too few visible cells: ", cell_count)
        _finish(10)
        return

    var has_sensor: bool = false
    var has_neural: bool = false
    for cell_v in org.visual.body_cells:
        var cell: Dictionary = cell_v
        var tissue: int = int(cell["t"])
        if tissue == TISSUE_SENSOR:
            has_sensor = true
        if tissue == TISSUE_NEURAL:
            has_neural = true
    if not has_sensor or not has_neural:
        printerr("SELFTEST ERROR: advanced morphology missing sensor/neural tissue")
        _finish(11)
        return

    org.language_stage = 8
    var thought: String = str(org.generate_thought(rng))
    if thought.length() < 16:
        printerr("SELFTEST ERROR: advanced language output too short: ", thought)
        _finish(12)
        return

    var child_genome = genome.mutated(rng, 0.12)
    if int(child_genome.generation) != int(genome.generation) + 1:
        printerr("SELFTEST ERROR: genome mutation generation did not increment")
        _finish(13)
        return

    var lateral_cells: int = 0
    for cell_v in org.visual.body_cells:
        var cell: Dictionary = cell_v
        var p: Vector3 = cell["p"]
        if absf(p.x) > 1.1:
            lateral_cells += 1
    if lateral_cells < 8:
        printerr("SELFTEST ERROR: advanced morphology lacks visible 3D appendages: lateral_cells=", lateral_cells)
        _finish(14)
        return

    # Verify autoloads are active in this project-context test. This is the exact
    # regression missed when the self-test was executed in standalone --script mode.
    var settings_store = get_node_or_null("/root/SettingsStore")
    if settings_store == null or not settings_store.has_method("get_value"):
        printerr("SELFTEST ERROR: SettingsStore autoload unavailable in project-context self-test")
        _finish(15)
        return
    var history_cap: int = int(settings_store.get_value("max_history_events", 32))
    if history_cap <= 0:
        printerr("SELFTEST ERROR: SettingsStore returned invalid history cap")
        _finish(16)
        return
    var app_log = get_node_or_null("/root/AppLog")
    if app_log != null and app_log.has_method("info"):
        app_log.info("self-test autoloads active; history_cap=%d" % history_cap)

    print("SELFTEST OK: cells=", cell_count, " lateral=", lateral_cells, " thought=", thought, " child_generation=", child_genome.generation, " history_cap=", history_cap)
    org.queue_free()
    _finish(0)
