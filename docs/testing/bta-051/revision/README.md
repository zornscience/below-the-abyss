# PR #35 review revision — passages, marine life and New Game

This revises **BTA-051 / PR #35**, on `bta-051-expanded-sunlit-shallows`.
It does not create another region or rewrite the first chapter. Historical
[initial BTA-051 evidence](../README.md) describes the earlier one-shot gate;
this document supersedes that behavior. The canonical buoy, both bloom decisions,
research IDs, technology and deliberate station services remain.

## What changed

- The route now threads below a floating basalt island and through a lower arch,
  then climbs between interlocking rock baffles. A high western alcove ends blind;
  the island can be circled through its eastern approach. The optional vent and
  closed eastern lagoon add branches. Painted rock, map and actual collision share
  reproducible jagged contours, with up to approximately 18 units of edge erosion.
  This intentionally changes authored terrain, while retaining vessel physics.
- The rough rockfall is now 380 units thick. **Three properly placed torpedoes**
  open a full-hull passage; one or two do not. Eligibility still checks actual
  continuous hull clearance, not a shot counter. Off-center openings can qualify.
  Ten rounds and intentional docking/rearming remain; a player can always retrace
  the west side to replenish. Protected cave boundaries cannot be blasted away.
- Detailed atlas illustrations present an eel and turtle using existing harmless
  collision-safe creature motion. A hammerhead patrols a closed optional lagoon
  beneath the main buoy approach. It holds during a 2.5 s text/symbol warning,
  pursues at 185 units/s for at most 6 s, and may cause a **6-point head ram**.
  The inherited 3.5 s damage cooldown and immediate retreat after a successful ram
  bound repeated contact. Ascending to the open shallow passage ends pursuit.
  Its line-of-sight proximity adapter does not fabricate acoustic events. Existing
  active sonar/explosion hearing, event identities and bounded history are reused;
  passive listening remains silent. No combat is required to finish the chapter.
  All three animals use the existing BlastReceiver health, blast-ID suppression
  and session reset. They grant no loot, XP or mission reward. Their projectile-hit
  layers are disabled outside the canonical region presentation.
- Torpedo impacts have a short pressure flash/ring and existing local refraction,
  expanding/contracting cavitation, rising bubbles and textured fragments. This is
  a stylized presentation, not a fluid simulation. Three batches total 50 instances;
  full effect lifetime is 2.6 simulation seconds. Comfort modes omit decoration,
  flash and lens, retaining a quiet short ring. Damage/range/event rules are unchanged.
- Twelve seafloor sources feed one bounded 36-bubble batch with deterministic
  irregular phases. Existing snow/vents remain bounded. The geometric bloom swims
  locally while alive, including after peaceful observation; collection removes it.
  Pause and comfort settings stop decorative motion without changing eligibility.
- A unique radio delivery requests a short UI-bus squelch/beep; duplicate messages
  and reopening transcripts do not. Original muffled blast and occasional bubble
  cues use the existing Effects bus. All honor volume/mute and voice budgets;
  none become extra gameplay acoustic events. Critical information remains text.

## New Game and save compatibility

The title now offers **New Game** alongside the existing Begin/Continue, Options,
Quit and prototype access. A bounded, scrollable confirmation explains exactly
what resets; cancel preserves everything. Keyboard Tab / controller right shoulder
cycles controls and Enter / A confirms. It works even when an old checkpoint needs
recovery; intentional New Game archives it rather than silently overwriting it.

Before writing a fresh checkpoint, `SaveCoordinator.begin_new_campaign()` renames
all expedition and four legacy campaign-store primaries, backups and recovery
sidecars into `campaign-archive-<timestamp>-<ticks>` in the checkpoint's parent
folder. The new schema-7 file resets story, choice flags, discoveries, research,
missions, ranks, ammunition, terrain, route and vessel resources. The fresh scene
starts the opening briefing. Settings/tutorial preferences are retained. Removing
old narrow stores from their live paths prevents legacy progress being reimported.
Reported archive/write failures roll back moved originals; tests check byte identity.
This is not a general profile/slot UI, and archives have no in-game restore button.
For manual recovery, quit and move the current campaign primaries, backups and
recovery sidecars into a separate preserved folder (keep settings). Restore the
matching archived set together to its original unprefixed filenames/parents; do
not mix one campaign's primary with another's backup or legacy files. Archive filenames
prefix the original basename with `0-` for expedition and `1-`..`4-` for narrow stores.

The existing atomic checkpoint writer and backup/recovery schema remain unchanged.
Multi-file archiving has rollback on reported I/O errors, but **does not provide a
power-loss transaction journal** across every rename. In the event of interruption,
inspect/preserve the archive before recovery. No prior campaign is intentionally
deleted. No settings file is archived or reset.

A pre-revision save with permanent `sunlit-cleared-passage` reconstructs a generous
opening in the thicker gate after restoring its terrain. This derives geometry from
an existing permanent ID, consumes no bounded excavation-journal slots, and emits
no discovery/reward/acoustic replay. Save schema and all stable IDs stay unchanged.
An old vessel pose intersecting newly authored solid rock uses the existing safe-base
relocation with resources/progress preserved. The prototype region remains separate.

## Manual playtest

1. Start from an existing profile. Choose **New Game**, navigate the confirmation
   with keyboard or controller, then cancel: Continue and files should be unchanged.
   Confirm on a second attempt. Read the fresh briefing; verify settings survived,
   fresh resources/ten torpedoes, empty records and an archived prior campaign.
2. Launch, listen to a radio arrival, reopen its transcript (no second arrival cue),
   then mute audio and check the same information remains understandable.
3. Visit the bloom. Observe swimming shapes, pause (motion stops), and choose either
   path. The peaceful bloom remains alive; collection removes it. Both complete.
4. At the rockfall near x=4550, face east and fire three carefully centered shots.
   Watch each transient effect and the progressively cut rock. The first two must
   not grant passage completion; the third should open a whole-hull route. Dock to
   rearm if necessary. Quit/Continue must retain an already cleared opening.
5. Beyond the silver shoal, travel below the floating island, ascend on its east,
   and double back into the high blind alcove (around 6750,270). Turn back east;
   the blind wall is solid. Observe the turtle near (7650,335), eel near (8500,650),
   and irregular seafloor bubbles. Follow the lower arch at y≈710, then ascend
   through the baffles around x=11780. These coordinates are reviewer aids only.
6. Optional: descend near x=19000 into the closed lagoon. Read HAMMERHEAD / alert
   text and `!` before pursuit. Permit one ram, check modest hull loss, then ascend
   to y≈650. It cannot follow into the main course or pin the vessel. Repeat with
   passive listening: listening itself must not alert it. Do not enter to finish
   the chapter; the normal route stays outside its territory.
7. Find the buoy through the existing sonar wavefront, scan the unchanged message,
   return through the cleared course, deliberately dock and debrief. Reopen research
   technology, respec, save/quit/Continue. Story, science, XP/ranks and claims must
   remain idempotent; route restart must preserve these permanent records.
8. Repeat at 800×600 with Large Text/High Contrast and reduced motion/effects/
   particles. Check scrolling/focus/Cancel, visible quiet impact feedback, frozen
   cosmetic motion and no new visual obstacle falsely suggesting an opening.

## Reproduce

Use pinned Godot `4.6.3.stable.official.7d41c59c4`, GUT 9.6.1 and the existing
Compatibility renderer. Install/bootstrap as documented in the root README.

```sh
python3 tools/validate_godot.py
python3 tools/run_tests.py
python3 tools/verify_sunlit_shallows.py
python3 tools/verify_expanded_expedition.py
python3 tools/verify_revision_two.py
python3 tools/verify_story_choice.py
python3 -m unittest discover -s tests/python -v
python3 tools/build_playtest.py
```

Native actual-input evidence (not a realtime performance sample):

```sh
mkdir -p /tmp/pr35-native
BTA_EVIDENCE_DIR=/tmp/pr35-native godot --path . --audio-driver Dummy \
  --rendering-method gl_compatibility --disable-render-loop --fixed-fps 60 \
  --script res://tests/fixtures/drive_sunlit_environment.gd --quit-after 90000 -- \
  --profile=pr35-review-fresh --input=controller --outcome=observe \
  --fauna-demo --survey-studies
```

Use a unique profile for each fresh run. Add `--small --high-contrast` for 800×600 Large Text/
High Contrast, `--wide` for 1920×1080, `--comfort` for reduced settings. The fixture
injects actual key/joypad events, follows focus and pilots the route; it does not
teleport the vessel or directly grant completion. Static screenshot/performance
fixtures elsewhere do place a vessel and must not be confused with this walkthrough.

## Evidence and limitations

[Exact results and commands](verification.txt) · [Changed files](changed-files.txt)
· [Asset provenance/import inventory](../../../../assets/art/sunlit/README.md).
Screenshots in this directory are native Godot viewport captures, not mockups or
an assertion of human visual acceptance. Automated keyboard/controller events are
not a physical-device or first-time human playtest. Audio playback/listening quality,
biological anatomy, visual polish and hardware 60 FPS require human/target-GPU review.
Artwork is original AI output with recorded provenance and pending project licensing;
new sound is repository-authored deterministic DSP. No new dependencies are added.
The older BTA-051 software-renderer regressions remain documented in
[performance.md](../performance.md); this revision does not declare them solved.

## Native actual-input gallery

The 1280×800 controller run observes the bloom and scans all eight optional studies.
The 800×600 keyboard run collects the specimen, with Large Text, High Contrast,
Reduced Motion/Effects/Particles and muted audio. Both deliberately enter the
optional lagoon and escape. These pictures are captured during the real input
walkthrough, with only evidence frames explicitly rendered on this software host.
They are not realtime frame-rate measurements. All chapter success tokens, counts
and rendering-driver identities are retained under logs.

| Subject | 1280×800 normal/controller | 800×600 Large Text + comfort/keyboard |
| --- | --- | --- |
| New Game title option | [Title](route-1280/observe-title.png) | [Title](route-800/collect-title-small.png) |
| Safe confirmation / reading focus | [Confirmation](route-1280/observe-new-game-confirmation.png) | [Confirmation](route-800/collect-new-game-confirmation-small.png) |
| Bloom choice | [Peaceful choice](route-1280/observe-bloom-choice.png) | [Collection choice](route-800/collect-bloom-choice-small.png) |
| Rockfall before excavation | [Thick rough plug](route-1280/observe-rockfall-before.png) | [Thick rough plug](route-800/collect-rockfall-before-small.png) |
| Second impact (still blocked) | [Pressure flash / bubbles](route-1280/observe-underwater-detonation-2.png) | [Comfort ring](route-800/collect-underwater-detonation-2-small.png) |
| Full-hull opening after three shots | [Opening](route-1280/observe-rockfall-after.png) | [Opening](route-800/collect-rockfall-after-small.png) |
| Blind alcove / lower loop | [Alcove](route-1280/observe-dead-end-alcove.png) | [Alcove](route-800/collect-dead-end-alcove-small.png) |
| Illustrated turtle | [Turtle](route-1280/observe-sea-turtle.png) | [Turtle](route-800/collect-sea-turtle-small.png) |
| Illustrated eel | [Eel](route-1280/observe-moray-eel.png) | [Eel](route-800/collect-moray-eel-small.png) |
| Lower arch / rough stone | [Passage](route-1280/observe-rock-arch-passages.png) | [Passage](route-800/collect-rock-arch-passages-small.png) |
| Hammerhead approach | [Approach: pursuit already active](route-1280/observe-hammerhead-warning.png) | [Start of pre-pursuit warning](route-800/collect-hammerhead-warning-start-small.png) |
| Modest head ram | [Hull feedback](route-1280/observe-hammerhead-ram.png) | [Hull feedback](route-800/collect-hammerhead-ram-small.png) |
| Ascending to safety | [Safe retreat](route-1280/observe-hammerhead-safe-retreat.png) | [Safe retreat](route-800/collect-hammerhead-safe-retreat-small.png) |
| Sonar buoy / recovered message | [Buoy](route-1280/observe-buoy-environment.png) | [Buoy](route-800/collect-buoy-environment-small.png) |
| Return / deliberate debrief | [Return](route-1280/observe-halcyon-return.png), [debrief](route-1280/observe-debrief.png) | [Return](route-800/collect-halcyon-return-small.png), [debrief](route-800/collect-debrief-small.png) |

The first close-approach capture in the 1280 run occurs after the warning has
elapsed; its filename is historical. The 800 warning-start image is captured from
the actual ALERT transition, before pursuit. The tests independently assert no
warning-phase damage and the 2.5-second boundary at 30/60/120 steps.

[Current software-renderer measurements, raw samples and same-position comparisons](performance.md)
cover all three window sizes in both modes. 5/36 medians were higher than the
initial PR #35 sample and 31/36 lower/equal; these separate cloud sessions do not
establish a causal speed improvement. The new atlas adds about 8 MiB of reported
texture allocation. Static probes do not measure transient blast spikes. Target-GPU
and human acceptance remain open; see the explicit limitations in that report.
