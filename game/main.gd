extends Node3D

const SimWorldScript = preload("res://game/sim_world.gd")
const CameraScript = preload("res://game/free_swim_camera.gd")
const UIScript = preload("res://game/arena_ui.gd")
const CellCycle = preload("res://game/cell_cycle.gd")
const TTSScript = preload("res://game/tts_windows.gd")
const OBJExporterScript = preload("res://game/obj_exporter.gd")
const HabitatVisualScript = preload("res://game/habitat_visual.gd")
const AudioEcosystemScript = preload("res://game/audio_ecosystem.gd")

const Cycle = preload("res://game/life_cycle.gd")

const APP_NAME = "GAN Organism Arena"
const VERSION = "1.0.0-alpha22"
const RELEASE_DATE = "2026-09-04"

var ai_gateway = null
var sim_world = null
var swim_camera = null
var ui = null
var sun: DirectionalLight3D
var environment: WorldEnvironment
var tts = TTSScript.new()
var thought_timer = 0.0
var last_speaker = null
var api_session_path: String = ""
var speaker_index = 0
var audio_speaker_index = 0
var organism_audio_timer: float = 0.0
var hud_timer = 0.0
var perf_timer = 0.0
var auto_sun_time = 0.0
var manual_pause = false
var panel_pause = false
var _rng = RandomNumberGenerator.new()
var habitat_visual = null
var audio_ecosystem = null
var base_world_size: float = 144.0
var manual_world_delta: float = 0.0

func _ready() -> void:
    _rng.randomize()
    AppLog.info("Starting %s v%s (%s)" % [APP_NAME, VERSION, RELEASE_DATE])
    AppLog.info("Godot: %s | OS: %s | renderer setting: %s" % [Engine.get_version_info().get("string", "unknown"), OS.get_name(), str(SettingsStore.get_value("renderer", "forward_plus"))])
    _apply_window_mode()
    _build_environment()
    base_world_size = float(SettingsStore.get_value("world_size", 144.0))
    _create_habitat()
    _build_dust()
    _create_world()
    _create_camera()
    _create_ui()
    _create_audio()
    _apply_light_mode(str(SettingsStore.get_value("light_mode", "auto_sun")))
    _start_optional_ai()

func _create_habitat() -> void:
    habitat_visual = HabitatVisualScript.new()
    habitat_visual.name = "EvolvingHabitat"
    add_child(habitat_visual)
    _apply_habitat_level(int(SettingsStore.get_value("habitat_level", 7)), false)

func _create_audio() -> void:
    audio_ecosystem = AudioEcosystemScript.new()
    audio_ecosystem.name = "EcosystemAudio"
    add_child(audio_ecosystem)
    audio_ecosystem.apply_settings()
    audio_ecosystem.set_habitat_level(int(SettingsStore.get_value("habitat_level", 7)))

func _current_world_size() -> float:
    var level: int = int(SettingsStore.get_value("habitat_level", 7))
    var natural_growth: float = float(level - 5) * float(SettingsStore.get_value("world_step", 1.0))
    return maxf(20.0, base_world_size + natural_growth + manual_world_delta)

func _apply_habitat_level(level: int, announce: bool = true) -> void:
    level = clampi(level, 5, 9)
    SettingsStore.set_value("habitat_level", level)
    var size: float = _current_world_size()
    if is_instance_valid(habitat_visual):
        habitat_visual.configure(level, size)
    if is_instance_valid(sim_world):
        sim_world.set_habitat(level, size, habitat_visual.waterline, habitat_visual.ground_y, habitat_visual.model, habitat_visual.resource_positions)
        if not sim_world.experiment_settings.is_empty():
            sim_world.experiment_settings["habitat_level"] = level
            sim_world.experiment_settings["world_size"] = size
        sim_world.record_event("user_habitat", {"level": level, "size": size})
    if is_instance_valid(audio_ecosystem):
        audio_ecosystem.set_habitat_level(level)
    if is_instance_valid(environment) and environment.environment != null:
        var env = environment.environment
        var air_mix: float = clampf(float(level - 5) / 4.0, 0.0, 1.0)
        env.background_color = Color(0.006, 0.018, 0.032).lerp(Color(0.10, 0.24, 0.38), air_mix * 0.75)
        env.fog_density = lerpf(0.0065, 0.0015, air_mix)
        env.ambient_light_energy = lerpf(0.72, 1.05, air_mix)
    if announce and is_instance_valid(ui):
        ui.set_thought("Habitat %d: %s | world %.1f³" % [level, _habitat_name(level), size])
    AppLog.info("habitat level=%d name=%s world_size=%.1f" % [level, _habitat_name(level), size])

func _habitat_name(level: int) -> String:
    return L10n.text("habitats.%d" % level)

func _resize_world(direction: float) -> void:
    manual_world_delta += direction * float(SettingsStore.get_value("world_step", 1.0))
    manual_world_delta = clampf(manual_world_delta, -base_world_size * 0.55, base_world_size * 3.0)
    _apply_habitat_level(int(SettingsStore.get_value("habitat_level", 7)))

func _create_world() -> void:
    sim_world = SimWorldScript.new()
    sim_world.name = "VolumetricLifeWorld"
    add_child(sim_world)
    sim_world.initialize(int(Time.get_unix_time_from_system()) & 0x7fffffff)
    if is_instance_valid(habitat_visual):
        sim_world.set_habitat(int(SettingsStore.get_value("habitat_level", 7)), _current_world_size(), habitat_visual.waterline, habitat_visual.ground_y, habitat_visual.model, habitat_visual.resource_positions)

func _create_camera() -> void:
    swim_camera = CameraScript.new()
    swim_camera.name = "Observer"
    add_child(swim_camera)
    swim_camera.global_position = Vector3(0.0, 4.0, 34.0)
    swim_camera.rotation = Vector3(0.0, 0.0, 0.0)
    sim_world.observer_camera = swim_camera.camera

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
    var half = float(SettingsStore.get_value("world_size", 144.0)) * 0.5
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
    var half = float(SettingsStore.get_value("world_size", 144.0)) * 0.5
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
    organism_audio_timer += delta
    hud_timer += delta
    perf_timer += delta
    if thought_timer >= float(SettingsStore.get_value("thought_interval", 7.0)):
        thought_timer = 0.0
        _emit_next_thought()
    if organism_audio_timer >= float(SettingsStore.get_value("organism_sound_interval", 4.5)):
        organism_audio_timer = 0.0
        _emit_organism_audio()
    if hud_timer >= 0.20:
        hud_timer = 0.0
        _refresh_hud()
        _refresh_selection_text()
    if perf_timer >= 10.0:
        perf_timer = 0.0
        var m: Dictionary = sim_world.metrics()
        AppLog.info("perf fps=%.1f organisms=%d steps=%d visual_cells=%d forms=%d cross_births=%d mutation_births=%d failed_dev=%d max_complexity=%.2f max_intelligence=%.3f renderer=%s" % [Performance.get_monitor(Performance.TIME_FPS), int(m["organisms"]), int(m["steps"]), int(m["visual_cells"]), int(m["body_plan_count"]), int(m["crossover_births"]), int(m["mutation_births"]), int(m["failed_developments"]), float(m["max_complexity"]), float(m["max_intelligence"]), str(SettingsStore.get_value("renderer", "forward_plus"))])
        var p: Dictionary = sim_world.take_performance()
        AppLog.info("navigation moving=%d motile=%d mean_speed=%.3f feeding_events=%d replans=%d goals=%s" % [p["moving"], p["motile"], p["mean_speed"], p["feeding_events"], p["replans"], str(p["goals"])])
        AppLog.info("perf_detail motion_ms=%.3f biology_ms=%.3f contacts_ms=%.3f peak_world_ms=%.3f frame_ms=%.3f draw_calls=%d primitives=%d ground_detail=%d ground_fast=%d ground_cached=%d envelopes=%d uploads=%d skipped_uploads=%d contact_quality=%d" % [p["motion_ms"], p["biology_ms"], p["contacts_ms"], p["peak_world_ms"], Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), p["ground_detail"], p["ground_fast"], p["ground_cached"], p["envelopes"], p["render_uploads"], p["skipped_uploads"], p["quality"]])

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
                if sim_world.experiment_mode:
                    sim_world.experiment_mode = false
                    manual_pause = true
                    sim_world.record_event("mode", {"mode": "live", "source": "space_key"})
                manual_pause = not manual_pause
                _sync_pause_state()
            KEY_L:
                _randomize_light()
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
            KEY_5:
                _apply_habitat_level(5)
            KEY_6:
                _apply_habitat_level(6)
            KEY_7:
                _apply_habitat_level(7)
            KEY_8:
                _apply_habitat_level(8)
            KEY_9:
                _apply_habitat_level(9)
            KEY_KP_ADD:
                _resize_world(1.0)
            KEY_KP_SUBTRACT:
                _resize_world(-1.0)
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
    last_speaker = org
    var text: String = str(org.generate_thought(_rng, L10n.language))
    var prefix = "#%d %s L%d" % [org.organism_id, org.family_name, org.language_stage]
    if mode in ["text", "both"]:
        ui.set_thought("%s: %s" % [prefix, text])
    else:
        ui.set_thought("")
    if mode in ["tts", "both"]:
        var spoken = tts.speak(org.thought_in_language(_speech_language()), _speech_language(), str(SettingsStore.get_value("tts_voice", "default")))
        if tts.last_error != "": ui.set_thought("%s: %s\n%s" % [prefix, text, L10n.text("ui." + tts.last_error)])
        AppLog.info("TTS thought speaker=%d stage=%d spoken=%s text=%s" % [org.organism_id, org.language_stage, str(spoken), text])

func _emit_organism_audio() -> void:
    if not is_instance_valid(audio_ecosystem) or not bool(SettingsStore.get_value("audio_enabled", true)) or not bool(SettingsStore.get_value("organism_audio", true)):
        return
    var speakers: Array = sim_world.top_speakers(12)
    if speakers.is_empty():
        return
    audio_speaker_index = audio_speaker_index % speakers.size()
    var org = speakers[audio_speaker_index]
    audio_speaker_index += 1
    audio_ecosystem.play_organism_call(org)

func _refresh_hud() -> void:
    var m: Dictionary = sim_world.metrics()
    var paused = manual_pause or panel_pause
    var mode = str(SettingsStore.get_value("view_mode", "natural"))
    ui.set_hud(L10n.text("ui.hud_format") % [APP_NAME, VERSION, Performance.get_monitor(Performance.TIME_FPS), int(m["steps"]), int(m["organisms"]), int(m["body_plan_count"]), int(m["visual_cells"]), int(SettingsStore.get_value("habitat_level", 7)), _habitat_name(int(SettingsStore.get_value("habitat_level", 7))), _current_world_size(), float(m["max_complexity"]), float(m["max_intelligence"]), L10n.text("option_values." + mode, mode), " | " + L10n.text("ui.paused") if paused else ""])
    ui.hud.text += "\n%s %d | %s %d | %s %d" % [L10n.text("life.pending", "Developing embryos"), int(m["embryos"]), L10n.text("life.conceptions", "Fertilized"), int(m["conceptions"]), L10n.text("life.losses", "Embryo losses"), int(m["brood_losses"])]

func _refresh_selection_text() -> void:
    if not is_instance_valid(ui):
        return
    var org = sim_world.selected if is_instance_valid(sim_world) else null
    if not is_instance_valid(org):
        ui.set_selection(L10n.text("ui.no_selection", "No organism selected. Aim at one and left-click, or press Tab."))
        return
    var labels: Array[String] = []
    var coverings: Array[String] = []
    for key in org.ecology_labels():
        var translated: String = L10n.text("ecology." + key, key.replace("_", " "))
        if key in ["skin", "feathers", "scales", "fur", "mucus", "membranes", "horns", "beak"]:
            coverings.append(translated)
        else:
            labels.append(translated)
    if labels.is_empty():
        labels.append(L10n.text("ecology.generalist", "generalist"))
    if coverings.is_empty():
        coverings.append(L10n.text("ecology.plant_tissues", "plant / filter tissues") if org.rooted else L10n.text("ecology.skin", "skin"))
    var behavior: String = L10n.text("behavior." + org.behavior_state, org.behavior_state.replace("_", " "))
    var text: String = "#%d %s | %s | Gen %d | %s %.2f | %s %d" % [org.organism_id, org.family_name, L10n.text("body_plans." + org.body_plan_name(), org.body_plan_name()), org.genome.generation, L10n.text("ecology.energy", "Energy"), org.energy, L10n.text("ecology.offspring", "Offspring"), org.children]
    text += "\n%s: %s" % [L10n.text("ecology.traits", "Traits"), ", ".join(labels)]
    text += "\n%s: %s" % [L10n.text("ecology.covering", "Body covering"), ", ".join(coverings)]
    text += "\n%s | O2 %d%% | %s %d%% | %s %d%%" % [behavior, int(org.oxygen * 100), L10n.text("ecology.stamina", "Stamina"), int(org.stamina * 100), L10n.text("ecology.moisture", "Moisture"), int(org.moisture * 100)]
    text += "\n%s %d%% | %s %d%% | %s %d | %s %d" % [L10n.text("ecology.flight", "Flight"), int(org.flight_skill * 100), L10n.text("ecology.tool_user", "Tools"), int(org.tool_skill * 100), L10n.text("ecology.medium_changes", "Water/land changes"), org.medium_changes, L10n.text("ecology.prey", "Prey"), org.prey_id]
    text += " | %s %.1f °C" % [L10n.text("ecology.temperature", "Environment"), org.ambient_temperature]
    var stage: String = Cycle.stage(org)
    var role: String = Cycle.sex_role(org.genome) if Cycle.development_fraction(org) >= 0.70 else "immature"
    text += "\n%s | %s | %s: %s | %s %.0fs" % [L10n.text("life." + stage, stage), L10n.text("life." + role, role), L10n.text("life.reproduction", "Reproduction"), L10n.text("life." + Cycle.mode(org), Cycle.mode(org)), L10n.text("life.age", "Age"), org.age_seconds]
    text += "\n%s %d%% | %s %d | %s %d%% | %s %d / %d" % [L10n.text("life." + org.reproduction_state, org.reproduction_state), int(org.reproduction_progress * 100), L10n.text("life.embryos", "Carried embryos"), org.carrying_count, L10n.text("life.fertility", "Genetic fertility"), int(org.genome.fertility_factor * 100), L10n.text("life.parents", "Parents"), org.parent_a, org.parent_b]
    text += "\n%s %d%% | %s %.2f / %.2f | %s %d%%" % [L10n.text("biology.growth", "Development"), int(org.development_progress * 100), L10n.text("biology.gametes", "Egg/sperm reserve"), org.egg_reserve, org.sperm_reserve, L10n.text("biology.diversity", "Heterozygosity"), int(org.genome.heterozygosity() * 100)]
    text += "\n%s: %s | %s %d | %s %d | DNA 2n" % [L10n.text("biology.cell_cycle"), L10n.text("biology." + CellCycle.strategy(org.genome)), L10n.text("biology.mitoses"), org.mitotic_divisions, L10n.text("biology.meioses"), org.meiosis_cycles]
    var dna: String = org.genome.DNA.encode(float(org.genome.alleles["hue"][0])) + org.genome.DNA.encode(float(org.genome.alleles["symmetry"][0]))
    text += "\n" + L10n.text("biology.emotion") + ": " + L10n.text("emotions." + org.emotion) + " | " + L10n.text("biology.sense") + ": " + L10n.text("senses.compound" if org.genome.compound_eye_drive > 0.58 else "senses.focused")
    text += "\nDNA: " + dna + "… | " + L10n.text("biology.dna_export")
    var anatomy: Dictionary = org.visual.anatomy_counts
    text += "\n" + L10n.text("biology.anatomy") % [anatomy["cartilage"], anatomy["membrane"], anatomy["hydrostat"], anatomy["active"]]
    var goal_label: String = L10n.text("behavior." + org.navigation_goal, org.navigation_goal.replace("_", " "))
    text += "\n" + L10n.text("ui.navigation_status") % [goal_label, org.global_position.distance_to(org.navigation_target), org.velocity.length(), org.feeding_events, org.navigation_replans]
    ui.set_selection(text)

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
    if is_instance_valid(sim_world):
        if not sim_world.experiment_settings.is_empty(): sim_world.experiment_settings[key] = value
        sim_world.record_event("user_setting", {"key": key, "value": value})
    SettingsStore.set_value(key, value)
    match key:
        "language":
            L10n.set_language(str(value))
            ui.refresh_language()
            ui.refresh_voices()
            tts.stop()
            if is_instance_valid(last_speaker) and str(SettingsStore.get_value("thought_mode", "text")) in ["text", "both"]:
                ui.set_thought("#%d %s: %s" % [last_speaker.organism_id, last_speaker.family_name, last_speaker.thought_in_language(L10n.language)])
            _refresh_hud()
            _refresh_selection_text()
        "speech_language", "tts_voice":
            tts.stop()
            ui.refresh_voices()
        "thought_mode":
            tts.stop()
            if str(value) == "off": ui.set_thought("")
        "mcp_enabled", "vklp_enabled", "vklp_write_enabled":
            _sync_optional_ai()
        "world_size":
            _apply_habitat_level(int(SettingsStore.get_value("habitat_level", 7)))
        "fullscreen":
            _apply_window_mode()
        "view_mode":
            sim_world.set_view_mode(str(value))
        "light_mode":
            _apply_light_mode(str(value))
        "camera_fov":
            if is_instance_valid(swim_camera):
                swim_camera.set_zoom_fov(float(value), false)
        "visual_cell_cap":
            sim_world.set_visual_cap(int(value))
        "contact_quality":
            sim_world.set_contact_quality(int(value))
        "nutrient_count":
            sim_world.set_nutrient_count(int(value))
        "habitat_level":
            _apply_habitat_level(int(value))
        "audio_enabled", "ambient_audio", "organism_audio", "audio_volume":
            if is_instance_valid(audio_ecosystem):
                audio_ecosystem.apply_settings()
        "renderer":
            ui.set_thought(L10n.text("ui.renderer_restart", "Rendering backend saved; restart the application to apply it."))
        _:
            pass

func _on_action_requested(action: String) -> void:
    match action:
        "save_settings":
            ui.show_profile_dialog(true)
        "load_settings":
            ui.show_profile_dialog(false)
        "test_speech":
            tts.stop()
            var samples: Dictionary = {"en": "This is the English voice for the organisms.", "de": "Das ist die deutsche Stimme für die Lebewesen.", "fr": "Voici la voix française des organismes."}
            if not tts.speak(samples[_speech_language()], _speech_language(), str(SettingsStore.get_value("tts_voice", "default"))):
                ui.set_thought(L10n.text("ui.tts_missing"))
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
        "export_genome":
            if not is_instance_valid(sim_world.selected):
                ui.set_thought(L10n.text("ui.select_first"))
            else:
                var org = sim_world.selected
                var folder: String = ProjectSettings.globalize_path("res://exports/dna")
                DirAccess.make_dir_recursive_absolute(folder)
                var path: String = folder.path_join("organism_%05d_step_%d.json" % [org.organism_id, sim_world.sim_steps])
                var file = FileAccess.open(path, FileAccess.WRITE)
                if file:
                    file.store_string(JSON.stringify(org.genome.dna_document(), "  "))
                    file.close()
                    ui.set_thought("DNA: " + path)
                else: ui.set_thought(L10n.text("ui.profile_write_error"))
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
    sim_world.observer_camera = swim_camera.camera
    if is_instance_valid(habitat_visual):
        sim_world.set_habitat(int(SettingsStore.get_value("habitat_level", 7)), _current_world_size(), habitat_visual.waterline, habitat_visual.ground_y, habitat_visual.model, habitat_visual.resource_positions)
    if is_instance_valid(ai_gateway): ai_gateway.api.configure(sim_world)
    sim_world.record_event("user_reset", {"seed": sim_world.run_seed})
    ui.set_thought(L10n.text("ui.world_reset", "A new evolutionary world has been generated."))

func _apply_window_mode() -> void:
    var fullscreen = bool(SettingsStore.get_value("fullscreen", true))
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func _apply_light_mode(mode: String) -> void:
    if not is_instance_valid(sun):
        return
    SettingsStore.set_value("light_mode", mode)
    match mode:
        "random": sun.rotation_degrees = Vector3(float(SettingsStore.get_value("light_pitch", -48.0)), float(SettingsStore.get_value("light_yaw", 42.0)), 0.0)
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

func _exit_tree() -> void:
    if api_session_path != "": DirAccess.remove_absolute(api_session_path)
    if is_instance_valid(audio_ecosystem):
        audio_ecosystem.shutdown()
    if tts != null and tts.has_method("stop"):
        tts.stop()

func _randomize_light() -> void:
    if not is_instance_valid(sun): return
    var yaw: float = fposmod(sun.rotation_degrees.y + _rng.randf_range(40.0, 320.0), 360.0)
    var pitch: float = _rng.randf_range(-75.0, -18.0)
    SettingsStore.set_value("light_pitch", pitch)
    SettingsStore.set_value("light_yaw", yaw)
    _apply_light_mode("random")
    if is_instance_valid(ui):
        ui.select_option_value("light_mode", "random")
        ui.set_thought(L10n.text("ui.random_light", "New light direction") + " | %.0f° / %.0f°" % [pitch, yaw])

func _speech_language() -> String:
    var code: String = str(SettingsStore.get_value("speech_language", "follow"))
    return L10n.language if code == "follow" else code

func _start_optional_ai() -> void:
    _sync_optional_ai()

func _sync_optional_ai() -> void:
    var enabled: bool = bool(SettingsStore.get_value("mcp_enabled", false)) or bool(SettingsStore.get_value("vklp_enabled", false))
    if not enabled:
        if is_instance_valid(ai_gateway):
            ai_gateway.shutdown()
            ai_gateway.queue_free()
            ai_gateway = null
            # An external step controller must not leave normal play suspended.
            sim_world.experiment_mode = false
        if api_session_path != "": DirAccess.remove_absolute(api_session_path)
        return
    if is_instance_valid(ai_gateway):
        ai_gateway.refresh_permissions()
        return
    var port: int = 8766
    var secret: String = ""
    if OS.get_cmdline_user_args().has("--arena-api"):
        var supplied: String = OS.get_environment("ARENA_API_PORT")
        if supplied.is_valid_int(): port = int(supplied)
        secret = OS.get_environment("ARENA_API_TOKEN")
    if secret.length() < 32: secret = Crypto.new().generate_random_bytes(32).hex_encode()
    ai_gateway = preload("res://game/ai_gateway.gd").new()
    add_child(ai_gateway)
    var result: Error = ai_gateway.start(sim_world, port, secret)
    if result != OK:
        ai_gateway.queue_free()
        ai_gateway = null
        ui.set_thought(L10n.text("ui.api_failed") + " (%d)" % result)
        AppLog.info("Optional AI interface could not start, error=%d" % result)
        return
    api_session_path = ProjectSettings.globalize_path("res://runtime/arena-session-%d.json" % port)
    DirAccess.make_dir_recursive_absolute(api_session_path.get_base_dir())
    var f = FileAccess.open(api_session_path, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify({"port": port, "token": secret}))
        f.close()
    ui.set_thought(L10n.text("ui.api_ready") + " (127.0.0.1:%d)" % port)
    AppLog.info("Optional AI interface listening on loopback port %d; normal live controls retained" % port)
