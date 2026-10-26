# BTA-040 verification

## Reproduce

```sh
python3 tools/install_gut.py
python3 tools/validate_godot.py
python3 tools/run_tests.py
godot --path .
```

Native art evidence (requires X11):

```sh
DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 godot --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/fixtures/capture_art_direction.gd
```

The fixture uses isolated `user://bta040-art-after.json` settings (no canonical save
profile), stages poses at base, cave, spires and trench, issues a real sonar request,
and renders 1280x800/800x600. These are actual Godot renders; staging is for composition
comparison, not a claimed input-driven route playtest. Decorative animation is not
serialized. Existing saves, navigation geometry and balance remain unchanged.

Before captures use the same fixture with `-- --before` in a separate checkout of
merged BTA-035 `f02f0e4`. They are native baseline renders, not edits of after images.

| Location | Before | After |
| --- | --- | --- |
| Base | [baseline](bta-040-before-base.png) | [new](bta-040-after-base.png) |
| Cave | [baseline](bta-040-before-cave.png) | [new](bta-040-after-cave.png) |
| Spires | [baseline](bta-040-before-spires.png) | [new](bta-040-after-spires.png) |
| Sonar | [baseline](bta-040-before-sonar.png) | [new](bta-040-after-sonar.png) |
| Deep | [baseline](bta-040-before-deep.png) | [new](bta-040-after-deep.png) |
| 800x600 | [baseline](bta-040-before-compact.png) | [new](bta-040-after-compact.png) |
| Menu | [baseline](bta-040-before-menu.png) | [new](bta-040-after-menu.png) |

## Manual review

1. Launch, Begin/Continue; fly the original cave → spires → lower return route. Check
   all walls match visible boundaries and the forward observation dome communicates
   heading when reversing. Vertical motion must not flip/rotate the body or camera.
2. Visit the optional trench: DANGER/ASCEND and numerical depth remain readable against
   darker water. Confirm hull/oxygen/battery bars retain contrast at low brightness.
3. Ping near known targets: new ticks must follow the same expanding radius, echoes
   appear on arrival and discoveries persist independently. Check passive arrows,
   classification, strength and expiry remain readable without color-only information.
4. Scan the plate, read research/map, accept/claim missions, install upgrades and use
   station services. Inspect focus in each interface using keyboard and controller.
   Save, quit and Continue; visual animation is temporary, progress/pose remain compatible.
5. Repeat menus at 800x600 and 1280x800. Check disabled actions and focus outlines, and
   observe harmless/predator behavior on their existing optional routes. No art should
   hide their telegraphing. Review staged world sign overlap separately from gameplay
   HUD; existing prototype instructional labels remain and need a later editorial pass.

## Performance observations and limits

Godot 4.6.3 GL compatibility, Linux X11 dummy display, Mesa llvmpipe software rendering.
The fixture samples 180 rendered process intervals at 800x600 after warmup. Baseline
observation: median 14.384 ms / p95 23.872 ms. An early art pass measured median
18.676 ms / p95 33.616 ms; a later run during validation measured 20.916 / 33.812 ms.
These VM/contention-dependent samples are not controlled desktop GPU benchmarks and
do not establish a performance improvement or a 60 FPS guarantee. Static background
caching, 15 Hz motes and arithmetic rock shading bound the added cost. Measure on the
target GPU before claiming the 60 FPS target is met; no hardware certification is made.

The lamp is non-occluding illustration, not physical lighting. No final production-art
approval, external human playtest, low-brightness hardware validation or native
Windows/macOS/controller certification is claimed. Original art provenance and scaling
rules are in [the style guide](../art_direction.md).

## Final verification

- Godot `4.6.3.stable.official.7d41c59c4`: import, 149 authored script checks and
  startup smoke passed; final atmospheric/sonar source checks also passed.
- Full GUT: **370/370 tests**, **24,396 assertions**, 46 scripts, **185.766 s**;
  zero failures/errors/skips. All earlier tests retained.
- Final presentation tests: 2/2, 41 assertions, including near/far scene composition,
  exact terrain outlines, original capsule dimensions and visual-only facing.
- Final isolated software-rendered observation (no concurrent test runner): median
  **15.826 ms**, p95 **25.135 ms** at 800x600 over 180 process intervals. The median
  is within 16.67 ms but p95 is not; consistent 60 FPS is not demonstrated.
- Pinned GUT verification, actionlint and whitespace checks passed.
- The PR records actual GitHub Actions results for its final commit.
