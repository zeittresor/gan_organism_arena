extends CanvasLayer

signal setting_changed(key: String, value)
signal action_requested(action: String)
signal panels_changed(open: bool)
signal quit_requested(action: String)
signal world_file_selected(path: String, saving: bool)
var world_dialog: FileDialog
var file_result: AcceptDialog
var _world_saving: bool = false

var hud: Label
var thought: Label
var selection: Label
var hint: Label
var crosshair: Label
var pause_badge: Label
var settings_panel: PanelContainer
var help_panel: PanelContainer
var exit_panel: PanelContainer
var exit_body: Label
var settings_box: VBoxContainer
var help_text: RichTextLabel
var settings_open = false
var help_open = false
var exit_open = false
var exit_return_to_settings: bool = false
var exit_return_to_help: bool = false
var help_return_to_settings: bool = false
var _manual_paused: bool = false
var _menu_paused: bool = false
var profile_dialog: FileDialog
var evolution_dialog: AcceptDialog
var evolution_text: RichTextLabel
var hud_hidden: bool = false
var _profile_saving: bool = false
var _setting_rows: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_hud()
    _build_settings()
    _build_help()
    _build_exit_dialog()
    _build_profile_dialog()
    _build_world_dialog()
    _build_evolution_dialog()
    get_viewport().size_changed.connect(_layout_hud)
    _layout_hud()

func _build_hud() -> void:
    hud = Label.new()
    hud.position = Vector2(18, 14)
    hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_theme_font_size_override("font_size", 17)
    add_child(hud)
    thought = Label.new()
    thought.position = Vector2(18, 44)
    thought.size = Vector2(1180, 70)
    thought.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    thought.add_theme_font_size_override("font_size", 16)
    add_child(thought)
    selection = Label.new()
    selection.position = Vector2(18, 104)
    selection.size = Vector2(1150, 300)
    selection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    selection.add_theme_font_size_override("font_size", 15)
    add_child(selection)
    hint = Label.new()
    hint.set_anchors_preset(Control.PRESET_TOP_LEFT)
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.position = Vector2(18, -38)
    hint.add_theme_font_size_override("font_size", 15)
    add_child(hint)
    crosshair = Label.new()
    crosshair.text = "+"
    crosshair.set_anchors_preset(Control.PRESET_CENTER)
    crosshair.position = Vector2(-5, -12)
    crosshair.add_theme_font_size_override("font_size", 22)
    add_child(crosshair)
    pause_badge = Label.new()
    pause_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pause_badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    pause_badge.add_theme_font_size_override("font_size", 24)
    pause_badge.add_theme_color_override("font_color", Color(1.0, 0.89, 0.38))
    pause_badge.visible = false
    add_child(pause_badge)
    refresh_language()

func _build_settings() -> void:
    settings_panel = PanelContainer.new()
    settings_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    settings_panel.size = Vector2(850, 680)
    settings_panel.position -= settings_panel.size * 0.5
    settings_panel.visible = false
    add_child(settings_panel)
    var outer = VBoxContainer.new()
    settings_panel.add_child(outer)
    var title = Label.new()
    title.name = "Title"
    title.add_theme_font_size_override("font_size", 26)
    outer.add_child(title)
    var scroll = ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(820, 555)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    outer.add_child(scroll)
    settings_box = VBoxContainer.new()
    settings_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(settings_box)

    _add_action_button("show_help")

    _add_option("language", L10n.available_languages(), str(SettingsStore.get_value("language", "en")))
    _add_option("speech_language", ["follow", "en", "de", "fr"], str(SettingsStore.get_value("speech_language", "follow")))
    _add_option("tts_voice", ["default"], str(SettingsStore.get_value("tts_voice", "default")))
    _add_toggle("mcp_enabled", bool(SettingsStore.get_value("mcp_enabled", false)))
    _add_toggle("vklp_enabled", bool(SettingsStore.get_value("vklp_enabled", false)))
    _add_toggle("vklp_write_enabled", bool(SettingsStore.get_value("vklp_write_enabled", false)))
    _add_text("vklp_url", str(SettingsStore.get_value("vklp_url", "http://127.0.0.1:8000")))
    _add_option("renderer", ["forward_plus", "mobile", "compatibility"], str(SettingsStore.get_value("renderer", "forward_plus")))
    _add_toggle("textures_enabled", bool(SettingsStore.get_value("textures_enabled", false)))
    _add_action_button("reload_textures")
    _add_action_button("export_texture")
    _add_toggle("auto_reseed", bool(SettingsStore.get_value("auto_reseed", true)))
    _add_slider("minimum_population", 1, 80, 1, float(SettingsStore.get_value("minimum_population", 5)))
    _add_slider("plant_evolution_bias", 0.0, 1.0, 0.05, float(SettingsStore.get_value("plant_evolution_bias", 0.35)))
    _add_toggle("auto_reproduce", bool(SettingsStore.get_value("auto_reproduce", true)))
    _add_toggle("fullscreen", bool(SettingsStore.get_value("fullscreen", true)))
    _add_option("view_mode", ["natural", "cell", "neural", "energy"], str(SettingsStore.get_value("view_mode", "natural")))
    _add_option("light_mode", ["auto_sun", "random", "top_left", "top_right", "bottom_left", "bottom_right", "left_middle", "right_middle", "center", "back"], str(SettingsStore.get_value("light_mode", "auto_sun")))
    _add_slider("simulation_speed", 0.25, 3.0, 0.05, float(SettingsStore.get_value("simulation_speed", 1.0)))
    _add_slider("simulation_tick_hz", 3.0, 30.0, 1.0, float(SettingsStore.get_value("simulation_tick_hz", 12.0)))
    _add_slider("evolution_rate", 0.1, 4.0, 0.1, float(SettingsStore.get_value("evolution_rate", 1.0)))
    _add_slider("habitat_level", 5, 9, 1, float(SettingsStore.get_value("habitat_level", 7)))
    _add_slider("world_step", 0.25, 4.0, 0.25, float(SettingsStore.get_value("world_step", 1.0)))
    _add_slider("organism_cap", 8, 80, 1, float(SettingsStore.get_value("organism_cap", 28)))
    _add_slider("nutrient_count", 32, 700, 8, float(SettingsStore.get_value("nutrient_count", 180)))
    _add_slider("visual_cell_cap", 64, 420, 8, float(SettingsStore.get_value("visual_cell_cap", 180)))
    _add_slider("contact_quality", 0, 100, 5, float(SettingsStore.get_value("contact_quality", 85)))
    _add_slider("gravity_scale", 0.2, 2.5, 0.05, float(SettingsStore.get_value("gravity_scale", 1.0)))
    _add_slider("body_rebuild_interval", 0.25, 6.0, 0.25, float(SettingsStore.get_value("body_rebuild_interval", 1.0)))
    _add_slider("mutation_strength", 0.00, 0.50, 0.01, float(SettingsStore.get_value("mutation_strength", 0.14)))
    _add_slider("macro_mutation_rate", 0.00, 0.60, 0.001, float(SettingsStore.get_value("macro_mutation_rate", 0.014)))
    _add_slider("crossover_rate", 0.00, 1.00, 0.01, float(SettingsStore.get_value("crossover_rate", 0.82)))
    _add_slider("viability_threshold", 0.00, 0.75, 0.01, float(SettingsStore.get_value("viability_threshold", 0.18)))
    _add_slider("mate_cooldown", 2.0, 90.0, 1.0, float(SettingsStore.get_value("mate_cooldown", 24.0)))
    _add_slider("mating_radius", 3.0, 40.0, 0.5, float(SettingsStore.get_value("mating_radius", 12.0)))
    _add_slider("social_spacing", 1.5, 12.0, 0.25, float(SettingsStore.get_value("social_spacing", 4.5)))
    _add_slider("courtship_strength", 0.0, 2.0, 0.05, float(SettingsStore.get_value("courtship_strength", 0.75)))
    _add_slider("group_strength", 0.0, 2.0, 0.05, float(SettingsStore.get_value("group_strength", 0.55)))
    _add_slider("predation_strength", 0.0, 2.0, 0.05, float(SettingsStore.get_value("predation_strength", 0.45)))
    _add_slider("hierarchy_strength", 0.0, 2.0, 0.05, float(SettingsStore.get_value("hierarchy_strength", 0.35)))
    _add_slider("follow_distance", 2.0, 20.0, 0.5, float(SettingsStore.get_value("follow_distance", 6.0)))
    _add_slider("follow_height", 0.0, 8.0, 0.25, float(SettingsStore.get_value("follow_height", 1.6)))
    _add_toggle("camera_noclip", bool(SettingsStore.get_value("camera_noclip", false)))
    _add_toggle("observer_presence", bool(SettingsStore.get_value("observer_presence", false)))
    _add_toggle("show_hud", bool(SettingsStore.get_value("show_hud", true)))
    _add_toggle("show_crosshair", bool(SettingsStore.get_value("show_crosshair", true)))
    _add_slider("camera_fov", 28.0, 105.0, 1.0, float(SettingsStore.get_value("camera_fov", 78.0)))
    _add_slider("zoom_step", 1.0, 12.0, 0.5, float(SettingsStore.get_value("zoom_step", 4.0)))
    _add_toggle("audio_enabled", bool(SettingsStore.get_value("audio_enabled", true)))
    _add_toggle("ambient_audio", bool(SettingsStore.get_value("ambient_audio", true)))
    _add_toggle("organism_audio", bool(SettingsStore.get_value("organism_audio", true)))
    _add_slider("audio_volume", 0.0, 1.0, 0.05, float(SettingsStore.get_value("audio_volume", 0.45)))
    _add_slider("organism_sound_interval", 1.0, 20.0, 0.5, float(SettingsStore.get_value("organism_sound_interval", 4.5)))
    _add_option("thought_mode", ["off", "text", "tts", "both"], str(SettingsStore.get_value("thought_mode", "text")))
    _add_slider("thought_interval", 2.0, 25.0, 0.5, float(SettingsStore.get_value("thought_interval", 7.0)))
    _add_slider("max_history_events", 4, 96, 4, float(SettingsStore.get_value("max_history_events", 32)))

    _add_action_button("save_world")
    _add_action_button("load_world")
    _add_action_button("save_settings")
    _add_action_button("load_settings")
    _add_action_button("test_speech")
    _add_action_button("rebuild_visuals")
    _add_action_button("inject")
    _add_action_button("export_selected")
    _add_action_button("export_genome")
    _add_action_button("evolution_overview")
    _add_action_button("export_evolution")
    _add_action_button("reset_world")
    _add_action_button("close_settings")
    refresh_language()

func _build_help() -> void:
    help_panel = PanelContainer.new()
    help_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    help_panel.size = Vector2(980, 680)
    help_panel.position -= help_panel.size * 0.5
    help_panel.visible = false
    add_child(help_panel)
    var box = VBoxContainer.new()
    help_panel.add_child(box)
    var title = Label.new()
    title.name = "Title"
    title.add_theme_font_size_override("font_size", 26)
    box.add_child(title)
    help_text = RichTextLabel.new()
    help_text.bbcode_enabled = true
    help_text.fit_content = false
    help_text.scroll_active = true
    help_text.custom_minimum_size = Vector2(940, 555)
    box.add_child(help_text)
    var close = Button.new()
    close.name = "Close"
    close.pressed.connect(func(): toggle_help(false))
    box.add_child(close)
    refresh_language()

func _build_exit_dialog() -> void:
    exit_panel = PanelContainer.new()
    exit_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    exit_panel.size = Vector2(620, 360)
    exit_panel.position -= exit_panel.size * 0.5
    exit_panel.visible = false
    exit_panel.z_index = 20
    add_child(exit_panel)
    var box = VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    exit_panel.add_child(box)
    var title = Label.new()
    title.name = "Title"
    title.add_theme_font_size_override("font_size", 26)
    box.add_child(title)
    exit_body = Label.new()
    exit_body.name = "Body"
    exit_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    exit_body.custom_minimum_size = Vector2(570, 70)
    box.add_child(exit_body)
    _add_exit_button(box, "exit_open_settings")
    _add_exit_button(box, "exit_save_quit")
    _add_exit_button(box, "exit_quit")
    _add_exit_button(box, "exit_cancel")
    refresh_language()

func _add_exit_button(parent: VBoxContainer, action: String) -> void:
    var button = Button.new()
    button.name = action
    button.custom_minimum_size = Vector2(0, 42)
    button.pressed.connect(func():
        if action == "exit_cancel":
            close_exit_dialog(true)
        elif action == "exit_open_settings":
            close_exit_dialog(false)
            toggle_settings(true)
        else:
            quit_requested.emit("save_quit" if action == "exit_save_quit" else "quit")
    )
    parent.add_child(button)

func _add_option(key: String, values: Array, current: String) -> void:
    var row = _make_row(key)
    var opt = OptionButton.new()
    opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for v in values:
        opt.add_item(str(v))
        opt.set_item_metadata(opt.item_count - 1, str(v))
        if str(v) == current:
            opt.select(opt.item_count - 1)
    opt.item_selected.connect(func(index: int): setting_changed.emit(key, opt.get_item_metadata(index)))
    row.add_child(opt)
    _setting_rows[key] = {"label": row.get_child(0), "control": opt}

func _add_toggle(key: String, current: bool) -> void:
    var row = _make_row(key)
    var check = CheckButton.new()
    check.button_pressed = current
    check.toggled.connect(func(value: bool): setting_changed.emit(key, value))
    row.add_child(check)
    _setting_rows[key] = {"label": row.get_child(0), "control": check}

func _add_slider(key: String, min_value: float, max_value: float, step: float, current: float) -> void:
    var row = _make_row(key)
    var slider = HSlider.new()
    slider.min_value = min_value
    slider.max_value = max_value
    slider.step = step
    slider.value = current
    slider.custom_minimum_size = Vector2(320, 30)
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var value_label = Label.new()
    value_label.custom_minimum_size = Vector2(78, 30)
    value_label.text = _format_value(current, step)
    slider.value_changed.connect(func(value: float):
        value_label.text = _format_value(value, step)
        setting_changed.emit(key, int(value) if step >= 1.0 else value)
    )
    row.add_child(slider)
    row.add_child(value_label)
    _setting_rows[key] = {"label": row.get_child(0), "control": slider, "value": value_label}

func _make_row(key: String) -> HBoxContainer:
    var row = HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var label = Label.new()
    label.custom_minimum_size = Vector2(300, 34)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.name = "Label"
    row.add_child(label)
    settings_box.add_child(row)
    return row

func _add_action_button(action: String) -> void:
    var button = Button.new()
    button.name = "action_" + action
    button.pressed.connect(func(): action_requested.emit(action))
    settings_box.add_child(button)

func _format_value(value: float, step: float) -> String:
    if step < 0.01: return "%.3f" % value
    return "%d" % int(round(value)) if step >= 1.0 else "%.2f" % value

func _build_evolution_dialog() -> void:
    evolution_dialog = AcceptDialog.new()
    evolution_dialog.exclusive = true
    evolution_dialog.size = Vector2i(780, 590)
    add_child(evolution_dialog)
    evolution_text = RichTextLabel.new()
    evolution_text.bbcode_enabled = false
    evolution_text.scroll_active = true
    evolution_text.custom_minimum_size = Vector2(620, 420)
    evolution_text.add_theme_font_size_override("normal_font_size", 17)
    evolution_dialog.add_child(evolution_text)

func show_evolution_report(report: Dictionary) -> void:
    var totals: Dictionary = report["totals"]
    var population: Dictionary = report["population"]
    var lines: Array[String] = []
    lines.append(L10n.text("evolution.run") % [report["seed"], report["time"]])
    lines.append(L10n.text("evolution.population") % [population["living"], population["reserved_embryos"], population["rooted"]])
    lines.append(L10n.text("evolution.generations") % [population["highest_generation"], totals["highest_generation"]])
    lines.append("")
    lines.append(L10n.text("evolution.births") % [totals["births"], totals["sexual_births"], totals["clonal_births"]])
    lines.append(L10n.text("evolution.mutated") % [totals["mutated_births"], totals["macro_births"]])
    lines.append(L10n.text("evolution.founders") % [totals["initial_founders"], totals["rescue_founders"], totals["manual_founders"]])
    lines.append(L10n.text("evolution.deaths") % totals["deaths"])
    lines.append(L10n.text("evolution.floor") % population["target"] if population["floor_enabled"] else L10n.text("evolution.floor_off"))
    if population["deficit"] > 0:
        lines.append(L10n.text("evolution.capacity_wait") % population["deficit"])
    lines.append("")
    lines.append(L10n.text("evolution.discoveries") % totals["new_topologies"])
    for discovery in report["discoveries"]:
        lines.append("  " + L10n.text("evolution.discovery") % [L10n.text("body_plans." + discovery["plan"]), discovery["id"], discovery["generation"], discovery["time"]])
    lines.append(L10n.text("evolution.discovery_note"))
    lines.append("")
    lines.append(L10n.text("evolution.recent"))
    var records: Array = report["records"]
    for i in range(records.size() - 1, maxi(-1, records.size() - 13), -1):
        var entry: Dictionary = records[i]
        lines.append(L10n.text("evolution.record") % [entry["id"], entry["generation"], L10n.text("body_plans." + entry["plan"]), L10n.text("evolution.origin_" + entry["origin"]), entry["parents"][0], entry["parents"][1], L10n.text("evolution.alive" if entry["alive"] else "evolution.dead")])
    lines.append("")
    lines.append(L10n.text("evolution.retention") % [records.size(), totals["dropped_records"]])
    evolution_text.text = "\n".join(lines)
    evolution_text.scroll_to_line(0)
    evolution_dialog.title = L10n.text("actions.evolution_overview")
    evolution_dialog.get_ok_button().text = L10n.text("evolution.close")
    evolution_dialog.popup_centered_clamped(Vector2i(780, 590), 0.9)

func toggle_settings(force = null) -> void:
    if exit_open:
        exit_open = false
        exit_panel.visible = false
        exit_return_to_settings = false
        exit_return_to_help = false
    settings_open = not settings_open if force == null else bool(force)
    settings_panel.visible = settings_open
    if settings_open:
        help_return_to_settings = false
        help_open = false
        help_panel.visible = false
    if settings_open: sync_settings()
    panels_changed.emit(settings_open or help_open or exit_open)

func toggle_help(force = null) -> void:
    if exit_open:
        exit_open = false
        exit_panel.visible = false
        exit_return_to_settings = false
        exit_return_to_help = false
    var opening: bool = not help_open if force == null else bool(force)
    if opening and not help_open: help_return_to_settings = settings_open
    help_open = opening
    help_panel.visible = help_open
    if help_open:
        settings_open = false
        settings_panel.visible = false
        help_text.scroll_to_line(0)
    elif help_return_to_settings:
        settings_open = true
        settings_panel.visible = true
        help_return_to_settings = false
    refresh_language()
    panels_changed.emit(settings_open or help_open or exit_open)

func show_exit_dialog() -> void:
    if exit_open:
        return
    exit_return_to_settings = settings_open
    exit_return_to_help = help_open
    settings_open = false
    help_open = false
    settings_panel.visible = false
    help_panel.visible = false
    exit_open = true
    exit_panel.visible = true
    refresh_language()
    var cancel = exit_panel.find_child("exit_cancel", true, false) as Button
    if cancel: cancel.grab_focus()
    panels_changed.emit(true)

func close_exit_dialog(restore_previous: bool = false) -> void:
    exit_open = false
    exit_panel.visible = false
    if restore_previous and exit_return_to_help:
        help_open = true
        help_panel.visible = true
    elif restore_previous and exit_return_to_settings:
        settings_open = true
        settings_panel.visible = true
        sync_settings()
    exit_return_to_settings = false
    exit_return_to_help = false
    refresh_language()
    panels_changed.emit(settings_open or help_open or exit_open)

func set_pause_status(manual: bool, menu: bool) -> void:
    _manual_paused = manual
    _menu_paused = menu
    if not is_instance_valid(pause_badge): return
    pause_badge.visible = manual or menu
    var key: String = "pause_both" if manual and menu else ("pause_manual" if manual else "pause_menu")
    pause_badge.text = L10n.text("ui." + key)

func _complete_help() -> String:
    var text: String = L10n.text("help.content")
    text += "\n\n[b]" + L10n.text("help.escape_title", "Escape / exit prompt") + "[/b]\n" + L10n.text("help.escape", "Escape opens the exit prompt with settings, world snapshot and quit choices.")
    text += "\n\n[b]" + L10n.text("help.settings_reference") + "[/b]\n\n"
    for key in _setting_rows:
        text += "[b]" + L10n.text("settings." + key) + "[/b]\n" + L10n.text("tooltips." + key) + "\n\n"
    text += "[b]" + L10n.text("help.actions_reference") + "[/b]\n\n"
    for child in settings_box.get_children():
        if child is Button and child.name.begins_with("action_"):
            var action: String = child.name.trim_prefix("action_")
            text += "[b]" + L10n.text("actions." + action) + "[/b]\n" + L10n.text("tooltips." + action) + "\n\n"
    return text

func set_hud(text: String) -> void:
    hud.text = text

func toggle_hud() -> void:
    hud_hidden = not hud_hidden
    _sync_hud_visibility()

func _sync_hud_visibility() -> void:
    var show_text: bool = not hud_hidden and bool(SettingsStore.get_value("show_hud", true))
    for label in [hud, thought, selection]:
        if is_instance_valid(label): label.visible = show_text
    if is_instance_valid(crosshair):
        crosshair.visible = not hud_hidden and bool(SettingsStore.get_value("show_crosshair", true))
    if is_instance_valid(hint): hint.visible = show_text and bool(SettingsStore.get_value("show_help_hint", true))

func refresh_visibility() -> void:
    _sync_hud_visibility()

func set_thought(text: String) -> void:
    thought.text = text

func set_selection(text: String) -> void:
    selection.text = text

func refresh_language() -> void:
    set_pause_status(_manual_paused, _menu_paused)
    if hud:
        hint.text = L10n.text("ui.hint", "F10 Settings | F1 Help | WASD + mouse swim | LMB select | RMB follow")
    if settings_panel:
        var title = settings_panel.find_child("Title", true, false) as Label
        if title:
            title.text = L10n.text("ui.settings_title", "Settings")
        for key in _setting_rows:
            var row: Dictionary = _setting_rows[key]
            var label = row.get("label") as Label
            if label:
                label.text = L10n.text("settings.%s" % key, key.replace("_", " ").capitalize())
                var help: String = L10n.text("tooltips." + key)
                label.tooltip_text = help
                label.mouse_filter = Control.MOUSE_FILTER_PASS
                row["control"].tooltip_text = help
                if row.has("value"): row["value"].tooltip_text = help
                if row["control"] is OptionButton:
                    var option: OptionButton = row["control"]
                    for i in range(option.item_count):
                        var value: String = str(option.get_item_metadata(i))
                        if key != "tts_voice" or value == "default":
                            option.set_item_text(i, L10n.text("option_values." + value, value))
                        option.get_popup().set_item_tooltip(i, help)
        for child in settings_box.get_children():
            if child is Button and child.name.begins_with("action_"):
                var action = child.name.trim_prefix("action_")
                child.text = L10n.text("actions.%s" % action, action.replace("_", " ").capitalize())
                child.tooltip_text = L10n.text("tooltips." + action)
    if help_panel:
        var title_h = help_panel.find_child("Title", true, false) as Label
        if title_h:
            title_h.text = L10n.text("ui.help_title", "Help / Project Guide")
        var close = help_panel.find_child("Close", true, false) as Button
        if close:
            close.text = L10n.text("actions.back_settings" if help_return_to_settings else "actions.close_help")
        if help_text:
            help_text.text = _complete_help()
    if exit_panel:
        var exit_title = exit_panel.find_child("Title", true, false) as Label
        if exit_title:
            exit_title.text = L10n.text("ui.exit_title", "Exit GAN Organism Arena?")
        if exit_body:
            exit_body.text = L10n.text("ui.exit_body", "Choose what should happen next. The simulation is paused while this dialog is open.")
        for action in ["exit_open_settings", "exit_save_quit", "exit_quit", "exit_cancel"]:
            var button = exit_panel.find_child(action, true, false) as Button
            if button:
                button.text = L10n.text("actions." + action, action.replace("_", " ").capitalize())
                button.tooltip_text = L10n.text("tooltips." + action, button.text)
    _sync_hud_visibility()

func _layout_hud() -> void:
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    var width: float = maxf(260.0, viewport_size.x - 36.0)
    hud.size = Vector2(width, 82)
    hint.position = Vector2(18, maxf(0.0, viewport_size.y - 68.0))
    hint.size = Vector2(width, 54)
    pause_badge.position = Vector2(18, maxf(0.0, viewport_size.y - 122.0))
    pause_badge.size = Vector2(width, 52)
    thought.position = Vector2(18, 102)
    thought.size = Vector2(width, 60)
    selection.position = Vector2(18, 172)
    selection.size = Vector2(minf(width, 1150), minf(340.0, maxf(180.0, viewport_size.y - 290.0)))
    for item in [hud, thought, selection, hint, crosshair, pause_badge]:
        item.mouse_filter = Control.MOUSE_FILTER_IGNORE

func select_option_value(key: String, value: String) -> void:
    if not _setting_rows.has(key): return
    var control = _setting_rows[key]["control"]
    if control is OptionButton:
        for i in range(control.item_count):
            if control.get_item_text(i) == value:
                control.select(i)
                return

func _add_text(key: String, current: String) -> void:
    var row = _make_row(key)
    var edit = LineEdit.new()
    edit.text = current
    edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    edit.focus_exited.connect(func(): setting_changed.emit(key, edit.text.strip_edges()))
    edit.text_submitted.connect(func(value: String): setting_changed.emit(key, value.strip_edges()))
    row.add_child(edit)
    _setting_rows[key] = {"label": row.get_child(0), "control": edit}

func sync_settings() -> void:
    for key in _setting_rows:
        var control = _setting_rows[key]["control"]
        var value = SettingsStore.get_value(key)
        if control is CheckButton: control.set_pressed_no_signal(bool(value))
        elif control is HSlider:
            control.set_value_no_signal(float(value))
            _setting_rows[key]["value"].text = _format_value(float(value), control.step)
        elif control is OptionButton:
            for i in range(control.item_count):
                if str(control.get_item_metadata(i)) == str(value): control.select(i)
        elif control is LineEdit: control.text = str(value)
    refresh_language()
    refresh_voices()

func refresh_voices() -> void:
    if not _setting_rows.has("tts_voice"): return
    var option: OptionButton = _setting_rows["tts_voice"]["control"]
    option.clear()
    option.add_item(L10n.text("option_values.default", "Automatic voice"))
    option.set_item_metadata(0, "default")
    var language: String = str(SettingsStore.get_value("speech_language", "follow"))
    if language == "follow": language = L10n.language
    var selected_voice: String = str(SettingsStore.get_value("tts_voice", "default"))
    for voice in DisplayServer.tts_get_voices():
        if not str(voice.get("language", "")).to_lower().replace("_", "-").begins_with(language): continue
        option.add_item(str(voice["name"]))
        option.set_item_metadata(option.item_count - 1, str(voice["id"]))
        # Voice names are system-owned labels, not localization keys.
        if str(voice["id"]) == selected_voice: option.select(option.item_count - 1)
    if option.item_count == 1:
        option.tooltip_text = L10n.text("ui.tts_missing")

func _build_profile_dialog() -> void:
    profile_dialog = FileDialog.new()
    profile_dialog.access = FileDialog.ACCESS_FILESYSTEM
    profile_dialog.filters = PackedStringArray(["*.json ; Arena settings"])
    profile_dialog.file_selected.connect(_profile_selected)
    add_child(profile_dialog)

func show_profile_dialog(saving: bool) -> void:
    _profile_saving = saving
    profile_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if saving else FileDialog.FILE_MODE_OPEN_FILE
    var folder: String = ProjectSettings.globalize_path("res://settings/profiles")
    DirAccess.make_dir_recursive_absolute(folder)
    profile_dialog.current_dir = folder
    profile_dialog.current_file = "arena-settings.json" if saving else ""
    profile_dialog.title = L10n.text("actions.save_settings" if saving else "actions.load_settings")
    profile_dialog.popup_centered_ratio(0.75)

func _profile_selected(path: String) -> void:
    if _profile_saving:
        var result: Error = SettingsStore.export_profile(path)
        set_thought(L10n.text("ui.profile_saved" if result == OK else "ui.profile_write_error"))
        return
    var result: Dictionary = SettingsStore.read_profile(path)
    if result.has("error"):
        set_thought(L10n.text("ui." + str(result["error"])))
        return
    var values: Dictionary = result["settings"]
    # Validate the entire profile before applying anything. Set final values first
    # so dependent options (permissions, voices) see one consistent configuration.
    var changed: Array = []
    for key in values:
        if SettingsStore.get_value(key) != values[key]: changed.append(key)
        SettingsStore.data[key] = values[key]
    SettingsStore.save_settings()
    for key in changed: setting_changed.emit(key, values[key])
    sync_settings()
    set_thought(L10n.text("ui.profile_loaded"))

func _build_world_dialog() -> void:
    world_dialog = FileDialog.new()
    world_dialog.access = FileDialog.ACCESS_FILESYSTEM
    world_dialog.filters = PackedStringArray(["*.arena ; Arena world checkpoint"])
    world_dialog.file_selected.connect(func(path: String): world_file_selected.emit(path, _world_saving))
    add_child(world_dialog)
    file_result = AcceptDialog.new()
    add_child(file_result)

func show_world_dialog(saving: bool) -> void:
    _world_saving = saving
    world_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if saving else FileDialog.FILE_MODE_OPEN_FILE
    var folder: String = ProjectSettings.globalize_path("res://exports/world_saves")
    DirAccess.make_dir_recursive_absolute(folder)
    world_dialog.current_dir = folder
    world_dialog.current_file = "world_%d.arena" % int(Time.get_unix_time_from_system()) if saving else ""
    world_dialog.title = L10n.text("actions.save_world" if saving else "actions.load_world")
    world_dialog.popup_centered_ratio(0.75)

func show_file_result(success: bool, message: String) -> void:
    file_result.dialog_text = L10n.text(message if success else "ui.world_file_failed")
    file_result.popup_centered(Vector2i(520, 140))
