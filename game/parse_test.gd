extends SceneTree

# Runtime parser probe. Each file is loaded independently. Godot may return a Script resource even after reporting a parser
# error, so alpha4 incorrectly printed PARSE OK for broken files. The explicit
# can_instantiate() check plus installer-side SCRIPT ERROR scanning makes parser
# failures fatal without hot-reloading already-instantiated autoload scripts.
const CORE_SCRIPTS = [
    "res://game/settings_store.gd",
    "res://game/dna_codec.gd",
    "res://game/cell_cycle.gd",
    "res://game/affect_model.gd",
    "res://game/thought_language.gd",
    "res://game/body_contact.gd",
    "res://game/body_support.gd",
    "res://game/support_test_terrain.gd",
    "res://game/support_test.gd",
    "res://game/posture_test.gd",
    "res://game/locomotion.gd",
    "res://game/navigation.gd",
    "res://game/navigation_test.gd",
    "res://game/anatomical_rig.gd",
    "res://game/locomotion_test.gd",
    "res://game/interaction_test.gd",
    "res://game/app_log.gd",
    "res://game/localization.gd",
    "res://game/tts_windows.gd",
    "res://game/genome.gd",
    "res://game/physiology.gd",
    "res://game/experiment_api.gd",
    "res://game/ai_gateway.gd",
    "res://game/biology_test.gd",
    "res://game/experiment_test.gd",
    "res://game/ecology_traits.gd",
    "res://game/habitat_model.gd",
    "res://game/ecology_system.gd",
    "res://game/ecology_test.gd",
    "res://game/surface_test.gd",
    "res://game/life_cycle.gd",
    "res://game/reproduction_system.gd",
    "res://game/reproduction_test_world.gd",
    "res://game/life_cycle_test.gd",
    "res://game/nutrient_field.gd",
    "res://game/habitat_visual.gd",
    "res://game/audio_ecosystem.gd",
    "res://game/free_swim_camera.gd",
    "res://game/organism_visual.gd",
    "res://game/organism.gd",
    "res://game/obj_exporter.gd",
    "res://game/sim_world.gd",
    "res://game/arena_ui.gd",
    "res://game/main.gd",
    "res://game/self_test.gd",
    "res://game/smoke_test.gd"
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
