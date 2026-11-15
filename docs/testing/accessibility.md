# BTA-043 verification and native evidence

BTA-042 PR #23 was confirmed merged before branching from
`bb9217be24be2231089e4d202b556db329ab424c` as
`bta-043-controller-accessibility`. No new gameplay, story content, dependency,
progression field, acoustic ID/history rule or checkpoint schema is introduced.

## Reproduce automated verification

Pinned engine **4.6.3.stable.official.7d41c59c4**, GUT **9.6.1**. Repository root:

```sh
# Managed cloud directories; omit on a normal desktop:
export XDG_CACHE_HOME=/workspace/.cache
export XDG_DATA_HOME=/workspace/.local/share
export XDG_CONFIG_HOME=/workspace/.config
python3 tools/install_gut.py
python3 tools/validate_godot.py
python3 tools/run_tests.py
# Launch normal chapter:
godot --path .
```

Focused new tests:

```sh
godot --headless --path . --script res://addons/gut/gut_cmdln.gd -gexit -gdisable_colors -gconfig= -gtest=res://tests/unit/test_accessibility_settings.gd,res://tests/integration/test_accessibility.gd
```

The unchanged PR/main workflow installs checksum-pinned Godot/GUT, rejects import,
parser and smoke errors, and runs the whole GUT suite. It retains stdout, JUnit and
summaries in `godot-validation-<run>-<attempt>` for 3 days. The PR records its exact
hosted run, head SHA and result. No old test is removed, skipped or weakened.

New automated coverage (16 cases):

- Preferences roundtrip, legacy input-only/audio settings, invalid types/presets,
  no partial application, rejected-byte preservation and non-overwriting recovery.
- Device-specific remapped hints, drift suppression and active-device disconnect.
- Controller preview/save/cancel, scoped defaults, fixed confirm/back after a
  gameplay remap, modal preservation and keyboard escape after disconnect/capture.
- Cosmetic effect flags on existing and newly emitted sonar, unchanged battery
  cost, wavefront discovery and acoustic ledger count.
- All three resolutions with three passive contacts, Large numeric type, navigation
  clearance, simultaneous threat/impact/pressure slots, focused-control retention,
  font restoration, Compact floor and shape-distinct high-contrast focus.
- Controller-reachable research/notice scrolling, muted Large controller debrief
  and existing checkpoint reload without adding accessibility to campaign data.

The debrief integration test uses existing domain adapters for route evidence;
the native test below separately flies the entire collision-aware route through
real keyboard/controller input, without positioning or progress shortcuts.

## Native input-driven walkthrough

On an available native X11 display, from the repository root, run each pair in order:

```sh
export DISPLAY=:99
export LIBGL_ALWAYS_SOFTWARE=1
# Controller at 800x600:
godot --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/fixtures/capture_accessibility.gd
godot --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/fixtures/capture_accessibility.gd -- --continue-accessibility
# Keyboard at the 1280x800 reference size:
godot --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/fixtures/capture_accessibility.gd -- --keyboard
godot --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/fixtures/capture_accessibility.gd -- --keyboard --continue-accessibility
# Controller at 1920x1080:
godot --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/fixtures/capture_accessibility.gd -- --1080
godot --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/fixtures/capture_accessibility.gd -- --1080 --continue-accessibility
```

Use your normal display/environment for a desktop run; no dependency on Xorg is
added to the game or CI. The fixture uses isolated `user://bta043-native-<tag>.json`
settings/checkpoints. First process removes only that tag's fixture files; second
preserves them and explicitly exercises latest-backup recovery, then Continue.
It never touches the player's normal profile. Run the first command again to reset
that fixture before repeating recovery (existing rejected files are protected).

No mouse event or programmatic `grab_focus` occurs in this fixture. Actual Tab/
shoulder focus cycling, Enter/A, arrows/D-pad, Escape/B, physical key events and
joypad axis events pass through InputMap and the real menus. Waypoint steering
reads vessel position/velocity to decide input but never writes either. No direct
discovery/research/mission completion, route-stage assignment, collision bypass or
narrative flag insertion occurs.

Each first process intentionally:

1. Opens Accessibility, selects Large, enables all comfort/contrast options and
   saves; opens Audio and saves mute.
2. Opens and confirms New Expedition; reads the briefing, intentionally accepts
   the existing objectives through Begin survey and returns to piloting.
3. Flies to the plate, emits an actual ping, waits for wavefront discovery,
   intentionally starts the three-second scan and waits for completion.
4. Opens map → Research, reads/scolls the completed record, then closes both.
5. Pilots UpperGate → Cave → EastChamber → TwinSpires, pings the landmark and
   returns via ReturnTurn → LowerEast → LowerWest → BaseRise → base.
6. Docks, opens station log, intentionally debriefs (one conclusion event), scrolls,
   installs the FREE sonar upgrade, explicitly Service all and returns to piloting.
7. Opens remapping, selects sonar, captures an unused shoulder/Tab and saves.
   Controller also tries an Interact conflict first, verifies rejection and cancels.
   Restores input defaults, saves, verifies mute/Large remain, saves expedition and
   exits normally. Fresh process recovers the valid checkpoint backup, Continues,
   verifies concluded state/upgrade/preferences with zero replayed story events,
   and opens the restored log.

## Recorded results

- Pinned Godot/GUT installation: PASS.
- Headless import + **171 authored script checks** + startup smoke: PASS, no errors.
- Complete GUT: **430/430 tests passing**, **52 scripts**, **25,376 assertions**,
  **228.134 seconds**; **0 failures, 0 errors, 0 skipped**. This includes all 414
  prior tests and 16 new accessibility cases.
- Focused accessibility: **16/16**, **190 assertions**, **11.047 seconds**.
- `git diff --check`, documentation links and screenshot dimensions: PASS.


[Raw native stdout from all six successful processes](bta-043-native-trace.txt).
All six exited **0**, with no Godot errors/leaks. Mesa llvmpipe emitted the known
unsupported-VSync warning. These are **synthetic controller/keyboard events in
native graphical Godot**, not a physical-device or independent human playtest.

| Native input / resolution | Full walkthrough wall time | Active route time | Conclusion events | Fresh recovery + Continue |
| --- | ---: | ---: | ---: | --- |
| Controller / 800×600 | 67.735s | 50.733s | 1 | PASS, 0 replayed |
| Keyboard / 1280×800 | 63.088s | 43.700s | 1 | PASS, 0 replayed |
| Controller / 1920×1080 | 91.261s | 58.417s | 1 | PASS, 0 replayed |

All were muted with Large, softer sonar, disabled motes, reduced motion and high
contrast. The keyboard fixture was tuned to brake with key releases rather than
using analog steering thresholds; no game movement configuration was changed.
Actual screenshot PNG headers were checked against each requested resolution.

120 consecutive process-frame intervals were sampled during gameplay after the
scan, with Mesa 25.0.7 llvmpipe (LLVM 19.1.7, 256 bits), native X11, Dummy audio:

| Resolution | Mean ms | Median ms | p95 ms |
| --- | ---: | ---: | ---: |
| 800×600 | 24.663 | 22.630 | 40.465 |
| 1280×800 | 48.202 | 46.214 | 67.096 |
| 1920×1080 | 88.378 | 83.861 | 122.345 |

These are wall intervals in a shared cloud/software-rendering session, including
scheduling effects, not GPU timings or an isolated benchmark. They do **not** meet
or establish the target 60 FPS on a representative GPU, and provide no numerical
baseline-overhead claim. Settings/layout work is event-driven/coalesced; reduced
particles stop processing and reduced propeller motion stops idle redraws.
Physical GPU/Steam Deck performance and independent usability remain pending.

## Screenshots

Actual Godot renders; no mockups or compositing. Large + all comfort options:

| Screen | 800×600 controller | 1280×800 keyboard | 1920×1080 controller |
| --- | --- | --- | --- |
| Accessibility and visible focus | [800](bta-043-controller-800-settings.png) | [1280](bta-043-keyboard-1280-settings.png) | [1920](bta-043-controller-1920-settings.png) |
| Safe New Expedition confirmation | [800](bta-043-controller-800-confirmation.png) | [1280](bta-043-keyboard-1280-confirmation.png) | [1920](bta-043-controller-1920-confirmation.png) |
| Briefing / text scrolling | [800](bta-043-controller-800-briefing.png) | [1280](bta-043-keyboard-1280-briefing.png) | [1920](bta-043-controller-1920-briefing.png) |
| Gameplay HUD after real scan | [800](bta-043-controller-800-hud.png) | [1280](bta-043-keyboard-1280-hud.png) | [1920](bta-043-controller-1920-hud.png) |
| Completed research / text scrolling | [800](bta-043-controller-800-research.png) | [1280](bta-043-keyboard-1280-research.png) | [1920](bta-043-controller-1920-research.png) |
| Remapping and save | [800](bta-043-controller-800-remapping.png) | [1280](bta-043-keyboard-1280-remapping.png) | [1920](bta-043-controller-1920-remapping.png) |

<details><summary>Debrief and fresh-process restored log (story spoilers)</summary>

| View | 800×600 | 1280×800 | 1920×1080 |
| --- | --- | --- | --- |
| Explicit conclusion | [800](bta-043-controller-800-debrief.png) | [1280](bta-043-keyboard-1280-debrief.png) | [1920](bta-043-controller-1920-debrief.png) |
| Fresh process after backup recovery / Continue | [800](bta-043-controller-800-continued.png) | [1280](bta-043-keyboard-1280-continued.png) | [1920](bta-043-controller-1920-continued.png) |

</details>

See [manual acceptance steps, preferences/recovery contract and known limits](../accessibility.md).
