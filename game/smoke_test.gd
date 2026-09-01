extends Node

const MainScene = preload("res://scenes/Main.tscn")

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var arena = MainScene.instantiate()
    add_child(arena)
    for _frame in range(90):
        await get_tree().process_frame

    if is_instance_valid(arena) and arena.has_method("prepare_shutdown"):
        arena.prepare_shutdown()
    if is_instance_valid(arena):
        remove_child(arena)
        arena.free()

    # Let queued frees and audio-driver references settle before ending the engine.
    for _frame in range(6):
        await get_tree().process_frame

    print("SMOKETEST OK: Main scene initialized, simulated, shut down and freed cleanly.")
    get_tree().quit(0)
