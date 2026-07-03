# GAN Organism Arena

Documentation for **v0.2.8**.  
Release date: **2026-07-03**.

**GAN Organism Arena** is a Panda3D artificial-life visualizer inspired by Conway's Game of Life, GAN-style morphology generation, organism tracking, lightweight agent behavior, evolutionary scoring, generated sound and 3D export.

This release intentionally uses a **pseudo-GAN / genome generator** instead of a heavy pretrained neural model. The architecture is prepared for optional ONNX generator/critic models, but the application is immediately usable without external model files.

## What is this application for?

Classic Conway's Game of Life is a deterministic cellular automaton. A grid of living/dead cells evolves by simple local rules: cells survive, die or are born according to their neighbors. This can produce surprisingly complex patterns, but classic Life does not contain individual agents or intent.

GAN Organism Arena uses that idea as a visual and mathematical base, then interprets connected cell clusters as **digital organisms**. In Organism Mode, those organisms receive genomes, body plans, traits, energy, local behavioral bias, memory limits, ancestry, scoring and optional melodies. The result is not pure Conway Life anymore; it is a small experimental artificial ecosystem.

The application is useful as:

- a visible cellular-automata playground,
- a pseudo-evolution experiment,
- a visual toy for artificial-life ideas,
- a 2D/3D organism morphology generator,
- a source of OBJ snapshots for later work in Blender or other 3D tools,
- a foundation for later real GAN/ONNX or neural cellular automata experiments.

## License

GAN Organism Arena is released under the **MIT License**. See `LICENSE.txt` in the project root.

## Windows quick start

1. Extract the ZIP.
2. Double-click `install_windows.bat`.
3. Wait for the virtual environment and dependencies to install.
4. The installer offers an automatic fullscreen start after setup.
5. Later, start with `run_windows.bat`.

The installer is safe to run repeatedly. It reuses local `.venv`, prepares/reuses local `wheelhouse\`, installs/upgrades requirements, creates installer logs in `logs\install`, and verifies the project imports plus a non-graphical simulation smoke test.

## Project structure

| Folder / file | Purpose |
|---|---|
| `README.md` | short project entry point |
| `docs\README.md` | full English documentation |
| `docs\DESIGN.md` | design/architecture notes |
| `changelogs\CHANGELOG.md` | version history |
| `LICENSE.txt` | MIT License text |
| `src\pandalife_gan\` | application source code |
| `language\` | editable UI translation JSON files |
| `settings\config.json` | persistent user settings, created at runtime |
| `logs\` | runtime logs |
| `logs\install\` | installer logs |
| `.venv\` | local Python virtual environment, created by installer |
| `wheelhouse\` | local dependency wheel cache, created/reused by installer |
| `exports\obj\` | exported lifeform OBJ snapshots |
| `screenshots\` | screenshots saved with `F12` |

## Language files

The runtime UI can be switched between:

- English, the default,
- German,
- French.

The menu option is **Language**. Translation files live in:

```text
language\en.json
language\de.json
language\fr.json
```

They are ordinary UTF-8 JSON files. You can edit them manually or add another file later. Missing keys fall back to English. The current language is stored in:

```text
settings\config.json
```

The README is intentionally kept in English as the canonical project documentation.

## Logs and diagnostics

Runtime runs write logs to:

```text
logs\runtime_YYYYMMDD_HHMMSS.log
logs\latest_runtime.log
logs\panda3d_notify.log
```

Installer logs are written to:

```text
logs\install\install_YYYYMMDD_HHMMSS.log
```

If fullscreen starts briefly and closes again, send these files:

```text
logs\latest_runtime.log
logs\panda3d_notify.log
```

Useful launchers:

| File | Purpose |
|---|---|
| `run_windows.bat` | fullscreen normal start |
| `run_windowed.bat` | normal windowed start |
| `run_safe_windowed.bat` | conservative diagnostic mode, lower grid, no FPS meter |
| `run_selftest.bat` | non-graphical simulation/render-array smoke test |

## Requirements

- Windows 10/11
- Python 3.10 or newer
- Internet access for first dependency install, unless the wheelhouse is already populated
- GPU capable of basic OpenGL

Python packages:

- panda3d
- numpy
- pillow

Optional future package:

- onnxruntime, only if real ONNX GAN models are added later

## Main controls

| Key / Mouse | Action |
|---|---|
| Esc | Quit, or close Help/Settings first |
| Space | Pause/resume in main view; in Settings it toggles whether the simulation resumes after closing the menu |
| R | Reset world with new organisms |
| G | Inject new generated organism at a random valid position |
| Left click | Inject a generated organism at the mouse cursor position |
| Left drag | Rotate 3D terrain/object perspective; a click without drag injects at cursor |
| Mouse wheel | Zoom / 3D orbit distance |
| C | Toggle Critic overlay |
| H | Toggle main HUD overlay |
| O | Clean view: hide/show normal HUD and quick-help overlays |
| F1 | Open built-in Help page |
| P | Toggle Pure Conway / Organism Mode |
| V | Cycle view preset |
| 1-8 | Select view preset |
| B | Toggle anti-flicker blending |
| T | Cycle render mode: 2D texture -> 3D terrain -> 3D objects |
| E | Export current primary lifeforms as OBJ files |
| F10 / M | Open/close Settings menu |
| + / = | Faster simulation |
| - | Slower simulation |
| F | Toggle fullscreen |
| F12 | Save screenshot |
| Arrow keys / WASD | Move camera / orbit target |

## Settings and Help menu

Press `F10` or `M` during runtime to open the graphical Settings menu. It is rendered as a Panda3D overlay, so it works in fullscreen and windowed mode. The simulation is paused completely while Settings or Help is open, then restores the previous running/paused state when closed. Press `F1` to open the built-in Help page directly.

The Settings list is vertically scrollable and shows a visual scrollbar when not all rows fit in the panel. If there are more options than fit in the panel, the selected row remains visible while you move with `Up/Down` or `W/S`. Long detail/help text is wrapped to stay inside the panel. The Help page has its own vertical scrolling and scrollbar.

Inside the menu:

| Key | Action |
|---|---|
| Up / Down | Select a menu row; scroll Help when Help is open |
| W / S | Select a menu row; scroll Help when Help is open |
| Left / Right | Change selected value |
| A / D | Change selected value |
| Enter | Apply/toggle selected option |
| F | Toggle fullscreen/windowed mode |
| F1 | Open built-in Help page |
| F10 / M / Esc | Close the menu or return from Help |

Settings are saved persistently to:

```text
settings\config.json
```

The built-in Help page explains the project purpose, Game of Life basics, every Settings option, all major hotkeys, mouse controls, output folders, and the MIT License.

## Settings option summary

| Option | Purpose |
|---|---|
| Help / key reference | opens the in-app documentation and key reference |
| Language | switches UI/help text between English, German and French JSON files |
| Resolution | changes display size preset; default is 1920 x 1080 |
| Fullscreen / windowed | changes display mode |
| View preset | changes color interpretation of the cellular world |
| Render mode | switches 2D texture, 3D terrain and true 3D object mode |
| 3D object organism cap | limits how many primary organisms are rendered as object meshes; higher values show more bodies but cost more FPS |
| OBJ export cap | limits the number of organisms exported as OBJ |
| Anti-flicker blend | smooths visual changes between steps |
| Simulation mode | switches Pure Conway and Organism Mode |
| Simulation speed | controls target steps per second |
| Evolution memory depth | controls per-organism retained history |
| Dead organism archive cap | controls how many extinct organisms remain in memory |
| Tracker scan interval | trades tracking precision against performance |
| Memory status | shows current memory counters |
| Prune memory now | immediately trims history/archive data |
| Organism soundscape | enables/disables generated harmonic organism sound |
| Sound volume | master soundscape volume |
| Sound organism voices | maximum simultaneous audible organisms |
| Resume after closing menu | controls whether the simulation resumes after Settings closes |
| Critic overlay | shows critic/interest visualization |
| Compact HUD | toggles the small main status line |
| F10 hint | toggles the small settings hint |
| FPS meter | toggles Panda3D FPS display |
| Clean view | hides overlays for observation/screenshots |
| Inject new organism | adds a generated organism; left click in the main view also injects at the cursor using a 3D hit test with a safe fallback |
| Export OBJ lifeforms | writes primary lifeforms to `exports\obj\` |
| Reset world | starts a new generated world |
| Close menu | closes Settings |

## Render modes

### 2D texture

The fastest and clearest overview. The simulation is drawn as a cellular texture.

### 3D terrain

The cellular field becomes a height/depth surface. This is useful for watching waves, colonies and activity as a landscape.

### 3D objects

Primary lifeforms become actual x/y/z organism meshes. Shape generation uses size, age, energy, genome, body plan, sensors, eyes, limbs, manipulators and armor. Evolution is open-ended in visible tiers: organisms can continue past microbe/complexoid into macroform, elderform, biomech and leviathan-style body plans. This mode intentionally renders only selected primary organisms for performance; increase the 3D object organism cap if you want more bodies visible at once.

## OBJ export

Press `E` or choose **Export OBJ lifeforms** in Settings to export the current primary lifeforms. Files are written to:

```text
exports\obj\step_XXXXXXXX\
```

Each export folder contains:

- one `.obj` file per primary organism,
- one `.mtl` material file per organism,
- `all_primary_lifeforms.obj` as a combined scene,
- `README_export.txt` with organism IDs, family IDs, body plans and scores.

These files can be opened in external 3D tools such as Blender, MeshLab, 3D viewers, render software or modeling tools. The exported meshes are static snapshots of the current evolutionary state.

## Soundscape

The optional generated audio layer is on by default in a new installation and can be disabled in Settings. The app generates small local WAV melody assets under `assets\generated_audio` and uses Panda3D's built-in sound loader.

Sound behavior:

- each audible organism gets a deterministic harmonic melody/tone derived from its family/id,
- more important organisms are louder, based on size, age, complexity, energy and critic score,
- less important organisms fade back or drop out when the active voice cap is reached,
- Settings exposes sound on/off, master volume, and maximum active organism voices.

CLI options:

```text
--sound
--no-sound
--sound-volume 0.45
--max-sound-organisms 6
--language en|de|fr
--render-mode 2d|terrain3d|object3d
--object-mode-max-organisms 28
--obj-export-max-organisms 32
```


## Render/backend performance note

True 3D object mode is the most expensive mode because it converts lifeforms into dynamic mesh geometry. Use **3D object organism cap**, **3D object update interval**, and **3D object mesh quality** in Settings to trade detail for FPS. The **Render backend** setting is selected before Panda3D creates the window, so backend changes require an app restart. Hardware/Auto or OpenGL are preferred; software rendering is only a diagnostic fallback.

## Thoughts and speech

The **Thought output** option can hide organism proto-thoughts, show them as text, speak them via Windows TTS, or do both. TTS is best-effort and uses Windows' built-in speech system without adding a Python dependency.

## Lighting

The **Light direction** option controls the 3D key light. The automatic sun mode moves over time; manual presets lock the light to fixed directions. **Regenerate render/shaders** rebuilds the light setup and mesh cache.
