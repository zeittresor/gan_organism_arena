extends Node

var language = "en"
var fallback: Dictionary = {}
var active: Dictionary = {}

func _ready() -> void:
    _load_fallback()
    set_language(str(SettingsStore.get_value("language", "en")), false)

func _load_json(code: String) -> Dictionary:
    var path = "res://language/%s.json" % code
    if not FileAccess.file_exists(path):
        return {}
    var f = FileAccess.open(path, FileAccess.READ)
    if not f:
        return {}
    var value = JSON.parse_string(f.get_as_text())
    return value if value is Dictionary else {}

func _load_fallback() -> void:
    fallback = _load_json("en")

func available_languages() -> Array[String]:
    var result: Array[String] = []
    var dir = DirAccess.open("res://language")
    if dir:
        dir.list_dir_begin()
        var file = dir.get_next()
        while file != "":
            if not dir.current_is_dir() and file.to_lower().ends_with(".json"):
                result.append(file.get_basename())
            file = dir.get_next()
        dir.list_dir_end()
    result.sort()
    if result.has("en"):
        result.erase("en")
        result.push_front("en")
    if result.is_empty():
        result.append("en")
    return result

func set_language(code: String, save = true) -> void:
    var candidate = _load_json(code)
    if candidate.is_empty():
        code = "en"
        candidate = fallback
    language = code
    active = candidate
    if save:
        SettingsStore.set_value("language", code)

func text(key: String, fallback_text = "") -> String:
    var value = _lookup(active, key)
    if value == null:
        value = _lookup(fallback, key)
    if value == null:
        return fallback_text if fallback_text != "" else key
    return str(value)

func _lookup(root: Dictionary, key: String):
    var current: Variant = root
    for part in key.split("."):
        if not current is Dictionary or not current.has(part):
            return null
        current = current[part]
    return current
