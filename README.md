# GAN Organism Arena

**Version 1.0.0-alpha22 — 2026-09-04**

### Alpha22: purposeful exploration, feeding and partner seeking

- Individuals keep exploration waypoints and forage with energy-based hysteresis. Fruitless approaches trigger a new route and a temporary target cooldown. Local food sensing uses the current developmental stage.
- Nutrients are captured at the articulated head. Body origins no longer have to enter the food particle, and land food is not shifted upward to the body origin.
- Ecological actions replace competing intentions; existing turn/acceleration limits smooth the resulting movement. Compatible receptive adults approach partners before the random courtship event starts. Emergency respiration and escape take priority.
- Selection details show the current goal, distance, speed, meal count and route retries in EN/DE/FR. Optional observations include the same navigation data; diagnostic logs include movement/feeding summaries.
- Existing anatomical restrictions still govern swimming, land locomotion and flight. See [Alpha22 notes](docs/ALPHA22_DE.md) and [validation status](docs/TESTING.md).

### Alpha21: headless installer and OBJ export hotfix

- Hidden connectors receive no render instance. Active connectors use compact indices, including after view changes.
- Rendering and OBJ export share CPU pose buffers; the exporter no longer reads per-instance transforms from the graphics server.
- Regression tests check hidden anatomy, connector allocation and natural/cell view transitions without graphics readback. Native installer gates stay enabled.
- See [Alpha21 notes](docs/ALPHA21_DE.md) and [validation status](docs/TESTING.md). Windows/Godot execution was not available here.

### Alpha20: articulated shore posture and connector fixes

- Axial joints now follow the local terrain tangent without alternating overcorrection; their bounded range and proximal pivot allow long bodies to curve over ridges. Unsupported body mass biases the support pitch instead of treating one tail contact as a clamp.
- Up/down swimming turns also propagate into trailing joints and relax smoothly afterwards. Head/tail interaction anchors follow the actual articulated pose.
- Cranial horns and beaks attach to the head even when their material/size sample comes from a remote limb. Hidden internal tissues have fully hidden connectors, removing long needle-like residual geometry in natural view and OBJ export.
- Adds native installer regression cases for sharp ridges, steep shores, independent segment bending, vertical swim turns and connector geometry. See [Alpha20 notes](docs/ALPHA20_DE.md) and [validation status](docs/TESTING.md). Native Windows/Godot rendering was not available in this build environment.

### Alpha19: ground-following spines and planetary gravity

- Axial joints can settle vertically along uneven terrain as well as bend sideways. An overdamped, bounded pose solver preserves rigid bones and connected segment lengths, including across body rebuilds.
- Buoyancy follows the immersed fraction of structural body volume. Dry overhangs lose water support; unsupported bodies and pupae fall. Powered flight needs adequate anatomy, reserves and lift at the selected gravity.
- F10 **Planetary gravity (× Earth)**: 0.20–2.50, default 1.00; live changes, settings-profile persistence and explanatory EN/DE/FR tooltips. Also available as the optional experiment parameter `gravity_scale`.
- Structural tissue carries ground contact; feathers and similar coverings no longer lift the whole body like rigid stilts. Local sensing is cached; wholly contained collision spheres are removed without shrinking the occupied envelope.
- Read [Alpha19 notes](docs/ALPHA19_DE.md) and [validation status](docs/TESTING.md). Local checks execute production logic with substitute engine objects; Alpha19 still needs native Windows/Godot visual validation.

### Alpha18: installer self-test hotfix

- Fixes the step-5 runtime error in `locomotion_test.gd`: nutrient fixture positions are constructed as an explicit `Array[Vector3]` before assigning the typed property.
- The fixture node belongs to the test scene, so it also has a cleanup owner if a test aborts.
- Static package verification rejects bare array literals assigned to known typed-array members. The guard detects the original alpha17 failure.
- Includes the Alpha17 movement and anatomical-joint changes. See [validation status](docs/TESTING.md) for the distinction between native user logs and local source checks.

### Alpha17: stable locomotion and anatomical joints

- Steering intent, body turning, propulsion and contact impulses are separate. Limited angular acceleration, gradual turns and persistent food/prey targets prevent rapid body-axis reversals.
- Continuously integrated gait phase fixes animation jumps after speed changes or long runtimes. Compatible body rebuilds preserve joint poses.
- Rigid bones/shafts and fixed attachments inherit their parent frame. Cartilage joints, flexible shell joints and muscular hydrostats have anatomy-dependent axes, angular limits and muscle-driven strokes.
- Terrain support follows posed tissue orientation. Existing contact-quality controls, caches, visibility savings and the tissue budget are retained.
- Localized anatomy counts, Cell-view joint markers and optional API joint data make the mechanisms inspectable.
- Read [Alpha17 movement notes](docs/ALPHA17_DE.md) and [validation status](docs/TESTING.md). Native Windows/Godot rendering has not been executed for this build here.

### Alpha16: performance and adjustable contact accuracy

- F10 **Contact accuracy** slider (0–100, default 85), live updates and profile persistence, with explanatory EN/DE/FR tooltips.
- Terrain tile bounds, pose-aware contact caches and proximity checks avoid unnecessary detailed work. Quality 100 retains the detailed articulated contact model; lower settings tolerate small overlaps and use fewer contact passes.
- Static render scales/colors are reused. Invisible organisms skip graphics uploads while articulation, collision and biology continue; re-entry and OBJ export flush the current pose.
- Detailed ten-second runtime diagnostics identify motion, biology and contact CPU costs, rendering workload and cache/visibility savings.
- Read [alpha16 performance notes](docs/ALPHA16_DE.md) and [verification](docs/TESTING.md). Source benchmarks are not Windows FPS measurements.

### Alpha15: connected bodies, options and developmental mechanisms

F10 now contains independent **MCP/VKLP permission switches**, a separate VKLP submission permission, a service URL, explanatory tooltips for every option, and **Save settings / Load settings** JSON profiles. Connecting an allowed adapter preserves normal controls and the current population. The direct VKLP client also works with MCP disabled.

Menu/thought language and spoken language can be selected separately (English, German, French). Installed voices are filtered by speech language, with a test button. Thoughts, memory fragments and HUD labels are localized. A missing matching system voice is reported instead of speaking in a different language.

Bodies have connected, length-preserving animated branches and a flexible axial chain. Body envelopes resolve overlap, including mating contact; rotated tissue footprints constrain terrain contact and gravity returns unsupported land organisms to the ground. Focused eyes have colored irises and pupils that follow targets; inherited traits can instead produce compound eyes and antennae. Gradually developed affect influences exploration, attachment and escape behavior.

**88 paired quantitative loci** now map to inspectable fictional A/C/G/T DNA chromosomes with gene offsets and complementary strands. F10 exports the selected DNA as JSON. Mitotic growth and tissue repair consume energy. Reciprocal meiotic tetrads produce actual stored haploid gametes; fertilization restores paired alleles. Heritable facultative strategies can invest in both clonal buds and sexual reproduction. Odd-looking forms remain eligible if they can function and survive.

See [Alpha15 details and controls](docs/ALPHA15_DE.md), [AI interfaces](docs/AI_INTERFACES_DE.md), and [validation status](docs/TESTING.md). Visual style remains procedural instanced geometry; the reference creature is not a promised photorealistic rendering.

### Alpha14: deeper biological mechanisms

The world remains the main application and runs fully offline without AI integrations. Inheritance now uses **84 diploid loci**, linked segregation/recombination, partial dominance, inherited sex chromosomes and eight recessive-load loci. Juvenile development spends real reserves; mature organisms synthesize finite egg/sperm reserves. Embryonic stages develop according to energy, temperature, oxygen and health. Food particles refill over time instead of instantly recreating consumed energy.

**All alpha13 controls and features remain available**, including with MCP, VKLP or both active. Connecting does not pause/reset the world or lock controls. Fixed stepping is an explicitly chosen experiment mode. Optional Python-standard-library adapters let AIs observe and run experiments, apply external information with provenance, and send simulation-scoped claims/evidence to the user's VKLP 0.1 service. A visible game continues when the MCP connection closes.

See [Biology](docs/BIOLOGY_RESEARCH_DE.md), [optional AI interfaces and runnable examples](docs/AI_INTERFACES_DE.md), and [validation status](docs/TESTING.md). The optional adapters require Python 3.10+; normal installation and gameplay do not. The installer keeps its cache search and native Godot parsing/self-test gates.

The following sections describe the retained earlier features. Alpha14's biology document supersedes older descriptions of scalar inheritance and age-only development.

### Alpha13: coastal ancestors and complete reproductive cycles

New worlds start in **coastal habitat 7**, now with usable sky. Aquatic founders begin underwater with constrained terrestrial/flight traits; those bounds apply only to founders, so their descendants can evolve beyond them. The previous default of habitat 5 migrates once; other saved habitats remain selected.

Reproduction now has compatible gamete roles, courtship/contact, fertilization, egg incubation or embryo retention/gestation, birth and immature offspring. Twenty additional inherited parameters cover reproductive anatomy, dimorphism/displays, developmental stages, genetic compatibility and brief cross-medium hunting. External spawning, internal egg laying, yolk-fed egg retention, maternal provisioning and plant/clonal propagules are distinct mechanisms. There is no automatic cloning fallback for sexual organisms. Embryos consume parental resources, can be lost and reserve population slots.

Bodies visibly grow through life stages; appropriate combinations can develop larvae and pupae. Scientific Cell view exposes schematic primary reproductive tissues; secondary display structures mature with the body. Individuals develop and learn; populations evolve genetically across generations. Arbitrary Earth species cannot cross merely because they meet: compatibility is an explicit simplified model, not a biological guarantee.

Strong swimmers can breach for low aerial prey; land hunters can snap at nearby swimmers or leap; suitable flyers can dive shallowly. Physical reach, breath, stamina and recovery constrain these actions. The water surface now has animated waves, view-angle highlights/opacity, a visible underside and a terrain-matched shore contour. **L chooses a new random sun direction on each press**; it stays fixed until changed or auto_sun is selected.

The installer includes **51 ecology + 71 covering + 115 life-cycle assertions**. They pass in the source-translation harness; native Godot/Windows rendering and installation have not been tested here. See [Life cycles and model limits](docs/LIFE_CYCLE_DE.md) and [Testing](docs/TESTING.md).

**Alpha11 parser hotfix:** renamed the ecological gene loop binding `trait` to `gene_name`. Godot 4.7.2 rejected the old identifier and consequently could not load the dependent simulation/self-test scripts. Package validation now also checks loop bindings, constant names and static-function parameters against reserved names. The alpha10 ecology and larger world are retained.

### Alpha12: heritable body coverings

Organisms can combine **skin, scales, feathers with quills, fur/bristles, mucus, membranes, horns/spines, beaks and pigment patterns**. Nine additional inherited genes affect visible structures, insulation, water drag, drying, skin breathing, protection, bite strength and maintenance costs. Feathers can develop on non-flying bodies without fins; flight still requires a capable skeleton/body, wings, air respiration, practice and open sky. A simple local temperature gradient gives insulation both benefits and costs.

Coverings share the existing cell budget and use stylized instanced geometry. Tree stems gain bark colouring. The inspector separates coverings from ecological adaptations and displays ambient temperature. EN/DE/FR help and 71 covering assertions are included, alongside the 51 ecology assertions. The alpha11 reserved-name fix remains included.

### Alpha10: larger world and ecological specialization

The default world is now **144 × 86.4 × 144 units**, twice each previous dimension (eight times the volume). Old settings migrate once. New heritable traits connect respiration, locomotion, body load, feeding and behavior: amphibious life, structurally gated flight in sky habitats, pack hunting, ambush, tools, hiding, cleaning, parasitism, upright gait, small insect-like forms and rooted photosynthetic/filter-feeding bodies. Land trees require supporting traits. The visible terrain and organism floor queries now share one heightfield.

The inspector shows adaptations, current behavior, oxygen, stamina, moisture and learned skills. Evolution remains constrained by the implemented gene/body grammar; no particular Earth species or advanced form is guaranteed. Population rescue is now optional and off by default; there is no forced culling based on complexity/intelligence.

**Deutsch:** [Neue Lebensweisen und Bedienung](docs/ECOLOGY_DE.md). **Validation:** [Testing and limitations](docs/TESTING.md).

**Controls:** 5–9 habitat stages; 7/8/9 provide usable sky; NumPad + / - changes world size.

**Engine target:** Godot 4.7.2 stable  
**License:** MIT

## TL;DR

GAN Organism Arena is now a real **3D artificial-life aquarium** instead of a 2D cellular simulation with a 3D visualization layer. Organisms exist and move in X/Y/Z, consume resources in a volume, reproduce through mutation and two-parent genetic crossover, build three-dimensional bodies, accumulate bounded experience, and develop increasingly expressive communication.

On Windows, run:

```text
install_windows.bat
```

The installer prepares a **portable local copy of Godot 4.7.2** in `runtime/godot/`, parses every core GDScript deterministically, runs an advanced morphology/genome/language/appendage self-test plus 51 ecology, 71 covering and 115 life-cycle assertions plus a clean project-context runtime smoke test, and starts it after a 10-second cancelable delay. Nothing is installed system-wide. Before downloading, alpha9 searches the current runtime folder, nearby/sibling project trees and the Windows Downloads folder for an existing `Godot_v4.7.2-stable_win64.exe.zip`; only the official SHA-256-valid archive is reused. Internet is therefore only required when no valid local copy exists.

## Controls

- Mouse — free look
- W/S — swim forward/back
- A/D — strafe
- Q/E — descend/ascend
- Shift — boost
- Mouse wheel — optical zoom; Shift + wheel — observer speed
- L — new random light direction; persists until changed
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

The project deliberately decouples simulation from rendering. Organism decision/evolution ticks default to 12 Hz while the camera can render at the display frame rate. Each organism uses two MultiMeshes for body tissues and their connections. Articulated poses update at up to 20 Hz. Only visible organisms need animation uploads; biology and physical poses continue outside the camera view. Morphology is rebuilt only when development visibly changes. Per-organism event memory is bounded.

The most useful performance controls are:

- **Contact accuracy** (default 85; 100 for detailed footprint support)
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


## Alpha9 installer/cache and camera update

The mouse wheel now changes optical camera FOV in both free-swim and organism-follow modes. Hold Shift while using the wheel to change observer movement speed. The Windows installer now searches nearby/sibling project directories and the user Downloads folder for `Godot_v4.7.2-stable_win64.exe.zip`, verifies the official SHA-256, and reuses it before attempting a network download. Smoke testing runs through a dedicated scene that frees the main simulation before exiting.
