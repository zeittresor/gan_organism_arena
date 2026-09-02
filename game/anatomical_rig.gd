extends RefCounted

# Heritable support, armor, wood and muscle traits determine the mechanical
# tissue at each attachment. Bone meshes and shaft segments never deform.
# Modes: fixed attachment, cartilage joint, flexible exoskeleton joint,
# muscular hydrostat. Cartilage is not assumed for every kind of organism.
static func configure(cell: Dictionary, genome, rooted: bool) -> void:
    var tissue: int = int(cell["t"])
    var chain: int = int(cell.get("chain_index", -1))
    var count: int = int(cell.get("chain_count", 0))
    var axis: Vector3 = cell.get("chain_axis", Vector3.FORWARD)
    var soft: bool = (genome.body_plan in [2, 6] and genome.support_drive < 0.72) or (genome.support_drive < 0.24 and genome.armor_drive < 0.50)
    var mode: String = "fixed"
    var limit: float = 0.0
    var pivot: float = 1.0
    var bend_axis: Vector3 = Vector3.UP
    if not rooted and int(cell.get("parent", -1)) >= 0:
        if tissue in [0, 1] and (chain < 0 or absf(axis.z) > 0.70):
            mode = "hydrostat" if soft else "cartilage"
            limit = 0.12 if soft else 0.065
            pivot = 0.0 if soft else 0.5
        elif chain >= 0 and tissue in [0, 1, 4, 5, 9, 10]:
            var hinge: bool = chain == 0 or (count >= 4 and chain == int(count / 2))
            if soft and tissue in [0, 1, 5]:
                mode = "hydrostat"
                limit = 0.18
                pivot = 0.0
            elif hinge:
                mode = "membrane" if genome.armor_drive > 0.50 or genome.body_plan == 5 else "cartilage"
                limit = 0.45 if tissue in [9, 10] else 0.28
            bend_axis = Vector3.FORWARD if tissue == 9 else Vector3.RIGHT
        elif tissue == 6 and (chain >= 0 or absf(cell["p"].x) < float(cell["r"]) * 0.30):
            mode = "membrane"
            limit = 0.055
            pivot = 0.5
        elif tissue == 5 and soft:
            mode = "hydrostat"
            limit = 0.10
            bend_axis = Vector3.FORWARD
            pivot = 0.0
    var muscle: float = clampf(genome.muscle_drive, 0.0, 1.0)
    # A joint may exist without active muscles; it then has no active stroke.
    limit *= (1.0 - genome.wood_drive * 0.85) * (1.0 - genome.armor_drive * 0.35)
    cell["joint_mode"] = mode
    cell["joint"] = mode != "fixed"
    cell["joint_limit"] = limit
    cell["joint_muscle"] = muscle if mode != "fixed" else 0.0
    cell["joint_axis"] = bend_axis
    cell["joint_pivot"] = pivot
    cell["joint_angle"] = 0.0
    cell["joint_rate"] = 0.0

static func advance(cell: Dictionary, activity: float, phase: float, turn_rate: float, body_size: float, dt: float) -> float:
    var limit: float = float(cell["joint_limit"])
    var muscle: float = float(cell["joint_muscle"])
    if limit <= 0.0 or muscle <= 0.0: return 0.0
    var rest: Vector3 = cell["p"]
    var offset: float = PI if rest.x < 0.0 else 0.0
    var wave: float = sin(phase - rest.z * 0.55 + offset)
    var stroke: float = activity * sqrt(muscle)
    var target: float = wave * limit * stroke
    if cell["joint_axis"] == Vector3.UP:
        target += turn_rate * limit * muscle * clampf(rest.z / maxf(1.0, body_size), 0.0, 1.0) * 0.6
    target = clampf(target, -limit, limit)
    var angle: float = float(cell["joint_angle"])
    var maximum_rate: float = 0.3 + muscle * 2.0
    var rate: float = clampf((target - angle) * 8.0, -maximum_rate, maximum_rate)
    rate = move_toward(float(cell["joint_rate"]), rate, (1.0 + muscle * 5.0) * dt)
    var step: float = rate * dt
    if step * (target - angle) > 0.0 and absf(step) > absf(target - angle):
        step = target - angle
        rate = 0.0
    angle = clampf(angle + step, -limit, limit)
    cell["joint_angle"] = angle
    cell["joint_rate"] = rate
    return angle
