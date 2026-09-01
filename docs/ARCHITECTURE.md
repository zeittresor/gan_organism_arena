# Architecture — GAN Organism Arena 1.0.0-alpha9

## Simulation

`ArenaSimWorld` owns a bounded 3D aquarium, nutrient field and living `ArenaOrganism` instances. Behavior and evolution are evaluated at a configurable simulation tick rate, independent of rendering FPS.

Each organism has a mutable `ArenaGenome` with continuous drives for morphology and behavior. The current prototype computes movement from resource attraction, social affinity, threat response, curiosity and buoyancy. Reproduction can be asexual mutation or two-parent genetic crossover. A heritable mutability gene controls how far descendants can drift, while rare macro-mutations can switch the developmental body topology. A viability score penalizes metabolically expensive structures that lack sufficient support, so some combinations die out rather than being silently normalized. Heritable longevity introduces gradual senescence; this matters because a population that reaches its cap must still turn over for Darwinian selection to continue indefinitely.

## Developmental morphology

`OrganismVisual` builds a local 3D body from instanced low-poly biological cells. The body is deliberately developmental rather than a static mesh lookup. The morphology space currently contains seven topology families—serpentine, fusiform, radial, ray-like, branching, crustacean-like and cephalopod-like. These are developmental topologies rather than fixed species. Continuous genes alter width, elongation, flattening, head/tail allocation, limb placement/length/thickness, fins, armor, shell/support and branching, while complexity reveals more structure over an organism’s lifetime.

Visible body-cell count is capped as an LOD/performance constraint. Cells can now also be anisotropically scaled, so bodies are not forced to be chains of identical spheres. The organism's actual complexity and cognition are not capped by that visual budget.

## Rendering

Godot `MultiMesh` is used for body cells, nutrient particles and water-dust particles. An organism's local cells are uploaded only on morphology rebuild; movement then happens by moving the parent Node3D. This avoids rebuilding hundreds of cell transforms every rendered frame.

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
