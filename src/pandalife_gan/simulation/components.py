from __future__ import annotations

from dataclasses import dataclass
from collections import deque

import numpy as np


@dataclass(slots=True)
class Component:
    cells_yx: np.ndarray
    bbox: tuple[int, int, int, int]
    owner_hint: int | None = None

    @property
    def size(self) -> int:
        return int(self.cells_yx.shape[0])

    @property
    def centroid_xy(self) -> tuple[float, float]:
        if self.size == 0:
            return (0.0, 0.0)
        return float(np.mean(self.cells_yx[:, 1])), float(np.mean(self.cells_yx[:, 0]))


def find_components(grid: np.ndarray, min_size: int = 3) -> list[Component]:
    """Find 8-neighbor connected live components.

    This intentionally does not wrap at edges. For visual organism identity, that
    is less surprising than toroidal object tracking.
    """

    h, w = grid.shape
    visited = np.zeros_like(grid, dtype=bool)
    live_positions = np.argwhere(grid)
    components: list[Component] = []
    neighbors = [
        (-1, -1), (-1, 0), (-1, 1),
        (0, -1),           (0, 1),
        (1, -1),  (1, 0),  (1, 1),
    ]

    for sy, sx in live_positions:
        sy_i = int(sy)
        sx_i = int(sx)
        if visited[sy_i, sx_i]:
            continue
        queue: deque[tuple[int, int]] = deque([(sy_i, sx_i)])
        visited[sy_i, sx_i] = True
        cells: list[tuple[int, int]] = []
        min_y = max_y = sy_i
        min_x = max_x = sx_i

        while queue:
            y, x = queue.popleft()
            cells.append((y, x))
            if y < min_y:
                min_y = y
            if y > max_y:
                max_y = y
            if x < min_x:
                min_x = x
            if x > max_x:
                max_x = x
            for dy, dx in neighbors:
                ny = y + dy
                nx = x + dx
                if ny < 0 or ny >= h or nx < 0 or nx >= w:
                    continue
                if visited[ny, nx] or not grid[ny, nx]:
                    continue
                visited[ny, nx] = True
                queue.append((ny, nx))

        if len(cells) >= min_size:
            components.append(
                Component(
                    cells_yx=np.array(cells, dtype=np.int16),
                    bbox=(min_x, min_y, max_x, max_y),
                )
            )

    components.sort(key=lambda c: c.size, reverse=True)
    return components
