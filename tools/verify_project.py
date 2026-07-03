from __future__ import annotations

import importlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))


def main() -> int:
    modules = [
        "pandalife_gan",
        "pandalife_gan.app_config",
        "pandalife_gan.runtime_logging",
        "pandalife_gan.localization",
        "pandalife_gan.simulation.conway",
        "pandalife_gan.simulation.world",
        "pandalife_gan.ai.pseudo_gan",
        "pandalife_gan.render.image_builder",
        "pandalife_gan.render.soundscape",
    ]
    for name in modules:
        importlib.import_module(name)
        print(f"OK import: {name}")

    # Panda3D render module is import-checked only if Panda3D is installed.
    try:
        importlib.import_module("pandalife_gan.render.object_mesh")
        print("OK import: pandalife_gan.render.object_mesh")
        importlib.import_module("pandalife_gan.render.panda_app")
        print("OK import: pandalife_gan.render.panda_app")
    except Exception as exc:
        print(f"ERROR importing Panda3D app module: {exc}")
        return 1

    # Non-graphical simulation smoke test. This catches array/logic errors without
    # requiring a desktop or GPU context.
    from pandalife_gan.app_config import AppConfig
    from pandalife_gan.render.image_builder import ImageBuilder
    from pandalife_gan.simulation.world import LifeWorld

    cfg = AppConfig(grid_width=64, grid_height=64, initial_organisms=8, organism_history_limit=32, dead_archive_limit=24, memory_prune_interval=8)
    world = LifeWorld(cfg)
    for _ in range(48):
        world.update()
    stats = world.memory_stats()
    if stats["dead_archive"] > cfg.dead_archive_limit:
        print(f"ERROR: dead archive exceeded limit: {stats}")
        return 1
    if stats["total_history_samples"] > (stats["organisms"] + stats["dead_archive"]) * cfg.organism_history_limit:
        print(f"ERROR: history samples exceeded configured limit: {stats}")
        return 1
    snap = world.snapshot()
    builder = ImageBuilder()
    for mode_index in range(len(builder.MODE_NAMES)):
        builder.next_mode(mode_index)
        rgba = builder.build_rgba(snap)
        if rgba.shape != (64, 64, 4):
            print(f"ERROR: unexpected image shape {rgba.shape} in mode {mode_index}")
            return 1

    # Regression check for v0.2.5+: high open-ended complexity must not overflow
    # uint8 colour conversion in any 2D view.
    if snap.organisms:
        first = next(iter(snap.organisms.values()))
        first.complexity_level = 160
        first.eyes = 40
        first.limbs = 40
        first.manipulators = 40
        first.armor = 1.0
        for mode_index in range(len(builder.MODE_NAMES)):
            builder.next_mode(mode_index)
            rgba = builder.build_rgba(snap)
            if rgba.dtype.name != "uint8" or rgba.shape != (64, 64, 4):
                print(f"ERROR: high-complexity render regression in mode {mode_index}: {rgba.shape} {rgba.dtype}")
                return 1
    print(
        f"OK self-test: step={snap.step_index} cells={snap.critic.living_cells} "
        f"organisms={len(snap.organisms)} view_modes={len(builder.MODE_NAMES)} memory={stats}"
    )

    import json
    for code in ("en", "de", "fr"):
        path = ROOT / "language" / f"{code}.json"
        if not path.exists():
            print(f"ERROR: missing language file {path}")
            return 1
        json.loads(path.read_text(encoding="utf-8"))
        print(f"OK language: {path.name}")

    print("Project verification complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
