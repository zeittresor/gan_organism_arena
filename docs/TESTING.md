# Windows testing guide — 1.0.0-alpha6

1. Extract the ZIP to a normal writable folder (not directly inside the ZIP viewer).
2. Run `install_windows.bat`.
3. The installer downloads a portable local Godot 4.7.2 runtime, verifies its SHA-256, runs a deterministic all-script GDScript parse test, then the artificial-life self-test and a short runtime smoke test.
4. After the 10-second prompt the arena starts automatically unless cancelled.

If Forward+ / Vulkan does not open correctly, use `run_compatibility.bat` to force Godot's OpenGL compatibility renderer.

For diagnostics, run `run_diagnostics.bat` and send these files if something fails:

- `logs/install/install_*.log`
- `logs/latest_runtime.log`
- any console output shown by `run_selftest.bat`

The most useful first observations are: startup success, FPS after several minutes, organism body variety, whether organisms visibly move in all three axes, whether selection/follow works, whether TTS works, and whether Settings/Help remain usable at 1920x1080.
