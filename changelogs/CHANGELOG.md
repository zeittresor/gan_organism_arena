# Changelog

## v0.2.3

- Added explicit MIT License references to README/docs and kept `LICENSE.txt` as the canonical license file.
- Kept the root README and full docs in English as the canonical project documentation language.
- Added editable runtime language files under `language\`:
  - `language\en.json`
  - `language\de.json`
  - `language\fr.json`
- Added a **Language** option in Settings.
  - Default language is English.
  - Current language is persisted in `settings\config.json`.
  - Missing translation keys fall back to English.
- Added a small JSON-backed localization layer for menu/help text.
- Made the Settings options list vertically scrollable so lower menu items remain inside the panel.
- Expanded the built-in Help / Key Reference into a project explanation:
  - explains the purpose of the application,
  - explains Game of Life basics,
  - explains the difference between Pure Conway and Organism Mode,
  - explains every settings category and option,
  - explains hotkeys, mouse controls, output folders and license.
- Added CLI option `--language en|de|fr`.
- Updated version metadata to v0.2.3.

# Changelog

## v0.2.2

- Reorganized project documentation and diagnostics folders.
  - Main changelog is now stored under `changelogs\CHANGELOG.md`.
  - Extended documentation is stored under `docs\`.
  - Installer logs now go to `logs\install\`.
  - Runtime logs continue to go to `logs\`.
- Updated the Windows installer to create and reuse a local `.venv` automatically in the program directory.
- Added automatic local `wheelhouse\` handling.
  - Installer tries to populate the wheelhouse with dependency wheels.
  - Repeated installs prefer local wheels when available.
  - If the wheelhouse is missing or incomplete, the installer falls back to normal online pip installation.
- Updated README/project layout to reflect the new folder structure.
- Updated version metadata to v0.2.2.

## v0.2.1

- Fixed a crash when switching to 3D terrain/object mode from Settings or when restarting with a persisted 3D render mode.
  - The camera dispatcher no longer recursively calls itself in `terrain3d`.
- Improved menu cursor/font behavior.
  - Windows font paths are now passed through Panda3D `Filename.fromOsSpecific`.
  - If emoji/symbol fonts still cannot be loaded, Settings falls back to safe ASCII symbols instead of displaying square boxes.
- Expanded the built-in Help page so all Settings options and main hotkeys are explained.
- Added vertical scrolling for the Help page using Up/Down or W/S.
- Updated version metadata and diagnostics for v0.2.1.

## v0.2.0

- Added a third render mode: **3D Objects**.
  - `T` now cycles: `2D texture -> 3D terrain -> 3D objects -> 2D texture`.
  - The original 2D and 3D terrain modes are kept unchanged.
- Added true 3D organism meshes in object mode.
  - Primary organisms are converted into evolving organic 3D structures.
  - The mesh generator uses organism size, age, energy, genome, body plan, sensors, eyes, limbs, manipulators and armor.
  - Shapes are built as real x/y/z meshes, not as a flat height map.
- Added mouse-orbit camera for object mode.
  - Left-drag rotates around the organism-world center like orbiting a sphere.
  - Mouse wheel changes orbit distance.
  - WASD/arrow keys move the orbit target slightly.
- Added OBJ export.
  - Press `E` to export current primary lifeforms.
  - Settings menu contains `Export OBJ lifeforms`, `OBJ export cap`, and `3D object organism cap`.
  - Exports are written to `exports\obj\step_XXXXXXXX\`.
  - Each primary lifeform gets its own `.obj`/`.mtl` pair plus a combined `all_primary_lifeforms.obj` scene.
- Added persistent settings for:
  - `render_mode`
  - `object_mode_max_organisms`
  - `obj_export_max_organisms`
- Added CLI options:
  - `--render-mode 2d|terrain3d|object3d`
  - `--object-mode-max-organisms N`
  - `--obj-export-max-organisms N`
- Updated Settings and Help text for 3D object mode and OBJ export.

## v0.1.9

- Selection cursor in Settings uses `👉`.
- Save feedback displays `✔ Saved` for about one second.
- Windows symbol/emoji font loading improved for menu glyphs.

## v0.1.8

- Settings are saved to `settings\config.json`.
- Default resolution changed to 1920×1080 Full HD.
- Soundscape defaults to enabled on new installations.
- Left-click injection at mouse cursor added.
- Settings menu column alignment improved.
