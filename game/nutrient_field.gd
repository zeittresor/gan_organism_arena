extends Node3D

var rng = RandomNumberGenerator.new()
var points: Array[Vector3] = []
var multimesh_instance: MultiMeshInstance3D
var half_extent = 36.0

func initialize(count: int, extent: float, seed_value: int) -> void:
    rng.seed = seed_value
    half_extent = extent
    multimesh_instance = MultiMeshInstance3D.new()
    add_child(multimesh_instance)
    var mesh = SphereMesh.new()
    mesh.radius = 0.14
    mesh.height = 0.28
    mesh.radial_segments = 6
    mesh.rings = 3
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.40, 1.0, 0.56, 0.82)
    mat.emission_enabled = true
    mat.emission = Color(0.08, 0.42, 0.12)
    mat.emission_energy_multiplier = 0.65
    mesh.material = mat
    var mm = MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = mesh
    multimesh_instance.multimesh = mm
    set_count(count)

func set_count(count: int) -> void:
    count = clampi(count, 16, 2000)
    while points.size() < count:
        points.append(_random_point())
    while points.size() > count:
        points.pop_back()
    _upload()

func nearest_index(pos: Vector3) -> int:
    var best = -1
    var best_d = INF
    for i in range(points.size()):
        var d = pos.distance_squared_to(points[i])
        if d < best_d:
            best_d = d
            best = i
    return best

func respawn(index: int) -> void:
    if index < 0 or index >= points.size():
        return
    points[index] = _random_point()
    _update_one(index)

func _random_point() -> Vector3:
    return Vector3(
        rng.randf_range(-half_extent, half_extent),
        rng.randf_range(-half_extent * 0.58, half_extent * 0.58),
        rng.randf_range(-half_extent, half_extent)
    )

func _upload() -> void:
    if not multimesh_instance:
        return
    var mm = multimesh_instance.multimesh
    mm.instance_count = points.size()
    for i in range(points.size()):
        mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, points[i]))

func _update_one(index: int) -> void:
    if not multimesh_instance:
        return
    multimesh_instance.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, points[index]))
