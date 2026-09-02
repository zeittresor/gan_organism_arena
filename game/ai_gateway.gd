extends Node

const Experiment = preload("res://game/experiment_api.gd")
var api = Experiment.new()
var server = TCPServer.new()
var token: String = ""
var clients: Array = []
var step_owner: String = ""

func start(world, port: int, secret: String) -> Error:
    if secret.length() < 32 or port < 1024 or port > 65535: return ERR_INVALID_PARAMETER
    api.configure(world)
    token = secret
    var result: Error = server.listen(port, "127.0.0.1")
    set_process(result == OK)
    return result

func _process(_delta: float) -> void:
    if server.is_connection_available():
        var peer = server.take_connection()
        if clients.size() >= 8: peer.disconnect_from_host()
        else: clients.append({"peer": peer, "input": PackedByteArray(), "output": PackedByteArray(), "offset": 0, "started": Time.get_ticks_msec(), "answered": false})
    for i in range(clients.size() - 1, -1, -1):
        var client: Dictionary = clients[i]
        var peer = client["peer"]
        peer.poll()
        if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED or Time.get_ticks_msec() - client["started"] > 30000:
            peer.disconnect_from_host()
            clients.remove_at(i)
            continue
        if client["answered"]:
            var output: PackedByteArray = client["output"]
            var offset: int = client["offset"]
            var sent: Array = peer.put_partial_data(output.slice(offset, mini(output.size(), offset + 65536)))
            if sent[0] != OK:
                peer.disconnect_from_host()
                clients.remove_at(i)
                continue
            client["offset"] += int(sent[1])
            if client["offset"] >= output.size():
                peer.disconnect_from_host()
                clients.remove_at(i)
            continue
        var count: int = mini(peer.get_available_bytes(), 16384)
        if count == 0: continue
        var received: Array = peer.get_data(count)
        if received[0] != OK:
            peer.disconnect_from_host()
            clients.remove_at(i)
            continue
        client["input"].append_array(received[1])
        var bytes: PackedByteArray = client["input"]
        if bytes.size() > 65536:
            _answer(client, {"id": null, "error": "request exceeds 64 KiB"})
            continue
        var newline: int = bytes.find(10)
        if newline < 0: continue
        var request = JSON.parse_string(bytes.slice(0, newline).get_string_from_utf8())
        if not request is Dictionary:
            _answer(client, {"id": null, "error": "invalid JSON object"})
            continue
        if request.get("token", "") != token:
            _answer(client, {"id": request.get("id"), "error": "unauthorized"})
            continue
        var protocol: String = str(request.get("protocol", "mcp"))
        if protocol not in ["mcp", "vklp"] or not bool(SettingsStore.get_value(protocol + "_enabled", false)):
            _answer(client, {"id": request.get("id"), "error": "Interface disabled in F10 settings: " + protocol})
            continue
        var arguments = request.get("arguments", {})
        if not arguments is Dictionary or not request.get("action", "") is String:
            _answer(client, {"id": request.get("id"), "error": "invalid arguments"})
            continue
        client["protocol"] = protocol
        var result: Dictionary = api.execute(request.get("action", ""), arguments)
        if request.get("action", "") == "mode" and not result.has("error"):
            step_owner = protocol if arguments.get("mode", "") == "stepped" else ""
        _answer(client, {"id": request.get("id"), "result": result})

func _answer(client: Dictionary, result: Dictionary) -> void:
    client["output"] = (JSON.stringify(result) + "\n").to_utf8_buffer()
    client["answered"] = true

func shutdown() -> void:
    set_process(false)
    for client in clients: client["peer"].disconnect_from_host()
    clients.clear()
    server.stop()

func _exit_tree() -> void:
    shutdown()

func refresh_permissions() -> void:
    if step_owner != "" and not bool(SettingsStore.get_value(step_owner + "_enabled", false)):
        api.world.experiment_mode = false
        api.world.sim_accumulator = 0.0
        api.world.record_event("mode", {"mode": "live", "source": "interface_disabled", "protocol": step_owner})
        step_owner = ""
    for i in range(clients.size() - 1, -1, -1):
        var protocol: String = str(clients[i].get("protocol", ""))
        if protocol != "" and not bool(SettingsStore.get_value(protocol + "_enabled", false)):
            clients[i]["peer"].disconnect_from_host()
            clients.remove_at(i)
