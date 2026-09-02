extends RefCounted

const CellCycle = preload("res://game/cell_cycle.gd")

# Allocation model in simulation energy units, inspired by energy-budget theory.
# Maintenance is paid in Organism; only remaining reserves can fund development
# and gametes. Parameters are experimental, not a calibrated species DEB model.
static func advance(org, dt: float) -> void:
    var condition: float = clampf((org.energy - 0.22) / 0.70, 0.0, 1.0)
    condition *= clampf(org.oxygen, 0.0, 1.0) * org.genome.genetic_health()
    var thermal: float = clampf(pow(1.6, (org.ambient_temperature - 22.0) / 10.0), 0.25, 2.0)
    CellCycle.repair(org, dt, condition)
    var available: float = maxf(0.0, org.energy - 0.22)
    if org.development_progress < 1.0:
        var duration: float = 24.0 + org.genome.maturation_gene * 60.0
        var progress: float = minf(1.0 - org.development_progress, dt * condition * thermal / duration)
        var growth_cost: float = 0.24 + org.genome.size_gene * 0.20
        progress = minf(progress, available / growth_cost)
        var payment: float = progress * growth_cost
        org.energy -= payment
        org.growth_investment += payment
        CellCycle.grow(org, payment)
        org.development_progress = minf(1.0, org.development_progress + progress)
        return
    # Mature gonads continuously synthesize finite gamete reserves. Courtship
    # and refractory periods are separate from this nutritional requirement.
    var role: String = "hermaphrodite" if org.genome.sex_system > 0.70 else ("female" if int(org.genome.sex_chromosomes[0]) + int(org.genome.sex_chromosomes[1]) == 0 else "male")
    var budget: float = minf(available, dt * (0.003 + org.genome.reproduction * 0.008) * condition * thermal)
    if CellCycle.can_clone(org.genome):
        var fraction: float = 1.0 if not CellCycle.can_mate(org.genome) else 0.45
        var bud: float = minf(budget * fraction, maxf(0.0, 0.64 - org.bud_reserve))
        org.bud_reserve += bud * 0.85
        org.energy -= bud
        org.gamete_investment += bud
        budget -= bud
        if not CellCycle.can_mate(org.genome): return
    var egg_budget: float = budget * (0.75 if role == "hermaphrodite" else 1.0)
    var sperm_budget: float = budget * (0.25 if role == "hermaphrodite" else 1.0)
    if role != "male":
        var payment: float = minf(egg_budget, maxf(0.0, 0.90 - org.egg_reserve) / 0.85)
        org.egg_reserve += payment * 0.85
        org.energy -= payment
        org.gamete_investment += payment
    if role != "female":
        var payment: float = minf(sperm_budget, maxf(0.0, 0.16 - org.sperm_reserve) / 0.85)
        org.sperm_reserve += payment * 0.85
        org.energy -= payment
        org.gamete_investment += payment
    # Old gametes are resorbed inefficiently, returning part of their investment.
    var decay: float = minf(1.0, dt * 0.001)
    var recycled: float = (org.egg_reserve + org.sperm_reserve) * decay
    org.egg_reserve *= 1.0 - decay
    org.sperm_reserve *= 1.0 - decay
    org.energy += recycled * 0.5
    CellCycle.sync_gametes(org)

static func reproductive_ready(org) -> bool:
    if CellCycle.can_clone(org.genome) and org.bud_reserve >= 0.32: return true
    if not CellCycle.can_mate(org.genome): return false
    return org.egg_reserve >= 0.26 or org.sperm_reserve >= 0.055

static func embryo_stage(progress: float) -> String:
    if progress < 0.15: return "cleavage"
    if progress < 0.35: return "gastrulation"
    if progress < 0.75: return "organogenesis"
    return "fetal_growth"
