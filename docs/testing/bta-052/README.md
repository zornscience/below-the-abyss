# BTA-052: Surface expedition and instrument polish

Review branch: `bta-052-surface-expedition-polish`, based on merged PR #35.
User-selected layout: open-water shelf with optional caves. This changes canonical
geography deliberately; the old prototype terrain remains available in development
mode. No new region, mission, story choice, currency or save file is introduced.

## Behavior and balancing

- Halcyon's painted platform deck is above world **y=0**. Lantern-2 launches at
  **(420,80), 20 m**. A fixed surface collider keeps the hull submerged; decorative
  waves never move collision. Existing **0.25 m/world unit** mapping is unchanged.
  Ordinary shelf floor y=800 is 200 m: a roughly 180 m descent from departure.
  New optional lower caves reach about 285 m, within the stock 300 m rating.
  The existing optional deep vent remains a local pressure hazard, not Zone 2.
- The main route is open water; rockfall excavation is optional. Grounded shelters,
  a blind alcove and three additional horizontal plugs provide side exploration.
  Authored research positions and buoy/story IDs stay fixed. Painted trim follows
  actual rock, including excavated polygons. Extra entrances use the same bounded
  excavation journal and torpedo interfaces.
- Visible specimens, the reference plate and the bloom can be scanned by approaching
  and activating Interact, without a preceding ping. Terrain line of sight prevents
  scanning through cave roofs. An authored, bounded surface allowance permits inspection
  of the legacy wreck’s hull around its embedded recorder anchor. Hidden buoy acquisition still requires the outbound
  sonar wavefront. Passive listening does not discover targets or generate pings.
- Torpedo count is alongside hull/power/oxygen. Floating scan/route/docking words and
  docking-radius drawings are removed. Optional tutorial cards remain configurable
  in Help/Options; contextual HUD interaction prompts remain.
- Text Up/Down buttons are removed from story, logs, research, radio, notices and
  mission details. Focus the reading pane with Tab/shoulder, then use D-pad/Up/Down;
  PageUp/PageDown, wheel and scrollbars also work. Fixed Back/Escape remains.
- Incoming radio types at 34 characters/second, follows the tail and dismisses after
  a length-dependent reading hold. Reduced Motion displays it immediately. The unread
  archive remains available with R/left shoulder; manually opened transcripts stay
  until closed. Dismissal never accepts an assignment, deletes evidence or pauses
  piloting. Existing incoming radio sound and mute/volume controls remain.
- Five icon-labelled research branches reconstruct authored baseline capabilities:
  sonar range 900→1200→1500→1800; rated hull 300→400→450→500 m;
  torpedo acceleration 500→750→1000→1250; blast radius 150→190→215→240
  (UI compares **area**); engine acceleration 120→180→240→300.
  Speed, drag, energy costs and cooldowns do not change. First new rank costs **2 RP**,
  further ranks **3 RP**. Existing total budget remains bounded at six; at most two
  new ranks. Canonical-only chapter awards four total points, funding one rank with
  free reassignment; archived outer-shelf awards can fund a second. No repeat farming.
- Cosmetic sonar arcs return from reached targets/terrain toward the submarine.
  They add no AcousticEvents and do not change reveal time, history or cooldown.
  Returns are bounded (16 terrain probes/ping, 24 spatially deduplicated sources/ping,
  32 live effects), and disappear on restart. Reduced Particles suppresses them;
  Reduced Motion/Effects uses quiet static feedback.
- Painted torpedoes, subtle atlas deformation on existing fauna, a slow red status
  beacon, clipped headlight material illumination and a quiet Music-bus score improve
  presentation. No decoration changes physics, saves or event identity. The light
  approximates first-surface contact with nine cached rays; it is not physical optics.

## Save compatibility

Atomic expedition schema **8** adds three rank keys and `legacy_ranks` inside the
existing campaign section. Versions 1–7 migrate in memory through the existing
coordinator/backup/recovery path. Existing sonar/hull allocations retain their effects
and original one-point paid cost. Refunding a legacy rank returns that original cost;
reassigning uses current prices. Capabilities never multiply on reload. A freed-up
old pose obstructed by reauthored rock uses the existing validated-base relocation
without resetting resources or permanent progress. Old underwater poses otherwise
remain unchanged; returning players ascend to the new near-surface dock.

Version 8 permits the authored upgraded blast radius up to 240; older documents retain
the previous 160 maximum. All terrain IDs remain stable and old journal records are
retained across prototype/canonical switching. No old mission or narrative IDs change.
Keep a backup before switching branches: an older binary intentionally rejects the
new schema rather than guessing its meaning.

## Reproducible checks

```sh
python3 tools/install_gut.py
python3 tools/install_export_templates.py
godot --version # 4.6.3.stable.official.7d41c59c4
godot --headless --editor --path . --import
python3 tools/validate_godot.py
python3 tools/run_tests.py
python3 tools/verify_expanded_expedition.py
python3 tools/verify_revision_two.py
python3 tools/verify_story_choice.py
python3 tools/verify_sunlit_shallows.py
python3 -m unittest discover -s tests/python -v
python3 tools/build_playtest.py
# Pass the exact emitted archive path to tools/smoke_playtest.py.
```

Launch: `godot --path .`. Native input evidence uses
`tests/fixtures/drive_sunlit_environment.gd` with `--disable-render-loop`; screenshots
force native Godot draws, while the fixture pilots with physical key/controller events.
This accelerated evidence run is not an FPS benchmark or a human playtest.

## Manual route

Begin a New Game or use a separate profile. Read the short briefing; depart beneath
Halcyon and try ascending: the waves are a solid ceiling. Descend to the bloom and
Interact without sonar. Complete either decision. Observe the ammo/resource deck.
Explore east over the rockfall, or fire three facing shots through it. Dive into a
lower shaft near x6200/y1000 and blast east into its optional tunnel; exit west and
ascend. The second blocked lower cave is near x11350/y1000; the basalt arch entrance
is near x9800/y650. No cave or blast is required for chapter completion.

Approach a visible shoal or mineral specimen and Interact directly. Try scanning the
arch from above its roof: it should fail. Watch radio typing, tail scrolling and
automatic dismissal; reopen the complete message with R/left shoulder. In the reported
buoy search area, ping and wait for outbound arrival and returning arcs. Scan the
identified buoy, return west, ascend to Halcyon and Interact. Automatic docking services
rearm/refill; the debrief and permanent records work as before. In Technology, compare
icons, prices and before/after values; buy an engine or torpedo rank, then freely
reassign. Quit/Continue and restart must preserve earned points and installed ranks.

Repeat at 800×600 with Large Text/High Contrast, muted audio and reduced settings.
Check reading-pane focus and D-pad scrolling, Escape/Back recovery, no menu input firing
sonar/torpedoes, no oversized empty prompt panels, steady beacon under reduced flashing,
quiet visual alternatives and optional tutorial disable. Adjust Music separately from
radio/UI sounds. Human evaluation of music, feel and art is still needed.

## Results and limitations

Final command results and screenshot inventory are recorded alongside this document
once verification completes. Native renders use Mesa llvmpipe software rendering;
no claim of target-hardware 60 FPS or professional art/audio acceptance is made.
