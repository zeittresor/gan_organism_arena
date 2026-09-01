extends RefCounted

# Capability scores are shared by movement, decisions, physiology and visuals.
# They are toy ecological mechanics, not taxonomic stages or a fitness ladder.
static func body_scale(g) -> float:
    return lerpf(0.28, 1.55, float(g.size_gene))

static func walking(g) -> float:
    return float(g.terrestrial_drive) * sqrt(float(g.limb_drive) * float(g.support_drive))

static func lift(g) -> float:
    var skeleton: float = maxf(float(g.light_skeleton), (1.0 - float(g.size_gene)) * float(g.armor_drive))
    var covering: float = 1.0 + float(g.feather_cover) * 0.22 + float(g.membrane_cover) * 0.18
    var load: float = 0.35 + float(g.size_gene) * 0.80 + float(g.armor_drive) * 0.60 + float(g.shell_drive) * 0.50 + float(g.horn_drive) * 0.10 + float(g.skin_thickness) * 0.06
    return float(g.flight_drive) * float(g.wing_area) * float(g.support_drive) * (0.35 + skeleton * 0.65) * covering / load

static func flight_body(g) -> bool:
    return lift(g) > 0.24 and float(g.limb_drive) > 0.38 and float(g.support_drive) > 0.40 and float(g.lung_drive) > 0.38

static func amphibious(g) -> bool:
    return water_breathing(g) >= 0.42 and air_breathing(g) >= 0.42 and walking(g) > 0.18

static func water_breathing(g) -> float:
    return clampf(float(g.gill_drive) + float(g.skin_breathing) * 0.38 * skin_permeability(g), 0.0, 1.0)

static func air_breathing(g) -> float:
    return clampf(float(g.lung_drive) + float(g.skin_breathing) * 0.22 * skin_permeability(g), 0.0, 1.0)

static func upright(g) -> bool:
    return walking(g) > 0.36 and float(g.balance_drive) * float(g.support_drive) > 0.44 and float(g.neural_drive) > 0.38

static func tools(g) -> bool:
    return float(g.manipulation) * float(g.neural_drive) * float(g.limb_drive) > 0.24 and float(g.tool_drive) > 0.40

static func sessile(g) -> bool:
    return float(g.root_drive) > 0.72 and (float(g.photosynthesis) > 0.50 or float(g.cleaning_drive) > 0.60)

static func swim_speed(g) -> float:
    var propulsion: float = 0.30 + float(g.fin_drive) * 0.45 + float(g.tail_drive) * 0.25
    var drag: float = 0.65 + float(g.body_width) * 0.18 + float(g.armor_drive) * 0.25 + float(g.shell_drive) * 0.25
    drag *= coat_drag(g)
    return (1.0 + float(g.muscle_drive) * 4.0) * (0.30 + float(g.aquatic_drive) * 0.70) * propulsion / drag

static func maintenance(g) -> float:
    # Dual respiration, powerful muscles, cognition and foliage all cost energy.
    return 0.0008 * (float(g.gill_drive) + float(g.lung_drive)) + 0.0012 * float(g.muscle_drive) + 0.0008 * float(g.neural_drive) + 0.0005 * float(g.photosynthesis) + 0.0004 * float(g.wing_area)


static func skin_permeability(g) -> float:
    return clampf(1.0 - float(g.skin_thickness) * 0.45 - float(g.scale_cover) * 0.38, 0.15, 1.0)

static func water_loss(g) -> float:
    return clampf(1.0 - float(g.skin_thickness) * 0.35 - float(g.scale_cover) * 0.22 - float(g.mucus_cover) * 0.26, 0.20, 1.0)

static func coat_drag(g) -> float:
    var wet_coat: float = (float(g.fur_cover) * 0.30 + float(g.feather_cover) * 0.16) * (1.0 - float(g.mucus_cover) * 0.50)
    return 1.0 + wet_coat - float(g.mucus_cover) * 0.10 - float(g.scale_cover) * 0.06

static func insulation(g, wet: bool) -> float:
    var warmth: float = clampf(float(g.fur_cover) * 0.65 + float(g.feather_cover) * 0.42, 0.0, 0.85)
    if wet:
        warmth *= 0.25 + float(g.mucus_cover) * 0.50
    return warmth

static func covering_cost(g) -> float:
    return 0.00035 * (float(g.skin_thickness) + float(g.scale_cover) + float(g.mucus_cover)) + 0.00055 * (float(g.fur_cover) + float(g.feather_cover) + float(g.membrane_cover)) + 0.00030 * (float(g.horn_drive) + float(g.beak_drive))

static func covering_protection(g) -> float:
    return float(g.skin_thickness) * 0.08 + float(g.scale_cover) * 0.16 + float(g.horn_drive) * float(g.support_drive) * 0.08

static func thermal_cost(g, wet: bool, temperature: float) -> float:
    var coat: float = insulation(g, wet)
    var cold: float = maxf(0.0, 17.0 - temperature) / 22.0
    var hot: float = maxf(0.0, temperature - 29.0) / 14.0
    return 0.0018 * (cold * (1.0 - coat) + hot * (1.0 + coat * 0.55))
