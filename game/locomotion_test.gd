extends Node

const Fixture = preload("res://game/interaction_test.gd")
const Motion = preload("res://game/locomotion.gd")
const Rig = preload("res://game/anatomical_rig.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        printerr("SELFTEST ERROR: locomotion: ", label)

func run_all() -> bool:
    var fixture = Fixture.new()
    add_child(fixture)
    var org = fixture.creature(800)
    org.in_water = true
    org.global_position = Vector3.ZERO
    Motion.initialize(org, Vector3.FORWARD)
    org.velocity = Vector3.FORWARD * 3.0
    var dt: float = 1.0 / 60.0
    var sideways: float = 0.0
    var turn_sign: float = 0.0
    for tick in range(480):
        org.desired_velocity = Vector3(0.02 if tick % 2 == 0 else -0.02, 0.0, 3.0)
        var yaw: float = org.heading_yaw
        var velocity: Vector3 = org.velocity
        Motion.step(org, dt, 1000.0)
        check(absf(wrapf(org.heading_yaw - yaw, -PI, PI)) <= Motion.turn_limit(org) * dt + 0.000001, "bounded body rotation through a reversal")
        check(org.velocity.distance_to(velocity) <= Motion.acceleration_limit(org) * dt + 0.000001, "bounded propulsion acceleration")
        if tick == 8: turn_sign = signf(org.turn_yaw_speed)
        if tick > 8 and tick < 60: check(signf(org.turn_yaw_speed) == turn_sign, "antipodal target does not alternate turn sides")
        org.global_position += org.velocity * dt
        sideways = maxf(sideways, absf(org.global_position.x))
    check(Motion.forward(org.heading_yaw, org.heading_pitch).dot(Vector3(0, 0, 1)) > 0.97, "U-turn eventually reaches the new heading")
    check(sideways > 0.6, "reversal describes a curve instead of an instant central flip")
    Motion.initialize(org, Vector3.FORWARD)
    org.desired_velocity = Vector3.FORWARD * 2.0
    org.velocity = Vector3(5.0, 0.0, 2.0)
    Motion.step(org, dt, 1000.0)
    check(absf(org.heading_yaw) < 0.00001, "contact velocity cannot redirect the steering heading")
    for tick in range(120):
        org.desired_velocity = Vector3(0.001 if tick % 2 == 0 else -0.001, 3.0, 0.001)
        Motion.step(org, dt, 1000.0)
        check(absf(org.heading_yaw) < 0.00001 and absf(org.heading_pitch) <= 1.10001, "near-vertical swimming has a stable azimuth and pitch limit")
    Motion.initialize(org, Vector3.FORWARD)
    org.in_water = false
    org.velocity = Vector3(0, -20, -1)
    org.desired_velocity = Vector3(0, 20, -3)
    Motion.step(org, dt, 1000.0)
    check(org.heading_pitch == 0.0 and org.velocity.y == -20.0, "gravity does not pitch a grounded body or become propulsion")
    org.in_water = true
    org.genome.muscle_drive = 0.0
    org.velocity = Vector3.ZERO
    org.desired_velocity = Vector3(3, 0, 0)
    Motion.step(org, 0.5, 1000.0)
    check(org.velocity == Vector3.ZERO and org.heading_yaw == 0.0, "no active propulsion or turning without muscles")
    org.genome.muscle_drive = 0.85

    var visual = org.visual
    visual._animation_time = 100000.0
    visual.gait_phase = 1.0
    org.velocity = Vector3.ZERO
    visual.animate_life(0.05)
    var phase: float = visual.gait_phase
    org.velocity = Vector3(10, 0, 0)
    visual.animate_life(0.05)
    check(fposmod(visual.gait_phase - phase, TAU) <= 0.30001, "gait phase stays continuous after long runtime and a speed jump")

    for plan in range(7):
        var life = fixture.creature(820 + plan, plan, 120)
        life.genome.support_drive = 0.40 if plan in [2, 6] else 0.8
        life.genome.armor_drive = 0.10 if plan in [2, 6] else 0.65
        life.visual.rebuild(true)
        var rig = life.visual
        check(rig.anatomy_counts["active"] > 0, "each motile body plan has muscle-driven articulation")
        if plan in [2, 6]: check(rig.anatomy_counts["hydrostat"] > 0, "soft-bodied lineages have muscular hydrostats")
        for tick in range(20):
            life.velocity = Vector3(2, 0, 0)
            rig.animate_life(0.05)
        var pose_before: Array = rig.posed_cells.duplicate()
        rig.rebuild(true)
        for i in range(rig.body_cells.size()):
            check(rig.posed_cells[i].distance_to(pose_before[i]) < 0.00001, "compatible rebuild preserves joint pose instead of snapping to rest")
        var rigid_shaft: bool = false
        for i in range(1, rig.body_cells.size()):
            var cell: Dictionary = rig.body_cells[i]
            var parent: int = int(cell["parent"])
            check(absf(float(cell["joint_angle"])) <= float(cell["joint_limit"]) + 0.000001, "joint stays within anatomical range")
            if int(cell["t"]) in [2, 12, 13, 17, 18, 19, 26]:
                check(not cell["joint"], "bone and hard attached tissues do not flex internally")
            if not cell["joint"] and not bool(cell.get("eye_surface", false)):
                var expected: Vector3 = rig.posed_cells[parent] + rig.posed_bases[parent] * (cell["p"] - rig.body_cells[parent]["p"])
                check(rig.posed_cells[i].distance_to(expected) < 0.00001, "rigid attachment follows the parent frame exactly")
                check((rig.posed_bases[i].x - rig.posed_bases[parent].x).length() < 0.00001, "bone frame cannot rotate independently of its rigid parent")
                if int(cell.get("chain_index", -1)) > 0: rigid_shaft = true
        if plan == 5: check(rigid_shaft, "jointed legs contain rigid shafts between hinges")
        life.genome.muscle_drive = 0.0
        rig.rebuild(true)
        var before: Array = rig.posed_cells.duplicate()
        life.velocity = Vector3(4, 0, 0)
        rig.animate_life(0.2)
        for i in range(rig.body_cells.size()):
            check(rig.posed_cells[i].distance_to(before[i]) < 0.00001, "passive transport cannot animate unpowered tissue")
        life.queue_free()

    var model = preload("res://game/habitat_model.gd").new()
    model.configure(7, 144.0)
    var food = preload("res://game/nutrient_field.gd").new()
    add_child(food)
    food.habitat = model
    # A dynamically accessed typed property does not type an Array literal.
    # Construct the typed array first, just as for habitat resource positions.
    var food_points: Array[Vector3] = [Vector3(3, -5, 0), Vector3(-3.05, -5, 0)]
    food.points = food_points
    food.reserves = [0.28, 0.28]
    org.global_position = Vector3(0, -5, 0)
    check(food.nearest_for(org, 0.1) == 0, "food acquisition")
    org.global_position.x = -0.1
    check(food.nearest_for(org, 0.1) == 0, "small distance changes do not switch a food target")
    check(food.nearest_for(org, 1.0) == 0, "food hysteresis persists after reconsideration")
    org.global_position.x = -2.0
    check(food.nearest_for(org, 1.0) == 1, "a substantially better food target can replace the old one")
    food.reserves[1] = 0.0
    check(food.nearest_for(org, 0.01) == 0, "consumed food is invalidated immediately")
    food.queue_free()
    org.queue_free()
    fixture.queue_free()
    print("LOCOMOTION SELFTEST: ", checks, " checks; ", failures, " failures")
    return failures == 0
