# Twilight Shelf assets — BTA-054

Three original AI-generated illustrated PNG masters made with OpenAI `image_gen`
under the user's level-details/NPC request. No stock library, photograph, external
runtime dependency or imitation of another game's artwork. These are not human-
painted layered sources. Project licensing remains pending; no new license or
exclusive-rights claim is made. Exact source identities, dimensions and SHA256s:
[provenance.json](provenance.json). Committed PNG bytes are unchanged generator
outputs. Fauna layout was revised using the image-editing tool to improve gutters.
Generation is stochastic; reproducible builds use the committed masters.

| Master | Size | Runtime use |
| --- | --- | --- |
| environment_atlas.png | 2172×724 | Detailed mineral-crusted basalt vent chimneys, fragmented historic wooden whaler, pale cold-water sponge/tube-worm garden |
| deep_water.png | 1942×809 | Horizon-free dark painted canyon/water; no angular prototype relief or baked surface |
| fauna_atlas.png | 2172×724 | Natural eel, squid and jellyfish; equal-width cells, right-facing, alpha background |

The environment atlas has **authored nonuniform regions**, not an assumed perfect
three-cell grid: x=0..610 vent, 610..1550 wreck, 1550..2172 garden. Keep these regions
in TwilightDressing with the master. Runtime flora uses varied scale/facing; the
wreck is darker background archaeology, not a secret Lantern-1 identification or
an interactable hull. Two vent colliders approximate the painted chimney silhouettes;
they never span a passage or change BTA-053's authored passage contours.

Import: lossless, alpha-border fix, mipmaps enabled, linear mipmap sampling. Keep
.import metadata with the masters. The existing basalt, rock-edge, cliff and searchlight assets retain their original provenance and
bytes. No surface or wave master is used in the deep level.

Fauna reuses AcousticCreature navigation, AcousticReceiver dispatch, stable IDs and
BlastReceiver health. An explicit-phase shader adds eel undulation, squid mantle/
arm motion and jelly bell pulses. Headings follow actual movement. Reduced Motion
stops cosmetic deformation, while the creatures continue their actual swimming.
They are natural ambient wildlife, not the canonical Warden/sentinel story encounter.

A bounded texture-local plume shader animates existing searchlight art; it does not
read the screen, move the submarine, use global TIME or create GPU particles.
Reduced Effects/Motion make it steady; warning text and a visible plume remain even
when decorative particles are disabled. Marine snow is one 40-instance batch.

Reusable workflow: preserve the original master and provenance; author atlas regions
and collision/holdfast anchors explicitly; keep render art separate from authoritative
terrain; validate alpha/gutters at native gameplay scale; add comfort flags and bounded
updates; capture actual Godot evidence and obtain human art review. Pixel-identical
regeneration, professional art acceptance and target-GPU 60 FPS are not claimed.
