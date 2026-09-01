# Testing — 1.0.0-alpha12 (2026-09-01)

## Alpha11 parser regression

The supplied Windows 4.7.2 log located the first failure at `genome.gd:116`, the `for trait` declaration. The other three script failures followed that failed preload. Alpha11 changes only that loop identifier in the evolutionary code, plus version metadata and verification/documentation.

The updated reserved-name expression was exercised against the actual alpha10 ZIP source (rejected), alpha11 source (accepted), bad loop/constant/variable examples, and legitimate names/comments/string examples. All 22 alpha11 scripts pass this declaration check. The source-harness self-tests were rerun successfully. Native Godot/Windows validation has not been performed here.

## Alpha12 covering checks

71 assertions execute the covering implementation: feathers without fins/flight, visible tissue types at small and normal cell budgets, mixed coverings, bounded rebuilds, insulation, water drag, moisture retention, skin permeability, actual bite protection, energy costs, inheritance, crossover and mutation bounds. These passed in the source-translation harness, along with the 51 ecology assertions and existing core tests. The full source simulation was rerun across habitats 5–9 after integrating the new physiology costs.

## Validation of the ecological implementation

- Structural source checks across 23 GDScript files: balanced delimiters, reserved variable names, duplicate functions, preload targets and current version metadata.
- English/German/French JSON parsed and ecological translation keys compared.
- 51 ecological assertions executed using a Python source-translation test harness with substitutes for Godot nodes, vectors and rendering resources: respiration, amphibious breathing, flight prerequisites, flight without sky, power/cost tradeoff, rooted productivity/anchoring, upright anatomy, finite tool food and wear, cleaning, parasitism, pack targeting, inheritance and reproducible mutation.
- The existing morphology/genome/language self-test also ran under that harness: seven distinct morphology signatures, valid crossover, viable versus unsupported construction and advanced procedural language output.
- The source simulation loop ran for 120 ticks in each of habitats 5–9 with 16 starting organisms. Assertions checked finite positions, terrain floor constraints and physiological ranges. Extinction cleanup did not secretly inject replacements.
- The settings migration block was executed against old defaults, a custom old world size and an already migrated configuration. A second load did not double the size again.
- Final archive integrity and per-file SHA-256 manifest verified during packaging.

**Limits:** The source-translation harness is not the Godot interpreter and uses simplified engine substitutes. It cannot establish Godot parser/type-checker compatibility, actual rendering, UI layout, audio, Windows PowerShell installation behavior or long-run ecological balance. No native Godot or Windows runtime test was possible in the build environment. This package is an alpha for testing, not a claim that every ecological niche will emerge in every run.

## Native Windows checks included

1. Extract the complete ZIP to a writable directory.
2. Run `install_windows.bat`. It reuses a checksum-valid nearby Godot 4.7.2 ZIP before attempting a download.
3. The installer runs package verification, the native GDScript parser probe, the original self-test **all 51 ecological assertions and 71 covering assertions**, then the clean-startup/shutdown smoke scene. Explicit script errors cause installation to fail even if a native process returns zero.
4. If it passes, the arena launches after the cancellable ten-second delay.
5. `run_selftest.bat` reruns the original, ecological and covering assertions in the project context. `run_parse_test.bat` checks scripts separately.

## Visual and behavioral acceptance

- Wheel zoom in free and follow views; Shift+wheel still changes observer speed.
- Keys 5–9: the shoreline matches the visible terrain; swimmers stay above the bed, grounded forms rest on the surface, and powered flight is confined to habitats 8/9.
- Select organisms with Tab/LMB. Watch oxygen, moisture, stamina, adaptations and current actions in the inspector.
- With suitable inherited traits and enough time, observe small arthropod-like bodies, upright forms, wings, rooted plants/filters and supported land trees. These are possible outcomes, not guaranteed unlocks.
- In the Natural view inspect skin, feathers/quills, scales, fur, membranes, horns and beaks across suitable inherited combinations. Feathered bodies must also exist without flight. Confirm the separate covering line and temperature remain readable. These visual/UI checks require native Godot and remain unverified here.
- Verify visible flank/drive hunting, hiding near cover, food extraction with a visible tool, and changing finite host/food resources. Skills should start fresh for offspring.
- Check longer runs for energy balance, starvation, survival diversity and generational turnover. With rescue off, genuine extinction is possible; G injects a new organism.
- If Vulkan does not open, use `run_compatibility.bat`. For diagnostics use `run_diagnostics.bat` and retain `logs/install/install_*.log`, the related parse/self-test/smoke logs and `logs/latest_runtime.log`.
