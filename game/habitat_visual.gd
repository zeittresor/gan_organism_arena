extends Node3D

var habitat_level: int = 5
var world_size: float = 72.0
var waterline: float = 21.0
var ground_y: float = -21.0
var geometry_root: Node3D

func _ready() -> void:
    geometry_root = Node3D.new()
    geometry_root.name = "HabitatGeometry"
    add_child(geometry_root)

func configure(level: int, size: float) -> void:
    habitat_level = clampi(level, 5, 9)
    world_size = maxf(20.0, size)
    _rebuild()

func _clear_geometry() -> void:
    if not is_instance_valid(geometry_root):
        return
    for child in geometry_root.get_children():
        child.queue_free()

func _rebuild() -> void:
    _clear_geometry()
    var half: float = world_size * 0.5
    ground_y = -half * 0.60
    match habitat_level:
        5:
            waterline = half * 0.60
        6:
            waterline = half * 0.38
        7:
            waterline = half * 0.12
        8:
            waterline = -half * 0.08
        _:
            waterline = -half * 0.18
    _build_bounds(half)
    if habitat_level >= 6:
        _build_ground(half)
        _build_land_masses(half)
    if habitat_level <= 8:
        _build_water_surface(half)
    if habitat_level >= 8:
        _build_air_markers(half)

func _build_bounds(half: float) -> void:
    var yhalf: float = half * 0.60
    var mesh = ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    mesh.surface_set_color(Color(0.10, 0.48, 0.62, 0.22))
    var corners = [
        Vector3(-half,-yhalf,-half), Vector3(half,-yhalf,-half), Vector3(half,-yhalf,half), Vector3(-half,-yhalf,half),
        Vector3(-half,yhalf,-half), Vector3(half,yhalf,-half), Vector3(half,yhalf,half), Vector3(-half,yhalf,half)
    ]
    var edges = [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]]
    for e in edges:
        mesh.surface_add_vertex(corners[e[0]])
        mesh.surface_add_vertex(corners[e[1]])
    for i in range(-3, 4):
        var t: float = float(i) / 3.0 * half
        mesh.surface_add_vertex(Vector3(t, ground_y, -half))
        mesh.surface_add_vertex(Vector3(t, ground_y, half))
        mesh.surface_add_vertex(Vector3(-half, ground_y, t))
        mesh.surface_add_vertex(Vector3(half, ground_y, t))
    mesh.surface_end()
    var instance = MeshInstance3D.new()
    instance.mesh = mesh
    var mat = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.vertex_color_use_as_albedo = true
    instance.material_override = mat
    geometry_root.add_child(instance)

func _build_ground(half: float) -> void:
    var ground = MeshInstance3D.new()
    var box = BoxMesh.new()
    box.size = Vector3(half * 2.0, 0.55, half * 2.0)
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.13, 0.18, 0.12)
    mat.roughness = 0.95
    box.material = mat
    ground.mesh = box
    ground.position = Vector3(0.0, ground_y - 0.30, 0.0)
    geometry_root.add_child(ground)

func _build_land_masses(half: float) -> void:
    var rng = RandomNumberGenerator.new()
    rng.seed = 9127 + habitat_level * 271
    var count: int = 2 + (habitat_level - 5) * 2
    for i in range(count):
        var mound = MeshInstance3D.new()
        var sphere = SphereMesh.new()
        sphere.radius = rng.randf_range(3.2, 7.8)
        sphere.height = sphere.radius * rng.randf_range(0.7, 1.35)
        sphere.radial_segments = 12
        sphere.rings = 6
        var mat = StandardMaterial3D.new()
        mat.albedo_color = Color(0.20 + rng.randf_range(0.0, 0.08), 0.26 + rng.randf_range(0.0, 0.12), 0.12)
        mat.roughness = 0.90
        sphere.material = mat
        mound.mesh = sphere
        var x = rng.randf_range(-half * 0.72, half * 0.72)
        var z = rng.randf_range(-half * 0.72, half * 0.72)
        var above: float = rng.randf_range(1.0, 5.5) + float(habitat_level - 6) * 1.2
        mound.position = Vector3(x, ground_y + above, z)
        mound.scale = Vector3(rng.randf_range(1.0, 1.8), rng.randf_range(0.35, 0.75), rng.randf_range(1.0, 1.8))
        geometry_root.add_child(mound)

func _build_water_surface(half: float) -> void:
    var plane = MeshInstance3D.new()
    var mesh = PlaneMesh.new()
    mesh.size = Vector2(half * 2.0, half * 2.0)
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.03, 0.22, 0.31, 0.19)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.metallic = 0.08
    mat.roughness = 0.22
    mesh.material = mat
    plane.mesh = mesh
    plane.position.y = waterline
    geometry_root.add_child(plane)

func _build_air_markers(half: float) -> void:
    var mm_instance = MultiMeshInstance3D.new()
    var sphere = SphereMesh.new()
    sphere.radius = 0.10
    sphere.height = 0.20
    sphere.radial_segments = 5
    sphere.rings = 3
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.86, 0.90, 0.94, 0.18)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    sphere.material = mat
    var mm = MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = sphere
    mm.instance_count = 80
    var rng = RandomNumberGenerator.new()
    rng.seed = 42119
    for i in range(mm.instance_count):
        var p = Vector3(rng.randf_range(-half, half), rng.randf_range(waterline + 1.5, half * 0.55), rng.randf_range(-half, half))
        mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
    mm_instance.multimesh = mm
    geometry_root.add_child(mm_instance)
