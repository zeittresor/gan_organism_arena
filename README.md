# PandaLife GAN Organism Arena

Version **0.2.3**.

PandaLife GAN Organism Arena is an artificial-life sandbox built with Panda3D. It combines a Game-of-Life-inspired cellular world with organism tracking, genome-like traits, pseudo-GAN morphology generation, evolutionary scoring, optional harmonic sound, 2D/3D visualization, and OBJ export.

## Quick start

1. Run `install_windows.bat`.
2. Start later with `run_windows.bat`, `run_windowed.bat`, or `run_safe_windowed.bat`.
3. Open Settings/Help in the app with `F10` or `F1`.

## Project folders

- full documentation: `docs\README.md`
- design notes: `docs\DESIGN.md`
- changelog: `changelogs\CHANGELOG.md`
- runtime logs: `logs\`
- installer logs: `logs\install\`
- persistent settings: `settings\config.json`
- editable UI languages: `language\en.json`, `language\de.json`, `language\fr.json`
- local virtual environment: `.venv\` created by installer
- local wheel cache: `wheelhouse\` created/reused by installer
- exported OBJ lifeforms: `exports\obj\`

## License

This project is released under the **MIT License**. See `LICENSE.txt`.

The installer is safe to run repeatedly and prefers local wheelhouse packages when available, with online fallback for missing dependencies.
