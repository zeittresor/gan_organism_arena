# Replaceable optional textures

Enable **Use optional PNG textures** in F10 Settings. This option is off by default.

- Eight terrain maps cover habitat ground, silt, rock and organic soil plus height-blended deep seabed, wet shore, beach sand and grass.
- Six organism maps cover skin, scales, fur, membrane, plates and mottling. Each founder starts with a weighted pair selected from its inherited surface traits and seed.
- Fifteen detail maps cover specialised or future tissue categories. Horns, beaks, feathers, wings, fins, claws/limbs, armour, eyes, bone, neural tissue, leaves, bark/roots, reproductive surfaces and ornaments receive thematic slots. Unknown later tissue uses `adaptive.png` rather than an untextured surface.
- Four material maps (`wood`, `stone`, `metal`, `cloth`) are supplied for current and later tools, armour or clothing. A texture can only appear once the corresponding object/feature exists in the simulation.
- Press **F9** after replacing a file. Existing inherited coats remain stable; the terrain and future founders use the replacements.
- PNG files up to 1 MiB each are accepted. The 33 supplied files are seamless 256×256 maps and together remain below 3 MiB. Terrain sampling blends stable random offsets, quarter-turns and reflections between neighbouring regions, while organism segments use separate stable excerpts. Replacements are resized to 128×128 internally, so small square, tileable, neutral-coloured images with no unique large landmark work best.

At a sexual birth, the program builds a new 128×128 map by mixing the actual parent pixels equally. A later child therefore inherits the already mixed result of previous generations. A clone gets an independent pixel copy. The organism's inherited pigment colour still modulates the pattern. Use **Export selected coat texture** to save the selected generated map under `exports/textures`.

The original photographic-style defaults were generated with the built-in OpenAI image tool. Alpha27 removes their unique macro landmarks with deterministic spectral reconstruction and adds compact procedural transition/tissue maps. All remain neutral diffuse material maps without text, perspective, cast shadows or a depicted animal.
