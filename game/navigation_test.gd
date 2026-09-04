extends Node

const Fixture = preload("res://game/interaction_test.gd")
const Terrain = preload("res://game/support_test_terrain.gd")
const PairWorld = preload("res://game/reproduction_test_world.gd")
const Food = preload("res://game/nutrient_field.gd")
const Navigation = preload("res://game/navigation.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        printerr("SELFTEST ERROR: navigation: ", label)

func run_all() -> bool:
    var fixture = Fixture.new()
    add_child(fixture)
    var terrain = Terrain.new()
    terrain.profile = 2
    terrain.ground_y = -12.0
    terrain.waterline = 20.0
    var rng = RandomNumberGenerator.new()
    rng.seed = 22
    for plan in [0, 1, 2]:
        var org = fixture.creature(220 + plan, plan, 80)
        org.habitat = terrain
        org.genome.gill_drive = 0.9
        org.genome.lung_drive = 0.05
        org.genome.skin_breathing = 0.05
        org.global_position = Vector3(0, -5, 0)
        org.energy = 0.60
        org.in_water = true
        org.velocity = Vector3.ZERO
        org._body_timer = -10000.0
        org.Locomotion.initialize(org, Vector3.FORWARD)
        var food = Vector3(0, -11.5, -12)
        org.food_target_index = 0
        var arrived: bool = false
        for tick in range(360):
            org.think_step(1.0 / 12.0, food, Vector3.ZERO, Vector3.ZERO, rng, 0.0)
            org.motion_step(1.0 / 12.0, terrain.half_extent)
            if Navigation.can_feed(org, food):
                arrived = true
                break
        check(arrived, "hungry body plan reaches bottom food using its mouth")
        check(org.global_position.distance_to(Vector3(0, -5, 0)) > 2.0, "feeding approach produces net translation")
        check(Navigation.can_feed(org, Navigation.mouth_position(org)), "head-local food is reachable independently of body origin")
        var mouth: Vector3 = Navigation.mouth_position(org)
        check(not Navigation.can_feed(org, mouth + Vector3.RIGHT * (Navigation.mouth_radius(org) + 1.0)), "distant food cannot be consumed")
        org.queue_free()

    var explorer = fixture.creature(230, 0, 64)
    explorer.habitat = terrain
    explorer.global_position = Vector3(0, 3, 0)
    explorer.in_water = true
    explorer.energy = 1.30
    explorer.food_target_index = -1
    explorer.velocity = Vector3.ZERO
    explorer._body_timer = -10000.0
    explorer.Locomotion.initialize(explorer, Vector3.FORWARD)
    explorer.think_step(0.05, explorer.global_position, Vector3.ZERO, Vector3.ZERO, rng, 0.0)
    var destination: Vector3 = explorer.navigation_target
    for tick in range(20):
        explorer.think_step(0.05, explorer.global_position, Vector3.ZERO, Vector3.ZERO, rng, 0.0)
        check(explorer.navigation_target.distance_to(destination) < 0.00001, "exploration waypoint persists across decision ticks")
        explorer.motion_step(0.05, terrain.half_extent)
    for tick in range(160):
        explorer.think_step(0.05, explorer.global_position, Vector3.ZERO, Vector3.ZERO, rng, 0.0)
        explorer.motion_step(0.05, terrain.half_extent)
    check(explorer.global_position.distance_to(Vector3(0, 3, 0)) > 6.0, "satiated exploration moves away from its starting place")
    explorer.energy = 0.5
    explorer.food_target_index = 3
    explorer.navigation_base_goal = "explore"
    var blocked_food: Vector3 = explorer.global_position + Vector3.FORWARD * 20.0
    for tick in range(100):
        Navigation.choose(explorer, 0.1, blocked_food, Vector3.ZERO, Vector3.ZERO, rng)
    check(explorer.navigation_replans > 0 and explorer.food_rejected_index == 3, "stationary failed approach rejects the target and replans")
    check(explorer.food_reject_timer > 0.0, "unreachable food remains on cooldown")
    explorer.desired_velocity = Vector3.RIGHT * 4.0
    explorer.behavior_state = "seek_water"
    explorer.steer_towards(explorer.global_position + Vector3(-1, 0, 0) * 10.0, 0.2)
    check(explorer.desired_velocity.x < 0.0, "urgent destination replaces an opposing food intention")
    explorer.queue_free()

    var larva = fixture.creature(240, 0, 64)
    larva.genome.metamorphosis = 0.9
    larva.genome.aquatic_larva = 0.9
    larva.genome.gill_drive = 0.0
    larva.genome.skin_breathing = 0.0
    larva.genome.lung_drive = 0.9
    larva.development_progress = 0.2
    larva.global_position = Vector3(0, 5, 0)
    var field = Food.new()
    add_child(field)
    field.habitat = terrain
    var positions: Array[Vector3] = [Vector3(0, 21, 0), Vector3(0, 5, -6), Vector3(0, 5, -100)]
    var reserves: Array[float] = [0.28, 0.28, 0.28]
    field.points = positions
    field.reserves = reserves
    check(field.nearest_for(larva, 0.1) == 1, "aquatic larva selects water food using current stage rather than adult lungs")
    larva.food_rejected_index = 1
    larva.food_reject_timer = 10.0
    check(field.nearest_for(larva, 0.1) == -1, "rejected and beyond-sensing food do not prevent exploration")
    var world = PairWorld.new()
    add_child(world)
    world.set_process(false)
    world.habitat = terrain
    var a = fixture.creature(250, 0, 64)
    var b = fixture.creature(251, 0, 64)
    for parent in [a, b]:
        parent.genome.sex_system = 0.2
        parent.genome.internal_fertilization = 0.8
        parent.genome.reproductive_anatomy = 0.8
        parent.genome.gamete_code = 0.5
        parent.genome.development_code = 0.5
        parent.genome.ensure_diploid()
        parent.behavior_state = "explore"
        parent.energy = 1.4
        parent.age_seconds = 100.0
        parent.development_progress = 1.0
        parent.oxygen = 1.0
        world.organisms.append(parent)
    a.global_position = Vector3(-5, 5, 0)
    b.global_position = Vector3(5, 5, 0)
    a.egg_reserve = 0.78
    b.sperm_reserve = 0.11
    check(world.reproduction.compatibility(a, b) > 0.0, "partner fixture is reproductively compatible")
    # dt=0 means no random courtship event can be required for approach.
    world.reproduction.step(world, 0.0, true)
    check(a.behavior_state == "seek_mate" and b.behavior_state == "seek_mate", "receptive adults actively seek compatible partners before courtship")
    check(a.desired_velocity.x > 0.0 and b.desired_velocity.x < 0.0, "partner seeking creates converging travel intentions")
    check(world.reproduction.conceptions == 0, "partner seeking alone cannot bypass fertilization requirements")
    a.behavior_state = "seek_water"
    a.desired_velocity = Vector3.FORWARD
    world.reproduction.step(world, 0.0, true)
    check(a.behavior_state == "seek_water" and a.desired_velocity == Vector3.FORWARD, "respiration escape outranks partner seeking")
    world.organisms.clear()
    a.queue_free()
    b.queue_free()
    world.queue_free()
    field.queue_free()
    larva.queue_free()
    fixture.queue_free()
    print("NAVIGATION SELFTEST: ", checks, " checks; ", failures, " failures")
    return failures == 0
