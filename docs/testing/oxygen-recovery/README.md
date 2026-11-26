# Oxygen exhaustion and Halcyon recovery: evidence

Designer decisions approved on 2026-11-15. They supersede §6 of
`docs/investigations/oxygen-exhaustion.md` and the BTA-059 ascent-tether respawn.
**No human playtest of this change exists.** Everything below is automated evidence from a Linux
container with no GPU (headless debug binary, software GL for screenshots).

## Behaviour

| Situation | What happens |
| --- | --- |
| Oxygen reaches 0 (Sunlit or Twilight) | A 60 s life-support countdown starts. It runs on simulation time and freezes whenever the simulation pauses (pause menu, map, station, dialogs, title). The vessel can still move. |
| During the countdown | Red screen border and the line `OXYGEN DEPLETED, LIFE SUPPORT 0:42`. The last 10 s read `LIFE SUPPORT CRITICAL`. The existing oxygen alarm cue sounds at 0 and at 10 s left. |
| Oxygen rises above 0 (Halcyon dock service or Twilight tether refit) | The countdown cancels and the border clears. |
| Countdown expires, or hull is destroyed (either chapter) | Fade to black and a text card. The recovery checkpoint is written at once through the atomic checkpoint path. |
| Card input | Accept (Enter, Space or A) is ignored until the 0.5 s fade has finished plus 0.5 s. A held key or button, and key-repeat echoes, never confirm it. A fresh press is needed. The footer reads `Enter / A: continue`. Escape and B do nothing. |
| Card confirmed (Enter or A) | Sunlit: piloting resumes at the Halcyon berth. Twilight: the Halcyon refit page opens, via the same refit transfer as a voluntary tether return. |
| Recovery restock | Free and full: hull, battery, oxygen and torpedoes return to maximum. Records, discoveries and choices are kept. The unfinished scan is cancelled. In Twilight the mission completes exactly as on a voluntary tether return. |
| Continue from a checkpoint with oxygen 0 | No instant failure. The full 60 s countdown restarts when piloting resumes. |
| Continue from a BTA-059 hull-0 checkpoint | Recovery runs on Continue. |

Card text (oxygen): "LIFE SUPPORT FAILED. Oxygen ran out. Wick sent a distress beacon and Halcyon’s
crew recovered Lantern-2. Hull, battery, oxygen and torpedoes are restored. The unfinished scan was
cancelled. All records, discoveries and choices are kept." Button: "Continue at Halcyon".

Hull variant (new text, for review): "HULL FAILURE." then the existing cause sentence
("Pressure exceeded the hull rating.", "A collision depleted hull integrity.", "Thermal vent exposure
depleted hull integrity." or "Hull integrity was depleted."), then the same closing sentences.

Border presentation:

| Mode | Border |
| --- | --- |
| Default | 10 px, opacity pulses between 60% and 100%. 0.5 pulses per second until 20 s remain, then a linear rise to 1.5 per second at 0. Hard cap 2 per second. The pulse freezes while paused. |
| Reduced flashing | Static, fully opaque. Width grows from 6 px at 60 s to 24 px at 0. |
| High contrast | Brighter red (`#ff5050` instead of `#d01f1f`), 4 px thicker, white 2 px inner edge. |

Interpretation note: "ramps from 0.5 Hz at 60 s to 1.5 Hz over the last 20 s" was implemented as a
constant 0.5 Hz from 60 s to 20 s, then a linear ramp to 1.5 Hz at 0 s.

## Endurance (full to empty at normal travel, `--fixed-fps 60`)

Re-run of `tests/fixtures/measure_oxygen_endurance.gd` on this branch: real `main.tscn`, real input at
full stick deflection on an open-water patrol, measured until oxygen reads 0. Simulated play time is
what a player experiences while the simulation runs. Pauses and menus freeze the drain, so session
time to empty is longer.

| Region | Drain (per s) | Physics frames | Simulated play time to empty | Wall clock (accelerated) | Battery at that moment | Hull |
| --- | --- | --- | --- | --- | --- | --- |
| Sunlit | 0.048 (was 0.03) | 125,000 | **2,083.33 s (34.7 min)** (was 55.6 min) | 378.7 s | 37.5 (was 0.052) | 100 |
| Twilight | 0.03 (was 0.02) | 200,000 | **3,333.33 s (55.6 min)** (was 83.3 min) | 704.4 s | 60.0 (was 40.0) | 100 |

Both runs: 100% full-thrust frames, zero paused frames, `OXYGEN_ENDURANCE_PASS`. Against the targets:
Sunlit's 15 to 20 min expedition target is still exceeded by about 1.7 to 2.3 times, and Twilight's
unverified 30 to 45 min novice target by about 1.2 to 1.9 times. In Sunlit, battery now outlasts
oxygen at continuous full thrust (before the retune, both ran out together).

Consequence of the retune: a 45-minute Twilight run now ends with 19 oxygen. The BTA-058 budget test
required at least 25. That assertion was rewritten to the exact new value (see below).

## Screenshots

Native captures (`tests/fixtures/capture_oxygen_warning.gd`, xvfb, `gl_compatibility`, software GL),
all at 0:42 remaining in the Sunlit chapter:

| Mode | 1280x800 | 800x600 |
| --- | --- | --- |
| Default | `oxygen-border-default-1280x800.png` | `oxygen-border-default-800x600.png` |
| Reduced flashing | `oxygen-border-reduced-flashing-1280x800.png` | `oxygen-border-reduced-flashing-800x600.png` |
| High contrast | `oxygen-border-high-contrast-1280x800.png` | `oxygen-border-high-contrast-800x600.png` |
| Recovery card | `recovery-card-1280x800.png` | `recovery-card-800x600.png` |

A still image cannot show the pulse or the thickening. Those are covered by the timing tests below.

## Commands and results

All run in this container on Godot 4.6.3 (checksummed), GUT 9.6.1 at the pinned commit. One Godot job at a time.

```sh
export GODOT_BIN=/path/to/Godot_v4.6.3-stable_linux.x86_64
$GODOT_BIN --headless --path . --editor --import --quit
python3 tools/lint_release_safety.py
python3 -m unittest discover -s tests/python
python3 tools/validate_godot.py
python3 tools/run_tests.py
python3 tools/verify_depth_gate.py   # and every verify_* script in the CI workflow
python3 tools/build_playtest.py --allow-dirty
python3 tools/smoke_playtest.py build/below-the-abyss-playtest-linux-*.zip --log /tmp/smoke.log
python3 tools/smoke_playtest.py build/below-the-abyss-playtest-linux-*.zip --log /tmp/neg.log --break-oxygen-wiring   # must FAIL
$GODOT_BIN --headless --path . --fixed-fps 60 --script res://tests/fixtures/measure_oxygen_endurance.gd -- sunlit
$GODOT_BIN --headless --path . --fixed-fps 60 --script res://tests/fixtures/measure_oxygen_endurance.gd -- twilight
BTA_EVIDENCE_DIR=$PWD/docs/testing/oxygen-recovery xvfb-run -a $GODOT_BIN --path . --rendering-method gl_compatibility --script res://tests/fixtures/capture_oxygen_warning.gd
```

| Check | Result |
| --- | --- |
| `tools/lint_release_safety.py` | PASS (no side effects in asserts) |
| `python3 -m unittest discover -s tests/python` | 10 tests OK |
| `tools/validate_godot.py` | PASS: import, 359 script checks, startup smoke |
| `tools/run_tests.py` (full GUT) | **828/828 pass**, 0 failures (`main` baseline in the same container: 803/803) |
| `test_tether_refit_checkpoint` on `main` before the extraction, then after | Goldens recorded on 93b6070, byte-identical after (2/2) |
| CI `verify_*` routes (9) + `verify_depth_gate` | 10/10 PASS. Run on the revision before the final text-placement fix and comment-only edits. CI reruns all of them. |
| `build_playtest.py` + `smoke_playtest.py` (real Linux export) | PASS, including `RELEASE_OXYGEN_WIRING_PASS` and `RELEASE_DEPTH_GATE_PASS` |
| 20 `--break-*-wiring` negatives | 20/20 fail as required with their own token. `--break-oxygen-wiring` gives `RELEASE_OXYGEN_WIRING_FAIL countdown`. |
| Endurance fixture, both regions, `--fixed-fps 60` | `OXYGEN_ENDURANCE_PASS` twice (table above) |
| Screenshot fixture | `OXYGEN_CAPTURE_PASS`, 8 PNGs |

Long waits in the integration tests run the real physics driver with `Engine.time_scale = 8` and
measure the simulation time actually applied (a probe node sums the physics delta while the vessel
simulates). The authored 60 s grace is used throughout. Pause, cancel and presentation checks run
at normal speed.

## Manual playtest steps (not yet run by a person)

These are developer verification steps. The script for an outside playtest is
`docs/playtesting/recovery_playtest.md`.

1. `godot --path .`, New Expedition, launch the Sunlit chapter. Pause, open Accessibility, keep defaults.
2. Wait out the drain (about 35 min of Sunlit simulation time at full travel). Confirm the border,
   the text line under the oxygen gauge and the alarm at 0.
3. Press Escape (keyboard) or Start (controller). The countdown text must stop changing and the
   border must stop pulsing. Resume and confirm it continues.
4. Dock at Halcyon with E or A before 0:00. The border must clear and no recovery may follow.
5. Let it reach 0:00 again. Confirm the alarm at 0:10, the CRITICAL wording, the fade and the card.
   Press Enter or A at once (ignored for about a second), then Escape or B (nothing happens), then
   Enter or A again. You are at the Halcyon berth, full supplies.
6. Repeat 2 to 5 in Twilight. The card leads to the Halcyon refit page. Resume the expedition.
7. Repeat with Reduced flashing (static border that thickens) and High contrast (brighter border,
   white inner edge). Check 1280x800 and 800x600.
8. Destroy the hull (for example by lingering below the depth rating). The same card appears with the
   HULL FAILURE text and recovery follows.
9. Quit while the card is open, relaunch and Continue. You resume at Halcyon with full supplies.

## Known limitations

- **No human playtest exists.** Nobody has checked whether players notice the border, understand the
  card or find 60 s fair.
- **Recovery has no penalty** beyond the vessel's position and the cancelled scan. It is a free full
  restock by design. In Twilight it also lands on the refit page, where service is free anyway.
- With a 60 s grace, cancelling by refit is only practical within about a minute of Halcyon or the
  ascent tether. Most depletions will end in recovery.
- Continue always restarts the full 60 s. A checkpoint holding zero oxygen (written by the old
  BTA-059 respawn, or a Twilight sentinel decision taken at zero oxygen) gives a fresh countdown on
  every load.
- The alarm reuses the existing oxygen cue and the mixer's rules: a 12 s cue cooldown, mute and
  volume, and no overlap with another alarm. It can therefore be silent at 0 or at 10 s, for example
  when the hull alarm is playing. The border and text are always shown.
- The drain retune edits shared Resources. `prototype_resources.tres` also drives the legacy
  prototype phase, and `twilight_resources.tres` also drives the combat test box. Their oxygen drain
  changed too. Neither has the countdown or recovery: zero oxygen there stays inert, as before.
- If the recovery checkpoint cannot be written (a corrupt or unwritable save), the card stays and
  offers a retry. The card holds input, so the pause menu's backup recovery is not reachable from
  it. The BTA-059 respawn panel had the same limitation.
- The pending Twilight casualty retry before recovery is covered by code review only, not by a test.
- The pulse phase advances on frame time while its rate follows simulation time. Measured at or
  below 2 pulses per second in tests. Not measured on a real display or GPU.
- The hull-failure card wording ("HULL FAILURE." plus the existing cause sentence) is new text and
  needs designer review.
- Screenshots use software GL in a container. No GPU, Steam Deck, Windows or macOS evidence.
