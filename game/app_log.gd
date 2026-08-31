extends Node

var _latest: FileAccess
var _session: FileAccess
var session_path = ""

func _ready() -> void:
    var log_dir = ProjectSettings.globalize_path("res://logs")
    DirAccess.make_dir_recursive_absolute(log_dir)
    var stamp = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
    session_path = log_dir.path_join("runtime_%s.log" % stamp)
    _latest = FileAccess.open(log_dir.path_join("latest_runtime.log"), FileAccess.WRITE)
    _session = FileAccess.open(session_path, FileAccess.WRITE)
    info("Runtime log initialised: %s" % session_path)

func _write(level: String, message: String) -> void:
    var ts = Time.get_datetime_string_from_system()
    var line = "%s [%s] %s" % [ts, level, message]
    print(line)
    if _latest:
        _latest.store_line(line)
        _latest.flush()
    if _session:
        _session.store_line(line)
        _session.flush()

func info(message: String) -> void:
    _write("INFO", message)

func warn(message: String) -> void:
    _write("WARN", message)

func error(message: String) -> void:
    _write("ERROR", message)
