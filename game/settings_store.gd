extends Node

const VERSION = "1.0.0-alpha12"
const RELEASE_DATE = "2026-09-01"

var defaults = {
    "language": "en",
    "simulation_speed": 1.0,
    "simulation_tick_hz": 12.0,
    "evolution_rate": 1.0,
    "organism_cap": 28,
    "initial_organisms": 16,
    "nutrient_count": 540,
    "visual_cell_cap": 180,
    "world_size": 144.0,
    "thought_mode": "text",
    "thought_interval": 7.0,
    "tts_voice": "default",
    "view_mode": "natural",
    "light_mode": "auto_sun",
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
    "max_history_events": 32,
    "body_rebuild_interval": 1.0,
    "mutation_strength": 0.14,
    "macro_mutation_rate": 0.14,
    "crossover_rate": 0.90,
    "viability_threshold": 0.18,
    "mate_cooldown": 16.0,
    "mating_radius": 18.0,
    "social_spacing": 4.5,
    "follow_distance": 6.0,
    "follow_height": 1.6,
    "neural_glow": true,
    "fullscreen": true,
    "habitat_level": 5,
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

func save_settings() -> void:
    var dir = path.get_base_dir()
    DirAccess.make_dir_recursive_absolute(dir)
    var f = FileAccess.open(path, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(data, "  "))

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
