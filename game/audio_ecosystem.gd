extends Node

var ambient_player: AudioStreamPlayer
var voice_players: Array[AudioStreamPlayer3D] = []
var rng = RandomNumberGenerator.new()
var enabled: bool = true
var habitat_level: int = 5

func _ready() -> void:
    rng.randomize()
    ambient_player = AudioStreamPlayer.new()
    add_child(ambient_player)
    _refresh_ambient()

func apply_settings() -> void:
    enabled = bool(SettingsStore.get_value("audio_enabled", true))
    var volume: float = float(SettingsStore.get_value("audio_volume", 0.45))
    ambient_player.volume_db = linear_to_db(maxf(0.001, volume * 0.55))
    if enabled and bool(SettingsStore.get_value("ambient_audio", true)):
        if not ambient_player.playing:
            _refresh_ambient()
            ambient_player.play()
    else:
        ambient_player.stop()

func set_habitat_level(level: int) -> void:
    habitat_level = clampi(level, 5, 9)
    _refresh_ambient()

func _refresh_ambient() -> void:
    ambient_player.stream = _make_ambient_stream()
    call_deferred("apply_settings_deferred")

func apply_settings_deferred() -> void:
    enabled = bool(SettingsStore.get_value("audio_enabled", true))
    if enabled and bool(SettingsStore.get_value("ambient_audio", true)) and not ambient_player.playing:
        ambient_player.play()

func play_organism_call(org) -> void:
    if not enabled or not bool(SettingsStore.get_value("organism_audio", true)) or not is_instance_valid(org):
        return
    var player = AudioStreamPlayer3D.new()
    player.position = org.global_position
    player.max_distance = 48.0
    player.unit_size = 4.0
    player.volume_db = linear_to_db(maxf(0.001, float(SettingsStore.get_value("audio_volume", 0.45))))
    player.stream = _make_call_stream(org)
    add_child(player)
    voice_players.append(player)
    player.finished.connect(func():
        voice_players.erase(player)
        if is_instance_valid(player):
            player.queue_free()
    )
    player.play()

func shutdown() -> void:
    enabled = false
    if is_instance_valid(ambient_player):
        ambient_player.stop()
        ambient_player.stream = null
    for player in voice_players.duplicate():
        if is_instance_valid(player):
            player.stop()
            player.stream = null
    voice_players.clear()

func _exit_tree() -> void:
    shutdown()

func _make_ambient_stream() -> AudioStreamWAV:
    var rate: int = 11025
    var seconds: float = 5.0
    var samples: int = int(rate * seconds)
    var bytes = PackedByteArray()
    bytes.resize(samples * 2)
    var phase: float = 0.0
    var low: float = 0.0
    for i in range(samples):
        low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.015)
        var base_hz: float = lerpf(46.0, 118.0, float(habitat_level - 5) / 4.0)
        phase += TAU * base_hz / float(rate)
        var wind: float = sin(phase * 0.17) * 0.012 * float(maxi(0, habitat_level - 7))
        var value: float = low * (0.10 + float(habitat_level - 5) * 0.012) + sin(phase) * 0.018 + sin(phase * 0.47) * 0.012 + wind
        bytes.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
    var wav = AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = rate
    wav.stereo = false
    wav.data = bytes
    wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
    wav.loop_begin = 0
    wav.loop_end = samples
    return wav

func _make_call_stream(org) -> AudioStreamWAV:
    var rate: int = 16000
    var stage: int = int(org.language_stage)
    var duration: float = clampf(0.18 + float(stage) * 0.055, 0.18, 0.85)
    var samples: int = int(rate * duration)
    var bytes = PackedByteArray()
    bytes.resize(samples * 2)
    var family: int = int(org.genome.family_id)
    var base_freq: float = 120.0 + float((family * 47) % 260) + float(stage) * 18.0
    var syllables: int = clampi(1 + int(stage / 2), 1, 5)
    for i in range(samples):
        var t: float = float(i) / float(rate)
        var slot: int = mini(syllables - 1, int(t / duration * float(syllables)))
        var freq: float = base_freq * (1.0 + float((slot * 3 + family) % 5) * 0.08)
        var envelope: float = sin(PI * fposmod(t * float(syllables) / duration, 1.0))
        envelope = pow(maxf(0.0, envelope), 0.7)
        var harmonic: float = sin(TAU * freq * t)
        harmonic += sin(TAU * freq * 1.51 * t) * (0.16 + minf(0.22, stage * 0.025))
        if stage >= 4:
            harmonic += sin(TAU * freq * 2.02 * t) * 0.10
        var value: float = harmonic * envelope * 0.16
        bytes.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
    var wav = AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = rate
    wav.stereo = false
    wav.data = bytes
    return wav
