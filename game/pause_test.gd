extends Node

const LifeTest = preload("res://game/life_cycle_test.gd")
const API = preload("res://game/experiment_api.gd")
const Nutrients = preload("res://game/nutrient_field.gd")
var checks: int = 0
var failed: int = 0

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failed += 1
        printerr("SELFTEST ERROR: pause: ", label)

func run_all() -> bool:
    var helper = LifeTest.new()
    add_child(helper)
    var world = helper.make_world()
    world.experiment_settings = {"auto_reseed": false, "auto_reproduce": false}
    world.nutrient_field = Nutrients.new()
    world.add_child(world.nutrient_field)
    world.nutrient_field.initialize(32, world.half_extent, 3525)
    world.nutrient_field.set_habitat(world.habitat)
    var mother = helper.make_parent(world, 2)
    var father = helper.make_parent(world, 3)
    check(world.reproduction._conceive(world, mother, father), "pause fixture has a developing embryo")
    world.advance_experiment(1)
    var before: Vector3 = mother.global_position
    var energy: float = mother.energy
    var age: float = mother.age_seconds
    var time: float = world.elapsed_sim_time
    var presentation: float = world.presentation_time
    var steps: int = world.sim_steps
    var embryo: float = world.reproduction.broods[0]["development"]
    var nutrients: float = world.nutrient_field.stored_energy()
    world.sim_accumulator = 9.0
    world.set_simulation_paused(true)
    for i in range(120): world._process(0.5)
    world._simulation_tick(60.0)
    world.advance_experiment(120)
    check(world.sim_steps == steps and is_equal_approx(world.elapsed_sim_time, time), "pause freezes world steps and simulation time")
    check(mother.global_position == before and mother.age_seconds == age and mother.energy == energy, "pause freezes motion, ageing and energy")
    check(world.reproduction.broods[0]["development"] == embryo and world.nutrient_field.stored_energy() == nutrients, "pause freezes embryos and food renewal")
    check(world.presentation_time == presentation and world.sim_accumulator == 0.0, "water/light clock freezes and pending catch-up is discarded")
    var api = API.new()
    api.configure(world)
    check(api.execute("observe", {})["paused"] and api.execute("capture", {}).has("evolution"), "paused world remains observable/exportable")
    for action in ["step", "reset", "mode", "parameters"]:
        var result: Dictionary = api.execute(action, {})
        check(result.has("error") and result.get("paused", false), "protocol cannot bypass the local pause: " + action)
    world.set_simulation_paused(false)
    world.advance_experiment(1)
    check(world.sim_steps == steps + 1 and is_equal_approx(world.elapsed_sim_time, time + 1.0 / 12.0), "resume advances exactly one requested tick without catch-up")
    check(world.reproduction.broods[0]["development"] > embryo, "existing embryos resume development after pause")
    world.experiment_mode = true
    world.set_simulation_paused(true)
    world.set_simulation_paused(false)
    check(world.experiment_mode, "pause/resume preserves deliberately selected stepped mode")
    world.queue_free()
    helper.queue_free()
    print("PAUSE SELFTEST: ", checks, " checks; ", failed, " failures")
    return failed == 0
