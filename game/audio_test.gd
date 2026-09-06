extends Node

const AudioEcosystem = preload("res://game/audio_ecosystem.gd")
var checks: int = 0
var failed: int = 0

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failed += 1
        printerr("SELFTEST ERROR: audio: ", label)

func run_all() -> bool:
    var tiny: float = AudioEcosystem.acoustic_base_frequency(0.08, 0.35, 1.0, 2, 4)
    var giant: float = AudioEcosystem.acoustic_base_frequency(0.98, 14.0, 2.0, 2, 4)
    var unarmored: float = AudioEcosystem.acoustic_base_frequency(0.65, 5.0, 1.0, 3, 4)
    var armored: float = AudioEcosystem.acoustic_base_frequency(0.65, 5.0, 1.8, 3, 4)
    check(tiny > giant, "small expressed bodies call at a higher pitch than giants")
    check(unarmored > armored, "structural loading lowers the resonant pitch")
    check(tiny >= 35.0 and tiny <= 1800.0 and giant >= 35.0 and giant <= 1800.0, "allometric pitch stays in the audible safety range")
    print("AUDIO SELFTEST: %d checks; %d failures" % [checks, failed])
    return failed == 0
