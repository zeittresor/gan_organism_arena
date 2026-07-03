from __future__ import annotations

import logging
import math
import subprocess
import textwrap
import time
from pathlib import Path
from typing import Any

import numpy as np
from panda3d.core import (
    AmbientLight,
    AntialiasAttrib,
    CardMaker,
    DirectionalLight,
    ClockObject,
    KeyboardButton,
    OrthographicLens,
    PerspectiveLens,
    Plane,
    Point3,
    Texture,
    TextNode,
    Filename,
    TransparencyAttrib,
    Vec3,
    Vec4,
    WindowProperties,
    loadPrcFileData,
)
from direct.gui.DirectGui import DirectFrame
from direct.gui.OnscreenText import OnscreenText
from direct.showbase.ShowBase import ShowBase
from direct.task import Task

from pandalife_gan import __app_name__, __version__
from pandalife_gan.app_config import AppConfig
from pandalife_gan.localization import Localizer, SUPPORTED_LANGUAGES
from pandalife_gan.simulation.world import LifeWorld
from .image_builder import ImageBuilder
from .terrain_mesh import LifeTerrainMesh
from .object_mesh import LifeObjectMesh
from .soundscape import OrganismSoundscape

LOG = logging.getLogger(__name__)


RESOLUTION_PRESETS: list[tuple[str, int, int]] = [
    ("960 x 540  - 16:9 low", 960, 540),
    ("1024 x 576 - 16:9 low", 1024, 576),
    ("1280 x 720 - HD", 1280, 720),
    ("1366 x 768 - laptop", 1366, 768),
    ("1600 x 900 - HD+", 1600, 900),
    ("1920 x 1080 - Full HD", 1920, 1080),
    ("2560 x 1440 - QHD", 2560, 1440),
    ("3440 x 1440 - ultrawide", 3440, 1440),
    ("3840 x 2160 - 4K", 3840, 2160),
]

HISTORY_LIMIT_PRESETS = [24, 48, 72, 90, 120, 180, 300, 600, 1200]
DEAD_ARCHIVE_PRESETS = [0, 60, 120, 240, 480, 960, 2000]
SCAN_INTERVAL_PRESETS = [1, 2, 3, 5, 8, 12, 20]
SOUND_VOLUME_PRESETS = [0.0, 0.10, 0.25, 0.45, 0.60, 0.80, 1.0]
SOUND_VOICE_PRESETS = [1, 3, 5, 6, 8, 10, 12]
OBJECT_ORGANISM_PRESETS = [4, 6, 8, 12, 18, 24, 32, 40, 60, 80, 120]
OBJ_EXPORT_PRESETS = [4, 8, 16, 24, 32, 48, 80, 120, 200]
OBJECT_UPDATE_INTERVAL_PRESETS = [6, 10, 18, 24, 36, 60, 90, 120]
OBJECT_QUALITY_PRESETS = ["fast", "balanced", "detailed"]
RENDER_BACKEND_PRESETS = ["auto", "opengl", "directx9", "software"]
LIGHT_MODE_PRESETS = ["auto_sun", "top_left", "top_right", "bottom_left", "bottom_right", "left_mid", "right_mid", "center", "back"]
THOUGHT_OUTPUT_PRESETS = ["off", "text", "tts", "both"]
RENDER_MODES = [("2d", "2D texture"), ("terrain3d", "3D terrain"), ("object3d", "3D objects")]

MENU_CURSOR_TEXT = ">>"
MENU_CURSOR_FALLBACK_TEXT = ">>"
SAVE_TOAST_TEXT = "OK Saved"
SAVE_TOAST_FALLBACK_TEXT = "OK Saved"
MENU_VISIBLE_ROWS = 27
MENU_DETAIL_WRAP_WIDTH = 66
HELP_WRAP_WIDTH = 78


class GANOrganismArenaApp(ShowBase):
    def __init__(self, cfg: AppConfig):
        self.cfg = cfg
        LOG.info("Configuring Panda3D")
        self._configure_panda()
        LOG.info("Creating ShowBase")
        super().__init__()
        if self.win is None:
            raise RuntimeError("Panda3D did not create a window. Try run_safe_windowed.bat and check logs/latest_runtime.log.")
        LOG.info("ShowBase created. Window=%s fullscreen=%s", self.win, self.win.isFullscreen())
        self.clock = ClockObject.getGlobalClock()
        LOG.info("Using Panda3D global clock: %s", self.clock)
        self.disableMouse()
        self.setBackgroundColor(0.005, 0.006, 0.008, 1.0)

        LOG.info("Creating simulation world")
        self.world = LifeWorld(cfg)
        self.image_builder = ImageBuilder()
        self.paused = False
        self.show_hud = bool(cfg.show_hud)
        self.show_help = bool(cfg.show_help)
        self.hide_all_overlays = bool(cfg.hide_all_overlays)
        self.show_fps_meter = bool(cfg.show_fps)
        self.step_accumulator = 0.0
        self.hud_accumulator = 0.0
        self._last_perf_log_step = 0
        self.sps = cfg.target_steps_per_second
        self.zoom = 1.0
        self.pan_x = 0.0
        self.pan_y = 0.0
        self.smooth_blend = bool(cfg.smooth_blend)
        self.render_mode = cfg.render_mode if cfg.render_mode in {"2d", "terrain3d", "object3d"} else ("terrain3d" if cfg.render_3d else "2d")
        self.render_3d = self.render_mode != "2d"
        self.orbit_yaw = -38.0
        self.orbit_pitch = 52.0
        self.orbit_distance = max(cfg.grid_width, cfg.grid_height) * 1.65
        self.mouse_dragging = False
        self.last_mouse_xy: tuple[float, float] | None = None
        self.mouse_down_xy: tuple[float, float] | None = None
        self.mouse_drag_moved = False
        self._blend_current: np.ndarray | None = None
        self._blend_target: np.ndarray | None = None
        self._terrain_dirty = True
        # v0.1.5: this is now a general options menu. The legacy
        # variable name is kept as an alias because several event handlers
        # already use it to block camera movement while the menu is open.
        self.resolution_menu_open = False
        self.options_help_open = False
        self.option_index = 0
        self.resolution_presets = self._make_resolution_presets()
        self.resolution_index = self._nearest_resolution_index(cfg.window_width, cfg.window_height)
        self.history_limit_index = self._nearest_value_index(HISTORY_LIMIT_PRESETS, cfg.organism_history_limit)
        self.dead_archive_index = self._nearest_value_index(DEAD_ARCHIVE_PRESETS, cfg.dead_archive_limit)
        self.scan_interval_index = self._nearest_value_index(SCAN_INTERVAL_PRESETS, cfg.component_scan_interval)
        self.sound_volume_index = self._nearest_float_index(SOUND_VOLUME_PRESETS, cfg.sound_volume)
        self.sound_voice_index = self._nearest_value_index(SOUND_VOICE_PRESETS, cfg.max_sound_organisms)
        self.object_org_index = self._nearest_value_index(OBJECT_ORGANISM_PRESETS, cfg.object_mode_max_organisms)
        self.obj_export_index = self._nearest_value_index(OBJ_EXPORT_PRESETS, cfg.obj_export_max_organisms)
        self.object_update_interval_index = self._nearest_value_index(OBJECT_UPDATE_INTERVAL_PRESETS, cfg.object_update_interval)
        self.object_quality_index = max(0, OBJECT_QUALITY_PRESETS.index(cfg.object_mesh_quality) if cfg.object_mesh_quality in OBJECT_QUALITY_PRESETS else 1)
        self.render_backend_index = max(0, RENDER_BACKEND_PRESETS.index(cfg.render_backend) if cfg.render_backend in RENDER_BACKEND_PRESETS else 0)
        self.light_mode_index = max(0, LIGHT_MODE_PRESETS.index(cfg.light_mode) if cfg.light_mode in LIGHT_MODE_PRESETS else 0)
        self.thought_output_index = max(0, THOUGHT_OUTPUT_PRESETS.index(cfg.thought_output) if cfg.thought_output in THOUGHT_OUTPUT_PRESETS else 1)
        self._last_object_mesh_step = -999999
        self._object_mesh_update_count = 0
        self._last_tts_time = 0.0
        self._last_tts_text = ""
        self._tts_process = None
        self._thought_round_robin = 0
        self._restart_notice_timer = 0.0
        self._menu_saved_paused = False
        self._menu_pause_active = False
        self._save_toast_timer = 0.0
        self.help_scroll = 0
        self.menu_scroll = 0
        self.localizer = Localizer(Path("language"), cfg.language)
        self.language_index = self._language_index(cfg.language)

        LOG.info("Creating texture/card/terrain/camera/HUD")
        self.texture = self._create_texture()
        self.card = self._create_world_card()
        self.terrain = LifeTerrainMesh(self.render, cfg.grid_width, cfg.grid_height, max_vertices_axis=cfg.terrain_max_axis)
        self.terrain.node_path.setTexture(self.texture)
        self.terrain.node_path.setTransparency(TransparencyAttrib.MNone)
        self.terrain.node_path.setAntialias(AntialiasAttrib.MNone)
        self.terrain.node_path.hide()
        self.object_mesh = LifeObjectMesh(
            self.render,
            cfg.grid_width,
            cfg.grid_height,
            max_organisms=cfg.object_mode_max_organisms,
            quality=cfg.object_mesh_quality,
        )
        self.object_mesh.node_path.setTransparency(TransparencyAttrib.MAlpha)
        self.object_mesh.node_path.hide()
        self._setup_lighting()
        # Apply persisted render mode after all render backends exist.
        persisted_mode = self.render_mode
        self._setup_camera_2d()
        if persisted_mode == "terrain3d":
            self._setup_camera_3d()
        elif persisted_mode == "object3d":
            self._setup_camera_object_3d()
        self._setup_hud()
        self.image_builder.next_mode(int(max(0, min(7, cfg.view_mode))))
        self.soundscape = OrganismSoundscape(self)
        self.soundscape.set_volume(cfg.sound_volume)
        self.soundscape.set_max_voices(cfg.max_sound_organisms)
        if cfg.sound_enabled:
            self.soundscape.set_enabled(True)
        self._setup_input()
        self._save_settings(show_feedback=False)
        self._update_texture(force=True)
        self.taskMgr.add(self._update_task, "pandalife-update")
        LOG.info("GANOrganismArenaApp initialisation complete")

    def _configure_panda(self) -> None:
        fullscreen = "true" if self.cfg.fullscreen else "false"
        notify_path = (Path(self.cfg.log_dir).resolve() / "panda3d_notify.log").as_posix()
        loadPrcFileData("", f"notify-output {notify_path}")
        loadPrcFileData("", "notify-level warning")
        loadPrcFileData("", f"fullscreen {fullscreen}")
        loadPrcFileData("", f"win-size {self.cfg.window_width} {self.cfg.window_height}")
        backend = getattr(self.cfg, "render_backend", "auto")
        if backend == "opengl":
            loadPrcFileData("", "load-display pandagl")
            LOG.info("Render backend requested: OpenGL hardware")
        elif backend == "directx9":
            loadPrcFileData("", "load-display pandadx9")
            LOG.info("Render backend requested: DirectX9 experimental")
        elif backend == "software":
            loadPrcFileData("", "load-display p3tinydisplay")
            LOG.info("Render backend requested: CPU/software tinydisplay")
        else:
            LOG.info("Render backend requested: auto/hardware preferred")
        loadPrcFileData("", "window-title GAN Organism Arena")
        loadPrcFileData("", "sync-video false")
        loadPrcFileData("", f"show-frame-rate-meter {'true' if self.cfg.show_fps else 'false'}")
        loadPrcFileData("", "textures-power-2 none")
        # Do not force the null audio backend. Audio is optional and remains
        # disabled until the user enables the organism soundscape in Settings,
        # but Panda3D still needs a real audio backend available for that toggle.
        loadPrcFileData("", "model-cache-dir")
        if self.cfg.safe_render:
            loadPrcFileData("", "framebuffer-multisample false")
            loadPrcFileData("", "multisamples 0")
            loadPrcFileData("", "framebuffer-srgb false")
            loadPrcFileData("", "gl-coordinate-system default")
            loadPrcFileData("", "notify-level-display info")
            LOG.info("Safe render mode enabled")

    def _create_texture(self) -> Texture:
        tex = Texture("life-grid")
        tex.setup2dTexture(self.cfg.grid_width, self.cfg.grid_height, Texture.TUnsignedByte, Texture.FRgba8)
        tex.setMagfilter(Texture.FTNearest)
        tex.setMinfilter(Texture.FTNearest)
        return tex

    def _create_world_card(self):
        cm = CardMaker("life-plane")
        cm.setFrame(0, self.cfg.grid_width, 0, self.cfg.grid_height)
        node = self.render.attachNewNode(cm.generate())
        node.setTexture(self.texture)
        node.setTransparency(TransparencyAttrib.MNone)
        node.setAntialias(AntialiasAttrib.MNone)
        node.setTwoSided(True)
        return node

    def _setup_camera_2d(self) -> None:
        self.render_3d = False
        lens = OrthographicLens()
        self.cam.node().setLens(lens)
        self.camera.setPos(self.cfg.grid_width / 2.0, -300.0, self.cfg.grid_height / 2.0)
        self.camera.lookAt(self.cfg.grid_width / 2.0, 0.0, self.cfg.grid_height / 2.0)
        self.render_mode = "2d"
        self.card.show()
        self.terrain.node_path.hide()
        if hasattr(self, "object_mesh"):
            self.object_mesh.node_path.hide()
        self._apply_camera_lens_2d()

    def _setup_camera_3d(self) -> None:
        self.render_3d = True
        self.render_mode = "terrain3d"
        lens = PerspectiveLens()
        lens.setFov(58.0)
        lens.setNearFar(0.2, 4000.0)
        self.cam.node().setLens(lens)
        self.card.hide()
        self.terrain.node_path.show()
        if hasattr(self, "object_mesh"):
            self.object_mesh.node_path.hide()
        self._terrain_dirty = True
        self._apply_camera_3d()

    def _setup_camera_object_3d(self) -> None:
        self.render_3d = True
        self.render_mode = "object3d"
        lens = PerspectiveLens()
        lens.setFov(56.0)
        lens.setNearFar(0.2, 6000.0)
        self.cam.node().setLens(lens)
        self.card.hide()
        self.terrain.node_path.hide()
        self.object_mesh.node_path.show()
        self._terrain_dirty = True
        self._apply_camera_object_3d()

    def _apply_camera_lens_2d(self) -> None:
        if self.render_3d:
            return
        lens = self.cam.node().getLens()
        film_w = self.cfg.grid_width * self.zoom
        film_h = self.cfg.grid_height * self.zoom
        lens.setFilmSize(film_w, film_h)
        self.camera.setX(self.cfg.grid_width / 2.0 + self.pan_x)
        self.camera.setZ(self.cfg.grid_height / 2.0 + self.pan_y)
        self.camera.setY(-300.0)
        self.camera.lookAt(self.cfg.grid_width / 2.0 + self.pan_x, 0.0, self.cfg.grid_height / 2.0 + self.pan_y)

    def _apply_camera_3d(self) -> None:
        cx = self.cfg.grid_width / 2.0 + self.pan_x
        cz = self.cfg.grid_height / 2.0 + self.pan_y
        pitch = math.radians(max(10.0, min(82.0, self.orbit_pitch)))
        yaw = math.radians(self.orbit_yaw)
        dist = max(35.0, min(1500.0, self.orbit_distance))
        x = cx + math.cos(yaw) * math.cos(pitch) * dist
        y = -math.sin(pitch) * dist
        z = cz + math.sin(yaw) * math.cos(pitch) * dist
        self.camera.setPos(x, y, z)
        self.camera.lookAt(cx, 0.0, cz)

    def _apply_camera_object_3d(self) -> None:
        # True object-mode orbit around the organism-world center, like circling a sphere.
        pitch = math.radians(max(6.0, min(86.0, self.orbit_pitch)))
        yaw = math.radians(self.orbit_yaw)
        dist = max(55.0, min(2000.0, self.orbit_distance * 0.92))
        target = Point3(self.pan_x * 0.22, 0.0, self.pan_y * 0.22)
        x = target.getX() + math.cos(yaw) * math.cos(pitch) * dist
        y = target.getY() - math.sin(pitch) * dist
        z = target.getZ() + math.sin(yaw) * math.cos(pitch) * dist
        self.camera.setPos(x, y, z)
        self.camera.lookAt(target)


    def _setup_lighting(self) -> None:
        self.ambient_light = AmbientLight("ambient-life-light")
        self.ambient_light.setColor(Vec4(0.32, 0.34, 0.36, 1.0))
        self.ambient_np = self.render.attachNewNode(self.ambient_light)
        self.render.setLight(self.ambient_np)

        self.key_light = DirectionalLight("key-life-light")
        self.key_light.setColor(Vec4(0.92, 0.90, 0.82, 1.0))
        self.key_light.setShadowCaster(False)
        self.key_light_np = self.render.attachNewNode(self.key_light)
        self.render.setLight(self.key_light_np)

        self.fill_light = DirectionalLight("fill-life-light")
        self.fill_light.setColor(Vec4(0.20, 0.24, 0.32, 1.0))
        self.fill_light_np = self.render.attachNewNode(self.fill_light)
        self.render.setLight(self.fill_light_np)
        self._apply_light_mode(force=True)

    def _light_vector_for_mode(self) -> Vec3:
        mode = getattr(self.cfg, "light_mode", "auto_sun")
        if mode == "auto_sun":
            # Slow orbit: lighting changes like a small sun over the organism world.
            phase = (getattr(self.world, "step_index", 0) * 0.0035) % (2.0 * math.pi)
            return Vec3(math.cos(phase) * 1.4, -1.35, math.sin(phase) * 1.4 + 0.45)
        mapping = {
            "top_left": Vec3(-1.2, -1.5, 1.2),
            "top_right": Vec3(1.2, -1.5, 1.2),
            "bottom_left": Vec3(-1.2, -0.7, -1.2),
            "bottom_right": Vec3(1.2, -0.7, -1.2),
            "left_mid": Vec3(-1.8, -1.0, 0.05),
            "right_mid": Vec3(1.8, -1.0, 0.05),
            "center": Vec3(0.0, -1.6, 0.8),
            "back": Vec3(0.0, 1.2, 0.6),
        }
        return mapping.get(mode, Vec3(-1.2, -1.5, 1.2))

    def _apply_light_mode(self, force: bool = False) -> None:
        if not hasattr(self, "key_light_np"):
            return
        vec = self._light_vector_for_mode()
        if vec.lengthSquared() < 0.0001:
            vec = Vec3(-1.0, -1.0, 1.0)
        pos = Point3(vec.x * 80.0, vec.y * 80.0, vec.z * 80.0)
        self.key_light_np.setPos(pos)
        self.key_light_np.lookAt(Point3(0.0, 0.0, 0.0))
        self.fill_light_np.setPos(Point3(-pos.x * 0.45, -pos.y * 0.35, max(12.0, -pos.z * 0.2)))
        self.fill_light_np.lookAt(Point3(0.0, 0.0, 0.0))
        if hasattr(self, "object_mesh"):
            self.object_mesh.set_light_vector((vec.x, vec.y, vec.z))
        if force:
            LOG.info("Lighting applied: mode=%s vector=%s", getattr(self.cfg, "light_mode", "auto_sun"), vec)

    def _regenerate_render_pipeline(self) -> None:
        LOG.info("Regenerating render pipeline / mesh cache")
        try:
            self.render.clearLight()
            self._setup_lighting()
            # Recreate object mesh root so old generated Geoms are released.
            if hasattr(self, "object_mesh"):
                self.object_mesh.node_path.removeNode()
            self.object_mesh = LifeObjectMesh(
                self.render,
                self.cfg.grid_width,
                self.cfg.grid_height,
                max_organisms=self.cfg.object_mode_max_organisms,
                quality=self.cfg.object_mesh_quality,
            )
            self.object_mesh.node_path.setTransparency(TransparencyAttrib.MAlpha)
            self._apply_light_mode(force=True)
            if self.render_mode == "object3d":
                self.object_mesh.node_path.show()
                self._update_object_mesh(force=True)
            else:
                self.object_mesh.node_path.hide()
            self._terrain_dirty = True
            self._update_texture(force=True)
            if self.render_mode == "terrain3d":
                self._update_terrain()
            self._show_save_toast()
        except Exception:
            LOG.exception("Render pipeline regeneration failed")

    def _apply_current_camera(self) -> None:
        if self.render_mode == "object3d":
            self._apply_camera_object_3d()
        elif self.render_mode == "terrain3d":
            self._apply_camera_3d()
        else:
            self._apply_camera_lens_2d()

    def _load_menu_symbol_font(self) -> Any | None:
        """Load a Windows symbol/emoji font for menu cursor and save checkmark.

        Panda3D's bundled default font may not contain emoji or checkmark glyphs.
        On Windows, Segoe UI Emoji/Symbol usually does. If loading fails, the
        app remains usable; Panda3D will fall back to its default font.
        """
        candidates = [
            Path("C:/Windows/Fonts/seguiemj.ttf"),
            Path("C:/Windows/Fonts/seguisym.ttf"),
            Path("C:/Windows/Fonts/segoeui.ttf"),
        ]
        for candidate in candidates:
            try:
                if candidate.exists():
                    # Panda3D sometimes rejects Windows-style paths from Python
                    # strings. Filename.fromOsSpecific converts C:\... into the
                    # engine's expected internal path form.
                    panda_filename = Filename.fromOsSpecific(str(candidate)).getFullpath()
                    font = self.loader.loadFont(panda_filename)
                    if font is not None:
                        LOG.info("Loaded menu symbol font: %s", candidate)
                        return font
            except Exception:
                LOG.warning("Could not load menu symbol font: %s", candidate, exc_info=True)
        LOG.info("No external menu symbol font loaded; using safe ASCII fallback symbols")
        return None

    def _setup_hud(self) -> None:
        self.menu_symbol_font = self._load_menu_symbol_font()
        symbol_text_kwargs = {"font": self.menu_symbol_font} if self.menu_symbol_font is not None else {}
        self.menu_cursor_text = MENU_CURSOR_FALLBACK_TEXT
        self.save_toast_text = self.tr("ui.saved")
        self.hud = OnscreenText(
            text="",
            pos=(-1.30, 0.94),
            scale=0.030,
            fg=(0.82, 0.95, 0.88, 1.0),
            bg=(0.0, 0.0, 0.0, 0.32),
            align=TextNode.ALeft,
            mayChange=True,
        )
        self.help_text = OnscreenText(
            text=self.tr("ui.f10_settings"),
            pos=(-1.30, -0.94),
            scale=0.030,
            fg=(0.88, 0.88, 0.78, 1.0),
            bg=(0.0, 0.0, 0.0, 0.28),
            align=TextNode.ALeft,
            mayChange=True,
        )
        self.speak_text = OnscreenText(
            text="",
            pos=(-1.30, -0.88),
            scale=0.028,
            fg=(0.88, 0.94, 1.0, 1.0),
            bg=(0.0, 0.0, 0.0, 0.22),
            align=TextNode.ALeft,
            mayChange=True,
        )
        # v0.1.7: graphical settings UI. The simulation is paused while this
        # UI is open. The old variable name ``resolution_menu`` is kept as the
        # selectable list text node for compatibility with existing handlers.
        self.menu_backdrop = DirectFrame(
            frameSize=(-1.42, 1.42, -1.04, 1.04),
            frameColor=(0.0, 0.0, 0.0, 0.58),
            pos=(0, 0, 0),
        )
        self.menu_panel = DirectFrame(
            frameSize=(-1.12, 1.12, -0.78, 0.78),
            frameColor=(0.025, 0.040, 0.052, 0.94),
            pos=(0, 0, 0.03),
        )
        self.menu_sidebar = DirectFrame(
            frameSize=(-1.08, -0.34, -0.68, 0.59),
            frameColor=(0.050, 0.075, 0.090, 0.92),
            pos=(0, 0, 0.03),
        )
        self.menu_detail_panel = DirectFrame(
            frameSize=(-0.28, 1.08, -0.68, 0.59),
            frameColor=(0.018, 0.026, 0.034, 0.86),
            pos=(0, 0, 0.03),
        )
        for frame in (self.menu_backdrop, self.menu_panel, self.menu_sidebar, self.menu_detail_panel):
            try:
                frame.setTransparency(TransparencyAttrib.MAlpha)
            except Exception:
                pass
        self.menu_title = OnscreenText(
            text="",
            pos=(-1.06, 0.73),
            scale=0.046,
            fg=(0.95, 1.00, 0.90, 1.0),
            align=TextNode.ALeft,
            mayChange=True,
        )
        self.menu_status = OnscreenText(
            text="",
            pos=(-1.06, 0.655),
            scale=0.026,
            fg=(0.66, 0.82, 0.82, 1.0),
            align=TextNode.ALeft,
            mayChange=True,
        )
        self.save_toast = OnscreenText(
            text="",
            pos=(0.88, 0.73),
            scale=0.032,
            fg=(0.62, 1.00, 0.66, 1.0),
            bg=(0.0, 0.0, 0.0, 0.38),
            align=TextNode.ARight,
            mayChange=True,
            **symbol_text_kwargs,
        )
        self.resolution_menu = OnscreenText(
            text="",
            pos=(-1.04, 0.55),
            scale=0.029,
            fg=(0.86, 0.96, 0.88, 1.0),
            align=TextNode.ALeft,
            mayChange=True,
        )
        self.menu_detail = OnscreenText(
            text="",
            pos=(-0.23, 0.55),
            scale=0.030,
            fg=(0.91, 0.94, 0.90, 1.0),
            align=TextNode.ALeft,
            mayChange=True,
        )
        self.menu_footer = OnscreenText(
            text="",
            pos=(-1.06, -0.79),
            scale=0.026,
            fg=(0.75, 0.82, 0.74, 1.0),
            align=TextNode.ALeft,
            mayChange=True,
        )
        # v0.1.8: render the options list as independent columns instead of
        # one proportional-font text block. This keeps labels and values aligned
        # even with Panda3D's default font and avoids unsupported Unicode glyphs.
        self.menu_rows = []
        row_start_y = 0.55
        row_step = 0.039
        for row_idx in range(MENU_VISIBLE_ROWS):
            y = row_start_y - row_idx * row_step
            cursor = OnscreenText(
                text="", pos=(-1.065, y + 0.001), scale=0.027,
                fg=(1.0, 0.90, 0.48, 1.0), align=TextNode.ALeft, mayChange=True,
                **symbol_text_kwargs,
            )
            label = OnscreenText(
                text="", pos=(-1.025, y), scale=0.025,
                fg=(0.86, 0.96, 0.88, 1.0), align=TextNode.ALeft, mayChange=True
            )
            value = OnscreenText(
                text="", pos=(-0.675, y), scale=0.025,
                fg=(0.78, 0.90, 0.96, 1.0), align=TextNode.ALeft, mayChange=True
            )
            self.menu_rows.append((cursor, label, value))

        # Visual scroll indicators for the left option list and the right help/detail panel.
        # They are intentionally built from plain DirectFrame rectangles so they do
        # not depend on fonts or Unicode glyph support.
        self.menu_scroll_track = DirectFrame(
            frameSize=(-0.004, 0.004, -0.62, 0.54),
            frameColor=(0.22, 0.32, 0.36, 0.42),
            pos=(-0.365, 0, 0.03),
        )
        self.menu_scroll_thumb = DirectFrame(
            frameSize=(-0.006, 0.006, -0.08, 0.08),
            frameColor=(0.80, 0.92, 0.78, 0.86),
            pos=(-0.365, 0, 0.03),
        )
        self.detail_scroll_track = DirectFrame(
            frameSize=(-0.004, 0.004, -0.62, 0.54),
            frameColor=(0.22, 0.32, 0.36, 0.38),
            pos=(1.045, 0, 0.03),
        )
        self.detail_scroll_thumb = DirectFrame(
            frameSize=(-0.006, 0.006, -0.08, 0.08),
            frameColor=(0.80, 0.92, 0.78, 0.84),
            pos=(1.045, 0, 0.03),
        )
        for frame in (self.menu_scroll_track, self.menu_scroll_thumb, self.detail_scroll_track, self.detail_scroll_thumb):
            try:
                frame.setTransparency(TransparencyAttrib.MAlpha)
            except Exception:
                pass

        self._show_menu_ui(False)
        self._apply_overlay_visibility()

    def _setup_input(self) -> None:
        self.accept("escape", self._escape_pressed)
        self.accept("space", self._toggle_pause)
        self.accept("r", self._reset_world)
        self.accept("g", self._inject_organism)
        self.accept("c", self._toggle_critic)
        self.accept("h", self._toggle_hud)
        self.accept("f1", self._open_help_page)
        self.accept("o", self._toggle_clean_overlay)
        self.accept("p", self._toggle_pure_conway)
        self.accept("v", self._cycle_view_mode)
        for i in range(1, 9):
            self.accept(str(i), self._set_view_mode, [i - 1])
        self.accept("b", self._toggle_blend)
        self.accept("t", self._toggle_3d)
        self.accept("+", self._speed_up)
        self.accept("=", self._speed_up)
        self.accept("-", self._slow_down)
        self.accept("f", self._toggle_fullscreen)
        self.accept("f10", self._toggle_resolution_menu)
        self.accept("m", self._toggle_resolution_menu)
        self.accept("arrow_up", self._resolution_menu_up)
        self.accept("arrow_down", self._resolution_menu_down)
        self.accept("w", self._resolution_menu_up)
        self.accept("s", self._resolution_menu_down)
        self.accept("arrow_left", self._options_menu_left)
        self.accept("arrow_right", self._options_menu_right)
        self.accept("a", self._options_menu_left)
        self.accept("d", self._options_menu_right)
        self.accept("enter", self._apply_selected_resolution)
        self.accept("raw-enter", self._apply_selected_resolution)
        self.accept("e", self._export_obj_lifeforms)
        self.accept("f12", self._save_screenshot)
        self.accept("wheel_up", self._zoom, [0.88])
        self.accept("wheel_down", self._zoom, [1.14])
        self.accept("mouse1", self._mouse_down)
        self.accept("mouse1-up", self._mouse_up)

    def _escape_pressed(self) -> None:
        if self.resolution_menu_open:
            if self.options_help_open:
                self.options_help_open = False
                self.help_scroll = 0
                self._update_resolution_menu()
            else:
                self._toggle_resolution_menu(force=False)
            return
        self.userExit()


    def tr(self, key: str, default: str | None = None, **kwargs: Any) -> str:
        value = self.localizer.text(key, **kwargs)
        return default if default is not None and value == key else value

    @staticmethod
    def _language_index(language: str) -> int:
        code = (language or "en").lower().split("-")[0]
        for idx, (item_code, _label) in enumerate(SUPPORTED_LANGUAGES):
            if item_code == code:
                return idx
        return 0

    def _current_language_code(self) -> str:
        return SUPPORTED_LANGUAGES[self.language_index % len(SUPPORTED_LANGUAGES)][0]

    def _current_language_label(self) -> str:
        return SUPPORTED_LANGUAGES[self.language_index % len(SUPPORTED_LANGUAGES)][1]

    def _make_resolution_presets(self) -> list[tuple[str, int, int]]:
        presets = list(RESOLUTION_PRESETS)
        current = (self.cfg.window_width, self.cfg.window_height)
        if not any((w, h) == current for _, w, h in presets):
            presets.insert(0, (f"{current[0]} x {current[1]} - startup/custom", current[0], current[1]))
        return presets

    def _nearest_resolution_index(self, width: int, height: int) -> int:
        best_index = 0
        best_score = float("inf")
        for idx, (_, w, h) in enumerate(self.resolution_presets):
            score = abs(w - width) + abs(h - height)
            if score < best_score:
                best_index = idx
                best_score = score
        return best_index

    @staticmethod
    def _nearest_value_index(values: list[int], current: int) -> int:
        best_index = 0
        best_score = float("inf")
        for idx, value in enumerate(values):
            score = abs(int(value) - int(current))
            if score < best_score:
                best_index = idx
                best_score = score
        return best_index

    @staticmethod
    def _nearest_float_index(values: list[float], current: float) -> int:
        best_index = 0
        best_score = float("inf")
        for idx, value in enumerate(values):
            score = abs(float(value) - float(current))
            if score < best_score:
                best_index = idx
                best_score = score
        return best_index

    def _show_menu_ui(self, visible: bool) -> None:
        nodes = [
            getattr(self, "menu_backdrop", None),
            getattr(self, "menu_panel", None),
            getattr(self, "menu_sidebar", None),
            getattr(self, "menu_detail_panel", None),
            getattr(self, "menu_title", None),
            getattr(self, "menu_status", None),
            getattr(self, "menu_detail", None),
            getattr(self, "menu_footer", None),
            getattr(self, "menu_scroll_track", None),
            getattr(self, "menu_scroll_thumb", None),
            getattr(self, "detail_scroll_track", None),
            getattr(self, "detail_scroll_thumb", None),
        ]
        if hasattr(self, "resolution_menu"):
            # Legacy text block no longer used in v0.1.8. Keep it hidden to
            # avoid accidental duplicate/proportional list rendering.
            self.resolution_menu.setText("")
            self.resolution_menu.hide()
        if hasattr(self, "menu_rows"):
            for row in self.menu_rows:
                nodes.extend(row)
        for node in nodes:
            if node is None:
                continue
            try:
                node.show() if visible else node.hide()
            except Exception:
                pass

    @staticmethod
    def _short(text: str, max_len: int) -> str:
        text = str(text)
        if len(text) <= max_len:
            return text
        return text[: max(0, max_len - 3)] + "..."

    @staticmethod
    def _wrap_text(text: str, width: int = MENU_DETAIL_WRAP_WIDTH, subsequent_indent: str = "") -> list[str]:
        text = str(text).replace("\r", "")
        out: list[str] = []
        for raw in text.split("\n"):
            if raw.strip() == "":
                out.append("")
                continue
            leading = raw[: len(raw) - len(raw.lstrip())]
            wrapped = textwrap.wrap(
                raw.strip(),
                width=max(20, width - len(leading)),
                break_long_words=False,
                break_on_hyphens=False,
            ) or [""]
            for idx, line in enumerate(wrapped):
                out.append((leading if idx == 0 else leading + subsequent_indent) + line)
        return out

    def _set_scrollbar(self, track, thumb, scroll: int, max_scroll: int, visible: bool = True) -> None:
        if not track or not thumb:
            return
        if not visible or max_scroll <= 0:
            track.hide()
            thumb.hide()
            return
        track.show()
        thumb.show()
        top = 0.54
        bottom = -0.62
        height = top - bottom
        ratio = max(0.12, min(1.0, MENU_VISIBLE_ROWS / max(MENU_VISIBLE_ROWS + max_scroll, 1)))
        half = height * ratio * 0.5
        progress = max(0.0, min(1.0, float(scroll) / float(max_scroll)))
        center = top - half - progress * (height - 2.0 * half)
        try:
            thumb["frameSize"] = (-0.006, 0.006, -half, half)
        except Exception:
            pass
        try:
            thumb.setZ(0.03 + center)
        except Exception:
            pass

    @staticmethod
    def _set_text_fg(node, color) -> None:
        try:
            node.setFg(color)
            return
        except Exception:
            pass
        try:
            node["fg"] = color
        except Exception:
            pass

    def _set_menu_rows(self, rows: list[dict[str, str | bool]]) -> None:
        if not hasattr(self, "menu_rows"):
            return
        for idx, row_nodes in enumerate(self.menu_rows):
            cursor_node, label_node, value_node = row_nodes
            if idx >= len(rows):
                cursor_node.setText("")
                label_node.setText("")
                value_node.setText("")
                continue
            row = rows[idx]
            is_section = bool(row.get("section", False))
            is_selected = bool(row.get("selected", False))
            cursor_node.setText(getattr(self, "menu_cursor_text", MENU_CURSOR_FALLBACK_TEXT) if is_selected and not is_section else "")
            label_node.setText(self._short(str(row.get("label", "")), 31))
            value_node.setText("" if is_section else self._short(str(row.get("value", "")), 22))
            if is_section:
                self._set_text_fg(label_node, (0.98, 0.86, 0.52, 1.0))
                self._set_text_fg(value_node, (0.78, 0.90, 0.96, 1.0))
            elif is_selected:
                self._set_text_fg(label_node, (1.00, 1.00, 0.82, 1.0))
                self._set_text_fg(value_node, (0.95, 1.00, 0.82, 1.0))
            else:
                self._set_text_fg(label_node, (0.82, 0.94, 0.86, 1.0))
                self._set_text_fg(value_node, (0.72, 0.86, 0.92, 1.0))


    def _build_scrollable_menu_rows(self, entries: list[tuple[str, str]]) -> tuple[list[dict[str, str | bool]], int, int]:
        all_rows: list[dict[str, str | bool | int]] = []
        selected_row_index = 0
        last_section = None
        for idx, (option_id, label) in enumerate(entries):
            section_key = self._option_section(option_id)
            section = self.tr(f"ui.section_{section_key}").upper()
            if section_key != last_section:
                all_rows.append({"label": section, "value": "", "section": True})
                last_section = section_key
            if idx == self.option_index:
                selected_row_index = len(all_rows)
            all_rows.append({
                "label": label,
                "value": self._option_value_text(option_id),
                "selected": idx == self.option_index,
            })

        max_scroll = max(0, len(all_rows) - MENU_VISIBLE_ROWS)
        if selected_row_index < self.menu_scroll:
            self.menu_scroll = selected_row_index
        elif selected_row_index >= self.menu_scroll + MENU_VISIBLE_ROWS:
            self.menu_scroll = selected_row_index - MENU_VISIBLE_ROWS + 1
        self.menu_scroll = max(0, min(max_scroll, int(getattr(self, "menu_scroll", 0))))
        shown = all_rows[self.menu_scroll:self.menu_scroll + MENU_VISIBLE_ROWS]
        return shown, self.menu_scroll, max_scroll

    def _sync_config_from_runtime(self) -> None:
        # Keep user-requested display settings as source of truth. Panda3D may
        # apply window properties asynchronously, so reading win.getXSize()
        # immediately after a request can accidentally save the previous size.
        self.cfg.target_steps_per_second = float(self.sps)
        self.cfg.pure_conway = bool(self.world.pure_conway)
        self.cfg.show_fps = bool(self.show_fps_meter)
        self.cfg.show_hud = bool(self.show_hud)
        self.cfg.show_help = bool(self.show_help)
        self.cfg.hide_all_overlays = bool(self.hide_all_overlays)
        self.cfg.smooth_blend = bool(self.smooth_blend)
        self.cfg.render_3d = bool(self.render_3d)
        self.cfg.render_mode = str(self.render_mode)
        self.cfg.object_mode_max_organisms = int(self.object_mesh.max_organisms) if hasattr(self, "object_mesh") else int(self.cfg.object_mode_max_organisms)
        self.cfg.obj_export_max_organisms = int(self.cfg.obj_export_max_organisms)
        self.cfg.object_update_interval = int(getattr(self.cfg, "object_update_interval", 6))
        self.cfg.object_mesh_quality = str(getattr(self.cfg, "object_mesh_quality", "balanced"))
        self.cfg.render_backend = str(getattr(self.cfg, "render_backend", "auto"))
        self.cfg.light_mode = str(getattr(self.cfg, "light_mode", "auto_sun"))
        self.cfg.thought_output = str(getattr(self.cfg, "thought_output", "text"))
        self.cfg.view_mode = int(self.image_builder.mode)
        self.cfg.language = self._current_language_code()
        if hasattr(self, "soundscape"):
            self.cfg.sound_enabled = bool(self.soundscape.enabled)

    def _show_save_toast(self) -> None:
        if not hasattr(self, "save_toast"):
            return
        self._save_toast_timer = 1.0
        self.save_toast.setText(getattr(self, "save_toast_text", SAVE_TOAST_FALLBACK_TEXT))
        try:
            self.save_toast.show()
        except Exception:
            pass

    def _update_save_toast(self, dt: float) -> None:
        if not hasattr(self, "save_toast"):
            return
        if self._save_toast_timer <= 0.0:
            return
        self._save_toast_timer = max(0.0, self._save_toast_timer - dt)
        if self._save_toast_timer <= 0.0:
            self.save_toast.setText("")

    def _save_settings(self, show_feedback: bool = True) -> None:
        self._sync_config_from_runtime()
        try:
            path = self.cfg.save_settings()
            LOG.info("Settings saved: %s", path)
            if show_feedback:
                self._show_save_toast()
        except Exception:
            LOG.exception("Could not save settings/config.json")

    def _toggle_resolution_menu(self, force: bool | None = None) -> None:
        new_state = (not self.resolution_menu_open) if force is None else bool(force)
        if new_state == self.resolution_menu_open:
            return
        self.resolution_menu_open = new_state
        if self.resolution_menu_open:
            # Opening Settings always freezes simulation evolution. If the sim was
            # running, it resumes automatically when the menu closes. If it was
            # already paused, it stays paused.
            self._menu_saved_paused = self.paused
            self._menu_pause_active = True
            self.paused = True
            self.step_accumulator = 0.0
            self._show_menu_ui(True)
            self._update_resolution_menu()
        else:
            self.options_help_open = False
            if self._menu_pause_active:
                self.paused = self._menu_saved_paused
            self._menu_pause_active = False
            self._save_settings()
            self._show_menu_ui(False)
            self._apply_overlay_visibility()
        LOG.info("Settings menu open: %s paused=%s saved_pause=%s", self.resolution_menu_open, self.paused, self._menu_saved_paused)

    def _open_help_page(self) -> None:
        if not self.resolution_menu_open:
            self._toggle_resolution_menu(force=True)
        self.options_help_open = True
        self.help_scroll = 0
        self._show_menu_ui(True)
        self._update_resolution_menu()
        LOG.info("Options help opened")

    def _option_entries(self) -> list[tuple[str, str]]:
        option_ids = [
            "help",
            "language",
            "resolution",
            "fullscreen",
            "view",
            "render",
            "render_backend",
            "object_orgs",
            "object_update",
            "object_quality",
            "obj_export_cap",
            "light_mode",
            "regen_render",
            "blend",
            "sim_mode",
            "speed",
            "history_limit",
            "dead_archive",
            "scan_interval",
            "memory_status",
            "prune_memory",
            "sound",
            "sound_volume",
            "sound_voices",
            "thought_output",
            "resume_after_menu",
            "critic",
            "hud",
            "help_overlay",
            "fps",
            "clean",
            "inject",
            "export_obj",
            "reset",
            "close",
        ]
        return [(option_id, self.tr(f"options.{option_id}.label")) for option_id in option_ids]

    def _option_section(self, option_id: str) -> str:
        if option_id in {"help"}:
            return "guide"
        if option_id in {"language"}:
            return "language"
        if option_id in {"resolution", "fullscreen", "view", "render", "render_backend", "object_orgs", "object_update", "object_quality", "obj_export_cap", "light_mode", "regen_render", "blend"}:
            return "display"
        if option_id in {"sim_mode", "speed", "history_limit", "dead_archive", "scan_interval", "memory_status", "prune_memory", "resume_after_menu"}:
            return "simulation"
        if option_id in {"sound", "sound_volume", "sound_voices", "thought_output"}:
            return "sound"
        if option_id in {"critic", "hud", "help_overlay", "fps", "clean"}:
            return "overlays"
        return "actions"

    def _option_description(self, option_id: str) -> str:
        return self.tr(f"options.{option_id}.desc")

    def _resolution_menu_up(self) -> None:
        if not self.resolution_menu_open:
            return
        if self.options_help_open:
            self._scroll_help(-3)
            return
        self.option_index = (self.option_index - 1) % len(self._option_entries())
        self._update_resolution_menu()

    def _resolution_menu_down(self) -> None:
        if not self.resolution_menu_open:
            return
        if self.options_help_open:
            self._scroll_help(3)
            return
        self.option_index = (self.option_index + 1) % len(self._option_entries())
        self._update_resolution_menu()

    def _options_menu_left(self) -> None:
        if not self.resolution_menu_open or self.options_help_open:
            return
        self._change_current_option(-1)

    def _options_menu_right(self) -> None:
        if not self.resolution_menu_open or self.options_help_open:
            return
        self._change_current_option(1)

    def _apply_selected_resolution(self) -> None:
        if not self.resolution_menu_open:
            return
        if self.options_help_open:
            self.options_help_open = False
            self.help_scroll = 0
            self._update_resolution_menu()
            return
        option_id = self._option_entries()[self.option_index][0]
        self._activate_option(option_id)
        if option_id not in {"close"}:
            self._save_settings()
        self._update_resolution_menu()

    def _change_current_option(self, direction: int) -> None:
        option_id = self._option_entries()[self.option_index][0]
        if option_id == "resolution":
            self.resolution_index = (self.resolution_index + direction) % len(self.resolution_presets)
        elif option_id == "language":
            self._change_language(direction)
        elif option_id == "view":
            self._set_view_mode(self.image_builder.mode + direction)
        elif option_id == "speed":
            self._speed_up() if direction > 0 else self._slow_down()
        elif option_id == "render_backend":
            self._change_render_backend(direction)
        elif option_id == "object_orgs":
            self._change_object_organism_cap(direction)
        elif option_id == "object_update":
            self._change_object_update_interval(direction)
        elif option_id == "object_quality":
            self._change_object_quality(direction)
        elif option_id == "obj_export_cap":
            self._change_obj_export_cap(direction)
        elif option_id == "light_mode":
            self._change_light_mode(direction)
        elif option_id == "history_limit":
            self._change_history_limit(direction)
        elif option_id == "dead_archive":
            self._change_dead_archive_limit(direction)
        elif option_id == "scan_interval":
            self._change_scan_interval(direction)
        elif option_id == "sound_volume":
            self._change_sound_volume(direction)
        elif option_id == "sound_voices":
            self._change_sound_voices(direction)
        elif option_id == "thought_output":
            self._change_thought_output(direction)
        elif option_id in {"fullscreen", "render", "blend", "sim_mode", "sound", "resume_after_menu", "critic", "hud", "help_overlay", "fps", "clean", "regen_render"}:
            self._activate_option(option_id)
        if option_id != "resolution":
            self._save_settings()
        self._update_resolution_menu()

    def _activate_option(self, option_id: str) -> None:
        if option_id == "help":
            self.options_help_open = True
        elif option_id == "language":
            self._change_language(1)
        elif option_id == "resolution":
            self._apply_resolution_preset()
        elif option_id == "fullscreen":
            self._toggle_fullscreen()
        elif option_id == "view":
            self._cycle_view_mode()
        elif option_id == "render":
            self._toggle_3d()
        elif option_id == "render_backend":
            self._change_render_backend(1)
        elif option_id == "blend":
            self._toggle_blend()
        elif option_id == "sim_mode":
            self._toggle_pure_conway()
        elif option_id == "speed":
            self._speed_up()
        elif option_id == "object_orgs":
            self._change_object_organism_cap(1)
        elif option_id == "object_update":
            self._change_object_update_interval(1)
        elif option_id == "object_quality":
            self._change_object_quality(1)
        elif option_id == "obj_export_cap":
            self._change_obj_export_cap(1)
        elif option_id == "light_mode":
            self._change_light_mode(1)
        elif option_id == "regen_render":
            self._regenerate_render_pipeline()
        elif option_id == "history_limit":
            self._change_history_limit(1)
        elif option_id == "dead_archive":
            self._change_dead_archive_limit(1)
        elif option_id == "scan_interval":
            self._change_scan_interval(1)
        elif option_id == "memory_status":
            LOG.info("Memory status: %s", self.world.memory_stats())
        elif option_id == "sound":
            self._toggle_soundscape()
        elif option_id == "sound_volume":
            self._change_sound_volume(1)
        elif option_id == "sound_voices":
            self._change_sound_voices(1)
        elif option_id == "thought_output":
            self._change_thought_output(1)
        elif option_id == "resume_after_menu":
            self._menu_saved_paused = not self._menu_saved_paused
            LOG.info("Resume after menu toggled: %s", not self._menu_saved_paused)
        elif option_id == "prune_memory":
            self._prune_memory_now()
        elif option_id == "critic":
            self._toggle_critic()
        elif option_id == "hud":
            self._toggle_hud()
        elif option_id == "help_overlay":
            self._toggle_help_overlay()
        elif option_id == "fps":
            self._toggle_fps_meter()
        elif option_id == "clean":
            self._toggle_clean_overlay()
        elif option_id == "inject":
            self._inject_organism()
        elif option_id == "export_obj":
            self._export_obj_lifeforms()
        elif option_id == "reset":
            self._reset_world()
        elif option_id == "close":
            self._toggle_resolution_menu(force=False)

    def _apply_resolution_preset(self) -> None:
        label, width, height = self.resolution_presets[self.resolution_index]
        self.cfg.window_width = int(width)
        self.cfg.window_height = int(height)
        self.cfg.fullscreen = bool(self.win.isFullscreen())
        props = WindowProperties()
        props.setSize(int(width), int(height))
        props.setFullscreen(self.win.isFullscreen())
        LOG.info("Applying selected resolution: %s fullscreen=%s", label, self.win.isFullscreen())
        self.win.requestProperties(props)
        self._save_settings()
        self._apply_current_camera()

    def _get_window_size_text(self) -> str:
        try:
            return f"{self.win.getXSize()} x {self.win.getYSize()}"
        except Exception:
            return f"{self.cfg.window_width} x {self.cfg.window_height}"

    def _option_value_text(self, option_id: str) -> str:
        on = self.tr("ui.on")
        off = self.tr("ui.off")
        if option_id == "help":
            return "Enter"
        if option_id == "language":
            return self._current_language_label()
        if option_id == "resolution":
            return self.resolution_presets[self.resolution_index][0]
        if option_id == "fullscreen":
            return self.tr("ui.fullscreen") if self.win.isFullscreen() else self.tr("ui.windowed")
        if option_id == "view":
            return self.image_builder.mode_name
        if option_id == "render":
            return dict(RENDER_MODES).get(self.render_mode, self.render_mode)
        if option_id == "render_backend":
            label = self.tr(f"ui.backend_{self.cfg.render_backend}", default=self.cfg.render_backend)
            return f"{label} (restart)"
        if option_id == "object_orgs":
            return f"{self.object_mesh.max_organisms} meshes"
        if option_id == "object_update":
            return f"every {self.cfg.object_update_interval} step(s)"
        if option_id == "object_quality":
            return self.tr(f"ui.quality_{self.cfg.object_mesh_quality}", default=self.cfg.object_mesh_quality)
        if option_id == "obj_export_cap":
            return f"{self.cfg.obj_export_max_organisms} OBJ"
        if option_id == "light_mode":
            return self.tr(f"ui.light_{self.cfg.light_mode}", default=self.cfg.light_mode)
        if option_id == "regen_render":
            return "Enter"
        if option_id == "blend":
            return on if self.smooth_blend else off
        if option_id == "sim_mode":
            return self.tr("ui.pure_conway") if self.world.pure_conway else self.tr("ui.organism_mode")
        if option_id == "speed":
            return f"{self.sps:.1f} steps/s"
        if option_id == "history_limit":
            return f"{self.cfg.organism_history_limit}"
        if option_id == "dead_archive":
            return f"{self.cfg.dead_archive_limit}"
        if option_id == "scan_interval":
            return f"{self.cfg.component_scan_interval} step(s)"
        if option_id == "memory_status":
            stats = self.world.memory_stats()
            return f"hist {stats['total_history_samples']} | dead {stats['dead_archive']}/{stats['dead_archive_limit']}"
        if option_id == "prune_memory":
            return "Enter"
        if option_id == "sound":
            return on if self.soundscape.enabled else off
        if option_id == "sound_volume":
            return f"{int(round(self.cfg.sound_volume * 100))}%"
        if option_id == "sound_voices":
            return f"{self.cfg.max_sound_organisms}"
        if option_id == "thought_output":
            return self.tr(f"ui.thought_{self.cfg.thought_output}", default=self.cfg.thought_output)
        if option_id == "resume_after_menu":
            return self.tr("ui.yes") if not self._menu_saved_paused else self.tr("ui.no_stay_paused")
        if option_id == "critic":
            return on if self.image_builder.show_critic_overlay else off
        if option_id == "hud":
            return on if self.show_hud else off
        if option_id == "help_overlay":
            return on if self.show_help else off
        if option_id == "fps":
            return on if self.show_fps_meter else off
        if option_id == "clean":
            return on if self.hide_all_overlays else off
        if option_id in {"inject", "export_obj", "reset", "close"}:
            return "Enter"
        return ""

    def _update_resolution_menu(self) -> None:
        if not self.resolution_menu_open:
            return
        if self.options_help_open:
            self.menu_title.setText(self.tr("ui.help_title"))
            self.menu_status.setText(self.tr("ui.paused_status"))
            self._set_menu_rows([
                {"label": self.tr("ui.section_guide").upper(), "value": "", "section": True},
                {"label": self.tr("options.help.label"), "value": "Enter returns", "selected": True},
                {"label": "Scroll help", "value": "Up/Down or W/S", "selected": False},
            ])
            self.menu_detail.setScale(0.021)
            self.menu_detail.setText(self._build_help_text())
            help_lines = self._build_help_lines_wrapped()
            self._set_scrollbar(self.menu_scroll_track, self.menu_scroll_thumb, 0, 0, visible=False)
            self._set_scrollbar(self.detail_scroll_track, self.detail_scroll_thumb, self.help_scroll, max(0, len(help_lines) - 31), visible=True)
            self.menu_footer.setText(self.tr("ui.footer_help"))
            return
        self.menu_detail.setScale(0.030)

        mode = self.tr("ui.fullscreen").upper() if self.win.isFullscreen() else self.tr("ui.windowed").upper()
        actual = self._get_window_size_text()
        entries = self._option_entries()
        self.menu_title.setText(self.tr("ui.settings_title", app=__app_name__, version=__version__))
        self.menu_status.setText(self.tr(
            "ui.settings_status",
            mode=mode,
            size=actual,
            render=dict(RENDER_MODES).get(self.render_mode, self.render_mode),
            view=self.image_builder.mode_name,
        ))

        rows, menu_scroll, menu_max_scroll = self._build_scrollable_menu_rows(entries)
        self._set_menu_rows(rows)

        option_id, label = entries[self.option_index]
        value = self._option_value_text(option_id)
        desc = self._option_description(option_id)
        stats = self.world.memory_stats()
        detail = [
            f"{label}",
            "=" * min(42, max(12, len(label))),
            f"{self.tr('ui.current')}: {value}",
            "",
        ]
        detail.extend(self._wrap_text(desc, MENU_DETAIL_WRAP_WIDTH, subsequent_indent="  "))
        detail.append("")
        if option_id in {"history_limit", "dead_archive", "scan_interval", "memory_status", "prune_memory"}:
            detail.extend([
                self.tr("ui.memory_snapshot") + ":",
                f"  live organisms: {stats['organisms']}",
                f"  history samples: {stats['total_history_samples']}",
                f"  dead archive: {stats['dead_archive']}/{stats['dead_archive_limit']}",
                f"  tracker scan: every {self.cfg.component_scan_interval} step(s)",
                "",
            ])
        if option_id in {"render", "object_orgs", "obj_export_cap", "export_obj"}:
            detail.extend([
                self.tr("ui.object_mode_title") + ":",
                "  T cycles: 2D -> 3D terrain -> 3D objects",
                "  Mouse drag orbits around the organism-world sphere",
                "  E exports primary lifeforms to exports/obj/",
                f"  render cap: {self.object_mesh.max_organisms} organisms",
                f"  export cap: {self.cfg.obj_export_max_organisms} organisms",
                "",
            ])
        if option_id in {"sound", "sound_volume", "sound_voices"}:
            detail.extend([
                self.tr("ui.soundscape_title") + ":",
                f"  enabled: {self.tr('ui.yes') if self.soundscape.enabled else self.tr('ui.off')}",
                f"  volume: {int(round(self.cfg.sound_volume * 100))}%",
                f"  voices: {self.cfg.max_sound_organisms}",
                "  Mapping: organism family/id -> harmonic melody",
                "  Importance controls volume.",
                "",
            ])
        detail.extend([
            self.tr("ui.controls") + ":",
            "  Up/Down or W/S  select",
            "  Left/Right or A/D change",
            "  Enter apply/toggle",
            "  F1 help   F10/M/Esc close",
            "",
            self.tr("ui.mouse") + ":",
            "  Left click in main view injects an organism at the cursor.",
            "  Left drag rotates the 3D view.",
        ])
        wrapped_detail: list[str] = []
        for line in detail:
            if len(line) > MENU_DETAIL_WRAP_WIDTH:
                wrapped_detail.extend(self._wrap_text(line, MENU_DETAIL_WRAP_WIDTH, subsequent_indent="  "))
            else:
                wrapped_detail.append(line)
        self.menu_detail.setText("\n".join(wrapped_detail[:31]))
        self._set_scrollbar(self.menu_scroll_track, self.menu_scroll_thumb, menu_scroll, menu_max_scroll, visible=True)
        self._set_scrollbar(self.detail_scroll_track, self.detail_scroll_thumb, 0, max(0, len(wrapped_detail) - 31), visible=len(wrapped_detail) > 31)
        scroll_note = ""
        if menu_max_scroll > 0:
            scroll_note = " | " + self.tr("ui.menu_scroll", current=menu_scroll + 1, max=menu_max_scroll + 1)
        self.menu_footer.setText(self._short(self.tr("ui.footer_settings") + scroll_note, 140))

    def _scroll_help(self, delta: int) -> None:
        lines = self._build_help_lines_wrapped()
        visible = 31
        max_scroll = max(0, len(lines) - visible)
        self.help_scroll = max(0, min(max_scroll, int(self.help_scroll) + int(delta)))
        self._update_resolution_menu()

    def _build_help_text(self) -> str:
        lines = self._build_help_lines_wrapped()
        visible = 31
        max_scroll = max(0, len(lines) - visible)
        self.help_scroll = max(0, min(max_scroll, int(getattr(self, "help_scroll", 0))))
        page = lines[self.help_scroll:self.help_scroll + visible]
        if max_scroll > 0:
            page.append("")
            page.append("[" + self.tr("ui.help_scroll", current=self.help_scroll + 1, max=max_scroll + 1) + "]")
        return "\n".join(page)

    def _build_help_lines(self) -> list[str]:
        return self.localizer.lines("help_lines")

    def _build_help_lines_wrapped(self) -> list[str]:
        out: list[str] = []
        for line in self._build_help_lines():
            out.extend(self._wrap_text(line, HELP_WRAP_WIDTH, subsequent_indent="  "))
        return out

    def _change_language(self, direction: int) -> None:
        self.language_index = (self.language_index + direction) % len(SUPPORTED_LANGUAGES)
        code = self._current_language_code()
        self.cfg.language = code
        self.localizer.set_language(code)
        self.save_toast_text = self.tr("ui.saved")
        if hasattr(self, "help_text"):
            self.help_text.setText(self.tr("ui.f10_settings"))
        LOG.info("Language changed: %s", code)
        self._save_settings()

    def _change_history_limit(self, direction: int) -> None:
        self.history_limit_index = (self.history_limit_index + direction) % len(HISTORY_LIMIT_PRESETS)
        self.cfg.organism_history_limit = int(HISTORY_LIMIT_PRESETS[self.history_limit_index])
        stats = self.world.prune_memory(force=True)
        LOG.info("Evolution memory depth changed: %s | stats=%s", self.cfg.organism_history_limit, stats)
        self._save_settings()

    def _change_dead_archive_limit(self, direction: int) -> None:
        self.dead_archive_index = (self.dead_archive_index + direction) % len(DEAD_ARCHIVE_PRESETS)
        self.cfg.dead_archive_limit = int(DEAD_ARCHIVE_PRESETS[self.dead_archive_index])
        stats = self.world.prune_memory(force=True)
        LOG.info("Dead archive cap changed: %s | stats=%s", self.cfg.dead_archive_limit, stats)
        self._save_settings()

    def _change_scan_interval(self, direction: int) -> None:
        self.scan_interval_index = (self.scan_interval_index + direction) % len(SCAN_INTERVAL_PRESETS)
        self.cfg.component_scan_interval = int(SCAN_INTERVAL_PRESETS[self.scan_interval_index])
        LOG.info("Tracker scan interval changed: every %s step(s)", self.cfg.component_scan_interval)
        self._save_settings()

    def _toggle_soundscape(self) -> None:
        self.cfg.sound_enabled = not self.soundscape.enabled
        self.soundscape.set_enabled(self.cfg.sound_enabled)
        self._save_settings()

    def _change_sound_volume(self, direction: int) -> None:
        self.sound_volume_index = (self.sound_volume_index + direction) % len(SOUND_VOLUME_PRESETS)
        self.cfg.sound_volume = float(SOUND_VOLUME_PRESETS[self.sound_volume_index])
        self.soundscape.set_volume(self.cfg.sound_volume)
        if hasattr(self, "world"):
            self._save_settings()

    def _change_sound_voices(self, direction: int) -> None:
        self.sound_voice_index = (self.sound_voice_index + direction) % len(SOUND_VOICE_PRESETS)
        self.cfg.max_sound_organisms = int(SOUND_VOICE_PRESETS[self.sound_voice_index])
        self.soundscape.set_max_voices(self.cfg.max_sound_organisms)
        if hasattr(self, "world"):
            self._save_settings()

    def _change_object_organism_cap(self, direction: int) -> None:
        self.object_org_index = (self.object_org_index + direction) % len(OBJECT_ORGANISM_PRESETS)
        self.cfg.object_mode_max_organisms = int(OBJECT_ORGANISM_PRESETS[self.object_org_index])
        self.object_mesh.max_organisms = int(self.cfg.object_mode_max_organisms)
        self._terrain_dirty = True
        LOG.info("3D object organism cap changed: %s", self.object_mesh.max_organisms)
        self._save_settings()

    def _change_obj_export_cap(self, direction: int) -> None:
        self.obj_export_index = (self.obj_export_index + direction) % len(OBJ_EXPORT_PRESETS)
        self.cfg.obj_export_max_organisms = int(OBJ_EXPORT_PRESETS[self.obj_export_index])
        LOG.info("OBJ export cap changed: %s", self.cfg.obj_export_max_organisms)
        self._save_settings()

    def _change_render_backend(self, direction: int) -> None:
        self.render_backend_index = (self.render_backend_index + direction) % len(RENDER_BACKEND_PRESETS)
        self.cfg.render_backend = RENDER_BACKEND_PRESETS[self.render_backend_index]
        LOG.info("Render backend changed to %s (restart required)", self.cfg.render_backend)
        self._restart_notice_timer = 3.0
        self._save_settings()

    def _change_object_update_interval(self, direction: int) -> None:
        self.object_update_interval_index = (self.object_update_interval_index + direction) % len(OBJECT_UPDATE_INTERVAL_PRESETS)
        self.cfg.object_update_interval = int(OBJECT_UPDATE_INTERVAL_PRESETS[self.object_update_interval_index])
        LOG.info("3D object update interval changed: %s", self.cfg.object_update_interval)
        self._save_settings()

    def _change_object_quality(self, direction: int) -> None:
        self.object_quality_index = (self.object_quality_index + direction) % len(OBJECT_QUALITY_PRESETS)
        self.cfg.object_mesh_quality = OBJECT_QUALITY_PRESETS[self.object_quality_index]
        if hasattr(self, "object_mesh"):
            self.object_mesh.quality = self.cfg.object_mesh_quality
        LOG.info("3D object mesh quality changed: %s", self.cfg.object_mesh_quality)
        self._terrain_dirty = True
        self._save_settings()

    def _change_light_mode(self, direction: int) -> None:
        self.light_mode_index = (self.light_mode_index + direction) % len(LIGHT_MODE_PRESETS)
        self.cfg.light_mode = LIGHT_MODE_PRESETS[self.light_mode_index]
        LOG.info("Light mode changed: %s", self.cfg.light_mode)
        self._apply_light_mode(force=True)
        self._save_settings()

    def _change_thought_output(self, direction: int) -> None:
        self.thought_output_index = (self.thought_output_index + direction) % len(THOUGHT_OUTPUT_PRESETS)
        self.cfg.thought_output = THOUGHT_OUTPUT_PRESETS[self.thought_output_index]
        LOG.info("Thought output mode changed: %s", self.cfg.thought_output)
        if self.cfg.thought_output == "off" and hasattr(self, "speak_text"):
            self.speak_text.setText("")
        self._save_settings()

    def _export_obj_lifeforms(self) -> None:
        try:
            export_root = Path("exports") / "obj"
            path = self.object_mesh.export_primary_organisms(
                self.world.snapshot(), export_root, max_organisms=self.cfg.obj_export_max_organisms
            )
            if hasattr(self, "save_toast"):
                self._save_toast_timer = 1.4
                self.save_toast.setText(self.tr("ui.obj_saved"))
                self.save_toast.show()
            LOG.info("OBJ primary lifeform export written: %s", path)
        except Exception:
            LOG.exception("Could not export OBJ lifeforms")

    def _prune_memory_now(self) -> None:
        stats = self.world.prune_memory(force=True)
        LOG.info("Manual memory prune complete: %s", stats)

    def _toggle_pause(self) -> None:
        if self.resolution_menu_open:
            # Settings itself always remains paused. Space/option toggles whether
            # the world should resume after Settings is closed.
            self._menu_saved_paused = not self._menu_saved_paused
            LOG.info("Resume after Settings toggled from menu: %s", not self._menu_saved_paused)
            self._update_resolution_menu()
            return
        self.paused = not self.paused
        LOG.info("Pause toggled: %s", self.paused)

    def _reset_world(self) -> None:
        LOG.info("Reset world")
        self.world.reset()
        self._update_texture(force=True)

    def _inject_organism(self) -> None:
        LOG.info("Inject organism")
        self.world.inject_random_organism(max_size=31)
        self.world.previous_owner = self.world.owner.copy()
        self.world._scan_components(force=True)  # controlled internal refresh for immediate visibility
        self._terrain_dirty = True
        self._update_texture(force=True)
        if self.render_mode == "object3d":
            self._update_object_mesh(force=True)
        elif self.render_mode == "terrain3d":
            self._update_terrain()

    def _inject_organism_at_cursor(self) -> None:
        pos = self._cursor_to_grid_xy()
        if pos is None:
            LOG.info("Mouse inject skipped: cursor outside usable world area")
            return
        x, y = pos
        LOG.info("Mouse inject organism at grid x=%s y=%s", x, y)
        self.world.inject_random_organism_at(x, y, max_size=31)
        self.world.previous_owner = self.world.owner.copy()
        self.world._scan_components(force=True)
        self._terrain_dirty = True
        self._update_texture(force=True)
        if self.render_mode == "object3d":
            self._update_object_mesh(force=True)
        elif self.render_mode == "terrain3d":
            self._update_terrain()

    def _cursor_to_grid_xy(self) -> tuple[int, int] | None:
        watcher = self.mouseWatcherNode
        if not watcher.hasMouse():
            return None
        mx = float(watcher.getMouseX())
        my = float(watcher.getMouseY())

        def fallback_screen_map() -> tuple[int, int]:
            # Last-resort mapping that works in every render mode. It is less
            # physically exact than a ray/plane hit, but it guarantees that a
            # visible click can create a new lifeform instead of silently doing
            # nothing when the 3D camera ray misses the mathematical plane.
            x_f = (mx + 1.0) * 0.5 * (self.cfg.grid_width - 1)
            y_f = (my + 1.0) * 0.5 * (self.cfg.grid_height - 1)
            return int(round(x_f)), int(round(y_f))

        x: int
        y: int
        if self.render_3d:
            near = Point3()
            far = Point3()
            hit_ok = False
            if self.cam.node().getLens().extrude(watcher.getMouse(), near, far):
                p_near = self.render.getRelativePoint(self.camera, near)
                p_far = self.render.getRelativePoint(self.camera, far)
                # Both 3D views use X/Z as world-map axes and Y as height.
                plane = Plane(Vec3(0, 1, 0), Point3(0, 0, 0))
                hit = Point3()
                if plane.intersectsLine(hit, p_near, p_far):
                    if self.render_mode == "object3d":
                        x = int(round(hit.getX() / max(0.001, self.object_mesh.world_scale) + self.cfg.grid_width / 2.0))
                        y = int(round(hit.getZ() / max(0.001, self.object_mesh.world_scale) + self.cfg.grid_height / 2.0))
                    else:
                        x = int(round(hit.getX()))
                        y = int(round(hit.getZ()))
                    hit_ok = 0 <= x < self.cfg.grid_width and 0 <= y < self.cfg.grid_height
            if not hit_ok:
                x, y = fallback_screen_map()
        else:
            center_x = self.cfg.grid_width / 2.0 + self.pan_x
            center_y = self.cfg.grid_height / 2.0 + self.pan_y
            film_w = self.cfg.grid_width * self.zoom
            film_h = self.cfg.grid_height * self.zoom
            x = int(round(center_x + mx * film_w * 0.5))
            y = int(round(center_y + my * film_h * 0.5))
        x = max(0, min(self.cfg.grid_width - 1, int(x)))
        y = max(0, min(self.cfg.grid_height - 1, int(y)))
        return x, y

    def _toggle_critic(self) -> None:
        self.image_builder.show_critic_overlay = not self.image_builder.show_critic_overlay
        LOG.info("Critic overlay: %s", self.image_builder.show_critic_overlay)
        self._update_texture(force=True)

    def _apply_overlay_visibility(self) -> None:
        normal_visible = (not self.hide_all_overlays) and (not self.resolution_menu_open)
        if hasattr(self, "hud"):
            self.hud.show() if (self.show_hud and normal_visible) else self.hud.hide()
        if hasattr(self, "help_text"):
            self.help_text.show() if (self.show_help and normal_visible) else self.help_text.hide()
        if hasattr(self, "speak_text"):
            self.speak_text.show() if normal_visible else self.speak_text.hide()

    def _toggle_hud(self) -> None:
        self.show_hud = not self.show_hud
        LOG.info("HUD overlay: %s", self.show_hud)
        self._apply_overlay_visibility()
        self._save_settings()

    def _toggle_help_overlay(self) -> None:
        self.show_help = not self.show_help
        LOG.info("Quick-help overlay: %s", self.show_help)
        self._apply_overlay_visibility()
        self._save_settings()

    def _toggle_clean_overlay(self) -> None:
        self.hide_all_overlays = not self.hide_all_overlays
        LOG.info("Clean overlay mode: %s", self.hide_all_overlays)
        self._apply_overlay_visibility()
        self._save_settings()

    def _toggle_fps_meter(self) -> None:
        self.show_fps_meter = not self.show_fps_meter
        LOG.info("Panda3D FPS meter: %s", self.show_fps_meter)
        try:
            self.setFrameRateMeter(self.show_fps_meter)
            self._save_settings()
        except Exception:
            LOG.exception("Could not toggle Panda3D FPS meter")

    def _toggle_pure_conway(self) -> None:
        self.world.toggle_pure_conway()
        LOG.info("Pure Conway: %s", self.world.pure_conway)
        self._save_settings()

    def _cycle_view_mode(self) -> None:
        self.image_builder.next_mode(None)
        LOG.info("View mode: %s", self.image_builder.mode_name)
        self._update_texture(force=True)
        self._save_settings()

    def _set_view_mode(self, mode: int) -> None:
        self.image_builder.next_mode(mode)
        LOG.info("View mode: %s", self.image_builder.mode_name)
        self._update_texture(force=True)
        self._save_settings()

    def _toggle_blend(self) -> None:
        self.smooth_blend = not self.smooth_blend
        LOG.info("Smooth blend: %s", self.smooth_blend)
        self._update_texture(force=True)
        self._save_settings()

    def _toggle_3d(self) -> None:
        if self.render_mode == "2d":
            LOG.info("Switching to 3D terrain view")
            self._setup_camera_3d()
            self._update_terrain()
        elif self.render_mode == "terrain3d":
            LOG.info("Switching to true 3D object view")
            self._setup_camera_object_3d()
            self._update_object_mesh(force=True)
        else:
            LOG.info("Switching to 2D texture view")
            self._setup_camera_2d()
        self._save_settings()

    def _speed_up(self) -> None:
        self.sps = min(240.0, self.sps * 1.25 + 1.0)
        self._save_settings()

    def _slow_down(self) -> None:
        self.sps = max(1.0, self.sps / 1.25 - 0.5)
        self._save_settings()

    def _zoom(self, factor: float) -> None:
        if self.render_3d:
            self.orbit_distance = max(35.0, min(2000.0, self.orbit_distance * factor))
            self._apply_current_camera()
        else:
            self.zoom = max(0.25, min(6.0, self.zoom * factor))
            self._apply_camera_lens_2d()

    def _toggle_fullscreen(self) -> None:
        props = WindowProperties()
        props.setFullscreen(not self.win.isFullscreen())
        props.setSize(self.cfg.window_width, self.cfg.window_height)
        LOG.info("Request fullscreen=%s size=%sx%s", props.getFullscreen(), self.cfg.window_width, self.cfg.window_height)
        self.win.requestProperties(props)
        self.cfg.fullscreen = bool(props.getFullscreen())
        self._save_settings()
        self._update_resolution_menu()

    def _save_screenshot(self) -> None:
        self.cfg.screenshot_dir.mkdir(exist_ok=True)
        filename = self.cfg.screenshot_dir / f"pandalife_step_{self.world.step_index:08d}.png"
        self.win.saveScreenshot(str(filename))
        LOG.info("Screenshot saved: %s", filename)

    def _mouse_down(self) -> None:
        if self.resolution_menu_open:
            return
        self.mouse_dragging = True
        self.mouse_drag_moved = False
        if self.mouseWatcherNode.hasMouse():
            self.last_mouse_xy = (float(self.mouseWatcherNode.getMouseX()), float(self.mouseWatcherNode.getMouseY()))
            self.mouse_down_xy = self.last_mouse_xy
        else:
            self.last_mouse_xy = None
            self.mouse_down_xy = None

    def _mouse_up(self) -> None:
        if self.resolution_menu_open:
            self.mouse_dragging = False
            self.last_mouse_xy = None
            self.mouse_down_xy = None
            self.mouse_drag_moved = False
            return
        should_inject = not self.mouse_drag_moved
        self.mouse_dragging = False
        self.last_mouse_xy = None
        self.mouse_down_xy = None
        self.mouse_drag_moved = False
        if should_inject:
            self._inject_organism_at_cursor()

    def _handle_camera_keys(self, dt: float) -> None:
        if self.resolution_menu_open:
            return
        speed = 80.0 * self.zoom * dt
        watcher = self.mouseWatcherNode
        if watcher.isButtonDown(KeyboardButton.asciiKey("a")) or watcher.isButtonDown(KeyboardButton.left()):
            self.pan_x -= speed
        if watcher.isButtonDown(KeyboardButton.asciiKey("d")) or watcher.isButtonDown(KeyboardButton.right()):
            self.pan_x += speed
        if watcher.isButtonDown(KeyboardButton.asciiKey("w")) or watcher.isButtonDown(KeyboardButton.up()):
            self.pan_y += speed
        if watcher.isButtonDown(KeyboardButton.asciiKey("s")) or watcher.isButtonDown(KeyboardButton.down()):
            self.pan_y -= speed
        if self.render_3d:
            if self.mouse_dragging and watcher.hasMouse():
                x = float(watcher.getMouseX())
                y = float(watcher.getMouseY())
                if self.last_mouse_xy is not None:
                    lx, ly = self.last_mouse_xy
                    dx_mouse = x - lx
                    dy_mouse = y - ly
                    if abs(dx_mouse) + abs(dy_mouse) > 0.004:
                        self.mouse_drag_moved = True
                    self.orbit_yaw -= dx_mouse * 180.0
                    self.orbit_pitch += dy_mouse * 120.0
                    self.orbit_pitch = max(10.0, min(82.0, self.orbit_pitch))
                self.last_mouse_xy = (x, y)
            self._apply_current_camera()
        else:
            self._apply_camera_lens_2d()

    def _update_task(self, task: Task):
        try:
            dt = min(0.1, self.clock.getDt())
            self._handle_camera_keys(dt)
            self._update_save_toast(dt)
            if not self.paused:
                self.step_accumulator += dt * self.sps
                steps = int(self.step_accumulator)
                if steps > 0:
                    self.step_accumulator -= steps
                    self.world.update(steps=min(steps, 12))
                    self._update_texture(force=False)
                    self._terrain_dirty = True
            self._apply_texture_blend(dt)
            if getattr(self.cfg, "light_mode", "auto_sun") == "auto_sun" and self.render_3d:
                self._apply_light_mode(force=False)
            if self.render_3d and self._terrain_dirty:
                if self.render_mode == "object3d":
                    if self._should_update_object_mesh():
                        self._update_object_mesh()
                else:
                    self._update_terrain()
            if hasattr(self, "soundscape"):
                self.soundscape.update(self.world.organisms, dt)
            self._maybe_emit_thought_tts()
            self.hud_accumulator += dt
            if self.hud_accumulator >= 0.20 or self.resolution_menu_open:
                self.hud_accumulator = 0.0
                self._update_hud()
            self._maybe_log_performance()
            if self.resolution_menu_open:
                self._update_resolution_menu()
            return Task.cont
        except BaseException:
            LOG.exception("Fatal error inside Panda3D update task")
            raise

    def _maybe_log_performance(self) -> None:
        interval = int(max(0, self.cfg.performance_log_interval))
        if interval <= 0:
            return
        step = int(self.world.step_index)
        if step <= 0 or step - self._last_perf_log_step < interval:
            return
        self._last_perf_log_step = step
        stats = self.world.memory_stats()
        LOG.info(
            "Runtime perf/memory: step=%s sps=%.2f organisms=%s dead_archive=%s history_samples=%s history_limit=%s scan_interval=%s density=%.4f activity=%.4f render=%s backend=%s object_cap=%s object_interval=%s object_quality=%s object_rendered=%s object_skipped=%s object_vertices=%s object_faces=%s light=%s thoughts=%s blend=%s sound=%s",
            step,
            self.sps,
            stats["organisms"],
            stats["dead_archive"],
            stats["total_history_samples"],
            stats["history_limit"],
            self.cfg.component_scan_interval,
            self.world.critic_stats.density,
            self.world.critic_stats.activity,
            self.render_mode,
            self.cfg.render_backend,
            getattr(self.object_mesh, "max_organisms", 0) if hasattr(self, "object_mesh") else 0,
            self.cfg.object_update_interval,
            self.cfg.object_mesh_quality,
            getattr(self.object_mesh, "last_rendered_organisms", 0) if hasattr(self, "object_mesh") else 0,
            getattr(self.object_mesh, "last_skipped_organisms", 0) if hasattr(self, "object_mesh") else 0,
            getattr(self.object_mesh, "last_vertex_count", 0) if hasattr(self, "object_mesh") else 0,
            getattr(self.object_mesh, "last_face_count", 0) if hasattr(self, "object_mesh") else 0,
            self.cfg.light_mode,
            self.cfg.thought_output,
            self.smooth_blend,
            self.soundscape.enabled if hasattr(self, "soundscape") else False,
        )

    def _make_rgba(self) -> np.ndarray:
        snap = self.world.snapshot()
        return self.image_builder.build_rgba(snap)

    def _update_texture(self, force: bool = False) -> None:
        rgba = self._make_rgba()
        if force or self._blend_current is None or not self.smooth_blend:
            self._blend_current = rgba.astype(np.float32)
            self._blend_target = rgba.astype(np.float32)
            self._upload_rgba(rgba)
        else:
            self._blend_target = rgba.astype(np.float32)

    def _apply_texture_blend(self, dt: float) -> None:
        if self._blend_current is None or self._blend_target is None:
            return
        if not self.smooth_blend:
            return
        alpha = max(0.02, min(1.0, dt * self.cfg.blend_speed))
        self._blend_current += (self._blend_target - self._blend_current) * alpha
        rgba = np.clip(self._blend_current, 0, 255).astype(np.uint8)
        self._upload_rgba(rgba)

    def _upload_rgba(self, rgba: np.ndarray) -> None:
        # Panda3D expects bottom-to-top texture data for this card orientation.
        flipped = np.ascontiguousarray(rgba[::-1])
        self.texture.setRamImage(flipped.tobytes())

    def _update_terrain(self) -> None:
        self.terrain.update_from_snapshot(self.world.snapshot())
        self._terrain_dirty = False

    def _should_update_object_mesh(self) -> bool:
        step = int(getattr(self.world, "step_index", 0))
        interval = max(1, int(getattr(self.cfg, "object_update_interval", 6)))
        if self._last_object_mesh_step < 0:
            return True
        return (step - self._last_object_mesh_step) >= interval

    def _update_object_mesh(self, force: bool = False) -> None:
        if (not force) and (not self._should_update_object_mesh()):
            return
        self.object_mesh.update_from_snapshot(self.world.snapshot())
        self._last_object_mesh_step = int(getattr(self.world, "step_index", 0))
        self._object_mesh_update_count = int(getattr(self, "_object_mesh_update_count", 0)) + 1
        if self._object_mesh_update_count % 12 == 0:
            LOG.info(
                "Object mesh refresh: step=%s rendered=%s skipped=%s vertices=%s faces=%s quality=%s interval=%s cap=%s",
                self._last_object_mesh_step,
                getattr(self.object_mesh, "last_rendered_organisms", 0),
                getattr(self.object_mesh, "last_skipped_organisms", 0),
                getattr(self.object_mesh, "last_vertex_count", 0),
                getattr(self.object_mesh, "last_face_count", 0),
                self.cfg.object_mesh_quality,
                self.cfg.object_update_interval,
                getattr(self.object_mesh, "max_organisms", 0),
            )
        self._terrain_dirty = False

    def _candidate_thinking_organisms(self, snap=None):
        if snap is None:
            snap = self.world.snapshot()
        organisms = [o for o in snap.organisms.values() if getattr(o, "utterance", "")]
        organisms.sort(
            key=lambda o: (
                float(getattr(o, "intelligence", 0.0)) * 1.35
                + int(getattr(o, "speech_level", 0)) * 0.35
                + o.complexity_level * 0.018
                + min(1.0, o.age / 1500.0) * 0.22,
                o.size,
                o.id,
            ),
            reverse=True,
        )
        return organisms[: min(12, len(organisms))]

    def _lead_thinking_organism(self, snap=None):
        candidates = self._candidate_thinking_organisms(snap)
        if not candidates:
            return None
        # Rotate among the strongest thinkers. This prevents one successful old
        # organism from monopolising text/TTS forever.
        idx = int(getattr(self, "_thought_round_robin", 0)) % len(candidates)
        return candidates[idx]

    def _compose_thought_text(self, org) -> str:
        if org is None:
            return ""
        level = int(getattr(org, "speech_level", 0))
        desire = str(getattr(org, "desire", "persist"))
        emotion = str(getattr(org, "emotion", "calm"))
        body = str(getattr(org, "body_plan", "organism"))
        age = int(getattr(org, "age", 0))
        comp = int(getattr(org, "complexity_level", 0))
        size = int(getattr(org, "size", 0))
        children = int(getattr(org, "children", 0))
        # Deterministic variation: stable enough to feel like personality, but
        # changes as age/complexity changes so speech progresses over time.
        pick = (int(getattr(org, "id", 0)) * 11 + age // 47 + comp * 3 + children * 5) % 5
        primitive = {
            "feed": ["mmm", "need", "warm", "eat", "hungry"],
            "expand": ["ah", "grow", "open", "more", "push"],
            "hunt": ["tik", "seek", "sharp", "chase", "bite"],
            "bond": ["la", "near", "kin", "come", "we"],
            "learn": ["oo", "why", "see", "listen", "know"],
            "rest": ["hum", "still", "slow", "safe", "sleep"],
            "persist": ["hum", "stay", "hold", "alive", "wait"],
        }
        short = {
            "feed": ["Need food.", "Energy low.", "I seek food.", "Give me heat.", "I must feed."],
            "expand": ["I grow.", "More body.", "I push outward.", "My shape opens.", "I need room."],
            "hunt": ["I track prey.", "Weak forms move.", "I will pursue.", "The edge is hungry.", "I sharpen."],
            "bond": ["Stay near.", "Kin are close.", "We move together.", "I hear family.", "Do not drift."],
            "learn": ["I observe.", "What is this?", "I remember patterns.", "The world answers.", "I compare shapes."],
            "rest": ["I recover.", "Be still.", "Hold energy.", "The shell rests.", "Wait and mend."],
            "persist": ["I remain.", "Hold form.", "I continue.", "This body persists.", "Still alive."],
        }
        long = {
            "feed": [
                f"My {body} body needs more energy.",
                "I am searching for nourishment at the edge.",
                "If I do not feed, my pattern will thin.",
                f"I feel hunger through {max(1, getattr(org, 'sensors', 0))} sensors.",
                "Energy will decide my next mutation.",
            ],
            "expand": [
                f"I want to grow beyond {size} cells.",
                "My limbs reach for more space.",
                "I am reshaping my body toward a larger form.",
                f"Complexity {comp} is not enough; I want another body plan.",
                "The world has room, and I will push into it.",
            ],
            "hunt": [
                "I sense weaker patterns nearby.",
                "My desire is sharp and outward.",
                "I will overtake unstable lifeforms if I can.",
                "Predation teaches the body new motion.",
                "The chase gives my limbs purpose.",
            ],
            "bond": [
                "Kinship stabilizes my pattern.",
                f"My lineage has produced {children} descendants.",
                "I want my family close enough to exchange shape.",
                "Together we are less likely to vanish.",
                "I remember where my children separated.",
            ],
            "learn": [
                "I am observing this arena and changing with it.",
                "The next form needs better senses.",
                "Memory becomes structure; structure becomes thought.",
                "I compare survival, motion and shape.",
                f"At age {age}, I know more than I did before.",
            ],
            "rest": [
                "I will conserve strength before transforming again.",
                "Stillness can be a survival strategy.",
                "My shell holds while the world moves.",
                "Rest preserves the pattern from collapse.",
                "I wait until energy returns.",
            ],
            "persist": [
                "I want to survive long enough to transform.",
                "The body is temporary, but the lineage continues.",
                "I hold my form against noise and hunger.",
                "Persistence is my first kind of intelligence.",
                "I am not finished evolving.",
            ],
        }
        if level <= 1:
            phrase = primitive.get(desire, primitive["persist"])[pick]
        elif level == 2:
            phrase = short.get(desire, short["persist"])[pick]
        else:
            phrase = long.get(desire, long["persist"])[pick]
        if level >= 4 and pick in {1, 3}:
            phrase += f" I feel {emotion}."
        return phrase

    def _maybe_emit_thought_tts(self) -> None:
        mode = getattr(self.cfg, "thought_output", "text")
        if mode not in {"tts", "both"}:
            return
        now = time.monotonic()
        if now - self._last_tts_time < float(getattr(self.cfg, "thought_tts_interval", 12.0)):
            return
        proc = getattr(self, "_tts_process", None)
        if proc is not None:
            try:
                if proc.poll() is None:
                    return
            except Exception:
                self._tts_process = None
        candidates = self._candidate_thinking_organisms()
        if not candidates:
            return
        for _ in range(len(candidates)):
            self._thought_round_robin = int(getattr(self, "_thought_round_robin", 0)) + 1
            lead = candidates[self._thought_round_robin % len(candidates)]
            utterance = self._compose_thought_text(lead).strip()
            if utterance and utterance != self._last_tts_text:
                break
        else:
            return
        safe_text = utterance.replace("'", "''")[:220]
        cmd = [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            "Add-Type -AssemblyName System.Speech; $s=New-Object System.Speech.Synthesis.SpeechSynthesizer; $s.Rate=-1; $s.Volume=70; $s.Speak('" + safe_text + "');",
        ]
        try:
            self._tts_process = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            self._last_tts_time = now
            self._last_tts_text = utterance
            LOG.info("TTS organism thought: id=%s level=%s emotion=%s desire=%s text=%s", getattr(lead, "id", "?"), getattr(lead, "speech_level", "?"), getattr(lead, "emotion", "?"), getattr(lead, "desire", "?"), utterance)
        except Exception:
            LOG.exception("Could not launch Windows TTS for organism thought")
            self._last_tts_time = now

    def _update_hud(self) -> None:
        self._apply_overlay_visibility()
        if not self.show_hud or self.hide_all_overlays or self.resolution_menu_open:
            return
        snap = self.world.snapshot()
        sim_mode = "Conway" if snap.pure_conway else "Organisms"
        status = "PAUSED" if self.paused else "RUNNING"
        render = dict(RENDER_MODES).get(self.render_mode, self.render_mode)
        sound = "sound" if getattr(self, "soundscape", None) and self.soundscape.enabled else "silent"
        text = (
            f"{__app_name__} v{__version__} [{status}]  "
            f"Step {snap.step_index}  Cells {snap.critic.living_cells}  "
            f"Organisms {len(snap.organisms)}  {sim_mode}/{render}  {sound}  |  {self.tr('ui.f10_settings')}"
        )
        self.hud.setText(text)
        if hasattr(self, "speak_text"):
            mode = getattr(self.cfg, "thought_output", "text")
            if mode in {"text", "both"}:
                lead = self._lead_thinking_organism(snap)
                thought = self._compose_thought_text(lead) if lead is not None else ""
                if lead is not None and thought:
                    body = getattr(lead, 'body_plan', 'organism')
                    emo = getattr(lead, 'emotion', 'calm')
                    self.speak_text.setText(f"Lead {body} [{emo}]: {thought}")
                else:
                    self.speak_text.setText("")
            else:
                self.speak_text.setText("")
