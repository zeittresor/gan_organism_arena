extends Node3D

const FollowSolver = preload("res://game/follow_camera_solver.gd")

var camera: Camera3D
var yaw = 0.0
var pitch = 0.0
var move_speed = 14.0
var mouse_sensitivity = 0.0023
var enabled = true
var follow_target = null
var follow_velocity = Vector3.ZERO
var follow_snap_pending: bool = false
var habitat_model = null
var noclip_enabled: bool = false
const OBSERVER_CLEARANCE: float = 1.15
const WORLD_MARGIN: float = 0.75

func _ready() -> void:
    camera = Camera3D.new()
    camera.current = true
    camera.fov = clampf(float(SettingsStore.get_value("camera_fov", 78.0)), 28.0, 105.0)
    camera.near = 0.04
    camera.far = 800.0
    add_child(camera)
    move_speed = float(SettingsStore.get_value("move_speed", 14.0))
    mouse_sensitivity = float(SettingsStore.get_value("mouse_sensitivity", 0.0023))
    noclip_enabled = bool(SettingsStore.get_value("camera_noclip", false))
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if not enabled:
        return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not is_instance_valid(follow_target):
        # look_at() also changes the rotation while following/spawning.
        # Begin every free look from that actual orientation, never stale angles.
        yaw = rotation.y - event.relative.x * mouse_sensitivity
        pitch = rotation.x - event.relative.y * mouse_sensitivity
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
    global_position = _constrain_free_position(global_position)

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
    var look_target: Vector3 = focus + forward * minf(2.2, size_hint * 0.18)
    var model = follow_target.habitat if follow_target.habitat != null else habitat_model
    var clearance: float = FollowSolver.clearance_for_body(size_hint)
    if not noclip_enabled:
        desired = FollowSolver.safe_position(model, look_target, desired, clearance)

    # Critically damped-ish smoothing avoids a camera that oscillates with every
    # small body steering correction. A newly followed body snaps straight to
    # its safe viewpoint so interpolation cannot travel through a mountain.
    if follow_snap_pending:
        global_position = _constrain_free_position(desired) if noclip_enabled else desired
        follow_snap_pending = false
    else:
        var stiffness: float = clampf(delta * 3.1, 0.0, 1.0)
        var smoothed: Vector3 = global_position.lerp(desired, stiffness)
        global_position = FollowSolver.safe_position(model, look_target, smoothed, clearance) if not noclip_enabled else _constrain_free_position(smoothed)
    if global_position.distance_squared_to(look_target) > 0.01:
        look_at(look_target, Vector3.UP)

func release_mouse() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func capture_mouse() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_follow(target) -> void:
    follow_target = null if follow_target == target else target
    follow_snap_pending = is_instance_valid(follow_target)

func set_habitat(model) -> void:
    habitat_model = model
    if not noclip_enabled:
        global_position = _constrain_free_position(global_position)

func set_noclip(enabled_value: bool) -> void:
    noclip_enabled = enabled_value
    SettingsStore.set_value("camera_noclip", noclip_enabled)
    if not noclip_enabled:
        global_position = _constrain_free_position(global_position)

func place_safe_observer_start(model) -> void:
    habitat_model = model
    if model == null or not model.has_method("nearest_medium"):
        global_position = Vector3(0.0, 6.0, 24.0)
        rotation = Vector3.ZERO
        return
    # Prefer a dry, open shore point for the observer. The model returns the
    # exact terrain height, so this never starts below a ridge as the old fixed
    # (0,4,34) position could. If a habitat has no land, use safe water instead.
    var focus: Vector3 = model.nearest_medium(Vector3.ZERO, false, OBSERVER_CLEARANCE)
    if model.is_water(focus):
        focus = model.nearest_medium(Vector3(0.0, model.waterline - 3.0, 0.0), true, OBSERVER_CLEARANCE)
    var desired: Vector3 = focus + Vector3(0.0, 5.0, 11.0)
    global_position = FollowSolver.safe_position(model, focus, desired, OBSERVER_CLEARANCE)
    look_at(focus + Vector3.UP * 0.8, Vector3.UP)

func _constrain_free_position(value: Vector3) -> Vector3:
    if habitat_model == null:
        return value
    var safe: Vector3 = value
    var extent_value = habitat_model.get("half_extent")
    if extent_value != null:
        var extent: float = float(extent_value) - WORLD_MARGIN
        safe.x = clampf(safe.x, -extent, extent)
        safe.z = clampf(safe.z, -extent, extent)
    # Clamp horizontal coordinates before sampling the floor at the final point.
    if not noclip_enabled and habitat_model.has_method("floor_at"):
        safe.y = maxf(safe.y, float(habitat_model.floor_at(safe)) + OBSERVER_CLEARANCE)
    var bottom_value = habitat_model.get("bottom_y")
    if bottom_value != null:
        safe.y = maxf(safe.y, float(bottom_value) + WORLD_MARGIN)
    var ceiling_value = habitat_model.get("ceiling_y")
    if ceiling_value != null:
        safe.y = minf(safe.y, float(ceiling_value) - WORLD_MARGIN)
    return safe

func set_zoom_fov(value: float, persist: bool = false) -> void:
    if not is_instance_valid(camera):
        return
    camera.fov = clampf(value, 28.0, 105.0)
    if persist:
        SettingsStore.set_value("camera_fov", camera.fov)

func reset_zoom() -> void:
    set_zoom_fov(float(SettingsStore.defaults.get("camera_fov", 78.0)), true)
