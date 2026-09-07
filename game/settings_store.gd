extends Node

const VERSION = "1.0.0-alpha38"
const RELEASE_DATE = "2026-09-07"

var defaults = {
    "language": "en",
    "simulation_speed": 1.0,
    "simulation_tick_hz": 12.0,
    "evolution_rate": 1.0,
    "organism_cap": 28,
    "initial_organisms": 10,
    "nutrient_count": 540,
    "visual_cell_cap": 180,
    "contact_quality": 85,
    "gravity_scale": 1.0,
    "world_size": 288.0,
    "thought_mode": "text",
    "thought_interval": 7.0,
    "tts_voice": "default",
    "speech_language": "follow",
    "mcp_enabled": false,
    "vklp_enabled": false,
    "vklp_write_enabled": false,
    "vklp_url": "http://127.0.0.1:8000",
    "view_mode": "natural",
    "light_mode": "auto_sun",
    "light_pitch": -48.0,
    "light_yaw": 42.0,
    "renderer": "forward_plus",
    "move_speed": 14.0,
    "mouse_sensitivity": 0.0023,
    "camera_fov": 78.0,
    "zoom_step": 4.0,
    "show_fps": true,
    "show_help_hint": true,
    "auto_reproduce": true,
    "auto_reseed": true,
    "minimum_population": 5,
    "plant_evolution_bias": 0.35,
    "ecology_schema": 1,
    "life_cycle_schema": 1,
    "world_volume_schema": 1,
    "population_rescue_schema": 1,
    "startup_form_schema": 1,
    "texture_default_schema": 1,
    "max_history_events": 32,
    "body_rebuild_interval": 1.0,
    "nutrient_renewal": 1.0,
    "temperature_offset": 0.0,
    "mutation_strength": 0.14,
    "macro_mutation_rate": 0.014,
    "crossover_rate": 0.90,
    "viability_threshold": 0.18,
    "mate_cooldown": 16.0,
    "mating_radius": 18.0,
    "social_spacing": 4.5,
    "follow_distance": 6.0,
    "follow_height": 1.6,
    "camera_noclip": false,
    "observer_presence": false,
    "show_hud": true,
    "show_crosshair": true,
    "show_wireframe": true,
    "neural_glow": true,
    "textures_enabled": true,
    "fullscreen": true,
    "habitat_level": 7,
    "world_step": 1.0,
    "courtship_strength": 0.75,
    "group_strength": 0.55,
    "predation_strength": 0.45,
    "hierarchy_strength": 0.35,
    "audio_enabled": true,
    "ambient_audio": true,
    "organism_audio": true,
    "audio_volume": 0.45,
    "organism_sound_interval": 4.5
}

var data: Dictionary = {}
var path = ""

func _ready() -> void:
    path = ProjectSettings.globalize_path("res://settings/config.json")
    data = defaults.duplicate(true)
    load_settings()

func load_settings() -> void:
    if not FileAccess.file_exists(path):
        save_settings()
        return
    var f = FileAccess.open(path, FileAccess.READ)
    if not f:
        return
    if f.get_length() > 65536:
        f.close()
        return
    var parsed = JSON.parse_string(f.get_as_text())
    f.close()
    if parsed is Dictionary:
        # Local config needs the same type/range validation as imported profiles.
        # Recover valid fields individually so one broken option cannot prevent startup.
        var valid: Dictionary = {}
        for key in parsed:
            var checked: Dictionary = validate_profile({key: parsed[key]})
            if checked.has("settings"): valid.merge(checked["settings"])
            elif str(key).ends_with("_schema") and defaults.has(key) and (parsed[key] is int or parsed[key] is float) and is_finite(float(parsed[key])) and float(parsed[key]) >= 0.0:
                valid[key] = int(parsed[key])
        parsed = valid
        for key in parsed: data[key] = parsed[key]
        # One-time migration: double old dimensions; never double again on restart.
        if int(parsed.get("ecology_schema", 0)) < 1:
            data["world_size"] = maxf(144.0, float(parsed.get("world_size", 72.0)) * 2.0)
            data["nutrient_count"] = maxi(540, int(parsed.get("nutrient_count", 180)))
            data["ecology_schema"] = 1
            save_settings()

        if int(parsed.get("life_cycle_schema", 0)) < 1:
            if int(parsed.get("habitat_level", 5)) == 5:
                data["habitat_level"] = 7
            data["life_cycle_schema"] = 1
            save_settings()

        # Alpha23 doubles the horizontal habitat while keeping terrain/depth
        # proportions independent and adding 50% dedicated upper airspace.
        if int(parsed.get("world_volume_schema", 0)) < 1:
            data["world_size"] = clampf(maxf(288.0, float(parsed.get("world_size", 144.0)) * 2.0), 40.0, 1000.0)
            data["world_volume_schema"] = 1
            save_settings()

        # Alpha24 turns the old event-only reseed into a continuously checked,
        # user-disableable population floor. Preserve an explicit old switch;
        # missing values use the new default. Do not overwrite later choices.
        if int(parsed.get("population_rescue_schema", 0)) < 1:
            data["auto_reseed"] = parsed.get("auto_reseed", true)
            data["minimum_population"] = 5
            data["population_rescue_schema"] = 1
            save_settings()

        # Alpha27 changes the fresh-world default from sixteen repeated
        # founders to ten distinct samples from a startup pool. The pool can
        # grow independently of the population so new worlds stay varied
        # without spawning extra organisms.
        # Preserve an intentionally changed value; only migrate the old
        # untouched default.
        if int(parsed.get("startup_form_schema", 0)) < 1:
            if int(parsed.get("initial_organisms", 16)) == 16:
                data["initial_organisms"] = 10
            data["startup_form_schema"] = 1
            save_settings()

        # Alpha37 makes the supplied texture set the normal presentation.
        # A missing marker means the old false value came from the former
        # package default; migrate it once, after which the user can switch
        # textures off explicitly without it being changed again.
        if int(parsed.get("texture_default_schema", 0)) < 1:
            data["textures_enabled"] = true
            data["texture_default_schema"] = 1
            save_settings()

func save_settings() -> void:
    var dir = path.get_base_dir()
    DirAccess.make_dir_recursive_absolute(dir)
    var temporary: String = path + ".tmp"
    var f = FileAccess.open(temporary, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(data, "  "))
        f.flush()
        var status: Error = f.get_error()
        f.close()
        if status == OK:
            DirAccess.rename_absolute(temporary, path)
        else:
            DirAccess.remove_absolute(temporary)

func get_value(key: String, fallback = null):
    if data.has(key):
        return data[key]
    if defaults.has(key):
        return defaults[key]
    return fallback

func set_value(key: String, value) -> void:
    if defaults.has(key):
        data[key] = value
        save_settings()

func export_profile(destination: String) -> Error:
    var temporary: String = destination + ".tmp"
    var f = FileAccess.open(temporary, FileAccess.WRITE)
    if not f: return FileAccess.get_open_error()
    f.store_string(JSON.stringify({"schema": "arena.settings/1", "settings": data}, "  "))
    f.flush()
    var status: Error = f.get_error()
    f.close()
    if status == OK: status = DirAccess.rename_absolute(temporary, destination)
    if status != OK: DirAccess.remove_absolute(temporary)
    return status

func read_profile(source: String) -> Dictionary:
    var f = FileAccess.open(source, FileAccess.READ)
    if not f: return {"error": "profile_read_error"}
    if f.get_length() > 65536: return {"error": "profile_invalid"}
    var parsed = JSON.parse_string(f.get_as_text())
    if not parsed is Dictionary or parsed.get("schema", "") != "arena.settings/1" or not parsed.get("settings") is Dictionary:
        return {"error": "profile_invalid"}
    return validate_profile(parsed["settings"])

func validate_profile(values: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    var enums: Dictionary = {"language": ["en", "de", "fr"], "speech_language": ["follow", "en", "de", "fr"], "view_mode": ["natural", "cell", "neural", "energy"], "thought_mode": ["off", "text", "tts", "both"], "renderer": ["forward_plus", "mobile", "compatibility"], "light_mode": ["auto_sun", "random", "top_left", "top_right", "bottom_left", "bottom_right", "left_middle", "right_middle", "center", "back"]}
    var ranges: Dictionary = {"gravity_scale": [0.2, 2.5], "simulation_speed": [0.25, 3.0], "simulation_tick_hz": [3, 30], "evolution_rate": [0.1, 4.0], "organism_cap": [8, 80], "initial_organisms": [2, 80], "minimum_population": [1, 80], "plant_evolution_bias": [0, 1], "nutrient_count": [32, 1000], "visual_cell_cap": [48, 420], "contact_quality": [0, 100], "world_size": [40, 1000], "thought_interval": [2, 25], "camera_fov": [28, 105], "zoom_step": [1, 12], "light_pitch": [-90, 90], "light_yaw": [-360, 360], "move_speed": [1, 100], "mouse_sensitivity": [0.0001, 0.03], "max_history_events": [4, 96], "body_rebuild_interval": [0.25, 6], "nutrient_renewal": [0, 4], "temperature_offset": [-12, 12], "mutation_strength": [0, 0.5], "macro_mutation_rate": [0, 0.6], "crossover_rate": [0, 1], "viability_threshold": [0, 0.75], "mate_cooldown": [2, 90], "mating_radius": [3, 40], "social_spacing": [1.5, 12], "follow_distance": [2, 20], "follow_height": [0, 8], "habitat_level": [5, 9], "world_step": [0.25, 4], "courtship_strength": [0, 2], "group_strength": [0, 2], "predation_strength": [0, 2], "hierarchy_strength": [0, 2], "audio_volume": [0, 1], "organism_sound_interval": [1, 20]}
    for key in values:
        if not defaults.has(key) or key in ["ecology_schema", "life_cycle_schema", "world_volume_schema", "population_rescue_schema", "startup_form_schema", "texture_default_schema"]: continue
        var value = values[key]
        var initial = defaults[key]
        if initial is bool:
            if not value is bool: return {"error": "profile_invalid"}
        elif initial is int or initial is float:
            if not (value is int or value is float) or not is_finite(float(value)): return {"error": "profile_invalid"}
            if initial is int and float(value) != floor(float(value)): return {"error": "profile_invalid"}
            if ranges.has(key) and (float(value) < ranges[key][0] or float(value) > ranges[key][1]): return {"error": "profile_invalid"}
            value = int(value) if initial is int else float(value)
        elif initial is String:
            if not value is String or value.length() > 2048: return {"error": "profile_invalid"}
            if enums.has(key) and value not in enums[key]: return {"error": "profile_invalid"}
            if key == "vklp_url" and not (value.begins_with("https://") or value.begins_with("http://127.0.0.1:") or value.begins_with("http://localhost:")):
                return {"error": "profile_invalid"}
        result[key] = value
    if result.is_empty(): return {"error": "profile_invalid"}
    return {"settings": result}
