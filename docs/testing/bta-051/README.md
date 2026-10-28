# BTA-051 — expanded Sunlit Shallows

Based on merged PR #34, main `ce64e08`. Branch `bta-051-expanded-sunlit-shallows`.
Only the canonical first region is expanded; no Twilight Shelf, new alignment choice,
late-game reveal or wildlife combat requirement. The exact Mara message, both
light-bloom outcomes, existing station/talent systems and the legacy expedition remain.

[Architecture, save migration and failure semantics](../../decisions/bta-051-expanded-shallows.md)
· [Performance](performance.md) · [Art inventory/provenance](../../../assets/art/sunlit/README.md)
· [Exact results](verification.txt) · [Changed files](changed-files.txt).

## Playtest route

1. Begin **The Sunlit Shallows**, read the short Halcyon briefing and launch. Docking
   intentionally remains E / controller A; repairs/refill/rearm happen on docking,
   never from merely flying through base. Technology is available before departure.
2. Move east past Halcyon's pylons. Read Okafor's nonblocking map call. Open M / Back:
   ▲ is your orientation, station is always charted, hatched sectors are unsurveyed,
   the dashed circle is a reported area, not a precise buoy coordinate. Tab / right
   shoulder reaches Zoom, Pan and Follow; Enter / A activates. Close with M / Back
   or Escape / B. Bindings are remappable, and messages use the current bindings.
3. At the geometric bloom, ping F / X, approach and Interact E / A. Either observe
   the bloom unharmed or collect Crane's specimen. Both paths remain completable;
   the exclusive choice, visual consequence and Resonance persist without a number.
4. Continue east through Twin Spires. The fractured barrier around x=4550 is real
   terrain. Face east and fire Space / right trigger. One well-placed excavation
   torpedo makes a full-hull opening. A glancing or small cut is insufficient.
   If ammunition is empty, retrace the shallow route to Halcyon, dock to rearm and
   return. No creature must be shot; protected boundaries and science stay intact.
5. The shallow corridor alternates upper/lower passages. Ping near the silver shoal
   (6000,600); stop within the scanner's radius and intentionally scan with Interact.
   Review the pictured, nonblocking record and XP, then find the mineral terrace
   (7650,450). Optional amber darters (9100,620), the lower arch opening (10600,710),
   blue grazers (15500,650), pillow basalt (16800,710) and sediment fan (17800,350)
   add field studies. Map → Research retains the full descriptions.
6. Optional: descend the wide shaft near x=14000. Its margin study at y=1090 can
   be scanned safely from y≈1020. Read the fitted depth rating, CAUTION/DANGER text
   and Wick warning. The unchanged mapping is 0.25 m/unit from surface y=0; the
   standard hull is rated 300 m (y=1200). Below rating, pressure grace precedes
   damage; turn up to stop it. The closed shaft ends at 625 m. This is a local
   optional hazard, not access to another region. Fitted upgrades remain authoritative.
7. Consult the reported search circle. A ping too far away reveals nothing. Move
   within range and ping again; wait for the wavefront. The actual buoy at
   (20800,620) has no sprite, exact map marker, scan prompt or collision before its
   first valid echo. Afterward it remains identified. Approach and scan to recover
   **“It isn't empty down there. Tell Elias the Choir is a voice.”**
8. Read Mara's message through the radio or expedition log. Return west through
   the same cleared shallow course. Deliberately dock at Halcyon, submit the first
   expedition debrief, and inspect technology: unique scientific XP adds at most
   two points. Reassignment stays free. Quit and Continue to check the record,
   passage, choices, ranks and claims; none may grant another award.
9. For recovery review, expend power on pings at base then attempt one without
   sufficient energy: no pulse/cooldown/charge should occur. Dock to recover.
   Damage the vessel in the optional shaft then return for repair. If depleted,
   Pause → Continue restores the last safe checkpoint, or Restart Test Route returns
   to departure; permanent science/story/terrain survive. There is no new death
   screen, penalty or automatic respawn in this prototype.

The long route stays ≤200 m except the explicitly optional shaft. The game does
not expose these authored coordinates to players as compulsory markers; they are
provided here for reproducible review. No fast travel, teleport or staged completion
is used in the input-driven route fixture. The full course is a **15–20 minute human
first-time target**; automated steering time is reported separately and cannot
establish comprehension, pacing, quality or physical controller usability.

## Acceptance mapping

| Requirement | Implementation / evidence |
| --- | --- |
| Larger interconnected shallow route | Authored alternating ridges, arch and optional vent; continuous full-hull sweeps and normal-input return |
| Map/report/tutorial | Existing map action; known/unknown/report layers; focusable zoom/pan/follow; contextual radio and mission projection |
| Physical rockfall | Existing torpedo/excavation, actual capsule clearance, persistent cut + one POI; small/off-center cut tests and empty-ammo return |
| Pressure and retreat | Existing world-depth API, actual fitted rating/grace/damage, upward retreat and safe-checkpoint recovery |
| Hidden buoy | Existing bus and sonar wavefront; out-of-range/early arrival/negative passive/map/collision tests; unchanged recording |
| Lightweight wildlife | Six 5–12 fish schools, one batch/receiver each, three authored species records, fixed-step model and bounded memory |
| Scientific feedback | Actual subject images, text/classification/XP, no focus or piloting capture, bounded queue, priority warnings and research reread |
| Atomic capped progression | Schema 7 science ID sets in existing checkpoint; data-driven 20/30/100/cap2, no retroactive XP, failure/Continue/restart tests |
| Performance | Post-PR34 baseline captured before changes, comparable shared views, expanded live samples, controlled scanner workload |
| Preservation | Entire prior GUT suite and old input drivers retained; schema1–6, ranks, records, terrain, Resonance and old prototype remain |

## Reproducible verification

Use the pinned Godot **4.6.3.stable.official.7d41c59c4**, existing GUT9.6.1 and matching
export templates. No new external package/dependency is introduced.

```sh
python3 tools/install_gut.py
python3 tools/validate_godot.py
python3 tools/run_tests.py
python3 tools/verify_expanded_expedition.py
python3 tools/verify_revision_two.py
python3 tools/verify_story_choice.py
python3 tools/verify_sunlit_shallows.py
python3 -m unittest discover -s tests/python -v
python3 tools/install_export_templates.py
python3 tools/build_playtest.py
# Pass the single generated build/below-the-abyss-playtest-linux-*.zip path:
python3 tools/smoke_playtest.py build/below-the-abyss-playtest-linux-VERSION.zip
```

The canonical wrapper retains all 12 fresh/Continue/mid-expedition launches and
both devices/outcomes. Its expanded observer-controller run also uses normal input
to exhaust ammunition, return/rearm, exhaust sonar energy/refill, scan all eight new
studies, enter damaging pressure, miss the buoy with one ping, then recover and
return. Guards are increased for the larger course; tests/assertions are retained.
The CI job has 40 minutes for the unchanged full suite plus longer input routes;
GUT's bounded budget is 900 seconds; the first 600-second attempt timed out near
the final integration scripts and is retained rather than discarded. Hosted Actions results must be checked
on the PR; local checks alone are not hosted CI success.

Native evidence (a working desktop DISPLAY is required):

```sh
python3 tools/capture_sunlit_survey.py --output docs/testing/bta-051/after \
  --baseline docs/testing/bta-051/before
python3 tools/report_sunlit_survey.py
mkdir -p /tmp/bta051-input-evidence
BTA_EVIDENCE_DIR=/tmp/bta051-input-evidence godot --path . \
  --audio-driver Dummy --rendering-method gl_compatibility --disable-render-loop \
  --fixed-fps 60 --script res://tests/fixtures/drive_sunlit_environment.gd \
  --quit-after 90000 -- --profile=bta051-native-review --input=controller \
  --outcome=observe --survey-studies --vent-damage-demo --missed-ping-demo \
  --empty-ammo-demo --low-energy-demo
```

Use unique profiles for independent runs. Add `--small --high-contrast --comfort`
for 800×600 Large Text/High Contrast/reduced effects, or `--wide` for 1920×1080;
default is 1280×800. Native route captures use the actual viewport, no compositing.
Sparse redraw makes this feasible on a software-only cloud host and is **not** a
realtime performance test. Baseline/staged presentation probes set poses through
the existing APIs; their captures must not be passed off as a flown expedition.
Actual input runs log active vessel simulation seconds (excluding paused reading/menus)
and host wall seconds separately.

Controlled scanner comparison (pause state, same eight legacy subjects, seven
1000-call batches; an API workload, not whole-game FPS):

```sh
godot --headless --path . --script res://tests/fixtures/profile_scanner.gd -- --baseline-targets
```

## Native visual evidence

The `before/` directory is an isolated archive of ce64e08 captured before edits.
The `after/` directory holds all three native resolutions, normal/reduced modes,
six comparable shared views plus expanded school/arch/vent/buoy probes. Shared
camera limits are fixture-only; gameplay uses the larger authored limits. Static
terrain intentionally differs; manifests retain hashes but do not assert equal
physics. The old buoy location is not a meaningful after comparison.
Input-driven route directories include the map, rockfall before/after, pictured
records, pressure states, travelling sonar, first buoy echo, XP and final debrief.
See verification.txt for actual completed commands, file counts and limitations.

## Remaining review

No human participant, physical gamepad session, target Fedora/NVIDIA measurement,
15–20 minute pacing acceptance or artistic approval is fabricated. Software-rendered
frames cannot certify 60 FPS. Schools use conservative clear rectangular habitats
and suspend while distant; they are not a new creature/species production pipeline.
The vent and scientific species are illustrative prototype field subjects. Human
artists should review atlas gutters/texture repetition and editable source layers.
The new fish atlas is AI-generated; thumbnails are offline Godot subject renders;
project licensing remains pending. Existing source art masters remain unchanged.

## Review gallery

Native viewport readbacks only. The input matrix redraws each milestone at the
listed sizes/comfort modes, then restores its original 800×600 Large Text/High
Contrast piloting settings; it does not teleport the player or advance objectives.
Resizing adds a small number of ordinary simulation frames, so individual wavefront
frames are consecutive instants, not a pixel-identical timestamp. This is screenshot
and input evidence, not a realtime framerate capture.

| Milestone | 800×600 | 1280×800 | 1920×1080 |
| --- | --- | --- | --- |
| Reported map area | [PNG](route-matrix/800-normal-expanded-map.png) | [PNG](route-matrix/1280-normal-expanded-map.png) | [PNG](route-matrix/1920-normal-expanded-map.png) |
| Rockfall before | [PNG](route-matrix/800-normal-rockfall-before.png) | [PNG](route-matrix/1280-normal-rockfall-before.png) | [PNG](route-matrix/1920-normal-rockfall-before.png) |
| Rockfall after | [PNG](route-matrix/800-normal-rockfall-after.png) | [PNG](route-matrix/1280-normal-rockfall-after.png) | [PNG](route-matrix/1920-normal-rockfall-after.png) |
| School / record | [PNG](route-matrix/800-normal-scan-sunlit-silver-shoal.png) | [PNG](route-matrix/1280-normal-scan-sunlit-silver-shoal.png) | [PNG](route-matrix/1920-normal-scan-sunlit-silver-shoal.png) |
| Vent margin | [PNG](route-matrix/800-normal-vent-safe.png) | [PNG](route-matrix/1280-normal-vent-safe.png) | [PNG](route-matrix/1920-normal-vent-safe.png) |
| Pressure warning | [PNG](route-matrix/800-normal-vent-danger.png) | [PNG](route-matrix/1280-normal-vent-danger.png) | [PNG](route-matrix/1920-normal-vent-danger.png) |
| Travelling sonar | [PNG](route-matrix/800-normal-sonar-travelling.png) | [PNG](route-matrix/1280-normal-sonar-travelling.png) | [PNG](route-matrix/1920-normal-sonar-travelling.png) |
| Buoy echo | [PNG](route-matrix/800-normal-sonar-buoy-arrival.png) | [PNG](route-matrix/1280-normal-sonar-buoy-arrival.png) | [PNG](route-matrix/1920-normal-sonar-buoy-arrival.png) |
| Scientific XP | [PNG](route-matrix/800-normal-research-xp.png) | [PNG](route-matrix/1280-normal-research-xp.png) | [PNG](route-matrix/1920-normal-research-xp.png) |
| Debrief | [PNG](route-matrix/800-normal-debrief.png) | [PNG](route-matrix/1280-normal-debrief.png) | [PNG](route-matrix/1920-normal-debrief.png) |

Every row also has a `-reduced-` counterpart in the same directory. At 800 that
combines Large Text, High Contrast, Reduced Motion, Reduced Effects and Reduced
Particles; written information remains present while motion/shafts/particles are
suppressed. Full normal-mode and reduced-mode staged world views and live monitors
are under after/. No human acceptance is inferred from these image files.

| Shared position | Post-PR #34 baseline | After expansion |
| --- | --- | --- |
| Halcyon | [1280×800](before/1280-normal-departure.png) | [1280×800](after/1280-normal-departure.png) |
| Bloom | [1280×800](before/1280-normal-plankton.png) | [1280×800](after/1280-normal-plankton.png) |
| Twin Spires/eastern approach | [1280×800](before/1280-normal-twin-spires.png) | [1280×800](after/1280-normal-twin-spires.png) |

The first extended observer capture (route-1280, 803.75 active seconds) preceded
final cosmetic backdrop/legacy-visibility cleanup. Its input assertions and raw log
are retained. The matrix is the final presentation evidence; the observer and
collect outcomes are also verified again by the canonical regression wrapper.

The final map label matrix was recaptured by the same normal-input opening route
with `--stop-after-map` after the annotation cleanup. Its separate raw log is
[retained](logs/native-final-map.txt). The canonical map filters archived outer
prototype fixture markers (including its unrelated wreck) without deleting their
discovery records; switching to the prototype restores their map presentation.
The very wide overview needs zoom/pan for local geometry at small window sizes.

The full input matrix also spends a bonus point beyond the commissioning budget
through actual station buttons, reaching pressure-hull rank two.
[800×600 Large Text assigned talents](route-matrix/collect-research-xp-assigned-small.png).

Reproduce the matrix by using
`--script res://tests/fixtures/drive_sunlit_survey_matrix.gd` in the native command,
with `--outcome=collect --small --high-contrast --comfort --survey-studies
--vent-damage-demo --missed-ping-demo` (supply-edge flags may be omitted). Add
`--stop-after-map` for the short final annotation review. The matrix stores
66 requested milestone PNGs plus the original route's additional captures;
[capture inventory](route-matrix/capture.json) validates their exact dimensions.
