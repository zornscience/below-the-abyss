# BTA-060 commands and evidence

Working directory: `/workspace/below-the-abyss`. Environment before engine commands:

```sh
export XDG_CACHE_HOME=/workspace/.cache
export XDG_DATA_HOME=/workspace/.local/share
export XDG_CONFIG_HOME=/workspace/.config
```

| Command | Result |
| --- | --- |
| `python3 tools/lint_release_safety.py` | PASS; runtime assertions contain only allowlisted pure checks |
| `python3 -m unittest discover -s tests/python` | PASS; 10 tests |
| `CI_LOG_DIR=$PWD/build/bta060-final python3 tools/validate_godot.py` | PASS; pinned 4.6.3, import, 329 script checks, startup smoke |
| `CI_LOG_DIR=$PWD/build/bta060-final python3 tools/run_tests.py` | PASS; 766 tests, 0 failures/errors/skips |
| `python3 tools/verify_chapter_handoff.py` | PASS |
| `python3 tools/verify_depth_gate.py` | PASS |
| `python3 tools/verify_expanded_expedition.py` | PASS |
| `python3 tools/verify_revision_two.py` | PASS |
| `python3 tools/verify_story_choice.py` | PASS |
| `python3 tools/verify_sunlit_shallows.py` | PASS |
| `python3 tools/verify_twilight_expedition.py` | PASS |
| `python3 tools/verify_twilight_habitat.py` | PASS |
| `python3 tools/verify_twilight_stalker.py` | PASS; quiet complete chapter; keyboard and controller warning/pursuit/escape at 95 hull |
| `python3 tools/verify_twilight_survey.py` | PASS |
| `python3 tools/build_playtest.py --allow-dirty` | PASS; real Linux release export/package, manifest in logs/linux-export.json |
| `git diff --check` | PASS |

Both the first full suite and final suite passed 766 tests. The final run covers the
bounded sight/target-query work. No existing assertion or timeout was modified.
Route orchestration ran at most two route tools concurrently. The new tool runs
three independent fresh profiles (quiet keyboard chapter, hunted keyboard, hunted
controller), with source inputs and acceptance tokens in the current logs.

Focused command: eight tests, 84 assertions, all passed:

```sh
godot --headless --path . --script res://addons/gut/gut_cmdln.gd \
  -gexit -gdisable_colors -gconfig= \
  -gtest=res://tests/unit/test_rift_stalker.gd,res://tests/integration/test_twilight_hunt.gd \
  -gjunit_xml_file=res://build/ci-logs/bta060-target.xml
```

The tests exercise the real receiver, passive contact, hull API, weapon-only collider,
a fired projectile, one detonation, stun and no kill, not merely component presence.
The pure models additionally cover multi-actor nearest selection and farther hearing.
Checkpoint reset uses the actual registered `checkpoint_restored` signal, not a new
save field or altered schema. Existing full Continue/failure routes also passed.

## Export smoke

The prepared environment supplies checksum-verified Godot 4.6.3 Linux templates.
The final dirty-development export has a source-content build ID and binary SHA-256
recorded in `logs/linux-export.json`; the packaging helper restores build_info.json.
The smoke helper checks package inventory and checksum and runs the extracted binary
away from source/editor with isolated data/config/cache. Use the package path from
that manifest as `$package`:

```sh
python3 tools/smoke_playtest.py "$package" --log build/playtest/positive060-final.log
python3 tools/smoke_playtest.py "$package" --log build/playtest/stalker-registration060-final.log --break-stalker-registration-wiring
python3 tools/smoke_playtest.py "$package" --log build/playtest/stalker-passive060-final.log --break-stalker-passive-wiring
python3 tools/smoke_playtest.py "$package" --log build/playtest/stalker-hearing060-final.log --break-stalker-hearing-wiring
python3 tools/smoke_playtest.py "$package" --log build/playtest/stalker-scare060-final.log --break-stalker-scare-wiring
python3 tools/smoke_playtest.py "$package" --log build/playtest/depth-rating060-final.log --break-depth-rating-wiring
python3 tools/smoke_playtest.py "$package" --log build/playtest/depth-section060-final.log --break-depth-section-wiring
python3 tools/smoke_playtest.py "$package" --log build/playtest/failure060-final.log --break-failure-wiring
python3 tools/smoke_playtest.py "$package" --log build/playtest/resource060-final.log --break-resource-wiring
python3 tools/smoke_playtest.py "$package" --log build/playtest/visibility060-final.log --break-visibility-wiring
python3 tools/smoke_playtest.py "$package" --log build/playtest/registration060-final.log --break-registration-wiring
```

Positive: exit 0, default telemetry OFF, all five expected registration/resource/
visibility/Stalker/depth pass tokens. Stalker proof hears an actual ping and actual
far explosion, then fires a real torpedo and steps its ray to the invulnerable actor,
proving the collider and scare callback work in the export. It is not an editor-only
assertion or a direct call to the scare method.

Each of the ten negative runs exited 1 as expected, with its specific
`RELEASE_*_WIRING_FAIL` token verified. These are deliberately failing negative
cases, not ordinary failed tests. New cases remove the real receiver binding,
passive emitter binding, accepted event eligibility, or detonation-to-scare signal.
CI runs every negative case and preserves logs alongside the package.

## Native captures and frame-cost limits

```sh
DISPLAY=:99 BTA_EVIDENCE_DIR=$PWD/docs/testing/bta-060 \
  godot --path . --audio-driver Dummy --rendering-method gl_compatibility \
  --script res://tests/fixtures/capture_twilight_stalker.gd
```

PASS `BTA060_CAPTURE_PASS`; six PNGs independently checked for exact 1280×800 or
800×600 dimensions. Warning, pursuit and scare images were visually inspected.
The fixture reapplies the normal commissioned hull capability, settles camera
interpolation, disables unrelated tutorial cards, and holds actor motion for framing.
It drives warning from a real ping, pursuit through model time, and scare via an
actual fired projectile. Actual moving pursuit/escape is verified separately by
both input-device routes. No composed/generated screenshots or image edits.

Renderer: Mesa llvmpipe OpenGL under Xvfb, not target gaming hardware. Final staged
capture samples: 1280×800 whole-process 112.336 ms / physics 9.964 ms; 800×600
328.214 ms / physics 22.657 ms. They include software rendering, synchronous readback,
other active simulation and concurrent validation, while the photographed actor's
motion is held. They do not isolate new AI cost or certify 60 FPS. The unsupported
VSync warning is retained; no final capture gameplay errors. New runtime work uses
one bounded graph (168 candidate cells), four sight/target checks per second while
investigating/hunting, and fresh contact checks only when a hit is eligible. Nearest
selection/temporary arrays happen only on detonation, not every frame.
