extends RefCounted

# Aggregate tissue population, distinct from the bounded render-cell budget.
# Mitosis preserves ploidy; meiosis produces haploid gametes, not somatic growth.
static func strategy(g) -> String:
    if g.asexual_drive >= 0.94: return "mitotic"
    if g.asexual_drive > 0.78: return "combined"
    return "meiotic"

static func can_clone(g) -> bool:
    return g.asexual_drive > 0.78

static func can_mate(g) -> bool:
    return g.asexual_drive < 0.94

static func grow(org, payment: float) -> void:
    org.mitotic_investment += maxf(0.0, payment)
    var target: int = 16 + int(org.mitotic_investment / 0.0005)
    var divisions: int = maxi(0, target - org.somatic_cells)
    org.somatic_cells += divisions
    org.mitotic_divisions += divisions

static func repair(org, dt: float, condition: float) -> void:
    if org.tissue_damage <= 0.0: return
    var payment: float = minf(maxf(0.0, org.energy - 0.22), dt * 0.004 * condition)
    payment = minf(payment, org.tissue_damage * 0.12)
    org.energy -= payment
    org.repair_investment += payment
    org.tissue_damage = maxf(0.0, org.tissue_damage - payment / 0.12)
    # Replacement divisions restore damaged tissue without increasing adult mass.
    var total: int = int(org.repair_investment / 0.0005)
    org.mitotic_divisions += maxi(0, total - org.repair_divisions)
    org.repair_divisions = total

static func sync_gametes(org) -> void:
    if not can_mate(org.genome):
        org.egg_genomes.clear()
        org.sperm_genomes.clear()
        return
    var egg_count: int = clampi(int(org.egg_reserve / 0.26), 0, 3)
    var sperm_count: int = clampi(int(org.sperm_reserve / 0.055), 0, 3)
    while org.egg_genomes.size() > egg_count: org.egg_genomes.pop_back()
    while org.sperm_genomes.size() > sperm_count: org.sperm_genomes.pop_back()
    var rng = RandomNumberGenerator.new()
    while org.egg_genomes.size() < egg_count or org.sperm_genomes.size() < sperm_count:
        rng.seed = int(org.genome.seed) + org.organism_id * 1031 + org.meiosis_cycles * 7919
        var products: Array = org.genome.meiotic_products(rng, float(org._setting("mutation_strength", 0.14)))
        org.meiosis_cycles += 1
        if org.egg_genomes.size() < egg_count:
            org.egg_genomes.append(products[0])
            org.polar_bodies += 3
        else:
            for product in products:
                if org.sperm_genomes.size() < sperm_count: org.sperm_genomes.append(product)
