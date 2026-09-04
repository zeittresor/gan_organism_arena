extends Node

const VERSION = "1.0.0-alpha22"
const RELEASE_DATE = "2026-09-04"

var defaults = {
    "language": "en",
    "simulation_speed": 1.0,
    "simulation_tick_hz": 12.0,
    "evolution_rate": 1.0,
    "organism_cap": 28,
    "initial_organisms": 16,
    "nutrient_count": 540,
    "visual_cell_cap": 180,
    "contact_quality": 85,
    "gravity_scale": 1.0,
    "world_size": 144.0,
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
    "auto_reseed": false,
    "ecology_schema": 1,
    "life_cycle_schema": 1,
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
    "neural_glow": true,
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
    var parsed = JSON.parse_string(f.get_as_text())
    if parsed is Dictionary:
        for key in parsed:
            if defaults.has(key):
                data[key] = parsed[key]
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

func save_settings() -> void:
    var dir = path.get_base_dir()
    DirAccess.make_dir_recursive_absolute(dir)
    var temporary: String = path + ".tmp"
    var f = FileAccess.open(temporary, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(data, "  "))
        f.close()
        DirAccess.rename_absolute(temporary, path)

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
    var f = FileAccess.open(destination, FileAccess.WRITE)
    if not f: return FileAccess.get_open_error()
    f.store_string(JSON.stringify({"schema": "arena.settings/1", "settings": data}, "  "))
    f.close()
    return OK

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
    var ranges: Dictionary = {"gravity_scale": [0.2, 2.5], "simulation_speed": [0.25, 3.0], "simulation_tick_hz": [3, 30], "evolution_rate": [0.1, 4.0], "organism_cap": [8, 80], "initial_organisms": [2, 80], "nutrient_count": [32, 1000], "visual_cell_cap": [48, 420], "contact_quality": [0, 100], "world_size": [40, 1000], "thought_interval": [2, 25], "camera_fov": [28, 105], "zoom_step": [1, 12], "light_pitch": [-90, 90], "light_yaw": [-360, 360], "move_speed": [1, 100], "mouse_sensitivity": [0.0001, 0.03], "max_history_events": [4, 96], "body_rebuild_interval": [0.25, 6], "nutrient_renewal": [0, 4], "temperature_offset": [-12, 12], "mutation_strength": [0, 0.5], "macro_mutation_rate": [0, 0.6], "crossover_rate": [0, 1], "viability_threshold": [0, 0.75], "mate_cooldown": [2, 90], "mating_radius": [3, 40], "social_spacing": [1.5, 12], "follow_distance": [2, 20], "follow_height": [0, 8], "habitat_level": [5, 9], "world_step": [0.25, 4], "courtship_strength": [0, 2], "group_strength": [0, 2], "predation_strength": [0, 2], "hierarchy_strength": [0, 2], "audio_volume": [0, 1], "organism_sound_interval": [1, 20]}
    for key in values:
        if not defaults.has(key) or key in ["ecology_schema", "life_cycle_schema"]: continue
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
