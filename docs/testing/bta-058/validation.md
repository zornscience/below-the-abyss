# BTA-058 validation

Working directory: `/workspace/below-the-abyss`. Before engine commands:

```sh
export XDG_CACHE_HOME=/workspace/.cache
export XDG_DATA_HOME=/workspace/.local/share
export XDG_CONFIG_HOME=/workspace/.config
```

| Command | Result |
| --- | --- |
| `python3 tools/lint_release_safety.py` | PASS; runtime assertions contain only allowlisted pure checks |
| `python3 -m unittest discover -s tests/python` | PASS; 10 tests |
| `CI_LOG_DIR=$PWD/build/bta058-final python3 tools/validate_godot.py` | PASS; exact Godot 4.6.3, import, 315 authored script checks and startup smoke |
| `CI_LOG_DIR=$PWD/build/bta058-final python3 tools/run_tests.py` | See final suite summary below |
| `python3 tools/verify_chapter_handoff.py` | PASS |
| `python3 tools/verify_expanded_expedition.py` | PASS |
| `python3 tools/verify_revision_two.py` | PASS |
| `python3 tools/verify_story_choice.py` | PASS |
| `python3 tools/verify_sunlit_shallows.py` | PASS |
| `python3 tools/verify_twilight_expedition.py` | PASS |
| `python3 tools/verify_twilight_habitat.py` | PASS |
| `python3 tools/verify_twilight_survey.py` | PASS |
| `python3 tools/install_export_templates.py` | PASS; official archive verified with repository-pinned SHA-512 |
| `python3 tools/build_playtest.py --allow-dirty` | PASS; actual Linux release export and package; build digest in logs/linux-export.json |
| `git diff --check` | PASS |

Focused test command (5 passed, 75 assertions):

```sh
godot --headless --path . --script res://addons/gut/gut_cmdln.gd \
  -gexit -gdisable_colors -gconfig= \
  -gtest=res://tests/integration/test_twilight_action_costs.gd,res://tests/unit/test_action_cost_profile.gd \
  -gjunit_xml_file=res://build/ci-logs/bta058-target.xml
```

The first full suite also passed 750 tests. Final results below are from the
completed files, not a prior report. No existing assertions were loosened and no
timeouts were raised. Routes ran with at most two concurrent route runners.

Export smoke, using the package in `logs/linux-export.json`:

```sh
python3 tools/smoke_playtest.py "$package" --log build/playtest/positive058-final.log
python3 tools/smoke_playtest.py "$package" --log build/playtest/resource-negative058-final.log --break-resource-wiring
python3 tools/smoke_playtest.py "$package" --log build/playtest/visibility-negative058-final.log --break-visibility-wiring
python3 tools/smoke_playtest.py "$package" --log build/playtest/registration-negative058-final.log --break-registration-wiring
```

Positive case: exit 0, registration/resource/visibility pass tokens, default
telemetry OFF. Each negative case: expected exit 1, and corresponding
`RELEASE_RESOURCE_WIRING_FAIL`, `RELEASE_VISIBILITY_WIRING_FAIL`, or
`RELEASE_REGISTRATION_WIRING_FAIL`. These are expected negative outcomes, not
ordinary passing tests. Logs are committed alongside this record.

Native capture (Xvfb :99, software Mesa llvmpipe, not headless Godot rendering):

```sh
DISPLAY=:99 BTA_EVIDENCE_DIR=$PWD/docs/testing/bta-058 \
  godot --path . --audio-driver Dummy --rendering-method gl_compatibility \
  --script res://tests/fixtures/capture_twilight_resources.gd
```

PASS `BTA058_CAPTURE_PASS`; PNG dimensions independently checked as 1280×800 and
800×600 and both images visually inspected. Xvfb was extracted outside the checkout
from a Debian package obtained using signed APT repository metadata; system sudo
was unavailable. Renderer VSync support warning is recorded in the capture log.

## Final suite summary

```text
PASS: tests=752, passed=752, failures=0, errors=0, skipped=0
```
