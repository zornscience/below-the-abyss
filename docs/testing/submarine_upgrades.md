# BTA-033 verification and playtest

## Commands

Use pinned Godot 4.6.3 from the repository root:

```sh
python3 tools/install_gut.py
python3 tools/validate_godot.py
python3 tools/run_tests.py
godot --path .
```

Focused tests (disable default directory collection to run only these scripts):

```sh
godot --headless --path . --script res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_upgrade_store.gd,res://tests/integration/test_submarine_upgrades.gd -gexit -gdisable_colors
```

The existing GitHub Actions PR/main workflow runs the same pinned installer,
validation and full-suite wrapper and retains logs/JUnit artifacts. No workflow
checks are removed or bypassed. The old sonar HUD exact-string expectation now
includes the baseline numerical range; its gameplay assertions remain unchanged.

## Manual keyboard/controller playtest

Use a fresh profile for the baseline comparison, or preserve/move only the existing
upgrade file and its backup before launching. Do not delete discovery/research files.
User data locations are available through Godot's Project > Open User Data Folder.

1. Begin exploration in normal mode. Confirm HUD sonar RANGE 900 u and safe depth
   300 m. Passing through the base or opening services must not install anything.
2. Slow inside the docking ring; E/controller A opens station services. Choose
   Prototype upgrades using arrows/Tab/D-pad and Enter/A. Read both explicit
   before/after values and FREE installation rules. Simulation stays paused.
3. Select Sonar range / install FREE deliberately. Confirm 900 → 1200, saved status,
   installed/disabled button and HUD range 1200 after undocking. Repeat activation
   must not stack, charge battery or generate another completion event.
4. From approximately `(760,480)`, ping. The overlook echo `(1750,240)` is about
   1019 world units away: baseline cannot reveal it; installed sonar reveals it
   only when the wave reaches it (~1.70 seconds). Each successful ping still costs
   4 battery and starts a four-second cooldown. Listening passively remains silent.
5. Install Pressure hull / deeper operating rating. Confirm 300 → 400 meters and
   persistent installed state. It must not restore current hull/battery/oxygen.
   Navigate the safe main route east and turn south at the lower-return junction
   into the marked optional pressure trench. At 320–335 m the baseline HUD shows
   DANGER and eventually loses hull; the upgraded HUD shows SAFE and takes no
   pressure damage. CAUTION now begins at 360 m. Do not confuse the fixed baseline
   trench signs with the vessel's current rating shown on the HUD.
6. Ascend, complete the return route and use legitimate station services. Check
   upgraded capability values, route completion and permanent research/discoveries
   remain. Reopen the menu: installed buttons remain disabled. Back/Escape/B/Start
   returns from upgrades to services, then to piloting. Repeat at 800x600/1280x800.
7. Use Restart Test Route: temporary sonar/route state resets as previously documented,
   both installed capabilities remain. Quit/relaunch: both remain installed, using
   saved IDs rather than stacked multipliers. Verify map/research, scanner, passive
   sonar, harmless observer and optional predator still operate.
8. Persistence recovery: back up the upgrade file externally, install both upgrades
   to create `.bak`, quit, then place malformed content in the primary only. Relaunch:
   baseline capabilities and a readable blocked-install status must appear. Dock,
   open upgrades and intentionally recover backup. The valid previous ID set returns;
   the rejected primary is preserved as `.rejected`. Recovery may restore only the
   earlier installation. A second recovery must not overwrite `.rejected`. Preserve
   files before moving/removing the rejected copy for further testing.

## Native graphical evidence

Reproduce with a working X11 display (the automated fixture clears only its own
`user://bta033-capture.json` settings/upgrade/discovery/research files and sidecars):

```sh
DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 godot --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/fixtures/capture_submarine_upgrades.gd
```

- [Before installation](bta-033-upgrades-before.png)
- [After both intentional installations](bta-033-upgrades-after.png)
- [800x600 installed page](bta-033-upgrades-compact.png)
- [Baseline depth/HUD comparison](bta-033-depth-before.png)
- [Upgraded depth/HUD after actual input-driven flight](bta-033-depth-after.png)

These are native Godot X11/GL compatibility renders using Mesa llvmpipe. The baseline
335-meter comparison is explicitly staged while simulation is stopped; it does not
claim a baseline expedition was flown. Keyboard/controller installation and the
subsequent upgraded expedition use native Input events. The fixture pings from
`(760,480)`, verifies the real out-of-baseline-range overlook echo, flies the normal
route, descends to ~335 m, waits beyond the baseline grace period without hull loss,
returns, services explicitly and restarts with both upgrades retained. No movement
pose/velocity writes are used during that flight. Controller events are injected;
physical-device ergonomics and subjective human playtesting remain manual checks.

See [API, balancing, schema and limitations](../decisions/bta-033-persistent-upgrades.md).

## Local results

- Godot `4.6.3.stable.official.7d41c59c4`: headless import, all 127 authored
  script checks and startup smoke passed.
- Full GUT: **322/322 tests**, **23,804 assertions**, 40 scripts, 173.676 seconds;
  zero failures, errors or skipped tests. This includes all prior tests.
- Focused BTA-033 tests: 19/19 tests, 933 assertions passed.
- Native fixture verified the extended-range echo, a ~335-meter pressure-safe flight,
  explicit return services and persistent upgrades after restart.
- Existing workflow lint and whitespace checks passed. The PR records actual hosted
  GitHub Actions results for its final commit and retained validation artifacts.
