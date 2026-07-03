from __future__ import annotations

import argparse
import logging
import os
import platform
import sys
from pathlib import Path

from . import __app_name__, __version__
from .app_config import AppConfig
from .runtime_logging import flush_runtime_logging, setup_runtime_logging


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=f"{__app_name__} {__version__}")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--fullscreen", action="store_true", help="Start in fullscreen mode.")
    mode.add_argument("--windowed", action="store_true", help="Start in a window.")
    parser.add_argument("--safe-render", action="store_true", help="Use conservative Panda3D render settings.")
    parser.add_argument("--force-windowed-safe", action="store_true", help="Force windowed mode when --safe-render is used.")
    parser.add_argument("--grid", default=None, help="Grid size, e.g. 128x128, 192x192 or 256x256.")
    parser.add_argument("--sps", type=float, default=None, help="Simulation steps per second.")
    parser.add_argument("--width", type=int, default=None, help="Window width for windowed mode.")
    parser.add_argument("--height", type=int, default=None, help="Window height for windowed mode.")
    parser.add_argument("--log-dir", default="logs", help="Directory for runtime logs.")
    parser.add_argument("--language", choices=["en", "de", "fr"], default=None, help="UI language: en, de or fr.")
    parser.add_argument("--no-fps", action="store_true", help="Disable Panda3D frame-rate meter.")
    parser.add_argument("--no-blend", action="store_true", help="Disable interpolated texture blending between simulation steps.")
    parser.add_argument("--blend-speed", type=float, default=None, help="Blend speed for anti-flicker interpolation.")
    parser.add_argument("--terrain-max-axis", type=int, default=None, help="Maximum sampled vertex count per axis for 3D terrain mode.")
    parser.add_argument("--history-limit", type=int, default=None, help="Per-organism evolution history depth kept in memory.")
    parser.add_argument("--dead-archive-limit", type=int, default=None, help="Maximum number of dead organism records retained.")
    parser.add_argument("--memory-prune-interval", type=int, default=None, help="Simulation steps between automatic memory pruning passes.")
    parser.add_argument("--sound", action="store_true", help="Start with the optional organism soundscape enabled.")
    parser.add_argument("--no-sound", action="store_true", help="Start with the optional organism soundscape disabled.")
    parser.add_argument("--sound-volume", type=float, default=None, help="Master volume for organism soundscape, 0.0 to 1.0.")
    parser.add_argument("--max-sound-organisms", type=int, default=None, help="Maximum number of organisms that can sound at the same time.")
    parser.add_argument("--render-mode", choices=["2d", "terrain3d", "object3d"], default=None, help="Start render mode: 2d, terrain3d or object3d.")
    parser.add_argument("--render-backend", choices=["auto", "opengl", "directx9", "software"], default=None, help="Panda3D display backend. Changes normally require restart.")
    parser.add_argument("--object-mode-max-organisms", type=int, default=None, help="Maximum active organisms shown as true 3D object meshes.")
    parser.add_argument("--object-update-interval", type=int, default=None, help="Simulation steps between true-3D object mesh rebuilds.")
    parser.add_argument("--object-mesh-quality", choices=["fast", "balanced", "detailed"], default=None, help="True-3D object mesh detail quality.")
    parser.add_argument("--light-mode", choices=["auto_sun", "top_left", "top_right", "bottom_left", "bottom_right", "left_mid", "right_mid", "center", "back"], default=None, help="Lighting direction preset.")
    parser.add_argument("--thought-output", choices=["off", "text", "tts", "both"], default=None, help="Show/hear organism thoughts: off, text, tts or both.")
    parser.add_argument("--obj-export-max-organisms", type=int, default=None, help="Maximum primary organisms exported per OBJ save action.")
    parser.add_argument("--self-test", action="store_true", help="Run a short non-graphical simulation test and exit.")
    return parser


def _run_self_test(cfg: AppConfig) -> int:
    from .render.image_builder import ImageBuilder
    from .simulation.world import LifeWorld

    logging.info("Running non-graphical self-test")
    cfg.grid_width = min(cfg.grid_width, 64)
    cfg.grid_height = min(cfg.grid_height, 64)
    cfg.initial_organisms = min(cfg.initial_organisms, 8)
    world = LifeWorld(cfg)
    for _ in range(24):
        world.update()
    snap = world.snapshot()
    rgba = ImageBuilder().build_rgba(snap)
    assert rgba.shape == (cfg.grid_height, cfg.grid_width, 4)
    assert rgba.dtype.name == "uint8"
    logging.info(
        "Self-test OK: step=%s cells=%s organisms=%s critic=%.3f",
        snap.step_index,
        snap.critic.living_cells,
        len(snap.organisms),
        snap.critic.score,
    )
    print("Self-test OK")
    return 0


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    args = build_arg_parser().parse_args(argv)
    cfg = AppConfig.from_args(args)

    # Keep all generated files inside the project directory, independent from the
    # console's original start path.
    Path("screenshots").mkdir(exist_ok=True)
    Path("settings").mkdir(exist_ok=True)
    cfg.screenshot_dir = Path("screenshots")
    Path(cfg.log_dir).mkdir(parents=True, exist_ok=True)
    log_path = setup_runtime_logging(cfg.log_dir)

    logging.info("Starting %s v%s", __app_name__, __version__)
    logging.info("Platform: %s", platform.platform())
    logging.info("Arguments: %s", argv)
    logging.info("Runtime log: %s", log_path)
    logging.info("Config: %s", cfg)

    try:
        if args.self_test:
            return _run_self_test(cfg)

        # Panda3D imports are delayed so command-line help, installer verification
        # and self-tests can run in environments where the engine is not yet installed
        # or where no display is available.
        from .render.panda_app import GANOrganismArenaApp

        app = GANOrganismArenaApp(cfg)
        logging.info("GANOrganismArenaApp constructed; entering Panda3D main loop")
        app.run()
        logging.info("Panda3D main loop ended normally")
        return 0
    except SystemExit:
        raise
    except BaseException:
        logging.exception("Fatal runtime error")
        print("\nFATAL: GAN Organism Arena crashed. See logs\\latest_runtime.log for details.", file=sys.stderr)
        return 1
    finally:
        flush_runtime_logging()


if __name__ == "__main__":
    raise SystemExit(main())
