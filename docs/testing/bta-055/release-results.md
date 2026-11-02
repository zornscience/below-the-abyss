# BTA-055 release results

Tested runtime source: `3ecfa35d0aa7d33cfe3987a4efa4e113045705d3`. Engine `4.6.3.stable.official.7d41c59c4`,
GUT 9.6.1, Compatibility. Source was clean for export (`development_dirty: false`).
Subsequent evidence/provenance documentation and main-integration commits do not
change gameplay code, scenes, shaders or rendered image bytes.

Full suite: **727/727**, **43,271 assertions**, **579.083 s**, no failures/errors/skips.
Import, **301 parser checks**, startup, all original and new input matrices,
seven Python tests, four native chapter processes, clean Linux export and standalone
package launch passed. Raw logs and graphical gallery are linked in [README.md](README.md).

Native deep simulation time, excluding first-chapter preparation and paused reading:
**252.550 seconds** west-first/release, **343.250 seconds**
east-first/capture. These experienced automated routes are much shorter than the
**30–45-minute novice-human target**. That target is **not verified or claimed**;
pacing/content density and unfamiliar-player comprehension remain review items.
No artificial waiting pads these times. Both routes use zero torpedoes, ordinary
movement/actions/menu focus, deliberate return and exactly one debrief allowance.

Package: `below-the-abyss-playtest-linux-3ecfa35d0aa7.zip`. Binary SHA-256:
`e7cf3c053078041a0476176b0955b70580d7bdd8c5d1e68d163ddb40df4f7df4`. See [manifest](logs/manifest.json) and
[export result](logs/linux-export.json). No binary release was published.

Automated results are separate from human playtesting, audible-mix review,
physical-gamepad testing, target-GPU performance and art/readability approval.
Native screenshots are original unedited Godot viewports on software rendering.
No Drowned Caves or later-campaign gameplay is implemented.

PR/hosted-CI publication status will be recorded after push. No automatic merge.
