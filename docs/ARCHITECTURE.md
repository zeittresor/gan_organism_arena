# Architecture — GAN Organism Arena 1.0.0-alpha6

## Simulation

`ArenaSimWorld` owns a bounded 3D aquarium, nutrient field and living `ArenaOrganism` instances. Behavior and evolution are evaluated at a configurable simulation tick rate, independent of rendering FPS.

Each organism has a mutable `ArenaGenome` with continuous drives for morphology and behavior. The current prototype computes movement from resource attraction, social affinity, threat response, curiosity and buoyancy. Reproduction creates mutated descendants and never assigns a fixed terminal species.

## Developmental morphology

`OrganismVisual` builds a local 3D body from instanced low-poly biological cells. The body is deliberately developmental rather than a static mesh lookup. Complexity alters axial length, support structures, head/sensor concentration, paired appendages, digit-like branches, fins, armor and feather-like fans.

Visible body-cell count is capped as an LOD/performance constraint. The organism's actual complexity and cognition are not capped by that visual budget.

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
