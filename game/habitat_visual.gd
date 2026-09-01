extends Node3D

const HabitatModelScript = preload("res://game/habitat_model.gd")
var model = HabitatModelScript.new()
var resource_positions: Array[Vector3] = []

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
    model.configure(habitat_level, world_size)
    var half: float = model.half_extent
    ground_y = model.ground_y
    waterline = model.waterline
    _build_bounds(half)
    _build_terrain()
    _build_resources()
    _build_water_surface(half)
    if model.has_sky():
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

func _build_terrain() -> void:
    var surface = SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for z in range(model.GRID):
        for x in range(model.GRID):
            var a: Vector3 = model.vertex(x, z)
            var b: Vector3 = model.vertex(x + 1, z)
            var c: Vector3 = model.vertex(x, z + 1)
            var d: Vector3 = model.vertex(x + 1, z + 1)
            for p in [a, b, c, b, d, c]:
                var above: bool = p.y > waterline
                var color: Color = Color(0.23, 0.30, 0.12) if above else Color(0.13, 0.22, 0.23)
                if absf(p.y - waterline) < 1.6:
                    color = Color(0.43, 0.39, 0.25)
                var dx: float = (model.floor_at(p + Vector3.RIGHT * 0.1) - model.floor_at(p - Vector3.RIGHT * 0.1)) / 0.2
                var dz: float = (model.floor_at(p + Vector3(0, 0, 0.1)) - model.floor_at(p - Vector3(0, 0, 0.1))) / 0.2
                surface.set_normal(Vector3(-dx, 1.0, -dz).normalized())
                surface.set_color(color)
                surface.add_vertex(p)
    var mesh = MeshInstance3D.new()
    mesh.mesh = surface.commit()
    var mat = StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.roughness = 0.95
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mesh.material_override = mat
    geometry_root.add_child(mesh)

func _build_resources() -> void:
    resource_positions.clear()
    var rng = RandomNumberGenerator.new()
    rng.seed = 77117
    for i in range(40):
        var p = Vector3(rng.randf_range(-0.90, 0.90) * model.half_extent, 0.0, rng.randf_range(-0.90, 0.90) * model.half_extent)
        p.y = model.floor_at(p)
        resource_positions.append(p)
        var instance = MeshInstance3D.new()
        var stone = SphereMesh.new()
        stone.radius = 0.8 if i % 3 == 0 else 0.32
        stone.height = stone.radius * 1.6
        stone.radial_segments = 6
        stone.rings = 3
        var mat = StandardMaterial3D.new()
        mat.albedo_color = Color(0.34, 0.32, 0.25) if i % 3 == 0 else Color(0.58, 0.35, 0.14)
        mat.roughness = 0.95
        stone.material = mat
        instance.mesh = stone
        instance.position = p + Vector3.UP * stone.radius * 0.4
        geometry_root.add_child(instance)

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
