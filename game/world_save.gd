extends RefCounted

# Data-only local checkpoints. No scripts, arbitrary Objects or resource paths
# are deserialized. Runtime nodes/render buffers are rebuilt from the saved DNA.
const Genome = preload("res://game/genome.gd")
const SkinPatternScript = preload("res://game/skin_pattern.gd")
const SCHEMA: String = "arena.checkpoint/1"
const MAX_BYTES: int = 67108864
const MAGIC: String = "GANARENA1\n"
var last_error: String = ""

func capture(world, camera, settings: Dictionary) -> Dictionary:
    var bodies: Array = []
    for org in world.organisms:
        if not is_instance_valid(org): continue
        bodies.append({"state": fields(org, ["visual", "habitat", "support_habitat", "support_heights"]), "transform": org.transform,
            "animation_time": org.visual._animation_time, "gait_phase": org.visual.gait_phase})
    return {"schema": SCHEMA, "version": "1.0.0-alpha38", "settings": settings.duplicate(true),
        "world": fields(world, ["organisms", "selected", "observer_camera", "habitat", "ecology", "reproduction", "evolution_history", "nutrient_field", "simulation_paused", "experiment_mode"]),
        "organisms": bodies, "nutrients": fields(world.nutrient_field, ["habitat", "multimesh_instance"]),
        "ecology": fields(world.ecology, ["habitat", "population", "id_map", "rooted_counts"]),
        "reproduction": fields(world.reproduction), "evolution": fields(world.evolution_history, ["by_id"]),
        "camera": {"transform": camera.transform, "fov": camera.camera.fov, "follow_id": camera.follow_target.organism_id if is_instance_valid(camera.follow_target) else -1},
        "selected_id": world.selected.organism_id if is_instance_valid(world.selected) else -1}

func fields(object, excluded: Array = []) -> Dictionary:
    var result: Dictionary = {}
    for property in object.get_property_list():
        var key: String = property["name"]
        if not (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) or key in excluded: continue
        var value = object.get(key)
        if value is Object and not (value is Genome or value is SkinPatternScript or value is RandomNumberGenerator): continue
        result[key] = encode(value)
    return result

func encode(value):
    if value is Genome: return {"$arena_type": "genome", "fields": fields(value)}
    if value is SkinPatternScript:
        return {"$arena_type": "skin", "weights": value.source_weights.duplicate(true), "inherited": value.inherited, "parents": value.parent_count,
            "png": value.image.save_png_to_buffer() if value.image != null else PackedByteArray()}
    if value is RandomNumberGenerator: return {"$arena_type": "rng", "seed": value.seed, "state": value.state}
    if value is Object: return null
    if value is Array:
        var result: Array = []
        for item in value: result.append(encode(item))
        return result
    if value is Dictionary:
        var result: Dictionary = {}
        for key in value: result[key] = encode(value[key])
        return result
    return value

func decode(value):
    if value is Dictionary:
        match value.get("$arena_type", ""):
            "genome":
                var g = Genome.new()
                if not restore_fields(g, value.get("fields", {})): return null
                return g
            "skin":
                var skin = SkinPatternScript.new()
                skin.source_weights = value.get("weights", {}).duplicate(true)
                skin.inherited = bool(value.get("inherited", false))
                skin.parent_count = int(value.get("parents", 0))
                var png: PackedByteArray = value.get("png", PackedByteArray())
                if not png.is_empty():
                    var pixels = Image.new()
                    if pixels.load_png_from_buffer(png) != OK or pixels.get_width() != 128 or pixels.get_height() != 128:
                        last_error = "Invalid inherited texture"
                        return null
                    skin.image = pixels
                return skin
            "rng":
                var rng = RandomNumberGenerator.new()
                rng.seed = int(value.get("seed", 0))
                rng.state = int(value.get("state", 0))
                return rng
        var result: Dictionary = {}
        for key in value: result[key] = decode(value[key])
        return result
    if value is Array:
        var result: Array = []
        for item in value: result.append(decode(item))
        return result
    return value

func restore_fields(object, values: Dictionary) -> bool:
    for property in object.get_property_list():
        var key: String = property["name"]
        if not (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) or not values.has(key): continue
        var previous = object.get(key)
        var value = decode(values[key])
        if not last_error.is_empty(): return false
        if previous is Array:
            if not value is Array:
                last_error = "Invalid array: " + key
                return false
            if previous.is_typed():
                for item in value:
                    if typeof(item) != previous.get_typed_builtin():
                        last_error = "Invalid array element: " + key
                        return false
            previous.assign(value)
        elif previous != null and typeof(previous) != typeof(value):
            last_error = "Invalid property: " + key
            return false
        else:
            object.set(key, value)
    return true

func write_file(path: String, data: Dictionary) -> bool:
    last_error = ""
    var bytes: PackedByteArray = var_to_bytes(data)
    if bytes.size() > MAX_BYTES:
        last_error = "Checkpoint exceeds 64 MiB"
        return false
    bytes = MAGIC.to_utf8_buffer() + digest(bytes) + bytes
    var temporary: String = path + ".tmp"
    var file = FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        last_error = "Cannot open checkpoint for writing"
        return false
    file.store_buffer(bytes)
    file.flush()
    var status: Error = file.get_error()
    file.close()
    if status != OK or FileAccess.get_file_as_bytes(temporary) != bytes:
        DirAccess.remove_absolute(temporary)
        last_error = "Checkpoint write verification failed"
        return false
    if DirAccess.rename_absolute(temporary, path) != OK:
        DirAccess.remove_absolute(temporary)
        last_error = "Cannot replace checkpoint"
        return false
    return true

func read_file(path: String) -> Dictionary:
    last_error = ""
    var file = FileAccess.open(path, FileAccess.READ)
    if file == null:
        last_error = "Cannot read checkpoint"
        return {}
    if file.get_length() > MAX_BYTES or file.get_length() < 8:
        last_error = "Invalid checkpoint size"
        return {}
    var bytes: PackedByteArray = file.get_buffer(file.get_length())
    file.close()
    var header: int = MAGIC.length()
    if bytes.size() < header + 32 or bytes.slice(0, header).get_string_from_utf8() != MAGIC:
        last_error = "Invalid checkpoint header"
        return {}
    var payload: PackedByteArray = bytes.slice(header + 32)
    if digest(payload) != bytes.slice(header, header + 32):
        last_error = "Checkpoint checksum mismatch"
        return {}
    # bytes_to_var never enables object deserialization (unlike *_with_objects).
    var data = bytes_to_var(payload)
    if not data is Dictionary or data.get("schema") != SCHEMA:
        last_error = "Unknown checkpoint format"
        return {}
    for key in ["settings", "world", "nutrients", "ecology", "reproduction", "evolution", "camera"]:
        if not data.get(key) is Dictionary:
            last_error = "Missing checkpoint section: " + key
            return {}
    if not data.get("organisms") is Array or data["organisms"].size() > 80:
        last_error = "Invalid checkpoint population"
        return {}
    if not SettingsStore.validate_profile(data["settings"]).has("settings"):
        last_error = "Invalid checkpoint settings"
        return {}
    return data

func restore(world, data: Dictionary) -> bool:
    # The caller supplies a fresh, paused staging world. Failure never destroys
    # the currently viewed world; the caller discards this staging instance.
    last_error = ""
    if not restore_fields(world, data["world"]): return false
    world.experiment_settings = data["settings"].merged(world.experiment_settings, true)
    world.habitat.configure(world.habitat_level, world.half_extent * 2.0)
    world.nutrient_field = world.NutrientFieldScript.new()
    world.add_child(world.nutrient_field)
    world.nutrient_field.initialize(32, world.half_extent, world.run_seed + 91)
    world.nutrient_field.habitat = world.habitat
    if not restore_fields(world.nutrient_field, data["nutrients"]): return false
    if world.nutrient_field.points.size() != world.nutrient_field.reserves.size() or world.nutrient_field.points.size() > 2000:
        last_error = "Invalid nutrient field"
        return false
    world.nutrient_field._upload()
    if not restore_fields(world.ecology, data["ecology"]): return false
    world.ecology.habitat = world.habitat
    if world.ecology.resources.size() != world.ecology.stocks.size():
        last_error = "Invalid resource stocks"
        return false
    var ids: Dictionary = {}
    for item in data["organisms"]:
        if not item is Dictionary or not item.get("state") is Dictionary or not item.get("transform") is Transform3D:
            last_error = "Invalid organism record"
            return false
        var state: Dictionary = item["state"]
        var genome = decode(state.get("genome"))
        var oid: int = int(state.get("organism_id", -1))
        if not genome is Genome or oid < 1 or ids.has(oid):
            last_error = "Invalid DNA or organism ID"
            return false
        ids[oid] = true
        var org = world.OrganismScript.new()
        world.add_child(org)
        org.habitat = world.habitat
        org.initialize(oid, genome, item["transform"].origin, world.visual_cap, world.view_mode)
        world.organisms.append(org)
        if not restore_fields(org, state): return false
        org.transform = item["transform"]
        org.support_timer = 0.0
        org.support_habitat = null
        org.visual.rebuild(true)
        org.visual._animation_time = float(item.get("animation_time", 0.0))
        org.visual.gait_phase = float(item.get("gait_phase", 0.0))
    if not restore_fields(world.reproduction, data["reproduction"]): return false
    if world.reproduction.broods.size() > 80 or world.reproduction.reserved_count() > 80:
        last_error = "Invalid embryo count"
        return false
    for brood in world.reproduction.broods:
        brood["marker"] = world.reproduction._make_marker(world, brood["position"], brood["route"])
        brood["marker"].visible = not brood["internal"]
    for cloud in world.reproduction.spawn_clouds:
        cloud["marker"] = world.reproduction._make_marker(world, cloud["position"], "spawn")
    if not restore_fields(world.evolution_history, data["evolution"]): return false
    for record in world.evolution_history.records:
        world.evolution_history.by_id[int(record["id"])] = record
    world.sim_accumulator = 0.0
    return last_error.is_empty()

func digest(bytes: PackedByteArray) -> PackedByteArray:
    var context = HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(bytes)
    return context.finish()
