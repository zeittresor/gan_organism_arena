extends RefCounted

# Steering intent is separate from contact impulses. Turn the body gradually,
# then accelerate along its heading, so a reversal describes a physical curve.
static func initialize(org, direction: Vector3) -> void:
    org.heading_yaw = atan2(-direction.x, -direction.z)
    org.heading_pitch = 0.0
    org.turn_yaw_speed = 0.0
    org.turn_pitch_speed = 0.0
    org.body_roll = 0.0
    org.global_rotation = Vector3(0.0, org.heading_yaw, 0.0)

static func forward(yaw: float, pitch: float) -> Vector3:
    return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))

static func turn_limit(org) -> float:
    var length_value: float = org.visual.get_body_size_hint() if is_instance_valid(org.visual) else 2.0
    var agility: float = 1.1 + org.genome.muscle_drive * 1.4 + org.genome.fin_drive * 0.6
    agility *= 1.0 - org.genome.armor_drive * 0.30
    if org.airborne: agility *= 0.75
    return clampf(agility / sqrt(1.0 + maxf(1.0, length_value) * 0.35), 0.35, 2.4) * sqrt(clampf(org.genome.muscle_drive / 0.60, 0.0, 1.0))

static func acceleration_limit(org) -> float:
    return org.genome.muscle_drive * 4.8 * (0.4 + org.stamina * 0.6) / sqrt(0.7 + org.genome.size_gene)

static func boundary_intent(org, intent: Vector3, half_extent: float) -> Vector3:
    var radius: float = org.visual.contact_radius if is_instance_valid(org.visual) else 1.0
    var margin: float = minf(half_extent * 0.45, radius + 2.0 + org.velocity.length() * 1.2)
    var safe_edge: float = half_extent - margin
    var p: Vector3 = org.global_position
    var avoidance = Vector3.ZERO
    if absf(p.x) > safe_edge:
        avoidance.x = -signf(p.x) * clampf((absf(p.x) - safe_edge) / maxf(1.0, margin - radius), 0.0, 1.0)
    if absf(p.z) > safe_edge:
        avoidance.z = -signf(p.z) * clampf((absf(p.z) - safe_edge) / maxf(1.0, margin - radius), 0.0, 1.0)
    if org.in_water or org.airborne:
        var top: float = half_extent * 0.60 - margin
        if p.y > top: avoidance.y = -clampf((p.y - top) / maxf(1.0, margin), 0.0, 1.0)
        if org.in_water and org.grounded: intent.y = maxf(0.0, intent.y)
    if avoidance.length_squared() > 0.0001:
        var speed: float = intent.length()
        intent = (intent.normalized() + avoidance * 3.0).normalized() * speed
    return intent

static func step(org, dt: float, half_extent: float) -> void:
    if dt <= 0.0: return
    var fixed_body: bool = org.rooted or org.Cycle.stage(org) == "pupa"
    var ballistic: bool = org.burst_time > 0.0
    var spatial: bool = org.in_water or org.airborne or ballistic
    var intent: Vector3 = org.velocity if ballistic else boundary_intent(org, org.desired_velocity, half_extent)
    if org.airborne and not ballistic and org.prey_id < 0 and org.pair_target_id < 0:
        intent.y = lerpf(intent.y, clampf(org.cruise_altitude - org.global_position.y, -2.0, 2.0), 0.60)
    if not spatial: intent.y = 0.0
    if fixed_body: intent = Vector3.ZERO
    var speed: float = intent.length()
    var target_yaw: float = org.heading_yaw
    var target_pitch: float = 0.0 if not spatial or fixed_body else org.heading_pitch
    if speed > 0.08:
        # Keep the last azimuth near vertical; no look_at/up-vector singularity.
        var horizontal: float = Vector2(intent.x, intent.z).length()
        if horizontal > maxf(0.05, speed * 0.05):
            target_yaw = atan2(-intent.x, -intent.z)
        if spatial:
            var pitch_limit: float = 1.25 if ballistic else (0.90 if org.airborne else 1.10)
            target_pitch = clampf(atan2(intent.y, horizontal), -pitch_limit, pitch_limit)
    var limit: float = turn_limit(org) if org.genome.muscle_drive > 0.0 and not fixed_body else 0.0
    var yaw_error: float = wrapf(target_yaw - org.heading_yaw, -PI, PI)
    # Commit to a U-turn side even when a target wobbles around exactly behind.
    if absf(yaw_error) > 2.5 and absf(org.turn_yaw_speed) > 0.05:
        yaw_error = absf(yaw_error) * signf(org.turn_yaw_speed)
    elif absf(yaw_error) > 3.0:
        yaw_error = absf(yaw_error) * (1.0 if org.organism_id % 2 == 0 else -1.0)
    var yaw_goal: float = clampf(yaw_error * 2.5, -limit, limit)
    var pitch_error: float = target_pitch - org.heading_pitch
    var pitch_goal: float = clampf(pitch_error * 2.5, -limit * 0.65, limit * 0.65)
    org.turn_yaw_speed = move_toward(org.turn_yaw_speed, yaw_goal, limit * 3.5 * dt)
    org.turn_pitch_speed = move_toward(org.turn_pitch_speed, pitch_goal, limit * 2.5 * dt)
    if limit <= 0.0:
        org.turn_yaw_speed = 0.0
        org.turn_pitch_speed = 0.0
    var yaw_step: float = org.turn_yaw_speed * dt
    var pitch_step: float = org.turn_pitch_speed * dt
    if yaw_step * yaw_error > 0.0 and absf(yaw_step) > absf(yaw_error):
        yaw_step = yaw_error
        org.turn_yaw_speed = 0.0
    if pitch_step * pitch_error > 0.0 and absf(pitch_step) > absf(pitch_error):
        pitch_step = pitch_error
        org.turn_pitch_speed = 0.0
    org.heading_yaw = wrapf(org.heading_yaw + yaw_step, -PI, PI)
    org.heading_pitch += pitch_step
    var maximum_pitch: float = 1.25 if ballistic else (0.90 if org.airborne else 1.10)
    if absf(org.heading_pitch) > maximum_pitch:
        org.heading_pitch = clampf(org.heading_pitch, -maximum_pitch, maximum_pitch)
        org.turn_pitch_speed = 0.0
    var roll_goal: float = 0.0
    if org.airborne and not ballistic: roll_goal = clampf(-org.turn_yaw_speed * org.velocity.length() * 0.045, -0.30, 0.30)
    org.body_roll = move_toward(org.body_roll, roll_goal, 0.7 * dt)
    org.global_rotation = Vector3(org.heading_pitch, org.heading_yaw, org.body_roll)
    if fixed_body:
        org.velocity = Vector3.ZERO
        return
    # Jumps/dives retain momentum. Gravity and contacts remain physical forces.
    if ballistic: return
    var heading: Vector3 = forward(org.heading_yaw, org.heading_pitch)
    if not spatial:
        heading.y = 0.0
        heading = heading.normalized()
    var alignment: float = maxf(0.0, heading.dot(intent.normalized())) if speed > 0.08 else 1.0
    var cruise: float = 0.55 if org.airborne else (0.30 if org.in_water else 0.15)
    var goal: Vector3 = heading * speed * lerpf(cruise, 1.0, alignment)
    var acceleration: float = acceleration_limit(org)
    if not spatial:
        goal.y = org.velocity.y
        if not org.grounded: acceleration *= 0.12
    org.velocity = org.velocity.move_toward(goal, acceleration * dt)
