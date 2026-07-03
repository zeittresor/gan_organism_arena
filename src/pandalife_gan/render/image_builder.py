from __future__ import annotations

import math
import numpy as np

from pandalife_gan.simulation.world import WorldSnapshot


class ImageBuilder:
    """Converts simulation state to an RGBA texture."""

    MODE_NAMES = [
        "Classic",
        "Age Glow",
        "Energy",
        "Family",
        "Traits",
        "Thermal",
        "Ghost",
        "Critic Heat",
    ]

    def __init__(self):
        self.mode = 0
        self.show_critic_overlay = False

    @property
    def mode_name(self) -> str:
        return self.MODE_NAMES[self.mode % len(self.MODE_NAMES)]

    def next_mode(self, mode: int | None = None) -> int:
        if mode is None:
            self.mode = (self.mode + 1) % len(self.MODE_NAMES)
        else:
            self.mode = int(mode) % len(self.MODE_NAMES)
        return self.mode

    def build_rgba(self, snap: WorldSnapshot) -> np.ndarray:
        h, w = snap.grid.shape
        rgba = np.zeros((h, w, 4), dtype=np.uint8)
        rgba[..., 3] = 255
        rgba[..., 0:3] = 3

        mode = self.mode % len(self.MODE_NAMES)
        if mode == 0:
            self._classic(rgba, snap)
        elif mode == 1:
            self._age(rgba, snap)
        elif mode == 2:
            self._energy(rgba, snap)
        elif mode == 3:
            self._family(rgba, snap)
        elif mode == 4:
            self._traits(rgba, snap)
        elif mode == 5:
            self._thermal(rgba, snap)
        elif mode == 6:
            self._ghost(rgba, snap)
        else:
            self._critic_heat(rgba, snap)

        if self.show_critic_overlay:
            self._critic_overlay(rgba, snap)
        return rgba

    @staticmethod
    def _classic(rgba: np.ndarray, snap: WorldSnapshot) -> None:
        live = snap.grid
        owner = snap.owner
        age = snap.age.astype(np.float32)
        brightness = np.clip(0.45 + np.log1p(age) / 5.8, 0.45, 1.35)
        for oid, org in snap.organisms.items():
            mask = live & (owner == oid)
            if not mask.any():
                continue
            color = np.array(org.color_rgba[:3], dtype=np.float32)
            rgba[mask, 0:3] = np.clip(color * brightness[mask, None], 0, 255).astype(np.uint8)
        unknown = live & (owner <= 0)
        rgba[unknown, 0:3] = np.array([230, 230, 210], dtype=np.uint8)

    @staticmethod
    def _age(rgba: np.ndarray, snap: WorldSnapshot) -> None:
        live = snap.grid
        age = np.clip(np.log1p(snap.age.astype(np.float32)) / np.log(800.0), 0.0, 1.0)
        rgba[live, 0] = np.clip(40 + age[live] * 190, 0, 255).astype(np.uint8)
        rgba[live, 1] = np.clip(110 + (1.0 - np.abs(age[live] - 0.5) * 2.0) * 130, 0, 255).astype(np.uint8)
        rgba[live, 2] = np.clip(255 - age[live] * 210, 0, 255).astype(np.uint8)

    @staticmethod
    def _energy(rgba: np.ndarray, snap: WorldSnapshot) -> None:
        live = snap.grid
        owner = snap.owner
        rgba[live, 0:3] = np.array([120, 120, 120], dtype=np.uint8)
        for oid, org in snap.organisms.items():
            mask = live & (owner == oid)
            if not mask.any():
                continue
            e = max(0.0, min(1.0, org.energy))
            base = np.array(org.color_rgba[:3], dtype=np.float32)
            highlight = np.array([255, 255, 255], dtype=np.float32)
            color = base * (0.30 + e * 0.75) + highlight * (0.10 * e)
            rgba[mask, 0:3] = np.clip(color, 0, 255).astype(np.uint8)

    @staticmethod
    def _family(rgba: np.ndarray, snap: WorldSnapshot) -> None:
        live = snap.grid
        owner = snap.owner
        for oid, org in snap.organisms.items():
            mask = live & (owner == oid)
            if not mask.any():
                continue
            fam = org.genome.family_id
            # deterministic family colour independent from individual mutations
            hue = (fam * 0.071 + 0.19) % 1.0
            r, g, b = ImageBuilder._hsv_byte(hue, 0.74, 0.84 + 0.12 * org.energy)
            rgba[mask, 0:3] = np.array([r, g, b], dtype=np.uint8)
        rgba[live & (owner <= 0), 0:3] = np.array([200, 200, 190], dtype=np.uint8)

    @staticmethod
    def _traits(rgba: np.ndarray, snap: WorldSnapshot) -> None:
        ImageBuilder._classic(rgba, snap)
        for org in snap.organisms.values():
            if org.size <= 0 or org.complexity_level <= 0:
                continue
            x = int(round(org.centroid[0]))
            y = int(round(org.centroid[1]))
            base = np.array(org.color_rgba[:3], dtype=np.uint8)
            glow = np.array([255, 255, 235], dtype=np.uint8)
            shell = np.array([190, 230, 255], dtype=np.uint8)
            # Shell/armor ring.
            if org.armor > 0.20:
                radius = max(2, 1 + org.complexity_level)
                ImageBuilder._draw_ring(rgba, x, y, radius, shell)
            # Eyes/sensors in movement direction.
            mx, my = org.genome.motion_bias
            dx = 1 if mx >= 0 else -1
            dy = 1 if my >= 0 else -1
            for i in range(max(0, org.eyes)):
                off = i - (org.eyes - 1) / 2.0
                ImageBuilder._paint(rgba, x + dx * 2 + int(off), y + dy * 2, glow)
            # Limbs/arms as small radial traces.
            limb_count = max(org.limbs, org.manipulators)
            for i in range(limb_count):
                ang = (i / max(1, limb_count)) * math.tau + org.id * 0.41
                length = 2 + min(4, org.complexity_level)
                for j in range(1, length + 1):
                    lx = x + int(round(math.cos(ang) * j))
                    ly = y + int(round(math.sin(ang) * j))
                    c = np.clip(base.astype(np.int16) + 70, 0, 255).astype(np.uint8)
                    ImageBuilder._paint(rgba, lx, ly, c)
            # Core marker encodes complexity level.
            core = np.array([255, max(70, 240 - org.complexity_level * 25), 80 + org.complexity_level * 25], dtype=np.uint8)
            ImageBuilder._paint(rgba, x, y, core)

    @staticmethod
    def _thermal(rgba: np.ndarray, snap: WorldSnapshot) -> None:
        live = snap.grid
        owner = snap.owner
        age = np.clip(np.log1p(snap.age.astype(np.float32)) / np.log(900.0), 0.0, 1.0)
        rgba[live, 0] = np.clip(50 + 205 * age[live], 0, 255).astype(np.uint8)
        mid = np.clip(1.0 - np.abs(age[live] - 0.55) * 1.8, 0.0, 1.0)
        rgba[live, 1] = np.clip(30 + 190 * mid, 0, 255).astype(np.uint8)
        rgba[live, 2] = np.clip(30 + 80 * (1.0 - age[live]), 0, 255).astype(np.uint8)
        for oid, org in snap.organisms.items():
            if org.complexity_level <= 0:
                continue
            mask = live & (owner == oid)
            rgba[mask, 2] = np.clip(rgba[mask, 2].astype(np.int16) + 20 * org.complexity_level, 0, 255).astype(np.uint8)

    @staticmethod
    def _ghost(rgba: np.ndarray, snap: WorldSnapshot) -> None:
        live = snap.grid
        age = np.clip(np.log1p(snap.age.astype(np.float32)) / np.log(650.0), 0.0, 1.0)
        rgba[..., 0:3] = np.array([4, 7, 12], dtype=np.uint8)
        rgba[live, 0] = np.clip(50 + 80 * age[live], 0, 255).astype(np.uint8)
        rgba[live, 1] = np.clip(90 + 140 * age[live], 0, 255).astype(np.uint8)
        rgba[live, 2] = np.clip(120 + 120 * (1.0 - age[live] * 0.3), 0, 255).astype(np.uint8)

    @staticmethod
    def _critic_heat(rgba: np.ndarray, snap: WorldSnapshot) -> None:
        live = snap.grid
        owner = snap.owner
        rgba[..., 0:3] = np.array([7, 3, 4], dtype=np.uint8)
        for oid, org in snap.organisms.items():
            mask = live & (owner == oid)
            if not mask.any():
                continue
            heat = max(0.0, min(1.0, org.score * 0.75 + org.energy * 0.25))
            rgba[mask, 0] = np.uint8(60 + 190 * heat)
            rgba[mask, 1] = np.uint8(20 + 180 * (1.0 - abs(heat - 0.5) * 2.0))
            rgba[mask, 2] = np.uint8(35 + 110 * (1.0 - heat))
        rgba[live & (owner <= 0), 0:3] = np.array([160, 110, 80], dtype=np.uint8)

    @staticmethod
    def _critic_overlay(rgba: np.ndarray, snap: WorldSnapshot) -> None:
        # Minimal unobtrusive overlay: stripe at top encodes world critic score.
        h, w, _ = rgba.shape
        stripe_h = max(2, h // 80)
        score = max(0.0, min(1.0, snap.critic.score))
        active_w = int(w * score)
        rgba[:stripe_h, :, 0:3] = np.array([40, 20, 20], dtype=np.uint8)
        rgba[:stripe_h, :active_w, 0:3] = np.array([60, 230, 130], dtype=np.uint8)

    @staticmethod
    def _paint(rgba: np.ndarray, x: int, y: int, color: np.ndarray) -> None:
        h, w, _ = rgba.shape
        if 0 <= x < w and 0 <= y < h:
            rgba[y, x, 0:3] = color

    @staticmethod
    def _draw_ring(rgba: np.ndarray, x: int, y: int, radius: int, color: np.ndarray) -> None:
        for dy in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                d = dx * dx + dy * dy
                if radius * radius - radius <= d <= radius * radius + radius:
                    ImageBuilder._paint(rgba, x + dx, y + dy, color)

    @staticmethod
    def _hsv_byte(h: float, s: float, v: float) -> tuple[int, int, int]:
        import colorsys

        r, g, b = colorsys.hsv_to_rgb(h % 1.0, max(0.0, min(1.0, s)), max(0.0, min(1.0, v)))
        return int(r * 255), int(g * 255), int(b * 255)
