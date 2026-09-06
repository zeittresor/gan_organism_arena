# Testing — 1.0.0-alpha30 (2026-09-06)

## Installer hotfix (alpha30-fix1)

The original alpha30 archive mistakenly retained `config/version="1.0.0-alpha29"` in `project.godot`. The Windows installer correctly rejected it before starting Godot. The corrected archive sets alpha30 and regenerates all package checksums.

The unchanged `tools/verify_package.ps1` now passes under PowerShell 7.4.6 on Linux. The packaging workflow also runs `python tools/check_release.py` before writing the ZIP; a regression check confirms that the original alpha29/alpha30 mismatch is rejected. This does not substitute for testing the complete installer on Windows.

## Native verification

Executed the production GDScript with **Godot 4.7.2.stable.official.ed1daf0bf, Linux x86_64, headless**. This release is no longer verified solely through the Python translation harness.

**11,824 named native checks passed**, plus the morphology/genome/language integration:

- Texture: 20 checks, 0 failures.
- Application: 51 checks, 0 failures.
- Ui: 19 checks, 0 failures.
- Pause: 13 checks, 0 failures.
- Evolution: 215 checks, 0 failures.
- Camera: 6 checks, 0 failures.
- Navigation: 43 checks, 0 failures.
- Posture: 868 checks, 0 failures.
- Support: 857 checks, 0 failures.
- Locomotion: 3371 checks, 0 failures.
- Interaction: 5458 checks, 0 failures.
- Ecology: 60 checks, 0 failures.
- Surface: 71 checks, 0 failures.
- Life Cycle: 122 checks, 0 failures.
- Biology: 629 checks, 0 failures.
- Experiment: 21 checks, 0 failures.

The application regressions cover resumable checkpoints (DNA, gametes, embryo state, inherited pixel maps, RNG and nutrient positions), corrupted files and write failures, settings recovery, camera spawn/free-look/noclip, founder plant safeguards, finite scavenging and recycling, and bounded seabed features across all five habitats. Proportion regressions compare generated head width with supporting body width and exercise inherited head-size variation. Independently marked parents verify morphological, cognitive and behavioral inheritance and deterministic regional expression without changes to germ-line DNA.

UI regressions instantiate the actual main application: ESC/cancel, pause ownership, blocked shortcuts, English/German/French help, texture toggles/reload, profile camera options, changed world dimensions, saving/loading, selection/follow restoration, invalid load and reset while paused.

- Native MCP stdio → Python TCP client → Godot simulation end-to-end: PASS, including same-seed reset/stepping, 91 diploid loci and evidence export.
- Native VKLP-only gateway and simultaneous MCP+VKLP configuration: PASS. No remote claim submission is performed by these tests.
- Python MCP/VKLP adapter/permission suite: 15 tests, PASS.
- Seeded stability run: 3 seeds × 1,800 ticks, totaling 450 simulation seconds. Check finite body state, population floor/cap and remains limit. This is a stability test, not proof that a particular evolutionary outcome will occur.
- Grammar/UI coverage: 58 GDScripts; 70 settings/actions with labels and explanatory tooltips in EN/DE/FR.
- Release archive: fresh extraction, ZIP CRC and each payload SHA-256. Personal configuration, screenshots, runtime sessions, generated logs and engine caches are excluded.

## Reproduce

The Windows installer executes the native parser, SelfTest scene and SmokeTest scene before accepting the installation. Run `run_selftest.bat`, `run_parse_test.bat` or `run_diagnostics.bat` later. Optional live MCP verification: enable MCP in Settings, then run `python tests/live_arena_check.py --godot PATH_TO_GODOT --headless`.

## Limits

Windows PowerShell launch behavior, Windows voices/audio devices and hardware GPU rendering/FPS were not executed on this Linux host. Headless tests exercise real Godot scripts and Image/ImageTexture objects, but do not establish rendered appearance or performance on a user's GPU. The terrain/organism shader code is unchanged in this release. Runtime play-testing on the target PC remains useful.

Checkpoints reconstruct rendering/contact caches; they do not promise frame-exact or cross-version replay. Alpha29 JSON observation exports cannot be loaded as checkpoints. Mutation can help or harm fitness. Seven topology grammars and their continuous developmental variation remain a finite fictional model, rather than a calibrated model of terrestrial species.
