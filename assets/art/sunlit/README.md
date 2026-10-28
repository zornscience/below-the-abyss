# Sunlit Shallows illustrated assets — BTA-050

Seven original AI-generated PNG outputs made with OpenAI `image_gen`, under the
user-authorized environmental-art scope. These are **not human-painted layered
sources, photographs, stock assets or licensed third-party art**. Project licensing
remains pending; no new license or exclusive rights are claimed. Original generator
outputs remain in `/workspace/generated_images`; committed PNG bytes are unchanged.
[Provenance, exact dimensions, SHA256 and source-file identities](provenance.json).
Generation is stochastic and no reproducible model/seed is supplied; reproducible
builds use the committed masters, not a claim of pixel-identical regeneration.

| Asset | Dimensions | Purpose and import |
| --- | --- | --- |
| kelp_atlas.png | 1254×1254 | Four organic plant variants; transparent, lossless, mipmaps |
| shelf_panorama.png | 1774×887 | Distant basalt/water atmosphere; opaque, lossless, mipmaps |
| basalt_strata.png | 1254×1254 | Broad weathered geology/mineral material; opaque, repeat, mipmaps |
| rock_edge.png | 2172×724 | Transparent worn ledge trim; clipped inside actual solid polygons |
| fish_atlas.png | 1774×887 | Existing green observer / tawny predator presentation; transparent, mipmaps |
| service_cradle.png | 1536×1024 | Halcyon support, deck, pressure housings and umbilical wear; transparent, mipmaps |
| emergency_buoy.png | 1024×1536 | Existing recording buoy, worn pressure shell/antenna/tether; transparent, mipmaps |

All use linear mipmap filtering at runtime. Source alpha-edge correction remains
Godot's importer setting; no custom Python raster processing or image compositing.
The kelp atlas has an authored split at normalized y=0.56, with per-cell holdfast
anchors; it is not assumed to be a perfectly regular generated sprite sheet.
Fish cells are equal horizontal halves, fitted to the prior illustration footprint.
Keep import files and atlas anchors with the master when reusing it.

Art briefs: quiet scientific continental shelf, cool teal/indigo with olive mineral
wear; flowing ribbon/feather/bull kelp and low fans; eroded basalt/quartz/barnacles;
soft distant shelves; scientific brass/porcelain/steel fixtures; small believable
fish scales and fins. No text, unrelated franchise/artist, new creature behavior,
alien structure, wreck reveal or future-zone lore was requested. Repository-owned
PR #33 Halcyon/cliff masters provided the material/palette references for all except
the plants, which used a descriptive brief. Existing title, vessel, station and
searchlight assets are reused unchanged.

The material is illustrative, not surveyed geometry. Painted trim is intersected
with the actual current polygons, including excavations, and does not invent
openings. Background rock is fogged/low contrast; only existing foreground terrain
is solid. Vegetation, scientific fittings and particles have no collision/interaction.
The floor/cave silhouette remains angular where required by unchanged graybox
collision data; this pass does not pretend to have redesigned the level.

Before production approval, a human artist should review atlas gutters, alpha
edges, material repetition, native-scale fish detail and editable source layers.
The texture is repeatable by the renderer but not certified as a seamless hand-
retouched material. Baked illumination remains static in reduced-effects mode;
this is not dynamic visibility/occlusion or a new light-toggle mechanic.

## Reuse workflow

1. Start from an approved native-scale palette/material sheet and actual solid
   contours. Separate distant atmosphere, painted material, clipped edges and props;
   an attractive background is not a substitute for readable passages.
2. Preserve the original raster master and record dimensions, generation/artist
   provenance, reference sources, hash and licensing status. Human review/retouching
   should produce editable source layers before production approval.
3. Import static masters losslessly with mipmaps. Test atlas gutters/anchors and
   alpha edges at their actual in-game size; repeat only appropriate material maps.
4. Compose decorations in a scene-owned presentation layer. Clip solid-looking trim
   to authoritative current stone; never derive collision or discovery from paint.
   Reuse the comfort clock/flags, bounded batches and visibility-driven initialization.
5. Capture identical authored poses before/after in all supported window sizes and
   comfort modes. Run the unchanged navigation, chapter, save and accessibility tests.
6. Profile live gameplay independently of still captures, retain regressions as well
   as improvements, and obtain target-GPU and human readability/art approval.

This is a proposed asset pipeline, not implementation of another playable region.
