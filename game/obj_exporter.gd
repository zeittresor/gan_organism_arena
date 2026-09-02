extends RefCounted

static func export_organism(org) -> String:
    if not is_instance_valid(org) or not org.visual: return ""
    org.visual.flush_render()
    var dir: String = ProjectSettings.globalize_path("res://exports/obj")
    DirAccess.make_dir_recursive_absolute(dir)
    var path: String = dir.path_join("organism_%05d_gen_%03d_step.obj" % [org.organism_id, org.genome.generation])
    var file = FileAccess.open(path, FileAccess.WRITE)
    if not file: return ""
    file.store_line("# GAN Organism Arena: current articulated pose and tissue connections")
    file.store_line("# id=%d family=%d generation=%d" % [org.organism_id, org.genome.family_id, org.genome.generation])
    var vertex_base: int = 1
    for instance in [org.visual.multimesh_instance, org.visual.links_instance]:
        var mm: MultiMesh = instance.multimesh
        var arrays: Array = mm.mesh.surface_get_arrays(0)
        var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
        for i in range(mm.instance_count):
            var transform_value: Transform3D = mm.get_instance_transform(i)
            if absf(transform_value.basis.determinant()) < 0.00000001: continue
            for point in vertices:
                var p: Vector3 = transform_value * point
                file.store_line("v %.6f %.6f %.6f" % [p.x, p.y, p.z])
            if indices.is_empty():
                for j in range(0, vertices.size() - 2, 3):
                    file.store_line("f %d %d %d" % [vertex_base + j, vertex_base + j + 1, vertex_base + j + 2])
            else:
                for j in range(0, indices.size() - 2, 3):
                    file.store_line("f %d %d %d" % [vertex_base + indices[j], vertex_base + indices[j + 1], vertex_base + indices[j + 2]])
            vertex_base += vertices.size()
    file.close()
    return path
