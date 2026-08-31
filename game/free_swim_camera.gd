extends Node3D

var camera: Camera3D
var yaw = 0.0
var pitch = 0.0
var move_speed = 14.0
var mouse_sensitivity = 0.0023
var enabled = true
var follow_target = null

func _ready() -> void:
    camera = Camera3D.new()
    camera.current = true
    camera.fov = 78.0
    camera.near = 0.04
    camera.far = 400.0
    add_child(camera)
    move_speed = float(SettingsStore.get_value("move_speed", 14.0))
    mouse_sensitivity = float(SettingsStore.get_value("mouse_sensitivity", 0.0023))
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if not enabled:
        return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        yaw -= event.relative.x * mouse_sensitivity
        pitch -= event.relative.y * mouse_sensitivity
        pitch = clampf(pitch, deg_to_rad(-88.0), deg_to_rad(88.0))
        rotation = Vector3(pitch, yaw, 0.0)
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            move_speed = minf(70.0, move_speed * 1.14)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            move_speed = maxf(1.5, move_speed / 1.14)

func _process(delta: float) -> void:
    if not enabled:
        return
    if is_instance_valid(follow_target):
        var target_pos: Vector3 = follow_target.global_position
        var desired: Vector3 = target_pos - global_transform.basis.z * 8.0 + Vector3.UP * 2.2
        global_position = global_position.lerp(desired, clampf(delta * 1.8, 0.0, 1.0))
        look_at(target_pos, Vector3.UP)
        return
    var input = Vector3.ZERO
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): input.z -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): input.z += 1.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): input.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input.x += 1.0
    if Input.is_key_pressed(KEY_E): input.y += 1.0
    if Input.is_key_pressed(KEY_Q): input.y -= 1.0
    if input.length_squared() > 1.0:
        input = input.normalized()
    var boost = 3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
    var world_move = global_transform.basis * input
    global_position += world_move * move_speed * boost * delta

func release_mouse() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func capture_mouse() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_follow(target) -> void:
    follow_target = null if follow_target == target else target
