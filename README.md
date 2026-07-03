# PandaLife GAN Organism Arena

Version **0.2.3**.

PandaLife GAN Organism Arena is an artificial-life sandbox built with Panda3D. It combines a Game-of-Life-inspired cellular world with organism tracking, genome-like traits, pseudo-GAN morphology generation, evolutionary scoring, optional harmonic sound, 2D/3D visualization, and OBJ export.

## Quick start

1. Run `install_windows.bat`.
2. Start later with `run_windows.bat`, `run_windowed.bat`, or `run_safe_windowed.bat`.
3. Open Settings/Help in the app with `F10` or `F1`.

<img width="1920" height="1080" alt="pandalife_step_00000087" src="https://github.com/user-attachments/assets/3aff2a79-a356-411e-8539-5b0a24029402" />

<img width="1920" height="1080" alt="pandalife_step_00000436" src="https://github.com/user-attachments/assets/abe685c5-ad4d-4ed2-ab84-e1c665fa2bfa" />

<img width="1920" height="1080" alt="pandalife_step_00000750" src="https://github.com/user-attachments/assets/05f9f972-2cbc-4dd3-80ee-4c6f290a7c3a" />

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
