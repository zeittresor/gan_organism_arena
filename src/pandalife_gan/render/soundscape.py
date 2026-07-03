from __future__ import annotations

import logging
import math
import wave
from pathlib import Path
from typing import Any

import numpy as np

from pandalife_gan.simulation.organism import Organism

LOG = logging.getLogger(__name__)


class OrganismSoundscape:
    """Small optional organism sound layer using Panda3D's built-in SFX API.

    The simulation must remain fully usable without audio hardware, so every
    audio operation is best-effort and never raises out of the class.
    """

    SCALE_RATIOS = [1.0, 9 / 8, 5 / 4, 3 / 2, 5 / 3, 2.0]
    MELODY_PATTERNS = [
        [0, 2, 4, 3],
        [0, 3, 4, 5],
        [2, 4, 5, 4],
        [0, 1, 3, 4],
        [3, 4, 2, 0],
        [4, 5, 3, 2],
        [0, 2, 3, 5],
        [1, 3, 5, 4],
        [2, 0, 3, 4],
        [5, 4, 2, 3],
        [0, 4, 3, 2],
        [3, 5, 4, 1],
    ]

    def __init__(self, base: Any, output_dir: Path | str = Path("assets/generated_audio")) -> None:
        self.base = base
        self.output_dir = Path(output_dir)
        self.enabled = False
        self.master_volume = 0.45
        self.max_voices = 6
        self.update_interval = 0.55
        self._accumulator = 0.0
        self._generated = False
        self._melody_files: list[Path] = []
        self._sound_pool: dict[int, Any] = {}
        self._active_org_to_melody: dict[int, int] = {}
        self._playing_melodies: set[int] = set()
        self.available = True

    def set_enabled(self, enabled: bool) -> None:
        self.enabled = bool(enabled)
        LOG.info("Organism soundscape enabled=%s", self.enabled)
        if not self.enabled:
            self.stop_all()
        elif self.enabled:
            self._ensure_assets_and_pool()

    def set_volume(self, volume: float) -> None:
        self.master_volume = max(0.0, min(1.0, float(volume)))
        LOG.info("Organism soundscape volume=%.2f", self.master_volume)

    def set_max_voices(self, voices: int) -> None:
        self.max_voices = max(1, min(12, int(voices)))
        LOG.info("Organism soundscape max voices=%s", self.max_voices)

    def update(self, organisms: dict[int, Organism], dt: float) -> None:
        if not self.enabled or not self.available:
            return
        self._accumulator += dt
        if self._accumulator < self.update_interval:
            return
        self._accumulator = 0.0
        try:
            self._ensure_assets_and_pool()
            ranked = sorted(
                organisms.values(),
                key=lambda o: self._importance(o),
                reverse=True,
            )[: self.max_voices]
            active_ids = {o.id for o in ranked}
            for oid in list(self._active_org_to_melody):
                if oid not in active_ids:
                    melody_index = self._active_org_to_melody.pop(oid)
                    self._stop_sound(melody_index)

            for rank, organism in enumerate(ranked):
                melody_index = self._melody_index_for(organism)
                self._active_org_to_melody[organism.id] = melody_index
                sound = self._sound_pool.get(melody_index)
                if sound is None:
                    continue
                importance = self._importance(organism)
                # Louder for meaning/fitness, but gently reduced by rank so the
                # top organism does not drown the ecosystem.
                volume = self.master_volume * (0.10 + 0.72 * importance) * (0.92 ** rank)
                volume = max(0.0, min(0.85, volume))
                try:
                    sound.setVolume(volume)
                    if hasattr(sound, "setBalance"):
                        # Centroid x creates a subtle stereo position.
                        width = max(1.0, getattr(getattr(self.base, "cfg", None), "grid_width", 192))
                        balance = max(-0.95, min(0.95, (organism.centroid[0] / width) * 2.0 - 1.0))
                        sound.setBalance(balance)
                    if hasattr(sound, "setLoop"):
                        sound.setLoop(True)
                    if melody_index not in self._playing_melodies:
                        sound.play()
                        self._playing_melodies.add(melody_index)
                except Exception:
                    LOG.exception("Could not update organism sound #%s", organism.id)
        except Exception:
            LOG.exception("Soundscape update failed; disabling audio")
            self.available = False
            self.stop_all()

    def stop_all(self) -> None:
        for sound in list(self._sound_pool.values()):
            try:
                sound.stop()
            except Exception:
                pass
        self._active_org_to_melody.clear()
        self._playing_melodies.clear()

    def _ensure_assets_and_pool(self) -> None:
        if not self._generated:
            self._generate_melody_wavs()
        if self._sound_pool:
            return
        for index, path in enumerate(self._melody_files):
            try:
                sound = self.base.loader.loadSfx(str(path))
                if hasattr(sound, "setLoop"):
                    sound.setLoop(True)
                sound.setVolume(0.0)
                self._sound_pool[index] = sound
            except Exception:
                LOG.exception("Could not load soundscape melody: %s", path)
                self.available = False
                break

    def _generate_melody_wavs(self) -> None:
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self._melody_files = []
        base_freq = 130.8128  # C3
        for idx, pattern in enumerate(self.MELODY_PATTERNS):
            octave = 1.0 if idx < 6 else 2.0
            root_shift = self.SCALE_RATIOS[idx % len(self.SCALE_RATIOS)]
            samples = self._render_pattern(base_freq * root_shift * octave, pattern)
            path = self.output_dir / f"organism_melody_{idx:02d}.wav"
            self._write_wav(path, samples)
            self._melody_files.append(path)
        self._generated = True
        LOG.info("Generated %s organism melody WAV assets in %s", len(self._melody_files), self.output_dir)

    def _render_pattern(self, root_freq: float, pattern: list[int]) -> np.ndarray:
        sample_rate = 22050
        note_seconds = 0.34
        gap_seconds = 0.035
        out: list[np.ndarray] = []
        for degree in pattern:
            ratio = self.SCALE_RATIOS[degree % len(self.SCALE_RATIOS)]
            freq = root_freq * ratio
            n = int(sample_rate * note_seconds)
            t = np.arange(n, dtype=np.float32) / sample_rate
            # Sine + soft fifth overtone, intentionally low volume to avoid harshness.
            wave_data = np.sin(2.0 * math.pi * freq * t) * 0.55
            wave_data += np.sin(2.0 * math.pi * freq * 1.5 * t) * 0.18
            envelope = np.ones_like(wave_data)
            fade = max(16, int(sample_rate * 0.035))
            envelope[:fade] = np.linspace(0.0, 1.0, fade)
            envelope[-fade:] = np.linspace(1.0, 0.0, fade)
            out.append(wave_data * envelope)
            out.append(np.zeros(int(sample_rate * gap_seconds), dtype=np.float32))
        return np.concatenate(out).astype(np.float32)

    @staticmethod
    def _write_wav(path: Path, samples: np.ndarray) -> None:
        clipped = np.clip(samples, -0.95, 0.95)
        pcm = (clipped * 32767).astype("<i2")
        with wave.open(str(path), "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(22050)
            wf.writeframes(pcm.tobytes())

    def _melody_index_for(self, organism: Organism) -> int:
        family = getattr(organism.genome, "family_id", organism.id)
        return int((family * 7 + organism.id * 3 + organism.complexity_level) % len(self.MELODY_PATTERNS))

    @staticmethod
    def _importance(organism: Organism) -> float:
        size_score = min(1.0, math.log1p(max(0, organism.size)) / 5.0)
        age_score = min(1.0, organism.age / 900.0)
        complexity_score = min(1.0, organism.complexity_level / 5.0)
        score = max(0.0, min(1.0, organism.score))
        energy = max(0.0, min(1.0, organism.energy))
        return max(0.0, min(1.0, 0.28 * size_score + 0.20 * age_score + 0.22 * complexity_score + 0.20 * score + 0.10 * energy))

    @staticmethod
    def _is_playing(sound: Any) -> bool:
        try:
            status = sound.status()
            playing = getattr(sound, "PLAYING", None)
            if playing is not None:
                return status == playing
            return str(status).lower().endswith("playing")
        except Exception:
            return False

    def _stop_sound(self, melody_index: int) -> None:
        sound = self._sound_pool.get(melody_index)
        if sound is None:
            return
        try:
            sound.stop()
            self._playing_melodies.discard(melody_index)
        except Exception:
            self._playing_melodies.discard(melody_index)
