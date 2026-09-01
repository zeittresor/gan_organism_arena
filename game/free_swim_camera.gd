extends Node3D

var camera: Camera3D
var yaw = 0.0
var pitch = 0.0
var move_speed = 14.0
var mouse_sensitivity = 0.0023
var enabled = true
var follow_target = null
var follow_velocity = Vector3.ZERO

func _ready() -> void:
    camera = Camera3D.new()
    camera.current = true
    camera.fov = clampf(float(SettingsStore.get_value("camera_fov", 78.0)), 28.0, 105.0)
    camera.near = 0.04
    camera.far = 400.0
    add_child(camera)
    move_speed = float(SettingsStore.get_value("move_speed", 14.0))
    mouse_sensitivity = float(SettingsStore.get_value("mouse_sensitivity", 0.0023))
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if not enabled:
        return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not is_instance_valid(follow_target):
        yaw -= event.relative.x * mouse_sensitivity
        pitch -= event.relative.y * mouse_sensitivity
        pitch = clampf(pitch, deg_to_rad(-88.0), deg_to_rad(88.0))
        rotation = Vector3(pitch, yaw, 0.0)
    elif event is InputEventMouseButton and event.pressed:
        # Mouse wheel is primarily optical zoom. Hold Shift while scrolling to
        # retain the older observer-speed adjustment without sacrificing zoom.
        if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
            if Input.is_key_pressed(KEY_SHIFT):
                if event.button_index == MOUSE_BUTTON_WHEEL_UP:
                    move_speed = minf(70.0, move_speed * 1.14)
                else:
                    move_speed = maxf(1.5, move_speed / 1.14)
            else:
                var direction: float = -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
                var factor: float = maxf(0.25, float(event.factor))
                var step: float = float(SettingsStore.get_value("zoom_step", 4.0))
                set_zoom_fov(camera.fov + direction * step * factor, true)

func _process(delta: float) -> void:
    if not enabled:
        return
    if is_instance_valid(follow_target):
        _follow_process(delta)
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

func _follow_process(delta: float) -> void:
    var rear: Vector3 = follow_target.global_position
    var focus: Vector3 = follow_target.global_position
    var size_hint: float = 2.0
    var forward: Vector3 = (-follow_target.global_transform.basis.z).normalized()
    if follow_target.has_method("follow_camera_data"):
        var data: Dictionary = follow_target.follow_camera_data()
        rear = data.get("rear", rear)
        focus = data.get("focus", focus)
        size_hint = float(data.get("size", size_hint))
        forward = data.get("forward", forward)

    # Follow from the organism's anatomical rear, not its centre. Because Godot's
    # Node3D forward direction is -Z after look_at(), +Z is the trailing direction.
    var follow_distance: float = float(SettingsStore.get_value("follow_distance", 6.0)) + minf(8.0, size_hint * 0.42)
    var follow_height: float = float(SettingsStore.get_value("follow_height", 1.6)) + minf(3.0, size_hint * 0.10)
    var trailing_direction: Vector3 = -forward
    var desired: Vector3 = rear + trailing_direction * follow_distance + Vector3.UP * follow_height

    # Critically damped-ish smoothing avoids a camera that oscillates with every
    # small body steering correction.
    var stiffness: float = clampf(delta * 3.1, 0.0, 1.0)
    global_position = global_position.lerp(desired, stiffness)
    var look_target: Vector3 = focus + forward * minf(2.2, size_hint * 0.18)
    if global_position.distance_squared_to(look_target) > 0.01:
        look_at(look_target, Vector3.UP)

func release_mouse() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func capture_mouse() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_follow(target) -> void:
    follow_target = null if follow_target == target else target

func set_zoom_fov(value: float, persist: bool = false) -> void:
    if not is_instance_valid(camera):
        return
    camera.fov = clampf(value, 28.0, 105.0)
    if persist:
        SettingsStore.set_value("camera_fov", camera.fov)

func reset_zoom() -> void:
    set_zoom_fov(float(SettingsStore.defaults.get("camera_fov", 78.0)), true)
