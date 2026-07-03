from __future__ import annotations

import numpy as np


def neighbor_count(grid: np.ndarray) -> np.ndarray:
    g = grid.astype(np.uint8, copy=False)
    return (
        np.roll(np.roll(g, 1, 0), 1, 1)
        + np.roll(g, 1, 0)
        + np.roll(np.roll(g, 1, 0), -1, 1)
        + np.roll(g, 1, 1)
        + np.roll(g, -1, 1)
        + np.roll(np.roll(g, -1, 0), 1, 1)
        + np.roll(g, -1, 0)
        + np.roll(np.roll(g, -1, 0), -1, 1)
    )


def conway_step(grid: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    n = neighbor_count(grid)
    alive = grid
    survive = alive & ((n == 2) | (n == 3))
    born = (~alive) & (n == 3)
    return survive | born, n
