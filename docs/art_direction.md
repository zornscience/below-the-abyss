# Below the Abyss — visual direction / BTA-040

This is an original, implemented visual study for review, not approved final production
art. No external artwork, generated mockups, fonts or new dependency is included.

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
