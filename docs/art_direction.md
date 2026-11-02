# Below the Abyss — visual direction / BTA-040

This document retains the original BTA-040 study and subsequent revisions. The
user-requested BTA-049 review revision below supersedes its vector-only asset policy.
Artwork is for review, not approved final production art. No new font or runtime
dependency is included.

## Palette and hierarchy

| Role | Hex | Use |
| --- | --- | --- |
| Deep water | #02050B | Depth gradient's darkest end, negative space |
| Shelf water | #06202B | Shallow ocean, muted teal atmosphere |
| Basalt | #09181F | Solid rock base; restrained strata |
| Stone rim | #3B7078 | Exact navigable collision boundary |
| Hull porcelain | #D2D6C5 | Survey vessel dorsal silhouette |
| Hull steel | #638F98 | Mid-value lower hull |
| Bioluminescence | #53C6C2 | Observation dome, sparse mineral seams |
| Station brass | #B5A779 | Platform markings and familiar safe landmark |
| Focus | #D9E0A6 | Persistent two-pixel keyboard/controller focus |
| Instrument ink | #D1E6DE | Text and numerical readings |

Cool negative space dominates. Warm paint belongs to the station, not every object.
Preserve existing SAFE/CAUTION/DANGER text and symbols independently of palette.

## Environment principles

A dark depth gradient supports cached, low-contrast distant ridges. Parallax2D uses
0.24 horizontal / 0.18 vertical far scroll and 0.48 / 0.32 near scroll; the background does not contain
real POI shapes or map/discovery information. Broad low-opacity shafts imply distant
water illumination. Sparse motes drift slowly at 15 redraws/second. Static ridges
remain cached; moving the camera transforms them without rebuilding geometry.

Every rock's Polygon2D silhouette and CollisionPolygon2D still use the identical
original outline. A shared inexpensive shader adds stepped strata/grain, while a
fine contour traces the exact wall. Mineral scratches remain inside the polygon.
Station platform/post paint and paired spire seams distinguish existing landmarks.
Organic fine-line details are nonsolid filigree, not filled passage-blocking walls.
No new environmental interaction, collectible or narrative fact is implied.

Deeper water becomes darker/cooler without darkening UI. Readable wall rims and the
submarine remain visible in the optional pressure trench. Hazard signs remain text.
Avoid textures that camouflage narrow passages or imply navigable holes in solids.

## NERIS silhouette and animation

The original 80x48 SVG is centered on the existing 64x32 capsule footprint: blunt
observation bow, aft propeller, dorsal survey mast, porcelain shell and ventral keel.
Small fittings may extend beyond the capsule; they do not redefine collision bounds.
The forward dome and restrained illustrated lamp wedge communicate heading. Only
the Visual child mirrors with horizontal velocity; physics body, camera, saves and
vertical movement stay unchanged. Propeller phase stops when vessel simulation stops.
The wedge is illustrative light, not a visibility/occlusion or sonar rule.

Keep the body recognizable in silhouette at native scale; reserve dorsal shell,
ventral keel and panel slots for later reviewed damage/upgrade art, without implementing
those states here. Do not rotate the physics capsule to animate art.

## Sonar and instruments

Existing wave radius/timing/receipts remain authoritative. Fine angular ticks add a
scientific instrument cadence to the expanding ring; no new target or terrain reveal.
Discovery endpoints retain temporary echo outlines, textual captions and independent
permanent discovery semantics. Passive bearing arrows, classification/strength/expiry
and bars retain their existing information hierarchy and use the common instrument
palette. Listening still creates no visual world discovery.

A shared Theme gives HUD panels and station/map/research/mission/save controls the
same dark-teal materials, muted borders and warm focus outline. No layout/font-size
reduction, text removal, focus logic or input binding change is needed. Active text
stays readable; disabled buttons remain visibly different and retain their reasons.

## Assets, scaling and pipeline

Author vectors in local world units: SVG 80x48, displayed 1:1, with no raster scaling
up for the vessel. Environment geometry is in authored world coordinates. Reference
window is 1280x800; 800x600 is the minimum supported UI size. SVG imports through
Godot's existing importer. New originals and provenance are listed in
`assets/art-provenance.csv`; project licensing remains undecided.

Screenshots are rendered by Godot, not illustrations composited to resemble gameplay.
The capture fixture stages matching poses on baseline and implementation for review;
it is explicitly not evidence of flying a route. Existing full-suite flight and
save/resume tests provide gameplay regression coverage.

## Performance and accessibility

Use shared materials, cached static CanvasItem draws and bounded mote counts (150).
No bloom, full-screen postprocess stack, realtime shadows or dynamic light texture
allocation. Gradient is one polygon pass; rock shading uses simple arithmetic.
Particles update at 15 Hz with subpixel travel; no flashes or camera shake. Camera
framing and physical interpolation remain unchanged. Art never hides warnings or
changes UI input/focus. Review at low display brightness, both window sizes and deep
trench; avoid relying on color alone.

60 FPS on modest desktop hardware is the target, not certified by a software-rendered
cloud VM. See the testing record for measured frame intervals and limitations. Desktop
GPU, Windows/macOS and physical controller visual checks remain external work.

## BTA-048 interface revision

The approved compact production layout supersedes the original instrument panel
sizes described above. Existing InstrumentGlyph vectors accompany integer resource
percentages: green #22C55E, yellow #EAB308, red #EF4444, classified on normalized
fractions before rounding. LOW/EMPTY/INVALID and pressure/threat words/symbols remain
legible independently of color. Existing dark materials, contrast preferences and
focus treatments are reused. No environment, vessel, fauna or asset-pipeline art
changes. [Measured native comparisons](testing/bta-048/README.md).

## BTA-049 — The Halcyon Descent

The approved title extends this palette with original layered SVG composition,
not photographic imagery. The shared Lantern-2 master retains the existing blunt
bow, offset dome, mast, keel and 80x48 local footprint; title scale uses the same
640x384 texture as the playable sprite. Three connected Halcyon habitat/lab/dock
modules and restrained brass windows match the immediate departure installation.
Dark basalt planes, atmospheric depth and faint light wedges are reusable methods,
not new collision or discovery information. Existing terrain rims remain authoritative.

Title navigation uses actual Controls and the existing focus/contrast policy, with
no delayed activation, input-blocking entrance animation or flashing selection.
Slow waves, particulate drift and parallax have a static Reduced Motion alternative.
No fullscreen postprocessing, 3D, realtime shadows or new rendering dependency.
Sources/provenance remain in assets/art-provenance.csv; licensing is pending with
the rest of the project. [Asset workflow, native comparison and measurements](testing/bta-049/README.md).


## BTA-049 requested review revision — illustrated assets and restrained type

The user explicitly authorized a richer asset-driven treatment and smaller type
across every interface. The new `assets/art/painted` masters are AI-generated PNGs,
not hand-painted by a human, photographed, downloaded from a stock library or built
from more geometric drawing primitives. Weathered porcelain/steel Lantern-2, recessed
Halcyon habitat/lab/dock modules, stratified basalt, suspended-water light and textured
optics share the palette above. Title and gameplay load the same vessel/station/beam.
The playable vessel remains 80x48 world units over its original collision capsule.
Existing walls retain exact collision rims; illustration does not imply extra holes.

The original SVGs remain as silhouette/reference sources and historical fixtures.
Source PNGs, generator-file identities, dimensions and hashes are recorded in
`assets/art/painted/provenance.json`. Project licensing remains pending: generation
does not establish a new license or claim exclusive rights. No external dependency.

UiTypography is the semantic source of body, heading, menu, instrument and secondary
metrics. Standard prose is 16 px, dialog headings 18–20, title controls 17, secondary
14 and HUD/mission 16. Compact uses 90% with a 14 px floor; Large remains 125%.
Do not restore oversized defaults or shrink Large to make content fit: constrain the
panel, wrap prose and scroll. Keep text and focus outlines legible over opaque panel
surfaces, with only the surrounding world dimmed.

Painted surface reflections use a small, texture-local displacement of the water
layer. Cosmetic phase is explicit and freezes with Reduced Motion/softer effects.
The lamp is a shared transparent painted texture, not layered polygon wedges. Slow
parallax and bounded motes remain; no screen-read pass, realtime shadows or lighting
simulation. Full scene material and renderer limits remain in the revision evidence.

[Current native screenshots, asset workflow, art-review limits and exact commands](testing/bta-049/revision/README.md).


## BTA-050 — Sunlit Shallows illustrated environment

Use PR #33's painted material language in the canonical 0–200 m route: weathered
basalt, thin restrained mineral deposits, organic olive/teal vegetation, quiet
scientific hardware, soft depth haze and readable small fish. Foreground solids
keep their exact collision outlines. Painted edge trim stays inside current stone;
plants cannot block piloting, and lost supports hide them after excavation.
Distant illustration stays lower contrast than solid walls and never depicts
undiscovered architecture, a playable next region or new interaction markers.

The scene owns all art/comfort state and restores the previous prototype visuals
on chapter switching. Two inexpensive parallax planes use existing static hardware/
optics; baked diffuse light plus sparse shafts replace broad procedural decoration.
Thirty-six sediment/marine-snow points and four rising bubbles share two cached
particle masks and batched draws. Motion updates at most 15 Hz, stops with
simulation/reduced motion and never moves a physics body. No fullscreen screen-read,
noise postprocess, realtime shadows or new runtime dependency.

[Asset dimensions, unchanged generation masters, provenance and import settings](../assets/art/sunlit/README.md).
[Native before/after, measured costs and visual-review limitations](testing/bta-050/README.md).
Final human art approval, source cleanup, GPU profiling and external playtests remain
review gates. Do not equate a green test suite with a professional-art acceptance.

## BTA-052 — Surface-to-shelf continuity

Use the existing painted Halcyon module and water masters for a visible ocean
horizon, with a submerged service cradle and a physically fixed y=0 surface.
Grounded rough shelves, sheltered caves and an open upper water column replace the
canonical blanket ceiling. Landmarks remain at their established coordinates.
Nine cached rays add restrained first-surface lamp illumination to basalt and edge
trim, without full-screen postprocessing. Fauna uses atlas-clamped deformation;
Reduced Motion freezes it. A tiny slow red beacon has a steady reduced-flashing
alternative. Icon-labelled research cards and resource-deck ammunition follow the
existing semantic typography. Original torpedo master provenance and limitations
are recorded in assets/art/sunlit/README.md; verification in testing/bta-052/README.md.

### BTA-052 visual-review correction

Keep a single authored physical ocean surface. The title's baked wave texture must
not be reused as a water column. Use the new horizon-free submerged-water master;
clip parallax cliffs below world y=24 with a gentle fade into depth. Rounded textured
basalt has no technical cyan contour in the canonical region. Destructible rock is
warm ochre/clay with sediment banding and an irregular rounded plug silhouette;
protected geology remains cool basalt. Silhouette/material cues supplement colour.

Radio uses small original illustrated role portraits, not invented late-story lore.
Okafor/Crane/Mara appearances are provisional visual proposals because the supplied
Story Bible does not fix their physical features. Wick remains an optical instrument,
not a human. Source dimensions/import/provenance: assets/art/portraits/README.md and
assets/art/sunlit/README.md. Human character-art approval remains outstanding.

## BTA-054 — Twilight Shelf environment and wildlife

Carry the submerged illustrated language into cold mineral gardens, weathered
historic timber and pale natural fauna. Original atlas art supplies real material
detail; rock trim follows the unchanged passage contours. A distant whaler is not
Lantern-1. No surface waves, alien architecture, glyph or later-story revelation.
Visible/textual vent warnings and a bounded local plume survive comfort settings;
cosmetic phase never moves the vessel. See [masters, authored regions, provenance
and reusable workflow](../assets/art/twilight/README.md).

### BTA-055 sentinel

The Twilight sentinel is an original generated long-bodied luminous marine animal,
not a recoloured predator. It shares the region's painted cool materials and
restrained ivory/cyan light. Existing explicit-phase fauna shader supplies motion;
Reduced Motion disables cosmetic deformation. An illustrated retrieval-net overlay shares its material detail; the scratched
marking and muted curved cable are small authored functional illustrations.
[PNG provenance/import details](../assets/art/twilight/sentinel-provenance.json).
Human art/readability acceptance remains separate from automated validation.
