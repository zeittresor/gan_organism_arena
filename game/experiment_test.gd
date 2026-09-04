extends Node
const World = preload("res://game/sim_world.gd")
const API = preload("res://game/experiment_api.gd")
var checks: int = 0
var failed: int = 0
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failed += 1
        printerr("SELFTEST ERROR: experiment: ", label)

func run_all() -> bool:
    var world = World.new()
    add_child(world)
    world.set_process(false)
    world.initialize(42)
    var api = API.new()
    api.configure(world)
    var parameters: Dictionary = {"initial_organisms": 2, "organism_cap": 12, "nutrient_count": 32}
    check(not world.experiment_mode, "default AI observation preserves live mode")
    api.execute("mode", {"mode": "stepped"})
    var first: Dictionary = api.execute("reset", {"seed": 42, "parameters": parameters})
    check(first["organisms"].size() == 2 and first["step"] == 0, "reset creates requested seeded population")
    first = api.execute("step", {"steps": 12})
    check(first["step"] == 12 and absf(first["time"] - 1.0) < 0.000001, "steps advance exact simulation time")
    api.execute("reset", {"seed": 42, "parameters": parameters})
    var second: Dictionary = api.execute("step", {"steps": 12})
    check(first["organisms"] == second["organisms"] and first["broods"] == second["broods"], "same seed and interventions reproduce population state")
    for invalid in [0, -1, 121, true, 1.5, "12"]:
        check(api.execute("step", {"steps": invalid}).has("error"), "invalid step request rejected")
    check(api.execute("reset", {"seed": 1, "parameters": {"initial_organisms": 60, "organism_cap": 2}}).has("error"), "contradictory population setup rejected atomically")
    check(world.sim_steps == 12, "failed reset has no side effects")
    check(api.execute("parameters", {"parameters": {"temperature_offset": 99}}).has("error"), "out-of-range intervention rejected")
    var detail: Dictionary = api.execute("organism", {"id": 1})
    check(detail["genome"]["alleles"].size() > 80, "genome interface exposes actual allele pairs")
    api.execute("parameters", {"parameters": {"nutrient_renewal": 0.0}})
    check(world.event_log[-1]["kind"] == "intervention", "applied intervention records provenance")
    api.execute("parameters", {"parameters": {"gravity_scale": 0.5}})
    check(float(api.observation()["parameters"]["gravity_scale"]) == 0.5, "gravity intervention is observable")
    check(world.organisms[0].Support.gravity_scale(world.organisms[0]) == 0.5, "gravity intervention reaches live organism physics")
    check(api.execute("parameters", {"parameters": {"gravity_scale": 0.0}}).has("error"), "invalid gravity intervention rejected")
    var before: float = world.nutrient_field.stored_energy()
    var eaten: float = world.nutrient_field.consume(0)
    check(eaten > 0.0 and is_equal_approx(world.nutrient_field.stored_energy() + eaten, before), "food consumption spends finite particle energy")
    check(world.nutrient_field.replenish(1.0, 0.0) == 0.0, "zero renewal cannot create new nutrient energy")
    for i in range(2050): world.record_event("cursor_test", {"index": i})
    var events: Dictionary = api.execute("events", {"after": 0})
    check(events["gap"] and events["events"].size() == 2048, "bounded event history explicitly reports gaps")
    world.queue_free()
    print("EXPERIMENT SELFTEST: ", checks, " checks; ", failed, " failures")
    return failed == 0
