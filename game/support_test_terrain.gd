extends RefCounted

# Deterministic contact fixtures: a ramp and an uneven slope.
var half_extent: float = 144.0
var waterline: float = -100.0
var ground_y: float = 0.0
var revision: int = 1
var level: int = 7
var profile: int = 0

func floor_at(p: Vector3) -> float:
    if profile == 2: return ground_y
    if profile == 3: return 5.0 - absf(p.z - 3.0) * 0.9
    if profile == 4: return p.z * 0.95
    return p.z * 0.22 + (sin(p.z * 0.60) * 0.60 if profile == 1 else 0.0)

func floor_upper_bound(p: Vector3, radius: float) -> float:
    if profile == 2: return ground_y
    if profile == 3: return 5.0
    if profile == 4: return (p.z + radius) * 0.95
    return (p.z + radius) * 0.22 + (0.60 if profile == 1 else 0.0)

func is_water(p: Vector3) -> bool:
    return p.y < waterline and floor_at(p) < waterline

func has_sky() -> bool:
    return true

func temperature_at(_p: Vector3) -> float:
    return 17.0
