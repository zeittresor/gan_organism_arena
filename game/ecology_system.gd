extends RefCounted

const Traits = preload("res://game/ecology_traits.gd")
var habitat = null
var predation_strength: float = 0.45
var group_strength: float = 0.55
var resources: Array[Vector3] = []
var stocks: Array[float] = []
var id_map: Dictionary = {}
var population: Array = []
var hunt_events: int = 0
var pack_events: int = 0
var tool_events: int = 0
var cleaning_events: int = 0
var parasitic_events: int = 0
var rooted_counts: Dictionary = {}

func configure(model, positions: Array[Vector3]) -> void:
    habitat = model
    resources = positions.duplicate()
    stocks.clear()
    for i in range(resources.size()):
        stocks.append(0.70)

func begin_tick(snapshot: Array, dt: float) -> void:
    population = snapshot
    id_map.clear()
    rooted_counts.clear()
    for org in snapshot:
        if is_instance_valid(org) and org.alive:
            id_map[org.organism_id] = org
            if org.rooted:
                var patch: Vector2i = Vector2i(floori(org.global_position.x / 8.0), floori(org.global_position.z / 8.0))
                rooted_counts[patch] = int(rooted_counts.get(patch, 0)) + 1
    for i in range(stocks.size()):
        stocks[i] = minf(0.70, stocks[i] + dt * 0.003)
    # First plan all hunts, then resolve shared pack targets independently of
    # the update order. Hunting never teleports prey or awards abstract energy.
    for org in snapshot:
        if not is_instance_valid(org) or not org.alive:
            continue
        org.pack_leader_id = org.organism_id
        org.prey_id = -1
        if predation_strength <= 0.0 or org.rooted or org.genome.predator_drive < 0.45 or org.energy > 1.10:
            continue
        var best: float = INF
        for other in snapshot:
            if other == org or not is_instance_valid(other) or not other.alive:
                continue
            var d: float = org.global_position.distance_to(other.global_position)
            if is_packmate(org, other) and other.genome.predator_drive > 0.45 and d < 22.0:
                org.pack_leader_id = mini(org.pack_leader_id, other.organism_id)
            if other.genome.family_id == org.genome.family_id:
                continue
            if not reachable(org, other.global_position):
                continue
            var detection: float = 15.0 + org.genome.sensory_drive * 20.0
            if other.hiding:
                detection *= 0.25 + (1.0 - other.genome.camouflage) * 0.40
            if d > detection:
                continue
            var strength: float = Traits.body_scale(other.genome) / maxf(0.2, Traits.body_scale(org.genome))
            if strength > 1.65 and org.genome.pack_drive * org.genome.cooperation < 0.34:
                continue
            var score: float = d * (0.75 + strength * 0.4) + other.genome.armor_drive * 4.0
            if score < best:
                best = score
                org.prey_id = other.organism_id
    var planned_prey: Dictionary = {}
    for org in snapshot:
        if is_instance_valid(org) and org.alive:
            planned_prey[org.organism_id] = org.prey_id
    for org in snapshot:
        if not is_instance_valid(org) or not org.alive:
            continue
        var leader = id_map.get(org.pack_leader_id)
        if is_instance_valid(leader):
            var shared = id_map.get(int(planned_prey.get(leader.organism_id, -1)))
            if is_instance_valid(shared) and shared.alive and reachable(org, shared.global_position):
                org.prey_id = shared.organism_id

func is_packmate(a, b) -> bool:
    return group_strength > 0.0 and a.genome.pack_drive * a.genome.cooperation > 0.34 and b.genome.pack_drive * b.genome.cooperation > 0.34 and (a.genome.family_id == b.genome.family_id or a.genome.cooperation + b.genome.cooperation > 1.45)

func reachable(org, p: Vector3) -> bool:
    var wet: bool = habitat.is_water(p)
    if wet and Traits.water_breathing(org.genome) < 0.28:
        return false
    if not wet and Traits.air_breathing(org.genome) < 0.28:
        return false
    if not wet and p.y > habitat.floor_at(p) + 6.0 and not org.can_fly:
        return false
    return true

func act(org, dt: float, rng: RandomNumberGenerator) -> void:
    if not org.alive:
        return
    org.hiding = false
    var film_growth: float = minf(0.15 - org.surface_food, dt * 0.0007)
    org.surface_food += film_growth
    org.energy = maxf(0.0, org.energy - film_growth * 0.30)
    org.parasite_load = maxf(0.0, org.parasite_load - dt * 0.002)
    if org.rooted:
        _feed_rooted(org, dt)
        return
    # Respiration outranks all food, reproduction and curiosity decisions.
    var breathing: float = Traits.water_breathing(org.genome) if org.in_water else Traits.air_breathing(org.genome)
    var want_water: bool = not org.in_water
    var leave_medium: bool = breathing < 0.38 and org.oxygen < 0.65
    if not org.in_water and org.moisture < 0.35 and org.genome.moisture_need > 0.45:
        leave_medium = true
        want_water = true
    # Amphibious individuals revisit shore/water according to their own
    # moisture budget and exploratory preference, with a minimum dwell time.
    if Traits.amphibious(org.genome) and org.medium_timer > 24.0 + (1.0 - org.genome.curiosity) * 45.0:
        leave_medium = true
    if Traits.flight_body(org.genome) and habitat.has_sky() and org.in_water and org.age_seconds > 18.0 and org.energy > 0.65:
        leave_medium = true
        want_water = false
    if leave_medium:
        org.decision_timer -= dt
        if org.decision_timer <= 0.0:
            org.refuge = habitat.nearest_medium(org.global_position, want_water, org.body_clearance())
            org.decision_timer = 2.0
        org.behavior_state = "seek_water" if want_water else "seek_land"
        org.steer_towards(org.refuge, minf(1.0, dt * 5.0))
        return
    org.decision_timer = 0.0
    if Traits.sessile(org.genome):
        org.behavior_state = "settle"
        org.steer_towards(Vector3(org.global_position.x, habitat.floor_at(org.global_position), org.global_position.z), minf(1.0, dt * 4.0))
        return
    var threat = _threat_for(org)
    if is_instance_valid(threat) and (org.genome.shyness > 0.48 or org.energy < 0.35):
        _hide_or_flee(org, threat, dt)
        return
    if org.genome.parasite_drive > 0.72 and org.energy < 0.95:
        if _symbiosis(org, dt, true):
            return
    if org.genome.cleaning_drive > 0.66 and org.energy < 1.05:
        if _symbiosis(org, dt, false):
            return
    if Traits.tools(org.genome) and org.age_seconds > 25.0 and org.intelligence > 0.14 and org.energy < 1.0:
        if _use_tool(org, dt):
            return
    if org.prey_id >= 0:
        _hunt(org, dt, rng)
        return
    # Grazers can feed on evolved sessile bodies without being predators.
    if org.genome.grazer_drive > 0.52 and org.energy < 0.90:
        var plant = _nearest_host(org, true)
        if is_instance_valid(plant):
            org.behavior_state = "graze"
            org.steer_towards(plant.global_position, minf(1.0, dt * 2.0))
            if _contact(org, plant):
                _transfer_food(org, plant, dt * 0.035, 0.70)
            return
    if org.airborne:
        org.behavior_state = "fly"
    elif org.can_fly and not org.in_water:
        org.behavior_state = "flight_practice"
    elif org.stand_upright:
        org.behavior_state = "walk_upright"

func _feed_rooted(org, dt: float) -> void:
    var patch: Vector2i = Vector2i(floori(org.global_position.x / 8.0), floori(org.global_position.z / 8.0))
    var crowd: float = maxf(1.0, float(rooted_counts.get(patch, 1)))
    var depth: float = maxf(0.0, habitat.waterline - org.global_position.y)
    var light: float = exp(-depth * 0.025)
    var canopy: float = 1.0 + (org.genome.wood_drive * 0.35 if not org.in_water else 0.0)
    var gain: float = dt * (0.019 * org.genome.photosynthesis * light * canopy + 0.006 * org.genome.cleaning_drive) / crowd
    if org.oxygen < 0.20:
        gain *= 0.15
    org.energy = minf(1.45, org.energy + gain)
    org.behavior_state = "photosynthesize" if org.genome.photosynthesis > org.genome.cleaning_drive else "filter_feed"

func _threat_for(org):
    var closest = null
    var best: float = 18.0
    for other in population:
        if not is_instance_valid(other) or not other.alive or other == org or other.rooted:
            continue
        if other.genome.family_id == org.genome.family_id or other.genome.predator_drive < 0.50:
            continue
        var d: float = org.global_position.distance_to(other.global_position)
        if d < best:
            best = d
            closest = other
    return closest

func _hide_or_flee(org, threat, dt: float) -> void:
    var best: float = INF
    var target: Vector3 = org.global_position + (org.global_position - threat.global_position).normalized() * 6.0
    for cover in resources:
        if not reachable(org, cover + Vector3.UP * org.body_clearance()):
            continue
        var d: float = org.global_position.distance_to(cover)
        if d < best and d < 14.0:
            best = d
            var away: Vector3 = (cover - threat.global_position).normalized()
            target = cover + away * 1.2 + Vector3.UP * org.body_clearance()
    org.behavior_state = "hide" if best < 3.0 else "flee"
    org.hiding = best < 3.0
    org.steer_towards(target, minf(1.0, dt * 4.0), 0.35 if org.hiding else 1.35)
    if org.hiding:
        org.fear = maxf(0.0, org.fear - dt * 0.10)

func _nearest_host(org, plants_only: bool = false):
    var best: float = 24.0
    var host = null
    for other in population:
        if other == org or not is_instance_valid(other) or not other.alive:
            continue
        if plants_only and not other.rooted:
            continue
        if not plants_only and Traits.body_scale(other.genome) < Traits.body_scale(org.genome) * 1.25:
            continue
        if not reachable(org, other.global_position):
            continue
        var d: float = org.global_position.distance_to(other.global_position)
        if d < best:
            best = d
            host = other
    return host

func _contact(a, b) -> bool:
    return a.global_position.distance_to(b.global_position) < 0.8 + 0.25 * (a.visual.get_body_size_hint() + b.visual.get_body_size_hint())

func _symbiosis(org, dt: float, parasitic: bool) -> bool:
    var host = _nearest_host(org)
    if not is_instance_valid(host):
        return false
    org.behavior_state = "parasitize" if parasitic else "clean_host"
    org.steer_towards(host.global_position, minf(1.0, dt * 4.0))
    if _contact(org, host):
        if parasitic:
            var taken: float = minf(host.energy, dt * 0.022 * org.genome.parasite_drive)
            host.energy -= taken
            host.parasite_load = minf(1.0, host.parasite_load + dt * 0.04)
            org.energy = minf(1.45, org.energy + taken * 0.70)
            host.fear = minf(1.0, host.fear + dt * 0.10)
            if host.energy <= 0.0001: host.alive = false
            parasitic_events += 1
        else:
            var available: float = host.surface_food + host.parasite_load * 0.10
            var taken: float = minf(available, dt * 0.045 * org.genome.cleaning_drive)
            var film: float = minf(host.surface_food, taken)
            host.surface_food -= film
            host.parasite_load = maxf(0.0, host.parasite_load - (taken - film) * 10.0)
            org.energy = minf(1.45, org.energy + taken * 0.70)
            cleaning_events += 1
    return true

func _use_tool(org, dt: float) -> bool:
    var nearest: int = -1
    var best: float = 28.0
    for i in range(resources.size()):
        if not reachable(org, resources[i] + Vector3.UP * org.body_clearance()) or stocks[i] <= 0.03:
            continue
        var d: float = org.global_position.distance_to(resources[i])
        if d < best:
            best = d
            nearest = i
    if nearest < 0:
        return false
    org.behavior_state = "collect_tool" if org.tool_durability <= 0.0 else "use_tool"
    org.steer_towards(resources[nearest] + Vector3.UP * org.body_clearance(), minf(1.0, dt * 3.0))
    if best < org.body_clearance() + 1.8:
        if org.tool_durability <= 0.0:
            org.tool_durability = 1.0
            org.energy = maxf(0.0, org.energy - 0.012)
        else:
            var extracted: float = minf(stocks[nearest], dt * (0.022 + org.tool_skill * 0.025))
            stocks[nearest] -= extracted
            org.energy = minf(1.45, org.energy + extracted * 0.78)
            org.tool_durability = maxf(0.0, org.tool_durability - dt * 0.018)
            org.tool_skill = minf(1.0, org.tool_skill + dt * 0.012)
            org.tool_uses += 1
            tool_events += 1
    return true

func _hunt(org, dt: float, rng: RandomNumberGenerator) -> void:
    var prey = id_map.get(org.prey_id)
    if not is_instance_valid(prey) or not prey.alive:
        return
    var pack: bool = false
    for other in population:
        if other != org and is_instance_valid(other) and other.alive and other.prey_id == org.prey_id and is_packmate(org, other) and org.global_position.distance_to(other.global_position) < 22.0:
            pack = true
            break
    var dist: float = org.global_position.distance_to(prey.global_position)
    var target: Vector3 = prey.global_position
    var forward: Vector3 = prey.velocity.normalized()
    if forward.length_squared() < 0.01:
        forward = Vector3.FORWARD
    var side: Vector3 = forward.cross(Vector3.UP).normalized()
    if pack:
        org.hunt_tactic = "flank"
        var role: int = org.organism_id % 3
        target += forward * (2.0 + org.hunting_skill * 3.0)
        if role != 0:
            target += side * (3.2 if role == 1 else -3.2) * clampf(dist / 7.0, 0.0, 1.0)
        org.behavior_state = "pack_drive" if role == 0 else "pack_flank"
    elif org.genome.ambush_drive + float(org.tactic_scores["ambush"]) > 0.72:
        org.hunt_tactic = "ambush"
        org.behavior_state = "ambush"
        # Commit to an interception spot for several seconds, then wait there.
        # Keep the tactic through the final strike so success trains ambush too.
        org.ambush_timer -= dt
        if dist > 5.0:
            if org.ambush_timer <= 0.0:
                org.ambush_point = target + forward * minf(6.0, dist * 0.4)
                org.ambush_timer = 6.0
            org.steer_towards(org.ambush_point, minf(1.0, dt * 2.0), 0.55)
            if org.global_position.distance_to(org.ambush_point) < 1.5:
                org.velocity *= 0.75
            return
    else:
        org.hunt_tactic = "pursuit"
        org.behavior_state = "hunt"
        target += prey.velocity * minf(1.8, org.hunting_skill * dist / 6.0)
    if dist < 3.0:
        target = prey.global_position
    org.steer_towards(target, minf(1.0, dt * 4.0), 1.20)
    if _contact(org, prey):
        var taken: float = _transfer_food(org, prey, dt * (0.045 + org.genome.predator_drive * 0.065) * (1.0 + org.genome.beak_drive * 0.12) * predation_strength / 0.45, 0.72)
        if taken > 0.0:
            org.hunting_skill = minf(1.0, org.hunting_skill + taken * 0.12)
            org.tactic_scores[org.hunt_tactic] = minf(0.30, float(org.tactic_scores[org.hunt_tactic]) + taken * 0.10)
            hunt_events += 1
            if pack:
                pack_events += 1
                # Share part of the actual bite, not newly created energy.
                for ally in population:
                    if ally != org and is_instance_valid(ally) and ally.alive and ally.prey_id == org.prey_id and is_packmate(org, ally) and org.global_position.distance_to(ally.global_position) < 8.0:
                        var share: float = minf(org.energy, taken * 0.12)
                        org.energy -= share
                        ally.energy = minf(1.45, ally.energy + share)
                        break
    elif rng.randf() < dt * 0.05:
        org.tactic_scores[org.hunt_tactic] = maxf(-0.25, float(org.tactic_scores[org.hunt_tactic]) - 0.006)

func _transfer_food(org, victim, amount: float, efficiency: float) -> float:
    var taken: float = victim.receive_predation(amount, org.organism_id)
    org.energy = minf(1.45, org.energy + taken * efficiency)
    return taken
