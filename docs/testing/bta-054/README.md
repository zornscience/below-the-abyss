# BTA-054 — Twilight Shelf environment, wildlife and erupting vents

Based on main `67a6a0e`, after merged PR #37. Branch:
`bta-054-twilight-environment`. This is the user's requested environment/NPC/hazard
follow-up to the chapter foundation. The full cable/log/glyph/sentinel story remains
a separate delivery step of the [approved design](../../design/twilight-shelf.md).
No new mission, economy, reward, Resonance choice, region or save store is added.

## What changes

- New original illustrated vent, historic whaler, mineral-garden, eel, squid and
  jellyfish assets. Cold, submerged cliff layers, textured rock-edge trim, varied
  sponge/tube-worm colonies, interrupted human cable and restrained marine snow
  distinguish the two exploration approaches. No waves or Halcyon above the deep level.
- Three stable-ID natural wildlife NPCs: west-gallery eel, lower-junction squid,
  east-gully jellyfish. They swim using the existing collision-safe AcousticCreature
  controller and bounded navigation. Existing active sonar/explosion dispatch can
  attract them to investigate. Passive listening never emits or attracts them.
  They cannot collide with/trap or ram the player. Existing torpedo BlastReceiver
  damage works; no kill reward or species/story scoring is introduced.
- Two periodic hydrothermal jets, one in the west's lower pocket and one beside
  the east lower shelf. A quiet window, **4-second warning**, **3-second eruption**
  and **5-second cooling** period let the player wait or use a safe bypass. Mineral-rich
  hot water, not pressure depth, damages the hull. No knockback or required combat.
- Warning and thermal-damage text use existing contextual/HUD feedback rather than
  another permanent instrument or world-space helper label. Visual jet/chimney cues and geological passive
  contacts supplement text; nothing requires audio. Existing damage sounds use the
  current mixer, volume/mute and voice limits.

The 12 BTA-053 passage contours, spawn, camera behavior, research/mission positions
and both upper/lower loops remain. Each new chimney has a small local solid outline,
placed below the route's clear hull corridor. The new wreck is a **background**
illustration; it is not Lantern-1, a decoded log, an undiscovered map marker or a new
collision barrier. Future investigation content can attach separately reviewed targets.

## Hazard API and tuning

`ThermalVentProfile` is a validated Godot Resource. The authored default is
`resources/hazards/twilight_vent.tres`:

| Setting | Default |
| --- | --- |
| quiet / warning / erupt / cooling | 8 / 4 / 3 / 5 simulation seconds |
| thermal hull rate | 4 hull/second, at most 12 per continuous eruption |
| local damage jet | Rect2(-140,-550,190,290), above the chimney |
| approach warning radius | 650 world units |
| conservative hull envelope | 28 units around the damage jet |

`ThermalVentState.advance(delta, exposed)` integrates only the overlapping active
seconds, including transitions inside a physics step. It accepts finite 0..1-second
steps; invalid values do nothing. Profiles must keep the entire damaging jet and
hull envelope within the approach-warning radius. It uses simulation time, never wall time/render
TIME or enter/exit callback counts. Thirty/sixty/120-step inputs have equal damage.
`ThermalVent.exposes` also ray-checks protected terrain to avoid heating through rock.
`ThermalVent.damage_applied` reports the actual bounded amount removed through
`SubmarineHullSystem.apply_damage(amount, "thermal/<stable-id>")`.

Time integration is exact for each exposure interval; physical entry/exit and terrain
occlusion are sampled once per physics tick (up to one tick of boundary error).
Rendering frame rate never drives damage.

The expanding hull envelope is conservative; rectangular start edges are inclusive,
end edges exclusive, consistent with Godot Rect2. The visible plume is deliberately
slightly wider than its damaging core. Quiet/cooling jets and mere proximity cause
no damage. Heat does not consume battery/oxygen or modify depth ratings.

World sites: west `(29500,3880)` and east `(36000,3490)`. The existing upper connector
at y=2900 bypasses both jets. The west pocket is optional. The lower eastern approach
can be traversed in a quiet window or bypassed above the plume. Chimneys do not
move, seal passages or trap the player.

`TwilightHabitat` owns ecology, three bounded ambient sources, NPC lifecycle and
presentation. No singleton. It advances only while the deep expedition is actively
simulating. Pausing freezes vents, NPC logic, sound scheduling and decorative phase. Each source uses the existing 256-event
cap (vent contacts cover roughly 51 minutes before a reset; biological contacts
roughly 72 minutes). Vent simulation/warnings continue after that logical audio cap.
Settings alter presentation only; they never remove thermal damage. Biological passive contacts represent the
eastern habitat ambience, not a tracking beacon on each visible animal.

## Saves and lifecycle

Schema **9** remains unchanged. All stable story/discovery/research/mission/upgrade
IDs and the expedition checkpoint/backup mechanism remain. Damage becomes ordinary
hull state in that checkpoint. Saving is rejected while the vessel occupies a
warning/active hot jet; a clear paused bypass is a legitimate checkpoint.

Continue, explicit route restart and regional refit transitions reset transient vent
cycles, ambient epochs and local wildlife using existing reset interfaces. Arrivals
get the full quiet/warning period rather than spawning into instant heat. Continue
preserves actual hull/ammunition/reserves and permanent records; it never heals.
Damaged/dead ambient animals are temporary, as in the existing prototype; there is
no farming reward. Existing acoustic history is neither cleared nor renumbered;
ambient source IDs remain stable and their epoch IDs avoid reset collisions.

If a historical deep pose intersects one of the new small chimney bodies, the
existing clear-spawn fallback relocates to the tether while preserving supplies and
records. No new file, silent progress reset or broader save architecture is introduced.

## Reproducible commands

Godot **4.6.3.stable.official.7d41c59c4**, GUT **9.6.1**, Compatibility renderer:

```sh
godot --path .
python3 tools/validate_godot.py
python3 tools/run_tests.py
python3 tools/verify_chapter_handoff.py
python3 tools/verify_twilight_habitat.py
python3 tools/verify_sunlit_shallows.py
python3 tools/verify_expanded_expedition.py
python3 tools/verify_revision_two.py
python3 tools/verify_story_choice.py
python3 -m unittest discover -s tests/python -v
python3 tools/build_playtest.py
python3 tools/smoke_playtest.py build/below-the-abyss-playtest-linux-<build-id>.zip \
  --log build/playtest/standalone-smoke.log
```

Focused new tests:

```sh
godot --headless --path . --script addons/gut/gut_cmdln.gd \
  -gexit -gdisable_colors -gconfig= \
  -gtest=res://tests/unit/test_thermal_vent.gd,res://tests/integration/test_twilight_habitat.gd
```

Native input-driven evidence on this managed Linux host:

```sh
export XDG_CACHE_HOME=/workspace/.cache
export XDG_DATA_HOME=/workspace/.local/share
export XDG_CONFIG_HOME=/workspace/.config
mkdir -p /tmp/bta054-native
DISPLAY=:98 LIBGL_ALWAYS_SOFTWARE=1 LP_NUM_THREADS=1 \
BTA_EVIDENCE_DIR=/tmp/bta054-native \
godot --path . --audio-driver Dummy --rendering-method gl_compatibility \
  --disable-render-loop --fixed-fps 60 \
  --script res://tests/fixtures/drive_twilight_habitat.gd --quit-after 120000 -- \
  --profile=bta054-review --input=keyboard --outcome=observe --no-excavation
```

Repeat with the same profile plus `--twilight-resume` for separate-process Continue,
station return/refit and resume. For controller / 800×600 use a separate profile and
`--input=controller --outcome=collect --small --high-contrast` in both processes.
Small mode enables Large Text and reduced presentation, with audio muted. Fixtures
reset only their named test profiles. They complete Chapter 1 and deployment through
normal inputs, steer to the vents, wait for real simulation phases, deliberately
enter one eruption, pause, escape, ping near a squid and save the resulting hull.
No actor teleport, mission completion or vent-clock injection occurs in that route.

## Manual route

1. Complete the buoy expedition or Continue a completed profile; open the Twilight
   exploration build. Confirm full first-deployment supplies at 350 m and no surface.
2. Head west, watch an eel, descend into the wreck gallery and inspect the historic
   wooden hull and gardens. It is not Mara's submarine or a new mission objective.
3. Continue into the optional west lower pocket. Observe a quiet jet, then the
   pressure-building warning. Remain beside the plume for an eruption: hull must
   stay unchanged. Move into the visible jet deliberately: thermal feedback and
   hull loss must occur, bounded by time spent in the three-second eruption.
4. Pause while exposed: warning/damage/NPC motion must freeze. Resume and retreat
   sideways/above the plume. Wait for cooling/quiet or use the upper connector.
5. Explore east via the lower junction or upper gully. Ping near the squid and watch
   it investigate the sound. Listen passively: contacts appear but listening causes
   no new event or NPC reaction. Observe the east jelly's bell/tentacle motion.
6. Save damaged hull on a clear, paused route. Quit/Continue: preserve hull, supplies
   and permanent records; the jet starts quietly. Return to the tether, service/refit,
   and resume without replaying chapter claims or choices.
7. Repeat using keyboard/controller, mute, Large Text/High Contrast and reduced
   motion/effects/particles at 800×600. Warning text and jet shape must still make
   the hazard understandable. Check the original shallow chapter and prototype.

## Results and screenshots

Local Godot 4.6.3 / GUT 9.6.1:

| Check | Result |
| --- | --- |
| Complete GUT suite | **704/704**, **42,941 assertions**, 679.116 s; [text](logs/gut.txt), [JUnit XML](logs/unit-tests.xml) |
| Focused terrain/UI/transfer regressions | **58/58**, 5,971 assertions; [log](logs/focused-geometry-ui.txt) |
| Final focused hazard/compact UI | **33/33**, 428 assertions; [log](logs/focused-final-ui.txt) |
| Import/parser/startup | Passed; **295 scripts**; [full validation](logs/validation.txt), [final changed-script checks](logs/final-changed-script-checks.txt) |
| New headless hazard/Continue/refit matrix | **4/4 processes**, both input devices/outcomes; [log](logs/headless-habitat.txt) |
| Existing expanded/revised expeditions, story choices and chapter handoff | Passed; [log](logs/legacy-and-handoff.txt) |
| Canonical chapter matrix, final native matrix and clean Linux export | Final results retained in [release results](release-results.md) |

Native captures are actual, unedited Godot Compatibility viewports under Xorg :98 /
Mesa llvmpipe. Keyboard/Observe uses 1280×800 normal visuals; controller/Collect uses
800×600, Large Text, High Contrast and reduced presentation. Both are muted.
The on-demand capture helper warms the renderer before readback, to settle glyph
atlas/control layout work as a normal continuous render loop would. No image editing,
mission injection, actor teleport or vent-clock injection occurs in the walkthrough.
Automated inputs are not human playtests or physical gamepad testing.

| Scene | 1280×800 keyboard | 800×600 controller / comfort |
| --- | --- | --- |
| Deployment explanation | [briefing](screenshots/1280/deep-commissioning.png) | [briefing](screenshots/800/deep-commissioning.png) |
| Deep starting pocket | [350 m](screenshots/1280/deep-start-350m.png) | [350 m](screenshots/800/deep-start-350m.png) |
| Eel gallery | [eel](screenshots/1280/deep-eel-gallery.png) | [eel](screenshots/800/deep-eel-gallery.png) |
| Historic wooden wreck | [whaler](screenshots/1280/historic-whaler.png) | [whaler](screenshots/800/historic-whaler.png) |
| Safe-side warning | [warning](screenshots/1280/vent-warning.png) | [warning](screenshots/800/vent-warning.png) |
| Eruption / safe bypass | [eruption](screenshots/1280/vent-eruption-safe-bypass.png) | [eruption](screenshots/800/vent-eruption-safe-bypass.png) |
| Inside warning jet, before damage | [clear jet](screenshots/1280/vent-clear-the-jet.png) | [clear jet](screenshots/800/vent-clear-the-jet.png) |
| Actual thermal hull loss | [damage](screenshots/1280/thermal-hull-damage.png) | [damage](screenshots/800/thermal-hull-damage.png) |
| Natural squid patrol | [squid](screenshots/1280/squid-patrol.png) | [squid](screenshots/800/squid-patrol.png) |
| Squid investigates actual ping | [reaction](screenshots/1280/squid-investigates-sonar.png) | [reaction](screenshots/800/squid-investigates-sonar.png) |
| Lower mineral garden | [garden](screenshots/1280/mineral-garden-and-east-vent.png) | [garden](screenshots/800/mineral-garden-and-east-vent.png) |
| Jelly drift | [jelly](screenshots/1280/jelly-drift.png) | [jelly](screenshots/800/jelly-drift.png) |
| Continue retains depleted reserves | [Continue](screenshots/1280/continue-supplies-preserved.png) | [Continue](screenshots/800/continue-supplies-preserved.png) |
| Halcyon refit | [station](screenshots/1280/halcyon-refit.png) | [station](screenshots/800/halcyon-refit.png) |
| Resume deep pocket | [resume](screenshots/1280/resume-from-tether.png) | [resume](screenshots/800/resume-from-tether.png) |

Compare the same authored deployment pose before/after at 1280×800:
[BTA-053 before](../bta-053/screenshots/1280/deep-start-350m.png) →
[BTA-054 after](screenshots/1280/deep-start-350m.png). Other captures are exploration
moments, not claims of pixel-identical camera/animation timing. Human art/readability
approval remains pending. Screenshots/conditions: [inventory](screenshots.json).

The objective panel keeps its natural wrapped height instead of repeatedly forcing
zero height. The thermal cue is compact; hazard instructions appear in the existing
context panel. No duplicate world-space helper labels overlap the instruments.

Render snapshots are observations, **not frame-time/GPU benchmarks**. Before renderer
warm-up, the captured regional samples were 44–56 draw calls at 1280×800 and 36–53 at
800×600 comfort, with up to about 150.1 / 147.7 MiB scene-wide texture allocation.
Final samples are retained in [1280 JSON](render-samples-1280.json) and
[800 JSON](render-samples-800.json); these include the whole loaded scene, not marginal
new-asset memory. There is no measured target-GPU/baseline frame-time comparison or
60 FPS claim. Warm-up/UI frames can have more draws; see complete native logs.

## Scope and remaining review

- Full Twilight investigation, Mara field logs, glyph, sentinel choice/rewards and
  30–45-minute story pacing remain future work. Ambient wildlife is not the sentinel.
- New masters are generated illustrated assets, not a human-authored final layered
  art pack. Native visual quality, alpha edges, texture repetition and environmental
  readability still need user/artist review.
- The hazard is a configurable hydrothermal jet prototype, not geophysical fluid,
  lava, currents, debris or a new survival resource. Both vents share one predictable
  default profile. Physical hull intersection uses a conservative rectangular envelope.
- No target-GPU performance, audible mix, unfamiliar-human comprehension or full
  campaign completion claim is made. Hosted CI/PR status is separate from local checks.
