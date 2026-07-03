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
    spine_segments: int = 0
    torso_segments: int = 0
    neck_segments: int = 0
    tail_segments: int = 0
    fin_pairs: int = 0
    arm_pairs: int = 0
    leg_pairs: int = 0
    finger_count: int = 0
    feather_level: float = 0.0
    head_size: float = 1.0
    posture: str = "amoeboid"
    emotion: str = "calm"
    desire: str = "persist"
    intelligence: float = 0.0
    speech_level: int = 0
    utterance: str = ""

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
        """Open-ended evolutionary complexity signal.

        Earlier versions normalized this to 0..1, which made organisms reach a
        visible ceiling: after becoming a complexoid, the true-3D body no longer
        had much reason to keep changing.  This score is intentionally not hard
        clamped.  It grows logarithmically with size/age/lineage so it remains
        stable for long runs while still allowing macro-organisms to continue
        differentiating over time.
        """
        size_score = math.log1p(max(0, self.size)) / 4.8
        age_score = math.log1p(max(0, self.age)) / math.log(1600.0)
        lineage_score = math.log1p(max(0, self.children)) / 2.2
        survival_score = max(0.0, float(self.score))
        motion_score = min(1.0, self.displacement / 8.0)
        stability_score = self.stability
        return max(
            0.0,
            0.32 * self.genome.complexity_drive
            + 0.25 * size_score
            + 0.22 * age_score
            + 0.12 * survival_score
            + 0.06 * lineage_score
            + 0.02 * motion_score
            + 0.01 * stability_score,
        )

    def update_traits(self) -> None:
        value = self.complexity_score
        # Much more open-ended than early versions. The multiplier is tuned so
        # long-lived successful organisms can continue accumulating morphology
        # rather than plateauing as round "complexoids". The visible mesh still
        # uses soft caps for performance, but the evolutionary state itself is
        # intentionally allowed to keep growing.
        self.complexity_level = int(max(0, min(180, math.floor((value ** 1.08) * 24.0))))
        self.metabolism = self.genome.metabolism
        growth = math.sqrt(max(0, self.complexity_level))
        self.armor = min(1.0, self.genome.armor_drive * (0.20 + 0.05 * growth))
        self.sensors = int(round(growth * self.genome.sensory_drive * 2.65))
        self.eyes = int(round(growth * self.genome.sensory_drive * 1.95))
        self.limbs = int(round(growth * self.genome.locomotion_drive * 3.15))
        self.manipulators = int(round(growth * self.genome.manipulator_drive * 2.55))
        self.trait_pulse = 0.5 + 0.5 * math.sin(self.age * 0.085 + self.id * 0.33)
        # Higher-order emergent traits for the true-3D object mode and audio.
        base_intelligence = (0.30 * self.genome.sensory_drive + 0.30 * self.genome.manipulator_drive + 0.20 * self.genome.cooperation + 0.20 * self.genome.complexity_drive)
        self.intelligence = max(0.0, min(1.75, 0.035 * self.complexity_level + base_intelligence * 0.95 + 0.0008 * self.age))
        self.spine_segments = max(0, min(16, 1 + self.complexity_level // 2))
        self.torso_segments = max(1, min(8, 1 + self.complexity_level // 3))
        self.neck_segments = max(0, min(5, self.complexity_level // 9))
        self.tail_segments = max(0, min(12, self.complexity_level // 5 + int(self.genome.locomotion_drive * 2.0)))
        self.arm_pairs = max(0, min(3, self.manipulators // 3))
        self.leg_pairs = max(0, min(4, max(1, self.limbs // 4) if self.complexity_level >= 6 else self.limbs // 5))
        self.fin_pairs = max(0, min(4, int((self.genome.expansion + self.genome.stabilization) * 2.3) if self.complexity_level >= 8 else 0))
        self.finger_count = max(0, min(8, 2 + self.manipulators // 2 if self.complexity_level >= 10 else 0))
        self.feather_level = max(0.0, min(1.0, 0.14 * max(0, self.complexity_level - 11) + 0.45 * self.genome.cooperation))
        self.head_size = 0.9 + min(2.8, 0.06 * self.complexity_level + 0.85 * self.genome.sensory_drive + 0.35 * self.genome.manipulator_drive)

        level = self.complexity_level
        if level <= 1:
            self.body_plan = "microbe"
            self.posture = "amoeboid"
        elif level <= 3:
            self.body_plan = "colony"
            self.posture = "radial"
        elif level <= 5:
            self.body_plan = "sensorium"
            self.posture = "radial"
        elif level <= 7:
            self.body_plan = "crawler"
            self.posture = "crawling"
        elif level <= 10:
            self.body_plan = "exoform"
            self.posture = "crawling"
        elif level <= 14:
            self.body_plan = "complexoid"
            self.posture = "serpentine"
        elif level <= 19:
            self.body_plan = "macroform"
            self.posture = "quadruped"
        elif level <= 25:
            self.body_plan = "elderform"
            self.posture = "quadruped"
        elif level <= 33:
            self.body_plan = "vertebraloid"
            self.posture = "quadruped"
        elif level <= 42:
            self.body_plan = "tetrapod"
            self.posture = "biped" if self.genome.manipulator_drive > 0.52 else "quadruped"
        elif level <= 54:
            self.body_plan = "bipedal"
            self.posture = "biped"
        elif level <= 68:
            self.body_plan = "aviform"
            self.posture = "avian"
        elif level <= 84:
            self.body_plan = "sophont"
            self.posture = "upright"
        else:
            self.body_plan = f"transcendent-{level}"
            self.posture = "upright"

        if self.posture in {"quadruped", "biped", "avian", "upright"}:
            self.leg_pairs = max(self.leg_pairs, 1 if self.posture == "biped" else 2)
        if self.posture in {"biped", "upright"}:
            self.arm_pairs = max(self.arm_pairs, 1)
        if self.posture == "avian":
            self.arm_pairs = max(self.arm_pairs, 1)
            self.fin_pairs = max(self.fin_pairs, 1)
            self.feather_level = max(self.feather_level, 0.45)

        # Emotional / motivational layer for sound and future text/speech.
        mood_axis = self.trait_pulse + self.genome.aggression * 0.75 + self.genome.cooperation * 0.45 - self.armor * 0.18
        if self.energy < 0.22:
            self.emotion = "hungry"
            self.desire = "feed"
        elif mood_axis > 1.28:
            self.emotion = "excited"
            self.desire = "expand"
        elif self.intelligence > 0.95 and self.genome.cooperation > 0.58:
            self.emotion = "curious"
            self.desire = "learn"
        elif self.genome.predation > 0.66:
            self.emotion = "aggressive"
            self.desire = "hunt"
        elif self.genome.cooperation > 0.64:
            self.emotion = "social"
            self.desire = "bond"
        elif self.stability > 0.76:
            self.emotion = "content"
            self.desire = "rest"
        else:
            self.emotion = "calm"
            self.desire = "persist"

        if self.intelligence < 0.25:
            self.speech_level = 0
            self.utterance = ""
        elif self.intelligence < 0.55:
            self.speech_level = 1
            self.utterance = {"feed": "mmm", "expand": "ah", "hunt": "tik", "bond": "la", "learn": "oo", "rest": "hum"}.get(self.desire, "hum")
        elif self.intelligence < 0.95:
            self.speech_level = 2
            self.utterance = {"feed": "need food", "expand": "grow", "hunt": "seek prey", "bond": "come near", "learn": "what is", "rest": "stay still", "persist": "hold form"}.get(self.desire, "hold form")
        elif self.intelligence < 1.28:
            self.speech_level = 3
            self.utterance = {"feed": "I need energy.", "expand": "I want to grow.", "hunt": "I will pursue.", "bond": "Stay with me.", "learn": "I want to learn.", "rest": "I will recover.", "persist": "I remain here."}.get(self.desire, "I remain here.")
        else:
            self.speech_level = 4
            self.utterance = {"feed": "I need more energy to continue evolving.", "expand": "I want to grow and reshape my body.", "hunt": "I am searching for weaker patterns to overtake.", "bond": "I want to remain close to my kin.", "learn": "I am observing this world and learning from it.", "rest": "I am conserving strength for the next change.", "persist": "I want to survive long enough to transform."}.get(self.desire, "I want to survive long enough to transform.")

    def mark_dead(self) -> None:
        self.alive = False
        self.energy = max(0.0, self.energy - 0.15)
