# BTA-057 — Sonar-driven Twilight visibility, Phase 1

User-selected Standard: **dim but readable**. Reduced is brighter. Applies only to
Twilight Shelf; no expedition schema, map, story, research, economy or combat change.
No human playtest results exist and none are claimed.

## Implementation / acceptance mapping

- Scene-owned TwilightVisibility, composed by ChapterJourney. One screen-texture
  darkness pass, then cached outlines from actual StaticBody2D CollisionPolygon2D
  children, including vent chimneys. No separately authored geometry or per-frame
  mesh rebuild. Shader uniforms use the inverse camera transform, preserving camera
  motion, window resizing and the existing vessel's small readable passive radius.
- Accepted SonarEmitter.pulse_emitted supplies origin, maximum radius and its copied
  travel speed. Presentation samples that emitter's simulation clock, so distance /
  speed gates every pixel; fade starts at arrival, never at emission. Out-of-range
  pixels stay dim. Eight fixed slots match the existing default pulse bound. No new
  receiver, acoustic dispatcher, identity/history semantics or permanent revelation.
- Existing headlight ray stops cap the short cone. Passive contacts retain their
  existing role. Faint cached terrain outlines and passive light within 150 units
  provide quiet-travel safety without pinging. Everything tunes through
  resources/balance/twilight_visibility.tres / TwilightVisibilityProfile.
- HUD remains above the darkness layer. A textual proximity cue and sonar state sit
  above the radio instrument. Standard/Reduced darkness appears after the existing
  accessibility toggles, retaining their established controller focus order.
  High Contrast selects brighter visibility/white outlines. Reduced Flashing lowers
  echo illumination; no strobe, camera shake or instantaneous fullscreen flash.
  Reduced Motion preserves essential wavefront timing and adds no cosmetic motion.
- SettingsStore accepts an optional strictly validated darkness preference in the
  existing personal preferences format. Missing means Standard. Explicit Save /
  discard behavior is unchanged. Expedition schema and permanent progress untouched.
- All five existing Twilight registration side effects previously inside assert()
  now execute explicitly and report errors in release. New lint rejects unapproved
  calls inside runtime assertions; existing pure validation assertions remain.
- The requested ReleaseSmoke/lint files were absent on main 3106076, so this change
  introduces them. An explicitly requested release diagnostic verifies the cached
  collision wiring, subscription, actual accepted ping and advancing reveal clock.
  Normal launches do not run it. The negative smoke flag disconnects that subscription
  in the exported binary, which must fail with RELEASE_VISIBILITY_WIRING_FAIL.

## Reproducible commands

Godot 4.6.3 official / GUT 9.6.1, Compatibility renderer, existing setup instructions.

```sh
python3 tools/lint_release_safety.py
python3 tools/run_tests.py
python3 tools/validate_godot.py
python3 tools/verify_expanded_expedition.py
python3 tools/verify_revision_two.py
python3 tools/verify_story_choice.py
python3 tools/verify_sunlit_shallows.py
python3 tools/verify_chapter_handoff.py
python3 tools/verify_twilight_habitat.py
python3 tools/verify_twilight_expedition.py
python3 tools/verify_twilight_survey.py
python3 -m unittest discover -s tests/python
python3 tools/build_playtest.py
# Use the package path printed by build_playtest.py:
python3 tools/smoke_playtest.py PACKAGE --log build/standalone.log
# This MUST return nonzero; it removes the actual release subscription:
python3 tools/smoke_playtest.py PACKAGE --log build/negative.log --break-visibility-wiring
```

Diagnostic native capture uses a region fixture, not a complete human expedition.
No new test hard-codes level coordinates: authored spawn/geometry are read directly.

```sh
mkdir -p /tmp/bta057-captures
BTA_EVIDENCE_DIR=/tmp/bta057-captures godot --path . --audio-driver Dummy \
 --rendering-method gl_compatibility --disable-render-loop --fixed-fps 60 \
 --script tests/fixtures/capture_twilight_visibility.gd
# Repeat with -- --small --controller for 800×600 / controller X input.
```

## Manual acceptance route

1. Begin/Continue Sunlit Shallows: verify it remains lit, menus/map and instruments
   are unchanged. Move to Twilight using the existing chapter handoff.
2. Travel quietly using WASD or left stick. Approach a wall: a faint outline and
   textual CLOSE TERRAIN distance should appear without a ping. Turn the vessel;
   only the short headlight cone should illuminate ahead. Reverse out of a pocket.
3. F / controller X (or remapped sonar) emits the existing paid pulse. Observe
   terrain/props emerge as the front reaches them, not immediately, and fade after
   arrival. Move away: origin stays fixed. Geometry outside range remains dim.
4. Pause mid-pulse; resume; restart/Continue. Transient echoes clear appropriately;
   no terrain map persistence is added. Existing discoveries and records persist.
5. Open Accessibility with keyboard/controller. Choose Reduced, Save, quit/reload.
   Test discard. Compare High Contrast, Reduced Flashing and Reduced Motion at both
   1280×800 and 800×600. Critical proximity/pulse information remains textual/visual
   while muted; no clue depends on audio or color alone.

## Performance and provenance limits

No generated, stock or third-party assets were added. The shader and collision-line
composition are original source code; existing illustrated assets retain provenance.
Rendering is one fullscreen pass plus visible cached line batches; uniform buffers
are bounded, preferences cached on change, and there are no per-frame Dictionary
snapshot/deep-copy or large geometry rebuilds in this component. Proximity samples
16 short physics rays at 10 Hz. Uniform uploads and driver allocation still exist.

The fixture measures 120 warmed frames at an identical camera pose, lit vs dark,
with normal rendering forced each frame. This measures software-renderer work plus
frame scheduling, not representative physical-GPU performance. Report actual final
numbers with hardware identification; do not claim 60 FPS without suitable hardware.
No human playtesting, physical controller testing or target-GPU validation exists.

Known scope limits: visual echo slots are bounded at eight; custom emitter profiles
allowing more concurrent pulses would need an explicitly approved rendering policy.
No occlusion/reflectivity simulation or permanent revealed-terrain map. Darkness does
not change gameplay eligibility, scientific scanning or passive-acoustic detection.
