extends Node3D

const SimWorldScript = preload("res://game/sim_world.gd")
const CameraScript = preload("res://game/free_swim_camera.gd")
const UIScript = preload("res://game/arena_ui.gd")
const TTSScript = preload("res://game/tts_windows.gd")
const OBJExporterScript = preload("res://game/obj_exporter.gd")

const APP_NAME = "GAN Organism Arena"
const VERSION = "1.0.0-alpha6"
const RELEASE_DATE = "2026-09-01"

var sim_world = null
var swim_camera = null
var ui = null
var sun: DirectionalLight3D
var environment: WorldEnvironment
var tts = TTSScript.new()
var thought_timer = 0.0
var speaker_index = 0
var hud_timer = 0.0
var perf_timer = 0.0
var auto_sun_time = 0.0
var manual_pause = false
var panel_pause = false
var _rng = RandomNumberGenerator.new()

func _ready() -> void:
    _rng.randomize()
    AppLog.info("Starting %s v%s (%s)" % [APP_NAME, VERSION, RELEASE_DATE])
    AppLog.info("Godot: %s | OS: %s | renderer setting: %s" % [Engine.get_version_info().get("string", "unknown"), OS.get_name(), str(SettingsStore.get_value("renderer", "forward_plus"))])
    _apply_window_mode()
    _build_environment()
    _build_aquarium_bounds()
    _build_dust()
    _create_world()
    _create_camera()
    _create_ui()
    _apply_light_mode(str(SettingsStore.get_value("light_mode", "auto_sun")))

func _create_world() -> void:
    sim_world = SimWorldScript.new()
    sim_world.name = "VolumetricLifeWorld"
    add_child(sim_world)
    sim_world.initialize(int(Time.get_unix_time_from_system()) & 0x7fffffff)

func _create_camera() -> void:
    swim_camera = CameraScript.new()
    swim_camera.name = "Observer"
    add_child(swim_camera)
    swim_camera.global_position = Vector3(0.0, 4.0, 34.0)
    swim_camera.rotation = Vector3(0.0, 0.0, 0.0)

func _create_ui() -> void:
    ui = UIScript.new()
    add_child(ui)
    ui.setting_changed.connect(_on_setting_changed)
    ui.action_requested.connect(_on_action_requested)
    ui.panels_changed.connect(_on_panels_changed)
    _refresh_selection_text()

func _build_environment() -> void:
    environment = WorldEnvironment.new()
    environment.name = "AquariumEnvironment"
    var env = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.006, 0.018, 0.032)
    env.background_energy_multiplier = 0.72
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.12, 0.24, 0.31)
    env.ambient_light_energy = 0.72
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color(0.06, 0.16, 0.22)
    env.fog_light_energy = 0.68
    env.fog_density = 0.0065
    env.fog_height = -24.0
    env.fog_height_density = 0.025
    environment.environment = env
    add_child(environment)

    sun = DirectionalLight3D.new()
    sun.name = "EvolutionSun"
    sun.light_color = Color(0.82, 0.93, 1.0)
    sun.light_energy = 1.35
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 95.0
    add_child(sun)

func _build_aquarium_bounds() -> void:
    var half = float(SettingsStore.get_value("world_size", 72.0)) * 0.5
    var yhalf = half * 0.60
    var mesh = ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    var c = Color(0.10, 0.48, 0.62, 0.24)
    mesh.surface_set_color(c)
    var corners = [
        Vector3(-half,-yhalf,-half), Vector3(half,-yhalf,-half), Vector3(half,-yhalf,half), Vector3(-half,-yhalf,half),
        Vector3(-half,yhalf,-half), Vector3(half,yhalf,-half), Vector3(half,yhalf,half), Vector3(-half,yhalf,half)
    ]
    var edges = [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]]
    for e in edges:
        mesh.surface_add_vertex(corners[e[0]])
        mesh.surface_add_vertex(corners[e[1]])
    # internal reference grid, sparse enough not to dominate the scene
    for i in range(-3, 4):
        var t = float(i) / 3.0 * half
        mesh.surface_add_vertex(Vector3(t, -yhalf, -half))
        mesh.surface_add_vertex(Vector3(t, -yhalf, half))
        mesh.surface_add_vertex(Vector3(-half, -yhalf, t))
        mesh.surface_add_vertex(Vector3(half, -yhalf, t))
    mesh.surface_end()
    var instance = MeshInstance3D.new()
    instance.mesh = mesh
    var mat = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.vertex_color_use_as_albedo = true
    instance.material_override = mat
    add_child(instance)

func _build_dust() -> void:
    var rng = RandomNumberGenerator.new()
    rng.seed = 17291
    var mm_instance = MultiMeshInstance3D.new()
    mm_instance.name = "WaterDust"
    var sphere = SphereMesh.new()
    sphere.radius = 0.035
    sphere.height = 0.07
    sphere.radial_segments = 4
    sphere.rings = 2
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.28, 0.68, 0.78, 0.20)
    mat.emission_enabled = true
    mat.emission = Color(0.08, 0.22, 0.26)
    mat.emission_energy_multiplier = 0.5
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    sphere.material = mat
    var mm = MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = sphere
    mm.instance_count = 380
    var half = float(SettingsStore.get_value("world_size", 72.0)) * 0.5
    for i in range(mm.instance_count):
        var p = Vector3(rng.randf_range(-half, half), rng.randf_range(-half * 0.58, half * 0.58), rng.randf_range(-half, half))
        var s = rng.randf_range(0.6, 2.2)
        mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), p))
    mm_instance.multimesh = mm
    add_child(mm_instance)

func _process(delta: float) -> void:
    if not is_instance_valid(sim_world) or not is_instance_valid(ui):
        return
    _update_sun(delta)
    thought_timer += delta
    hud_timer += delta
    perf_timer += delta
    if thought_timer >= float(SettingsStore.get_value("thought_interval", 7.0)):
        thought_timer = 0.0
        _emit_next_thought()
    if hud_timer >= 0.20:
        hud_timer = 0.0
        _refresh_hud()
        _refresh_selection_text()
    if perf_timer >= 10.0:
        perf_timer = 0.0
        var m: Dictionary = sim_world.metrics()
        AppLog.info("perf fps=%.1f organisms=%d steps=%d visual_cells=%d max_complexity=%.2f max_intelligence=%.3f renderer=%s" % [Performance.get_monitor(Performance.TIME_FPS), int(m["organisms"]), int(m["steps"]), int(m["visual_cells"]), float(m["max_complexity"]), float(m["max_intelligence"]), str(SettingsStore.get_value("renderer", "forward_plus"))])

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_F10:
                ui.toggle_settings()
            KEY_F1:
                ui.toggle_help()
            KEY_ESCAPE:
                if ui.settings_open:
                    ui.toggle_settings(false)
                elif ui.help_open:
                    ui.toggle_help(false)
                elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
                    swim_camera.release_mouse()
                else:
                    swim_camera.capture_mouse()
            KEY_SPACE:
                manual_pause = not manual_pause
                _sync_pause_state()
            KEY_G:
                sim_world.spawn_random()
            KEY_1:
                sim_world.set_view_mode("natural")
            KEY_2:
                sim_world.set_view_mode("cell")
            KEY_3:
                sim_world.set_view_mode("neural")
            KEY_4:
                sim_world.set_view_mode("energy")
            KEY_F8:
                _export_selected()
            KEY_F12:
                _save_screenshot()
            KEY_TAB:
                _select_next()
    elif event is InputEventMouseButton and event.pressed and not ui.settings_open and not ui.help_open:
        if event.button_index == MOUSE_BUTTON_LEFT:
            _select_from_crosshair()
        elif event.button_index == MOUSE_BUTTON_RIGHT and is_instance_valid(sim_world.selected):
            swim_camera.toggle_follow(sim_world.selected)

func _select_from_crosshair() -> void:
    if not swim_camera or not swim_camera.camera:
        return
    var origin: Vector3 = swim_camera.camera.global_position
    var direction: Vector3 = -swim_camera.camera.global_transform.basis.z.normalized()
    var best = null
    var best_t: float = INF
    for org in sim_world.organisms:
        if not is_instance_valid(org):
            continue
        var to_org: Vector3 = org.global_position - origin
        var t: float = to_org.dot(direction)
        if t < 0.0:
            continue
        var closest: Vector3 = origin + direction * t
        var threshold = 1.2 + minf(4.0, sqrt(float(org.visual.body_cells.size())) * 0.12)
        if closest.distance_to(org.global_position) <= threshold and t < best_t:
            best = org
            best_t = t
    _set_selected(best)

func _select_next() -> void:
    if sim_world.organisms.is_empty():
        _set_selected(null)
        return
    var idx = -1
    if is_instance_valid(sim_world.selected):
        idx = sim_world.organisms.find(sim_world.selected)
    idx = (idx + 1) % sim_world.organisms.size()
    _set_selected(sim_world.organisms[idx])

func _set_selected(org) -> void:
    if is_instance_valid(sim_world.selected):
        sim_world.selected.selected = false
    sim_world.selected = org
    if is_instance_valid(org):
        org.selected = true
    _refresh_selection_text()

func _emit_next_thought() -> void:
    var mode = str(SettingsStore.get_value("thought_mode", "text"))
    if mode == "off":
        ui.set_thought("")
        return
    var speakers: Array = sim_world.top_speakers(8)
    if speakers.is_empty():
        return
    speaker_index = speaker_index % speakers.size()
    var org = speakers[speaker_index]
    speaker_index += 1
    var text: String = str(org.generate_thought(_rng))
    var prefix = "#%d %s L%d" % [org.organism_id, org.family_name, org.language_stage]
    if mode in ["text", "both"]:
        ui.set_thought("%s: %s" % [prefix, text])
    else:
        ui.set_thought("")
    if mode in ["tts", "both"]:
        var spoken = tts.speak(text)
        AppLog.info("TTS thought speaker=%d stage=%d spoken=%s text=%s" % [org.organism_id, org.language_stage, str(spoken), text])

func _refresh_hud() -> void:
    var m: Dictionary = sim_world.metrics()
    var paused = manual_pause or panel_pause
    var mode = str(SettingsStore.get_value("view_mode", "natural"))
    ui.set_hud("%s %s | FPS %.1f | 3D steps %d | organisms %d | cells %d | max body %.1f | max mind %.2f | view %s%s" % [APP_NAME, VERSION, Performance.get_monitor(Performance.TIME_FPS), int(m["steps"]), int(m["organisms"]), int(m["visual_cells"]), float(m["max_complexity"]), float(m["max_intelligence"]), mode, " | PAUSED" if paused else ""])

func _refresh_selection_text() -> void:
    if not is_instance_valid(ui):
        return
    var org = sim_world.selected if is_instance_valid(sim_world) else null
    if not is_instance_valid(org):
        ui.set_selection(L10n.text("ui.no_selection", "No organism selected. Aim at one and left-click, or press Tab."))
        return
    ui.set_selection("Selected #%d %s | gen %d | age %.1fs | energy %.2f | complexity %.2f | intelligence %.3f | language L%d | children %d" % [org.organism_id, org.family_name, org.genome.generation, org.age_seconds, org.energy, org.complexity, org.intelligence, org.language_stage, org.children])

func _on_panels_changed(open: bool) -> void:
    panel_pause = open
    swim_camera.enabled = not open
    if open:
        swim_camera.release_mouse()
    else:
        swim_camera.capture_mouse()
    _sync_pause_state()

func _sync_pause_state() -> void:
    if is_instance_valid(sim_world):
        sim_world.process_mode = Node.PROCESS_MODE_DISABLED if (manual_pause or panel_pause) else Node.PROCESS_MODE_INHERIT

func _on_setting_changed(key: String, value) -> void:
    SettingsStore.set_value(key, value)
    match key:
        "language":
            L10n.set_language(str(value))
            ui.refresh_language()
        "fullscreen":
            _apply_window_mode()
        "view_mode":
            sim_world.set_view_mode(str(value))
        "light_mode":
            _apply_light_mode(str(value))
        "visual_cell_cap":
            sim_world.set_visual_cap(int(value))
        "nutrient_count":
            sim_world.set_nutrient_count(int(value))
        "renderer":
            ui.set_thought(L10n.text("ui.renderer_restart", "Rendering backend saved; restart the application to apply it."))
        _:
            pass

func _on_action_requested(action: String) -> void:
    match action:
        "rebuild_visuals":
            for org in sim_world.organisms:
                if is_instance_valid(org):
                    org.visual.recreate_render_resources()
            _apply_light_mode(str(SettingsStore.get_value("light_mode", "auto_sun")))
            ui.set_thought(L10n.text("ui.rebuilt", "Visual bodies and material/shader resources rebuilt."))
        "inject":
            sim_world.spawn_random()
        "export_selected":
            _export_selected()
        "reset_world":
            _reset_world()
        "close_settings":
            ui.toggle_settings(false)

func _export_selected() -> void:
    if not is_instance_valid(sim_world.selected):
        ui.set_thought(L10n.text("ui.select_first", "Select an organism first."))
        return
    var path: String = OBJExporterScript.export_organism(sim_world.selected)
    if path != "":
        ui.set_thought("OBJ: %s" % path)
        AppLog.info("OBJ export: %s" % path)

func _save_screenshot() -> void:
    var dir = ProjectSettings.globalize_path("res://screenshots")
    DirAccess.make_dir_recursive_absolute(dir)
    var path = dir.path_join("arena_%08d.png" % sim_world.sim_steps)
    var image = get_viewport().get_texture().get_image()
    var err = image.save_png(path)
    ui.set_thought("Screenshot: %s" % path if err == OK else "Screenshot failed")
    AppLog.info("Screenshot result=%s path=%s" % [str(err), path])

func _reset_world() -> void:
    if is_instance_valid(sim_world):
        sim_world.queue_free()
    sim_world = SimWorldScript.new()
    sim_world.name = "VolumetricLifeWorld"
    add_child(sim_world)
    sim_world.initialize(_rng.randi())
    ui.set_thought(L10n.text("ui.world_reset", "A new evolutionary world has been generated."))

func _apply_window_mode() -> void:
    var fullscreen = bool(SettingsStore.get_value("fullscreen", true))
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func _apply_light_mode(mode: String) -> void:
    if not is_instance_valid(sun):
        return
    SettingsStore.set_value("light_mode", mode)
    match mode:
        "top_left": sun.rotation_degrees = Vector3(-48, -42, 0)
        "top_right": sun.rotation_degrees = Vector3(-48, 42, 0)
        "bottom_left": sun.rotation_degrees = Vector3(42, -42, 0)
        "bottom_right": sun.rotation_degrees = Vector3(42, 42, 0)
        "left_middle": sun.rotation_degrees = Vector3(0, -68, 0)
        "right_middle": sun.rotation_degrees = Vector3(0, 68, 0)
        "center": sun.rotation_degrees = Vector3(-82, 0, 0)
        "back": sun.rotation_degrees = Vector3(-18, 180, 0)
        _:
            pass

func _update_sun(delta: float) -> void:
    if not is_instance_valid(sun):
        return
    if str(SettingsStore.get_value("light_mode", "auto_sun")) == "auto_sun":
        auto_sun_time += delta * 0.055
        sun.rotation = Vector3(-0.65 + sin(auto_sun_time * 0.47) * 0.38, auto_sun_time, 0.0)
