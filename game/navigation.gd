extends RefCounted

const Traits = preload("res://game/ecology_traits.gd")
const Cycle = preload("res://game/life_cycle.gd")

static func mouth_position(org) -> Vector3:
    return org.global_position + org.global_transform.basis * org.visual.get_focus_anchor_local()

static func mouth_radius(org) -> float:
    var index: int = org.visual.focus_anchor_index
    if index < 0: return 0.65
    var cell: Dictionary = org.visual.body_cells[index]
    var extent: Vector3 = cell["s"] * float(cell["r"])
    return maxf(extent.x, maxf(extent.y, extent.z)) + 0.35

static func can_feed(org, point: Vector3) -> bool:
    # Food has a physical location. Long bodies eat at the head, not the origin.
    var radius: float = mouth_radius(org)
    return mouth_position(org).distance_squared_to(point) <= radius * radius

static func land_capable(org) -> bool:
    return Cycle.air_breathing(org) >= 0.28 and Cycle.locomotor_maturity(org) and Traits.walking(org.genome) >= 0.18

static func waypoint(org, rng: RandomNumberGenerator, recovery: bool = false) -> Vector3:
    var yaw: float = org.heading_yaw + rng.randf_range(-1.1, 1.1)
    if recovery: yaw = org.heading_yaw + (1.5 if org.organism_id % 2 == 0 else -1.5)
    var length_value: float = 12.0 + org.genome.curiosity * 14.0
    var point: Vector3 = org.global_position + Vector3(-sin(yaw), 0.0, -cos(yaw)) * length_value
    point.y += rng.randf_range(-3.0, 3.0)
    if org.habitat == null: return point
    var margin: float = minf(org.habitat.half_extent * 0.35, org.visual.contact_radius + 2.0)
    var edge: float = org.habitat.half_extent - margin
    point.x = clampf(point.x, -edge, edge)
    point.z = clampf(point.z, -edge, edge)
    var floor_y: float = org.habitat.floor_at(point)
    var clearance: float = maxf(0.75, org.body_clearance())
    if org.in_water:
        if floor_y + clearance * 2.0 >= org.habitat.waterline:
            # Bounded local alternatives, no per-frame global path search.
            for angle in [1.2, -1.2, 2.4, -2.4, PI]:
                var candidate: Vector3 = org.global_position + Vector3(-sin(yaw + angle), 0.0, -cos(yaw + angle)) * length_value
                candidate.x = clampf(candidate.x, -edge, edge)
                candidate.z = clampf(candidate.z, -edge, edge)
                var bottom: float = org.habitat.floor_at(candidate)
                if bottom + clearance * 2.0 < org.habitat.waterline:
                    point = candidate
                    floor_y = bottom
                    break
        if floor_y + clearance * 2.0 < org.habitat.waterline:
            point.y = clampf(point.y, floor_y + clearance, org.habitat.waterline - clearance)
        else:
            point = org.global_position
    elif org.airborne:
        point.y = maxf(floor_y + clearance + 3.0, org.cruise_altitude)
    else:
        point.y = floor_y + clearance
        if floor_y < org.habitat.waterline and Cycle.water_breathing(org) < 0.28:
            point = org.global_position - (point - org.global_position) * 0.5
            point.y = org.habitat.floor_at(point) + clearance
    return point

static func choose(org, dt: float, food: Vector3, social: Vector3, threat: Vector3, rng: RandomNumberGenerator) -> Vector3:
    if org.rooted or Cycle.stage(org) == "pupa":
        org.navigation_goal = "photosynthesize" if org.rooted else "metamorphosing"
        org.navigation_target = org.global_position
        return Vector3.ZERO
    org.food_reject_timer = maxf(0.0, org.food_reject_timer - dt)
    org.navigation_timer -= dt
    org.navigation_recovery = maxf(0.0, org.navigation_recovery - dt)
    var forage: bool = org.food_target_index >= 0 and (org.energy < 0.82 or (org.navigation_base_goal == "forage" and org.energy < 1.16))
    var goal: String = "forage" if forage else "explore"
    if threat.length_squared() > 0.64:
        org.navigation_goal = "flee"
        org.navigation_target = org.global_position - threat.normalized() * 12.0
        org.behavior_state = "flee"
        return -threat.normalized()
    if org.navigation_recovery > 0.0:
        goal = "explore"
    if goal == "forage":
        if org.navigation_base_goal != goal or org.navigation_target.distance_squared_to(food) > 0.01:
            org.navigation_progress_timer = 0.0
            org.navigation_best_distance = mouth_position(org).distance_to(food)
        org.navigation_target = food
    elif org.navigation_base_goal != goal or org.navigation_timer <= 0.0 or org.global_position.distance_squared_to(org.navigation_target) < 9.0:
        org.navigation_target = waypoint(org, rng)
        org.navigation_timer = rng.randf_range(8.0, 16.0)
        org.navigation_progress_timer = 0.0
        org.navigation_best_distance = org.global_position.distance_to(org.navigation_target)
    org.navigation_base_goal = goal
    org.navigation_goal = goal
    org.behavior_state = goal
    var distance: float = mouth_position(org).distance_to(food) if goal == "forage" else org.global_position.distance_to(org.navigation_target)
    org.navigation_progress_timer += dt
    if distance < org.navigation_best_distance - 0.35:
        org.navigation_best_distance = distance
        org.navigation_progress_timer = 0.0
    if org.navigation_progress_timer > 7.0 and org.genome.muscle_drive > 0.05 and not org.rooted and Cycle.stage(org) != "pupa":
        # Discard a fruitless approach after actual lack of progress, not because
        # a new random direction was sampled. Keep the rejected food on cooldown.
        if goal == "forage":
            org.food_rejected_index = org.food_target_index
            org.food_reject_timer = 14.0
            org.food_retarget_timer = 0.0
        org.navigation_target = waypoint(org, rng, true)
        org.navigation_base_goal = "explore"
        org.navigation_goal = "explore"
        org.navigation_timer = 5.0
        org.navigation_recovery = 5.0
        org.navigation_progress_timer = 0.0
        org.navigation_best_distance = org.global_position.distance_to(org.navigation_target)
        org.navigation_replans += 1
        org.behavior_state = "explore"
    var target: Vector3 = org.navigation_target
    if org.navigation_goal == "forage":
        target -= mouth_position(org) - org.global_position
    org.eye_target = org.navigation_target
    var direction: Vector3 = target - org.global_position
    if not org.in_water and not org.airborne: direction.y = 0.0
    var steer: Vector3 = direction.normalized()
    # Cohesion can bend a route, but cannot cancel an individual's destination.
    if social.length_squared() > 0.0001:
        steer += social.normalized() * minf(0.18, social.length() * org.genome.cooperation * 0.12)
    var affect: Vector3 = org.Affect.steering(org, social, threat)
    if affect.length_squared() > 0.0001:
        steer += affect.normalized() * minf(0.12, affect.length())
    return steer
