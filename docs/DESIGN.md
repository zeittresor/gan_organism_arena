# Design notes

## Why not one GAN per organism?

A separate full GAN per organism would be computationally wasteful and would not create real-time decision making. This project uses a more scalable model:

```text
shared morphology generator
+ individual genome vector per organism
+ lightweight behavior policy
+ heuristic critic
```

The result behaves like a population of differentiated organisms while remaining fast enough for an interactive Panda3D visualizer.

## Simulation layers

1. **Life physics**: Conway-like birth/survival/death rules.
2. **Organism interpretation**: connected components become trackable organisms.
3. **Genome**: each organism receives latent traits.
4. **Policy**: each organism can apply small local interventions in Organism Mode.
5. **Critic**: the world and organisms are scored for activity, survival, density, and motion.
6. **Evolution**: successful organisms can spawn mutated descendants.

## Future ONNX integration

A real GAN generator can be added by placing files under:

```text
src/pandalife_gan/assets/models/gan_generator.onnx
src/pandalife_gan/assets/models/gan_critic.onnx
```

Then implement loading/inference in:

```text
src/pandalife_gan/ai/model_loader.py
```

## Localization design

Runtime UI text is loaded from editable JSON files in the project-level `language\` directory. English is the canonical fallback. The app currently ships:

```text
language\en.json
language\de.json
language\fr.json
```

The Settings option **Language** changes the active file and stores the selected code in `settings\config.json`. Missing keys fall back to English so manual translation edits cannot easily break the UI.

The root README and full documentation remain English by design so the repository has one canonical documentation language.

## License

The project uses the MIT License. The canonical license text is stored in `LICENSE.txt`.
