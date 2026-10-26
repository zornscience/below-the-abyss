# BTA-032 verification

## Reproduce

From the repository root, with Godot 4.6.3 on PATH:

```sh
python3 tools/install_gut.py
python3 tools/validate_godot.py
python3 tools/run_tests.py
godot --path .
```

Focused station tests (full suite also includes these):

```sh
godot --headless --path . --script res://addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_station_services.gd,res://tests/integration/test_station_interaction.gd -gexit -gdisable_colors
```

GitHub Actions runs the same installer, validator and full-suite wrapper on PRs to
main and pushes to main, with checksum-pinned Godot 4.6.3 and GUT 9.6.1. Existing
failure propagation and retained logs/JUnit artifacts are unchanged. The existing
real-input continental-shelf full-flight test now continues through explicit
station service after returning, preserving every earlier route/no-auto-refill
assertion.

## Manual keyboard/controller playtest

1. Launch, choose Begin exploration, and leave development mode off. The base has a
   docking ring, bracket, sign and STATION Interact prompt. Cross/leave/re-enter it:
   hull/battery/oxygen must not refill automatically.
2. Slow to at most 40 world units/second inside the ring. Press E or controller A.
   Confirm the DOCKED menu, FREE cost, individual before/after previews, focus outline
   and stopped simulation. Enter/leave the menu without service: values must not rise.
   Try entering while too fast: the Slow down message must appear without a scan.
3. Navigate with arrows/Tab or D-pad, select with Enter/A. Explicitly repair, charge
   or refill; only the selected resources should change. Service all restores all
   eligible pools. Full/disabled services show a reason and cannot activate. Using
   a profile with a smaller per-service limit must cap each activation; zero disables.
4. Read both mission-board notices. They offer no accept/complete/reward operation.
   Escape/B/Start returns to services, then to piloting. Repeat at 800x600 and
   1280x800; all pages/buttons must fit, with notices scrollable if needed.
5. Depart via the main safe route, deliberately scan a nearby target with E/A outside
   the ring, visit the calibration POI and return to base. Use active sonar as desired.
   Confirm depleted supplies on arrival, then dock and service. Route completion,
   discoveries, research entries, sonar history/cooldown and position must remain.
6. While docked, wait and confirm no battery/oxygen/pressure drain, contact expiry,
   creature movement or route-time advancement. Undock and confirm simulation resumes.
   Remap Interact in settings and repeat docking and outside-station scanning.
7. Use Restart Test Route separately: it closes a station session and performs the
   documented prototype reset, retaining permanent discovery/research records.
   Also check map, research log, active/passive sonar and the optional predator and
   harmless observer after undocking. Main routes remain clear of the optional predator.

## Native graphical evidence

The actual Godot X11 compatibility renderer (Mesa llvmpipe) ran
`tests/fixtures/capture_station_services.gd` with real Input events. This fixture
injects a 20-point hull deficit **before departure** solely to demonstrate repair;
it does not claim the safe route causes damage. It then earns a scientific record,
flies the complete outbound/return route, and docks without position/velocity writes.
Return values were hull 80, battery 39.34, oxygen 76.30, route COMPLETE, one research
record. Explicit Service all produced 100/100/100 with route, records and acoustic
history preserved. Controller board/back/undock/redock was also exercised.

```sh
DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 godot --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/fixtures/capture_station_services.gd
```

Requires a working X11 display; the fixture uses isolated `user://bta032-capture.json`
settings/discovery/research files. It overwrites only that fixture's records.

- [Station landmark](bta-032-station.png)
- [Returned expedition, before docking](bta-032-returned.png)
- [Before service](bta-032-before-service.png)
- [Explicit service result](bta-032-after-service.png)
- [Read-only notices](bta-032-notices.png)
- [800x600 services](bta-032-compact-services.png)
- [800x600 notice board](bta-032-compact-board.png)

These are native engine screenshots, not mockups. Automated controller evidence uses
Godot joypad Input events; physical controller ergonomics and human subjective
playtesting remain manual checks. No claim of a human hardware playtest is made.

See [API and balancing decisions](../decisions/bta-032-station-services.md).

## Local results

- Godot `4.6.3.stable.official.7d41c59c4`: import, all 120 authored script checks,
  startup smoke passed.
- Full GUT: 303/303 tests, 22,868 assertions, 38 scripts, 164.856 seconds;
  zero failures, errors or skipped tests.
- Focused station coverage: 18/18 tests, 236 assertions.
- Pinned GUT installer verification, actionlint and `git diff --check` passed.
- Native graphical fixture completed with
  `BTA032_GRAPHICAL_DEPART_SCAN_EXPLORE_RETURN_SERVICE_BOARD_CONTROLLER_OK`.

The pull request records the actual GitHub Actions run for its final commit.
