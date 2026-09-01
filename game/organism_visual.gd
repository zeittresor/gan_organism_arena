extends Node3D

const Traits = preload("res://game/ecology_traits.gd")
enum Tissue { BODY, SKIN, SKELETON, NEURAL, SENSOR, FIN, ARMOR, LEAF, ROOT, WING, LEG, FEATHER, QUILL, SCALE, FUR, MUCUS, MEMBRANE, HORN, BEAK, BARK }
var lowest_point: float = -0.5
var _phenotype: String = ""
var _animation_time: float = 0.0
var _animation_tick: float = 0.0
var tool_mesh: MeshInstance3D

var owner_life = null
var multimesh_instance: MultiMeshInstance3D
var body_cells: Array = []
var visual_cap = 180
var view_mode = "natural"
var _last_revision = -99999
var rear_anchor_local = Vector3(0.0, 0.0, 2.0)
var focus_anchor_local = Vector3(0.0, 0.0, -1.0)
var body_size_hint = 3.0

func _ready() -> void:
    multimesh_instance = MultiMeshInstance3D.new()
    add_child(multimesh_instance)
    _create_render_resources()
    tool_mesh = MeshInstance3D.new()
    var tool = BoxMesh.new()
    tool.size = Vector3(0.12, 0.13, 0.62)
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.75, 0.61, 0.31)
    tool.material = mat
    tool_mesh.mesh = tool
    tool_mesh.visible = false
    add_child(tool_mesh)

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
    if revision != _last_revision or _phenotype != phenotype_key():
        rebuild(true)

func rebuild(force = false) -> void:
    if not owner_life or not multimesh_instance:
        return
    var c = maxf(0.0, float(owner_life.complexity))
    var revision = int(floor(log(1.0 + c) * 7.0))
    if not force and revision == _last_revision:
        return
    _last_revision = revision
    _phenotype = phenotype_key()
    body_cells.clear()
    _develop_body(c)
    _upload()

func _develop_body(complexity: float) -> void:
    var g = owner_life.genome
    var growth: float = log(1.0 + complexity)
    var plan: int = int(g.body_plan)
    var budget: int = visual_cap
    visual_cap = maxi(24, int(budget * (0.68 if owner_life.rooted else 0.62)))
    if owner_life.rooted:
        _develop_rooted(g, growth)
    elif owner_life.stand_upright:
        _develop_upright(g, growth)
    elif g.size_gene < 0.28 and g.limb_drive > 0.55 and g.armor_drive > 0.45:
        _develop_crustacean(g, growth)
    else:
        match plan:
            1: _develop_fusiform(g, growth)
            2: _develop_radial(g, growth)
            3: _develop_ray(g, growth)
            4: _develop_branching(g, growth)
            5: _develop_crustacean(g, growth)
            6: _develop_cephalopod(g, growth)
            _: _develop_serpentine(g, growth)
    visual_cap = budget if owner_life.rooted else maxi(32, int(budget * 0.84))
    if not owner_life.rooted:
        _add_adaptive_structures(g, growth)
    visual_cap = budget
    if not owner_life.rooted:
        _add_body_coverings(g, growth)
    var size_scale: float = Traits.body_scale(g)
    lowest_point = 0.0
    for cell in body_cells:
        cell["p"] *= size_scale
        cell["r"] *= size_scale
        lowest_point = minf(lowest_point, cell["p"].y - cell["r"] * cell["s"].y)
    rear_anchor_local *= size_scale
    focus_anchor_local *= size_scale
    body_size_hint *= size_scale

func phenotype_key() -> String:
    return "%s:%s:%s" % [owner_life.rooted, owner_life.stand_upright, owner_life.in_water]

func _develop_rooted(g, growth: float) -> void:
    var tree: bool = not owner_life.in_water and g.wood_drive > 0.60 and g.support_drive > 0.55
    var height: float = (2.5 + growth * 1.3) if tree else (0.8 + growth * 0.45)
    var radius: float = 0.18 + g.support_drive * 0.18
    _add_chain(Vector3.ZERO, Vector3.UP * height, 10, Tissue.BARK if tree else Tissue.BODY, radius)
    for i in range(7):
        var angle: float = float(i) * 2.39996 + float(g.seed % 19)
        var radial = Vector3(cos(angle), 0.0, sin(angle))
        _add_chain(Vector3.ZERO, radial * (0.65 + g.root_drive) - Vector3.UP * 0.12, 3, Tissue.ROOT, radius * 0.5)
        var start = Vector3.UP * height * (0.30 + float(i) * 0.075)
        var tip = start + radial * height * (0.25 + g.branch_drive * 0.35) + Vector3.UP * height * 0.12
        _add_chain(start, tip, 3, Tissue.BARK if tree else Tissue.BODY, radius * 0.45)
        _add_cell(tip, Tissue.LEAF if g.photosynthesis > 0.5 else Tissue.FIN, 0.38 + g.photosynthesis * 0.65, Vector3(1.6, 0.35, 1.2))
    rear_anchor_local = Vector3.ZERO
    focus_anchor_local = Vector3.UP * height * 0.7
    body_size_hint = height * 0.65

func _develop_upright(g, growth: float) -> void:
    var height: float = 2.0 + growth * 0.30
    var hip = Vector3(0.0, height * 0.42, 0.0)
    var shoulder = Vector3(0.0, height * 0.86, 0.0)
    var width: float = 0.35 + g.body_width * 0.40
    _add_chain(hip, shoulder, 7, Tissue.BODY, width)
    _add_cell(hip, Tissue.SKELETON, width * 0.50, Vector3(1.4, 0.7, 0.8))
    var head = shoulder + Vector3(0.0, height * 0.20, -0.1)
    _make_head(g, head, width * (0.7 + g.head_drive * 0.5), growth)
    _add_cell(shoulder, Tissue.NEURAL, width * 0.25)
    for side_value in [-1.0, 1.0]:
        var foot = Vector3(side_value * width * 0.7, 0.0, -0.15)
        _add_chain(hip + Vector3(side_value * width * 0.55, 0.0, 0.0), foot, 6, Tissue.LEG, width * 0.27)
        _add_cell(foot, Tissue.LEG, width * 0.30, Vector3(1.0, 0.5, 1.7))
        var hand = shoulder + Vector3(side_value * width * 1.65, -height * 0.34, -width * 0.25)
        _add_chain(shoulder, hand, 5, Tissue.BODY, width * 0.18)
        for digit in range(3):
            _add_cell(hand + Vector3((digit - 1) * 0.08, -0.1, -g.manipulation * 0.20), Tissue.BODY, 0.07)
    rear_anchor_local = hip + Vector3(0.0, 0.0, width)
    focus_anchor_local = head
    body_size_hint = height

func animate_life(delta: float) -> void:
    _animation_time += delta
    _animation_tick += delta
    if tool_mesh:
        tool_mesh.visible = owner_life.tool_durability > 0.0
        tool_mesh.position = focus_anchor_local + Vector3(0.35, -0.25, 0.0)
        tool_mesh.rotation.x = sin(_animation_time * 5.0) * (0.7 if owner_life.behavior_state == "use_tool" else 0.1)
    # Animate only sparse appendages at 20 Hz, retaining the body MultiMesh.
    if _animation_tick < 0.05 or not multimesh_instance:
        return
    _animation_tick = 0.0
    var mm = multimesh_instance.multimesh
    for i in range(body_cells.size()):
        var cell: Dictionary = body_cells[i]
        var tissue: int = int(cell["t"])
        if tissue not in [Tissue.WING, Tissue.LEG, Tissue.LEAF, Tissue.FEATHER, Tissue.QUILL, Tissue.MEMBRANE]:
            continue
        var p: Vector3 = cell["p"]
        if (tissue == Tissue.WING or bool(cell.get("wing", false))) and owner_life.airborne:
            p.y += sin(_animation_time * 9.0) * absf(p.x) * 0.30
        elif tissue == Tissue.LEG and not owner_life.in_water and owner_life.velocity.length() > 0.3:
            p.z += sin(_animation_time * 7.0 + (PI if p.x < 0.0 else 0.0)) * 0.16
        elif tissue == Tissue.LEAF:
            p.x += sin(_animation_time * 1.2 + p.y) * 0.045
        var shape: Vector3 = cell["s"]
        mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(shape * (float(cell["r"]) / 0.30)), p))

func _develop_serpentine(g, growth: float) -> void:
    var body_length: float = 2.8 + growth * 1.35 + float(g.elongation) * 4.0
    var radius: float = 0.34 + growth * 0.075 + float(g.body_width) * 0.38
    var count: int = clampi(6 + int(growth * 2.1), 6, 20)
    var spine: Array[Vector3] = []
    for i in range(count):
        var t: float = float(i) / float(maxi(1, count - 1))
        var z: float = lerpf(-body_length * 0.48, body_length * 0.52, t)
        var wave: float = sin(t * TAU * (1.0 + float(g.branch_drive)) + float(int(g.seed) % 17)) * radius * 0.35
        var p = Vector3(wave * (1.0 - float(g.symmetry) * 0.55), sin(t * PI) * radius * 0.45, z)
        spine.append(p)
        var taper: float = 0.56 + sin(t * PI) * 0.72
        _add_cell(p, Tissue.BODY, radius * taper, Vector3(1.05, 0.82 + float(g.flattening) * 0.25, 1.28))
        _add_internal_tissue(p, radius, i, growth)
    var head: Vector3 = spine[0] + Vector3(0.0, radius * 0.22, -radius * (0.9 + float(g.head_drive)))
    _make_head(g, head, radius * (1.05 + float(g.head_drive) * 0.55), growth)
    var tail_start: Vector3 = spine[spine.size() - 1]
    var tail_end: Vector3 = tail_start + Vector3(0.0, -radius * 0.25, body_length * (0.18 + float(g.tail_drive) * 0.34))
    _add_chain(tail_start, tail_end, clampi(4 + int(growth), 4, 12), Tissue.BODY, radius * 0.43)
    if growth > 1.3 and float(g.limb_drive) > 0.15:
        _paired_appendages(g, spine, radius, growth, 1 + int(float(g.limb_drive) * 2.5))
    rear_anchor_local = tail_end
    focus_anchor_local = head
    body_size_hint = maxf(body_length * 0.55, 2.5)

func _develop_fusiform(g, growth: float) -> void:
    var length: float = 2.7 + growth * 0.72 + float(g.elongation) * 2.0
    var radius: float = 0.55 + float(g.body_width) * 0.72 + growth * 0.055
    var count: int = clampi(5 + int(growth * 1.15), 5, 12)
    var spine: Array[Vector3] = []
    for i in range(count):
        var t: float = float(i) / float(maxi(1, count - 1))
        var z: float = lerpf(-length * 0.42, length * 0.46, t)
        var p = Vector3(0.0, sin(t * PI) * radius * 0.12, z)
        spine.append(p)
        var torso: float = 0.72 + sin(t * PI) * 0.62
        _add_cell(p, Tissue.BODY, radius * torso, Vector3(1.30 + float(g.body_width) * 0.70, 0.92 - float(g.flattening) * 0.22, 0.82))
        if i > 0 and i < count - 1 and i % 2 == 0:
            _add_cell(p + Vector3(radius * 0.62, 0.0, 0.0), Tissue.SKELETON, radius * 0.18, Vector3(1.4, 0.6, 0.7))
            _add_cell(p + Vector3(-radius * 0.62, 0.0, 0.0), Tissue.SKELETON, radius * 0.18, Vector3(1.4, 0.6, 0.7))
        _add_internal_tissue(p, radius, i, growth)
    var head: Vector3 = spine[0] + Vector3(0.0, radius * 0.10, -radius * 1.05)
    _make_head(g, head, radius * (0.92 + float(g.head_drive) * 0.62), growth)
    _paired_appendages(g, spine, radius, growth, clampi(2 + int(float(g.limb_drive) * 1.6), 2, 4))
    var tail_start: Vector3 = spine[spine.size() - 1]
    var tail_len: float = length * (0.10 + float(g.tail_drive) * 0.30)
    var tail_end: Vector3 = tail_start + Vector3(0.0, 0.0, tail_len)
    if tail_len > 0.25:
        _add_chain(tail_start, tail_end, clampi(3 + int(growth * 0.8), 3, 9), Tissue.BODY, radius * 0.31)
    rear_anchor_local = tail_end
    focus_anchor_local = head
    body_size_hint = maxf(length * 0.50 + radius, 2.5)

func _develop_radial(g, growth: float) -> void:
    var core: float = 0.82 + float(g.body_width) * 0.85 + growth * 0.07
    _add_cell(Vector3.ZERO, Tissue.BODY, core, Vector3(1.2, 0.72 + (1.0 - float(g.flattening)) * 0.55, 1.2))
    _add_cell(Vector3(0.0, core * 0.22, -core * 0.35), Tissue.NEURAL, core * 0.25)
    var arms: int = clampi(4 + int(float(g.branch_drive) * 5.0 + growth * 0.35), 4, 10)
    var arm_len: float = (1.3 + float(g.limb_length) * 3.5) * (0.82 + growth * 0.08)
    for i in range(arms):
        var angle: float = TAU * float(i) / float(arms)
        var direction = Vector3(cos(angle), sin(angle) * (0.20 + float(g.flattening) * 0.45), sin(angle))
        direction = direction.normalized()
        var root: Vector3 = direction * core * 0.55
        var bend = Vector3(0.0, cos(angle * 2.0 + float(g.seed % 19)) * core * 0.45, 0.0)
        var tip: Vector3 = direction * arm_len + bend
        _add_chain(root, tip, clampi(4 + int(growth), 4, 11), Tissue.FIN if float(g.fin_drive) > 0.55 else Tissue.BODY, core * (0.14 + float(g.limb_thickness) * 0.12))
        if growth > 2.0 and i % 2 == 0:
            _add_cell(tip, Tissue.SENSOR, core * 0.12)
    # A small directional sensory lobe gives movement a front without imposing a spine.
    var head = Vector3(0.0, core * 0.10, -core * 1.10)
    _make_head(g, head, core * (0.42 + float(g.head_drive) * 0.32), growth)
    rear_anchor_local = Vector3(0.0, 0.0, core * 1.3)
    focus_anchor_local = head
    body_size_hint = core + arm_len * 0.55

func _develop_ray(g, growth: float) -> void:
    var length: float = 2.4 + growth * 0.58 + float(g.elongation) * 1.6
    var width: float = 2.1 + float(g.body_width) * 3.7 + growth * 0.28
    var thickness: float = 0.34 + (1.0 - float(g.flattening)) * 0.36
    var rows: int = clampi(5 + int(growth * 0.7), 5, 10)
    for row in range(rows):
        var t: float = float(row) / float(maxi(1, rows - 1))
        var z: float = lerpf(-length * 0.42, length * 0.34, t)
        var span: float = sin(t * PI) * width
        _add_cell(Vector3(0.0, 0.0, z), Tissue.BODY, thickness * 1.45, Vector3(1.9, 0.48, 1.1))
        if growth > 1.5 and row % 2 == 0:
            _add_cell(Vector3(0.0, thickness * 0.08, z), Tissue.NEURAL, thickness * 0.26, Vector3(1.5, 0.45, 1.0))
        var wing_steps: int = clampi(3 + int(span * 0.55), 3, 8)
        for side_value in [-1.0, 1.0]:
            for j in range(1, wing_steps + 1):
                var f: float = float(j) / float(wing_steps)
                var p = Vector3(side_value * span * f, -absf(side_value * span * f) * 0.035, z + f * 0.20)
                _add_cell(p, Tissue.FIN, thickness * lerpf(0.80, 0.26, f), Vector3(1.35, 0.34, 1.0))
    var head = Vector3(0.0, thickness * 0.35, -length * 0.72)
    _make_head(g, head, thickness * (1.35 + float(g.head_drive) * 0.62), growth)
    var tail_start = Vector3(0.0, 0.0, length * 0.34)
    var tail_end = Vector3(0.0, 0.0, length * (0.58 + float(g.tail_drive) * 0.72))
    _add_chain(tail_start, tail_end, clampi(5 + int(growth), 5, 13), Tissue.BODY, thickness * 0.55)
    rear_anchor_local = tail_end
    focus_anchor_local = head
    body_size_hint = maxf(width * 0.62, length * 0.62)

func _develop_branching(g, growth: float) -> void:
    var core: float = 0.64 + float(g.body_width) * 0.70 + growth * 0.055
    var trunk_len: float = 1.8 + float(g.elongation) * 2.2 + growth * 0.38
    var trunk: Array[Vector3] = []
    var segments: int = clampi(4 + int(growth), 4, 11)
    for i in range(segments):
        var t: float = float(i) / float(maxi(1, segments - 1))
        var p = Vector3(sin(t * 3.0 + float(g.seed % 7)) * core * 0.25, cos(t * 2.0) * core * 0.18, lerpf(-trunk_len * 0.42, trunk_len * 0.42, t))
        trunk.append(p)
        _add_cell(p, Tissue.BODY, core * lerpf(0.95, 0.58, absf(t - 0.5) * 1.4), Vector3(1.15, 1.0, 0.95))
        _add_internal_tissue(p, core, i, growth)
    var branch_count: int = clampi(4 + int(float(g.branch_drive) * 7.0 + growth * 0.5), 4, 12)
    for b in range(branch_count):
        var frac: float = 0.12 + 0.76 * (float(b) / float(maxi(1, branch_count - 1)))
        var idx: int = clampi(int(round(frac * float(trunk.size() - 1))), 0, trunk.size() - 1)
        var root: Vector3 = trunk[idx]
        var angle: float = float(b) * 2.399963 + float(g.seed % 23) * 0.08
        var radial = Vector3(cos(angle), sin(angle * 0.73), sin(angle)).normalized()
        var branch_len: float = (1.0 + float(g.limb_length) * 2.7) * (0.75 + growth * 0.08)
        var tip: Vector3 = root + radial * branch_len
        _add_chain(root, tip, clampi(3 + int(growth * 0.65), 3, 8), Tissue.BODY, core * (0.13 + float(g.limb_thickness) * 0.13))
        if growth > 2.2:
            var fork_axis = radial.cross(Vector3.UP)
            if fork_axis.length_squared() < 0.01:
                fork_axis = Vector3.RIGHT
            fork_axis = fork_axis.normalized()
            _add_chain(tip, tip + radial * branch_len * 0.45 + fork_axis * branch_len * 0.38, 3, Tissue.FIN if float(g.fin_drive) > 0.60 else Tissue.BODY, core * 0.10)
            _add_chain(tip, tip + radial * branch_len * 0.45 - fork_axis * branch_len * 0.38, 3, Tissue.SENSOR if float(g.sensory_drive) > 0.62 else Tissue.BODY, core * 0.10)
    var head = trunk[0] + Vector3(0.0, core * 0.20, -core * 0.70)
    _make_head(g, head, core * (0.62 + float(g.head_drive) * 0.52), growth)
    rear_anchor_local = trunk[trunk.size() - 1] + Vector3(0.0, 0.0, core)
    focus_anchor_local = head
    body_size_hint = maxf(trunk_len * 0.55, 2.5 + float(g.limb_length) * 1.5)

func _develop_crustacean(g, growth: float) -> void:
    var length: float = 2.4 + growth * 0.60 + float(g.elongation) * 1.4
    var width: float = 0.72 + float(g.body_width) * 0.95
    var segments: int = clampi(5 + int(growth * 1.15), 5, 13)
    var spine: Array[Vector3] = []
    for i in range(segments):
        var t: float = float(i) / float(maxi(1, segments - 1))
        var z: float = lerpf(-length * 0.42, length * 0.46, t)
        var p = Vector3(0.0, 0.0, z)
        spine.append(p)
        var segment_scale: float = 0.72 + sin(t * PI) * 0.45
        _add_cell(p, Tissue.ARMOR if i % 2 == 0 else Tissue.BODY, width * segment_scale, Vector3(1.50, 0.68, 0.72))
        _add_cell(p + Vector3(0.0, -width * 0.18, 0.0), Tissue.SKELETON, width * 0.16, Vector3(1.25, 0.55, 0.65))
        if growth > 1.6:
            _add_cell(p + Vector3(0.0, width * 0.08, 0.0), Tissue.NEURAL, width * 0.15)
    var leg_pairs: int = clampi(3 + int(float(g.limb_drive) * 4.0 + growth * 0.35), 3, 7)
    for pair in range(leg_pairs):
        var frac: float = 0.18 + 0.64 * float(pair) / float(maxi(1, leg_pairs - 1))
        var idx: int = clampi(int(round(frac * float(spine.size() - 1))), 1, spine.size() - 2)
        var root: Vector3 = spine[idx]
        var leg_len: float = (0.75 + float(g.limb_length) * 1.75) * (0.8 + growth * 0.05)
        for side_value in [-1.0, 1.0]:
            var knee = root + Vector3(side_value * leg_len * 0.58, -leg_len * 0.42, 0.0)
            var tip = root + Vector3(side_value * leg_len, -leg_len * 0.80, -leg_len * 0.12)
            _add_chain(root, knee, 2, Tissue.LEG, width * (0.11 + float(g.limb_thickness) * 0.10))
            _add_chain(knee, tip, 2, Tissue.LEG, width * 0.10)
    var head = spine[0] + Vector3(0.0, width * 0.08, -width * 0.92)
    _make_head(g, head, width * (0.82 + float(g.head_drive) * 0.45), growth)
    var tail_start = spine[spine.size() - 1]
    var tail_end = tail_start + Vector3(0.0, 0.0, length * (0.18 + float(g.tail_drive) * 0.22))
    _add_chain(tail_start, tail_end, 4, Tissue.ARMOR, width * 0.28)
    rear_anchor_local = tail_end
    focus_anchor_local = head
    body_size_hint = maxf(length * 0.55, width * 2.0)

func _develop_cephalopod(g, growth: float) -> void:
    var head_radius: float = 0.90 + float(g.head_drive) * 1.15 + growth * 0.075
    var mantle_center = Vector3(0.0, 0.0, 0.45)
    _add_cell(mantle_center, Tissue.BODY, head_radius, Vector3(1.10 + float(g.body_width) * 0.55, 1.05, 1.25))
    _add_cell(mantle_center + Vector3(0.0, head_radius * 0.10, -head_radius * 0.28), Tissue.NEURAL, head_radius * 0.32)
    var face = Vector3(0.0, 0.0, -head_radius * 0.78)
    _add_cell(face + Vector3(-head_radius * 0.42, head_radius * 0.12, 0.0), Tissue.SENSOR, head_radius * 0.16)
    _add_cell(face + Vector3(head_radius * 0.42, head_radius * 0.12, 0.0), Tissue.SENSOR, head_radius * 0.16)
    var tentacles: int = clampi(5 + int(float(g.branch_drive) * 5.0 + growth * 0.35), 5, 10)
    var tentacle_len: float = (1.4 + float(g.limb_length) * 3.8) * (0.76 + growth * 0.075)
    for i in range(tentacles):
        var angle: float = TAU * float(i) / float(tentacles)
        var root = Vector3(cos(angle) * head_radius * 0.45, sin(angle) * head_radius * 0.30, -head_radius * 0.42)
        var side = Vector3(cos(angle), sin(angle) * 0.65, -0.75).normalized()
        var curl = Vector3(sin(angle * 2.0), cos(angle * 1.5), 0.0) * tentacle_len * 0.18
        var tip = root + side * tentacle_len + curl
        _add_chain(root, tip, clampi(5 + int(growth), 5, 13), Tissue.BODY, head_radius * (0.10 + float(g.limb_thickness) * 0.08))
        if growth > 2.4 and i % 2 == 0:
            _add_cell(tip, Tissue.SENSOR, head_radius * 0.08)
    rear_anchor_local = mantle_center + Vector3(0.0, 0.0, head_radius * 1.25)
    focus_anchor_local = face
    body_size_hint = maxf(head_radius * 1.7, tentacle_len * 0.45)


func _add_adaptive_structures(g, growth: float) -> void:
    var center: Vector3 = focus_anchor_local.lerp(rear_anchor_local, 0.48)
    var size: float = maxf(0.45, body_size_hint * 0.22)
    # Wings are broad, sparse appendages rather than another worm-like chain.
    if Traits.flight_body(g) and growth > 1.0:
        var span: float = size * (1.8 + float(g.flight_drive) * 3.6)
        for side_value in [-1.0, 1.0]:
            var root = center + Vector3(side_value * size * 0.35, size * 0.12, 0.0)
            var tip = center + Vector3(side_value * span, size * 0.42, size * 0.22)
            _add_chain(root, tip, 5, Tissue.WING, size * 0.16)
            for ray in range(3):
                var rt = tip + Vector3(0.0, -size * (0.25 + ray * 0.18), size * (ray - 1) * 0.30)
                _add_chain(root, rt, 3, Tissue.WING, size * 0.08)
    # Terrestrial adaptation creates load-bearing paired legs below the body.
    if Traits.walking(g) > 0.20 and growth > 0.8 and not owner_life.stand_upright:
        var leg_len: float = size * (1.2 + float(g.limb_length) * 2.4)
        for zoff in [-size * 0.75, size * 0.55]:
            for side_value in [-1.0, 1.0]:
                var hip = center + Vector3(side_value * size * 0.48, -size * 0.15, zoff)
                var foot = hip + Vector3(side_value * size * 0.28, -leg_len, size * 0.12)
                _add_chain(hip, foot, 4, Tissue.LEG, size * 0.12)
    if g.cleaning_drive > 0.66 or g.parasite_drive > 0.72:
        _add_cell(focus_anchor_local + Vector3(0.0, -size * 0.2, -size * 0.3), Tissue.SKIN, size * 0.28, Vector3(1.6, 0.35, 1.0))
    if Traits.tools(g):
        for side_value in [-1.0, 1.0]:
            var hand = focus_anchor_local + Vector3(side_value * size * 0.9, -size * 0.3, 0.0)
            _add_chain(center, hand, 3, Tissue.BODY, size * 0.10)
            for digit in range(3):
                _add_cell(hand + Vector3((digit - 1) * size * 0.16, 0.0, -size * 0.25), Tissue.BODY, size * 0.06)
    # Aquatic specialists can evolve a caudal fan even when their base topology is radial/branching.
    if float(g.aquatic_drive) > 0.62 and float(g.fin_drive) > 0.42:
        var rear = rear_anchor_local
        var fan: float = size * (0.8 + float(g.fin_drive) * 1.8)
        _add_chain(rear, rear + Vector3(fan, fan * 0.65, fan * 0.18), 3, Tissue.FIN, size * 0.10)
        _add_chain(rear, rear + Vector3(-fan, fan * 0.65, fan * 0.18), 3, Tissue.FIN, size * 0.10)

func _add_body_coverings(g, growth: float) -> void:
    var samples: Array = []
    var wings: Array = []
    # Modify the outer soft tissue itself, avoiding a detached shell around the body.
    for cell in body_cells:
        if int(cell["t"]) == Tissue.BODY:
            cell["t"] = Tissue.SKIN
            cell["r"] *= 1.0 + float(g.skin_thickness) * 0.14
            samples.append(cell.duplicate())
        elif int(cell["t"]) == Tissue.WING:
            wings.append(cell.duplicate())
    if samples.is_empty():
        return
    var kinds: Array[int] = []
    if g.feather_cover > 0.45: kinds.append(Tissue.FEATHER)
    if g.scale_cover > 0.48: kinds.append(Tissue.SCALE)
    if g.fur_cover > 0.50: kinds.append(Tissue.FUR)
    if g.mucus_cover > 0.55: kinds.append(Tissue.MUCUS)
    if g.membrane_cover > 0.55: kinds.append(Tissue.MEMBRANE)
    if g.horn_drive > 0.55 and g.support_drive > 0.35: kinds.append(Tissue.HORN)
    if g.beak_drive > 0.55: kinds.append(Tissue.BEAK)
    if kinds.is_empty():
        return
    # Cycle through kinds before spending more on any one covering. This keeps
    # mixed coats visible at the default budget, rather than dropping late types.
    for i in range(48):
        if body_cells.size() >= visual_cap:
            break
        var kind: int = kinds[i % kinds.size()]
        var sample: Dictionary = samples[(i + int(g.seed % samples.size())) % samples.size()]
        if kind in [Tissue.FEATHER, Tissue.MEMBRANE] and not wings.is_empty():
            sample = wings[i % wings.size()]
        var p: Vector3 = sample["p"]
        var radius: float = float(sample["r"])
        var shape: Vector3 = sample["s"]
        # Stagger patches around the upper surface even on a single-cell mantle.
        var angle: float = float(i) * 2.399963 + float(g.seed % 31) * 0.20
        var surface_direction: Vector3 = Vector3(sin(angle), 0.35 + absf(cos(angle)), 0.0).normalized()
        var skin_top: Vector3 = p + surface_direction * shape * radius * 0.93
        var length: float = (0.35 + minf(1.0, growth * 0.13)) * (0.5 + radius)
        var start: int = body_cells.size()
        match kind:
            Tissue.FEATHER:
                # Two vanes and a contrasting rachis form a layered feather.
                # Feathers can grow on body/tail before any flight anatomy exists.
                _add_cell(skin_top + Vector3(-length * 0.14, length * 0.09, length * 0.25), Tissue.FEATHER, length * 0.65, Vector3(0.26, 0.065, 0.90))
                _add_cell(skin_top + Vector3(length * 0.14, length * 0.09, length * 0.25), Tissue.FEATHER, length * 0.65, Vector3(0.26, 0.065, 0.90))
                _add_cell(skin_top + Vector3(0, length * 0.10, length * 0.22), Tissue.QUILL, length * 0.70, Vector3(0.035, 0.04, 1.0))
            Tissue.SCALE:
                _add_cell(skin_top, Tissue.SCALE, radius * 0.85, Vector3(0.75, 0.12, 0.85))
            Tissue.FUR:
                _add_cell(skin_top + Vector3(-length * 0.07, length * 0.18, 0), Tissue.FUR, length * 0.50, Vector3(0.15, 0.75, 0.13))
                _add_cell(skin_top + Vector3(length * 0.07, length * 0.12, length * 0.04), Tissue.FUR, length * 0.40, Vector3(0.18, 0.80, 0.15))
            Tissue.MUCUS:
                _add_cell(skin_top, Tissue.MUCUS, radius * 0.80, Vector3(0.90, 0.06, 1.05))
            Tissue.MEMBRANE:
                _add_cell(skin_top + Vector3(0, length * 0.06, 0), Tissue.MEMBRANE, length, Vector3(1.5, 0.045, 0.85))
            Tissue.HORN:
                # Only the first horn belongs on the head; later samples form
                # short defensive dorsal spines rather than repeated faces.
                var horn_base: Vector3 = skin_top
                if i < kinds.size():
                    horn_base = focus_anchor_local + Vector3(radius * 0.35, radius * 0.55, 0)
                for segment in range(3):
                    var horn_radius: float = length * lerpf(0.22, 0.055, float(segment) / 2.0)
                    _add_cell(horn_base + Vector3(0, length * segment * 0.22, length * segment * 0.06), Tissue.HORN, horn_radius, Vector3(0.7, 1.5, 0.7))
            Tissue.BEAK:
                # One beak per head, never another beak on each body segment.
                if i >= kinds.size():
                    continue
                var mouth: Vector3 = focus_anchor_local + Vector3(0, -radius * 0.12, -radius * 0.60)
                _add_cell(mouth, Tissue.BEAK, length * 0.65, Vector3(0.65, 0.32, 1.1))
                _add_cell(mouth + Vector3(0, -length * 0.05, -length * 0.55), Tissue.BEAK, length * 0.25, Vector3(0.45, 0.28, 1.0))
        for j in range(start, body_cells.size()):
            body_cells[j]["wing"] = int(sample["t"]) == Tissue.WING and kind in [Tissue.FEATHER, Tissue.MEMBRANE]

func _surface_color(cell: Dictionary) -> Color:
    var color: Color = _cell_color(int(cell["t"]))
    if view_mode != "natural":
        return color
    var p: Vector3 = cell["p"]
    var g = owner_life.genome
    if int(cell["t"]) in [Tissue.SKIN, Tissue.SCALE, Tissue.FEATHER, Tissue.FUR]:
        var pigment: float = sin(p.z * 5.0 + float(g.seed % 17))
        if g.pattern_drive > 0.68:
            pigment *= cos(p.x * 7.0 + p.y * 4.0)
        if pigment > 0.30 and g.pattern_drive > 0.30:
            color = color.darkened(float(g.pattern_drive) * 0.38)
    return color

func _paired_appendages(g, spine: Array[Vector3], radius: float, growth: float, requested_pairs: int) -> void:
    if spine.size() < 3:
        return
    var max_pairs: int = 5 if visual_cap >= 240 else 4
    var pair_count: int = clampi(requested_pairs, 1, max_pairs)
    var limb_length: float = (0.65 + float(g.limb_length) * 3.25) * (0.75 + growth * 0.10)
    var limb_radius: float = radius * (0.10 + float(g.limb_thickness) * 0.22)
    for pair in range(pair_count):
        var spread: float = float(pair) / float(maxi(1, pair_count - 1))
        var center_frac: float = lerpf(0.20, 0.78, clampf(float(g.limb_position) * 0.45 + spread * 0.55, 0.0, 1.0))
        var idx: int = clampi(int(round(center_frac * float(spine.size() - 1))), 1, spine.size() - 2)
        var root: Vector3 = spine[idx]
        var down: float = lerpf(0.22, 0.82, 1.0 - float(g.buoyancy))
        for side_value in [-1.0, 1.0]:
            var elbow = root + Vector3(side_value * limb_length * 0.58, -down * limb_length * 0.48, -limb_length * 0.08)
            var tip = root + Vector3(side_value * limb_length, -down * limb_length, limb_length * 0.10)
            var tissue: int = Tissue.FIN if float(g.fin_drive) > 0.58 else Tissue.BODY
            _add_chain(root, elbow, 3, tissue, limb_radius)
            _add_chain(elbow, tip, 3, tissue, limb_radius * 0.76)
            if growth > 2.2 and tissue == Tissue.BODY:
                var digits: int = clampi(2 + int(float(g.branch_drive) * 3.0), 2, 5)
                for digit in range(digits):
                    var fan_offset: float = (float(digit) - float(digits - 1) * 0.5) * limb_length * 0.11
                    var digit_tip = tip + Vector3(side_value * limb_length * 0.22, -limb_length * 0.10, fan_offset)
                    _add_chain(tip, digit_tip, 2, Tissue.BODY, limb_radius * 0.35)
            elif tissue == Tissue.FIN:
                var rays: int = clampi(3 + int(float(g.branch_drive) * 3.0), 3, 6)
                for ray in range(rays):
                    var a: float = lerpf(-0.72, 0.72, float(ray) / float(maxi(1, rays - 1)))
                    var fin_tip = tip + Vector3(side_value * limb_length * 0.28, sin(a) * limb_length * 0.52, cos(a) * limb_length * 0.42)
                    _add_chain(tip, fin_tip, 2, Tissue.FIN, limb_radius * 0.30)

func _make_head(g, head: Vector3, radius: float, growth: float) -> void:
    _add_cell(head, Tissue.BODY, radius, Vector3(1.08 + float(g.body_width) * 0.28, 0.92, 1.05))
    if growth > 0.8:
        _add_cell(head + Vector3(-radius * 0.44, radius * 0.18, -radius * 0.52), Tissue.SENSOR, radius * 0.16)
        _add_cell(head + Vector3(radius * 0.44, radius * 0.18, -radius * 0.52), Tissue.SENSOR, radius * 0.16)
    if growth > 2.4 and float(g.sensory_drive) > 0.45:
        var antenna_len: float = radius * (0.65 + float(g.sensory_drive) * 1.25)
        _add_chain(head + Vector3(-radius * 0.28, radius * 0.46, -radius * 0.20), head + Vector3(-radius * 0.48, radius * 0.55, -antenna_len), 4, Tissue.SENSOR, radius * 0.08)
        _add_chain(head + Vector3(radius * 0.28, radius * 0.46, -radius * 0.20), head + Vector3(radius * 0.48, radius * 0.55, -antenna_len), 4, Tissue.SENSOR, radius * 0.08)

func _add_internal_tissue(pos: Vector3, radius: float, index: int, growth: float) -> void:
    if growth > 1.6:
        _add_cell(pos + Vector3(0.0, 0.02, 0.0), Tissue.NEURAL, radius * 0.20)
    if growth > 2.1 and index % 2 == 0:
        _add_cell(pos + Vector3(0.0, -radius * 0.20, 0.0), Tissue.SKELETON, radius * 0.15)

func _add_cell(pos: Vector3, tissue: int, radius: float, shape: Vector3 = Vector3.ONE) -> void:
    if body_cells.size() >= visual_cap:
        return
    body_cells.append({"p": pos, "t": tissue, "r": clampf(radius, 0.055, 1.8), "s": shape})

func _add_chain(a: Vector3, b: Vector3, count: int, tissue: int, radius: float) -> void:
    for i in range(count):
        if body_cells.size() >= visual_cap:
            return
        var t: float = float(i + 1) / float(count + 1)
        _add_cell(a.lerp(b, t), tissue, radius * lerpf(1.0, 0.62, t))

func _upload() -> void:
    if not multimesh_instance or not multimesh_instance.multimesh:
        return
    var mm = multimesh_instance.multimesh
    mm.instance_count = body_cells.size()
    if owner_life and mm.mesh and mm.mesh.material:
        mm.mesh.material.roughness = 0.85 if owner_life.rooted else 0.78 - float(owner_life.genome.mucus_cover) * 0.54
    for i in range(body_cells.size()):
        var cell: Dictionary = body_cells[i]
        var radius: float = float(cell["r"])
        var pos: Vector3 = cell["p"]
        var shape: Vector3 = cell.get("s", Vector3.ONE)
        var scale_vec: Vector3 = Vector3.ONE * (radius / 0.30)
        scale_vec *= shape
        var xf = Transform3D(Basis.IDENTITY.scaled(scale_vec), pos)
        mm.set_instance_transform(i, xf)
        mm.set_instance_color(i, _surface_color(cell))

func get_rear_anchor_local() -> Vector3:
    return rear_anchor_local

func get_focus_anchor_local() -> Vector3:
    return focus_anchor_local

func get_body_size_hint() -> float:
    return body_size_hint

func _cell_color(tissue: int) -> Color:
    var base: Color = owner_life.genome.base_color() if owner_life else Color.WHITE
    if view_mode == "natural" or view_mode == "cell":
        if tissue == Tissue.LEAF: return Color(0.18 + base.r * 0.25, 0.50 + base.g * 0.25, 0.12 + base.b * 0.28)
        if tissue == Tissue.ROOT: return Color(0.38, 0.26, 0.15)
        if tissue == Tissue.WING: return base.lightened(0.28)
        if tissue == Tissue.SKIN: return base.lightened(0.05)
        if tissue == Tissue.FEATHER: return base.lightened(0.35)
        if tissue == Tissue.QUILL: return Color(0.86, 0.83, 0.64)
        if tissue == Tissue.SCALE: return base.darkened(0.20)
        if tissue == Tissue.FUR: return base.darkened(0.16)
        if tissue == Tissue.MUCUS: return base.lightened(0.30)
        if tissue == Tissue.MEMBRANE: return base.lightened(0.22)
        if tissue == Tissue.HORN: return Color(0.55, 0.45, 0.29)
        if tissue == Tissue.BEAK: return Color(0.65, 0.45, 0.18)
        if tissue == Tissue.BARK: return Color(0.28, 0.20, 0.12)
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
            var energy_level = clampf(float(owner_life.energy), 0.0, 1.0)
            return Color(1.0 - energy_level * 0.72, 0.18 + energy_level * 0.82, 0.12 + energy_level * 0.26)
        _:
            match tissue:
                Tissue.SENSOR: return Color(0.95, 1.0, 0.70)
                Tissue.FIN: return base.lightened(0.18)
                Tissue.ARMOR: return base.darkened(0.32)
                Tissue.NEURAL: return base.lightened(0.08)
                Tissue.SKELETON: return base.darkened(0.18)
                _: return base
