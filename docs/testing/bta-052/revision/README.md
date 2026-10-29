# BTA-052 visual and exploration review revision

This updates [PR #36](https://github.com/zornscience/below-the-abyss/pull/36),
`bta-052-surface-expedition-polish`, for the latest feedback. No new
region, campaign branch, reward or save schema is introduced. The preceding
[BTA-052 report](../README.md) is historical; this revision supersedes its returning
sonar effect and the original background/hammerhead presentation.

## Changes and acceptance mapping

| Feedback | Implementation |
| --- | --- |
| Mountains above waves / underwater wave background | New horizon-free painted water column. A single fixed ocean surface remains at y=0; relief shaders clip illustration in world coordinates below it. Distant layers move down into the water. The title's baked-wave master is no longer used underwater. |
| Rigid angular rock | Quadratic rounding of deterministic authored contours, including irregular excavation plugs. Collision, rock paint and map use the same outline. Thin shapes reduce erosion to avoid self-intersections; world seams remain welded. Canonical technical cyan outlines are removed. |
| Unclear destructible rock | Every excavatable plug uses warm layered clay/ochre against cool protected basalt, plus rounded lumpy silhouettes and sediment seams. The existing nearby radio explanation remains; colour is not the sole identification cue. |
| Unnatural returning sonar | Deleted SonarReflection and restored the main branch's original SonarEmitter/SonarPulse implementation, with one outward sweep and existing timed reveals. No return rays, new acoustic emissions or history changes. |
| Static animals / weak hammerhead | Propulsion-driven posterior swimming, eel travelling wave, alternating turtle flippers and stable-head hammerhead stroke. Heading follows velocity; pause/Reduced Motion stop deformation. Fixed an old canonical-mode callback that kept the harmless observer suspended. |
| Hammerhead aggression/range | Hearing 900 units; proximity 380; pursuit speed 265 units/s, at most 9 s, distance leash 900 and target leash 850. A 2 s text warning precedes aggression. A head-first ram remains 6 hull with 3 s damage cooldown; one ram no longer immediately ends pursuit. Ascend above the optional territory (shallow route y=400 / 100 m), or leave its leash, to escape. No player-solid animal collider or required combat. |
| Linear buoy search | Same buoy position/IDs, now inside a protected rock shelter with alternating vertical baffles and a blind lower spur. Its damaged reflector requires a clear ray and a receiver distance of at most 650 units. A drive-by ping above the roof cannot discover it. Depth changes and a clear angle inside are required. Scanner also checks terrain visibility. |
| Radio speaker picture | Four original illustrated atlas portraits: Okafor, Crane, Mara and Wick's optical instrument. Existing source text remains explicit. Existing typewriter/scroll/archive/mute/focus behavior stays. Radio bounds reserve space for the full resource/ammunition deck, including 800×600 Large Text. |
| Prototype remnants | Canonical mode hides the old cave/overlook echoes, outer prototype wreck/ink and old prototype predator. The obsolete overlook is excluded from the canonical chart without deleting its saved ID. Normal technical checkpoint status and surface-coordinate debug text are removed from that chart; actual recovery errors remain visible. Valid discoveries and the approximate buoy report remain. |

The new shelter intentionally changes local collision geography, as requested.
Movement, camera physics, terrain destruction rules, mission APIs and authored
research/buoy anchors are preserved. This is a modest navigational challenge in the
existing region, not a claim that the entire shelf has become a maze.

## Saves and contracts

Schema remains **8**. No new independent file, flag, ledger or stable-ID rename. The engraved calibration
reference instrument remains a legitimate optional scan subject at its existing
location; it is not a route arrow or a new Lantern-1 artifact.
Existing discovered buoys remain known; new shelter eligibility applies to fresh
acquisition. Discovery and scan completion still commit through their existing
atomic checkpoint gates. Repeated pings/reload cannot repeat the chapter reward.

An old saved pose that now intersects the shelter uses SaveCoordinator's existing
validated-base fallback: reserves and permanent evidence are preserved, with route
telemetry safely reset. The focused test writes/loads a real old obstructed pose
and checks 74 hull / 62 battery / 81 oxygen survive relocation. Existing excavation
journals are replayed through the same contour-cutting path; no journal is erased.
Prototype mode restores its old presentation/receiver behavior and preserves all
old records. The canonical legacy predator is hidden/suspended; the separate
hammerhead remains the optional encounter.

AcousticBus filtering, stable event identity, ordering and bounded history are
unchanged. The buoy's target adapter rejects occluded eligible receipts before
scheduling its existing outbound wavefront. This is opt-in authored occlusion,
not diffraction, echo-return simulation or a dispatcher bypass. Passive listening
remains silent and non-discovering. Legacy targets retain their prior behavior.

Radio portraits are proposals for physical appearances that the Story Bible does
not specify. They do not reveal Crane's secret or later-zone content. The added
Okafor/Crane bloom reply is a temporary session notification of the existing choice;
it grants nothing and is not replayed on restore.

## Native Godot evidence

Captured from Godot 4.6.3 Compatibility on Xorg/Mesa **llvmpipe**. Inputs pass through
normal keyboard/controller events; no player teleport, mission completion command
or reward injection is used. `--disable-render-loop` renders screenshots on demand
and is **not** realtime performance evidence. Automated inputs are not a human
playtest. The audio driver and in-game audio were muted.

### Surface, rock and map comparison

| Before this revision | After this revision |
| --- | --- |
| [Baked surface/background](../screenshots/observe-surface-departure.png) | [One surface, submerged cliffs](screenshots/observe-surface-departure.png) |
| [Cool/angular excavation plug](../../bta-051/revision/route-1280/observe-rockfall-before.png) | [Warm rounded sediment plug](screenshots/observe-rockfall-before.png) |
| [Old map presentation](../../bta-051/revision/route-1280/observe-expanded-map.png) | [Canonical survey chart](screenshots/observe-expanded-map.png) |

The surface uses the same fixture capture point; swimming/particles and radio
playback phase differ. Rock/map before images are historical PR #35 evidence of
the same feature, with its older authored layout. Shelter geometry is intentionally
new, not a pixel-identical collision scene. Art quality/readability need human review.

### New interaction/animal captures

- [Okafor radio portrait, 1280×800](screenshots/observe-bloom-radio-portrait.png)
- [Crane portrait, 800×600 Large Text/High Contrast](800/collect-bloom-radio-portrait-small.png)
- [Shelter entrance and first unsuccessful sweep](screenshots/observe-shelter-entrance.png)
- [Buoy before the clear-angle ping](screenshots/observe-buoy-before-sonar.png)
- [Outbound wave in transit](screenshots/observe-sonar-travelling.png)
- [Buoy identified on wave arrival](screenshots/observe-sonar-buoy-arrival.png)
- [Mara recording portrait/archive](screenshots/observe-maras-message.png)
- [Hammerhead warning](screenshots/observe-hammerhead-warning-start.png)
- [Head ram](screenshots/observe-hammerhead-ram.png)
- [Shallow-water escape](screenshots/observe-hammerhead-safe-retreat.png)
- [Return/debrief](screenshots/observe-halcyon-return.png)

## Reproducible verification

The same pinned engine/GUT and CI entry points remain:

```sh
# From repository root; Godot 4.6.3 on PATH.
python3 tools/install_gut.py
python3 tools/install_export_templates.py
godot --version
godot --headless --editor --path . --import
python3 tools/validate_godot.py
python3 tools/run_tests.py
python3 tools/verify_expanded_expedition.py
python3 tools/verify_revision_two.py
python3 tools/verify_story_choice.py
python3 tools/verify_sunlit_shallows.py
python3 -m unittest discover -s tests/python -v
python3 tools/build_playtest.py
# Use the exact ZIP printed by the build:
python3 tools/smoke_playtest.py build/below-the-abyss-playtest-linux-<commit>.zip \
  --log build/playtest/standalone-smoke.log
```

Focused regression:

```sh
godot --headless --path . --script addons/gut/gut_cmdln.gd \
  -gexit -gdisable_colors -gconfig= \
  -gtest=res://tests/integration/test_surface_review.gd
```

For this managed host, set writable XDG locations before any Godot command:

```sh
export XDG_CACHE_HOME=/workspace/.cache
export XDG_DATA_HOME=/workspace/.local/share
export XDG_CONFIG_HOME=/workspace/.config
mkdir -p /tmp/bta052-review-native
DISPLAY=:98 LIBGL_ALWAYS_SOFTWARE=1 LP_NUM_THREADS=2 \
BTA_EVIDENCE_DIR=/tmp/bta052-review-native \
godot --path . --audio-driver Dummy --rendering-method gl_compatibility \
  --disable-render-loop --fixed-fps 60 \
  --script res://tests/fixtures/drive_sunlit_environment.gd --quit-after 90000 -- \
  --profile=bta052-review-manual-evidence --input=keyboard --outcome=observe \
  --survey-studies --fauna-demo
```

Use a different isolated profile for `--input=controller --outcome=collect --small
--high-contrast --no-excavation`. Small mode selects Large Text and all reduced
presentation settings; the keyboard route retains animation. A fresh fixture run
resets only its named automation profile. For a 1920×1080 surface/map spot check,
use `--wide --stop-after-map` with another profile.

## Verification results

| Check | Final local result |
| --- | --- |
| Engine/import/parser/startup | **PASS**, 4.6.3.stable.official.7d41c59c4, import, **280** parser checks and startup. [Log](logs/validation.txt) |
| Full GUT suite | **669/669 PASS**, **42,512 assertions**, 472.274 s; no failures, errors or skips. [Runner](logs/gut-runner.txt), [suite](logs/gut-suite.txt), [JUnit](logs/gut-suite.xml) |
| Focused review regressions | **9/9 PASS**, 132 assertions, including terrain triangulation/continuous hull clearance, roof/baffle occlusion, scanner visibility, prior discoveries, prototype cleanup, materials, portraits/800px layout, animation/comfort, hammerhead 30/60/120 and real checkpoint relocation. [Log](logs/focused-tests.txt) |
| Native 1280×800 keyboard | **PASS**, Observe, all optional scientific studies, excavation, warning/ram/escape, buoy and full debrief; 5 shots, 602.983 simulation seconds. [Log](logs/native-1280.txt) |
| Native 800×600 controller | **PASS**, Collect, Large Text/High Contrast/reduced settings/muted, full chapter with **zero shots**, 607.283 simulation seconds. [Log](logs/native-800.txt) |
| Native 1920×1080 spot check | **PASS**, title, briefing/departure, station technology and map navigation. This is **not** a third full chapter. [Log](logs/native-1920.txt) |
| Python tooling | **7/7 PASS**. [Log](logs/python.txt) |
| Legacy controller routes and bloom matrix | **PASS**: expanded expedition, revised radio/research expedition, eight bloom fresh/Continue keyboard/controller processes. [Log](logs/legacy-routes.txt) |
| Linux release export | **PASS**, clean source `268dd0d310a9f4286e17cf239fd63d6a7bc3210f`, dirty=false. [Output](logs/linux-export.txt), [manifest](logs/linux-manifest.json) |
| Extracted standalone smoke | **PASS**, exact exported build, default telemetry OFF. [Runner](logs/standalone-smoke.txt), [console](logs/standalone-console.txt) |
| Canonical chapter/recovery matrix | **12/12 input processes PASS**, both outcomes/devices, completed Continue and quit-at-buoy/Continue. Includes optional studies/pressure, missed ping, empty ammunition and low-power service recovery, hammerhead escape, plus no-excavation fresh/Continue. [Log](logs/chapter-matrix.txt) |

All required local workflow entry points completed successfully. Hosted GitHub
Actions status remains unverified here.
The exported ZIP is `build/below-the-abyss-playtest-linux-268dd0d310a9.zip` (ignored
local build output); the later evidence-only commit does not change runtime source.
No failed diagnostic log is presented as successful evidence.
The changed-file inventory is [changed-files.txt](changed-files.txt). The retained PNG
inventory with exact sizes is [screenshots.json](screenshots.json).

## Manual review route

1. Launch `godot --path .`. Use New Game only on a disposable profile, or Continue
   an existing expedition. Begin, read/skip the briefing and launch. Halcyon is
   above a single surface; no cliff silhouette should appear above the waves.
2. Move with WASD/arrows or the left stick. Reach the bloom and deliberately choose
   Observe or Collect with E/A. Open radio with R/left shoulder: Okafor or Crane
   should appear beside explicit speaker text. Confirm text typing (immediate with
   Reduced Motion), scroll, close and revisit the archive. No audio is required.
3. Inspect the first lower rockfall. It is warm ochre layered sediment; neighbouring
   protected basalt is cool/darker. Face it and fire Space/right shoulder to excavate,
   or use the unobstructed upper-water bypass. All optional plugs share the material.
4. Explore the turtle terrace, eel alcove and observer area. Check stable heads,
   moving tails/flippers and genuine swimming. Pause freezes simulation; Reduced
   Motion removes decorative deformation. Static screenshots alone cannot establish
   that animation feels natural.
5. Optionally enter the eastern hammerhead territory. Wait for the text warning,
   then evade upward before/after a modest ram. It follows farther/faster but is
   bounded; ascend above 110 m (e.g. y=400 / 100 m) to leave its patrol rectangle.
   Do not remain beside it expecting the first ram to end pursuit. The required
   route stays above the territory and never needs combat.
6. In the approximate buoy report area, try a ping above the ridge. It should not
   reveal a hidden buoy through rock. Find the west shelter opening, descend below
   the hanging baffle, then rise over the floor baffle. For reproducibility, the
   validated hull-centre course is (19750,600) → (19900,710) → (20300,710) →
   (20300,560) → (20600,560). These coordinates are test instructions, not world
   markers shown to the player. The lower eastern spur ends blind and can be reversed.
7. Ping from a clear angle inside. The outbound wave reaches the reflector after
   distance/600 seconds; there is no returning graphic. Approach the buoy at its
   unchanged (20800,620), intentionally Interact and finish scanning. Recover Mara's
   message, save/quit and Continue. It stays known; neither choice nor mission reward
   can be farmed. Returning through the entrance is always possible without blasting.
8. Open M/Back. The chart has no obsolete cave/overlook/wreck markers or technical
   surface-coordinate/checkpoint text. Real legacy saved records remain in data;
   charted terrain and the approximate search circle remain legitimate navigation.
9. Return along the shallow course, intentionally dock, service/rearm and debrief.
   Research, talents, story completion and permanent records should remain intact.
   Repeat at 800×600 Large Text/High Contrast and with reduced settings/audio muted.
   Confirm the radio does not cover hull/power/oxygen/ammunition and all controls
   remain reachable by keyboard and controller.

## Limits

- No human playtest, anatomical-animation approval or audible mix review was performed.
  Screenshots and tests do not establish professional visual acceptance.
- No target GPU or realtime 60 FPS claim: this host uses software rendering and
  on-demand captures. Only a single small new water texture/portrait atlas and
  existing local/material shaders are added; there is no new fullscreen postprocess.
- Rounded outlines increase polygon vertices and intentionally alter small edge
  clearances. Automated continuous hull-route/triangulation checks and actual input
  traversals cover the required course, not every possible arbitrary player maneuver.
- The search is authored and modest; no new region, procedural maze, secrets or
  mandatory encounter. Legacy already-known buoys are deliberately not re-hidden.
- Portrait appearances are provisional, replacing an atlas later is safe. Licensing
  remains the project's existing pending status; provenance makes no new rights claim.
- GitHub Actions status and PR-description editing are unavailable here because
  configured network access excludes api.github.com. PR #36 was identified through
  its Git head ref matching this branch; pushing updates its source normally. Local
  workflow-equivalent results are separate from hosted CI; no automatic merge.
