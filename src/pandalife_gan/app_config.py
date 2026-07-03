from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
from typing import Any


@dataclass(slots=True)
class AppConfig:
    """Runtime configuration for GAN Organism Arena.

    The defaults are intentionally conservative so the app can run on older
    Windows 10 machines with integrated or modest discrete GPUs.
    """

    grid_width: int = 192
    grid_height: int = 192
    initial_organisms: int = 18
    target_steps_per_second: float = 18.0
    texture_scale: int = 4
    fullscreen: bool = True
    window_width: int = 1920
    window_height: int = 1080
    pure_conway: bool = False
    max_organisms: int = 96
    component_scan_interval: int = 3
    min_tracked_cells: int = 3
    screenshot_dir: Path = Path("screenshots")
    log_dir: Path = Path("logs")
    safe_render: bool = False
    show_fps: bool = True
    show_hud: bool = True
    show_help: bool = True
    hide_all_overlays: bool = False
    smooth_blend: bool = True
    blend_speed: float = 10.0
    terrain_max_axis: int = 96
    organism_history_limit: int = 24
    dead_archive_limit: int = 60
    memory_prune_interval: int = 120
    performance_log_interval: int = 600
    sound_enabled: bool = True
    sound_volume: float = 0.45
    max_sound_organisms: int = 6
    render_3d: bool = False
    render_mode: str = "2d"
    object_mode_max_organisms: int = 12
    obj_export_max_organisms: int = 32
    view_mode: int = 0
    settings_dir: Path = Path("settings")
    language: str = "en"
    render_backend: str = "auto"
    object_update_interval: int = 24
    object_mesh_quality: str = "fast"
    light_mode: str = "auto_sun"
    thought_output: str = "text"
    thought_tts_interval: float = 12.0

    @property
    def settings_path(self) -> Path:
        return self.settings_dir / "config.json"

    def load_settings(self) -> None:
        """Load persistent user settings from settings/config.json if present.

        Invalid or obsolete keys are ignored so older configs cannot prevent the
        app from starting. CLI arguments still override loaded values.
        """
        path = self.settings_path
        if not path.exists():
            return
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(data, dict):
                return
        except Exception:
            return
        render_mode_present = "render_mode" in data
        for key, value in data.items():
            if key in {"settings_dir", "screenshot_dir", "log_dir"}:
                continue
            if not hasattr(self, key):
                continue
            try:
                current = getattr(self, key)
                if isinstance(current, bool):
                    setattr(self, key, bool(value))
                elif isinstance(current, int) and not isinstance(current, bool):
                    setattr(self, key, int(value))
                elif isinstance(current, float):
                    setattr(self, key, float(value))
                elif isinstance(current, str):
                    setattr(self, key, str(value))
            except Exception:
                continue
        if not render_mode_present:
            self.render_mode = "terrain3d" if self.render_3d else "2d"
        elif self.render_mode not in {"2d", "terrain3d", "object3d"}:
            self.render_mode = "terrain3d" if self.render_3d else "2d"
        self.render_3d = self.render_mode != "2d"
        if getattr(self, "language", "en") not in {"en", "de", "fr"}:
            self.language = "en"
        if getattr(self, "render_backend", "auto") not in {"auto", "opengl", "directx9", "software"}:
            self.render_backend = "auto"
        if getattr(self, "object_mesh_quality", "balanced") not in {"fast", "balanced", "detailed"}:
            self.object_mesh_quality = "balanced"
        if getattr(self, "light_mode", "auto_sun") not in {"auto_sun", "top_left", "top_right", "bottom_left", "bottom_right", "left_mid", "right_mid", "center", "back"}:
            self.light_mode = "auto_sun"
        if getattr(self, "thought_output", "text") not in {"off", "text", "tts", "both"}:
            self.thought_output = "text"
        self.object_update_interval = max(1, min(120, int(getattr(self, "object_update_interval", 24))))
        self.thought_tts_interval = max(3.0, min(120.0, float(getattr(self, "thought_tts_interval", 12.0))))

    def to_settings_dict(self) -> dict[str, Any]:
        return {
            "window_width": int(self.window_width),
            "window_height": int(self.window_height),
            "fullscreen": bool(self.fullscreen),
            "target_steps_per_second": float(self.target_steps_per_second),
            "pure_conway": bool(self.pure_conway),
            "component_scan_interval": int(self.component_scan_interval),
            "show_fps": bool(self.show_fps),
            "show_hud": bool(self.show_hud),
            "show_help": bool(self.show_help),
            "hide_all_overlays": bool(self.hide_all_overlays),
            "smooth_blend": bool(self.smooth_blend),
            "blend_speed": float(self.blend_speed),
            "terrain_max_axis": int(self.terrain_max_axis),
            "organism_history_limit": int(self.organism_history_limit),
            "dead_archive_limit": int(self.dead_archive_limit),
            "memory_prune_interval": int(self.memory_prune_interval),
            "sound_enabled": bool(self.sound_enabled),
            "sound_volume": float(self.sound_volume),
            "max_sound_organisms": int(self.max_sound_organisms),
            "render_3d": bool(self.render_3d),
            "render_mode": str(self.render_mode),
            "object_mode_max_organisms": int(self.object_mode_max_organisms),
            "obj_export_max_organisms": int(self.obj_export_max_organisms),
            "view_mode": int(self.view_mode),
            "language": str(self.language),
            "render_backend": str(self.render_backend),
            "object_update_interval": int(self.object_update_interval),
            "object_mesh_quality": str(self.object_mesh_quality),
            "light_mode": str(self.light_mode),
            "thought_output": str(self.thought_output),
            "thought_tts_interval": float(self.thought_tts_interval),
        }

    def save_settings(self) -> Path:
        self.settings_dir.mkdir(parents=True, exist_ok=True)
        path = self.settings_path
        payload = self.to_settings_dict()
        path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
        return path

    @classmethod
    def from_args(cls, args) -> "AppConfig":
        cfg = cls()
        cfg.load_settings()
        if args.windowed:
            cfg.fullscreen = False
        if args.fullscreen:
            cfg.fullscreen = True
        if getattr(args, "safe_render", False):
            cfg.safe_render = True
            cfg.fullscreen = False if getattr(args, "force_windowed_safe", False) else cfg.fullscreen
            cfg.grid_width = min(cfg.grid_width, 128)
            cfg.grid_height = min(cfg.grid_height, 128)
            cfg.target_steps_per_second = min(cfg.target_steps_per_second, 12.0)
            cfg.initial_organisms = min(cfg.initial_organisms, 10)
            cfg.show_fps = False
        if getattr(args, "width", None):
            cfg.window_width = max(640, int(args.width))
        if getattr(args, "height", None):
            cfg.window_height = max(480, int(args.height))
        if getattr(args, "log_dir", None):
            cfg.log_dir = Path(args.log_dir)
        if getattr(args, "language", None) in {"en", "de", "fr"}:
            cfg.language = str(args.language)
        if getattr(args, "render_backend", None) in {"auto", "opengl", "directx9", "software"}:
            cfg.render_backend = str(args.render_backend)
        if getattr(args, "object_update_interval", None) is not None:
            cfg.object_update_interval = max(1, min(120, int(args.object_update_interval)))
        if getattr(args, "object_mesh_quality", None) in {"fast", "balanced", "detailed"}:
            cfg.object_mesh_quality = str(args.object_mesh_quality)
        if getattr(args, "light_mode", None) in {"auto_sun", "top_left", "top_right", "bottom_left", "bottom_right", "left_mid", "right_mid", "center", "back"}:
            cfg.light_mode = str(args.light_mode)
        if getattr(args, "thought_output", None) in {"off", "text", "tts", "both"}:
            cfg.thought_output = str(args.thought_output)
        if args.grid:
            try:
                w, h = args.grid.lower().replace("x", " ").split()[:2]
                cfg.grid_width = int(w)
                cfg.grid_height = int(h)
            except Exception as exc:  # pragma: no cover - defensive CLI parsing
                raise SystemExit(f"Invalid --grid value '{args.grid}'. Use e.g. 192x192.") from exc
        if args.sps:
            cfg.target_steps_per_second = max(1.0, min(240.0, float(args.sps)))
        if getattr(args, "no_fps", False):
            cfg.show_fps = False
        if getattr(args, "no_blend", False):
            cfg.smooth_blend = False
        if getattr(args, "blend_speed", None):
            cfg.blend_speed = max(1.0, min(60.0, float(args.blend_speed)))
        if getattr(args, "terrain_max_axis", None):
            cfg.terrain_max_axis = max(24, min(192, int(args.terrain_max_axis)))
        if getattr(args, "history_limit", None):
            cfg.organism_history_limit = max(12, min(1200, int(args.history_limit)))
        if getattr(args, "dead_archive_limit", None):
            cfg.dead_archive_limit = max(0, min(5000, int(args.dead_archive_limit)))
        if getattr(args, "memory_prune_interval", None):
            cfg.memory_prune_interval = max(10, min(5000, int(args.memory_prune_interval)))
        if getattr(args, "sound", False):
            cfg.sound_enabled = True
        if getattr(args, "no_sound", False):
            cfg.sound_enabled = False
        if getattr(args, "sound_volume", None) is not None:
            cfg.sound_volume = max(0.0, min(1.0, float(args.sound_volume)))
        if getattr(args, "max_sound_organisms", None) is not None:
            cfg.max_sound_organisms = max(1, min(12, int(args.max_sound_organisms)))
        if getattr(args, "render_mode", None) in {"2d", "terrain3d", "object3d"}:
            cfg.render_mode = str(args.render_mode)
            cfg.render_3d = cfg.render_mode != "2d"
        if getattr(args, "object_mode_max_organisms", None) is not None:
            cfg.object_mode_max_organisms = max(4, min(200, int(args.object_mode_max_organisms)))
        if getattr(args, "obj_export_max_organisms", None) is not None:
            cfg.obj_export_max_organisms = max(1, min(200, int(args.obj_export_max_organisms)))
        return cfg
