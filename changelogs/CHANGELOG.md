# Changelog

## 1.0.0-alpha29 — 2026-09-05

- Add a paused Escape exit prompt with localized choices to open settings, save a complete world snapshot and quit, quit without saving, or cancel.
- Save-and-quit writes `exports/world_saves/world_<unix-time>.json` with organisms, diploid DNA/phenotypes, nutrients, remains, evolution counters and camera state; live Genome objects are excluded so the archive stays valid JSON.
- Add the **Plant-niche discoverability** option. A moderate default bias makes inherited anchoring plus stationary feeding reach rooted aquatic or land plants more often, while aquatic founders remain motile.
- Retain bounded aquatic death remains and render them as slowly growing seabed coral/mineral stalks; deterministic reef anchors also populate deeper coast habitats.
- Extend EN/DE/FR labels, tooltips and help text for the new option and exit actions.

## 1.0.0-alpha28 — 2026-09-05

- Start the observer at a terrain-safe shore/water viewpoint instead of a fixed coordinate that could be inside a mountain.
- Keep free camera movement above the analytic terrain and keep follow-camera paths clear of the ground; add an optional Noclip setting for deliberate exploration through mountains and the seabed.
- Add an optional adult human-like observer signal. Organisms can perceive it, orient their eyes toward it, inspect it or avoid it, while it remains outside food and mating logic.
- Add persistent options for HUD text and crosshair visibility, with explanatory EN/DE/FR tooltips and profile support.

## 1.0.0-alpha27 — 2026-09-05

- Replace recognizable large landmarks in all four original terrain maps with lower-macro-frequency material detail while preserving compact 256×256, edge-closed PNGs.
- Add deterministic stochastic terrain sampling: neighbouring regions blend independently offset, quarter-turned and reflected samples instead of displaying one obvious repeated grid.
- Add deep-seabed, wet-shore, beach-sand and grass maps. The terrain shader blends these around the actual waterline and retains the habitat-specific ground as the regional land material.
- Give every rendered body segment a stable individual texture excerpt/orientation; inherited coat pixels and biological random streams remain unchanged.
- Expand the optional library to 33 replaceable maps: eight terrain, six inheritable coats, fifteen specialised/future tissue fallbacks and wood/stone/metal/cloth. Unknown tissue uses an adaptive fallback, and the current carried tool uses wood.
- Replace head-chasing courtship with persistent pair docking points and a common side-by-side orientation. Internal contact now checks reproductive-region proximity, tolerates momentary solver gaps and completes a verified approach-to-birth integration.
- Guard the optional texture toggle with complete-map checks and a vertex-colour fallback so invalid replacement PNGs cannot take down the running application.
- Mark aquatic ancestry outside the DNA loci and require three descendant steps before evolved respiration, support and locomotion can open a land or flight niche; steep-shore corrections keep early lineages submerged.
- Set the fresh-world population to ten and generate a seed-driven fourteen-entry founder pool: seven canonical aquatic plans plus seven new diploid crossover mixtures, sampled without repetition.

## 1.0.0-alpha26 — 2026-09-05

- Replace three oversized 1254×1254 PNG files (about 9 MB) with ten compact 256×256 templates totalling about 708 KB.
- Supply six distinct organism patterns (skin, scales, fur, membrane, plates and mottle) plus four habitat-specific terrain patterns.
- Make every bundled map technically seamless by matching opposite boundary pixels and softly blending the nearby border regions.
- Give each founder a deterministic two-template recipe informed by its surface traits. Sexual descendants combine the complete recipes and, when textures are active, the actual parent pixels; clonal descendants retain an independent copy.
- Keep runtime maps bounded at 128×128, cache byte buffers during weighted mixing and leave all PNG work disabled until the user activates textures.

## 1.0.0-alpha25 — 2026-09-05

- Add optional replaceable terrain/body PNG textures, disabled by default. Sexual offspring receive an owned 50/50 pixel mixture of both parents' actual inherited maps; clones receive an independent copy. This continues across generations.
- Add F9 texture reload, selected coat PNG export and F2 HUD toggle. Existing inherited coats survive template replacement and parent death.
- Add a full pause across biology, movement, development and presentation using P, Space or Pause; add a detailed in-app handbook and complete README control reference.
- Preserve the unmutated homolog during major regulatory mutation; record actual allele changes, including inherited gamete changes and clonal recessive-load changes.
- Restore the original 88-locus order; append topology and two new inherited pigment loci (91 total, map `arena.loci/3`). Make hue blending independent of parent order.
- Add event-driven, bounded genealogy and all-run evolutionary counters. Separate natural reproduction from automatic/manual injections and distinguish first natural topology appearances.
- Add F10 evolution overview, JSON history export and independent new-reproduction toggle; update EN/DE/FR help/tooltips and precise mutation controls.
- Apply population rescue immediately while paused/stepped, clean dead pending nodes and preserve explicitly disabled migrated preferences.
- Include genealogy in optional evidence exports; add native evolution regression gate (exit 34). Native Windows/Godot execution was unavailable during preparation; source checks and installer gates are documented.

## 1.0.0-alpha24 — 2026-09-05

- Automatische Nachbesetzung ist standardmäßig aktiv und prüft nach jedem Simulationsschritt unabhängig von neuen Todesereignissen den einstellbaren Zielbestand (Standard 5). Ein bereits leerer Zustand wird in einem Durchlauf aufgefüllt; Abschalten lässt Aussterben weiterhin zu.
- Neue Gründer sind junge, unverwandte Wasserorganismen mit zufälligen Genen, aber nur drei aquatischen Ahnenbauplänen und moderaten Größen. Weitere Topologien und extreme Größen entstehen dadurch erst in Nachkommen.
- Der Körperbauplan ist als 89. diploider Genort `body_plan_code` Bestandteil der exportierten fiktiven DNA. Rekombination und Makromutation wirken auf dieses Gen statt auf ein separates Form-Flag.
- Sexuelle Nachkommen erhalten nachweisbar Struktur-, Muskel-, Hüllen-, Physiologie- und Verhaltensallele beider Eltern. Die gemeinsame Pigmentfarbe mischt den Farbton zirkulär und korrekt über die Rotgrenze.
- F10-Regler, Profile, EN/DE/FR-Tooltips sowie MCP/VKLP-Parameter wurden ergänzt; Modellkennung `arena-biology-7`.

## 1.0.0-alpha23 — 2026-09-04

- Geländesichere RMB-Verfolgungskamera: Zielpunkt und geglättete Zwischenposition prüfen die vollständige Sichtlinie gegen das gemeinsame Heightfield; beim Aktivieren wird eine sichere erhöhte Ansicht gewählt.
- Erreichbare sessile Evolution aus weiterhin beweglichen Wassergründern: gekoppelte Schwellen für Verankerung und ortsfeste Ernährung, gezielte Bodensuche, Wurzeln sowie unterscheidbare Wasserpflanzen, Landpflanzen, Filtrierer und Bäume.
- Standardfläche 288 × 288; Relief und Wassertiefe bleiben entkoppelt auf vergleichbarem Niveau, die obere Grenze steigt von 43,2 auf 64,8 Einheiten. Einmalige Migration älterer Einstellungen.
- Neue Kamera-, Pflanzen-, Vererbungs- und Raumtests im Installer-Gate.

## 1.0.0-alpha14 — 2026-09-02

- Fix des gemeldeten alpha13-Installationsabbruchs: explizite Array[Vector3]-Argumente für Ressourcenlisten in Test- und Weltinitialisierung.
- 84 diploide Merkmalsloci mit Meiose, Kopplung/Rekombination, partieller Dominanz, vererbter Geschlechtskonstellation und acht rezessiven Belastungsloci.
- Energieabhängiges Wachstum und Reife, kostenpflichtige Ei-/Spermien-/Propagulusreserven, temperatur- und sauerstoffabhängige Embryonalphasen.
- Endliche Nahrungspartikel mit zeitlichem Nachschub; zusätzliche biologische Messwerte im Inspektor.
- Optionale MCP-stdio-Schnittstelle, laufende Beobachtung, explizite Versuchsschritte, Zustands-/Genomexport und verifizierbare Versuchsprotokolle.
- Adapter zum vorhandenen VKLP 0.1: Claims lesen, mit Provenienz für Versuche nutzen und Erkenntnisse aus der Simulation mit Evidenz einreichen.
- Aktivierung der Schnittstellen verändert keine Weltparameter, sperrt keine bisherigen Bedienelemente und erzwingt keinen Schrittbetrieb. Normale Anwendung ohne Python/Protokolle bleibt vollständig nutzbar.
- Neue biologische und Schnittstellen-Regressionen; Prüfung gegen Original-VKLP-Dienst. Native Windows/Godot-Prüfung bleibt ein Installer-Gate und wurde in dieser Buildumgebung nicht ausgeführt.


## 1.0.0-alpha13 — 2026-09-01

- Default to coastal habitat 7, including usable sky, and initialize aquatic founders in accessible water. Migrate only the old default habitat once. Descendants are not reset to founder limits.
- Replace instant reproduction and unconditional cloning fallback with compatible roles/anatomy, timed courtship/contact, fertilization, egg/embryo development and birth. Add distinct spawning, internal egg-laying, retained-yolk, maternal-nutrition and propagule routes; reserve population slots for unborn offspring.
- Add twenty inherited lifecycle/interaction genes, genetic compatibility and reduced hybrid fertility, parentage, nutritional maturation delays, larval/pupal/adult stages, schematic reproductive tissue, secondary displays and resource-funded parental care.
- Add finite-range shore bites, ballistic breaches/leaps, shallow dives, breath/stamina costs and return behavior. Prevent unadapted aquatic founders from climbing land through terrain correction.
- Add two-sided animated water with stronger highlights/opacity and terrain-intersected shore contours. L picks and saves a new fixed random light direction; auto_sun restores movement.
- Expand EN/DE/FR inspector/help and scientific-limit documentation. Add 115 lifecycle assertions; 237 ecology/covering/lifecycle assertions plus core tests pass in the source harness. Native Godot/Windows/shader validation remains unperformed here.

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
