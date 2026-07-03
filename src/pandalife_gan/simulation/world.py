from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import numpy as np

from pandalife_gan.app_config import AppConfig
from pandalife_gan.ai.critic import HeuristicCritic, CriticStats
from pandalife_gan.ai.genome import Genome
from pandalife_gan.ai.pseudo_gan import PseudoGanGenerator, GeneratedPattern
from .conway import conway_step, neighbor_count
from .components import Component, find_components
from .organism import Organism


@dataclass(slots=True)
class WorldSnapshot:
    grid: np.ndarray
    age: np.ndarray
    owner: np.ndarray
    organisms: dict[int, Organism]
    critic: CriticStats
    step_index: int
    pure_conway: bool
    dead_archive_count: int = 0
    total_history_samples: int = 0
    history_limit: int = 0


class LifeWorld:
    """Simulation model: Life-like physics + organism identity + evolution."""

    def __init__(self, cfg: AppConfig, seed: int | None = None):
        self.cfg = cfg
        self.rng = np.random.default_rng(seed)
        self.generator = PseudoGanGenerator(self.rng)
        self.critic = HeuristicCritic()
        self.grid = np.zeros((cfg.grid_height, cfg.grid_width), dtype=bool)
        self.age = np.zeros_like(self.grid, dtype=np.uint16)
        self.owner = np.full(self.grid.shape, -1, dtype=np.int32)
        self.previous_owner = self.owner.copy()
        self.organisms: dict[int, Organism] = {}
        self.dead_archive: list[Organism] = []
        self.step_index = 0
        self.next_organism_id = 1
        self.next_family_id = 1
        self.pure_conway = cfg.pure_conway
        self.critic_stats = CriticStats()
        self.reset()

    def reset(self) -> None:
        self.grid.fill(False)
        self.age.fill(0)
        self.owner.fill(-1)
        self.previous_owner.fill(-1)
        self.organisms.clear()
        self.dead_archive.clear()
        self.step_index = 0
        self.next_organism_id = 1
        self.next_family_id = 1
        for _ in range(self.cfg.initial_organisms):
            self.inject_random_organism(max_size=29)
        self.previous_owner = self.owner.copy()
        self._scan_components(force=True)
        self.critic.previous_grid = None
        self.critic_stats = self.critic.evaluate_world(self.grid, len(self.organisms))
        self.prune_memory(force=True)

    def inject_random_organism(self, max_size: int = 25) -> int | None:
        family_id = self.next_family_id
        self.next_family_id += 1
        genome = self.generator.random_genome(family_id=family_id)
        pattern = self.generator.generate(genome, max_size=max_size)
        return self._place_pattern(pattern, parent_id=None)

    def inject_random_organism_at(self, x: int, y: int, max_size: int = 25) -> int | None:
        """Inject one generated organism centered near a grid coordinate."""
        family_id = self.next_family_id
        self.next_family_id += 1
        genome = self.generator.random_genome(family_id=family_id)
        pattern = self.generator.generate(genome, max_size=max_size)
        return self._place_pattern(pattern, parent_id=None, center=(int(x), int(y)))

    def inject_child_near(self, parent: Organism) -> int | None:
        family_id = parent.genome.family_id
        pattern = self.generator.child_pattern(parent.genome, family_id=family_id, max_size=19)
        px, py = parent.centroid
        offset_x = int(np.sign(parent.genome.motion_bias[0]) * self.rng.integers(8, 22))
        offset_y = int(np.sign(parent.genome.motion_bias[1]) * self.rng.integers(8, 22))
        return self._place_pattern(pattern, parent_id=parent.id, center=(int(px + offset_x), int(py + offset_y)))

    def _place_pattern(self, pattern: GeneratedPattern, parent_id: int | None, center: tuple[int, int] | None = None) -> int | None:
        cells = pattern.cells
        if not cells.any():
            return None
        h, w = self.grid.shape
        ph, pw = cells.shape
        if ph > h or pw > w:
            return None

        def _center_bounds(length: int, pattern_length: int, margin: int = 3) -> tuple[int, int]:
            # cx/cy are later converted to x0/y0 by subtracting pattern_length//2.
            # Therefore a valid center must keep the whole pattern inside the grid.
            low = pattern_length // 2 + margin
            high = length - (pattern_length - pattern_length // 2) - margin + 1
            if high <= low:
                # Small diagnostic/self-test grids may not have room for a margin.
                # Fall back to the exact legal center interval instead of failing
                # with numpy's "low >= high" ValueError.
                low = pattern_length // 2
                high = length - (pattern_length - pattern_length // 2) + 1
            return low, high

        low_x, high_x = _center_bounds(w, pw)
        low_y, high_y = _center_bounds(h, ph)
        if high_x <= low_x or high_y <= low_y:
            return None
        if center is None:
            cx = int(self.rng.integers(low_x, high_x))
            cy = int(self.rng.integers(low_y, high_y))
        else:
            cx = max(low_x, min(high_x - 1, int(center[0]) % w))
            cy = max(low_y, min(high_y - 1, int(center[1]) % h))
        x0 = cx - pw // 2
        y0 = cy - ph // 2
        region = self.grid[y0 : y0 + ph, x0 : x0 + pw]
        if np.mean(region) > 0.45:
            return None
        oid = self.next_organism_id
        self.next_organism_id += 1
        organism = Organism(
            id=oid,
            genome=pattern.genome,
            color_rgba=pattern.genome.color_rgba,
            parent_id=parent_id,
            birth_step=self.step_index,
            label=pattern.label,
        )
        self.organisms[oid] = organism
        self.grid[y0 : y0 + ph, x0 : x0 + pw] |= cells
        owner_region = self.owner[y0 : y0 + ph, x0 : x0 + pw]
        age_region = self.age[y0 : y0 + ph, x0 : x0 + pw]
        owner_region[cells] = oid
        age_region[cells] = 1
        if parent_id in self.organisms:
            self.organisms[parent_id].children += 1
        return oid

    def update(self, steps: int = 1) -> WorldSnapshot:
        for _ in range(max(1, steps)):
            self._single_step()
        return self.snapshot()

    def _single_step(self) -> None:
        self.step_index += 1
        self.previous_owner = self.owner.copy()
        next_grid, n = conway_step(self.grid)
        if not self.pure_conway:
            next_grid = self._apply_organism_bias(next_grid, n)

        self.age = np.where(next_grid, np.minimum(self.age + 1, np.iinfo(np.uint16).max), 0).astype(np.uint16)
        self.grid = next_grid
        self.owner = np.where(self.grid, self.previous_owner, -1).astype(np.int32)

        if self.step_index % self.cfg.component_scan_interval == 0:
            self._scan_components(force=False)
        else:
            self._refresh_basic_energy()
        if not self.pure_conway and self.step_index % 90 == 0:
            self._maybe_reproduce()
        if self.step_index % 5 == 0:
            self.critic_stats = self.critic.evaluate_world(self.grid, len(self.organisms))
        if self.cfg.memory_prune_interval > 0 and self.step_index % self.cfg.memory_prune_interval == 0:
            self.prune_memory(force=False)

    def _apply_organism_bias(self, next_grid: np.ndarray, n: np.ndarray) -> np.ndarray:
        if not self.organisms:
            return next_grid
        out = next_grid.copy()
        live_yx = np.argwhere(self.grid)
        if live_yx.size == 0:
            return out

        # Sparse local intervention: sample organism boundary cells. This keeps the
        # world Life-like and avoids arbitrary full-map overwrites.
        for organism in list(self.organisms.values()):
            if not organism.alive or organism.size <= 0:
                continue
            if organism.energy <= 0.06:
                continue
            oyx = np.argwhere((self.owner == organism.id) & self.grid)
            if oyx.size == 0:
                continue
            sample_count = min(64, max(4, oyx.shape[0] // max(5, 14 - organism.complexity_level * 2) + organism.sensors + organism.limbs))
            picks = oyx[self.rng.choice(oyx.shape[0], size=sample_count, replace=oyx.shape[0] < sample_count)]
            for y, x in picks:
                # Motion-biased local direction.
                mx, my = organism.genome.motion_bias
                dx = int(np.sign(mx)) if self.rng.random() < abs(mx) * 0.55 else int(self.rng.integers(-1, 2))
                dy = int(np.sign(my)) if self.rng.random() < abs(my) * 0.55 else int(self.rng.integers(-1, 2))
                if dx == 0 and dy == 0:
                    dx = int(self.rng.choice([-1, 1]))
                ny = (int(y) + dy) % self.grid.shape[0]
                nx = (int(x) + dx) % self.grid.shape[1]

                if not self.grid[ny, nx] and n[ny, nx] == 2:
                    action_bonus = 1.0 + 0.10 * organism.limbs + 0.08 * organism.manipulators
                    if self.rng.random() < min(0.55, organism.genome.expansion * organism.energy * organism.metabolism * action_bonus):
                        out[ny, nx] = True
                        organism.energy = max(0.0, organism.energy - 0.002 * organism.metabolism)
                elif self.grid[ny, nx] and not out[ny, nx] and n[ny, nx] in (1, 4):
                    armor_bonus = 1.0 + organism.armor * 1.5 + 0.08 * organism.sensors
                    if self.rng.random() < min(0.55, organism.genome.stabilization * organism.energy * armor_bonus):
                        out[ny, nx] = True
                        organism.energy = max(0.0, organism.energy - 0.0015 * max(0.25, 1.0 - organism.armor))

            # Rare spore birth near stronger long-lived organisms.
            if organism.age > 180 and organism.energy > 0.38 and len(self.organisms) < self.cfg.max_organisms:
                if self.rng.random() < organism.genome.spore_rate * min(1.0, organism.score + 0.15):
                    self.inject_child_near(organism)
                    organism.energy = max(0.0, organism.energy - 0.08)

        return out

    def _scan_components(self, force: bool = False) -> None:
        comps = find_components(self.grid, min_size=self.cfg.min_tracked_cells)
        assigned: dict[int, np.ndarray] = {}
        new_owner = np.full(self.grid.shape, -1, dtype=np.int32)
        seen_ids: set[int] = set()

        for comp in comps[: self.cfg.max_organisms * 2]:
            oid = self._match_component(comp, seen_ids)
            if oid is None:
                oid = self._create_organism_from_component(comp)
            if oid is None:
                continue
            seen_ids.add(oid)
            y = comp.cells_yx[:, 0]
            x = comp.cells_yx[:, 1]
            new_owner[y, x] = oid
            assigned[oid] = comp.cells_yx

        self.owner = np.where(self.grid, new_owner, -1).astype(np.int32)

        # Update organism observations and mark missing organisms as dead.
        for oid, org in list(self.organisms.items()):
            if oid in assigned:
                org.alive = True
                org.update_observation(assigned[oid], self.step_index)
                self._trim_organism_history(org)
                org.update_traits()
                drain = org.size / self.grid.size * 0.018 * org.metabolism * max(0.35, 1.0 - org.armor * 0.55)
                trait_bonus = 0.0015 * org.sensors + 0.001 * org.manipulators
                org.energy = max(0.0, min(1.0, org.energy + 0.005 + org.stability * 0.003 + trait_bonus - drain))
                org.score = HeuristicCritic.evaluate_organism(org.size, org.age, org.energy, org.displacement)
            else:
                if self.step_index - org.last_seen_step > 18 or force:
                    org.mark_dead()
                    self._archive_dead_organism(org)
                    del self.organisms[oid]

        # Limit very tiny debris identity spam.
        if len(self.organisms) > self.cfg.max_organisms:
            keep = sorted(self.organisms.values(), key=lambda o: (o.score, o.size), reverse=True)[: self.cfg.max_organisms]
            keep_ids = {o.id for o in keep}
            for oid in list(self.organisms):
                if oid not in keep_ids:
                    self.organisms[oid].mark_dead()
                    self._archive_dead_organism(self.organisms[oid])
                    del self.organisms[oid]
            self.owner = np.where(np.isin(self.owner, list(keep_ids)), self.owner, -1)

    def _match_component(self, comp: Component, used_ids: set[int]) -> int | None:
        y = comp.cells_yx[:, 0]
        x = comp.cells_yx[:, 1]
        prev = self.previous_owner[y, x]
        prev = prev[prev > 0]
        if prev.size:
            ids, counts = np.unique(prev, return_counts=True)
            order = np.argsort(counts)[::-1]
            for idx in order:
                oid = int(ids[idx])
                if oid in self.organisms and oid not in used_ids:
                    return oid
            # Split: create child from dominant parent if original already used.
            parent_id = int(ids[order[0]])
            if parent_id in self.organisms and comp.size >= self.cfg.min_tracked_cells:
                return self._create_child_identity(parent_id)

        # Fallback: nearest centroid among unused organisms.
        cx, cy = comp.centroid_xy
        best: tuple[float, int] | None = None
        for oid, org in self.organisms.items():
            if oid in used_ids:
                continue
            dx = org.centroid[0] - cx
            dy = org.centroid[1] - cy
            dist = dx * dx + dy * dy
            if dist < 100.0 and (best is None or dist < best[0]):
                best = (dist, oid)
        return best[1] if best else None

    def _create_child_identity(self, parent_id: int) -> int | None:
        parent = self.organisms.get(parent_id)
        if parent is None:
            return None
        oid = self.next_organism_id
        self.next_organism_id += 1
        genome = parent.genome.mutated(self.rng, strength=0.08, family_id=parent.genome.family_id)
        child = Organism(
            id=oid,
            genome=genome,
            color_rgba=genome.color_rgba,
            parent_id=parent_id,
            birth_step=self.step_index,
            label="split-child",
        )
        self.organisms[oid] = child
        parent.children += 1
        return oid

    def _create_organism_from_component(self, comp: Component) -> int | None:
        if len(self.organisms) >= self.cfg.max_organisms:
            return None
        oid = self.next_organism_id
        self.next_organism_id += 1
        family_id = self.next_family_id
        self.next_family_id += 1
        genome = self.generator.random_genome(family_id=family_id)
        org = Organism(
            id=oid,
            genome=genome,
            color_rgba=genome.color_rgba,
            parent_id=None,
            birth_step=self.step_index,
            label="emergent",
        )
        self.organisms[oid] = org
        return oid

    def _refresh_basic_energy(self) -> None:
        for org in self.organisms.values():
            org.age += 1
            org.update_traits()
            drain = org.size / self.grid.size * 0.01 * org.metabolism * max(0.35, 1.0 - org.armor * 0.55)
            org.energy = max(0.0, min(1.0, org.energy + 0.0015 + 0.0008 * org.sensors - drain))

    def _maybe_reproduce(self) -> None:
        if len(self.organisms) >= self.cfg.max_organisms:
            return
        candidates = [o for o in self.organisms.values() if o.alive and o.age > 220 and o.score > 0.38 and o.energy > 0.42]
        if not candidates:
            return
        candidates.sort(key=lambda o: o.score + o.energy, reverse=True)
        for organism in candidates[:3]:
            if self.rng.random() < 0.08 + organism.genome.spore_rate + 0.012 * organism.complexity_level:
                self.inject_child_near(organism)
                organism.energy = max(0.0, organism.energy - 0.18)

    def _trim_organism_history(self, org: Organism) -> None:
        limit = int(max(0, self.cfg.organism_history_limit))
        if limit <= 0:
            org.history_sizes.clear()
        elif len(org.history_sizes) > limit:
            del org.history_sizes[:-limit]

    def _archive_dead_organism(self, org: Organism) -> None:
        self._trim_organism_history(org)
        self.dead_archive.append(org)
        self._trim_dead_archive()

    def _trim_dead_archive(self) -> None:
        limit = int(max(0, self.cfg.dead_archive_limit))
        if limit <= 0:
            self.dead_archive.clear()
            return
        if len(self.dead_archive) <= limit:
            return
        # Keep useful evolutionary memory: high score/long life/recently seen organisms.
        self.dead_archive.sort(key=lambda o: (o.score, o.age, o.last_seen_step), reverse=True)
        del self.dead_archive[limit:]

    def prune_memory(self, force: bool = False) -> dict[str, int]:
        """Bound history/archive memory while preserving useful evolution traces."""
        for org in self.organisms.values():
            self._trim_organism_history(org)
        for org in self.dead_archive:
            self._trim_organism_history(org)
        self._trim_dead_archive()
        return self.memory_stats()

    def memory_stats(self) -> dict[str, int]:
        live_history = sum(len(o.history_sizes) for o in self.organisms.values())
        archived_history = sum(len(o.history_sizes) for o in self.dead_archive)
        return {
            "organisms": len(self.organisms),
            "dead_archive": len(self.dead_archive),
            "live_history_samples": int(live_history),
            "archived_history_samples": int(archived_history),
            "total_history_samples": int(live_history + archived_history),
            "history_limit": int(self.cfg.organism_history_limit),
            "dead_archive_limit": int(self.cfg.dead_archive_limit),
        }

    def toggle_pure_conway(self) -> bool:
        self.pure_conway = not self.pure_conway
        return self.pure_conway

    def snapshot(self) -> WorldSnapshot:
        return WorldSnapshot(
            grid=self.grid.copy(),
            age=self.age.copy(),
            owner=self.owner.copy(),
            organisms=dict(self.organisms),
            critic=self.critic_stats,
            step_index=self.step_index,
            pure_conway=self.pure_conway,
            dead_archive_count=len(self.dead_archive),
            total_history_samples=self.memory_stats()["total_history_samples"],
            history_limit=int(self.cfg.organism_history_limit),
        )
