extends Node

const Main = preload("res://game/main.gd")
var checks: int = 0
var failures: int = 0
func check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        printerr("UI SELFTEST ERROR: " + message)

func key(app, code: int) -> void:
    var event = InputEventKey.new()
    event.keycode = code
    event.pressed = true
    app._unhandled_input(event)

func run_all() -> bool:
    var settings: Dictionary = SettingsStore.data.duplicate(true)
    var mouse_mode = Input.mouse_mode
    SettingsStore.data["mcp_enabled"] = false
    SettingsStore.data["vklp_enabled"] = false
    SettingsStore.data["fullscreen"] = false
    SettingsStore.data["initial_organisms"] = 2
    SettingsStore.data["auto_reseed"] = false
    SettingsStore.data["nutrient_count"] = 32
    SettingsStore.data["visual_cell_cap"] = 64
    var app = Main.new()
    add_child(app)
    var count: int = app.sim_world.organisms.size()
    key(app, KEY_ESCAPE)
    check(app.ui.exit_open and app.sim_world.simulation_paused and not app.swim_camera.enabled, "ESC pauses and releases observer")
    key(app, KEY_G)
    key(app, KEY_9)
    key(app, KEY_SPACE)
    check(app.sim_world.organisms.size() == count and app.sim_world.habitat_level == 7 and not app.manual_pause, "exit prompt blocks world shortcuts")
    key(app, KEY_ESCAPE)
    check(not app.panel_pause and not app.sim_world.simulation_paused, "ESC cancel resumes previous state")
    key(app, KEY_P)
    key(app, KEY_F10)
    key(app, KEY_G)
    check(app.sim_world.organisms.size() == count, "settings block organism injection shortcut")
    key(app, KEY_ESCAPE)
    key(app, KEY_ESCAPE)
    check(app.ui.settings_open and app.manual_pause, "cancel restores options and manual pause")
    for language in ["de", "fr", "en"]:
        app._on_setting_changed("language", language)
        check(app.ui.help_text.text.contains(L10n.text("tooltips.save_world")), "translated save help: " + language)
    app._on_setting_changed("show_hud", false)
    app._on_setting_changed("show_crosshair", false)
    check(not app.ui.hud.visible and not app.ui.crosshair.visible, "HUD and crosshair switches")
    app._on_setting_changed("textures_enabled", true)
    check(TextureAssets.enabled, "textures enabled through settings")
    app._reload_textures()
    app._on_setting_changed("textures_enabled", false)
    check(not TextureAssets.enabled, "textures disabled through settings")
    app._on_setting_changed("world_size", 100.0)
    check(is_equal_approx(app.sim_world.half_extent * 2.0, 102.0), "world size profile applies to current world")
    app._on_setting_changed("move_speed", 21.0)
    app._on_setting_changed("mouse_sensitivity", 0.004)
    check(app.swim_camera.move_speed == 21.0 and app.swim_camera.mouse_sensitivity == 0.004, "camera profile options apply immediately")
    app._set_selected(app.sim_world.organisms[0])
    app.swim_camera.toggle_follow(app.sim_world.selected)
    var path: String = "user://ui-world-roundtrip.arena"
    check(app._save_world(path), "save through main application")
    var previous = app.sim_world
    app._world_file_selected(path, false)
    check(app.sim_world != previous and app.sim_world.organisms.size() == count, "load replaces world after validation")
    check(app.sim_world.simulation_paused and app.manual_pause, "loaded world starts paused")
    check(is_instance_valid(app.sim_world.selected) and is_instance_valid(app.swim_camera.follow_target), "selection and follow restored")
    app.ui.file_result.hide()
    previous = app.sim_world
    app._world_file_selected("user://no-such-world.arena", false)
    check(app.sim_world == previous, "invalid load retains current world")
    app.ui.file_result.hide()
    app._reset_world()
    check(app.sim_world.simulation_paused and app.swim_camera.follow_target == null, "reset clears stale follow and preserves pause")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    app.free()
    SettingsStore.data = settings
    SettingsStore.save_settings()
    L10n.set_language(str(settings["language"]))
    TextureAssets.set_enabled(bool(settings["textures_enabled"]))
    Input.mouse_mode = mouse_mode
    print("UI SELFTEST: %d checks; %d failures" % [checks, failures])
    return failures == 0
