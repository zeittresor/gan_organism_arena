# GAN Organism Arena

**Version 1.0.0-alpha9 — 2026-09-01**

### Alpha8 habitats, ecology and sound

Alpha8 extends the working 3D evolution loop beyond a permanently aquatic box. Keys **5-9** switch between increasingly mixed habitats, from open water to water/land/sky. Habitat adaptation is heritable, so organisms are selected by aquatic, terrestrial and flight competence rather than being magically converted. Social evolution now includes courtship, group cohesion, simple hierarchy and predator/prey pressure. Procedural 3D organism calls and changing habitat ambience are independent from Windows TTS. At the population cap, weak organisms may be displaced by viable offspring so generation turnover can continue.

**New controls:** 5-9 habitat stages; NumPad + / - expands or shrinks the XYZ world.

**Engine target:** Godot 4.7.2 stable  
**License:** MIT

## TL;DR

GAN Organism Arena is now a real **3D artificial-life aquarium** instead of a 2D cellular simulation with a 3D visualization layer. Organisms exist and move in X/Y/Z, consume resources in a volume, reproduce through mutation and two-parent genetic crossover, build three-dimensional bodies, accumulate bounded experience, and develop increasingly expressive communication.

On Windows, run:

```text
install_windows.bat
```

The installer downloads a **portable local copy of Godot 4.7.2** into `runtime/godot/`, parses every core GDScript deterministically, runs an advanced morphology/genome/language/appendage self-test plus a short runtime smoke test, and starts it after a 10-second cancelable delay. Nothing is installed system-wide. After the first installation, the project can run offline. Alpha9 uses a clean project-context smoke test with orderly audio/TTS teardown, so Godot shutdown diagnostics are handled explicitly instead of being mistaken for a failed native process. The Godot binary itself is not duplicated inside this source ZIP; the installer fetches the official Windows x64 portable archive on the first run and verifies its SHA-256 before extraction.

## Controls

- Mouse — free look
- W/S — swim forward/back
- A/D — strafe
- Q/E — descend/ascend
- Shift — boost
- Mouse wheel — observer speed
- LMB — select organism under crosshair
- RMB — follow/unfollow selected organism
- Tab — next organism
- Space — pause/resume
- F10 — settings
- F1 — detailed in-app help
- 1/2/3/4 — Natural / Cell / Neural / Energy views
- G — inject a random organism
- F8 — export selected organism as OBJ
- F12 — screenshot
- Esc — release/capture mouse

## What changed from the classic build?

The old Panda3D/Python implementation is not merely being rendered differently. This branch replaces the simulation architecture:

- true 3D organism positions and movement;
- developmental genomes instead of a fixed body-stage ladder;
- seven distinct starting body topologies with continuously mutable proportions;
- two-parent crossover, ordinary mutation and rare macro-mutation into new body plans;
- developmental viability selection so incoherent genomes can fail instead of reproducing;
- heritable longevity/senescence so saturated populations continue to turn over across generations;
- GPU-instanced 3D body cells using Godot `MultiMesh`;
- bounded event memory instead of retaining every evolution step;
- separate simulation tick rate and rendering frame rate;
- real three-dimensional paired appendages, head/sensor growth, axial support, neural chains, fins, armor and branching structures;
- open-ended numerical complexity/cognition with only the *visible LOD budget* bounded;
- progressive communication from elemental calls to symbolic and compositional translated thoughts;
- free-swimming observer camera plus anatomical tail/rear follow mode;
- scientific Cell, Neural and Energy views;
- OBJ export for the selected current organism.

## Rendering backends

The Settings menu supports:

- `forward_plus` — Vulkan, recommended for modern GPUs;
- `mobile` — lighter Vulkan renderer;
- `compatibility` — OpenGL fallback.

For debugging, `run_console.bat` starts the console build and leaves engine errors visible. `run_mobile.bat` forces the lighter Vulkan Mobile renderer.

Renderer changes require a restart because Godot selects the graphics backend before loading the project. `run_compatibility.bat` is provided as a diagnostic fallback.

## Performance model

The project deliberately decouples simulation from rendering. Organism decision/evolution ticks default to 12 Hz while the camera can render at the display frame rate. Every organism is one moving Node3D containing a MultiMesh of local biological cells, so all cells are not individually transformed every frame. Morphology is rebuilt only when development visibly changes. Per-organism event memory is bounded.

The most useful performance controls are:

- **3D simulation ticks per second**
- **Maximum living organisms**
- **Maximum visible body cells per organism**
- **Body morphology refresh interval**
- **3D nutrient particle count**

## Directory layout

```text
GAN Organism Arena/
├─ project.godot
├─ scenes/
├─ game/
├─ language/          editable EN/DE/FR JSON
├─ settings/          persistent config.json
├─ logs/
│  └─ install/
├─ exports/
│  └─ obj/
├─ screenshots/
├─ runtime/
│  └─ godot/          portable Godot runtime after installation
├─ docs/
├─ changelogs/
├─ install_windows.bat
├─ run_windows.bat
├─ run_compatibility.bat
├─ run_parse_test.bat
├─ run_selftest.bat
└─ run_editor.bat
```

## Notes on the term “GAN”

The project name is retained from its original concept. The current core is better described as **developmental artificial life**: genomes, local developmental rules, selection, mutation, morphology, behavior and cognition. A future GAN/critic or learned morphology evaluator can be added as an optional evolutionary pressure rather than pretending a GAN is the correct tool for every part of the simulation.

## Status

This is an architectural alpha. It is designed to be directly runnable and extensible, but it is not yet a biological simulator or a claim of real consciousness. The important change is that the world, motion and body development are now genuinely three-dimensional and the code is structured so more sophisticated neural cellular automata, compute-shader tissue simulation, SDF surfaces and GDExtension/C++ acceleration can be added without returning to a 2D simulation core.
