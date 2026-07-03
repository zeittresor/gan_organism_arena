from __future__ import annotations

from dataclasses import dataclass

import numpy as np


@dataclass(slots=True)
class CriticStats:
    density: float = 0.0
    activity: float = 0.0
    entropy: float = 0.0
    organism_count: int = 0
    living_cells: int = 0
    score: float = 0.0


class HeuristicCritic:
    """Lightweight critic for GAN-style evaluation.

    A real discriminator can be plugged in later. For now this gives useful
    feedback for visual selection and evolution.
    """

    def __init__(self):
        self.previous_grid: np.ndarray | None = None

    def evaluate_world(self, grid: np.ndarray, organism_count: int) -> CriticStats:
        living = int(grid.sum())
        total = int(grid.size)
        density = living / max(1, total)
        if self.previous_grid is None or self.previous_grid.shape != grid.shape:
            activity = 0.0
        else:
            activity = float(np.mean(grid != self.previous_grid))

        p = min(max(density, 1e-6), 1.0 - 1e-6)
        entropy = float(-(p * np.log2(p) + (1 - p) * np.log2(1 - p)))
        density_score = 1.0 - min(1.0, abs(density - 0.18) / 0.18)
        activity_score = 1.0 - min(1.0, abs(activity - 0.08) / 0.16)
        count_score = min(1.0, organism_count / 36.0)
        score = 0.42 * density_score + 0.35 * activity_score + 0.15 * entropy + 0.08 * count_score
        self.previous_grid = grid.copy()
        return CriticStats(density, activity, entropy, organism_count, living, float(score))

    @staticmethod
    def evaluate_organism(size: int, age: int, energy: float, displacement: float) -> float:
        size_score = min(1.0, size / 180.0)
        age_score = min(1.0, age / 900.0)
        move_score = min(1.0, displacement / 8.0)
        return float(0.36 * size_score + 0.32 * age_score + 0.20 * energy + 0.12 * move_score)
