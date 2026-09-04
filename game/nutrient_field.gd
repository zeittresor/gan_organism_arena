extends Node3D

const Cycle = preload("res://game/life_cycle.gd")
const Navigation = preload("res://game/navigation.gd")
const Traits = preload("res://game/ecology_traits.gd")
var habitat = null

var rng = RandomNumberGenerator.new()
var points: Array[Vector3] = []
var reserves: Array = []
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

func set_extent(extent: float) -> void:
    half_extent = maxf(8.0, extent)
    for i in range(points.size()):
        points[i].x = clampf(points[i].x, -half_extent, half_extent)
        points[i].y = clampf(points[i].y, -half_extent * 0.58, half_extent * 0.58)
        points[i].z = clampf(points[i].z, -half_extent, half_extent)
    _upload()

func set_count(count: int) -> void:
    count = clampi(count, 16, 2000)
    while points.size() < count:
        points.append(_random_point())
        reserves.append(0.28)
    while points.size() > count:
        points.pop_back()
        reserves.pop_back()
    _upload()

func set_habitat(model) -> void:
    habitat = model
    half_extent = model.half_extent
    for i in range(points.size()):
        points[i] = _random_point()
    _upload()

func nearest_for(org, dt: float = 0.0) -> int:
    var best: int = -1
    var sensing: float = 14.0 + org.genome.sensory_drive * 28.0
    var distance: float = sensing * sensing
    var can_water: bool = Cycle.water_breathing(org) > 0.28
    var can_air: bool = Navigation.land_capable(org) or org.airborne
    var position_value: Vector3 = org.global_position
    org.food_retarget_timer = maxf(0.0, org.food_retarget_timer - dt)
    var previous: int = org.food_target_index
    if previous >= 0 and previous < points.size() and reserves[previous] >= 0.02 and not (previous == org.food_rejected_index and org.food_reject_timer > 0.0):
        var target: Vector3 = points[previous]
        var target_wet: bool = target.y < habitat.waterline
        if target.distance_squared_to(position_value) <= sensing * sensing and target.distance_squared_to(org.food_target_position) < 0.01 and ((target_wet and can_water) or (not target_wet and can_air)):
            if org.food_retarget_timer > 0.0: return previous
            best = previous
            distance = position_value.distance_squared_to(target) * 0.64
    for i in range(points.size()):
        if reserves[i] < 0.02 or (i == org.food_rejected_index and org.food_reject_timer > 0.0): continue
        var p: Vector3 = points[i]
        var wet: bool = p.y < habitat.waterline
        if (wet and not can_water) or (not wet and not can_air):
            continue
        var d: float = position_value.distance_squared_to(p)
        if d < distance:
            distance = d
            best = i
    org.food_target_index = best
    org.food_retarget_timer = 0.60 + float(org.organism_id % 5) * 0.04
    if best >= 0: org.food_target_position = points[best]
    return best

func nearest_index(pos: Vector3) -> int:
    var best = -1
    var best_d = INF
    for i in range(points.size()):
        if reserves[i] < 0.02: continue
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
    var p = Vector3(rng.randf_range(-half_extent * 0.98, half_extent * 0.98), rng.randf_range(-half_extent * 0.55, half_extent * 0.55), rng.randf_range(-half_extent * 0.98, half_extent * 0.98))
    if habitat != null:
        var floor_y: float = habitat.floor_at(p)
        if floor_y >= habitat.waterline - 0.5:
            p.y = floor_y + 0.5
        elif rng.randf() < 0.28:
            p.y = floor_y + 0.5
        else:
            p.y = rng.randf_range(floor_y + 0.4, habitat.waterline - 0.25)
    return p

func _upload() -> void:
    if not multimesh_instance:
        return
    var mm = multimesh_instance.multimesh
    mm.instance_count = points.size()
    for i in range(points.size()):
        mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (0.05 + 0.95 * reserves[i] / 0.28)), points[i]))

func _update_one(index: int) -> void:
    if not multimesh_instance:
        return
    multimesh_instance.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (0.05 + 0.95 * reserves[index] / 0.28)), points[index]))

func consume(index: int) -> float:
    if index < 0 or index >= reserves.size(): return 0.0
    var taken: float = reserves[index]
    reserves[index] = 0.0
    respawn(index)
    return taken

func replenish(dt: float, multiplier: float = 1.0) -> float:
    var added: float = 0.0
    for i in range(reserves.size()):
        var amount: float = minf(0.28 - reserves[i], dt * 0.006 * multiplier)
        if amount <= 0.0: continue
        reserves[i] += amount
        added += amount
        _update_one(i)
    return added

func stored_energy() -> float:
    var total: float = 0.0
    for amount in reserves: total += amount
    return total
