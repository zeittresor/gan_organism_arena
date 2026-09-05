# Controls

| Input | Action |
|---|---|
| Mouse | Look around |
| W / S | Swim forward / backward |
| A / D | Strafe left / right |
| Q / E | Descend / ascend |
| Shift | Boost movement speed |
| Mouse wheel | Optical zoom in/out |
| Shift + mouse wheel | Change observer speed |
| Left click | Select organism under crosshair |
| Right click | Follow / unfollow selected organism from behind its anatomical rear/tail |
| Tab | Select next organism |
| Space | Pause / resume |
| L | Set a new random fixed light direction; choose auto_sun in Settings for movement |
| F10 | Settings |
| F1 | Help / project guide |
| 1 | Natural view |
| 2 | Cell / tissue view |
| 3 | Neural view |
| 4 | Energy view |
| G | Inject random organism |
| F8 | Export selected organism as OBJ |
| F12 | Screenshot |
| Esc | Open exit prompt: settings, save world snapshot + quit, quit without saving, or cancel |


## Habitat stages (alpha8)

- `5`: open water only
- `6`: water with seabed / emerging islands
- `7`: default coast with water, substantial land and usable sky
- `8`: land, shallows and usable air volume
- `9`: combined water + land + open sky
- `NumPad +`: expand the simulation volume by one configured world unit
- `NumPad -`: shrink the simulation volume by one configured world unit

The habitat stage itself also grows the world by one configured unit per level above 5.

New founders start underwater. The former default habitat 5 migrates to 7 once; other saved habitats are preserved.


Alpha15 F10 additions: MCP and VKLP on/off; VKLP submissions on/off; VKLP URL; spoken language and matching installed voice; test speech; save/load named JSON settings profiles; export selected DNA. Every option/action has an EN/DE/FR tooltip. Profiles save settings, not the population/world state. OBJ export includes the current articulated tissue geometry and its connections.


Alpha19 F10 addition: **Planetary gravity (× Earth)**, 0.20–2.50, default 1.00. Applies on resuming from the menu, persists in normal settings and named profiles, and affects gravity, buoyancy forces, ballistic reach and flight support. `simulation_speed` remains independent.

Alpha24 F10 addition: **Automatic reseed target**, 1–80, default 5. While **Automatic reseed** is enabled, the live population is checked continuously and restored to this target with unrelated aquatic hatchlings. The effective target is limited by the organism cap and reserved embryo slots; disable reseeding to allow extinction.

Alpha29 additions: **Plant-niche discoverability** lowers or restores the inherited thresholds for rooting and stationary feeding (aquatic founders remain motile). Aquatic deaths are retained as bounded remains that grow into seabed coral/mineral features over simulation time. **Escape** opens a paused exit prompt; the save-and-quit choice writes a complete JSON world snapshot to `exports/world_saves`.


## Alpha25 options

- **F10 → Evolution overview:** births versus introductions, generations, first new topologies, rooted population and recent genealogy.
- **F10 → Export evolution history:** bounded genealogy and run counters as JSON in `exports/evolution`; observation only, not a reloadable world save.
- **F10 → Allow new reproduction:** controls new courtship/fertilization/cloning independently of automatic rescue; existing embryos continue developing.
- Small-mutation strength now permits zero. Disable both small and major mutation settings for mutation-free inheritance. Major-mutation probability displays three decimal places.
- Population rescue responds immediately while paused, also after pending dead organisms are cleaned up. Embryo reservations continue to limit free capacity.
