from __future__ import annotations

from dataclasses import dataclass, field
import math

import numpy as np

from pandalife_gan.ai.genome import Genome


@dataclass(slots=True)
class Organism:
    id: int
    genome: Genome
    color_rgba: tuple[int, int, int, int]
    parent_id: int | None = None
    age: int = 0
    energy: float = 1.0
    score: float = 0.0
    alive: bool = True
    size: int = 0
    centroid: tuple[float, float] = (0.0, 0.0)
    previous_centroid: tuple[float, float] = (0.0, 0.0)
    last_seen_step: int = 0
    birth_step: int = 0
    children: int = 0
    label: str = "organism"
    history_sizes: list[int] = field(default_factory=list)

    # Abstract evolutionary traits. These do not turn Life into a creature
    # animation system yet; they are visible/behavioural traits for digital
    # lifeforms inside the cellular world.
    complexity_level: int = 0
    body_plan: str = "microbe"
    eyes: int = 0
    limbs: int = 0
    manipulators: int = 0
    sensors: int = 0
    armor: float = 0.0
    metabolism: float = 1.0
    trait_pulse: float = 0.0

    def update_observation(self, cells_yx: np.ndarray, step_index: int) -> None:
        self.age += 1
        self.last_seen_step = step_index
        self.size = int(cells_yx.shape[0])
        self.previous_centroid = self.centroid
        if self.size:
            y = float(np.mean(cells_yx[:, 0]))
            x = float(np.mean(cells_yx[:, 1]))
            self.centroid = (x, y)
        self.history_sizes.append(self.size)
        if len(self.history_sizes) > 5000:
            del self.history_sizes[:-5000]
        self.update_traits()

    @property
    def displacement(self) -> float:
        dx = self.centroid[0] - self.previous_centroid[0]
        dy = self.centroid[1] - self.previous_centroid[1]
        return float((dx * dx + dy * dy) ** 0.5)

    @property
    def stability(self) -> float:
        if len(self.history_sizes) < 6:
            return 0.5
        arr = np.array(self.history_sizes[-60:], dtype=np.float32)
        mean = float(np.mean(arr))
        if mean <= 1.0:
            return 0.0
        return float(max(0.0, 1.0 - min(1.0, float(np.std(arr)) / mean)))

    @property
    def complexity_score(self) -> float:
        size_score = min(1.0, math.log1p(max(0, self.size)) / 5.2)
        age_score = min(1.0, self.age / 1100.0)
        lineage_score = min(1.0, self.children / 7.0)
        survival_score = max(0.0, min(1.0, self.score))
        return max(
            0.0,
            min(
                1.0,
                0.30 * self.genome.complexity_drive
                + 0.22 * size_score
                + 0.22 * age_score
                + 0.16 * survival_score
                + 0.10 * lineage_score,
            ),
        )

    def update_traits(self) -> None:
        value = self.complexity_score
        self.complexity_level = int(max(0, min(5, math.floor(value * 6.0))))
        self.metabolism = self.genome.metabolism
        self.armor = min(1.0, self.genome.armor_drive * (0.20 + 0.16 * self.complexity_level))
        self.sensors = int(round(self.complexity_level * self.genome.sensory_drive * 1.35))
        self.eyes = int(round(self.complexity_level * self.genome.sensory_drive * 1.10))
        self.limbs = int(round(self.complexity_level * self.genome.locomotion_drive * 1.60))
        self.manipulators = int(round(self.complexity_level * self.genome.manipulator_drive * 1.20))
        self.trait_pulse = 0.5 + 0.5 * math.sin(self.age * 0.085 + self.id * 0.33)
        if self.complexity_level <= 0:
            self.body_plan = "microbe"
        elif self.complexity_level == 1:
            self.body_plan = "colony"
        elif self.complexity_level == 2:
            self.body_plan = "sensorium"
        elif self.complexity_level == 3:
            self.body_plan = "crawler"
        elif self.complexity_level == 4:
            self.body_plan = "exoform"
        else:
            self.body_plan = "complexoid"

    def mark_dead(self) -> None:
        self.alive = False
        self.energy = max(0.0, self.energy - 0.15)
