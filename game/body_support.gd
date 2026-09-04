extends RefCounted

# Local load/immersion sensing is deliberately slower than display updates.
# Only structural tissue carries weight or displaces substantial water here.
static func update(org, dt: float, force: bool = false) -> void:
    if org.habitat == null or not is_instance_valid(org.visual): return
    org.support_timer -= dt
    var visual = org.visual
    if not force and org.support_timer > 0.0 and org.support_habitat == org.habitat and org.support_revision == org.habitat.revision and org.support_build == visual.build_revision and org.support_position.distance_squared_to(org.global_position) < 1.0:
        return
    org.support_timer = lerpf(0.20, 0.05, float(org.contact_quality) / 100.0)
    org.support_habitat = org.habitat
    org.support_revision = org.habitat.revision
    org.support_build = visual.build_revision
    org.support_position = org.global_position
    org.support_heights.clear()
    org.support_near_ground = false
    var total: float = 0.0
    var mass_center: Vector3 = Vector3.ZERO
    var contact_center: Vector3 = Vector3.ZERO
    var contact_weight: float = 0.0
    var suspended: float = 0.0
    var wet_volume: float = 0.0
    var weighted_z: float = 0.0
    var weighted_y: float = 0.0
    var zz: float = 0.0
    var zy: float = 0.0
    var basis_value: Basis = org.global_transform.basis
    for i in visual.collision_cells:
        var cell: Dictionary = visual.body_cells[i]
        var p: Vector3 = org.global_position + basis_value * visual.posed_cells[i]
        var ext: Vector3 = cell["s"] * float(cell["r"])
        var frame: Basis = basis_value * visual.posed_bases[i]
        var radius_y: float = maxf(0.02, Vector3(frame.x.y * ext.x, frame.y.y * ext.y, frame.z.y * ext.z).length())
        var floor_y: float = org.habitat.floor_at(p)
        var support_floor: float = floor_y
        if org.contact_quality >= 90:
            var rx: float = Vector3(frame.x.x * ext.x, frame.y.x * ext.y, frame.z.x * ext.z).length()
            var rz: float = Vector3(frame.x.z * ext.x, frame.y.z * ext.y, frame.z.z * ext.z).length()
            for edge in [Vector3(rx, 0, 0), Vector3(-rx, 0, 0), Vector3(0, 0, rz), Vector3(0, 0, -rz)]:
                support_floor = maxf(support_floor, org.habitat.floor_at(p + edge))
        var volume: float = maxf(0.0001, ext.x * ext.y * ext.z)
        var fraction: float = 0.0
        if floor_y < org.habitat.waterline:
            var depth: float = clampf((org.habitat.waterline - p.y + radius_y) / (2.0 * radius_y), 0.0, 1.0)
            fraction = depth * depth * (3.0 - 2.0 * depth)
        wet_volume += volume * fraction
        total += volume
        var gap: float = p.y - radius_y - support_floor
        mass_center += p * volume
        suspended += maxf(0.0, gap) * volume
        if gap < 0.20:
            contact_center += p * volume
            contact_weight += volume
        # Detailed contact uses footprint-edge samples; their conservative
        # clearance on a slope can exceed a center-only distance threshold.
        if gap < maxf(0.75, radius_y * 0.60): org.support_near_ground = true
        var target_y: float = support_floor + radius_y + 0.025
        if floor_y < org.habitat.waterline - radius_y * 2.0:
            # Water can support the immersed part while a dry overhang settles.
            target_y = maxf(target_y, minf(p.y, org.habitat.waterline - radius_y * 0.35))
        org.support_heights[i] = target_y
        var z: float = cell["p"].z
        weighted_z += volume * z
        weighted_y += volume * target_y
        zz += volume * z * z
        zy += volume * z * target_y
    org.submerged_fraction = wet_volume / maxf(0.0001, total)
    var spread: float = zz - weighted_z * weighted_z / maxf(0.0001, total)
    var slope: float = (zy - weighted_z * weighted_y / maxf(0.0001, total)) / maxf(0.1, spread)
    org.support_pitch = clampf(-atan(slope), -0.65, 0.65) if org.support_near_ground else 0.0
    if org.support_near_ground and contact_weight > 0.0001 and org.genome.body_plan == 0:
        # A slender tail/head contact is not a clamp holding the whole animal
        # cantilevered. Shift the root pitch toward its unsupported mass.
        var lever: float = ((mass_center / maxf(0.0001, total)) - contact_center / contact_weight).dot(basis_value.z)
        var load: float = clampf((suspended / maxf(0.0001, total) - 0.20) / 0.65, 0.0, 1.0) * (1.0 - org.submerged_fraction)
        org.support_pitch = clampf(org.support_pitch + clampf(lever / maxf(1.0, visual.body_size_hint), -0.40, 0.40) * load, -1.0, 1.0)
    org.support_samples += 1

static func flying(org) -> bool:
    return org.airborne and org.can_fly and org.habitat != null and org.habitat.has_sky() and org.genome.muscle_drive > 0.0 and org.energy > 0.25 and org.stamina > 0.18 and org.Traits.lift(org.genome) > 0.24 * gravity_scale(org)

static func gravity_scale(org) -> float:
    return clampf(float(org._setting("gravity_scale", 1.0)), 0.2, 2.5)

static func gravity(org, dt: float) -> void:
    if org.rooted: return
    if flying(org) and org.burst_time <= 0.0: return
    var immersed: float = org.submerged_fraction if org.habitat != null else (1.0 if org.in_water else 0.0)
    # Relative bulk density: neutral near the default, armor reduces buoyancy.
    var density: float = 0.85 + (1.0 - org.genome.buoyancy) * 0.30 + org.genome.armor_drive * 0.08
    org.velocity.y += dt * 9.8 * gravity_scale(org) * (immersed / density - 1.0)

static func conforming(org) -> bool:
    return org.habitat != null and not org.rooted and not flying(org) and org.burst_time <= 0.0 and (org.support_near_ground or (org.submerged_fraction > 0.02 and org.submerged_fraction < 0.95))

static func vertical_target(org, cell: Dictionary, index: int, frame: Basis, offset: Vector3) -> float:
    var parent: int = int(cell["parent"])
    if not org.support_heights.has(index) or not org.support_heights.has(parent): return 0.0
    var world_frame: Basis = org.global_transform.basis * frame
    var current: Vector3 = world_frame * offset
    var horizontal: float = Vector2(current.x, current.z).length()
    var sensitivity: float = (world_frame * Vector3.RIGHT.cross(offset)).y
    if horizontal < 0.02 or absf(sensitivity) < 0.02: return 0.0
    var target_height: float = float(org.support_heights[index]) - float(org.support_heights[parent])
    # Solve the full tangent angle; the previous linear half-lever estimate
    # overcorrected neighbouring vertebrae in alternating directions.
    return (atan2(target_height, horizontal) - atan2(current.y, horizontal)) * signf(sensitivity)
