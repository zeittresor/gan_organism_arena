extends SceneTree

# Runtime parser probe. Each file is loaded independently. Godot may return a Script resource even after reporting a parser
# error, so alpha4 incorrectly printed PARSE OK for broken files. The explicit
# can_instantiate() check plus installer-side SCRIPT ERROR scanning makes parser
# failures fatal without hot-reloading already-instantiated autoload scripts.
const CORE_SCRIPTS = [
    "res://game/settings_store.gd",
    "res://game/app_log.gd",
    "res://game/localization.gd",
    "res://game/tts_windows.gd",
    "res://game/genome.gd",
    "res://game/nutrient_field.gd",
    "res://game/free_swim_camera.gd",
    "res://game/organism_visual.gd",
    "res://game/organism.gd",
    "res://game/obj_exporter.gd",
    "res://game/sim_world.gd",
    "res://game/arena_ui.gd",
    "res://game/main.gd",
    "res://game/self_test.gd"
]

func _initialize() -> void:
    var failures: Array[String] = []
    for path in CORE_SCRIPTS:
        print("PARSE CHECK: %s" % path)
        var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
        if resource == null:
            failures.append(path)
            print("PARSE FAILED: %s (resource load returned null)" % path)
            continue
        if not (resource is Script):
            failures.append(path)
            print("PARSE FAILED: %s (resource is not a Script)" % path)
            continue
        var script_resource: Script = resource as Script
        if not script_resource.can_instantiate():
            failures.append(path)
            print("PARSE FAILED: %s (script cannot instantiate)" % path)
            continue
        print("PARSE OK: %s" % path)

    if not failures.is_empty():
        print("PARSE TEST FAILED: %d script(s): %s" % [failures.size(), ", ".join(failures)])
        quit(1)
        return
    print("PARSE TEST OK: all core scripts loaded and can instantiate successfully.")
    quit(0)
