extends Node

# Optional stochastic soak probe; it is intentionally not part of the fast
# installer gate. Run with Godot --headless --path . --script
# tests/long_run_ecology_probe.gd [steps]. It reports whether a normal seeded
# run ever expressed plants, land use and post-founder morphotypes.
const World = preload("res://game/sim_world.gd")

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var requested: int = 60000
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if not args.is_empty(): requested = clampi(int(args[0]), 1000, 500000)
    var world = World.new()
    add_child(world)
    world.experiment_mode = true
    world.experiment_settings = {
        "world_size": 144.0, "habitat_level": 7, "initial_organisms": 10,
        "minimum_population": 5, "organism_cap": 28, "nutrient_count": 300,
        "visual_cell_cap": 48, "auto_reseed": true, "auto_reproduce": true,
        "plant_evolution_bias": 0.35, "mutation_strength": 0.14,
        "macro_mutation_rate": 0.014, "contact_quality": 60
    }
    world.initialize(9072026)
    var ever_rooted: int = 0
    var ever_land: int = 0
    var ever_derived: int = 0
    var max_generation: int = 0
    var completed: int = 0
    while completed < requested:
        for org in world.organisms:
            if is_instance_valid(org) and is_instance_valid(org.visual): org.visual.set_render_active(false)
        var chunk: int = mini(120, requested - completed)
        world.advance_experiment(chunk)
        completed += chunk
        for org in world.organisms:
            if not is_instance_valid(org) or not org.alive: continue
            if org.rooted: ever_rooted += 1
            if not org.in_water: ever_land += 1
            if str(org.genome.expressed_morphotype()) != str(org.body_plan_name()): ever_derived += 1
            max_generation = maxi(max_generation, int(org.genome.generation))
    var metrics: Dictionary = world.metrics()
    var event_kinds: Dictionary = {}
    var death_causes: Dictionary = {}
    for event in world.event_log:
        var kind: String = str(event["kind"])
        event_kinds[kind] = int(event_kinds.get(kind, 0)) + 1
        if kind == "death":
            var cause: String = str(event["data"].get("cause", "unknown"))
            death_causes[cause] = int(death_causes.get(cause, 0)) + 1
    print("LONG RUN ECOLOGY PROBE: ", JSON.stringify({
        "steps": requested, "population": metrics["organisms"],
        "current_rooted": metrics["rooted_count"], "current_land": metrics["land_count"],
        "morphotypes": metrics["body_plan_count"], "topologies": metrics["topology_count"],
        "ever_rooted_samples": ever_rooted, "ever_land_samples": ever_land,
        "ever_derived_samples": ever_derived, "highest_generation": max_generation,
        "births": world.reproduction.births, "conceptions": world.reproduction.conceptions,
        "brood_losses": world.reproduction.losses, "open_broods": world.reproduction.broods.size(),
        "spawn_clouds": world.reproduction.spawn_clouds.size(), "event_kinds": event_kinds,
        "death_causes": death_causes, "history_totals": world.evolution_history.totals
    }))
    world.queue_free()
    get_tree().quit(0)
