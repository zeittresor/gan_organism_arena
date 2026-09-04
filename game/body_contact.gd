extends RefCounted

# Conservative articulated sphere envelopes, independent of rendering mode.
# Kinematic contact constraints; this is not a deformable FEM/ragdoll solver.
static func envelope(org) -> Array:
    var result: Array = []
    if not is_instance_valid(org.visual): return result
    var visual = org.visual
    var basis_value: Basis = org.global_transform.basis
    var cache: Dictionary = visual.contact_cache
    if cache.get("pose", -1) == visual.pose_revision and cache.get("basis") == basis_value:
        return cache["shape"]
    for index in visual.collision_cells:
        var cell: Dictionary = visual.body_cells[index]
        var p: Vector3 = visual.posed_cells[index]
        var ext: Vector3 = cell["s"] * float(cell["r"])
        var radius: float = maxf(ext.x, maxf(ext.y, ext.z))
        append_sphere(result, basis_value * p, radius)
        var parent: int = int(cell.get("parent", -1))
        if parent >= 0:
            var anchor: Vector3 = visual.posed_cells[parent]
            var length: float = p.distance_to(anchor)
            if length > radius * 1.5:
                append_sphere(result, basis_value * ((p + anchor) * 0.5), length * 0.5 + minf(radius, float(visual.body_cells[parent]["r"])) * 0.5)
    visual.contact_cache = {"pose": visual.pose_revision, "basis": basis_value, "shape": result}
    visual.contact_builds += 1
    return result

static func append_sphere(shapes: Array, position_value: Vector3, radius: float) -> void:
    # Contained spheres add no occupied volume. Removing them preserves the
    # same conservative contact envelope while reducing repeated pair checks.
    var i: int = shapes.size() - 1
    while i >= 0:
        var other: Dictionary = shapes[i]
        var difference: float = float(other["r"]) - radius
        if position_value.distance_squared_to(other["p"]) <= difference * difference:
            if difference >= 0.0: return
            shapes.remove_at(i)
        i -= 1
    shapes.append({"p": position_value, "r": radius})

static func pair_geometry(a, b, shape_a: Array, shape_b: Array) -> Dictionary:
    var gap: float = INF
    var normal: Vector3 = Vector3.RIGHT
    var offset: Vector3 = b.global_position - a.global_position
    for ca in shape_a:
        var center_a: Vector3 = ca["p"] - offset
        for cb in shape_b:
            var delta: Vector3 = cb["p"] - center_a
            var radii: float = float(ca["r"]) + float(cb["r"])
            var limit: float = gap + radii
            if limit <= 0.0 or delta.length_squared() >= limit * limit: continue
            var distance: float = delta.length()
            var candidate: float = distance - radii
            if candidate < gap:
                gap = candidate
                normal = delta / distance if distance > 0.0001 else Vector3.RIGHT
    return {"gap": gap, "normal": normal}

static func surface_gap(a, b) -> float:
    return float(pair_geometry(a, b, envelope(a), envelope(b))["gap"])

static func touching(a, b, margin: float = 0.22) -> bool:
    var reach: float = a.visual.contact_radius + b.visual.contact_radius + margin
    if a.global_position.distance_squared_to(b.global_position) > reach * reach: return false
    return overlaps(a, b, envelope(a), envelope(b), margin)

static func overlaps(a, b, shape_a: Array, shape_b: Array, margin: float) -> bool:
    var offset: Vector3 = b.global_position - a.global_position
    for ca in shape_a:
        var center_a: Vector3 = ca["p"] - offset
        for cb in shape_b:
            var radius: float = float(ca["r"]) + float(cb["r"]) + margin
            if radius > 0.0 and center_a.distance_squared_to(cb["p"]) < radius * radius: return true
    return false

static func solve(organisms: Array, iterations: int = 8, quality: int = 100) -> void:
    var slop: float = lerpf(0.18, 0.015, clampf(float(quality) / 100.0, 0.0, 1.0))
    var shapes: Array = []
    # Defer articulated envelopes until broad-phase spheres actually overlap.
    for org in organisms: shapes.append([])
    for iteration in range(iterations):
        var changed: bool = false
        for i in range(organisms.size()):
            var a = organisms[i]
            if not is_instance_valid(a) or not a.alive: continue
            for j in range(i + 1, organisms.size()):
                var b = organisms[j]
                if not is_instance_valid(b) or not b.alive or (a.rooted and b.rooted): continue
                var reach: float = a.visual.contact_radius + b.visual.contact_radius
                if a.global_position.distance_squared_to(b.global_position) > reach * reach: continue
                if shapes[i].is_empty(): shapes[i] = envelope(a)
                if shapes[j].is_empty(): shapes[j] = envelope(b)
                if not overlaps(a, b, shapes[i], shapes[j], -slop): continue
                var normal: Vector3 = (b.global_position - a.global_position).normalized()
                if normal.length_squared() < 0.001: normal = Vector3.RIGHT
                # Grounded organisms separate along the ground, rather than stack.
                if (a.grounded and not a.in_water) or (b.grounded and not b.in_water):
                    normal.y = 0.0
                    normal = normal.normalized() if normal.length_squared() > 0.001 else Vector3.RIGHT
                var depth: float = maxf(0.0, separation_distance(a, b, shapes[i], shapes[j], normal) - slop)
                var share_a: float = 0.0 if a.rooted else (1.0 if b.rooted else 0.5)
                a.global_position -= normal * depth * share_a
                b.global_position += normal * depth * (1.0 - share_a)
                var closing: float = (a.velocity - b.velocity).dot(normal)
                if closing > 0.0:
                    a.velocity -= normal * closing * share_a
                    b.velocity += normal * closing * (1.0 - share_a)
                changed = true
        if not changed: break

static func ground(org, world_half: float) -> void:
    if org.habitat == null or not is_instance_valid(org.visual): return
    var visual = org.visual
    var cache: Dictionary = visual.ground_cache
    var position_value: Vector3 = org.global_position
    var basis_value: Basis = org.global_transform.basis
    if cache.get("pose", -1) == visual.pose_revision and cache.get("position") == position_value and cache.get("basis") == basis_value and cache.get("habitat") == org.habitat and cache.get("terrain", -1) == org.habitat.revision and cache.get("rooted") == org.rooted and cache.get("half") == world_half and cache.get("quality") == org.contact_quality:
        visual.ground_cache_hits += 1
        return
    var radius: float = visual.contact_radius
    var ceiling: float = org.habitat.floor_upper_bound(position_value, radius)
    if not org.rooted and position_value.y - radius > ceiling + 0.20 and absf(position_value.x) + radius < world_half and absf(position_value.z) + radius < world_half and position_value.y + radius < world_half * 0.60:
        org.grounded = false
        visual.ground_fast_checks += 1
    else:
        visual.ground_detail_checks += 1
        ground_detail(org, world_half)
    visual.ground_cache = {"pose": visual.pose_revision, "position": org.global_position, "basis": basis_value, "habitat": org.habitat, "terrain": org.habitat.revision, "rooted": org.rooted, "half": world_half, "quality": org.contact_quality}
    # A wall correction changes the terrain footprint: recheck at the new x/z.
    if position_value.x != org.global_position.x or position_value.z != org.global_position.z:
        visual.ground_cache.clear()

static func ground_detail(org, world_half: float) -> void:
    var correction: float = -INF
    var min_x: float = INF
    var max_x: float = -INF
    var min_z: float = INF
    var max_z: float = -INF
    var max_y: float = -INF
    var basis_value: Basis = org.global_transform.basis
    var position_value: Vector3 = org.global_position
    # Soft coverings cannot act as stilts that lift the entire organism.
    for i in org.visual.collision_cells:
        var cell: Dictionary = org.visual.body_cells[i]
        if org.rooted and int(cell["t"]) == 8: continue # Roots may penetrate soil.
        var center: Vector3 = position_value + basis_value * org.visual.posed_cells[i]
        var e: Vector3 = cell["s"] * float(cell["r"])
        var cell_basis: Basis = basis_value * org.visual.posed_bases[i]
        # Exact vertical and horizontal support radii of the rotated ellipsoid.
        var extent = Vector3(
            Vector3(cell_basis.x.x * e.x, cell_basis.y.x * e.y, cell_basis.z.x * e.z).length(),
            Vector3(cell_basis.x.y * e.x, cell_basis.y.y * e.y, cell_basis.z.y * e.z).length(),
            Vector3(cell_basis.x.z * e.x, cell_basis.y.z * e.y, cell_basis.z.z * e.z).length())
        var floor_height: float = org.habitat.floor_at(center)
        # Footprint samples also protect long bodies on slopes and shorelines.
        if org.contact_quality >= 90:
            for offset in [Vector3(extent.x, 0, 0), Vector3(-extent.x, 0, 0), Vector3(0, 0, extent.z), Vector3(0, 0, -extent.z)]:
                floor_height = maxf(floor_height, org.habitat.floor_at(center + offset))
        correction = maxf(correction, floor_height + 0.025 - (center.y - extent.y))
        min_x = minf(min_x, center.x - extent.x)
        max_x = maxf(max_x, center.x + extent.x)
        min_z = minf(min_z, center.z - extent.z)
        max_z = maxf(max_z, center.z + extent.z)
        max_y = maxf(max_y, center.y + extent.y)
    if correction == -INF: return
    if correction > 0.0 or org.rooted:
        org.global_position.y += correction
        org.velocity.y = maxf(0.0, org.velocity.y) if not org.rooted else 0.0
    org.grounded = correction > -0.15
    org.global_position.x += maxf(0.0, -world_half - min_x) - maxf(0.0, max_x - world_half)
    org.global_position.z += maxf(0.0, -world_half - min_z) - maxf(0.0, max_z - world_half)
    if max_y > world_half * 0.60 and correction <= 0.0:
        org.global_position.y -= max_y - world_half * 0.60

static func separation_distance(a, b, shape_a: Array, shape_b: Array, normal: Vector3) -> float:
    var shift: float = 0.0
    var offset: Vector3 = b.global_position - a.global_position
    for ca in shape_a:
        var center_a: Vector3 = ca["p"] - offset
        for cb in shape_b:
            var delta: Vector3 = cb["p"] - center_a
            var along: float = delta.dot(normal)
            var perpendicular: float = maxf(0.0, delta.length_squared() - along * along)
            var radius: float = float(ca["r"]) + float(cb["r"])
            if perpendicular >= radius * radius: continue
            shift = maxf(shift, sqrt(radius * radius - perpendicular) - along)
    return shift
