extends Node

const Fixture = preload("res://game/support_test.gd")
const Terrain = preload("res://game/support_test_terrain.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        printerr("SELFTEST ERROR: posture: ", label)

func run_all() -> bool:
    var fixture = Fixture.new()
    add_child(fixture)
    for profile in [3, 4]:
        var terrain = Terrain.new()
        terrain.profile = profile
        terrain.waterline = 0.0 if profile == 4 else -100.0
        var org = fixture.creature()
        org.contact_quality = 85
        org.habitat = terrain
        org.global_position = Vector3(0, 12, 0)
        var late_low: float = INF
        var late_high: float = -INF
        for tick in range(280):
            org.motion_step(0.05, 144.0)
            check(fixture.gaps(org).x >= -0.06, "ridge/shore structural contact does not penetrate terrain")
            if tick >= 240:
                late_low = minf(late_low, org.global_position.y)
                late_high = maxf(late_high, org.global_position.y)
        check(late_high - late_low < 0.08, "ridge/shore posture settles without oscillation")
        check(fixture.gaps(org).y < 0.90, "long body follows a sharp ridge or steep shore instead of bridging high above it")
        var forward_frame: Vector3 = org.visual.posed_bases[0].z
        var relative_bend: float = 0.0
        for i in org.visual.collision_cells:
            relative_bend = maxf(relative_bend, forward_frame.distance_to(org.visual.posed_bases[i].z))
        check(relative_bend > 0.40, "individual body segments bend independently of root orientation")
        if profile == 4:
            var head: Vector3 = org.global_position + org.global_transform.basis * org.visual.get_focus_anchor_local()
            check(head.y < terrain.waterline + 0.5 and org.submerged_fraction > 0.05, "unsupported anterior body returns to water while tail remains on shore")
        org.queue_free()

    var swimmer = fixture.creature()
    swimmer.in_water = true
    swimmer.genome.muscle_drive = 0.85
    swimmer.visual.rebuild(true)
    swimmer.turn_pitch_speed = 0.6
    for tick in range(20): swimmer.visual.animate_life(0.05)
    var bent: int = 0
    var angles: Array[float] = []
    for cell in swimmer.visual.body_cells:
        angles.append(float(cell["vertical_angle"]))
        if absf(float(cell["vertical_angle"])) > 0.03: bent += 1
    check(bent >= 4, "vertical swimming turns propagate into multiple trailing joints")
    swimmer.turn_pitch_speed = -0.6
    swimmer.visual.animate_life(0.05)
    for i in range(angles.size()):
        check(absf(float(swimmer.visual.body_cells[i]["vertical_angle"]) - angles[i]) <= 0.030001, "reversing swim pitch does not snap joint angles")
    swimmer.turn_pitch_speed = 0.0
    for tick in range(40): swimmer.visual.animate_life(0.05)
    for cell in swimmer.visual.body_cells:
        check(absf(float(cell["vertical_angle"])) < 0.001, "trailing joints relax once the turn ends")
    swimmer.queue_free()

    var coated = fixture.creature()
    var g = coated.genome
    g.seed = 39
    g.limb_drive = 0.95
    g.muscle_drive = 0.85
    g.support_drive = 0.8
    g.horn_drive = 0.9
    g.beak_drive = 0.9
    g.fur_cover = 0.0
    g.scale_cover = 0.0
    g.feather_cover = 0.0
    g.membrane_cover = 0.0
    g.mucus_cover = 0.0
    coated.visual.rebuild(true)
    var visual = coated.visual
    var beaks: int = 0
    var horns: int = 0
    var hidden: int = 0
    for i in range(visual.body_cells.size()):
        var cell: Dictionary = visual.body_cells[i]
        var parent: int = int(cell["parent"])
        if int(cell["t"]) == 18:
            beaks += 1
            check(parent >= 0 and visual.body_cells[parent]["p"].distance_to(visual.focus_anchor_local) < 0.10, "beak attaches to the head rather than a remote coat sample")
        if int(cell["t"]) == 17 and horns < 3:
            horns += 1
            check(parent >= 0 and visual.body_cells[parent]["p"].distance_to(visual.focus_anchor_local) < 0.10, "first cranial horn attaches to the head")
        if int(cell["t"]) in [20, 21]:
            hidden += 1
            check(float(visual.link_radii[i]) == 0.0, "hidden anatomy has no needle-thin visible connector")
            check(int(visual.link_slots[i]) == -1, "hidden connectors have no render slot or exported instance")
            check(absf(visual.render_transforms[i].basis.determinant()) < 0.00000001, "hidden tissue is also omitted from body export")
    check(beaks == 2 and horns == 3 and hidden >= 2, "regression fixture contains cranial appendages and internal anatomy")
    check(visual.links_instance.multimesh.instance_count == visual.link_transforms.size(), "only active connectors are allocated")
    var next_slot: int = 0
    for i in range(visual.body_cells.size()):
        if float(visual.link_radii[i]) > 0.0:
            check(int(visual.link_slots[i]) == next_slot, "visible connectors use contiguous render slots")
            next_slot += 1
        else:
            check(int(visual.link_slots[i]) == -1, "every zero-radius connector is absent")
    check(next_slot == visual.link_transforms.size(), "connector buffer has no unused tail instances")
    var exported_links: Array = visual.get_export_transforms(true)
    check(exported_links.size() == next_slot, "OBJ export contains every visible connector and no hidden connector")
    var exported_body: Array = visual.get_export_transforms(false)
    check(exported_body.size() == visual.body_cells.size() - hidden, "OBJ export excludes internal anatomy in natural view")
    coated.in_water = true
    coated.turn_pitch_speed = 0.7
    for tick in range(20): visual.animate_life(0.05)
    var index: int = visual.focus_anchor_index
    var expected: Vector3 = visual.posed_cells[index] + visual.posed_bases[index] * (visual.focus_anchor_local - visual.body_cells[index]["p"])
    check(visual.get_focus_anchor_local().distance_to(expected) < 0.00001, "mouth/follow/tool anchor follows the articulated head")
    visual.set_view_mode("cell")
    for i in range(visual.body_cells.size()):
        if int(visual.body_cells[i]["t"]) in [20, 21]:
            check(visual.render_scales[i] != Vector3.ZERO, "scientific cell view still exposes internal anatomy")
    var cell_export: Array = visual.get_export_transforms(false)
    check(cell_export.size() == visual.body_cells.size(), "cell-view OBJ export includes internal anatomy")
    visual.set_view_mode("natural")
    check(visual.get_export_transforms(false).size() == visual.body_cells.size() - hidden, "view round trip removes hidden tissue again")
    check(visual.links_instance.multimesh.instance_count == visual.link_transforms.size(), "view round trip resizes connector allocation")
    coated.queue_free()
    fixture.queue_free()
    print("POSTURE SELFTEST: ", checks, " checks; ", failures, " failures")
    return failures == 0
