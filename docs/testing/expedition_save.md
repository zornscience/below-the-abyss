# BTA-035 save/resume verification

## Exact commands

From the repository root, with pinned Godot 4.6.3 on PATH:

```sh
python3 tools/install_gut.py
python3 tools/validate_godot.py
python3 tools/run_tests.py
godot --path .
```

Focused persistence and scene tests:

```sh
godot --headless --path . --script res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_expedition_store.gd,res://tests/integration/test_expedition_resume.gd -gexit -gdisable_colors
```

The unchanged PR/main GitHub Actions workflow runs the pinned installer, validator
and complete GUT wrapper and retains logs/JUnit. Existing standalone domain-store,
mission, station, upgrades, creatures, sonar, movement and resource tests remain.
New coordinated-save tests inject isolated checkpoint paths to exercise the actual
normal-game coordinator without writing the user's default profile.

## Complete player walkthrough

1. Launch. On a new profile choose **New Expedition…**, inspect its preservation
   warning and deliberately confirm (or Begin exploration). On an existing profile,
   choose **Continue saved expedition**. Corrupt/incompatible profiles block starting
   and explain recovery; never remove files just to hide an error.
2. Dock at Shelf Base with remappable Interact (E/controller A). Open Mission board →
   Missions and intentionally accept Shelf expedition and Calibration study. Back
   out to pilot; the mission HUD reports accepted objective counts.
3. Approach `(760,480)`, ping with F/controller X, wait for the wavefront, then
   deliberately scan the plate with Interact outside the docking ring. Hold position
   for three seconds. Confirm the discovery map and completed research record.
4. Follow the main route east. Near `(1450,400)` ping to observe the harmless creature
   investigate the sound; passive listening alone must not attract it. Continue to
   Twin Spires and ping to identify the landmark. The optional predator remains
   separate and escapable; no threat encounter is required to finish the route.
5. Return via the lower passage to Shelf Base. Supplies must not refill merely on
   arrival. Dock, explicitly repair/refill, and read the checkpoint-success message.
6. Open Prototype upgrades and install the sonar-range and/or pressure-hull upgrade.
   Return to Missions and claim completed acknowledgements. Verify installed values,
   mission CLAIMED state and research/discovery records.
7. Back to piloting, pause with Escape/Start and choose **Save expedition**. Wait for
   the explicit Expedition saved confirmation. Quit the application completely.
8. Relaunch; choose **Continue saved expedition** with keyboard or controller.
   Compare position, orientation, hull/battery/oxygen, range/depth upgrades, discovery
   map, research log and mission flags against the save. Small resource drain after
   resuming is normal simulation; saved values are restored before those frames.
   Temporary echoes, contacts, partial scans and creature pursuit should be cleared.
9. Move, ping, scan/map and dock again to verify gameplay after loading. Save again.
   Repeat across multiple expeditions. New Expedition must ask for confirmation and
   keep permanent progress; Cancel must leave the old checkpoint alone. Restart Test
   Route remains a distinctly labeled development action.
10. Test the pause/confirmation and station pages at 1280x800 and 800x600. Arrows/Tab/
    D-pad navigate, Enter/A activate and Escape/B cancels New Expedition confirmation.
    Existing input remapping and controller bindings remain operational.

## Recovery and migration exercises

Preserve the entire user-data directory externally before destructive test edits.
Do not edit unrelated profiles. Save files live in Godot's user-data folder (editor:
Project → Open User Data Folder).

- Corrupt only `saves/expedition.json`, retaining `.bak`. Relaunch: no partial vessel
  load or false save. Choose Recover expedition backup. Inspect preserved `.rejected`,
  Continue and verify claims remain claimed without reward replay. Repeated recovery
  must not overwrite an existing `.rejected`.
- Remove/move only the primary, leaving backup: starting a new profile is blocked
  until explicit recovery. Unsupported versions and bad resource values also block.
- Use a valid JSON checkpoint whose position lies in the roof/outside region. Continue
  must relocate to clear base, preserve supplies/progress and reset temporary route.
  Malformed/nonfinite coordinates reject the document instead of entering physics.
- With no canonical file, use existing narrow stores. Valid progress imports without
  changing their bytes. Invalid legacy data blocks migration; the pause recovery
  action validates the required legacy backups before applying recovery. Original
  files/backups are preserved, not deleted during adoption.
- Pause during pressure danger or predator alert/pursuit: manual save must refuse
  with a readable message. Resolve write/disk errors before quitting; failed writes
  must not claim success or grant upgrade/mission transitions.

## Actual two-process native verification

With a working X11 display, run these commands **in order**:

```sh
DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 godot --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/fixtures/capture_expedition_save.gd
DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 godot --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/fixtures/capture_expedition_save.gd -- --resume-capture
```

The first process resets only its isolated `user://bta035-capture*` fixture files,
starts a confirmed New Expedition, accepts both missions, flies the actual shelf,
uses real sonar/scanning controls, encounters the investigating observer, returns,
services explicitly, installs both upgrades, claims both acknowledgements, manually
saves and exits. It never writes vessel position/velocity or injects domain progress.

The **second Godot process** preserves those files, starts fresh, uses controller
Continue, verifies restored pose/resources/route/upgrades/research/discoveries/claims,
asserts zero replayed mission/claim/scan/ping events from scene creation through load,
and verifies movement and another manual save after resuming. This is a true process
exit/relaunch, not just reinstantiating a scene.

Screenshots:

- [Startup](bta-035-start.png)
- [New Expedition confirmation](bta-035-confirm.png)
- [Harmless observer encounter](bta-035-observer.png)
- [Station checkpoint / upgrades](bta-035-station-saved.png)
- [Manual save confirmation before exit](bta-035-saved.png)
- [Fresh-process Continue](bta-035-continue.png)
- [Resumed gameplay](bta-035-resumed.png)
- [800x600 pause UI](bta-035-compact.png)
- [800x600 station/upgrade UI after Continue](bta-035-station-compact.png)

These are native Godot X11/GL compatibility renders with Mesa llvmpipe. Automated
keyboard/controller evidence uses real Godot Input events; physical-device ergonomics
and subjective human external playtesting remain manual checks. Native Windows/macOS
runtime/filesystem behavior and physical controller testing were not performed.

See [architecture, schema, migration, recovery and limits](../decisions/bta-035-general-save-system.md).

## Verification results

- Pinned engine: `4.6.3.stable.official.7d41c59c4`; headless import, all **143**
  authored script checks and startup smoke passed.
- Full local GUT: **368/368 tests**, **24,354 assertions**, 45 scripts,
  **183.221 seconds**; zero failures, errors or skipped tests. All prior tests remain.
- Final focused save/load coverage: **21/21 tests**, **287 assertions**, including
  the final canonical-status assertion. Station/upgrade focused regressions and the
  original active-sonar restart navigation also passed after the focus-ring fix.
- Native first process exited with
  `BTA035_SAVE_EXIT_OK complete_route_scan_observer_services_two_upgrades_two_claims=true`.
- Fresh-process Continue exited with
  `BTA035_FRESH_PROCESS_CONTINUE_OK position_supplies_upgrades_research_discoveries_claims_route=true replayed_events=0 movement_after_load=true`.
- Additional fresh-process repeats verified the final focus trap, readable canonical
  store status and 800x600 station/pause UI. Nine native screenshots are included.
- GUT 9.6.1 checksum verification, actionlint and whitespace checks passed.
- The PR records the final GitHub Actions result, exact commit/run and retained artifact.
