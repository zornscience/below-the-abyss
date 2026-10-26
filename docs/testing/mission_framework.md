# BTA-034 verification and playable walkthrough

## Exact commands

From the repository root with pinned Godot 4.6.3 available as `godot`:

```sh
python3 tools/install_gut.py
python3 tools/validate_godot.py
python3 tools/run_tests.py
godot --path .
```

Focused mission tests:

```sh
godot --headless --path . --script res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_mission_service.gd,res://tests/unit/test_mission_store.gd,res://tests/integration/test_mission_framework.gd -gexit -gdisable_colors
```

Existing GitHub Actions PR/main validation runs the same pinned engine/GUT installer,
project validator and full-suite wrapper, retaining logs/JUnit artifacts. No CI checks
are removed. The existing real-input full-route test is extended through mission
acceptance, real scanning and sonar discovery, return, service and explicit claims;
all original navigation/resource/collision assertions remain.

## Complete playable mission walkthrough

Neither upgrades nor the optional creature encounters are required. Use normal mode;
development mode retains its existing Interact debug tools.

1. Begin exploration at Shelf Base. Slow within the docking ring and press **E /
   controller A** (remappable Interact). Choose **Mission board / notices**, then
   **Missions / accept objectives and claim acknowledgements**. Reading notices
   alone accepts nothing. Arrows/Tab/D-pad navigate; Enter/A selects.
2. Select MAIN / Shelf expedition, then **Accept objective**. Select OPTIONAL /
   Calibration study and accept it too. Both show ACCEPTED and unchecked objectives.
   Claim is disabled. Gameplay remains paused throughout station pages.
3. Escape/B/Start backs to notices, then services, then piloting. The HUD's mission
   summary lists accepted objectives and progress. Head east to the shelf navigation
   marker around `(760,480)`, beyond the base docking radius. Ping with F/controller X
   (remappable sonar action), wait for the wavefront, then press E/A to scan the
   plate within its 240-unit radius. Hold position for three simulation seconds.
   The optional objective becomes COMPLETED, not CLAIMED. Passive listening alone
   cannot discover or complete it.
4. Continue east along the marked cave passage: UpperGate `(1200,480)`, Cave
   `(2350,480)`, EastChamber `(3050,480)`, then Twin Spires `(3500,650)`. Stay on the
   main route below the clearly marked optional predator pocket. Ping near the
   spires and wait for the wavefront to identify the existing landmark. MAIN should
   report one of two objectives. No new discovery or route detection is introduced.
5. Return west through ReturnTurn `(3100,650)`, south to LowerEast `(3100,970)`,
   west to LowerWest `(900,970)`, north to BaseRise `(900,480)`, then base `(420,480)`.
   The existing route checker reports LOOP COMPLETE; MAIN becomes COMPLETED.
   Supplies should be lower on arrival, with no automatic restoration.
6. Dock intentionally. Use repair/refill services if desired, then reopen Missions.
   Select each completed objective and choose **Claim acknowledgement**. The board
   shows CLAIMED, checked objectives and the authored acknowledgement text. This
   creates no money, inventory, upgrades or resource changes. Repeated activation
   and reopening the board must not grant anything again.
7. Use Restart Test Route separately: route/temporary sonar state resets, but mission
   flags and both claims remain, alongside discoveries/research/upgrades. Quit and
   relaunch: claimed records remain without replaying completion/reward events.
8. Late acceptance: earlier permanent scans/discoveries count immediately. If the
   route is currently COMPLETE it also counts; unaccepted historical routes are not
   saved across a prior restart/reload. The policy is described on the decision page.
9. Test keyboard and controller back/navigation at 1280x800 and 800x600. Use the
   **Details ↑/↓** buttons to scroll long mission text without a mouse. Confirm map,
   research log, sonar, scanning, harmless observer, predator and both upgrades still
   operate. Station services must retain mission flags and route telemetry.

## Safe corruption/recovery exercise

Preserve the mission file/backup externally first; never damage discovery/research/
upgrade files for this exercise. After claiming, quit and corrupt only the mission
primary. Relaunch: SAVE BLOCKED appears and transitions are unavailable. Dock and
open Missions → Recover backup. The checkpoint restores CLAIMED without replaying
completion/claim events; rejected content remains in `.rejected`. A second recovery
cannot overwrite that preserved file. Missing/incompatible primary, malformed
checkpoint and simulated write failures are also covered automatically. Resolve
errors before quitting if progress could not be committed.

## Native walkthrough/screenshots

```sh
DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 godot --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/fixtures/capture_mission_framework.gd
```

Requires a working X11 display. The fixture resets only its isolated
`user://bta034-capture.json` files and sidecars. It operates real keyboard/controller
Input events and flies the entire route with existing input steering, with no vessel
pose/velocity writes, domain-state injections or resource grants. It asserts exactly
two completion signals and two acknowledgement signals, then verifies services,
restart and fresh-scene reload retain claims.

- [Available objectives](bta-034-available.png)
- [Accepted optional objective](bta-034-accepted.png)
- [Scan completed during expedition](bta-034-scan-complete.png)
- [Return with both objectives completed](bta-034-returned.png)
- [Ready for explicit claim](bta-034-ready-to-claim.png)
- [Claimed acknowledgement](bta-034-claimed.png)
- [Compact 800x600 page](bta-034-compact.png)

These are actual Godot X11/GL compatibility screenshots with Mesa llvmpipe, not
mockups. Controller evidence uses native joypad Input events; physical-device
ergonomics and subjective external human playtests remain manual checks. Native
runtime/file behavior is verified on Linux; Windows/macOS device testing is not claimed.

See [mission API, policy, persistence and limitations](../decisions/bta-034-mission-framework.md).

## Verification results

- Godot `4.6.3.stable.official.7d41c59c4`: import, all **137 authored script
  checks** and startup smoke passed. Final mission/UI/store script checks passed.
- Full local GUT: **347/347 tests**, **24,058 assertions**, 43 scripts,
  225.525 seconds; zero failures, errors or skipped tests.
- Focused mission tests: **25/25**, **242 assertions** passed.
- Native walkthrough completed with
  `BTA034_NATIVE_ACCEPT_SCAN_DISCOVER_RETURN_CLAIM_SERVICE_RESTART_RELOAD_OK completions=2 acknowledgements=2`.
- Pinned GUT installer verification, actionlint and whitespace checks passed.
- The expanded real-time walkthrough brought the observed suite close to its previous
  240-second subprocess limit, so it now has a bounded 300-second limit. The GitHub
  Actions job remains bounded at ten minutes; no checks or failure handling are removed.
- The PR records the final verification rerun and actual hosted GitHub Actions run,
  including final commit and retained artifact details.
