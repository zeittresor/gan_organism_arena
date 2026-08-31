extends RefCounted

var seed: int = 1
var generation: int = 0
var family_id: int = 0
var hue: float = 0.45
var symmetry: float = 0.75
var elongation: float = 0.55
var limb_drive: float = 0.55
var branch_drive: float = 0.35
var fin_drive: float = 0.35
var armor_drive: float = 0.25
var sensory_drive: float = 0.55
var neural_drive: float = 0.50
var cooperation: float = 0.45
var aggression: float = 0.25
var curiosity: float = 0.55
var metabolism: float = 0.50
var buoyancy: float = 0.50
var reproduction: float = 0.50
var vocal_drive: float = 0.35

func randomize_from(rng: RandomNumberGenerator, p_family_id: int) -> void:
    seed = int(rng.randi())
    family_id = p_family_id
    generation = 0
    hue = rng.randf()
    symmetry = rng.randf_range(0.25, 1.0)
    elongation = rng.randf_range(0.2, 0.95)
    limb_drive = rng.randf_range(0.1, 0.95)
    branch_drive = rng.randf_range(0.05, 0.9)
    fin_drive = rng.randf_range(0.05, 0.95)
    armor_drive = rng.randf_range(0.0, 0.9)
    sensory_drive = rng.randf_range(0.15, 1.0)
    neural_drive = rng.randf_range(0.1, 1.0)
    cooperation = rng.randf()
    aggression = rng.randf()
    curiosity = rng.randf_range(0.1, 1.0)
    metabolism = rng.randf_range(0.25, 0.9)
    buoyancy = rng.randf_range(0.2, 0.8)
    reproduction = rng.randf_range(0.2, 0.9)
    vocal_drive = rng.randf_range(0.05, 1.0)

func mutated(rng: RandomNumberGenerator, strength: float = 0.10):
    var script_resource = get_script()
    var g = script_resource.new()
    g.seed = int(rng.randi())
    g.generation = generation + 1
    g.family_id = family_id
    var names: Array[String] = [
        "hue", "symmetry", "elongation", "limb_drive", "branch_drive",
        "fin_drive", "armor_drive", "sensory_drive", "neural_drive",
        "cooperation", "aggression", "curiosity", "metabolism", "buoyancy",
        "reproduction", "vocal_drive"
    ]
    for property_name in names:
        var value: float = float(get(property_name)) + rng.randfn(0.0, strength)
        if property_name == "hue":
            value = fposmod(value, 1.0)
        else:
            value = clampf(value, 0.0, 1.0)
        g.set(property_name, value)
    return g

func base_color() -> Color:
    return Color.from_hsv(hue, 0.66, 0.92)
