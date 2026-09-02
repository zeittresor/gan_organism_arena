extends RefCounted

const CellCycle = preload("res://game/cell_cycle.gd")
const Contact = preload("res://game/body_contact.gd")

const Cycle = preload("res://game/life_cycle.gd")
const Physiology = preload("res://game/physiology.gd")
const Traits = preload("res://game/ecology_traits.gd")
var pairs: Array = []
var broods: Array = []
var conceptions: int = 0
var mating_events: int = 0
var losses: int = 0
var births: int = 0

func find_id(world, oid: int):
    for org in world.organisms:
        if is_instance_valid(org) and org.alive and org.organism_id == oid:
            return org
    return null

func reserved_count() -> int:
    var count: int = 0
    for brood in broods:
        count += brood["genomes"].size()
    return count

func compatibility(a, b) -> float:
    if not CellCycle.can_mate(a.genome) or not CellCycle.can_mate(b.genome): return 0.0
    if a == b or not a.can_reproduce() or not b.can_reproduce(): return 0.0
    if not ((Cycle.produces_eggs(a) and Cycle.produces_sperm(b)) or (Cycle.produces_eggs(b) and Cycle.produces_sperm(a))): return 0.0
    if Cycle.mode(a) == "propagule" or Cycle.mode(b) == "propagule":
        if Cycle.mode(a) != Cycle.mode(b): return 0.0
    elif Cycle.is_internal(a) != Cycle.is_internal(b):
        return 0.0
    if Cycle.is_internal(a):
        if minf(a.genome.reproductive_anatomy, b.genome.reproductive_anatomy) < 0.25: return 0.0
        var sizes: float = maxf(Traits.body_scale(a.genome), Traits.body_scale(b.genome)) / minf(Traits.body_scale(a.genome), Traits.body_scale(b.genome))
        if sizes > 2.5: return 0.0
        if absf(a.genome.reproductive_anatomy - b.genome.reproductive_anatomy) > 0.65: return 0.0
    if not ((a.egg_reserve >= 0.26 and b.sperm_reserve >= 0.055) or (b.egg_reserve >= 0.26 and a.sperm_reserve >= 0.055)): return 0.0
    var score: float = Cycle.genetic_compatibility(a.genome, b.genome)
    return score if score >= 0.48 else 0.0

func contact(a, b) -> bool:
    if Cycle.mode(a) == "propagule": return a.global_position.distance_to(b.global_position) <= 10.0
    return Contact.touching(a, b, 0.22)

func shared_site(a, b, model) -> Vector3:
    var midpoint: Vector3 = (a.global_position + b.global_position) * 0.5
    if Cycle.mode(a) == "propagule": return midpoint
    if Cycle.water_breathing(a) >= 0.42 and Cycle.water_breathing(b) >= 0.42:
        return model.nearest_medium(midpoint, true, maxf(a.body_clearance(), b.body_clearance()))
    if Cycle.air_breathing(a) >= 0.42 and Cycle.air_breathing(b) >= 0.42:
        return model.nearest_medium(midpoint, false, maxf(a.body_clearance(), b.body_clearance()))
    # Close shoreline encounters can use breath reserves, but coupling still
    # requires contact, a matching fertilization route and sufficient oxygen.
    midpoint.y = model.waterline
    return midpoint

func available_slots(world) -> int:
    return maxi(0, int(world.population_cap()) - world.organisms.size() - reserved_count())

func find_mate(world, parent):
    var best = null
    var best_score: float = INF
    for other in world.organisms:
        if other == parent or not is_instance_valid(other) or other.pair_target_id >= 0:
            continue
        var score: float = compatibility(parent, other)
        if score <= 0.0: continue
        var distance: float = parent.global_position.distance_to(other.global_position)
        if distance > world.mating_radius(): continue
        var preference: float = distance / (0.7 + score * 0.3 + other.genome.ornament_drive * other.genome.dimorphism * 0.20)
        if preference < best_score:
            best = other
            best_score = preference
    return best

func step(world, dt: float, allow_new: bool) -> void:
    _develop_broods(world, dt)
    _parental_care(world, dt)
    for i in range(pairs.size() - 1, -1, -1):
        var pair: Dictionary = pairs[i]
        var a = find_id(world, int(pair["a"]))
        var b = find_id(world, int(pair["b"]))
        if not allow_new or a == null or b == null:
            _release_pair(a, b)
            pairs.remove_at(i)
            continue
        pair["elapsed"] += dt
        if compatibility(a, b) <= 0.0 or minf(a.oxygen, b.oxygen) < 0.45 or maxf(a.fear, b.fear) > 0.80 or pair["elapsed"] > 30.0:
            _release_pair(a, b)
            pairs.remove_at(i)
            continue
        var touching: bool = contact(a, b)
        var external: bool = Cycle.mode(a) == "spawn"
        if external and (not a.in_water or not b.in_water): touching = false
        if touching:
            pair["contact"] += dt
            a.desired_velocity = Vector3.ZERO
            b.desired_velocity = Vector3.ZERO
            a.velocity *= 0.65
            b.velocity *= 0.65
            var action: String = "pollinating" if Cycle.mode(a) == "propagule" else ("spawning" if external else "copulating")
            a.reproduction_state = action
            b.reproduction_state = action
            a.behavior_state = action
            b.behavior_state = action
        else:
            pair["contact"] = 0.0
            var site: Vector3 = shared_site(a, b, world.habitat)
            var target_a: Vector3 = b.global_position if a.in_water == b.in_water else site
            var target_b: Vector3 = a.global_position if a.in_water == b.in_water else site
            a.steer_towards(target_a, minf(1.0, dt * 6.0 * world.courtship_strength()))
            b.steer_towards(target_b, minf(1.0, dt * 6.0 * world.courtship_strength()))
            a.reproduction_state = "courtship"
            b.reproduction_state = "courtship"
            a.behavior_state = "courtship"
            b.behavior_state = "courtship"
        var duration: float = 2.0 + (a.genome.reproductive_anatomy + b.genome.reproductive_anatomy) * 2.0
        a.reproduction_progress = clampf(pair["contact"] / duration, 0.0, 1.0)
        b.reproduction_progress = a.reproduction_progress
        if pair["contact"] >= duration:
            _conceive(world, a, b)
            _release_pair(a, b)
            pairs.remove_at(i)
    if not allow_new or available_slots(world) <= 0: return
    for parent in world.organisms:
        if not is_instance_valid(parent) or not parent.can_reproduce() or parent.pair_target_id >= 0: continue
        if world.rng.randf() > parent.reproduction_probability(dt): continue
        var partner = find_mate(world, parent)
        if partner != null and world.rng.randf() <= world.sexual_attempt_rate():
            parent.pair_target_id = partner.organism_id
            partner.pair_target_id = parent.organism_id
            pairs.append({"a": parent.organism_id, "b": partner.organism_id, "contact": 0.0, "elapsed": 0.0})
            mating_events += 1
        elif parent.genome.asexual_drive > 0.78:
            _conceive(world, parent, null)

func _release_pair(a, b) -> void:
    for org in [a, b]:
        if org == null: continue
        org.pair_target_id = -1
        org.reproduction_progress = 0.0
        if org.carrying_count == 0: org.reproduction_state = "idle"

func _conceive(world, a, b) -> bool:
    if not a.can_reproduce() or available_slots(world) <= 0: return false
    var clonal: bool = b == null
    if clonal and a.genome.asexual_drive <= 0.78: return false
    if not clonal and (compatibility(a, b) <= 0.0 or not contact(a, b)): return false
    var carrier = a
    var donor = b
    if not clonal and (not Cycle.produces_eggs(a) or a.egg_reserve < 0.26 or b.sperm_reserve < 0.055):
        carrier = b
        donor = a
    var route: String = "bud" if clonal else Cycle.mode(carrier)
    if route == "spawn" and (not carrier.in_water or not donor.in_water): return false
    var count: int = mini(1 + int(carrier.genome.brood_size * 2.5), available_slots(world))
    var unit_cost: float = 0.32 if clonal else 0.26
    var reserve: float = carrier.bud_reserve if clonal else carrier.egg_reserve
    count = mini(count, int(reserve / unit_cost))
    if count <= 0: return false
    if not clonal:
        CellCycle.sync_gametes(carrier)
        CellCycle.sync_gametes(donor)
        count = mini(count, mini(carrier.egg_genomes.size(), donor.sperm_genomes.size()))
        if count <= 0: return false
    var payment: float = unit_cost * count
    var donor_payment: float = 0.055 * count if not clonal else 0.0
    if clonal: carrier.bud_reserve -= payment
    else: carrier.egg_reserve -= payment
    carrier.mate_cooldown = world.mate_delay()
    if donor != null:
        donor.sperm_reserve -= donor_payment
        donor.mate_cooldown = world.mate_delay()
    var compatibility_score: float = 1.0 if clonal else Cycle.genetic_compatibility(carrier.genome, donor.genome)
    var eggs: Array = []
    var sperm_cells: Array = []
    if not clonal:
        for i in range(count):
            eggs.append(carrier.egg_genomes.pop_front())
            sperm_cells.append(donor.sperm_genomes.pop_front())
    if not clonal and world.rng.randf() > minf(1.0, compatibility_score + 0.15):
        losses += count
        carrier._remember("fertilization unsuccessful")
        return false
    var genomes: Array = []
    for i in range(count):
        var child = null
        if clonal:
            child = carrier.genome.mutated(world.rng, world.mutation_strength(), world.macro_rate())
        else:
            var family: int = carrier.genome.family_id
            if donor.genome.family_id != family:
                family = world.next_family
                world.next_family += 1
            child = carrier.genome.fertilize(donor.genome, eggs[i], sperm_cells[i], world.rng, world.mutation_strength(), world.macro_rate(), family)
            child.fertility_factor *= clampf((compatibility_score - 0.25) / 0.50, 0.0, 1.0)
        genomes.append(child)
    var internal: bool = route in ["live_birth", "retained_egg", "egg"]
    var duration: float = Cycle.embryo_duration(carrier.genome)
    var p: Vector3 = carrier.global_position
    var marker = _make_marker(world, p, route)
    marker.visible = not internal
    broods.append({"genomes": genomes, "a": carrier.organism_id, "b": donor.organism_id if donor != null else -1,
        "route": route, "cell_division": "mitosis", "somatic_ploidy": 2, "age": 0.0, "development": 0.0, "stage": "cleavage", "duration": duration, "internal": internal,
        "energy": (payment + donor_payment) * 0.85, "health": 1.0, "position": p,
        "wet": carrier.in_water, "protection": carrier.genome.egg_protection,
        "nourishment": carrier.genome.maternal_nourishment, "marker": marker,
        "hybrid": not clonal, "viability": compatibility_score})
    if internal:
        carrier.carrying_count = count
        carrier.reproduction_state = "gestating" if route == "live_birth" else "retaining_eggs"
    carrier._remember("fertilized brood: " + route)
    world.record_event("conception", {"mother": carrier.organism_id, "father": donor.organism_id if donor != null else -1, "route": route, "embryos": count, "compatibility": compatibility_score})
    conceptions += count
    return true

func _make_marker(world, p: Vector3, route: String):
    var marker = MeshInstance3D.new()
    var mesh = SphereMesh.new()
    mesh.radius = 0.30
    mesh.height = 0.48
    mesh.radial_segments = 8
    mesh.rings = 4
    var material = StandardMaterial3D.new()
    material.albedo_color = Color(0.30, 0.65, 0.25) if route in ["propagule", "bud"] else Color(0.94, 0.82, 0.58)
    mesh.material = material
    marker.mesh = mesh
    world.add_child(marker)
    marker.global_position = p
    return marker

func _develop_broods(world, dt: float) -> void:
    for i in range(broods.size() - 1, -1, -1):
        var brood: Dictionary = broods[i]
        var carrier = find_id(world, int(brood["a"]))
        var marker = brood["marker"]
        var count: int = brood["genomes"].size()
        var route: String = brood["route"]
        if brood["internal"]:
            if carrier == null:
                _lose_brood(i, null, world)
                continue
            brood["position"] = carrier.global_position
            carrier.reproduction_progress = clampf(brood["development"], 0.0, 1.0)
            if route == "live_birth":
                var transfer: float = minf(maxf(0.0, carrier.energy - 0.18), dt * (0.003 + brood["nourishment"] * 0.004))
                carrier.energy -= transfer
                brood["energy"] += transfer * 0.80
            if carrier.oxygen < 0.25 or carrier.energy < 0.18:
                brood["health"] -= dt * 0.045
            if route == "egg" and brood["development"] >= 0.25:
                brood["internal"] = false
                brood["wet"] = carrier.in_water
                carrier.carrying_count = 0
                carrier.reproduction_state = "laying_eggs"
                carrier.reproduction_event_timer = 3.0
                carrier.reproduction_progress = 0.0
                marker.visible = true
        else:
            var p: Vector3 = brood["position"]
            p.x = clampf(p.x, -world.half_extent + 0.5, world.half_extent - 0.5)
            p.z = clampf(p.z, -world.half_extent + 0.5, world.half_extent - 0.5)
            p.y = maxf(p.y, world.habitat.floor_at(p) + 0.30)
            if not brood["wet"]:
                p.y = world.habitat.floor_at(p) + 0.30
            brood["position"] = p
            var wet: bool = world.habitat.is_water(p)
            if route == "spawn" and not wet:
                brood["health"] -= dt * 0.12
            elif wet != brood["wet"]:
                brood["health"] -= dt * 0.05
            elif not wet and brood["protection"] < 0.45 and route == "egg":
                brood["health"] -= dt * (0.45 - brood["protection"]) * 0.10
            # Eggs can be eaten; only their remaining stored energy is transferred.
            for eater in world.organisms:
                if not eater.alive or eater.organism_id in [brood["a"], brood["b"]] or eater.energy > 1.0 or eater.genome.predator_drive < 0.45: continue
                if eater.global_position.distance_to(p) < 1.0 + eater.genome.reach_drive:
                    var taken: float = minf(brood["energy"], dt * 0.025)
                    brood["energy"] -= taken
                    eater.energy = minf(1.45, eater.energy + taken * 0.70)
                    brood["health"] -= dt * 0.08
        marker.global_position = brood["position"]
        brood["age"] += dt
        var temperature: float = carrier.ambient_temperature if brood["internal"] and carrier != null else world.habitat.temperature_at(brood["position"]) + world.temperature_offset
        var thermal: float = clampf(pow(1.6, (temperature - 22.0) / 10.0), 0.25, 2.0)
        var oxygen_factor: float = carrier.oxygen if brood["internal"] and carrier != null else 1.0
        var progress: float = minf(1.0 - brood["development"], dt * thermal * clampf(oxygen_factor, 0.0, 1.0) * clampf(brood["health"], 0.0, 1.0) / brood["duration"])
        var growth_cost: float = 0.055 * count
        progress = minf(progress, maxf(0.0, brood["energy"] - 0.02 * count) / growth_cost)
        brood["energy"] = maxf(0.0, brood["energy"] - progress * growth_cost - dt * 0.0002 * count)
        brood["development"] += progress
        brood["stage"] = Physiology.embryo_stage(brood["development"])
        if brood["health"] <= 0.0 or brood["energy"] <= 0.015:
            _lose_brood(i, carrier, world)
            continue
        if brood["development"] < 0.999999: continue
        if brood["internal"] and carrier != null:
            carrier.carrying_count = 0
            carrier.reproduction_state = "birthing"
            carrier.reproduction_event_timer = 3.0
            carrier.reproduction_progress = 0.0
        for child_genome in brood["genomes"]:
            if child_genome.viability_score() < world.viability_threshold():
                losses += 1
                continue
            var p: Vector3 = brood["position"] + Vector3(world.rng.randf_range(-0.4, 0.4), 0.2, world.rng.randf_range(-0.4, 0.4))
            var child = world.spawn_genome(child_genome, p)
            if child == null:
                losses += 1
                continue
            child.energy = brood["energy"] / count
            child.complexity = 0.5
            child.intelligence = 0.02
            child.parent_a = brood["a"]
            child.parent_b = brood["b"]
            world.record_event("birth", {"id": child.organism_id, "mother": child.parent_a, "father": child.parent_b, "mutations": child_genome.mutation_events, "crossovers": child_genome.crossover_events, "genetic_health": child_genome.genetic_health()})
            child.in_water = world.habitat.is_water(child.global_position)
            child.last_medium = child.in_water
            child.visual.rebuild(true)
            for oid in [brood["a"], brood["b"]]:
                var parent = find_id(world, int(oid))
                if parent != null:
                    parent.children += 1
                    parent._remember("offspring born: %d" % child.organism_id)
            births += 1
            if brood["hybrid"]: world.crossover_births += 1
            else: world.mutation_births += 1
        marker.queue_free()
        broods.remove_at(i)

func _lose_brood(index: int, carrier, world) -> void:
    var brood: Dictionary = broods[index]
    world.record_event("brood_loss", {"mother": brood["a"], "father": brood["b"], "stage": brood["stage"], "health": brood["health"], "energy": brood["energy"], "embryos": brood["genomes"].size()})
    losses += brood["genomes"].size()
    if carrier != null and brood["internal"]:
        carrier.carrying_count = 0
        carrier.reproduction_progress = 0.0
        carrier.reproduction_state = "idle"
        carrier._remember("brood lost")
    brood["marker"].queue_free()
    broods.remove_at(index)

func _parental_care(world, dt: float) -> void:
    for child in world.organisms:
        if not child.alive or Cycle.development_fraction(child) >= 0.70 or child.energy >= 0.65: continue
        for oid in [child.parent_a, child.parent_b]:
            var parent = find_id(world, int(oid))
            if parent == null or parent.genome.parental_care < 0.55 or parent.energy < 0.70: continue
            if parent.global_position.distance_to(child.global_position) > 5.0: continue
            var gift: float = minf(parent.energy - 0.65, dt * 0.025 * parent.genome.parental_care)
            parent.energy -= gift
            child.energy += gift * 0.90
            parent.behavior_state = "tending_young"
