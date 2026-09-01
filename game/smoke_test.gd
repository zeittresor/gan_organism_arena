extends Node

const MainScene = preload("res://scenes/Main.tscn")
var app = null
var frames: int = 0
var cleanup_started: bool = false

func _ready() -> void:
    call_deferred("_start")

func _start() -> void:
    app = MainScene.instantiate()
    add_child(app)
    print("SMOKE TEST: main scene instantiated")

func _process(_delta: float) -> void:
    frames += 1
    if frames == 75 and is_instance_valid(app):
        cleanup_started = true
        app.queue_free()
        print("SMOKE TEST: main scene queued for clean shutdown")
    elif cleanup_started and frames >= 90:
        print("SMOKE TEST OK: clean project-context startup/shutdown")
        get_tree().quit(0)
    elif frames > 240:
        printerr("SMOKE TEST ERROR: timed out")
        get_tree().quit(31)
