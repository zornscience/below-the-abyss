# BTA-053 — Chapter handoff and deep exploration foundation

Based on main `2a81d25`, after merged PR #36. Review branch:
`bta-053-chapter-handoff`. This implements the first delivery step of the
[user-agreed Twilight Shelf design](../../design/twilight-shelf.md), not the complete
30–45-minute story chapter. The wreck investigation, Mara field logs, glyph and
sentinel choices remain future work and are explicitly disclosed before deployment.
No new campaign rewards, economy, combat or research branches are added.

## Implemented player flow

- Once the buoy recording and bloom decision are secured, Interact at the buoy to
  choose **Finish chapter** or **Keep exploring**. The same finish action is also
  available in the expedition log. Manual return/docking still works.
- Finish performs an explicit, validated off-screen voyage and acknowledges the
  existing mission once, then presents the first expedition debrief. It does not
  manufacture an area/base-entered signal, rescan evidence or replay a decision.
- The completed-chapter page, station and title offer **Twilight Shelf / exploration
  preview**. Commissioning explains the free 1,000 m pressure fit. Entering begins
  fully supplied at **350 m**: full hull/battery/oxygen and ten torpedoes. Halcyon,
  the ocean surface and surface-wave art are not in the playable deep view.
- The central deployment pocket has large **western and eastern approaches**.
  Both reach substantial loops with depth changes, connecting passages and blind
  pockets. No excavation, enemy kill or new purchase is required. Geometry is a
  protected graybox with the shared illustrated basalt material, not final new art.
- Interact within **180 units** of the ascent tether to choose **Return to Halcyon**
  or **Stay here**. Passing it never refills or teleports. Return is unavailable from
  distant passages. A deliberate return uses the existing free station-service
  limits; refitting uses the existing finite research budget/free reassignment.
- **Resume Twilight Shelf** returns to the deployment pocket. Records, allocations,
  claims, story decisions and excavation history are retained. It does not reapply
  commissioning supplies: those come from the legitimate preceding station service.
- Ordinary **Continue** preserves saved pose, hull, battery, oxygen, ammunition and
  sonar cooldown. It never treats a load as fresh deployment or service.

No camera-physics, submarine-motion, torpedo, acoustic-dispatch/history or Resonance
rules are replaced. The existing headlight ray/material path also lights new walls.
Menus use the shared semantic typography, reading/focus navigation and pausing rules.

## Save contract and migration

Expedition schema **9** adds one strictly validated `journey` record inside the
existing atomic checkpoint, with `phase` and `commissioned`. Phases are `sunlit`,
`twilight`, `refit` and `prototype`; the last preserves explicit legacy presentation
and Continue. The active world identity is `continental_shelf` or `twilight_shelf`.
Unknown phases, non-boolean commissioning, mismatched identities and an unearned
commission are rejected. Versions **1–8** migrate to uncommissioned Sunlit state;
old bytes are not rewritten just by validation. Downgraded migration fixtures remove
new fields so they genuinely represent their declared historical versions.

All existing stable discovery/research/mission/upgrade IDs remain. The domain
catalogues remain shared campaign records; this foundation introduces no fake
Twilight discoveries or second ledger/file. Chapter 1 completion still belongs to
MissionService, via a pure scripted-return proposal that the coordinator commits
with the destination/service snapshot before emitting live completion/claim signals.
A failed write leaves live records, pose and supplies untouched. Restore is silent.

Commissioning is monotonic through writes/recovery. It reconstructs a validated
1,000 m baseline plus the previously paid hull margin (0/100/150/200 m), rather than
multiplying or repeatedly adding capabilities. The station comparison text uses
those actual values. Sonar costs/cooldowns and research prices are unchanged.

Initial deployment is intentionally fully supplied. Later off-screen servicing
quotes the existing StationProfile, including configured transfer limits and offline
eligibility. Restore uses existing hull/resource/ammunition APIs. Keep Exploring,
ordinary loading, map opening and tether proximity perform no service.

Continue selects the saved region presentation before validating the vessel pose.
The existing clear-spawn fallback remains; if no safe fallback exists, the previous
presentation is restored. Region geometry stays scene-owned under the existing
composition; the acoustic bus/domain services are retained, not duplicated.
New Game archives the campaign as before and clears commissioning in its new
checkpoint. Restart Test Route retains permanent records/commissioning and uses
its current region's spawn, distinct from station service.

## Existing visual assets

The layout reuses `assets/art/sunlit/water_column.png` (horizon-free water),
`service_cradle.png` (the public ascent platform), and the existing shared basalt
material supplied by `SunlitRockDressing`. Source files/import settings are unchanged.
Their original provenance remains in the [art documentation](../../art_direction.md)
and [Sunlit asset inventory](../../../assets/art/sunlit/README.md). New geometry is authored
GDScript graybox data, not a new illustrated-art commission or a claim of final
Twilight Shelf art quality.

## Graybox coordinates and navigation

Authored world surface datum remains y=0, at **0.25 m/world unit**. Deep deployment:
`(33000,1400)` = 350 m. Public camera/region bounds are
`Rect2i(27000,800,12000,3200)`; physical limits keep the sub inside submerged terrain.
The shared collision/paint contours are deterministically rounded and triangulated.
The top-level node's historic name remains unchanged for compatibility.

Continuous whole-hull routes are authored as `TwilightShelfLayout.WEST_LOOP` and
`EAST_LOOP`. Both close back at the central tether. The map shows public extent,
player position and the public ascent anchor; it does not draw unearned POIs or
claim to have surveyed the new terrain. Internal x coordinates are implementation
coordinates, not scientific-distance claims or text placed in the level.

## Commands

Pinned **Godot 4.6.3.stable.official.7d41c59c4**, GUT **9.6.1**, Compatibility.
From the repository root:

```sh
godot --version
godot --headless --editor --path . --import
python3 tools/validate_godot.py
python3 tools/run_tests.py
python3 tools/verify_expanded_expedition.py
python3 tools/verify_revision_two.py
python3 tools/verify_story_choice.py
python3 tools/verify_sunlit_shallows.py
python3 tools/verify_chapter_handoff.py
python3 -m unittest discover -s tests/python -v
python3 tools/build_playtest.py
python3 tools/smoke_playtest.py build/below-the-abyss-playtest-linux-<build-id>.zip \
  --log build/playtest/standalone-smoke.log
```

Launch the normal interactive game with `godot --path .`. Test using a separate
profile or archive the existing campaign with New Game before replaying Chapter 1.

Focused foundation tests:

```sh
godot --headless --path . --script addons/gut/gut_cmdln.gd \
  -gexit -gdisable_colors -gconfig= \
  -gtest=res://tests/integration/test_chapter_journey.gd
```

On this managed host, writable XDG locations are required:

```sh
export XDG_CACHE_HOME=/workspace/.cache
export XDG_DATA_HOME=/workspace/.local/share
export XDG_CONFIG_HOME=/workspace/.config
mkdir -p /tmp/bta053-native
DISPLAY=:98 LIBGL_ALWAYS_SOFTWARE=1 LP_NUM_THREADS=2 \
BTA_EVIDENCE_DIR=/tmp/bta053-native \
godot --path . --audio-driver Dummy --rendering-method gl_compatibility \
  --disable-render-loop --fixed-fps 60 \
  --script res://tests/fixtures/drive_chapter_handoff.gd --quit-after 90000 -- \
  --profile=bta053-review --input=keyboard --outcome=observe --no-excavation
```

Repeat with the same profile and `--twilight-resume` to prove a separate-process
Continue and actual-input refit/resume. For 800×600 controller evidence use a separate
profile with `--input=controller --outcome=collect --small --high-contrast` in both
processes. Small mode enables Large Text and reduced motion/effects/particles.
Fixtures reset only their named automation profiles on a fresh run, never normal
player data. Native captures render on demand; they are not performance benchmarks.

## Manual playtest

1. Begin or Continue the first expedition. Resolve either bloom outcome and recover
   Mara's buoy recording normally. After scanning, use Interact again to open the
   finish choice. Choose Keep exploring; verify piloting resumes without completion.
2. Open the choice again, or use the expedition log's Finish chapter action. Finish
   and verify the brief debrief, preserved choice/record and a single acknowledgement.
   Manual return still provides the original completion route on another profile.
3. Select the Twilight Shelf preview and confirm commissioning. Verify 350 m,
   full supplies/ten rounds and rated depth of at least 1,000 m. Look around: the
   platform, sky and ocean surface must be absent.
4. Travel left into the western passage, descend around the central formation and
   return by the eastern chimney. Also test an east-first route. Explore blind
   pockets and reverse without firing. No portion requires combat or an upgrade.
5. Ping, travel and deliberately expend supplies. Save while safely paused away
   from the tether, quit and Continue. Verify the same pose/supplies/ammunition and
   pressure rating, with no new completion event or supply refill.
6. Return to the central tether. Crossing its radius does nothing automatically.
   Interact, cancel Stay here, then explicitly Return to Halcyon. Verify paused
   station operations, service, research/refund controls and accurate rated-depth
   comparisons. Resume and verify the safe deep deployment pose and retained records.
7. Repeat with keyboard and controller, audio muted, 800×600/Large Text/High Contrast
   and reduced presentation settings. Confirm all bounded dialogs scroll/focus and
   Back closes the correct page. Test explicit legacy prototype access separately.

## Verification results

Automated local results (Godot 4.6.3, GUT 9.6.1, 2026-10-29):

| Check | Result / retained evidence |
| --- | --- |
| Entire GUT suite | **686/686**, 42,721 assertions, 559.381 s; [log](logs/gut.txt) |
| Existing canonical chapter matrix | **12/12 processes**, both outcomes/devices, completed and mid-buoy Continue, optional studies/recovery; [log](logs/canonical-routes.txt) |
| Existing expanded/revised expeditions and story-choice matrix | Passed, including 8 story-choice processes; [log](logs/legacy-routes.txt) |
| Python analysis tests | **7/7**; [log](logs/python.txt) |
| Native 1280×800 keyboard/Observe | Fresh chapter → deep west loop → saved depleted expedition; separate-process Continue → refit → resume, no replayed choices/claims; [fresh](logs/native-1280-fresh.txt), [Continue](logs/native-1280-continue.txt) |
| Native 800×600 controller/Collect | Same flow through the east loop, Large Text/High Contrast/reduced presentation/muted audio; [fresh](logs/native-800-fresh.txt), [Continue](logs/native-800-continue.txt) |

Final import/parser/startup, exact headless handoff matrix and clean Linux package
results are recorded in `release-results.md` after they complete. Hosted Actions
status is separate from these local workflow-equivalent checks.

Native evidence is actual Compatibility-renderer Godot output under Xorg :98,
Mesa llvmpipe (software rendering). Screenshots are unedited and captured only on
demand in the real input-driven fixture. Both native routes use muted audio; the
1280 route retains normal visual effects, and 800 uses comfort settings. The routes
simulate key/controller events through the normal input/UI paths, not direct
completion or teleport calls. Test-profile creation is isolated from player saves.

| Moment | 1280×800 keyboard | 800×600 controller / Large Text / High Contrast |
| --- | --- | --- |
| Buoy finish/cancel | [choice](screenshots/1280/finish-chapter-choice.png) | [choice](screenshots/800/finish-chapter-choice.png) |
| Existing chapter debrief | [debrief](screenshots/1280/first-chapter-debrief.png) | [debrief](screenshots/800/first-chapter-debrief.png) |
| Honest exploration-preview briefing | [commissioning](screenshots/1280/deep-commissioning.png) | [commissioning](screenshots/800/deep-commissioning.png) |
| Full deployment at 350 m | [start](screenshots/1280/deep-start-350m.png) | [start](screenshots/800/deep-start-350m.png) |
| Opposite approaches | [west](screenshots/1280/west-passage.png) | [east](screenshots/800/east-passage.png) |
| Connecting lower passage | [loop](screenshots/1280/lower-loop.png) | [loop](screenshots/800/lower-loop.png) |
| Map without shallow secrets | [map](screenshots/1280/deep-exploration-map.png) | [map](screenshots/800/deep-exploration-map.png) |
| Continue preserves depleted reserves | [Continue](screenshots/1280/continue-supplies-preserved.png) | [Continue](screenshots/800/continue-supplies-preserved.png) |
| Deliberate ascent choice | [tether](screenshots/1280/return-tether-choice.png) | [tether](screenshots/800/return-tether-choice.png) |
| Station service | [refit](screenshots/1280/halcyon-refit.png) | [refit](screenshots/800/halcyon-refit.png) |
| Existing research page | [research](screenshots/1280/research-refit.png) | [research](screenshots/800/research-refit.png) |
| Resume at deep anchor | [resume](screenshots/1280/resume-from-tether.png) | [resume](screenshots/800/resume-from-tether.png) |

Visual inspection confirmed the vessel and tether are in the first playable deep
view, no surface/platform is visible, dialog text wraps within its panel, focus is
visible, and the research page scrolls at 800×600. Large Text panels intentionally
retain the existing generous bounded reading area. Map anchor/player labels can be
close together while docked at the anchor; the shape/text legend distinguishes them.
No new artwork quality, physical-controller, human-comprehension or frame-rate
performance approval is inferred from this automation.

Transitions now keep simulation/input covered for two scene-owned physics ticks
while the existing camera settles at its destination. They do not change camera
physics. The existing benthic decoration rebuild uses a node-owned two-tick counter
instead of a global coroutine, so scene removal cannot resume work on a freed owner.
Tests exercise both fixes and preserve the existing sampling behavior.

## Limitations

- This is the **handoff/region foundation**, not the complete planned Chapter 2.
  It contains no new sentinel, glyph, Mara field log, story choice or bounty, and
  does not claim 30–45 minutes of finished narrative content.
- The region is a reusable textured graybox, not final commissioned environmental
  artwork. The tether reuses the original service-cradle illustration. No external
  dependencies or new art/licensing claims are introduced.
- Automation is not a human playtest. No first-time comprehension, art approval,
  target-hardware performance, physical-controller or audible-mix approval is claimed.
- The shared campaign catalogue is retained intentionally. A later story milestone
  must add actual Twilight records through validated catalogue/schema extensions.
- Hosted GitHub API access is currently unavailable; local workflow-equivalent
  results, Git push and any PR creation/status limitations are reported separately.
  Do not merge automatically.
