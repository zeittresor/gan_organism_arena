# Changelog

## 1.0.0-alpha12 — 2026-09-01

- Added nine heritable covering genes for skin thickness, scales, feathers, fur/bristles, mucus, membranes, horns/spines, beaks and pigment patterns; normal mutation, crossover and macro-mutation include them.
- Added visible covering layers and feather quills within the existing per-organism cell budget, mixed coverings, pigment stripes/spots, surface gloss and bark-coloured tree stems. Feathers do not require fins and do not independently unlock flight.
- Connected coverings to skin respiration, drying, swim drag, insulation, lift/load, bite protection, bite strength and maintenance costs. Added a simple local temperature gradient with cold/heat tradeoffs.
- Expanded the inspector and EN/DE/FR help. Added 71 covering assertions to the native installer self-test; all pass in the Python source-translation harness alongside 51 ecology assertions. Native Godot/Windows rendering and installation remain unverified here.
- Retained the alpha11 parser fix, validated runtime cache search, wheel zoom and doubled world dimensions.

## 1.0.0-alpha11 — 2026-09-01

- Fixed the Godot 4.7.2 parser failure at genome.gd:116: renamed reserved loop binding `trait` to `gene_name`. The dependent ecology_test.gd, sim_world.gd and self_test.gd failures originate from this failed genome load.
- Added `trait` to reserved-name checks; static verification now checks for-loop and constant declarations as well as variables, and includes static-function parameters.
- Regression check rejects the actual alpha10 genome and accepts the corrected source. The 51 source-level ecological assertions and existing morphology/genome/language tests pass in the substitute-engine harness. A native Windows/Godot rerun remains unverified in the build environment.
- Preserved ecological behavior, larger world, settings migration, mouse-wheel zoom and checksum-validated cached-runtime reuse.

## 1.0.0-alpha10 — 2026-09-01

- Doubled every default world dimension (144 × 86.4 × 144); one-time legacy settings migration; 540 distributed nutrients.
- Shared rendered terrain and ground queries; real dry land and water niches.
- Added 21 heritable ecological traits for respiration, locomotion, light structures, body size, manipulation, feeding and sessility.
- Oxygen reserves, drying, stamina and structural flight constraints; open sky required. Amphibious shore visits and respiratory escape behavior.
- Shared pack prey, driving/flanking and learned pursuit/ambush skills; hiding affects detection.
- Physical, wearing tools extract finite patch food; separate cleaning and parasitic host interactions.
- Upright, small insect-like, winged and rooted plant/tree-like phenotypes with sparse appendage animations.
- Finite host energy transfer and locally competing rooted productivity; grazing.
- Disabled automatic population rescue by default; removed forced intelligence/complexity culling. Increased reproduction opportunities to permit viable lineages to turn over within alpha run times.
- Expanded EN/DE/FR help and inspector, 51 ecological assertions integrated into installation self-test.
- Mouse-wheel zoom and SHA-256-validated runtime-cache reuse retained.

## 1.0.0-alpha9 — 2026-09-01

- Mouse-wheel optical zoom in free-swim and anatomical follow views; Shift+wheel retains observer-speed control.
- Added persistent camera FOV and configurable zoom step.
- Installer now searches checksum-valid local Godot 4.7.2 archives in the current runtime folder, nearby/sibling project trees and the Windows Downloads folder before downloading.
- Added a dedicated clean-shutdown smoke-test scene and safer native-command logging so benign Godot warnings do not abort installation by themselves.
- Added explicit audio/TTS cleanup during shutdown.

## 1.0.0-alpha8 — 2026-09-01

- Added habitat stages 5-9: open water, seabed/islands, coast, land/shallows/air, and combined water/land/sky.
- Habitat hotkeys 5-9 and numeric-keypad +/- world-size controls; each habitat stage naturally expands the world by one configured cell/unit.
- Added ecological adaptation genes for aquatic, terrestrial and flight niches; unsuitable environments now create real energy/development pressure.
- Added visible adaptive structures: wings, load-bearing legs and caudal fin fans can emerge independently of the original topology family.
- Added courtship steering/ritual motion, stronger cross-family mating, pack/group cohesion, same-family hierarchy and simple predator/prey behavior.
- Population caps now permit Darwinian turnover by replacing weak organisms when viable offspring are produced instead of freezing reproduction at capacity.
- Added procedural ecosystem audio: habitat ambience plus spatial organism calls/melodies whose complexity follows language stage/family.
- Added audio, courtship, grouping, predation, hierarchy and habitat controls to Settings.
- HUD now reports habitat/world size; selected-organism details include behavior and habitat stress.

## 1.0.0-alpha7 — 2026-09-01

- Reworked the developmental genome to support seven distinct body-topology families: serpentine, fusiform, radial, ray-like, branching, crustacean-like and cephalopod-like.
- Added continuous morphology genes for body width, flattening, head/tail allocation, limb length/thickness/position, shell/support and heritable mutability.
- Initial populations now deliberately span topology-space instead of being seeded from one worm-like template.
- Added two-parent genetic crossover. Offspring inherit mixed parental genes, may establish new family lineages, and can undergo rare macro-mutations into a different topology.
- Increased ordinary mutation range and added a configurable macro-mutation rate so descendants can diverge substantially instead of remaining near-clones.
- Added developmental viability scoring. Structurally unsupported or metabolically incoherent genomes lose energy faster and cannot reproduce below the configured viability threshold.
- Added heritable longevity and gradual senescence so a population at its organism cap still gets generational turnover instead of freezing evolution forever.
- Rebuilt the 3D morphology generator around topology-specific developmental builders and anisotropic body cells, producing broad/flat, radial, branching, many-legged, tentacled and compact forms in addition to serpentine forms.
- Added preferred social spacing and persistent wander steering to reduce rapid pairwise oscillation / permanent contact wobble.
- Added reproduction cooldowns and configurable mating radius.
- Reworked RMB follow mode to use each organism's generated anatomical rear/focus anchors and movement direction, keeping the observer behind the tail/rear instead of following the geometric centre.
- Added configurable follow distance/height and new evolution controls to Settings.
- Expanded HUD/runtime metrics with active body-plan count, crossover births, mutation births and failed developments.
- OBJ export now preserves anisotropic body-cell proportions.
- Expanded the project self-test to verify all seven morphology topologies, volumetric extents, crossover, macro-mutation infrastructure, viability selection and anatomical follow-camera anchors.

## 1.0.0-alpha6 — 2026-09-01

- Fixed the alpha5 installer failure `Compile Error: Identifier not found: SettingsStore`. The cause was the self-test being launched with Godot's standalone `--script` mode, which does not provide project autoload singletons in the same way as a normal project scene.
- Converted `game/self_test.gd` into a normal Node-based project self-test and added `scenes/SelfTest.tscn`.
- The installer and `run_selftest.bat` now execute the self-test as a project scene so `SettingsStore`, `L10n`, and `AppLog` are available exactly as they are during the real application.
- Added an explicit self-test assertion that the SettingsStore autoload is live.
- Static package verification now requires and validates `scenes/SelfTest.tscn`.
- Updated active version metadata to 1.0.0-alpha6.

## 1.0.0-alpha5 — 2026-08-31

- Fixed the Godot 4.7 parser failure in `game/organism.gd`: the local variable name `signal` was a reserved GDScript keyword and is now `language_signal`.
- Fixed the parser diagnostic itself: alpha4 could print `PARSE OK` even after Godot reported a parser error. The test now checks `can_instantiate()` for every core script, and the installer separately rejects any `SCRIPT ERROR`, `Parse Error`, `PARSE FAILED`, or `Failed to load script` output even if Godot returns exit code 0.
- Extended static package verification to reject reserved GDScript keywords used as variable names or function parameters before the Windows runtime is launched.
- Updated all active version metadata to 1.0.0-alpha5.

## 1.0.0-alpha5 - 2026-08-31

- Fixed the Godot 4.7 parser failure that blocked alpha3 installation. GDScript default arguments now use `=` instead of the invalid `:=` form.
- Removed inferred `:=` declarations throughout the alpha branch in favor of parser-safe dynamic `=` declarations where cross-script Variant references are involved.
- Reworked `game/parse_test.gd` into a dependency-free ResourceLoader parser probe that checks every core script separately and reports the exact failing target.
- Strengthened static package verification to reject invalid `:=` default-argument syntax and stale alpha3 version strings before packaging.

## 1.0.0-alpha3 — 2026-08-31

- Fixed the first Windows alpha2 installer failure caused by GDScript global-class/type resolution around `ArenaOrganism`.
- Removed fragile cross-script `class_name` dependencies from the runtime core and replaced them with explicit `preload()` dependencies.
- Reworked dynamic organism/world/camera references so Godot 4.7.2 does not have to infer static types from unresolved external members.
- Reworked genome creation/mutation so it no longer depends on a globally registered `ArenaGenome` class.
- Added `game/parse_test.gd`, which deterministically preloads every core script. The installer now runs this test before the morphology self-test.
- Strengthened the artificial-life self-test: it verifies advanced morphology, sensor/neural tissue, mutated generations, language output and visible lateral appendages.
- Kept the portable Godot 4.7.2 runtime download/checksum flow and the short headless runtime smoke test.
- Version/date are consistently reported as 1.0.0-alpha3 / 2026-08-31.

## 1.0.0-alpha1 — 2026-08-31

- Architectural rewrite from the classic 2D/Panda3D simulation into a Godot 4 true-3D artificial-life aquarium.
- Added genuine X/Y/Z organism position, swimming and resource interaction.
- Added free-swim observer controls with mouse look, WASD, Q/E and boost.
- Added developmental 3D bodies using MultiMesh GPU instancing.
- Added axial bodies, neural/support chains, heads, sensors, paired extremities, digits, fins, armor and feather-like branching.
- Added open-ended numerical complexity and cognitive development; only the visible-cell LOD budget is bounded.
- Added mutated lineage reproduction.
- Added bounded episodic event memory.
- Added progressive communication stages from elemental calls through symbolic/compositional translated thoughts.
- Added optional Windows SAPI TTS output.
- Added Natural, Cell, Neural and Energy scientific views.
- Added free organism selection/follow camera.
- Added OBJ export and screenshots.
- Added EN/DE/FR JSON localization.
- Added scrollable Settings and comprehensive in-app Help.
- Added light-direction presets and moving automatic sun.
- Added Forward+ Vulkan, Mobile Vulkan and Compatibility/OpenGL launcher selection.
- Added portable local Godot 4.7.2 Windows installer and headless project verification.
- Project remains MIT licensed.
