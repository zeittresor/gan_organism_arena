# Windows testing guide — 1.0.0-alpha9

1. Extract the ZIP to a normal writable folder (not directly inside the ZIP viewer).
2. Run `install_windows.bat`.
3. The installer downloads a portable local Godot 4.7.2 runtime, verifies its SHA-256, runs a deterministic all-script GDScript parse test, then the artificial-life self-test and a short runtime smoke test.
4. After the 10-second prompt the arena starts automatically unless cancelled.

If Forward+ / Vulkan does not open correctly, use `run_compatibility.bat` to force Godot's OpenGL compatibility renderer.

For diagnostics, run `run_diagnostics.bat` and send these files if something fails:

- `logs/install/install_*.log`
- `logs/latest_runtime.log`
- any console output shown by `run_selftest.bat`

The most useful alpha8 observations are: whether all seven broad morphology families are visibly distinguishable, whether descendants diverge in proportions across generations, whether cross-family offspring appear, whether unstable morphologies disappear naturally, whether close organisms still oscillate against one another, and whether RMB follow stays behind the tail/rear instead of chasing the centre. FPS after long runs and TTS/Settings usability are still useful too.


Alpha8 focus: test keys 5-9 and NumPad +/-; observe whether aquatic forms are disadvantaged on land, whether terrestrial/flight traits eventually appear, whether courtship/group/predation behavior is visible without jitter, whether populations keep producing generations at cap, and whether ambient + positional organism audio is audible independently of TTS.

## Clean runtime smoke test

Run `run_smoketest.bat` after installation to instantiate the real Main scene headlessly, run it briefly, perform orderly shutdown and verify the `SMOKETEST OK` marker.
