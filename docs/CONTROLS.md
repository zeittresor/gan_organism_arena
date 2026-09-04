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
| Esc | Release / capture mouse |


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
