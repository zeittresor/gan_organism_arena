from __future__ import annotations

from dataclasses import dataclass
import math

import numpy as np

from .genome import Genome


@dataclass(slots=True)
class GeneratedPattern:
    cells: np.ndarray
    genome: Genome
    label: str


class PseudoGanGenerator:
    """Shared morphology generator.

    It behaves like a deterministic GAN-style generator from latent vector to
    morphology, but requires no pretrained model. The class boundary is designed
    so a real ONNX generator can replace it later without changing the simulator.
    """

    def __init__(self, rng: np.random.Generator):
        self.rng = rng
        self._templates = self._build_templates()

    def random_genome(self, family_id: int) -> Genome:
        return Genome.random(self.rng, family_id=family_id)

    def generate(self, genome: Genome, max_size: int = 31) -> GeneratedPattern:
        idx = int(abs(genome._v(11) * 1009)) % len(self._templates)
        base = self._templates[idx].copy()
        label = f"template-{idx}"

        # Rotate/flip from latent code.
        rotations = int(abs(genome._v(12) * 10)) % 4
        base = np.rot90(base, rotations)
        if genome._v(13) > 0:
            base = np.fliplr(base)
        if genome._v(14) > 0.75:
            base = np.flipud(base)

        # Embed into a square canvas and add latent procedural detail.
        size = int(11 + (abs(genome._v(15)) % 1.0) * (max_size - 11))
        size = max(9, min(max_size, size | 1))
        canvas = np.zeros((size, size), dtype=bool)
        oy = (size - base.shape[0]) // 2
        ox = (size - base.shape[1]) // 2
        canvas[oy : oy + base.shape[0], ox : ox + base.shape[1]] |= base

        yy, xx = np.mgrid[0:size, 0:size]
        cx = (size - 1) / 2.0 + genome.motion_bias[0] * 1.8
        cy = (size - 1) / 2.0 + genome.motion_bias[1] * 1.8
        dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
        wave = np.sin(xx * (0.7 + abs(genome._v(0))) + genome._v(2) * 2.0)
        wave += np.cos(yy * (0.5 + abs(genome._v(1))) - genome._v(3) * 1.7)
        mask = (dist < size * (0.26 + 0.20 * genome.symmetry)) & (wave > 0.7)
        density_gate = self.rng.random((size, size)) < genome.density_preference * 0.28
        canvas |= mask & density_gate

        # Encourage symmetry for some families.
        if genome.symmetry > 0.55:
            if genome._v(4) > 0:
                canvas |= np.fliplr(canvas)
            else:
                canvas |= np.flipud(canvas)
        if genome.symmetry > 0.82:
            canvas |= canvas.T

        # Remove isolated excessive single-cell noise but keep classic templates.
        canvas = self._soft_clean(canvas)
        return GeneratedPattern(cells=canvas, genome=genome, label=label)

    def child_pattern(self, parent: Genome, family_id: int, max_size: int = 21) -> GeneratedPattern:
        child = parent.mutated(self.rng, strength=0.16, family_id=family_id)
        return self.generate(child, max_size=max_size)

    @staticmethod
    def _soft_clean(cells: np.ndarray) -> np.ndarray:
        n = (
            np.roll(np.roll(cells, 1, 0), 1, 1)
            + np.roll(cells, 1, 0)
            + np.roll(np.roll(cells, 1, 0), -1, 1)
            + np.roll(cells, 1, 1)
            + np.roll(cells, -1, 1)
            + np.roll(np.roll(cells, -1, 0), 1, 1)
            + np.roll(cells, -1, 0)
            + np.roll(np.roll(cells, -1, 0), -1, 1)
        )
        return cells & (n > 0)

    @staticmethod
    def _array(rows: list[str]) -> np.ndarray:
        return np.array([[ch in "#O1X" for ch in row] for row in rows], dtype=bool)

    def _build_templates(self) -> list[np.ndarray]:
        return [
            self._array([".#.", "..#", "###"]),  # glider
            self._array(["###", ".#.", ".#."]),
            self._array([".##", "##.", ".#."]),
            self._array([".###", "###."]),  # toad-like
            self._array(["##..", "##..", "..##", "..##"]),  # beacon
            self._array([".##.", "#..#", "#..#", ".##."]),
            self._array([".##...", "##....", ".#..##", "....##"]),
            self._array(["..#.....", "....#...", ".##..###"]),  # acorn-like
            self._array(["######", "#....#", "#....#", "######"]),
            self._array(["..###..", ".#...#.", "#.....#", ".#...#.", "..###.."]),
            self._array(["#..#..#", ".######", "#..#..#"]),
            self._array(["...#...", "..###..", ".#####.", "..###..", "...#..."]),
            self._array([".#.#.", "#...#", ".#.#.", "#...#", ".#.#."]),
            self._array(["###...###", "...###...", "###...###"]),
            self._array(["..##..", ".#..#.", "#....#", ".#..#.", "..##.."]),
            self._array(["#.#.#", ".###.", "#####", ".###.", "#.#.#"]),
            self._array(["...#...", "..###..", ".#####.", "###.###", ".#####.", "..###..", "...#..."]),
            self._array(["#.....#", ".#...#.", "..#.#..", "...#...", "..#.#..", ".#...#.", "#.....#"]),
            self._array(["..##..", ".####.", "##..##", ".#..#.", "##..##", ".####.", "..##.."]) ,
            self._array(["...##...", "..####..", ".##..##.", "##....##", ".##..##.", "..####..", "...##..."]),
            self._array([".#...#.", "###.###", ".#####.", "..###..", ".#####.", "###.###", ".#...#."]),
        ]
