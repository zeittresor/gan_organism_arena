extends Node

const Life = preload("res://game/organism.gd")
const Genome = preload("res://game/genome.gd")
const Terrain = preload("res://game/support_test_terrain.gd")
const Support = preload("res://game/body_support.gd")
const Contact = preload("res://game/body_contact.gd")
var checks: int = 0
var failures: int = 0
var test_gravity: float = 1.0

func _setting(key: String, fallback):
    return test_gravity if key == "gravity_scale" else fallback

func check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        printerr("SELFTEST ERROR: support: ", label)

func creature():
    var g = Genome.new()
    g.seed = 810
    g.body_plan = 0
    g.limb_drive = 0.0
    g.limb_length = 0.85
    g.branch_drive = 0.8
    g.sex_system = 0.9
    g.muscle_drive = 0.0
    g.wood_drive = 0.0
    g.armor_drive = 0.1
    g.tail_drive = 0.8
    g.head_drive = 0.4
    var org = Life.new()
    add_child(org)
    org.initialize(810, g, Vector3(0, 5, 0), 160, "natural")
    org.development_progress = 1.0
    org.complexity = 60.0
    org.energy = 1.4
    org.velocity = Vector3.ZERO
    org.desired_velocity = Vector3.ZERO
    org.in_water = false
    org.visual.rebuild(true)
    org.Locomotion.initialize(org, Vector3.FORWARD)
    return org

func gaps(org) -> Vector3:
    var smallest: float = INF
    var total: float = 0.0
    var largest: float = -INF
    for i in org.visual.collision_cells:
        var cell: Dictionary = org.visual.body_cells[i]
        var p: Vector3 = org.global_position + org.global_transform.basis * org.visual.posed_cells[i]
        var ext: Vector3 = cell["s"] * float(cell["r"])
        var frame: Basis = org.global_transform.basis * org.visual.posed_bases[i]
        var radius: float = Vector3(frame.x.y * ext.x, frame.y.y * ext.y, frame.z.y * ext.z).length()
        var gap: float = p.y - radius - org.habitat.floor_at(p)
        smallest = minf(smallest, gap)
        largest = maxf(largest, gap)
        total += gap
    return Vector3(smallest, total / maxf(1.0, org.visual.collision_cells.size()), largest)

func run_all() -> bool:
    for quality in [85, 100]:
        var terrain = Terrain.new()
        terrain.profile = 1
        var org = creature()
        var rigid = creature()
        org.habitat = terrain
        rigid.habitat = terrain
        org.contact_quality = quality
        rigid.contact_quality = quality
        # Control: same terrain sensing/orientation, locked vertical joints.
        rigid._body_timer = -1000.0
        for cell in rigid.visual.body_cells: cell["vertical_limit"] = 0.0
        var late_min: float = INF
        var late_max: float = -INF
        for tick in range(240):
            org.motion_step(0.05, 144.0)
            rigid.motion_step(0.05, 144.0)
            check(gaps(org).x >= -0.06, "structural body stays above uneven terrain")
            if tick >= 180:
                late_min = minf(late_min, org.global_position.y)
                late_max = maxf(late_max, org.global_position.y)
        check(org.global_position.y < 3.0, "unsupported long body falls to terrain")
        check(late_max - late_min < 0.08, "settled spine does not oscillate or jack the body upward")
        check(gaps(org).y < gaps(rigid).y * 0.90, "vertical articulation follows terrain more closely than a locked spine")
        var bent: bool = false
        for i in range(1, org.visual.body_cells.size()):
            var cell: Dictionary = org.visual.body_cells[i]
            var parent: int = int(cell["parent"])
            check(absf(float(cell["vertical_angle"])) <= float(cell["vertical_limit"]) + 0.000001, "passive joint respects its anatomical limit")
            if absf(float(cell["vertical_angle"])) > 0.03: bent = true
            if bool(cell.get("eye_surface", false)): continue
            var offset: Vector3 = cell["p"] - org.visual.body_cells[parent]["p"]
            var fraction: float = float(cell["joint_pivot"])
            var pivot: Vector3 = org.visual.posed_cells[parent] + org.visual.posed_bases[parent] * offset * fraction
            check(absf(org.visual.posed_cells[i].distance_to(pivot) - offset.length() * (1.0 - fraction)) < 0.00001, "ground conformance preserves connected rigid segment lengths")
            if int(cell["t"]) == 2:
                check(not cell["joint"] and float(cell["vertical_angle"]) == 0.0, "bone does not bend internally")
                check((org.visual.posed_bases[i].x - org.visual.posed_bases[parent].x).length() < 0.00001, "bone follows its supporting frame")
        check(bent, "external load bends existing joints even without active muscles")
        var previous: Array = org.visual.posed_cells.duplicate()
        org.visual.rebuild(true)
        for i in range(previous.size()):
            check(previous[i].distance_to(org.visual.posed_cells[i]) < 0.00001, "rebuild retains passive spine posture")
        org.queue_free()
        rigid.queue_free()

    var water = Terrain.new()
    water.profile = 2
    water.ground_y = -50.0
    water.waterline = 0.0
    var swimmer = creature()
    swimmer.habitat = water
    swimmer.global_position = Vector3(0, -10, 0)
    Support.update(swimmer, 0.0, true)
    check(swimmer.submerged_fraction > 0.999, "deep water supports all structural volume")
    swimmer.global_position.y = 0.0
    Support.update(swimmer, 0.0, true)
    check(swimmer.submerged_fraction > 0.05 and swimmer.submerged_fraction < 0.95, "surface crossing uses fractional immersion")
    swimmer.velocity = Vector3.ZERO
    Support.gravity(swimmer, 0.1)
    check(swimmer.velocity.y < -0.05, "partial immersion cannot support the whole dry overhang")
    swimmer.global_position.y = 10.0
    swimmer.in_water = true # Deliberately stale center-based habitat classification.
    Support.update(swimmer, 0.0, true)
    check(swimmer.submerged_fraction < 0.001, "dry anatomy loses buoyancy despite stale water flag")
    swimmer.velocity = Vector3.ZERO
    test_gravity = 0.5
    Support.gravity(swimmer, 0.1)
    var weak: float = swimmer.velocity.y
    swimmer.velocity = Vector3.ZERO
    test_gravity = 2.0
    Support.gravity(swimmer, 0.1)
    check(absf(weak + 0.49) < 0.00001 and absf(swimmer.velocity.y - weak * 4.0) < 0.00001, "gravity setting changes acceleration live")
    swimmer.rooted = true
    swimmer.velocity = Vector3.ZERO
    Support.gravity(swimmer, 0.1)
    check(swimmer.velocity == Vector3.ZERO, "root anchorage remains fixed")
    swimmer.rooted = false
    test_gravity = 1.0
    var samples: int = swimmer.support_samples
    Support.update(swimmer, 0.001)
    check(swimmer.support_samples == samples, "unchanged support sensing is cached")
    water.revision += 1
    Support.update(swimmer, 0.0)
    check(swimmer.support_samples == samples + 1, "terrain revision invalidates support sensing")
    swimmer.genome.metamorphosis = 0.9
    swimmer.genome.armor_drive = 0.5
    swimmer.genome.size_gene = 0.3
    swimmer.development_progress = 0.7
    swimmer.in_water = false
    swimmer.velocity = Vector3.ZERO
    swimmer.motion_step(0.1, 144.0)
    swimmer.motion_step(0.1, 144.0)
    check(swimmer.Cycle.stage(swimmer) == "pupa" and absf(swimmer.velocity.y + 1.96) < 0.00001, "unsupported pupa retains gravitational acceleration")
    swimmer.development_progress = 1.0
    swimmer.genome.muscle_drive = 0.8
    swimmer.genome.flight_drive = 0.5
    swimmer.genome.wing_area = 0.8
    swimmer.genome.support_drive = 0.8
    swimmer.genome.light_skeleton = 0.6
    swimmer.genome.armor_drive = 0.1
    swimmer.genome.shell_drive = 0.0
    swimmer.genome.horn_drive = 0.0
    swimmer.genome.skin_thickness = 0.1
    swimmer.genome.feather_cover = 0.0
    swimmer.genome.membrane_cover = 0.0
    swimmer.can_fly = true
    swimmer.airborne = true
    check(Support.flying(swimmer), "sufficient lift supports a powered flyer")
    test_gravity = 2.5
    check(not Support.flying(swimmer), "stronger gravity requires more lift even before ecology refresh")
    test_gravity = 1.0
    swimmer.genome.muscle_drive = 0.0
    check(not Support.flying(swimmer), "unpowered anatomy cannot hover on an airborne flag")
    swimmer.queue_free()

    var shapes: Array = []
    Contact.append_sphere(shapes, Vector3.ZERO, 2.0)
    Contact.append_sphere(shapes, Vector3.RIGHT * 0.5, 0.5)
    check(shapes.size() == 1, "contained collision sphere adds no occupied volume")
    Contact.append_sphere(shapes, Vector3.RIGHT * 3.0, 2.0)
    check(shapes.size() == 2, "partially overlapping collision sphere is retained")
    Contact.append_sphere(shapes, Vector3.ZERO, 6.0)
    check(shapes.size() == 1 and float(shapes[0]["r"]) == 6.0, "larger sphere replaces only wholly enclosed shapes")

    var store = preload("res://game/settings_store.gd").new()
    for value in [0.2, 0.5, 1.0, 2.5]:
        var profile: Dictionary = store.validate_profile({"gravity_scale": value})
        check(profile.has("settings") and profile["settings"]["gravity_scale"] == value, "gravity survives validated settings profiles")
    for value in [0.0, 2.6, true, "1.0"]:
        check(store.validate_profile({"gravity_scale": value}).has("error"), "invalid gravity profile rejected")
    store.free()
    print("SUPPORT SELFTEST: ", checks, " checks; ", failures, " failures")
    return failures == 0
