# GAN Organism Arena

A 3D artificial-life world for watching organisms feed, grow, reproduce and evolve. Start with ten aquatic organisms sampled from fourteen changing startup forms and observe what their descendants become as inherited traits and mutations meet the environment.

<img width="1920" height="1080" alt="arena_00005315" src="https://github.com/user-attachments/assets/8a6a05de-04f1-4a63-859d-56cfaf299434" />

<img width="1920" height="1080" alt="646812821-d911d339-64ae-4c53-91b3-40f50154e580" src="https://github.com/user-attachments/assets/84d1b1e0-61d1-401b-8b45-b4a22abfd290" />

<img width="1920" height="1080" alt="646529127-c91da578-978a-4d93-91b4-570ef8703176" src="https://github.com/user-attachments/assets/07d91894-fd24-4f4f-b8da-2d0635cd3dcc" />

<img width="1920" height="1080" alt="646812838-cd0b7163-48f2-4555-a4fb-e169a1b69580" src="https://github.com/user-attachments/assets/1a8a4cae-f704-4488-b284-263f90201830" />

<img width="1920" height="1080" alt="646529057-bb9b0e14-66b8-4403-ab44-4ba09e8e1f62" src="https://github.com/user-attachments/assets/28618a0f-0c28-4542-a875-53412452eb23" />

**Windows · Portable · 1.0.0-alpha38**  
Interface and speech settings: English, German and French.

## Start playing

1. Extract the Windows ZIP into its own folder.
2. Run **`install_windows.bat`** once.
3. Start the simulation with **`run_windows.bat`**.

Godot is installed inside the project folder. The installer reuses a verified local runtime archive when available; otherwise it downloads it. A separate Godot installation is unnecessary.

## Complete controls

| Key / mouse | Action |
| --- | --- |
| W / S or Up / Down | Move camera forward / backward |
| A / D or Left / Right | Move camera left / right |
| Q / E | Move camera down / up |
| Mouse movement | Look around while the pointer is captured |
| Shift while moving | Move the camera three times faster |
| Mouse wheel | Zoom in / out, including while following |
| Shift + mouse wheel | Reduce / increase camera movement speed |
| Left click | Select the organism under the crosshair |
| Tab | Select the next organism |
| Right click | Start / stop following the selected organism |
| **P, Space or Pause** | **Pause / resume the world** |
| **F10 → Help** or **F1** | **Full guide and option reference** |
| F2 | Hide / show the HUD for an unobstructed view |
| F8 | Export the selected organism as OBJ |
| F9 | Reload optional PNG templates when textures are enabled |
| F10 | Open / close settings |
| F12 | Save a screenshot |
| L | Randomize lighting |
| G | Introduce one unrelated young aquatic founder if capacity permits |
| 1 / 2 / 3 / 4 | Natural / cell / neural / energy view |
| 5 / 6 / 7 / 8 / 9 | Open water / seabed and islands / coast / land and shallows / full sky habitat |
| Numpad + / − | Increase / decrease world size |
| Escape | Open the exit prompt: settings, save world + quit, quit without saving, or cancel |

While paused, you can still look around and inspect organisms. Opening settings, help or the exit prompt also pauses the world. World shortcuts are inactive while menus are open. Escape again cancels the exit prompt; closing the window opens the same prompt.

## Make it your world

Use F10 to adjust the habitat, population, reproduction, sound and graphics, or save and load settings profiles. Hover over an option for an explanation. The **Help** button explains the simulation and every option in detail. **Plant-niche discoverability** controls how readily inherited anchoring and stationary feeding can produce rooted aquatic or land plants; founders still start as motile aquatic organisms.

The camera starts at a terrain-safe shore viewpoint. Follow mode keeps the complete camera path above the heightfield. In Settings, **Camera noclip** optionally allows travel through mountains and the seabed. **Human observer presence** adds an adult humanoid signal that organisms can notice, approach or avoid without making the observer edible or a mating target. **Show interface text** and **Show aiming crosshair** can be switched off independently for clean observation; F2 remains a quick HUD toggle.

Optional PNG textures are off by default. Enable them in F10 to use eight terrain, 21 organism/tissue and four future tool/material patterns. The 33 supplied seamless 256×256 files together remain below 3 MiB. Terrain maps include deep seabed, wet shore, beach sand and grass and blend according to height around the waterline. Landscape maps contain no dominant source landmarks; the terrain shader also blends deterministic random offsets, quarter-turns and reflections so one tile no longer appears as an obvious grid. Body segments use stable individual excerpts and orientations. Specialized tissues such as bone, eyes, fins, leaves, bark, wings, feathers, horns, beaks, limbs/claws, armour and reproductive surfaces are assigned thematic maps; an adaptive fallback prevents future unknown tissue from becoming untextured. Wood, stone, metal and cloth are prepared for tools or clothing, and the current carried tool uses wood. Replace files below `textures`, then press F9 or use **Reload PNG textures**. Founders receive varied weighted coat pairs. Every sexual offspring receives a new 50/50 pixel mixture of its parents' actual coat maps; this continues through later generations. Clonal offspring copy their parent's map. The generated texture of a selected organism can be exported from Settings.

If an optional image is missing or invalid, the texture switch fails safely back to the normal vertex-colour materials. Aquatic founders and descendants with fewer than three inherited transition steps remain in the water; land and flight require evolved respiration, support and locomotion rather than appearing at startup.

The **Evolution overview** separates natural offspring from automatically introduced replacements. Dead organisms leave a finite amount of edible tissue. Scavengers can feed on it, decomposition returns part to nearby food particles, and hard remains persist temporarily as inert substrate. Coral-like outcrops and stones decorate the seabed; dead animals do not automatically become living coral. DNA and evolution history can be exported for inspection. Evolution is experimental: particular creatures or abilities are not guaranteed.

Use **F10 → Save world / Load world** for resumable `.arena` checkpoints. They preserve organisms, DNA, gametes, developing embryos, inherited texture pixels, food stocks, remains, history, camera and random-generator state. **Escape → Save world and quit** saves under `exports/world_saves` and exits only after verifying the file. Loaded worlds start paused: close the menu and press **P** to continue. Loading preserves your current interface permissions. Alpha29 JSON analysis snapshots are not resumable checkpoints. Rendering and contact caches are rebuilt on load; frame-exact replay across versions is not promised.

Offspring receive one homolog from each parent at every locus. Head, torso, limb and tail development use tissue-specific regulatory mixtures of those inherited variants; body parts need not all resemble the same parent. Cognitive and behavioral predispositions are inherited too, while experience and practiced skills develop during life. Mutations can be beneficial, neutral or harmful; the habitat determines which variants reproduce successfully. Head proportions now follow supporting body tissue, with only mild juvenile enlargement.

Each new world builds seven canonical founder genomes plus seven fresh crossover mixtures of those genomes, then samples ten distinct entries from the fourteen-form pool. The pool is driven by the run seed, so the same seed is reproducible while a new start produces a different initial gene pool.

## Inheritance rather than blending of individual trait values

There are 84 continuous trait loci, each possessing two alleles. During sexual reproduction, each parent contributes a haploid set. Adjacent loci are arranged in groups of up to 16 on an artificial linkage map. At chromosome boundaries, a homolog is selected independently; the probability of crossover between adjacent loci is 0.06. These figures are parameters of a hypothetical genetic system, not empirically measured terrestrial recombination maps.

In the absence of mutation, existing alleles are passed on; a heterozygous parent does not generate arbitrary intermediate alleles. Some traits exhibit partial dominance, while others are expressed additively. Consequently, two heterozygous parents can produce a 1:2:1 genotype distribution. Mutation alters individual alleles; major structural changes are controlled separately and occur less frequently than before (0.014 instead of 0.14 per reproductive event).

Eight additional, independently segregating model loci carry recessive deleterious alleles. A single harmful copy has no effect, whereas two copies reduce genetic health by 0.09 per locus. Related animals do not incur a blanket penalty based on their family ID; however, they may pass on the same hidden alleles. Heterozygosity measures the proportion of distinct allele pairs across the 84 trait loci; it is not a general measure of fitness.

Where sex roles are distinct, an inherited XX/XY-style model configuration determines the role. Hermaphroditism remains a heritable trait. This convention does not replicate the full range of natural sex-determination systems. Learned hunting behavior and experience with tools are not inherited as acquired germline mutations.

## Having trouble?

For slower or incompatible graphics hardware, try `run_compatibility.bat`. If installation or startup fails, use `run_diagnostics.bat` and include the files from `logs` when reporting the problem.

Optional AI connections: [MCP and VKLP guide](docs/AI_INTERFACES_DE.md). They are off by default and are not required to use the application.

[Changes](changelogs/CHANGELOG.md) · [License: MIT](LICENSE.txt)
