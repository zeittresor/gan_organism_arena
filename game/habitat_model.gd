extends RefCounted

const GRID: int = 64
var half_extent: float = 72.0
var level: int = 5
var waterline: float = 43.2
var ground_y: float = -43.2
var heights: PackedFloat32Array = PackedFloat32Array()
const HEIGHT_TILE: int = 4
const HEIGHT_TILES: int = 16
var height_ceiling: PackedFloat32Array = PackedFloat32Array()
var revision: int = 0

func configure(p_level: int, size: float) -> void:
    level = clampi(p_level, 5, 9)
    half_extent = maxf(10.0, size * 0.5)
    ground_y = -half_extent * 0.60
    var levels: Array[float] = [0.60, 0.38, 0.12, -0.08, -0.18]
    waterline = half_extent * levels[level - 5]
    heights.resize((GRID + 1) * (GRID + 1))
    for z in range(GRID + 1):
        for x in range(GRID + 1):
            heights[z * (GRID + 1) + x] = _height_raw(float(x) / GRID * 2.0 - 1.0, float(z) / GRID * 2.0 - 1.0)
    # A triangle cannot exceed its highest vertex. Cache conservative maxima
    # once per terrain change, including both edges of every tile.
    height_ceiling.resize(HEIGHT_TILES * HEIGHT_TILES)
    for tz in range(HEIGHT_TILES):
        for tx in range(HEIGHT_TILES):
            var ceiling: float = -INF
            for z in range(tz * HEIGHT_TILE, (tz + 1) * HEIGHT_TILE + 1):
                for x in range(tx * HEIGHT_TILE, (tx + 1) * HEIGHT_TILE + 1):
                    ceiling = maxf(ceiling, heights[z * (GRID + 1) + x])
            height_ceiling[tz * HEIGHT_TILES + tx] = ceiling
    revision += 1

func floor_upper_bound(p: Vector3, radius: float) -> float:
    if height_ceiling.is_empty(): return ground_y
    var scale_value: float = float(HEIGHT_TILES) / (half_extent * 2.0)
    var x0: int = clampi(floori((p.x - radius + half_extent) * scale_value), 0, HEIGHT_TILES - 1)
    var x1: int = clampi(floori((p.x + radius + half_extent) * scale_value), 0, HEIGHT_TILES - 1)
    var z0: int = clampi(floori((p.z - radius + half_extent) * scale_value), 0, HEIGHT_TILES - 1)
    var z1: int = clampi(floori((p.z + radius + half_extent) * scale_value), 0, HEIGHT_TILES - 1)
    var ceiling: float = -INF
    for z in range(z0, z1 + 1):
        for x in range(x0, x1 + 1):
            ceiling = maxf(ceiling, height_ceiling[z * HEIGHT_TILES + x])
    return ceiling

func _height_raw(x: float, z: float) -> float:
    if level == 5:
        return ground_y
    if level == 6:
        var island: float = 0.0
        for center in [Vector2(-0.42, -0.30), Vector2(0.35, 0.30), Vector2(0.40, -0.48)]:
            var d: float = Vector2(x, z).distance_squared_to(center) / 0.17
            island = maxf(island, pow(maxf(0.0, 1.0 - d), 2.0))
        return half_extent * (-0.52 + island * 1.06)
    var ridges: float = x * 0.62 + sin(z * 5.2 + x * 2.0) * 0.14 + cos(x * 7.0 - z * 3.0) * 0.08
    return half_extent * clampf(ridges - 0.08, -0.56, 0.46)

func vertex(x: int, z: int) -> Vector3:
    return Vector3((float(x) / GRID * 2.0 - 1.0) * half_extent, heights[z * (GRID + 1) + x], (float(z) / GRID * 2.0 - 1.0) * half_extent)

func floor_at(p: Vector3) -> float:
    if heights.is_empty():
        return ground_y
    var fx: float = clampf((p.x / half_extent + 1.0) * 0.5 * GRID, 0.0, GRID - 0.00001)
    var fz: float = clampf((p.z / half_extent + 1.0) * 0.5 * GRID, 0.0, GRID - 0.00001)
    var x: int = int(fx)
    var z: int = int(fz)
    var u: float = fx - x
    var v: float = fz - z
    var a: float = heights[z * (GRID + 1) + x]
    var b: float = heights[z * (GRID + 1) + x + 1]
    var c: float = heights[(z + 1) * (GRID + 1) + x]
    var d: float = heights[(z + 1) * (GRID + 1) + x + 1]
    # Same triangle diagonal as the rendered mesh; collision and surface agree.
    if u + v <= 1.0:
        return a + (b - a) * u + (c - a) * v
    return d + (c - d) * (1.0 - u) + (b - d) * (1.0 - v)

func has_sky() -> bool:
    return level >= 7

func is_water(p: Vector3) -> bool:
    return p.y < waterline and floor_at(p) < waterline

func nearest_medium(p: Vector3, want_water: bool, clearance: float = 0.65) -> Vector3:
    var best: Vector3 = p
    var best_d: float = INF
    # Fixed grid search only on decision ticks (not per rendered frame).
    for z in range(1, 17):
        for x in range(1, 17):
            var q = Vector3((float(x) / 17.0 * 2.0 - 1.0) * half_extent, 0.0, (float(z) / 17.0 * 2.0 - 1.0) * half_extent)
            var floor_y: float = floor_at(q)
            if want_water:
                if floor_y > waterline - clearance * 2.0:
                    continue
                q.y = clampf(p.y, floor_y + clearance, waterline - clearance)
            else:
                if floor_y < waterline + 0.10:
                    continue
                q.y = floor_y + clearance
            var d: float = p.distance_squared_to(q)
            if d < best_d:
                best = q
                best_d = d
    # No land in the aquarium: air breathers can only seek the surface.
    if best_d == INF and not want_water:
        best.y = minf(half_extent * 0.60 - clearance, waterline + clearance)
    return best


func temperature_at(p: Vector3) -> float:
    # Toy climate gradients: colder depths/high ground, warmer lowland patches.
    # These values are game mechanics rather than a meteorological model.
    var regional: float = cos(p.x / half_extent * 2.5) * 5.0
    if is_water(p):
        return 22.0 + regional * 0.4 - maxf(0.0, waterline - p.y) * 0.28
    return 28.0 + regional - maxf(0.0, p.y - waterline) * 0.35
