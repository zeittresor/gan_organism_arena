extends Node3D

var water_material: ShaderMaterial
var world_time: float = 0.0
var wireframe_visible: bool = true

func set_world_time(seconds: float) -> void:
    world_time = seconds
    if is_instance_valid(water_material):
        water_material.set_shader_parameter("world_time", world_time)

const HabitatModelScript = preload("res://game/habitat_model.gd")
var model = HabitatModelScript.new()
var resource_positions: Array[Vector3] = []

var habitat_level: int = 5
var world_size: float = 288.0
var waterline: float = 21.0
var ground_y: float = -21.0
var geometry_root: Node3D
var terrain_materials: Array = []
var reef_instance: MultiMeshInstance3D
var reef_transforms: Array[Transform3D] = []
const REEF_CAPACITY: int = 192

func apply_textures() -> void:
    var terrain_texture = TextureAssets.terrain_texture_for(habitat_level) if TextureAssets.enabled else null
    var terrain_maps: Array = []
    for key in ["seabed", "shore", "sand", "grass"]:
        terrain_maps.append(TextureAssets.terrain_texture_named(key) if TextureAssets.enabled else null)
    var textures_ready: bool = TextureAssets.enabled and terrain_texture != null
    for map in terrain_maps:
        textures_ready = textures_ready and map != null
    for material in terrain_materials:
        if material is ShaderMaterial:
            material.set_shader_parameter("use_texture", textures_ready)
            if textures_ready:
                material.set_shader_parameter("terrain_map", terrain_texture)
                material.set_shader_parameter("seabed_map", terrain_maps[0])
                material.set_shader_parameter("shore_map", terrain_maps[1])
                material.set_shader_parameter("sand_map", terrain_maps[2])
                material.set_shader_parameter("grass_map", terrain_maps[3])
        elif material is StandardMaterial3D:
            material.albedo_texture = TextureAssets.terrain_texture_named("rock") if TextureAssets.enabled else null

func _ready() -> void:
    if has_node("/root/SettingsStore"):
        wireframe_visible = bool(SettingsStore.get_value("show_wireframe", true))
    geometry_root = Node3D.new()
    geometry_root.name = "HabitatGeometry"
    add_child(geometry_root)

func set_wireframe_visible(value: bool) -> void:
    wireframe_visible = value
    if not is_instance_valid(geometry_root):
        return
    var bounds := geometry_root.get_node_or_null("WorldWireframe")
    if bounds:
        bounds.visible = wireframe_visible

func configure(level: int, size: float) -> void:
    habitat_level = clampi(level, 5, 9)
    world_size = maxf(20.0, size)
    _rebuild()

func _clear_geometry() -> void:
    if not is_instance_valid(geometry_root):
        return
    for child in geometry_root.get_children():
        child.queue_free()

func _rebuild() -> void:
    _clear_geometry()
    terrain_materials.clear()
    model.configure(habitat_level, world_size)
    var half: float = model.half_extent
    ground_y = model.ground_y
    waterline = model.waterline
    _build_bounds(half)
    _build_terrain()
    _build_resources()
    _build_reef_features()
    _build_water_surface(half)
    _build_shoreline()
    if model.has_sky():
        _build_air_markers(half)
    apply_textures()

func _build_bounds(half: float) -> void:
    var bottom: float = model.bottom_y
    var top: float = model.ceiling_y
    var mesh = ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    mesh.surface_set_color(Color(0.10, 0.48, 0.62, 0.22))
    var corners = [
        Vector3(-half,bottom,-half), Vector3(half,bottom,-half), Vector3(half,bottom,half), Vector3(-half,bottom,half),
        Vector3(-half,top,-half), Vector3(half,top,-half), Vector3(half,top,half), Vector3(-half,top,half)
    ]
    var edges = [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]]
    for e in edges:
        mesh.surface_add_vertex(corners[e[0]])
        mesh.surface_add_vertex(corners[e[1]])
    for i in range(-3, 4):
        var t: float = float(i) / 3.0 * half
        mesh.surface_add_vertex(Vector3(t, ground_y, -half))
        mesh.surface_add_vertex(Vector3(t, ground_y, half))
        mesh.surface_add_vertex(Vector3(-half, ground_y, t))
        mesh.surface_add_vertex(Vector3(half, ground_y, t))
    mesh.surface_end()
    var instance = MeshInstance3D.new()
    instance.name = "WorldWireframe"
    instance.mesh = mesh
    var mat = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.vertex_color_use_as_albedo = true
    instance.material_override = mat
    instance.visible = wireframe_visible
    geometry_root.add_child(instance)

func _build_terrain() -> void:
    var surface = SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for z in range(model.GRID):
        for x in range(model.GRID):
            var a: Vector3 = model.vertex(x, z)
            var b: Vector3 = model.vertex(x + 1, z)
            var c: Vector3 = model.vertex(x, z + 1)
            var d: Vector3 = model.vertex(x + 1, z + 1)
            for p in [a, b, c, b, d, c]:
                var above: bool = p.y > waterline
                var color: Color = Color(0.23, 0.30, 0.12) if above else Color(0.13, 0.22, 0.23)
                if absf(p.y - waterline) < 1.6:
                    color = Color(0.43, 0.39, 0.25)
                var dx: float = (model.floor_at(p + Vector3.RIGHT * 0.1) - model.floor_at(p - Vector3.RIGHT * 0.1)) / 0.2
                var dz: float = (model.floor_at(p + Vector3(0, 0, 0.1)) - model.floor_at(p - Vector3(0, 0, 0.1))) / 0.2
                surface.set_normal(Vector3(-dx, 1.0, -dz).normalized())
                surface.set_color(color)
                surface.set_uv(Vector2(p.x, p.z) * 0.25)
                surface.add_vertex(p)
    var mesh = MeshInstance3D.new()
    mesh.mesh = surface.commit()
    var mat = ShaderMaterial.new()
    mat.shader = preload("res://game/terrain_surface.gdshader")
    mat.set_shader_parameter("use_texture", false)
    mat.set_shader_parameter("waterline", waterline)
    mat.set_shader_parameter("transition_width", maxf(1.5, world_size * 0.012))
    var grass_mix: float = 0.12 if habitat_level <= 6 else (0.82 if habitat_level in [7, 8] else 0.48)
    mat.set_shader_parameter("grass_mix", grass_mix)
    terrain_materials.append(mat)
    mesh.material_override = mat
    geometry_root.add_child(mesh)

func _build_resources() -> void:
    resource_positions.clear()
    var rng = RandomNumberGenerator.new()
    rng.seed = 77117
    for i in range(40):
        var p = Vector3(rng.randf_range(-0.90, 0.90) * model.half_extent, 0.0, rng.randf_range(-0.90, 0.90) * model.half_extent)
        p.y = model.floor_at(p)
        resource_positions.append(p)
        var instance = MeshInstance3D.new()
        var stone = SphereMesh.new()
        stone.radius = 0.8 if i % 3 == 0 else 0.32
        stone.height = stone.radius * 1.6
        stone.radial_segments = 6
        stone.rings = 3
        var mat = StandardMaterial3D.new()
        mat.albedo_color = Color(0.34, 0.32, 0.25) if i % 3 == 0 else Color(0.58, 0.35, 0.14)
        mat.roughness = 0.95
        terrain_materials.append(mat)
        stone.material = mat
        instance.mesh = stone
        instance.position = p + Vector3.UP * stone.radius * 0.4
        geometry_root.add_child(instance)

func _build_reef_features() -> void:
    # Coral and mineral outcrops appear only in habitats with a persistent
    # submerged floor. Their deterministic anchors keep a new world stable,
    # while dead-organism remains are added to the same mesh over time.
    reef_transforms.clear()
    reef_instance = null
    var rng = RandomNumberGenerator.new()
    rng.seed = 99831 + habitat_level * 17
    var mesh = CylinderMesh.new()
    mesh.top_radius = 0.07
    mesh.bottom_radius = 0.22
    mesh.height = 1.0
    mesh.radial_segments = 6
    mesh.rings = 2
    var material = StandardMaterial3D.new()
    material.albedo_color = Color.WHITE
    material.vertex_color_use_as_albedo = true
    material.roughness = 0.90
    mesh.material = material
    terrain_materials.append(material)
    for i in range(56):
        var p = Vector3(rng.randf_range(-0.90, 0.90) * model.half_extent, 0.0, rng.randf_range(-0.90, 0.90) * model.half_extent)
        var floor_y: float = model.floor_at(p)
        if floor_y >= model.waterline - 0.9:
            continue
        var stalk_count: int = rng.randi_range(1, 3)
        for stalk in range(stalk_count):
            var offset = Vector3(rng.randf_range(-0.9, 0.9), 0.0, rng.randf_range(-0.9, 0.9))
            var height: float = rng.randf_range(0.45, 1.8)
            var radius: float = rng.randf_range(0.45, 1.25)
            var base = p + offset
            base.y = model.floor_at(base)
            if base.y + height >= model.waterline: continue
            base.y += height * 0.5
            reef_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(radius, height, radius)), base))
    reef_instance = MultiMeshInstance3D.new()
    reef_instance.name = "CoralAndMineralReefs"
    var multi = MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.mesh = mesh
    multi.instance_count = REEF_CAPACITY
    reef_instance.multimesh = multi
    geometry_root.add_child(reef_instance)
    _upload_reef_transforms([])

func update_remains(remains: Array) -> void:
    if not is_instance_valid(reef_instance) or model == null:
        return
    _upload_reef_transforms(remains)

func _upload_reef_transforms(remains: Array) -> void:
    if not is_instance_valid(reef_instance) or reef_instance.multimesh == null:
        return
    var transforms: Array[Transform3D] = reef_transforms.duplicate()
    var colors: Array[Color] = []
    for i in range(transforms.size()): colors.append(Color(0.78, 0.34, 0.38))
    for i in range(remains.size()):
        if transforms.size() >= REEF_CAPACITY:
            break
        var item: Dictionary = remains[i]
        var values: Array = item.get("position", [])
        if values.size() < 3:
            continue
        var p = Vector3(float(values[0]), float(values[1]), float(values[2]))
        var floor_y: float = model.floor_at(p)
        var mineral: float = clampf(float(item.get("mineral", 0.0)), 0.0, 1.0)
        var biomass: float = clampf(float(item.get("biomass", 0.0)), 0.0, 3.0)
        if mineral < 0.05 and biomass < 0.005: continue
        var body_size: float = clampf(float(item.get("size", 0.5)), 0.15, 2.3)
        # Inert remains shrink as soft tissue is eaten/decays. They do not
        # spontaneously become living coral. Skeletal residue persists below.
        var stage: String = str(item.get("stage", "detritus"))
        var reef_growth: float = clampf(float(item.get("reef_growth", 0.0)), 0.0, 1.0)
        var height: float = 0.08 + body_size * (0.10 * mineral + 0.15 * biomass)
        var radius: float = 0.3 + body_size * 0.35
        var shape: Vector3 = Vector3(radius, height, radius)
        if stage in ["corpse", "carrion"]:
            shape = Vector3(radius * 1.45, maxf(0.12, height * 0.70), radius * 0.72)
        elif stage == "skeleton":
            shape = Vector3(radius * 1.60, maxf(0.06, height * 0.42), radius * 0.30)
        elif stage == "reef_substrate":
            shape = Vector3(radius * (0.65 + reef_growth * 0.55), maxf(0.18, height + reef_growth * body_size), radius * (0.65 + reef_growth * 0.55))
        p.y = maxf(floor_y + height * 0.5, p.y)
        transforms.append(Transform3D(Basis.IDENTITY.scaled(shape), p))
        var color: Color = Color(0.62, 0.57, 0.45).lerp(Color(0.40, 0.21, 0.16), clampf(biomass, 0.0, 1.0))
        if stage == "skeleton": color = Color(0.82, 0.79, 0.64)
        elif stage == "reef_substrate": color = Color(0.72, 0.34, 0.42).lerp(Color(0.34, 0.52, 0.45), reef_growth)
        colors.append(color)
    var multi: MultiMesh = reef_instance.multimesh
    multi.visible_instance_count = transforms.size()
    for i in range(transforms.size()):
        multi.set_instance_transform(i, transforms[i])
        multi.set_instance_color(i, colors[i])

func _build_water_surface(half: float) -> void:
    var plane = MeshInstance3D.new()
    var mesh = PlaneMesh.new()
    mesh.size = Vector2(half * 2.0, half * 2.0)
    mesh.subdivide_width = 96
    mesh.subdivide_depth = 96
    var mat = ShaderMaterial.new()
    mat.shader = preload("res://game/water_surface.gdshader")
    water_material = mat
    mat.set_shader_parameter("world_time", world_time)
    mesh.material = mat
    plane.mesh = mesh
    plane.position.y = waterline
    plane.extra_cull_margin = 0.20
    geometry_root.add_child(plane)

func _build_air_markers(half: float) -> void:
    var mm_instance = MultiMeshInstance3D.new()
    var sphere = SphereMesh.new()
    sphere.radius = 0.10
    sphere.height = 0.20
    sphere.radial_segments = 5
    sphere.rings = 3
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.86, 0.90, 0.94, 0.18)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    sphere.material = mat
    var mm = MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = sphere
    mm.instance_count = 80
    var rng = RandomNumberGenerator.new()
    rng.seed = 42119
    for i in range(mm.instance_count):
        var p = Vector3(rng.randf_range(-half, half), rng.randf_range(waterline + 1.5, model.ceiling_y - 1.0), rng.randf_range(-half, half))
        mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
    mm_instance.multimesh = mm
    geometry_root.add_child(mm_instance)

func _build_shoreline() -> void:
    # Intersect the actual terrain triangles with the mean water plane.
    var points: Array[Vector3] = []
    for z in range(model.GRID):
        for x in range(model.GRID):
            var a: Vector3 = model.vertex(x, z)
            var b: Vector3 = model.vertex(x + 1, z)
            var c: Vector3 = model.vertex(x, z + 1)
            var d: Vector3 = model.vertex(x + 1, z + 1)
            for triangle in [[a, b, c], [b, d, c]]:
                var crossings: Array[Vector3] = []
                for edge in [[0, 1], [1, 2], [2, 0]]:
                    var u: Vector3 = triangle[edge[0]]
                    var v: Vector3 = triangle[edge[1]]
                    if (u.y - waterline) * (v.y - waterline) < 0.0:
                        var p: Vector3 = u.lerp(v, (waterline - u.y) / (v.y - u.y))
                        p.y = waterline + 0.15
                        crossings.append(p)
                if crossings.size() == 2:
                    points.append_array(crossings)
    if points.is_empty(): return
    var mesh = ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    for p in points:
        mesh.surface_add_vertex(p)
    mesh.surface_end()
    var instance = MeshInstance3D.new()
    instance.mesh = mesh
    var material = StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color(0.72, 0.88, 0.85, 0.72)
    instance.material_override = material
    geometry_root.add_child(instance)
