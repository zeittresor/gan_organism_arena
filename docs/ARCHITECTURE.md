# Architecture — GAN Organism Arena 1.0.0-alpha20

## Simulation

`ArenaSimWorld` owns a bounded 3D aquarium, nutrient field and living `ArenaOrganism` instances. Behavior and evolution are evaluated at a configurable simulation tick rate, independent of rendering FPS.

Each organism has a mutable `ArenaGenome` with continuous drives for morphology and behavior. The current prototype computes movement from resource attraction, social affinity, threat response, curiosity and buoyancy. Reproduction can be asexual mutation or two-parent genetic crossover. A heritable mutability gene controls how far descendants can drift, while rare macro-mutations can switch the developmental body topology. A viability score penalizes metabolically expensive structures that lack sufficient support, so some combinations die out rather than being silently normalized. Heritable longevity introduces gradual senescence; this matters because a population that reaches its cap must still turn over for Darwinian selection to continue indefinitely.

## Developmental morphology

`OrganismVisual` builds a local 3D body from instanced low-poly biological cells. The body is deliberately developmental rather than a static mesh lookup. The morphology space currently contains seven topology families—serpentine, fusiform, radial, ray-like, branching, crustacean-like and cephalopod-like. These are developmental topologies rather than fixed species. Continuous genes alter width, elongation, flattening, head/tail allocation, limb placement/length/thickness, fins, armor, shell/support and branching, while complexity reveals more structure over an organism’s lifetime.

Visible body-cell count is capped as an LOD/performance constraint. Cells can now also be anisotropically scaled, so bodies are not forced to be chains of identical spheres. The organism's actual complexity and cognition are not capped by that visual budget.

## Rendering

Godot `MultiMesh` is used for body cells, nutrient particles and water-dust particles. Articulated local poses update at a bounded cadence (20 Hz), and static colors/scales are cached. Invisible organisms skip graphics uploads while their simulation and body poses continue. The parent Node3D carries world translation and orientation.

## Cognition / communication

The cognition model is intentionally small but stateful: energy, hunger, fear, curiosity, social tendency, experience and bounded episodic events. Communication stages progress from calls to syllables, token-like symbols, phrases, sentences and more compositional translated outputs.

The current language generator is procedural, not an LLM. That is intentional for deterministic/offline operation and makes later integration of local neural agents possible without coupling the basic simulator to a cloud service.

## Next acceleration layer

The preferred next technical step is a GDExtension/C++ or compute-shader module for sparse volumetric tissue simulation. Candidate architecture:

1. chunked 3D occupancy / tissue field;
2. compute-shader neighborhood updates;
3. developmental morphogen fields;
4. neural cellular automata for local tissue differentiation;
5. SDF/metaball rendering for smooth organism surfaces;
6. Marching Cubes only for export or close-up LOD;
7. evolutionary neural controller (NEAT/HyperNEAT-like topology mutation);
8. optional learned critic/GAN pressure for novelty and structural viability.


## Social motion and follow camera

Neighbour steering combines cohesion with a preferred separation radius. Very close organisms repel before their steering loops collapse into permanent oscillation. Reproduction has a cooldown and does not require two parents to occupy the same point. The observer follow camera queries anatomical rear/focus anchors from the generated morphology and follows behind the tail/rear in movement space.


## Alpha8 habitat/ecology layer

Habitat rendering is separated in `game/habitat_visual.gd`; ecological selection remains in the simulation core. `aquatic_drive`, `terrestrial_drive`, and `flight_drive` are mutable genome traits. Social vectors now combine spacing, group cohesion, courtship orbiting, hierarchy and predator/prey pressure. `game/audio_ecosystem.gd` synthesizes bounded procedural PCM streams for ambience and spatial organism signaling.


## Alpha10 ecological specialization

- `habitat_model.gd`: one sampled, triangulated heightfield for both surface rendering and organism floor queries. Water/land searches stay within the world. Open sky is available in habitats 7/8/9 as of alpha13.
- `ecology_traits.gd`: shared capability formulas for physiology, movement, decisions and morphology. New ecological genes participate in ordinary mutation, crossover and seeded macro-mutations.
- `ecology_system.gd`: resource patches, shared prey planning, local pack roles, learned tactic weights, finite host/food transfers, tools and rooted productivity. Respiration emergencies take priority over feeding and courtship.
- `organism.gd`: oxygen reserve, moisture, stamina, lifetime skills, medium transitions, locomotion and support constraints. There is no forced complexity-based survival score at the population cap.
- `organism_visual.gd`: scale, upright/rooted/insect-like development and sparse animated wings/legs/leaves; reserves part of the cell budget for adaptive structures.
- `settings_store.gd`: schema migration doubles legacy world size once; nutrients default to 540. Auto-reseeding is optional and defaults off.

The model is bounded artificial life, not unconstrained body invention, general intelligence, or a validated biological prediction. Trait thresholds and resource conversion coefficients are explicit game mechanics. Learning changes an individual's skills, not inherited memories.

API references: [SurfaceTool](https://docs.godotengine.org/en/stable/classes/class_surfacetool.html), [MultiMesh](https://docs.godotengine.org/en/stable/classes/class_multimesh.html).


## Alpha13 lifecycle and interactions

- `life_cycle.gd`: shared maturation, stage-specific respiration, sex roles, reproductive modes and genetic compatibility proxies. Somatic development and population evolution are separate.
- `reproduction_system.gd`: bounded pairs and broods, continuous contact before fertilization, maternal/yolk budgets, external egg survival, reserved birth slots, parentage and resource-conserving parental care. Existing embryos continue when new reproduction is disabled. No immediate sexual offspring or unconditional cloning fallback remains.
- `genome.gd`: twenty inherited lifecycle/interaction loci; the aquatic founder limiter is called only by random ancestor injection. `fertility_factor` carries reduced hybrid fertility separately from mutable morphological genes.
- `organism.gd` / `organism_visual.gd`: nutritional maturation delays, juvenile scaling, larva/pupa/adult bodies, reproductive tissue and displays; temporary ballistic/dive states suppress sustained flight steering and spend stamina.
- `ecology_system.gd`: persistent-habitat reach and brief hunting reach are separate. Bite transfer requires spatial contact; predation never creates reproductive hybrids.
- `water_surface.gdshader`: two-sided, transparent lit surface with analytic wave normals. No screen-texture/depth-buffer dependency. Coast contour intersects the same terrain triangles used for floor queries; cosmetic waves do not change the mean waterline used by ecology.
- `life_cycle_test.gd` and `reproduction_test_world.gd`: deterministic production-code checks with a subclass overriding settings reads; tests do not write user settings.

The renderer still uses one instanced body mesh per organism. New anatomy uses the existing cell budget. Each brood uses one small marker mesh and all unborn offspring count against reserved population capacity. Pair/brood/history storage remains bounded by the active population limits.

## Alpha14 biological state and optional adapters

Genome retains paired alleles independently of phenotype. Physiology allocates reserves to development and gametes; reproduction consumes those pools and develops embryos. The fixed-step experiment API reads and operates on the same SimWorld. An optional loopback gateway is loaded only with --arena-api. The stdio MCP adapter is a separate Python-standard-library process; VKLP uses the existing zeittresor/VKLP HTTP contract. Normal game startup imports no Python modules and opens no network listener. Connecting does not select step mode or lock UI controls. Claims and external-knowledge interventions carry explicit provenance. See BIOLOGY_RESEARCH_DE.md and AI_INTERFACES_DE.md.


Alpha15 modules: `body_contact.gd` constrains articulated envelopes and terrain footprints; `organism_visual.gd` maintains one acyclic attachment graph for pose and connecting tissue. Render cost is bounded by `visual_cell_cap` tissues plus at most `cap-1` connectors. Contact envelopes are conservative and do not simulate elastic tissue deformation or self-collision of an individual.
`cell_cycle.gd` handles paid somatic mitoses, tissue repair and finite haploid gamete pools. `genome.gd` constructs reciprocal meiotic tetrads and reunites stored gametes. `dna_codec.gd` maps alleles to a fictional regulatory nucleotide code and provides substitutions.
`affect_model.gd` supplies cognition-dependent affect variables used by steering. Four additional inherited sensory/affective loci choose eye focus, compound eyes, antennae and affective plasticity.
Settings profiles are validated transactionally and applied through the same UI setting signals. `ai_gateway.gd` enforces per-protocol permissions against SettingsStore on each request; adapters also check current config before access. `arena_vklp.py` is the direct HTTP client usable with MCP disabled.


## Alpha19 mechanical support

`body_support.gd` caches structural ellipsoid immersion and terrain targets at a quality-dependent cadence. `anatomical_rig.gd` defines bounded passive axial pitch alongside muscle-driven local articulation. `organism_visual.gd` propagates independent ideal support frames to avoid serial-chain feedback, then damps the actual joint angles without changing rigid segment lengths. Terrain contact, rendering and export read the same posed cells/bases. `body_contact.gd` uses structural tissues for weight-bearing contact and removes exactly contained envelope spheres. `locomotion.gd` gradually aligns the root pitch with the support slope; gravity remains external to intent and applies to unsupported pupae as well.

`gravity_scale` defaults to 1.0, is validated within [0.2, 2.5] in profiles and experiment interventions, and is read live by the same physics. The nominal acceleration is 9.8 world units/s². Density and immersion determine buoyancy; powered flight has a gravity-dependent lift threshold. Observation model `arena-biology-4` exposes support state and axial vertical limits/angles. Schematic overlapping ellipsoids approximate bulk volume; neither fluid dynamics nor tissue stress is simulated.


## Alpha20 articulation and connector corrections

Axial proximal pivots and `atan2` terrain-tangent targets replace half-lever linear correction. Support sampling accumulates mass/contact centers and suspended clearance without new terrain queries; these bias serpentine root pitch under overhangs. `anatomical_rig.gd` adds a bounded trailing pitch response to swimming turns. Existing static bones and rate-limited poses remain intact. Posed head/tail anchor accessors use their anatomical parent frames.

Cranial beaks/first horns resolve a head attachment instead of inheriting a potentially distant coat-sample parent. Zero-radius links upload a zero basis, matching hidden tissue geometry and the existing OBJ determinant filter. `posture_test.gd` exercises actual link transforms as well as sharp ridge/shore poses and swimming curvature. Model identifier: `arena-biology-5`.


## Alpha21 render buffers

Hidden connectors have no MultiMesh slot. Active links use compact contiguous indices, rebuilt on view/anatomy changes. CPU body/link transform buffers are shared by upload and OBJ export; export and posture validation do not use RenderingServer transform readback.

## Alpha22 navigation

`navigation.gd` supplies persistent local exploration goals, energy-based foraging hysteresis, head-local food capture and a seven-second no-progress recovery. Food targets that fail are excluded for fourteen seconds; sensing is range-limited and uses larval/adult respiratory capability. Exploration targets last 8–16 seconds unless reached or stalled. Bounded local water alternatives keep exploratory swimmers away from dry goals; this is not a global path planner.

`steer_towards` assigns the winning intention rather than averaging opposed destinations. `locomotion.gd` still bounds physical turns and acceleration. Social and affect steering remain bounded route influences. `reproduction_system.gd` caches a compatible partner of interest at 0.8–1.1 second intervals and approaches before probabilistic courtship, without bypassing maturity, gametes, compatibility, capacity or fertilization rules.

Model identifier `arena-biology-6`, observation schema `arena.observation/1`: additive navigation fields expose goal, target, speed, food target, mate interest, meal count and replans. UI controls and optional protocol permission behavior are unchanged.
