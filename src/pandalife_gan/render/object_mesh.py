from __future__ import annotations

import logging
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import numpy as np
from panda3d.core import (
    Geom,
    GeomNode,
    GeomTriangles,
    GeomVertexData,
    GeomVertexFormat,
    GeomVertexWriter,
    NodePath,
)

from pandalife_gan.simulation.organism import Organism
from pandalife_gan.simulation.world import WorldSnapshot

LOG = logging.getLogger(__name__)


@dataclass(slots=True)
class MeshData:
    vertices: list[tuple[float, float, float]]
    faces: list[tuple[int, int, int]]
    colors: list[tuple[float, float, float, float]]


class LifeObjectMesh:
    """Dynamic true-3D organism-object view.

    This renderer does not use a heightmap. It converts each primary lifeform
    into an organic 3D body made from an evolving ellipsoid core plus optional
    appendages, sensors/eyes and armor hints. The shapes are derived from the
    organism's current component, genome and traits, so they can be exported as
    normal OBJ meshes for external 3D tools.
    """

    def __init__(
        self,
        parent: NodePath,
        grid_width: int,
        grid_height: int,
        max_organisms: int = 28,
        quality: str = "balanced",
    ):
        self.grid_width = int(grid_width)
        self.grid_height = int(grid_height)
        self.max_organisms = int(max_organisms)
        self.quality = quality if quality in {"fast", "balanced", "detailed"} else "balanced"
        self.world_scale = 0.72
        self.light_vector = np.array([-0.55, -0.70, 0.45], dtype=np.float32)
        self.light_vector /= max(1e-6, float(np.linalg.norm(self.light_vector)))
        self.last_vertex_count = 0
        self.last_face_count = 0
        self.last_rendered_organisms = 0
        self.last_skipped_organisms = 0
        self.max_vertices_by_quality = {"fast": 7200, "balanced": 11000, "detailed": 15500}
        self.geom_node = GeomNode("life-object-organisms")
        self.node_path = parent.attachNewNode(self.geom_node)
        self.node_path.setTwoSided(True)
        LOG.info("Created 3D object organism mesh root: max_organisms=%s quality=%s", self.max_organisms, self.quality)

    def set_light_vector(self, vector) -> None:
        try:
            arr = np.array([float(vector[0]), float(vector[1]), float(vector[2])], dtype=np.float32)
            norm = float(np.linalg.norm(arr))
            if norm > 1e-6:
                self.light_vector = arr / norm
        except Exception:
            pass

    def _lit_color(self, color: tuple[float, float, float, float], normal) -> tuple[float, float, float, float]:
        try:
            n = np.array(normal, dtype=np.float32)
            n_norm = float(np.linalg.norm(n))
            if n_norm <= 1e-6:
                return color
            n = n / n_norm
            dot = max(0.0, float(np.dot(n, self.light_vector)))
            ambient = 0.36
            shade = min(1.25, ambient + 0.82 * dot)
            return (min(1.0, color[0] * shade), min(1.0, color[1] * shade), min(1.0, color[2] * shade), color[3])
        except Exception:
            return color

    def _quality_scale(self) -> float:
        return {"fast": 0.42, "balanced": 0.58, "detailed": 0.72}.get(self.quality, 0.50)

    def _mesh_steps(self, base_lat: int, base_lon: int) -> tuple[int, int]:
        q = self._quality_scale()
        return max(4, int(round(base_lat * q))), max(6, int(round(base_lon * q)))

    def select_primary_organisms(self, snap: WorldSnapshot, limit: int | None = None) -> list[Organism]:
        limit = int(limit or self.max_organisms)
        organisms = [o for o in snap.organisms.values() if o.alive and o.size >= 3]
        def key(o: Organism):
            recent = max(0, 120 - max(0, snap.step_index - getattr(o, "birth_step", 0))) / 120.0
            intelligence = float(getattr(o, "intelligence", 0.0))
            return (o.complexity_score + recent * 0.14 + intelligence * 0.08, o.score, o.size, o.age)
        organisms.sort(key=key, reverse=True)
        return organisms[:limit]

    def _vertex_budget(self) -> int:
        return int(self.max_vertices_by_quality.get(self.quality, 9000))

    def _rank_limit(self) -> int:
        # True-3D object meshes are CPU-generated each refresh. Keeping the
        # default visible set small gives stable FPS while still showing the
        # most important creatures. Users can raise the cap; the vertex budget
        # still prevents runaway geometry in long simulations.
        qlimit = {"fast": 18, "balanced": 14, "detailed": 10}.get(self.quality, 12)
        return max(3, min(int(self.max_organisms), qlimit))

    def update_from_snapshot(self, snap: WorldSnapshot) -> None:
        organisms = self.select_primary_organisms(snap, limit=self._rank_limit())
        self.geom_node.removeAllGeoms()
        self.last_vertex_count = 0
        self.last_face_count = 0
        self.last_rendered_organisms = 0
        self.last_skipped_organisms = 0
        if not organisms:
            return
        vertex_budget = self._vertex_budget()
        vertices: list[tuple[float, float, float]] = []
        colors: list[tuple[float, float, float, float]] = []
        faces: list[tuple[int, int, int]] = []
        for rank, org in enumerate(organisms):
            cells = self._organism_cells(snap, org.id)
            mesh = self.build_organism_mesh(snap, org, cells, local=False)
            # Always keep at least a few organisms, then respect the global
            # vertex budget.  This stops FPS from degrading as complexity grows.
            if rank >= 3 and len(vertices) + len(mesh.vertices) > vertex_budget:
                self.last_skipped_organisms += len(organisms) - rank
                break
            base = len(vertices)
            vertices.extend(mesh.vertices)
            colors.extend(mesh.colors)
            faces.extend((a + base, b + base, c + base) for a, b, c in mesh.faces)
            self.last_rendered_organisms += 1
        self.last_vertex_count = len(vertices)
        self.last_face_count = len(faces)
        self._install_geom(vertices, colors, faces)

    def _install_geom(
        self,
        vertices: list[tuple[float, float, float]],
        colors: list[tuple[float, float, float, float]],
        faces: list[tuple[int, int, int]],
    ) -> None:
        if not vertices or not faces:
            return
        vdata = GeomVertexData("life-object-vdata", GeomVertexFormat.getV3c4(), Geom.UHDynamic)
        vdata.setNumRows(len(vertices))
        vw = GeomVertexWriter(vdata, "vertex")
        cw = GeomVertexWriter(vdata, "color")
        for vertex, color in zip(vertices, colors):
            vw.addData3f(*vertex)
            cw.addData4f(*color)
        tris = GeomTriangles(Geom.UHStatic)
        for a, b, c in faces:
            tris.addVertices(int(a), int(b), int(c))
        tris.closePrimitive()
        geom = Geom(vdata)
        geom.addPrimitive(tris)
        self.geom_node.addGeom(geom)

    def _organism_cells(self, snap: WorldSnapshot, organism_id: int) -> np.ndarray:
        cells = np.argwhere((snap.owner == int(organism_id)) & snap.grid)
        if cells.size == 0:
            return np.empty((0, 2), dtype=np.int32)
        return cells.astype(np.int32, copy=False)

    def _world_offset(self, org: Organism) -> tuple[float, float, float]:
        cx, cy = org.centroid
        nx = (float(cx) / max(1.0, self.grid_width - 1.0) - 0.5) * 2.0
        nz = (float(cy) / max(1.0, self.grid_height - 1.0) - 0.5) * 2.0
        # Slightly dome-shaped organism world. It gives the special object mode
        # a spherical-stage feel without distorting the exported local organism.
        dome = max(0.0, 1.0 - 0.36 * (nx * nx + nz * nz))
        surface_y = math.sqrt(dome) * 14.0 - 10.0
        x = (float(cx) - self.grid_width / 2.0) * self.world_scale
        z = (float(cy) - self.grid_height / 2.0) * self.world_scale
        y = surface_y + 0.55 * org.complexity_level
        return x, y, z

    def build_organism_mesh(
        self,
        snap: WorldSnapshot,
        org: Organism,
        cells_yx: np.ndarray | None = None,
        *,
        local: bool = False,
    ) -> MeshData:
        if cells_yx is None:
            cells_yx = self._organism_cells(snap, org.id)
        if cells_yx.size == 0:
            cells_yx = np.array([[int(org.centroid[1]), int(org.centroid[0])]], dtype=np.int32)

        cx, cy = org.centroid
        dx = cells_yx[:, 1].astype(np.float32) - float(cx)
        dy = cells_yx[:, 0].astype(np.float32) - float(cy)
        spread_x = float(np.std(dx)) if dx.size else 1.0
        spread_z = float(np.std(dy)) if dy.size else 1.0
        size = max(1, int(org.size or cells_yx.shape[0]))
        complexity = max(0, int(org.complexity_level))
        growth = math.sqrt(max(0, complexity))
        base = 0.88 + math.log1p(size) * 0.22 + growth * 0.55
        # True-3D organisms are allowed to keep becoming macro-forms. These
        # are still guarded by soft render caps to avoid unbounded geometry.
        rx = max(0.80, min(28.0, base + spread_x * 0.30 + org.genome.expansion * (1.15 + growth * 0.18)))
        rz = max(0.80, min(28.0, base + spread_z * 0.30 + org.genome.stabilization * (0.90 + growth * 0.15)))
        ry = max(0.70, min(24.0, base * 0.72 + org.energy * 1.35 + growth * 0.78))

        center = (0.0, 0.0, 0.0) if local else self._world_offset(org)
        color = self._rgba01(org.color_rgba, alpha=1.0)
        shell = self._boost_color(color, 1.0 + org.armor * 0.35)
        eye_color = (0.80, 1.00, 0.95, 1.0)
        limb_color = self._boost_color(color, 1.18)

        if complexity >= 2:
            return self._build_structured_creature(
                org,
                center=center,
                color=color,
                shell=shell,
                eye_color=eye_color,
                limb_color=limb_color,
                radii=(rx, ry, rz),
            )

        vertices: list[tuple[float, float, float]] = []
        colors: list[tuple[float, float, float, float]] = []
        faces: list[tuple[int, int, int]] = []

        self._add_ellipsoid(vertices, colors, faces, center, (rx, ry, rz), color, org)

        # Armor as a faint second shell on advanced/stable organisms.
        if org.armor > 0.18 or complexity >= 3:
            shell_r = (rx * (1.07 + org.armor * 0.18), ry * (1.04 + org.armor * 0.13), rz * (1.07 + org.armor * 0.18))
            self._add_ellipsoid(vertices, colors, faces, center, shell_r, (*shell[:3], 0.42), org, lat_steps=5, lon_steps=10)

        appendage_count = max(0, min(24, org.limbs + org.manipulators))
        for i in range(appendage_count):
            angle = (2.0 * math.pi * i / max(1, appendage_count)) + org.id * 0.37 + org.age * 0.006
            up_bias = 0.18 * math.sin(org.age * 0.04 + i)
            direction = (math.cos(angle), up_bias, math.sin(angle))
            start = (center[0] + direction[0] * rx * 0.82, center[1] + direction[1] * ry, center[2] + direction[2] * rz * 0.82)
            length = 1.25 + 0.45 * math.sqrt(max(0, complexity)) + 0.055 * min(90, size) + 0.30 * org.energy
            end = (
                center[0] + direction[0] * (rx + length),
                center[1] + direction[1] * (ry + length * 0.55) - 0.18 * (i % 2),
                center[2] + direction[2] * (rz + length),
            )
            radius = 0.16 + 0.055 * math.sqrt(max(0, complexity)) + 0.020 * org.manipulators
            self._add_tapered_cylinder(vertices, colors, faces, start, end, radius, radius * 0.42, limb_color, segments=7)

        eye_count = max(0, min(18, org.eyes + org.sensors // 2))
        if eye_count:
            front_angle = math.atan2(org.genome.motion_bias[1], org.genome.motion_bias[0]) if any(org.genome.motion_bias) else org.id * 0.61
            for i in range(eye_count):
                offset_angle = front_angle + (i - (eye_count - 1) / 2.0) * 0.34
                pos = (
                    center[0] + math.cos(offset_angle) * rx * 0.84,
                    center[1] + ry * (0.24 + 0.07 * (i % 2)),
                    center[2] + math.sin(offset_angle) * rz * 0.84,
                )
                self._add_ellipsoid(vertices, colors, faces, pos, (0.20, 0.16, 0.20), eye_color, org, lat_steps=5, lon_steps=8, noise=False)

        return MeshData(vertices=vertices, faces=faces, colors=colors)


    def _build_structured_creature(
        self,
        org: Organism,
        *,
        center: tuple[float, float, float],
        color: tuple[float, float, float, float],
        shell: tuple[float, float, float, float],
        eye_color: tuple[float, float, float, float],
        limb_color: tuple[float, float, float, float],
        radii: tuple[float, float, float],
    ) -> MeshData:
        """Builds more creature-like bodies for evolved organisms.

        Instead of a single blob with spikes, high-complexity organisms gain a
        torso, spine, head, tail and posture-dependent limbs/wings/fins. The
        exact body remains abstract, but it can now progress from simple
        vertebrate-like shapes to more upright sophont-like silhouettes.
        """
        vertices: list[tuple[float, float, float]] = []
        colors: list[tuple[float, float, float, float]] = []
        faces: list[tuple[int, int, int]] = []
        cx, cy, cz = center
        rx, ry, rz = radii
        complexity = max(0, int(org.complexity_level))
        growth = math.sqrt(max(0, complexity))
        spine_n = max(3, min(10 if self.quality == "fast" else 13 if self.quality == "balanced" else 16, org.spine_segments or 3))
        spine_len = 4.2 + 1.15 * growth + 0.11 * min(160, org.size)
        torso_height = max(0.52, 0.42 * ry + 0.032 * complexity)
        torso_width = max(0.46, 0.34 * rz + 0.026 * complexity)
        head_scale = max(0.9, org.head_size)

        posture = getattr(org, "posture", "crawling")
        # Axis describing the main body orientation.
        if posture in {"upright", "biped"}:
            main_axis = np.array([0.25, 0.96, 0.0], dtype=np.float32)
        elif posture == "avian":
            main_axis = np.array([0.78, 0.48, 0.0], dtype=np.float32)
        else:
            main_axis = np.array([0.96, 0.20 if posture == "serpentine" else 0.12, 0.0], dtype=np.float32)
        main_axis /= max(1e-6, float(np.linalg.norm(main_axis)))
        side_axis = np.array([0.0, 0.0, 1.0], dtype=np.float32)
        up_axis = np.cross(side_axis, main_axis)
        up_axis /= max(1e-6, float(np.linalg.norm(up_axis)))

        spine_points: list[tuple[float, float, float]] = []
        for i in range(spine_n):
            t = 0.0 if spine_n == 1 else i / float(spine_n - 1)
            xoff = (t - 0.38) * spine_len
            arch = math.sin(t * math.pi) * (0.25 * growth)
            sway = math.sin(t * math.pi * 2.0 + org.id * 0.21 + org.trait_pulse * math.pi) * (0.18 + 0.02 * complexity)
            if posture == "serpentine":
                sway *= 1.7
            pos = np.array([cx, cy, cz], dtype=np.float32) + main_axis * xoff + up_axis * arch + side_axis * sway
            spine_points.append((float(pos[0]), float(pos[1]), float(pos[2])))
            radius_scale = 0.60 + 0.55 * math.sin(t * math.pi)
            seg_r = (torso_width * radius_scale, torso_height * (0.58 + 0.25 * math.sin(t * math.pi)), torso_width * radius_scale * 0.66)
            self._add_ellipsoid(vertices, colors, faces, spine_points[-1], seg_r, color, org, lat_steps=6 + min(8, complexity // 6), lon_steps=10 + min(14, complexity // 4))
            if i > 0:
                self._add_tapered_cylinder(vertices, colors, faces, spine_points[i - 1], spine_points[i], 0.18 + 0.035 * growth, 0.16 + 0.03 * growth, limb_color, segments=8)

        # Optional armor shell / dorsal plates for more advanced organisms.
        if org.armor > 0.16 or complexity >= 12:
            for i, p in enumerate(spine_points[1:-1], start=1):
                plate_h = 0.18 + org.armor * 0.42 + 0.018 * complexity
                top = (p[0], p[1] + plate_h, p[2])
                self._add_tapered_cylinder(vertices, colors, faces, p, top, 0.10 + 0.015 * org.armor * complexity, 0.03, (*shell[:3], 0.85), segments=5)

        front = np.array(spine_points[-1], dtype=np.float32)
        rear = np.array(spine_points[0], dtype=np.float32)
        head_center = front + main_axis * (0.55 + 0.18 * head_scale) + up_axis * (0.10 * head_scale)
        head_r = (0.55 * head_scale, 0.50 * head_scale, 0.48 * head_scale)
        self._add_tapered_cylinder(vertices, colors, faces, spine_points[-1], tuple(head_center), 0.24 + 0.04 * head_scale, 0.18 + 0.03 * head_scale, limb_color, segments=7)
        self._add_ellipsoid(vertices, colors, faces, tuple(head_center), head_r, self._boost_color(color, 1.08), org, lat_steps=7, lon_steps=12)

        # Eyes / face.
        eye_pairs = max(1, min(4, org.eyes // 2 if org.eyes else 1))
        for i in range(eye_pairs * 2):
            side = -1.0 if i % 2 == 0 else 1.0
            row = i // 2
            epos = head_center + main_axis * (0.18 + 0.04 * row) + up_axis * (0.06 - 0.03 * row) + side_axis * side * (0.22 + 0.06 * row)
            self._add_ellipsoid(vertices, colors, faces, tuple(epos), (0.10, 0.09, 0.10), eye_color, org, lat_steps=4, lon_steps=6, noise=False)
        # Sensor antennae / feelers.  These are intentionally long and
        # high-contrast so early evolved forms visibly stop looking like
        # plain blobs even in fast mesh quality.
        feeler_count = 2 + (1 if org.sensors >= 4 and self.quality != "fast" else 0)
        for i in range(feeler_count):
            side = -1.0 if i % 2 == 0 else 1.0
            offset = (i // 2) * 0.20
            root = head_center + side_axis * side * (0.20 + offset) + up_axis * 0.18
            tip = root + main_axis * (1.1 + 0.12 * growth) + side_axis * side * (0.55 + 0.04 * growth) + up_axis * (0.42 + 0.04 * growth)
            self._add_tapered_cylinder(vertices, colors, faces, tuple(root), tuple(tip), 0.045, 0.010, self._boost_color(eye_color, 1.05), segments=4)

        # Jaw / mouth as simple chin cylinder for high intelligence forms.
        if getattr(org, "speech_level", 0) >= 2:
            mouth = head_center + main_axis * 0.28 - up_axis * 0.20
            self._add_tapered_cylinder(vertices, colors, faces, tuple(head_center + main_axis * 0.16 - up_axis * 0.15), tuple(mouth), 0.08, 0.03, (0.9, 0.82, 0.82, 0.95), segments=5)

        # Tail.
        tail_n = max(0, min(10, org.tail_segments))
        if tail_n:
            prev = rear
            for i in range(tail_n):
                t = (i + 1) / float(tail_n)
                tail_dir = -main_axis + side_axis * (0.15 * math.sin(i * 0.7 + org.id * 0.3))
                tail_dir /= max(1e-6, float(np.linalg.norm(tail_dir)))
                seg = prev + tail_dir * (0.35 + 0.18 * (1.0 - t) * growth) - up_axis * (0.06 * t)
                self._add_tapered_cylinder(vertices, colors, faces, tuple(prev), tuple(seg), 0.14 * (1.0 - 0.55 * t), 0.06 * (1.0 - 0.5 * t), limb_color, segments=6)
                prev = seg
            # Optional tail fin / fan
            if org.fin_pairs > 0 or org.feather_level > 0.35:
                self._add_tapered_cylinder(vertices, colors, faces, tuple(prev), tuple(prev + side_axis * 1.2), 0.08, 0.01, self._boost_color(color, 1.18), segments=4)
                self._add_tapered_cylinder(vertices, colors, faces, tuple(prev), tuple(prev - side_axis * 1.2), 0.08, 0.01, self._boost_color(color, 1.18), segments=4)

        # Limbs, wings, fins.
        anchors = spine_points[1:-1] if len(spine_points) > 2 else spine_points
        leg_pairs = max(1 if complexity >= 2 else 0, min(3 if self.quality == "fast" else 4, org.leg_pairs))
        arm_pairs = max(1 if complexity >= 4 else 0, min(2 if self.quality == "fast" else 3, org.arm_pairs))
        fin_pairs = max(0, min(2 if self.quality == "fast" else 4, org.fin_pairs))
        feather_level = max(0.0, min(1.0, org.feather_level))

        def anchor_at(frac: float) -> np.ndarray:
            idx = max(0, min(len(anchors) - 1, int(round(frac * max(0, len(anchors) - 1)))))
            return np.array(anchors[idx], dtype=np.float32)

        # Legs.
        for i in range(leg_pairs):
            frac = 0.25 + (0.42 * i / max(1, leg_pairs - 1)) if leg_pairs > 1 else (0.58 if posture in {"biped", "upright"} else 0.38)
            root = anchor_at(frac)
            for side in (-1.0, 1.0):
                hip = root + side_axis * side * (torso_width * 0.52) - up_axis * (torso_height * 0.12)
                knee = hip - up_axis * (1.35 + 0.20 * growth) + main_axis * (0.28 if posture in {"biped", "upright", "avian"} else -0.18)
                foot = knee - up_axis * (1.25 + 0.22 * growth) + main_axis * (0.48 if posture in {"biped", "upright", "avian"} else 0.25)
                self._add_tapered_cylinder(vertices, colors, faces, tuple(hip), tuple(knee), 0.20 + 0.026 * growth, 0.13 + 0.014 * growth, limb_color, segments=7)
                self._add_tapered_cylinder(vertices, colors, faces, tuple(knee), tuple(foot), 0.13 + 0.014 * growth, 0.075, limb_color, segments=7)
                toe_span = 0.25 + 0.03 * getattr(org, "finger_count", 0)
                self._add_tapered_cylinder(vertices, colors, faces, tuple(foot), tuple(foot + main_axis * (0.38 + 0.03 * growth) + side_axis * side * toe_span), 0.04, 0.01, limb_color, segments=4)

        # Arms / forelimbs / wings.
        for i in range(max(arm_pairs, 1 if posture in {"avian", "upright", "biped"} else 0)):
            frac = 0.70 + (0.18 * i / max(1, arm_pairs))
            root = anchor_at(min(0.92, frac))
            for side in (-1.0, 1.0):
                shoulder = root + side_axis * side * (torso_width * 0.60) + up_axis * (torso_height * 0.12)
                elbow = shoulder + side_axis * side * (1.35 + 0.14 * growth) - up_axis * (0.08 if posture == "avian" else 0.48) + main_axis * 0.26
                hand = elbow + side_axis * side * (1.10 + 0.13 * growth) - up_axis * (0.04 if posture == "avian" else 0.36) + main_axis * 0.18
                self._add_tapered_cylinder(vertices, colors, faces, tuple(shoulder), tuple(elbow), 0.16 + 0.024 * growth, 0.11 + 0.012 * growth, limb_color, segments=7)
                self._add_tapered_cylinder(vertices, colors, faces, tuple(elbow), tuple(hand), 0.10, 0.052, limb_color, segments=7)
                if posture == "avian" or feather_level > 0.55:
                    # Wing/feather fan
                    fan_color = self._boost_color(color, 1.16)
                    for wing_i in range(3 + int(feather_level * 4)):
                        spread = 0.45 + wing_i * 0.22
                        feather = hand + side_axis * side * spread + up_axis * (0.16 * wing_i)
                        self._add_tapered_cylinder(vertices, colors, faces, tuple(elbow), tuple(feather), 0.04, 0.01, fan_color, segments=4)
                elif fin_pairs > 0 and posture not in {"biped", "upright"}:
                    fin_tip = hand + side_axis * side * (0.95 + 0.10 * fin_pairs) + up_axis * 0.10
                    self._add_tapered_cylinder(vertices, colors, faces, tuple(elbow), tuple(fin_tip), 0.05, 0.01, self._boost_color(color, 1.14), segments=4)
                else:
                    fingers = max(0, min(5, getattr(org, "finger_count", 0)))
                    for f in range(fingers):
                        spread = (f - (fingers - 1) / 2.0) * 0.12
                        finger_tip = hand + main_axis * 0.22 + side_axis * side * spread - up_axis * 0.03 * f
                        self._add_tapered_cylinder(vertices, colors, faces, tuple(hand), tuple(finger_tip), 0.025, 0.008, limb_color, segments=4)

        # Additional lateral fins for aquatic / glide-like forms.
        if fin_pairs > 0 and posture in {"serpentine", "quadruped", "crawling"}:
            for i in range(fin_pairs):
                frac = 0.25 + i / max(1, fin_pairs) * 0.55
                root = anchor_at(frac)
                for side in (-1.0, 1.0):
                    tip = root + side_axis * side * (0.95 + 0.16 * i) + up_axis * 0.10
                    self._add_tapered_cylinder(vertices, colors, faces, tuple(root), tuple(tip), 0.05, 0.01, self._boost_color(color, 1.12), segments=4)

        return MeshData(vertices=vertices, faces=faces, colors=colors)

    @staticmethod
    def _rgba01(color_rgba: tuple[int, int, int, int], alpha: float = 1.0) -> tuple[float, float, float, float]:
        r, g, b, _ = color_rgba
        return (r / 255.0, g / 255.0, b / 255.0, alpha)

    @staticmethod
    def _boost_color(color: tuple[float, float, float, float], factor: float) -> tuple[float, float, float, float]:
        return (min(1.0, color[0] * factor), min(1.0, color[1] * factor), min(1.0, color[2] * factor), color[3])

    def _add_ellipsoid(
        self,
        vertices: list[tuple[float, float, float]],
        colors: list[tuple[float, float, float, float]],
        faces: list[tuple[int, int, int]],
        center: tuple[float, float, float],
        radii: tuple[float, float, float],
        color: tuple[float, float, float, float],
        org: Organism,
        *,
        lat_steps: int | None = None,
        lon_steps: int | None = None,
        noise: bool = True,
    ) -> None:
        complexity = max(0, int(org.complexity_level))
        base_lat = int(lat_steps or (7 + min(7, complexity)))
        base_lon = int(lon_steps or (12 + min(14, complexity * 2)))
        lat, lon = self._mesh_steps(base_lat, base_lon)
        lat = max(4, min(10, lat))
        lon = max(6, min(16, lon))
        base = len(vertices)
        rx, ry, rz = radii
        cx, cy, cz = center
        for i in range(lat + 1):
            phi = -math.pi * 0.5 + math.pi * i / max(1, lat)
            cphi = math.cos(phi)
            sphi = math.sin(phi)
            for j in range(lon):
                theta = 2.0 * math.pi * j / max(1, lon)
                n = 1.0
                if noise:
                    n += 0.09 * math.sin(theta * 3.0 + org.id * 0.73 + org.age * 0.015)
                    n += 0.06 * math.cos(phi * 5.0 + theta * 1.7 + org.genome.vector[0] * 3.0)
                    n += 0.035 * math.sin((theta - phi) * 6.0 + org.trait_pulse * math.pi)
                normal = (cphi * math.cos(theta), sphi, cphi * math.sin(theta))
                vertices.append((cx + rx * n * cphi * math.cos(theta), cy + ry * n * sphi, cz + rz * n * cphi * math.sin(theta)))
                colors.append(self._lit_color(color, normal))
        for i in range(lat):
            for j in range(lon):
                a = base + i * lon + j
                b = base + i * lon + ((j + 1) % lon)
                c = base + (i + 1) * lon + j
                d = base + (i + 1) * lon + ((j + 1) % lon)
                faces.append((a, c, b))
                faces.append((b, c, d))

    def _add_tapered_cylinder(
        self,
        vertices: list[tuple[float, float, float]],
        colors: list[tuple[float, float, float, float]],
        faces: list[tuple[int, int, int]],
        start: tuple[float, float, float],
        end: tuple[float, float, float],
        r0: float,
        r1: float,
        color: tuple[float, float, float, float],
        *,
        segments: int = 7,
    ) -> None:
        segments = max(3, min(8, int(round(float(segments) * self._quality_scale()))))
        sx, sy, sz = start
        ex, ey, ez = end
        dx, dy, dz = ex - sx, ey - sy, ez - sz
        length = math.sqrt(dx * dx + dy * dy + dz * dz) or 1.0
        axis = np.array([dx / length, dy / length, dz / length], dtype=np.float32)
        up = np.array([0.0, 1.0, 0.0], dtype=np.float32)
        if abs(float(np.dot(axis, up))) > 0.92:
            up = np.array([1.0, 0.0, 0.0], dtype=np.float32)
        side1 = np.cross(axis, up)
        side1 /= max(1e-6, float(np.linalg.norm(side1)))
        side2 = np.cross(axis, side1)
        side2 /= max(1e-6, float(np.linalg.norm(side2)))
        base = len(vertices)
        for k, (cx, cy, cz, radius) in enumerate(((sx, sy, sz, r0), (ex, ey, ez, r1))):
            for i in range(segments):
                theta = 2.0 * math.pi * i / max(3, segments)
                offset = math.cos(theta) * side1 * radius + math.sin(theta) * side2 * radius
                vertices.append((float(cx + offset[0]), float(cy + offset[1]), float(cz + offset[2])))
                colors.append(self._lit_color(color, offset))
        for i in range(segments):
            a = base + i
            b = base + ((i + 1) % segments)
            c = base + segments + i
            d = base + segments + ((i + 1) % segments)
            faces.append((a, c, b))
            faces.append((b, c, d))

    def export_primary_organisms(
        self,
        snap: WorldSnapshot,
        export_root: Path,
        *,
        max_organisms: int = 32,
    ) -> Path:
        step_dir = export_root / f"step_{snap.step_index:08d}"
        step_dir.mkdir(parents=True, exist_ok=True)
        organisms = self.select_primary_organisms(snap, limit=max_organisms)
        combined_vertices: list[tuple[float, float, float]] = []
        combined_faces: list[tuple[int, int, int]] = []
        manifest_lines = [
            f"GAN Organism Arena OBJ export - step {snap.step_index}",
            f"Exported primary organisms: {len(organisms)}",
            "",
        ]
        for index, org in enumerate(organisms, start=1):
            cells = self._organism_cells(snap, org.id)
            mesh = self.build_organism_mesh(snap, org, cells, local=True)
            slug = f"organism_{index:02d}_id_{org.id}_family_{org.genome.family_id}_{org.body_plan}"
            obj_path = step_dir / f"{slug}.obj"
            mtl_path = step_dir / f"{slug}.mtl"
            self._write_obj(obj_path, mtl_path.name, slug, mesh, org)
            self._write_mtl(mtl_path, slug, org)
            base = len(combined_vertices)
            combined_vertices.extend(mesh.vertices)
            combined_faces.extend((a + base, b + base, c + base) for a, b, c in mesh.faces)
            manifest_lines.append(
                f"{obj_path.name}: id={org.id} family={org.genome.family_id} body={org.body_plan} size={org.size} age={org.age} score={org.score:.3f} energy={org.energy:.3f}"
            )
        if combined_vertices and combined_faces:
            combined = MeshData(combined_vertices, combined_faces, [(1, 1, 1, 1)] * len(combined_vertices))
            self._write_obj(step_dir / "all_primary_lifeforms.obj", "all_primary_lifeforms.mtl", "all_primary_lifeforms", combined, None)
            (step_dir / "all_primary_lifeforms.mtl").write_text("newmtl all_primary_lifeforms\nKd 0.80 0.88 0.86\nKa 0.05 0.05 0.05\n", encoding="utf-8")
        (step_dir / "README_export.txt").write_text("\n".join(manifest_lines) + "\n", encoding="utf-8")
        LOG.info("OBJ export complete: %s organisms=%s", step_dir, len(organisms))
        return step_dir

    def _write_obj(self, path: Path, mtl_name: str, object_name: str, mesh: MeshData, org: Organism | None) -> None:
        lines = [
            "# GAN Organism Arena OBJ export",
            f"mtllib {mtl_name}",
            f"o {object_name}",
            f"usemtl {object_name}",
        ]
        if org is not None:
            lines.extend([
                f"# organism_id {org.id}",
                f"# family_id {org.genome.family_id}",
                f"# body_plan {org.body_plan}",
                f"# size {org.size}",
                f"# age {org.age}",
                f"# energy {org.energy:.5f}",
                f"# score {org.score:.5f}",
                f"# traits eyes={org.eyes} limbs={org.limbs} manipulators={org.manipulators} sensors={org.sensors} armor={org.armor:.5f}",
            ])
        for x, y, z in mesh.vertices:
            lines.append(f"v {x:.6f} {y:.6f} {z:.6f}")
        for a, b, c in mesh.faces:
            lines.append(f"f {a + 1} {b + 1} {c + 1}")
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    def _write_mtl(self, path: Path, material_name: str, org: Organism) -> None:
        r, g, b, _ = self._rgba01(org.color_rgba)
        text = (
            f"newmtl {material_name}\n"
            f"Kd {r:.5f} {g:.5f} {b:.5f}\n"
            "Ka 0.04 0.04 0.04\n"
            "Ks 0.10 0.10 0.10\n"
            "Ns 18.0\n"
        )
        path.write_text(text, encoding="utf-8")
