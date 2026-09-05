extends Node

const Solver = preload("res://game/follow_camera_solver.gd")
const Terrain = preload("res://game/support_test_terrain.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, label: String) -> void:
    checks += 1
    if condition:
        print("CAMERA OK: ", label)
    else:
        failures += 1
        printerr("SELFTEST ERROR: camera: ", label)

func run_all() -> bool:
    var terrain = Terrain.new()
    terrain.profile = 3
    var focus: Vector3 = Vector3(0.0, terrain.floor_at(Vector3(0.0, 0.0, -4.0)) + 0.6, -4.0)
    var desired: Vector3 = Vector3(0.0, 1.0, 10.0)
    var clearance: float = Solver.clearance_for_body(8.0)
    var safe: Vector3 = Solver.safe_position(terrain, focus, desired, clearance)
    check(safe.y > desired.y + 2.0, "ridge obstruction raises follow camera")
    check(Solver.path_is_clear(terrain, focus, safe, clearance), "ridge-safe position has a clear terrain sightline")
    check(safe.y >= terrain.floor_at(safe) + clearance - 0.002, "camera endpoint remains above terrain")

    terrain.profile = 4
    focus = Vector3(0.0, terrain.floor_at(Vector3(0.0, 0.0, -5.0)) + 0.8, -5.0)
    desired = Vector3(0.0, 0.0, 5.0)
    safe = Solver.safe_position(terrain, focus, desired, clearance)
    check(Solver.path_is_clear(terrain, focus, safe, clearance), "steep slope cannot contain follow camera or sightline")

    terrain.profile = 2
    terrain.ground_y = -3.0
    focus = Vector3(0.0, 1.0, 0.0)
    desired = Vector3(0.0, 4.0, 8.0)
    safe = Solver.safe_position(terrain, focus, desired, clearance)
    check(safe.distance_to(desired) < 0.002, "already safe camera placement is unchanged")
    check(Solver.clearance_for_body(40.0) > Solver.clearance_for_body(2.0), "large organisms receive more camera clearance")
    print("CAMERA SELFTEST: ", checks, " checks; ", failures, " failures")
    return failures == 0
