# GAN Organism Arena

Version **0.2.8**.  
Release date: **2026-07-03**.

GAN Organism Arena is an artificial-life sandbox built with Panda3D. It combines a Game-of-Life-inspired cellular world with organism tracking, genome-like traits, pseudo-GAN morphology generation, evolutionary scoring, organic artificial-life sounds, artificial-lifes could learn to speak (with tts voice output), 2D/3D visualization, and OBJ export.

<img width="1920" height="1080" alt="pandalife_step_00000170" src="https://github.com/user-attachments/assets/37eaa632-e07d-424c-8dcd-45b2e81aed1f" />

<img width="1920" height="1080" alt="pandalife_step_00002147" src="https://github.com/user-attachments/assets/f6265fc8-11d8-4cdc-abdd-0d594491b405" />

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
