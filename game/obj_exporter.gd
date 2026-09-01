extends RefCounted

static func export_organism(org) -> String:
    if not is_instance_valid(org) or not org.visual:
        return ""
    var dir = ProjectSettings.globalize_path("res://exports/obj")
    DirAccess.make_dir_recursive_absolute(dir)
    var path = dir.path_join("organism_%05d_gen_%03d_step.obj" % [org.organism_id, org.genome.generation])
    var f = FileAccess.open(path, FileAccess.WRITE)
    if not f:
        return ""
    f.store_line("# GAN Organism Arena 3D OBJ export")
    f.store_line("# id=%d family=%d generation=%d complexity=%.4f intelligence=%.4f" % [org.organism_id, org.genome.family_id, org.genome.generation, org.complexity, org.intelligence])
    var vertex_base = 1
    for cell_v in org.visual.body_cells:
        var cell: Dictionary = cell_v
        var p: Vector3 = cell["p"]
        var r = float(cell["r"])
        var shape: Vector3 = cell.get("s", Vector3.ONE)
        var rx: float = r * shape.x
        var ry: float = r * shape.y
        var rz: float = r * shape.z
        var verts = [
            p + Vector3(0, ry, 0), p + Vector3(rx, 0, 0), p + Vector3(0, 0, rz),
            p + Vector3(-rx, 0, 0), p + Vector3(0, 0, -rz), p + Vector3(0, -ry, 0)
        ]
        for v in verts:
            f.store_line("v %.6f %.6f %.6f" % [v.x, v.y, v.z])
        var faces = [[0,1,2],[0,2,3],[0,3,4],[0,4,1],[5,2,1],[5,3,2],[5,4,3],[5,1,4]]
        for face in faces:
            f.store_line("f %d %d %d" % [vertex_base + face[0], vertex_base + face[1], vertex_base + face[2]])
        vertex_base += 6
    f.close()
    return path
