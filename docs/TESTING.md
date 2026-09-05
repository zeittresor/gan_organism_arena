# Testing — 1.0.0-alpha29 (2026-09-05)

## Current verification

- The translated production-source suite passes **11,704 named checks**: pause 13, evolution/inheritance 185, camera 6, navigation 43, posture 868, support 857, locomotion 3,371, interaction 5,458, ecology 60, surface 71, lifecycle 122, biology 629 and experiment API 21. The morphology/genome/language integration check passes too.
- The native Godot texture suite adds **20 checks** to the installer gate (11,724 expected named checks there). It covers the disabled fast path, unchanged biological RNG, owned child pixels, 50/50 sexual mixing, a 75/25 grandchild, independent clonal copies, parent immutability, survival after parent destruction, all 33 registered source maps, transition lookup and the bounded tissue atlas.
- Separate pixel/frequency oracles repeat the central texture arithmetic with actual RGB images. All 33 supplied 256×256 PNG files decode, remain below 3 MiB together and have exactly matching opposite edges. The eight terrain maps pass a low macro-landmark energy limit. Runtime source images stay at 128×128; inherited mixing occurs on birth/first use rather than per frame.
- 55 GDScripts pass the available grammar parser and are registered in the native parse test. All 68 settings/actions have labels and explanatory tooltips in English, German and French.
- Population rescue from an already empty world, sexual inheritance, macro mutation, plant evolution, follow-camera terrain clearance, persistent navigation, connected posture, body contact, gestation/birth/growth and pause semantics remain covered.
- Aquatic founder markers keep the first three lineage generations submerged; land capability still requires evolved respiration and locomotor support. Texture loading has an explicit safe fallback for missing or invalid optional assets.
- Fresh-world initialization builds seven canonical and seven crossover founder genomes, then samples ten without replacement using the simulation RNG; repeated seeds remain reproducible.
- Production side-by-side docking, courtship, gestation, birth and juvenile development pass with one offspring. Tests assert fixed pair docking points instead of moving head targets. The OBJ writer passes four view transitions with 933, 609, 957 and 933 vertices and no GPU readback. Performance regression passes 42 structural/cache checks. All 15 MCP/VKLP permission and adapter tests pass.
- The README was compared against every `KEY_`, mouse-button and camera input binding in source. It lists all controls, including F2 HUD visibility and F9 texture reload.
- Packaging performs a fresh extraction, ZIP CRC check, payload SHA-256 check and file-count comparison. Personal `settings/config.json`, runtime logs and temporary files are excluded.

## Execution limits

This environment has no Windows or Godot 4.7.2 executable. The 11,704 source checks execute production GDScript logic through a Python translation harness with substitute engine objects; they do not validate Godot's renderer, Windows TTS or measured FPS. The texture shaders and native `Image`/`ImageTexture` path are source-checked and remain part of the Windows installer's native parse/self-test/smoke gates. Alpha21 is the latest clean native installation evidence supplied by the user.

The texture feature is disabled by default. Enabled performance depends on GPU/driver and asset replacements, although work is bounded to small images and generated only at birth or first display. The artificial-life model and seven topology grammars remain finite; particular Earth-like outcomes are not guaranteed.
