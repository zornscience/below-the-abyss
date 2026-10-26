# BTA-041 verification and listening review

## Reproduce

Pinned Godot **4.6.3.stable.official.7d41c59c4**, GUT **9.6.1**. From the repository:

```sh
# Managed cloud only; desktop users can use their normal Godot directories.
export XDG_CACHE_HOME=/workspace/.cache
export XDG_DATA_HOME=/workspace/.local/share
export XDG_CONFIG_HOME=/workspace/.config
python3 tools/install_gut.py
python3 tools/validate_godot.py
python3 tools/run_tests.py
# Rebuild original audio with no third-party library:
python3 tools/synthesize_audio.py
godot --headless --path . --editor --import
godot --path .
```

Focused audio tests:

```sh
godot --headless --path . --script res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_soundscape.gd,res://tests/integration/test_gameplay_audio.gd -gexit -gdisable_colors
```

The unchanged Actions workflow runs the installer, validator and full suite on PRs
into main and pushes to main, preserving version/import/parser/startup logs, GUT
output and JUnit in its 14-day artifact. No test is disabled or relaxed.

## Recorded automated results

- Engine/import/parser/startup validator: **PASS**, exact Godot version above,
  **157 authored script checks**, no Godot errors.
- Complete local GUT run before the final shared-alarm gate: **391/391 passing**, **48 scripts**, **24,956 assertions**,
  **194.613 seconds**, **0 failures / 0 errors / 0 skipped**.
- Final focused audio verification including the shared resource/predator alarm gate:
  **22/22 passing**, **209 assertions**, **3.529 seconds**, no Godot errors.
- Final 60-iteration headless startup: exit 0, no errors/leaks.
- Existing actionlint check and `git diff --check`: pass.
- `tools/synthesize_audio.py`: all **26 source WAVs byte-for-byte reproducible** on
  this Python host; checked against the source provenance SHA-256 values.

The PR records the hosted Actions run, exact head and final status after push;
its artifact retains the authoritative complete-suite result for that commit.

## Native evidence

Run the two commands in order on a working X11 display (use your real display on a
desktop). The first clears only its isolated **bta041-native** fixture profile;
the second reuses it in a fresh Godot process. Neither writes canonical user saves.

```sh
DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 godot --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/fixtures/capture_soundscape.gd
DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 godot --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/fixtures/capture_soundscape.gd -- --resume-audio
```

This is actual input-driven piloting through existing RouteMarkers, not a staged
vessel teleport. It begins an expedition, approaches the plate, pings, waits for
wavefront discovery, intentionally scans, passes the investigating harmless observer,
flies into the optional predator area, waits through warning into pursuit, retreats
to the safe main passage, visits Twin Spires, returns via the lower passage, explicitly
services at station, saves, exits, and continues in another process. The resource
warning portion is **an explicit test-only API exercise** after return: consume
battery/oxygen down to 18 and apply 82 hull damage with `audio-verification` source.
It does not claim those values arose naturally during the short expedition.

The [retained native stdout trace](bta-041-native-trace.txt) records the actual
accepted cue/bus sequence. Actual results: first process accepted **37 cues**, including ping, legitimate echo,
mechanical/geological/unknown passive events, biological observer reaction, scan
activation/completion, predator warning/pursuit/retreat, all three resource alarms,
docking, successful service and UI focus. Existing route completed in **51.0 seconds
of active piloting**; additional scan/threat/menu/warning review time is separate.
Fresh-process Continue restored research and completed route with **no ping or
research-completion replay**. Both native commands exited 0 with no Godot errors;
X11 llvmpipe emitted its known unsupported-VSync warning.

A real Godot `AudioEffectRecord` on Master captured this
[sonar + wavefront echo + scan mix](bta-041-sonar-scan-mix.wav), not a manually
assembled audio illustration: **4.830 s, 44100 Hz, stereo 16-bit PCM**, peak
**−10.08 dBFS**, RMS **−26.00 dBFS**, **zero clipped PCM samples**. It includes the
real active ping/echo and scan activation/progress/completion over the existing
atmosphere. See [source provenance](../../assets/audio-provenance.csv) for the
26 original 22050 Hz mono source WAVs; the stereo file is documentation evidence
of their native Godot mix and shares the project's pending licensing decision.
A nonzero recorded mix verifies the playback path, **not subjective listening**.

Native screenshots (Godot X11/GL compatibility, Mesa llvmpipe):

| View | Evidence |
| --- | --- |
| Independent audio controls / keyboard focus | [1280x800](bta-041-audio-settings.png) |
| Compact focus-following scroll panel | [800x600](bta-041-audio-compact.png) |
| Completed real scan | [Research feedback](bta-041-research.png) |
| Harmless investigation | [Observer](bta-041-observer.png) |
| Warning before aggression | [Warning](bta-041-warning.png) |
| Real pursuit | [Pursuit](bta-041-pursuit.png) |
| Escapable return to main passage | [Retreat](bta-041-retreat.png) |
| Low pools retain visible text | [Resource warnings](bta-041-resource-warnings.png) |
| Explicit refill/repair after expedition | [Station service](bta-041-station.png) |
| Second-process restored expedition | [Continue](bta-041-continued.png) |

## Manual listening and controller walkthrough

1. Launch `godot --path .`. Open **Audio settings** from the start/pause menu.
   Navigate all five sliders, mute, Save and Return using arrows/Tab/Enter, then
   D-pad/stick/A. Left/right changes 5%. Check the selected-slider ▶ label, button focus outline and focus-
   following scroll at 800x600. Preview, cancel, and confirm saved values survive a
   real quit/relaunch. Master zero/mute must silence everything; individual zero
   sliders must silence just their category. Music has no authored stream.
2. Begin/Continue and thrust in all directions. Listen for quiet machinery that
   rises with input and settles when released. Menu/station entry should fade the
   machinery/ambience down, without advancing resource or creature clocks.
3. Approach the calibration plate `(760,480)`. Press remapped sonar (F/controller X).
   Hear one strong ping only for successful requests. Echo audio/visual feedback
   must wait for actual wavefront arrival; failed energy/cooldown must stay silent.
   Passive classes should be soft, sparse and match the visible contact list.
4. Interact (E/A) outside the docking radius to intentionally scan the discovered
   plate. Compare scanner percentage/activation/progress/completion audio. Move out
   of range or cancel to stop it; pause/resume must not finish the scan. Repeat on
   a completed subject: no second research/completion cue or record.
5. Follow UpperGate toward `(1450,400)`. Ping near the observer to hear its curious
   reaction with visible INVESTIGATE; passive listening alone must not cause it.
   Continue the normal Cave → Twin Spires route. Ambient layers should change
   gradually with depth and leave useful quiet between events.
6. Optional: from the east chamber approach `(3060,390)` in the marked threat fork.
   Ping, read/hear WARNING, then wait for PURSUIT. Retreat down beyond Y=460 to the
   main passage. Compare the threat fade/retreat cue to SAFE/DISENGAGING. No sudden
   volume spike or permanent pursuit. The original route needs no encounter.
7. Optional pressure trench: descend X=2880–3280 below 300 m (below 400 m if hull
   upgraded), observe grace then pressure damage/creaks; ascend. A severe wall hit
   should produce a bounded impact cue; jitter must not repeatedly rattle alarms.
8. To review low warnings efficiently, use the separately enabled development
   resource panel (`godot --path . -- --debug-controls`) and intentionally deplete
   test supplies, then Return to piloting. Hull, oxygen, battery alarms are spaced
   and occur once per low episode. **! LOW / RETURN**, numbers/bars and DEPLETED
   remain readable. Refill above 25% to rearm; do not expect a constant alarm loop.
9. Return to base, slow down and Interact. Passing through base alone never refills.
   Explicitly perform repair/refill and compare before/after + service cue. Close,
   safely pause/Save, quit, relaunch and Continue. Audio preferences and permanent
   research/discovery/mission/upgrade records survive. No phantom ping, scan or
   reward acknowledgement plays during restoration. Restart Test Route remains a
   distinct temporary reset, preserving settings and permanent progress.
10. Repeat with **Mute all sound**, including map/research/station/controller flows.
    Every critical state must remain understandable through instruments and text.
    Evaluate on headphones and small speakers at comfortable output levels: loop
    seams, repetition, fatigue, sonar prominence, warning clarity and relative
    loudness need human approval. Avoid treating numerical level checks as mastering.

## Coverage, performance and limits

The new 22 focused tests cover bus routing/imported forward loops, independent
persistent settings/legacy files/invalid data, safe missing streams, hard voice
limits/rate suppression, mute, class mapping, fade/crossfade/duck behavior, actual
ping/echo gating, no recursive acoustics, passive snapshot deduplication, scanner
completion, alarms/visual equivalents, real threat transitions, station operations,
checkpoint/restart compatibility, and keyboard/controller preview/save/cancel/error.
Existing full suites cover unchanged domain rules, history capacity, saves, real
route piloting, physical collisions and 30/60/120-step simulation consistency.

Measured native 1280x800 process-frame intervals over 180 samples: first walkthrough
median **31.947 ms**, p95 **57.083 ms** with regression tests also running; fresh-process
Continue median **31.303 ms**, p95 **57.704 ms** without that test process. This is
software rendering, not a modest desktop GPU; **stable 60 FPS is not established**.
A final screenshot refresh while tests ran observed 37.537 / 109.180 ms, illustrating
the VM variance. These are whole-frame observations, not isolated audio CPU timings or a controlled
before/after performance comparison. The previous art milestone measured 800x600,
so its numbers are not directly comparable. The bounded mixer architecture avoids
runtime synthesis and unbounded player creation, but hardware profiling remains due.

No audible physical device is available in this environment. No subjective listening,
professional mastering, physical-controller ergonomics, Windows/macOS audio runtime,
long-session listening fatigue or external player approval is claimed. Centered
contact sounds deliberately avoid implying precise directional sensing. No final
music, recordings, voices, reverb/occlusion simulation or new gameplay mechanic is
included. Visual instructional sign overlap predates this milestone.
