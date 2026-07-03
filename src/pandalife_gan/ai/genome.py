from __future__ import annotations

from dataclasses import dataclass
import colorsys
import math
from typing import Iterable

import numpy as np


@dataclass(slots=True)
class Genome:
    """Compact per-organism latent vector.

    This is the lightweight substitute for a full per-organism GAN. A shared
    generator interprets the genome to create morphology and behavior.

    v0.1.x used a 16-dimensional vector. v0.1.3 expands this to 24 dimensions
    for visible evolutionary traits. Helper accessors keep older saved vectors
    safe if they are ever loaded later.
    """

    vector: np.ndarray
    generation: int = 0
    family_id: int = 0

    def _v(self, index: int, default: float = 0.0) -> float:
        if index < int(self.vector.shape[0]):
            return float(self.vector[index])
        return default

    @property
    def expansion(self) -> float:
        return float(0.02 + 0.14 * self._sigmoid(self._v(0)))

    @property
    def stabilization(self) -> float:
        return float(0.02 + 0.12 * self._sigmoid(self._v(1)))

    @property
    def spore_rate(self) -> float:
        return float(0.002 + 0.025 * self._sigmoid(self._v(2)))

    @property
    def aggression(self) -> float:
        return float(self._sigmoid(self._v(3)))

    @property
    def symmetry(self) -> float:
        return float(self._sigmoid(self._v(4)))

    @property
    def density_preference(self) -> float:
        return float(0.12 + 0.32 * self._sigmoid(self._v(5)))

    @property
    def motion_bias(self) -> tuple[float, float]:
        return (float(math.tanh(self._v(6))), float(math.tanh(self._v(7))))

    @property
    def sensory_drive(self) -> float:
        return float(self._sigmoid(self._v(16)))

    @property
    def locomotion_drive(self) -> float:
        return float(self._sigmoid(self._v(17)))

    @property
    def manipulator_drive(self) -> float:
        return float(self._sigmoid(self._v(18)))

    @property
    def armor_drive(self) -> float:
        return float(self._sigmoid(self._v(19)))

    @property
    def metabolism(self) -> float:
        # Low metabolism conserves energy; high metabolism allows faster action.
        return float(0.55 + 0.95 * self._sigmoid(self._v(20)))

    @property
    def complexity_drive(self) -> float:
        return float(self._sigmoid(self._v(21)))

    @property
    def cooperation(self) -> float:
        return float(self._sigmoid(self._v(22)))

    @property
    def predation(self) -> float:
        return float(self._sigmoid(self._v(23)))

    @property
    def color_rgba(self) -> tuple[int, int, int, int]:
        hue = float((self._v(8) * 0.137 + self.family_id * 0.071) % 1.0)
        sat = 0.58 + 0.35 * self._sigmoid(self._v(9))
        val = 0.55 + 0.40 * self._sigmoid(self._v(10))
        r, g, b = colorsys.hsv_to_rgb(hue, sat, val)
        return int(r * 255), int(g * 255), int(b * 255), 255

    @staticmethod
    def _sigmoid(x: float) -> float:
        return 1.0 / (1.0 + math.exp(-float(x)))

    @classmethod
    def random(cls, rng: np.random.Generator, family_id: int = 0) -> "Genome":
        return cls(vector=rng.normal(0.0, 1.0, 24).astype(np.float32), generation=0, family_id=family_id)

    def mutated(self, rng: np.random.Generator, strength: float = 0.18, family_id: int | None = None) -> "Genome":
        child = self.vector + rng.normal(0.0, strength, self.vector.shape).astype(np.float32)
        return Genome(
            vector=child.astype(np.float32),
            generation=self.generation + 1,
            family_id=self.family_id if family_id is None else family_id,
        )

    @classmethod
    def blend(cls, parents: Iterable["Genome"], rng: np.random.Generator, family_id: int) -> "Genome":
        parent_list = list(parents)
        if not parent_list:
            return cls.random(rng, family_id=family_id)
        max_len = max(int(p.vector.shape[0]) for p in parent_list)
        padded = []
        for p in parent_list:
            if int(p.vector.shape[0]) == max_len:
                padded.append(p.vector)
            else:
                arr = np.zeros(max_len, dtype=np.float32)
                arr[: p.vector.shape[0]] = p.vector
                padded.append(arr)
        base = np.mean(padded, axis=0).astype(np.float32)
        noise = rng.normal(0.0, 0.12, base.shape).astype(np.float32)
        return cls(base + noise, generation=max(p.generation for p in parent_list) + 1, family_id=family_id)
