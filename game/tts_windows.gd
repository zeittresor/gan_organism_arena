extends RefCounted

var last_pid = -1

func speak(text: String) -> bool:
    if OS.get_name() != "Windows" or text.strip_edges() == "":
        return false
    if last_pid > 0 and OS.is_process_running(last_pid):
        return false
    var safe = text.replace("'", "''").replace("\n", " ")
    var script = "$v=New-Object -ComObject SAPI.SpVoice; $v.Rate=0; $v.Volume=85; [void]$v.Speak('%s')" % safe
    last_pid = OS.create_process("powershell.exe", ["-NoProfile", "-WindowStyle", "Hidden", "-Command", script], false)
    return last_pid > 0

func shutdown() -> void:
    if last_pid > 0 and OS.is_process_running(last_pid):
        OS.kill(last_pid)
    last_pid = -1
