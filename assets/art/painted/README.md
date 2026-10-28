# BTA-049 illustrated masters

User-authorized AI-generated artwork, made with OpenAI `image_gen` on 2026-10-28
UTC. These are model-generated PNGs, not human-painted layered sources or licensed
stock artwork. No new project license or exclusive rights claim. See
[provenance.json](provenance.json) for original generation-file identities, exact
pixel dimensions and SHA256; [project ledger](../../art-provenance.csv).

The PNGs are unchanged copies of the generated outputs. Original outputs remain at
`/workspace/generated_images` in the authoring workspace. The generator does not
provide a reproducible model version/seed here: reproducing the **build** uses these
committed bytes, not a claim that regenerating a prompt yields identical pixels.
No generation service or dependency is required to play or export.

| Master | Art-direction brief (summary, not verbatim generation prompt) | Runtime reuse |
| --- | --- | --- |
| lantern_2.png | Original right-facing blunt observation dome/mast/keel silhouette; weathered porcelain, steel panels, seals, lamp and aft propeller; transparent | Title and playable 80×48 sprite |
| halcyon_modules.png | Original habitat/lab/dock silhouette; recessed brass-lit windows, worn modules, truss, cables and restrained scientific hardware; transparent | Title, immediate departure, station menu |
| shelf_cliff.png | Painted basalt relief, mineral wear, varied cool lighting, transparent water side; no structures or secrets | Layered title relief and local Halcyon background |
| descent_water.png | Dark ocean/sky, restrained surface reflection and underwater shafts; quiet left-side negative space | Texture-local animated title water |
| basalt.png | Muted painted basalt surface with material variation; no objects, labels or navigable holes | Exact authored rock/carved polygons |
| searchlight.png | Transparent textured aquamarine/brass-white beam, left source, soft particulate falloff; no objects | Title, vessel and station lighting |

Silhouette references for vessel/station/cliff/water came from this repository's
`assets/art/identity` SVG studies, rasterized by Godot for the authoring reference.
Basalt and beam were generated from descriptive briefs. No external artist, game,
photograph, recognizable franchise style, downloaded texture or third-party font was
specified. Source dimensions/aspect ratios are fitted explicitly without altering
world/collision geometry. The existing stable sprite node name remains for save/test
compatibility; it is not an indication of a new vessel identity.

Import losslessly with mipmaps and linear mipmap filtering for minification. Keep
transparent art separate from opaque water/materials. The title relief edge shader
feathers rectangular layer ends; its alpha silhouette is still authored artwork.
Motion uses the explicit cosmetic clock, with static comfort alternatives. No
screen read, runtime lighting simulation, new collision, camera rule or discovery.

Future production delivery should include human-reviewed editable material/lighting
layers, native-scale silhouette sheets, cleaned alpha edges and genuinely seamless
material variants with an explicit license. The generated PNGs do not substitute
for those source-delivery requirements. See the revision's native comparison and
commission checklist before visual acceptance.
