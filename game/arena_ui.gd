extends CanvasLayer

signal setting_changed(key: String, value)
signal action_requested(action: String)
signal panels_changed(open: bool)

var hud: Label
var thought: Label
var selection: Label
var hint: Label
var crosshair: Label
var settings_panel: PanelContainer
var help_panel: PanelContainer
var settings_box: VBoxContainer
var help_text: RichTextLabel
var settings_open = false
var help_open = false
var profile_dialog: FileDialog
var _profile_saving: bool = false
var _setting_rows: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_hud()
    _build_settings()
    _build_help()
    _build_profile_dialog()
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

    _add_option("language", L10n.available_languages(), str(SettingsStore.get_value("language", "en")))
    _add_option("speech_language", ["follow", "en", "de", "fr"], str(SettingsStore.get_value("speech_language", "follow")))
    _add_option("tts_voice", ["default"], str(SettingsStore.get_value("tts_voice", "default")))
    _add_toggle("mcp_enabled", bool(SettingsStore.get_value("mcp_enabled", false)))
    _add_toggle("vklp_enabled", bool(SettingsStore.get_value("vklp_enabled", false)))
    _add_toggle("vklp_write_enabled", bool(SettingsStore.get_value("vklp_write_enabled", false)))
    _add_text("vklp_url", str(SettingsStore.get_value("vklp_url", "http://127.0.0.1:8000")))
    _add_option("renderer", ["forward_plus", "mobile", "compatibility"], str(SettingsStore.get_value("renderer", "forward_plus")))
    _add_toggle("auto_reseed", bool(SettingsStore.get_value("auto_reseed", false)))
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
    _add_slider("mutation_strength", 0.02, 0.45, 0.01, float(SettingsStore.get_value("mutation_strength", 0.14)))
    _add_slider("macro_mutation_rate", 0.00, 0.60, 0.01, float(SettingsStore.get_value("macro_mutation_rate", 0.14)))
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

    _add_action_button("save_settings")
    _add_action_button("load_settings")
    _add_action_button("test_speech")
    _add_action_button("rebuild_visuals")
    _add_action_button("inject")
    _add_action_button("export_selected")
    _add_action_button("export_genome")
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
    return "%d" % int(round(value)) if step >= 1.0 else "%.2f" % value

func toggle_settings(force = null) -> void:
    settings_open = not settings_open if force == null else bool(force)
    settings_panel.visible = settings_open
    if settings_open:
        help_open = false
        help_panel.visible = false
    if settings_open: sync_settings()
    panels_changed.emit(settings_open or help_open)

func toggle_help(force = null) -> void:
    help_open = not help_open if force == null else bool(force)
    help_panel.visible = help_open
    if help_open:
        settings_open = false
        settings_panel.visible = false
    panels_changed.emit(settings_open or help_open)

func set_hud(text: String) -> void:
    hud.text = text

func set_thought(text: String) -> void:
    thought.text = text

func set_selection(text: String) -> void:
    selection.text = text

func refresh_language() -> void:
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
            close.text = L10n.text("actions.close_help", "Close help")
        if help_text:
            help_text.text = L10n.text("help.content", "Help text unavailable.")

func _layout_hud() -> void:
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    var width: float = maxf(260.0, viewport_size.x - 36.0)
    hud.size = Vector2(width, 82)
    hint.position = Vector2(18, maxf(0.0, viewport_size.y - 68.0))
    hint.size = Vector2(width, 54)
    thought.position = Vector2(18, 102)
    thought.size = Vector2(width, 60)
    selection.position = Vector2(18, 172)
    selection.size = Vector2(minf(width, 1150), minf(340.0, maxf(180.0, viewport_size.y - 290.0)))
    for item in [hud, thought, selection, hint, crosshair]:
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
