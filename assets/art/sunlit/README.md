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

## BTA-051 additions

| Asset | Dimensions | Provenance and use |
| --- | --- | --- |
| school_species.png | 2172×724 | Original unchanged OpenAI `image_gen` output, transparent three 724×724 cells: silver shoal, amber darter, blue grazer. Shared by each school's MultiMesh and its scientific notification. |
| bloom_thumbnail.png | 256×128 | Offline Godot render of the actual repository LightBloomVisual. |
| plate_thumbnail.png | 256×128 | Offline Godot render of the actual repository ShelfStoryDetails calibration plate. |

All three import losslessly with mipmaps and linear mipmap filtering. Exact bytes,
hashes and origins are in provenance.json; the fish output is AI generated, not a
human-painted layered master. Existing BTA-049/050 raster masters are unmodified.
Regenerate the two subject thumbnails using the pinned engine, not a network call:

```sh
godot --path . --script res://tools/render_science_thumbnails.gd
```

The expanded layout reuses basalt strata/trim, kelp variants, the Halcyon cradle,
searchlight shafts and background relief. Its protected collision geometry is
separate from these decorations; only the authored rockfall is excavatable.
Soft excavation dust uses a cached 64×64 native GradientTexture2D and one batch;
eight textured falling fragments use a second batch. Both expire in four simulation
seconds and obey comfort flags. Ambient schools use one MultiMesh/one receiver
per group, no fish collision bodies and a bounded fixed-step model. Their entire
static habitat must be clear; this is conservative avoidance, not pathfinding.

The underwater scientific subjects remain placeholders, not taxonomic claims about
real species. Human art, atlas-edge and target-GPU approval remain outstanding.

## PR #35 feedback additions

`marine_animals.png` is a 2172×724 transparent, original OpenAI image_gen output:
three equal 724×724 cells for a moray eel, sea turtle and hammerhead. The hammerhead
silhouette was revised with the same tool; the committed master is the unchanged
edited output, not a human-painted layered source. Exact source identities/hash are
in provenance.json. Lossless import, mipmaps and linear mipmap filtering match the
existing schools. Painted widths are 120/88/140 world units, with gentle body roll
and eel skew; Reduced Motion removes these decorative transforms. Actual movement
uses the existing acoustic creature navigation. Human anatomy/atlas-edge review and
production licensing remain outstanding; no new exclusive rights are claimed.

Rough protected rock, the thick rockfall and clipped basalt material share the same
deterministic authored contours. No decorative false passages are painted over solid
walls. Seafloor bubbles use twelve fixed source locations, staggered deterministic
phases and one 36-instance batch. They do not consume gameplay RNG. The plankton
encounter now drifts locally while alive; its interaction/research location is fixed.

The new underwater detonation uses three bounded batches: ten soft cavitation cloud
sprites, 28 rising bubble rings and twelve textured fragments, plus a brief existing
local refraction shader and pressure flash. No extra full-screen shader is added.
Reduced Effects/Particles/Motion use the launcher's existing comfort policy, removing
the decorative batches, flash and lens. The remaining quiet ring expires in 0.65 s;
the full cosmetic effect expires in 2.6 simulation seconds. Audio sources are original
fixed-seed PCM DSP in `tools/synthesize_feedback_audio.py`, not recordings. Regenerate:

```sh
python3 tools/synthesize_feedback_audio.py
```

Radio uses UI volume/mute; muffled blast and occasional cosmetic bubble chirps use
Effects volume/mute and the existing voice budgets. They generate no gameplay
AcousticEvents. See [review evidence and limitations](../../../docs/testing/bta-051/revision/README.md).

## BTA-052 presentation additions

`torpedo.png` is the unchanged transparent 2172×724 original OpenAI image_gen
output recorded in provenance.json. Painted ceramic, metal panels, nose, tail fins
and a propeller replace the white rectangle. Godot imports a 512-pixel-wide runtime
texture with mipmaps/lossless compression and linear mipmap filtering; rendered
size is 48×16 world units. Collision remains a swept ray, not the silhouette.
No new exclusive licensing or human painting claim is made.

The ocean horizon reuses `painted/descent_water.png` and Halcyon's existing painted
modules. It adds two low-amplitude wave lines over the artwork; the physical surface
is fixed at world y=0. Terrain lighting uses nine cached terrain rays and bounded
material illumination, not full-screen postprocessing or physically accurate optics.
Fauna uses atlas-clamped UV deformation driven by an explicit simulation clock;
Reduced Motion disables the deformation. All new visual clocks are scene-owned.
