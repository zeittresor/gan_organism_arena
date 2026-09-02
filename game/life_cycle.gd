extends RefCounted

const Traits = preload("res://game/ecology_traits.gd")
# Compressed artificial-life times, not real species gestation schedules.
static func maturity_age(g) -> float:
    return 24.0 + float(g.maturation_gene) * 60.0

static func development_fraction(org) -> float:
    return clampf(org.development_progress, 0.0, 1.0)

static func stage(org) -> String:
    var progress: float = development_fraction(org)
    var g = org.genome
    if org.senescence > 0.15: return "senescent"
    if progress >= 1.0: return "adult"
    if Traits.sessile(g) and g.photosynthesis > 0.50:
        return "seedling" if progress < 0.35 else "juvenile"
    if g.metamorphosis > 0.65 and g.armor_drive > 0.35 and g.size_gene < 0.45:
        if progress < 0.55: return "larva"
        if progress < 0.82: return "pupa"
        return "subadult"
    if g.metamorphosis > 0.40 and g.aquatic_larva > 0.65 and progress < 0.65:
        return "larva"
    if progress < 0.18: return "hatchling"
    if progress < 0.70: return "juvenile"
    return "subadult"

static func size_factor(org) -> float:
    return 0.28 + 0.72 * sqrt(development_fraction(org))

static func sex_role(g) -> String:
    if g.sex_system > 0.70: return "hermaphrodite"
    g.ensure_diploid()
    return "female" if int(g.sex_chromosomes[0]) + int(g.sex_chromosomes[1]) == 0 else "male"

static func produces_eggs(org) -> bool:
    return sex_role(org.genome) != "male"

static func produces_sperm(org) -> bool:
    return sex_role(org.genome) != "female"

static func mode(org) -> String:
    var g = org.genome
    if Traits.sessile(g) and g.photosynthesis > 0.50: return "propagule"
    if g.internal_fertilization < 0.50: return "spawn"
    if g.live_birth < 0.55: return "egg"
    return "live_birth" if g.maternal_nourishment > 0.50 else "retained_egg"

static func is_internal(org) -> bool:
    return mode(org) in ["egg", "retained_egg", "live_birth"]

static func genetic_compatibility(a, b) -> float:
    # Lineage labels and silhouette are not species definitions. These mutable
    # recognition/development loci approximate pre/postzygotic isolation.
    var distance: float = absf(a.gamete_code - b.gamete_code) * 0.55
    distance += absf(a.development_code - b.development_code) * 0.45
    return clampf(1.0 - distance * 1.65, 0.0, 1.0)

static func water_breathing(org) -> float:
    if stage(org) == "larva" and org.genome.aquatic_larva > 0.65:
        return maxf(0.75, Traits.water_breathing(org.genome))
    return Traits.water_breathing(org.genome)

static func air_breathing(org) -> float:
    if stage(org) == "larva" and org.genome.aquatic_larva > 0.65:
        return minf(0.20, Traits.air_breathing(org.genome))
    return Traits.air_breathing(org.genome)

static func locomotor_maturity(org) -> bool:
    return stage(org) not in ["larva", "pupa", "hatchling"]

static func embryo_duration(g) -> float:
    return 12.0 + float(g.gestation_gene) * 65.0
