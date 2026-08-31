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
var _setting_rows: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_hud()
    _build_settings()
    _build_help()

func _build_hud() -> void:
    hud = Label.new()
    hud.position = Vector2(18, 14)
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
    selection.size = Vector2(650, 92)
    selection.add_theme_font_size_override("font_size", 15)
    add_child(selection)
    hint = Label.new()
    hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
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
    _add_option("renderer", ["forward_plus", "mobile", "compatibility"], str(SettingsStore.get_value("renderer", "forward_plus")))
    _add_toggle("fullscreen", bool(SettingsStore.get_value("fullscreen", true)))
    _add_option("view_mode", ["natural", "cell", "neural", "energy"], str(SettingsStore.get_value("view_mode", "natural")))
    _add_option("light_mode", ["auto_sun", "top_left", "top_right", "bottom_left", "bottom_right", "left_middle", "right_middle", "center", "back"], str(SettingsStore.get_value("light_mode", "auto_sun")))
    _add_slider("simulation_speed", 0.25, 3.0, 0.05, float(SettingsStore.get_value("simulation_speed", 1.0)))
    _add_slider("simulation_tick_hz", 3.0, 30.0, 1.0, float(SettingsStore.get_value("simulation_tick_hz", 12.0)))
    _add_slider("evolution_rate", 0.1, 4.0, 0.1, float(SettingsStore.get_value("evolution_rate", 1.0)))
    _add_slider("organism_cap", 8, 80, 1, float(SettingsStore.get_value("organism_cap", 28)))
    _add_slider("nutrient_count", 32, 700, 8, float(SettingsStore.get_value("nutrient_count", 180)))
    _add_slider("visual_cell_cap", 64, 420, 8, float(SettingsStore.get_value("visual_cell_cap", 180)))
    _add_slider("body_rebuild_interval", 0.25, 6.0, 0.25, float(SettingsStore.get_value("body_rebuild_interval", 1.0)))
    _add_option("thought_mode", ["off", "text", "tts", "both"], str(SettingsStore.get_value("thought_mode", "text")))
    _add_slider("thought_interval", 2.0, 25.0, 0.5, float(SettingsStore.get_value("thought_interval", 7.0)))
    _add_slider("max_history_events", 4, 96, 4, float(SettingsStore.get_value("max_history_events", 32)))

    _add_action_button("rebuild_visuals")
    _add_action_button("inject")
    _add_action_button("export_selected")
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
        if str(v) == current:
            opt.select(opt.item_count - 1)
    opt.item_selected.connect(func(index: int): setting_changed.emit(key, opt.get_item_text(index)))
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
        for child in settings_box.get_children():
            if child is Button and child.name.begins_with("action_"):
                var action = child.name.trim_prefix("action_")
                child.text = L10n.text("actions.%s" % action, action.replace("_", " ").capitalize())
    if help_panel:
        var title_h = help_panel.find_child("Title", true, false) as Label
        if title_h:
            title_h.text = L10n.text("ui.help_title", "Help / Project Guide")
        var close = help_panel.find_child("Close", true, false) as Button
        if close:
            close.text = L10n.text("actions.close_help", "Close help")
        if help_text:
            help_text.text = L10n.text("help.content", "Help text unavailable.")
