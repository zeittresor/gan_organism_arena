# Testing — 1.0.0-alpha18 (2026-09-02)

## Reported Windows failure and correction

The supplied alpha17 Windows log confirms that Godot 4.7.2 loaded and instantiated every script in the native per-file parser list. At installer step 5, `locomotion_test.gd:113` then failed while assigning an untyped Array literal to the typed `nutrient_field.points: Array[Vector3]` property. The self-test returned exit code 29; the remaining installer stages were not reached. The ObjectDB/resource warnings appeared after this aborted test.

Alpha18 creates an explicit local `Array[Vector3]` and assigns that value. The food fixture is also attached to the test node for owned cleanup. The production locomotion, anatomy, ecology, contact and reproduction algorithms are the Alpha17 implementation.

The native Godot executable and Windows GUI are not available in this build environment. The Python source-execution harness substitutes engine objects and does not reproduce Godot's full type system. This limitation allowed the original typed-array assignment to pass source checks. Successful grammar parsing also cannot detect every runtime property-assignment error.

## Fresh Alpha18 checks

- Full source self-test: 3,371 locomotion, 5,443 interaction, 51 ecology, 71 covering, 115 lifecycle, 617 biology and 18 experiment assertions, plus the core morphology/genome/language checks.
- All 41 GDScripts grammar-parsed with gdtoolkit; reserved names, duplicate functions, preload references, native parse registration and active versions checked.
- Every declared typed-array member was audited for direct property assignment from array literals. A new conservative source rule rejects such assignments in both the Windows verifier and the build checker. It is not a general-purpose GDScript type checker.
- Regression check: the new rule rejects the original alpha17 `food.points = [...]` assignment and accepts the corrected project. Untyped `reserves` and `sex_chromosomes` arrays remain valid.
- EN/DE/FR JSON, formatted HUD fields, all 54 option/action labels and tooltips, and disabled-by-default protocol permissions checked.
- ZIP CRC, complete SHA-256 manifest and payload count verified after fresh extraction. Personal settings and runtime/test logs are excluded from the distributable.

Exact results are recorded in `BUILD_VERIFICATION.txt`. Alpha18 has not been installed or rendered natively here. The Windows installer retains native parser, full self-test and smoke-scene gates, including script-error scanning; no failing test has been disabled.

## Earlier integration evidence

Alpha17 source checks also exercised five habitats, mating/gestation/birth, resource and population bounds, deterministic experiment reset/stepping, 42 rotated terrain-contact comparisons, cache invalidation, visibility and offscreen biology. Fifteen Python adapter tests and the real MCP stdio/TCP path into a substitute-engine execution of the production game API passed. These are earlier results, not fresh native Alpha18 execution. The user reported fluent Alpha16 gameplay.

Normal installation and gameplay do not need Python. Optional adapter tests:

```text
py -3 -m unittest discover -s tests -v
```

For a native MCP integration check in a separate test project folder, enable MCP in F10 and run:

```text
py -3 tests/live_arena_check.py --headless
```

That integration scenario deliberately resets its test world.

## Movement model and visual checks

The [Alpha17 movement notes](ALPHA17_DE.md) describe limited turning, rigid skeletal segments, muscle-driven joints and soft-body articulation. The model uses schematic inherited mechanical parameters rather than measured tissue properties. Individual tendon forces, self-collision and full foot inverse kinematics are not implemented.

Windows checks still include the visible movement through turns, limb attachment, courtship contact, slopes, directed eyes, all view modes and localized system speech. Alpha18 corrects the reported installer blocker; native appearance and FPS require a successful Windows run.
