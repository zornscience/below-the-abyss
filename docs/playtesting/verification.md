# BTA-044 implementation verification

**No external study has run. Human participants evaluated: 0.** The checked-in
results_template.json remains empty. Synthetic unit/native fixtures are test data,
not fabricated human responses. Five unfamiliar people and evaluated feedback are
still required before BTA-044 external acceptance can be completed.

BTA-043 PR #24 was confirmed merged before branching from
`89e0bb2ac53a15e8b062971cafb8d5c94484682b` to `bta-044-external-playtesting`.

## Commands and automated coverage

Repository root, Godot 4.6.3.stable.official.7d41c59c4, pinned GUT 9.6.1:

```sh
export XDG_CACHE_HOME=/workspace/.cache
export XDG_DATA_HOME=/workspace/.local/share
export XDG_CONFIG_HOME=/workspace/.config
python3 tools/install_gut.py
python3 tools/validate_godot.py
python3 tools/run_tests.py
python3 -m unittest discover -s tests/python -v
# New GDScript cases only:
godot --headless --path . --script res://addons/gut/gut_cmdln.gd -gexit -gdisable_colors -gconfig= -gtest=res://tests/unit/test_playtest_recorder.gd,res://tests/integration/test_playtest_observer.gd
```

Recorded local results:

- Headless import + **179 authored script checks** + startup smoke: PASS.
- Complete GUT: **444/444**, **54 scripts**, **25,499 assertions**, **277.995 seconds**,
  no failures/errors/skips. All 430 prior cases retained, plus 14 new cases.
- Focused new GUT: **14/14**, **122 assertions**, **4.154 seconds**.
- Python analysis: **5/5 passing** synthetic-data cases.
- `git diff --check`: PASS.

Tests cover off-by-default/no-file behavior, opt-in, random sessions/build IDs,
bounded counters/history/dedup, 30/60/120-step exact clocks, completion idempotence,
privacy/strict invalid fields, JSON/text/backup roundtrip, corrupted primary
preservation, actual domain signal counts, silent Continue/restart, campaign/acoustic
non-mutation, repeated base returns, depletion/damage episodes and controller consent/
disable/export/back. A binary Resource roundtrip checks that both existing creature
hearing configurations retain their authored values through export.

The original GitHub validation job still runs pinned installation, import/parser/
smoke and the whole GUT suite; it also tests the Python analysis tool. A dependent
Linux package job installs checksum-pinned official templates, exports a clean
release, extracts and smoke-tests it with isolated data and retains package/manifest/
logs for 14 days. The PR records the actual final run/head/artifact result. A
workflow archive is a review/distribution artifact, not an automatic public release
or an invitation sent to participants.

## Standalone package and export fix

```sh
python3 tools/install_export_templates.py
python3 tools/build_playtest.py
python3 tools/smoke_playtest.py build/below-the-abyss-playtest-linux-<build-id>.zip --log build/playtest/standalone-smoke.log
```

Initial development export used `--allow-dirty`; final clean export uses its exact
committed build ID. The PR records the final package manifest/checksum. The binary
is an embedded-PCK Linux x86_64 executable, approximately 70 MiB, and the package
approximately 28 MiB. It is kept in ignored build/, not committed as a binary.
The package includes participant instructions, questionnaire, report disclosure and
official Godot engine/third-party copyright notices from tag 4.6.3-stable.

The first true export smoke detected a pre-existing difference from source execution:
CreatureProfile's nested default hearing Resource became null after binary resource
conversion. Both authored creature .tres files now explicitly serialize **the same**
hearing types, ranges (observer 650, predator 500) and minimum strength 0.2. This is an
export serialization fix, with no AI, navigation, perception or balance change.
The new binary roundtrip regression test and actual release launch verify it.

PASS: package inventory and executable SHA256, extract to a temporary directory,
launch **the release executable directly** with no source/editor reference,
`--headless --quit-after 60`, isolated XDG data and recording OFF/no telemetry file.
PASS: the extracted release executable also launched normally on native X11 at
1280×800 and quit after 60 iterations without engine errors. Development mode and
Restart Test Route are hidden/disabled in the playtest feature; --debug-controls
cannot re-enable them. Godot/GUT test fixtures and movement/example fixtures are
excluded from the package. A ResourceLoader.exists probe from outside the source
directory confirmed playtest=true, fixtures=false, GUT=false.

## Full exported-content chapter and report

The exported release's embedded resource pack was exercised by the pinned standard
Godot runtime with an **external** synthetic controller driver. This loads packaged
resources rather than source assets. The driver is excluded from the player package;
ordinary release templates do not expose the editor's --script test entry point.
The full injected walkthrough is therefore distinct from the separately verified
direct standalone-binary launches above. No physical controller/human is claimed.

With an existing X11 display, reproduce from **outside the source directory**
(to avoid filesystem fallback masking an export omission):

```sh
cd /tmp
export XDG_CACHE_HOME=/workspace/.cache XDG_DATA_HOME=/workspace/.local/share XDG_CONFIG_HOME=/workspace/.config
export DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1
export BTA_EVIDENCE_DIR=/workspace/below-the-abyss/docs/playtesting/evidence
export BTA_SYNTHETIC_REPORT=/workspace/below-the-abyss/tests/fixtures/playtesting/synthetic_native_session.json
godot --main-pack /workspace/below-the-abyss/build/playtest/below-the-abyss.x86_64 --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script /workspace/below-the-abyss/tests/fixtures/capture_playtest.gd
godot --main-pack /workspace/below-the-abyss/build/playtest/below-the-abyss.x86_64 --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script /workspace/below-the-abyss/tests/fixtures/capture_playtest.gd -- --continue-accessibility
# Headless bundle exclusion probe; no participant profile changes:
godot --headless --main-pack /workspace/below-the-abyss/build/playtest/below-the-abyss.x86_64 --script /workspace/below-the-abyss/tests/fixtures/capture_playtest.gd -- --probe-only
```

First process resets only bta044-native controller fixture profiles, opens consent
with Return initially focused, intentionally starts recording, saves Large/reduced/
contrast/mute, starts a fresh expedition, reads/accepts the briefing objectives,
flies through existing collision-aware waypoints, pings/scans, opens map/research,
reaches the landmark, returns, docks/debriefs, installs the free sonar upgrade,
services, remaps/restores controls, explicitly saves and disables recording/export.
It uses joypad button/axis events through real focus and InputMap, with no mouse,
programmatic focus grabs, vessel pose/velocity writes or inserted progression flags.
Second process explicitly recovers the fixture backup and Continues, preserving
progress while recording remains OFF and no narrative events replay. The evidence
profiles are separate from normal player data. Re-run the first command before
repeating recovery, because rejected-file preservation intentionally blocks reuse.

[Retained native trace](evidence/native-trace.txt). Recorded development build
`a28d1a15b3a8a40dd7e3410b9ec44a38bb6ec9e6` (manifest explicitly dirty):

- Full driver wall time **78.816 seconds**, active route telemetry **55.733 seconds**.
- Local report **60.548 active seconds**, **17.391 menu seconds**; session-window
  chapter completion at **71.163 seconds**. Different clocks/windows are intentional.
- **2 pings, 1 started/completed scan, 2 discoveries, 2 accepted/completed/claimed
  missions, 1 base return, 1 chapter conclusion**. No damage/failure/error in this
  safe-route run. Dedicated unit cases exercise those counters separately.
- Fresh recovery/Continue: concluded chapter, upgrade, Large and mute preserved,
  **0 replayed story events**, recording OFF with no automatic new session.
- Separate orderly-tree-exit probe: exactly one quit event, incomplete outcome kept,
  validated final report. Interrupted active-checkpoint handling is tested separately.
- Empty results analysis: **0 participants**, unknown percentages/median remain null.
  Analysis of the [clearly synthetic native report](../../tests/fixtures/playtesting/synthetic_native_session.json)
  plus empty feedback: **0 participants, 1 session**, sonar distribution [2].
  This report is NOT human research evidence.

Actual Godot renders of the exported content:

- [Consent page, recording OFF and Return focused](evidence/bta-044-consent.png)
- [HUD after actual scan, Large/muted/reduced effects](evidence/bta-044-hud.png)
- [Restored log (story spoilers)](evidence/bta-044-continued.png)

## Performance and remaining limits

Shared managed Linux environment: Debian 13, x86_64, exposed Intel Xeon Platinum
8573C / 5 vCPUs, Xorg :99, OpenGL Compatibility, Mesa 25.0.7 llvmpipe LLVM 19.1.7
software rendering, 1280×800, Dummy audio, Large/contrast/reduced effects, gameplay
while listening to ambient sources after a scan. The driver sampled 120 process-frame
wall intervals: **mean 66.795 ms, median 55.473 ms, p95 119.730 ms**. Other validation
work shared this environment. These are scheduling-inclusive runtime intervals, not
GPU timings, a gaming-PC minimum, an overhead comparison or proof of 60 FPS. Target
GPU/physical-controller/Steam Deck/Windows/macOS testing remains unperformed.
Mesa emitted its known unsupported-VSync warning; successful recorded runs had no
Godot errors/leaks. The developer-injected chapter is much faster than an unfamiliar
human session and establishes neither the 20–40-minute pacing target nor usability.

The local package and CI artifact have a limited review purpose/retention. No signing,
public hosting, participant recruitment, automatic transmission, crash stack capture
or actual feedback evaluation is implemented or claimed. Force-kill data can lose
15 seconds; corruption/temp/quota errors deliberately preserve files and can require
manual handling. A deliberate manual human protocol is still required. Use the
spoiler-free guide rather than this developer verification when recruiting.
