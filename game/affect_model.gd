extends RefCounted

# Operational affect variables, not a claim of subjective consciousness.
static func capacity(org) -> float:
    var development: float = org.intelligence + log(1.0 + org.complexity) * 0.12
    return clampf((development - 0.45) / 2.0, 0.0, 1.0) * (0.25 + org.genome.affective_plasticity * 0.75)

static func advance(org, dt: float, social: Vector3, threat: Vector3) -> void:
    var ability: float = capacity(org)
    var rate: float = minf(1.0, dt * (0.20 + org.genome.affective_plasticity * 0.50))
    var distress: float = clampf(org.fear + (1.0 - org.oxygen) * 0.7 + org.tissue_damage * 0.6, 0.0, 1.0)
    var satiation: float = clampf((org.energy - 0.65) * 1.6, 0.0, 1.0)
    var connection: float = 1.0 if org.pair_target_id >= 0 or org.carrying_count > 0 else clampf(social.length() * 0.2, 0.0, 1.0)
    org.affect_valence = lerpf(org.affect_valence, (satiation - distress) * ability, rate)
    org.affect_arousal = lerpf(org.affect_arousal, clampf(threat.length() * 0.4 + org.hunger * 0.5 + org.curiosity_state * 0.2, 0.0, 1.0) * ability, rate)
    org.affect_bond = lerpf(org.affect_bond, connection * org.genome.cooperation * ability, rate * 0.5)
    org.emotion = "reflex"
    if ability < 0.08: return
    if distress > 0.50: org.emotion = "distress"
    elif org.affect_bond > 0.18: org.emotion = "attachment"
    elif org.affect_valence > 0.20: org.emotion = "contentment"
    elif org.curiosity_state > 0.50: org.emotion = "curiosity"
    else: org.emotion = "caution"

static func steering(org, social: Vector3, threat: Vector3) -> Vector3:
    return social * org.affect_bond * 0.30 - threat * org.affect_arousal * 0.25 + org.wander_direction * maxf(0.0, org.affect_valence) * 0.08
