extends RefCounted

var last_error: String = ""

static func select_voice(voices: Array, language: String, preferred: String) -> String:
    var fallback: String = ""
    for voice in voices:
        var code: String = str(voice.get("language", "")).to_lower().replace("_", "-")
        if code != language and not code.begins_with(language + "-"): continue
        var id: String = str(voice.get("id", ""))
        if fallback == "": fallback = id
        if id == preferred: return id
    return fallback

func speak(text: String, language: String = "en", preferred: String = "default") -> bool:
    last_error = ""
    if text.strip_edges() == "": return false
    var voices: Array = DisplayServer.tts_get_voices()
    var voice: String = select_voice(voices, language, preferred)
    if voice == "":
        last_error = "tts_missing"
        return false
    if DisplayServer.tts_is_speaking(): return false
    DisplayServer.tts_speak(text, voice, 85, 1.0, 1.0)
    return true

func stop() -> void:
    DisplayServer.tts_stop()
