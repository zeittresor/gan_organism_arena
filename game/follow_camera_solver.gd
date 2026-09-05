extends RefCounted

# Terrain-aware follow-camera placement. The terrain is analytic rather than a
# physics collider, so checking only the final camera point is insufficient: a
# ridge can still cut through the line of sight to the followed organism.
const PATH_SAMPLES: int = 18
const FIRST_PATH_SAMPLE: int = 3

static func clearance_for_body(size_hint: float) -> float:
    return clampf(0.72 + maxf(0.0, size_hint) * 0.035, 0.72, 1.65)

static func required_lift(model, focus: Vector3, desired: Vector3, clearance: float) -> float:
    if model == null or not model.has_method("floor_at"):
        return 0.0
    var lift: float = 0.0
    # The first two samples are intentionally inside the organism's own visual
    # envelope. Starting at sample three prevents a ground-dweller's low focus
    # anchor from launching the camera unnecessarily high.
    for index in range(FIRST_PATH_SAMPLE, PATH_SAMPLES + 1):
        var fraction: float = float(index) / float(PATH_SAMPLES)
        var point: Vector3 = focus.lerp(desired, fraction)
        var floor_y: float = float(model.floor_at(point))
        # Lifting the endpoint changes this point only by fraction * lift.
        lift = maxf(lift, (floor_y + clearance - point.y) / fraction)
    return maxf(0.0, lift)

static func safe_position(model, focus: Vector3, desired: Vector3, clearance: float) -> Vector3:
    if model == null or not model.has_method("floor_at"):
        return desired
    var safe: Vector3 = desired
    # A second pass handles a heightfield whose sampled X/Z locations shift by
    # floating-point interpolation at steep triangle borders.
    for _pass in range(2):
        safe.y += required_lift(model, focus, safe, clearance)
    safe.y = maxf(safe.y, float(model.floor_at(safe)) + clearance)
    return safe

static func path_is_clear(model, focus: Vector3, camera_position: Vector3, clearance: float) -> bool:
    if model == null or not model.has_method("floor_at"):
        return true
    for index in range(FIRST_PATH_SAMPLE, PATH_SAMPLES + 1):
        var fraction: float = float(index) / float(PATH_SAMPLES)
        var point: Vector3 = focus.lerp(camera_position, fraction)
        if point.y < float(model.floor_at(point)) + clearance - 0.002:
            return false
    return true
