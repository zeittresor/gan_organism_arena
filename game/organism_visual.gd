extends Node3D

enum Tissue { BODY, SKIN, SKELETON, NEURAL, SENSOR, FIN, ARMOR }

var owner_life = null
var multimesh_instance: MultiMeshInstance3D
var body_cells: Array = []
var visual_cap = 180
var view_mode = "natural"
var _last_revision = -99999

func _ready() -> void:
    multimesh_instance = MultiMeshInstance3D.new()
    add_child(multimesh_instance)
    _create_render_resources()

func _create_render_resources() -> void:
    var sphere = SphereMesh.new()
    sphere.radius = 0.30
    sphere.height = 0.60
    sphere.radial_segments = 8
    sphere.rings = 4
    var mat = StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.roughness = 0.62
    mat.metallic = 0.03
    sphere.material = mat
    var mm = MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = true
    mm.mesh = sphere
    multimesh_instance.multimesh = mm

func recreate_render_resources() -> void:
    if not multimesh_instance:
        return
    _create_render_resources()
    _last_revision = -99999
    rebuild(true)

func configure(p_owner, cap: int, mode: String) -> void:
    owner_life = p_owner
    visual_cap = maxi(48, cap)
    view_mode = mode
    rebuild(true)

func set_visual_cap(cap: int) -> void:
    visual_cap = maxi(48, cap)
    rebuild(true)

func set_view_mode(mode: String) -> void:
    view_mode = mode
    _upload()

func maybe_rebuild() -> void:
    if not owner_life:
        return
    var revision = int(floor(log(1.0 + maxf(0.0, float(owner_life.complexity))) * 7.0))
    if revision != _last_revision:
        rebuild(false)

func rebuild(force = false) -> void:
    if not owner_life or not multimesh_instance:
        return
    var c = maxf(0.0, float(owner_life.complexity))
    var revision = int(floor(log(1.0 + c) * 7.0))
    if not force and revision == _last_revision:
        return
    _last_revision = revision
    body_cells.clear()
    _develop_body(c)
    _upload()

func _develop_body(complexity: float) -> void:
    var g = owner_life.genome
    var growth = log(1.0 + complexity)
    var body_length: float = 2.4 + growth * 1.45 + float(g.elongation) * 2.8
    var body_radius: float = 0.48 + growth * 0.10 + (1.0 - float(g.elongation)) * 0.28
    var spine_count = clampi(4 + int(growth * 2.2), 4, 18)
    var spine_points: Array[Vector3] = []

    for i in range(spine_count):
        var t = float(i) / float(maxi(1, spine_count - 1))
        var z = lerpf(-body_length * 0.48, body_length * 0.52, t)
        var arch = sin(t * PI) * minf(1.1, growth * 0.12)
        var sway: float = sin(t * TAU + float(int(g.seed) % 31)) * 0.08 * float(g.branch_drive)
        var p = Vector3(sway, arch, z)
        spine_points.append(p)
        var torso_scale = 0.58 + sin(t * PI) * 0.78
        _add_cell(p, Tissue.BODY, body_radius * torso_scale)
        if complexity > 8.0:
            _add_cell(p + Vector3(0.0, 0.02, 0.0), Tissue.NEURAL, body_radius * 0.23)
        if complexity > 12.0 and i % 2 == 0:
            _add_cell(p + Vector3(0.0, -body_radius * 0.22, 0.0), Tissue.SKELETON, body_radius * 0.18)

    # Head and sensor concentration grow gradually, rather than appearing as a fixed stage.
    var front: Vector3 = spine_points[0]
    var head_scale: float = body_radius * (1.05 + float(g.sensory_drive) * 0.55 + minf(0.75, growth * 0.08))
    var head = front + Vector3(0.0, 0.14 + head_scale * 0.12, -head_scale * 0.78)
    _add_cell(head, Tissue.BODY, head_scale)
    if complexity > 3.0:
        _add_cell(head + Vector3(-head_scale * 0.48, head_scale * 0.18, -head_scale * 0.52), Tissue.SENSOR, head_scale * 0.18)
        _add_cell(head + Vector3(head_scale * 0.48, head_scale * 0.18, -head_scale * 0.52), Tissue.SENSOR, head_scale * 0.18)
    if complexity > 20.0:
        _add_chain(head + Vector3(-head_scale * 0.28, head_scale * 0.55, -head_scale * 0.25), head + Vector3(-head_scale * 0.45, head_scale * 1.45, -head_scale * 0.85), 5, Tissue.SENSOR, head_scale * 0.10)
        _add_chain(head + Vector3(head_scale * 0.28, head_scale * 0.55, -head_scale * 0.25), head + Vector3(head_scale * 0.45, head_scale * 1.45, -head_scale * 0.85), 5, Tissue.SENSOR, head_scale * 0.10)

    # Tail keeps lengthening logarithmically; it never hits a conceptual evolution ceiling.
    var tail_start: Vector3 = spine_points[spine_points.size() - 1]
    var tail_length: float = (0.8 + float(g.elongation) * 2.0) * (0.65 + growth * 0.18)
    var tail_end = tail_start + Vector3(0.0, -0.18 * tail_length, tail_length)
    _add_chain(tail_start, tail_end, clampi(4 + int(growth), 4, 12), Tissue.BODY, body_radius * 0.44)

    # Paired appendages appear as true 3D chains, not radial spikes around a sphere.
    if complexity > 5.0:
        var max_pairs = 4 if visual_cap >= 240 else 3
        var pair_count: int = clampi(1 + int(float(g.limb_drive) * (1.0 + growth * 0.52)), 1, max_pairs)
        for pair in range(pair_count):
            var frac = 0.26 + 0.52 * (float(pair) / float(maxi(1, pair_count - 1)))
            var idx = clampi(int(round(frac * float(spine_points.size() - 1))), 1, spine_points.size() - 2)
            var root: Vector3 = spine_points[idx]
            var limb_length: float = (0.95 + float(g.limb_drive) * 2.25) * (0.72 + growth * 0.12)
            var down: float = 0.35 + (1.0 - float(g.buoyancy)) * 0.75
            for side in [-1.0, 1.0]:
                var elbow = root + Vector3(side * limb_length * 0.58, -down * limb_length * 0.46, -0.12 * limb_length)
                var tip = root + Vector3(side * limb_length, -down * limb_length, 0.12 * limb_length)
                var tissue: int = Tissue.FIN if float(g.fin_drive) > float(g.limb_drive) * 1.08 else Tissue.BODY
                _add_chain(root, elbow, 3, tissue, body_radius * 0.27)
                _add_chain(elbow, tip, 3, tissue, body_radius * 0.20)
                if complexity > 16.0 and tissue != Tissue.FIN:
                    # hand / foot rays
                    var finger_count: int = clampi(2 + int(float(g.branch_drive) * 3.0 + growth * 0.18), 2, 4)
                    for finger in range(finger_count):
                        var a = (float(finger) - float(finger_count - 1) * 0.5) * 0.18
                        var finger_tip = tip + Vector3(side * (0.32 + growth * 0.025), -0.12, a * limb_length)
                        _add_chain(tip, finger_tip, 2, Tissue.BODY, body_radius * 0.075)
                elif tissue == Tissue.FIN:
                    # fin fan extends in the third dimension and becomes larger with complexity
                    var fan = 3 + int(minf(3.0, growth * 0.55))
                    for f in range(fan):
                        var angle = lerpf(-0.65, 0.65, float(f) / float(maxi(1, fan - 1)))
                        var fin_tip = tip + Vector3(side * (0.45 + growth * 0.06), sin(angle) * limb_length * 0.55, cos(angle) * limb_length * 0.50)
                        _add_chain(tip, fin_tip, 2, Tissue.FIN, body_radius * 0.065)

    # Dorsal armor / feather-like structures are different evolutionary options.
    if complexity > 10.0 and float(g.armor_drive) > 0.48:
        for i in range(1, spine_points.size() - 1, 2):
            var p: Vector3 = spine_points[i]
            var h: float = 0.32 + growth * 0.07 + float(g.armor_drive) * 0.48
            _add_chain(p, p + Vector3(0.0, h, 0.0), 3, Tissue.ARMOR, body_radius * 0.10)
    elif complexity > 18.0 and float(g.fin_drive) > 0.58:
        for i in range(1, spine_points.size() - 1, 2):
            var p: Vector3 = spine_points[i]
            var feather = 0.45 + growth * 0.08
            _add_chain(p, p + Vector3(0.0, feather, 0.18), 3, Tissue.FIN, body_radius * 0.08)

func _add_cell(pos: Vector3, tissue: int, radius: float) -> void:
    if body_cells.size() >= visual_cap:
        return
    body_cells.append({"p": pos, "t": tissue, "r": clampf(radius, 0.055, 1.6)})

func _add_chain(a: Vector3, b: Vector3, count: int, tissue: int, radius: float) -> void:
    for i in range(count):
        if body_cells.size() >= visual_cap:
            return
        var t = float(i + 1) / float(count + 1)
        _add_cell(a.lerp(b, t), tissue, radius * lerpf(1.0, 0.68, t))

func _upload() -> void:
    if not multimesh_instance or not multimesh_instance.multimesh:
        return
    var mm = multimesh_instance.multimesh
    mm.instance_count = body_cells.size()
    for i in range(body_cells.size()):
        var cell: Dictionary = body_cells[i]
        var r = float(cell["r"])
        var pos: Vector3 = cell["p"]
        var xf = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (r / 0.30)), pos)
        mm.set_instance_transform(i, xf)
        mm.set_instance_color(i, _cell_color(int(cell["t"])))

func _cell_color(tissue: int) -> Color:
    var base: Color = owner_life.genome.base_color() if owner_life else Color.WHITE
    match view_mode:
        "cell":
            match tissue:
                Tissue.SKELETON: return Color(0.92, 0.90, 0.72)
                Tissue.NEURAL: return Color(0.30, 0.85, 1.00)
                Tissue.SENSOR: return Color(1.00, 0.90, 0.28)
                Tissue.FIN: return Color(base.r * 0.55, base.g * 0.80, minf(1.0, base.b + 0.32))
                Tissue.ARMOR: return base.darkened(0.38)
                _: return base
        "neural":
            if tissue == Tissue.NEURAL or tissue == Tissue.SENSOR:
                return Color(0.25, 0.92, 1.0)
            return base.darkened(0.58)
        "energy":
            var e = clampf(float(owner_life.energy), 0.0, 1.0)
            return Color(1.0 - e * 0.72, 0.18 + e * 0.82, 0.12 + e * 0.26)
        _:
            match tissue:
                Tissue.SENSOR: return Color(0.95, 1.0, 0.70)
                Tissue.FIN: return base.lightened(0.18)
                Tissue.ARMOR: return base.darkened(0.32)
                Tissue.NEURAL: return base.lightened(0.08)
                _: return base
