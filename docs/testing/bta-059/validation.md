# BTA-059 validation

Working directory `/workspace/below-the-abyss`; engine 4.6.3 standard, pinned GUT 9.6.1.

```sh
export XDG_CACHE_HOME=/workspace/.cache
export XDG_DATA_HOME=/workspace/.local/share
export XDG_CONFIG_HOME=/workspace/.config
```

| Command | Outcome |
| --- | --- |
| `python3 tools/lint_release_safety.py` | PASS; no side effects in runtime assertions |
| `python3 -m unittest discover -s tests/python` | PASS; 10 tests |
| `CI_LOG_DIR=$PWD/build/bta059-final python3 tools/validate_godot.py` | PASS; import, 321 authored script checks, exact version, startup smoke |
| `CI_LOG_DIR=$PWD/build/bta059-final python3 tools/run_tests.py` | Final summary below |
| `python3 tools/verify_depth_gate.py` | Current route log below: actual-input approach/crossing, lower/gate ranks, lingering and durable hull-only respawn |
| `python3 tools/build_playtest.py --allow-dirty` | PASS; real Linux release export, checksum-verified pinned templates, package/digest in logs/linux-export.json |
| `git diff --check` | PASS |

Focused tests (6 passed, 130 assertions; current results in logs/focused-tests.txt):

```sh
godot --headless --path . --script res://addons/gut/gut_cmdln.gd \
  -gexit -gdisable_colors -gconfig= \
  -gtest=res://tests/unit/test_twilight_depth_gate.gd,res://tests/integration/test_depth_respawn.gd \
  -gjunit_xml_file=res://build/ci-logs/bta059-target.xml
```

They verify per-rank pressure, old-save/new-safe-subject XP, actual checkpointed
zero-hull Continue/respawn, registered reachable subjects/optional mission status,
and actual keyboard/gamepad cancel/confirm events. UI events are flushed and awaited
on process frames, rather than assuming physics ticks flush UI input.

Existing route commands (full current logs and result summary alongside this file):

```sh
python3 tools/verify_chapter_handoff.py
python3 tools/verify_expanded_expedition.py
python3 tools/verify_revision_two.py
python3 tools/verify_story_choice.py
python3 tools/verify_sunlit_shallows.py
python3 tools/verify_twilight_expedition.py
python3 tools/verify_twilight_habitat.py
python3 tools/verify_twilight_survey.py
```

No existing assertions were removed or changed to inequality tolerances, and no
timeout was raised. Two expectations were updated for authorized new content:
exact total study count 10→17, and the habitat fixture's eligible discovery IDs now
include the seven new optional studies. Its exact membership assertions and checks
that research/missions/upgrades remain unchanged are retained. The first run exposed
these stale content expectations; the habitat run then exhausted its existing timeout
after the assertion stopped its coroutine. This was not fixed by increasing timeouts.

Real-export smoke commands use the package path in `logs/linux-export.json`:

```sh
python3 tools/smoke_playtest.py "$package" --log build/playtest/positive059-final.log
python3 tools/smoke_playtest.py "$package" --log build/playtest/depth-rating059-final.log --break-depth-rating-wiring
python3 tools/smoke_playtest.py "$package" --log build/playtest/depth-section059-final.log --break-depth-section-wiring
python3 tools/smoke_playtest.py "$package" --log build/playtest/failure059-final.log --break-failure-wiring
python3 tools/smoke_playtest.py "$package" --log build/playtest/resource059-final.log --break-resource-wiring
python3 tools/smoke_playtest.py "$package" --log build/playtest/visibility059-final.log --break-visibility-wiring
python3 tools/smoke_playtest.py "$package" --log build/playtest/registration059-final.log --break-registration-wiring
```

Positive: exit 0 and all four expected pass tokens (registration, resource,
visibility and depth gate), default telemetry off. Each negative: expected exit 1
and its corresponding `RELEASE_*_WIRING_FAIL` marker, not merely an arbitrary failure.
The three new negative cases reset the real applied rating, disable real layout
registration, or disconnect the actual hull-destruction signal. CI retains the logs.

Native capture, Xvfb :99 and Mesa llvmpipe:

```sh
DISPLAY=:99 BTA_EVIDENCE_DIR=$PWD/docs/testing/bta-059 \
  godot --path . --audio-driver Dummy --rendering-method gl_compatibility \
  --script res://tests/fixtures/capture_depth_gate.gd
```

PASS `BTA059_CAPTURE_PASS`; eight PNG dimensions independently checked. Warning,
stress, basin and failure images visually inspected, including the centered small
panel and unwrapped footer. Whole-process capture samples were 153.353/381.923 ms
and physics samples 5.395/0.285 ms (1280×800 / 800×600). These are snapshots during
software rendering, synchronous screenshots, paused failure and concurrent tests,
not an isolated adapter benchmark or target-GPU frame-time claim. The renderer's
unsupported-VSync warning is retained; no gameplay errors in the final capture.

Final GUT: 758 tests passed, 0 failures, errors or skips. All eight existing route tools passed after the habitat whitelist correction; the new depth route also passed. See logs/final-test-summary.txt and logs/route-results.txt.
