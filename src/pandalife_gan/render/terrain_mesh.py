from __future__ import annotations

import logging

import numpy as np
from panda3d.core import (
    Geom,
    GeomNode,
    GeomTriangles,
    GeomVertexData,
    GeomVertexFormat,
    GeomVertexRewriter,
    GeomVertexWriter,
    NodePath,
)

from pandalife_gan.simulation.world import WorldSnapshot

LOG = logging.getLogger(__name__)


class LifeTerrainMesh:
    """A lightweight dynamic 3D mesh for terrain-style Life rendering.

    The mesh samples the simulation grid at a fixed stride. This avoids one
    Panda3D object per cell and keeps the 3D mode reasonably cheap even on older
    Windows machines.
    """

    def __init__(self, parent: NodePath, grid_width: int, grid_height: int, max_vertices_axis: int = 96):
        self.grid_width = int(grid_width)
        self.grid_height = int(grid_height)
        self.stride = max(1, int(np.ceil(max(self.grid_width, self.grid_height) / max(8, max_vertices_axis))))
        self.sample_w = max(2, int(np.ceil(self.grid_width / self.stride)))
        self.sample_h = max(2, int(np.ceil(self.grid_height / self.stride)))
        self.height_scale = 8.5
        self.vdata = GeomVertexData("life-terrain-vdata", GeomVertexFormat.getV3n3t2(), Geom.UHDynamic)
        self.vdata.setNumRows(self.sample_w * self.sample_h)
        self._create_vertices(flat=True)
        geom = Geom(self.vdata)
        geom.addPrimitive(self._create_triangles())
        node = GeomNode("life-terrain")
        node.addGeom(geom)
        self.node_path = parent.attachNewNode(node)
        self.node_path.setTwoSided(True)
        LOG.info(
            "Created 3D terrain mesh: grid=%sx%s sample=%sx%s stride=%s",
            self.grid_width,
            self.grid_height,
            self.sample_w,
            self.sample_h,
            self.stride,
        )

    def _create_vertices(self, flat: bool = False) -> None:
        vw = GeomVertexWriter(self.vdata, "vertex")
        nw = GeomVertexWriter(self.vdata, "normal")
        tw = GeomVertexWriter(self.vdata, "texcoord")
        for sy in range(self.sample_h):
            gy = min(self.grid_height - 1, sy * self.stride)
            for sx in range(self.sample_w):
                gx = min(self.grid_width - 1, sx * self.stride)
                height = 0.0 if flat else 1.0
                vw.addData3f(float(gx), float(height), float(gy))
                nw.addData3f(0.0, 1.0, 0.25)
                tw.addData2f(gx / max(1, self.grid_width - 1), 1.0 - gy / max(1, self.grid_height - 1))

    def _create_triangles(self) -> GeomTriangles:
        tris = GeomTriangles(Geom.UHStatic)
        for sy in range(self.sample_h - 1):
            for sx in range(self.sample_w - 1):
                i0 = sy * self.sample_w + sx
                i1 = i0 + 1
                i2 = i0 + self.sample_w
                i3 = i2 + 1
                tris.addVertices(i0, i2, i1)
                tris.addVertices(i1, i2, i3)
        tris.closePrimitive()
        return tris

    def update_from_snapshot(self, snap: WorldSnapshot) -> None:
        grid = snap.grid
        age = snap.age.astype(np.float32)
        owner = snap.owner
        vw = GeomVertexRewriter(self.vdata, "vertex")
        for sy in range(self.sample_h):
            gy = min(self.grid_height - 1, sy * self.stride)
            for sx in range(self.sample_w):
                gx = min(self.grid_width - 1, sx * self.stride)
                alive = bool(grid[gy, gx])
                if alive:
                    oid = int(owner[gy, gx])
                    org = snap.organisms.get(oid)
                    complexity = org.complexity_level if org else 0
                    energy = org.energy if org else 0.5
                    h = 1.0 + min(7.5, np.log1p(age[gy, gx]) * 1.2) + complexity * 1.25 + energy * 1.2
                else:
                    h = -0.18
                vw.setData3f(float(gx), float(h * self.height_scale / 8.5), float(gy))
