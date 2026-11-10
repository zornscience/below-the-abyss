# Commands and results

Environment: Godot `4.6.3.stable.official.7d41c59c4`, GUT 9.6.1, Python 3,
Linux x86_64. Committed text logs normalize trailing whitespace only; substantive
output and expected injected ERROR lines are retained. Commands below run at the
repository root. Dependencies are the
existing project dependencies; no new SDK or runtime dependency was added.

```sh
export XDG_CACHE_HOME=/workspace/.cache
export XDG_DATA_HOME=/workspace/.local/share
export XDG_CONFIG_HOME=/workspace/.config
```

| Exact command | Final result | Evidence |
| --- | --- | --- |
| `python3 tools/lint_release_safety.py` | exit 0; assertions contain only allowlisted pure checks | [log](logs/release-safety.txt) |
| `python3 -m unittest discover -s tests/python` | exit 0; 10 tests pass | [log](logs/python-tests.txt) |
| `python3 tools/validate_godot.py` | exit 0; pinned engine, import, 350 script checks, startup smoke | [log](logs/godot-validation.txt) |
| `python3 tools/run_tests.py` | exit 0; 795/795 tests, 46,218 assertions, no failures/errors/skips | [log](logs/godot-tests.txt) |
| `python3 tools/verify_combat_box.py` | exit 0; both devices, both handling courses/measurements, ping stun, one-shot kill, visible chase, quiet escape, opted-in fixed rating and actual report readback | [log](logs/verify_combat_box.txt) |
| `python3 tools/verify_depth_gate.py` | exit 0 | [log](logs/verify_depth_gate.txt) |
| `python3 tools/verify_expanded_expedition.py` | exit 0 | [log](logs/verify_expanded_expedition.txt) |
| `python3 tools/verify_chapter_handoff.py` | exit 0 | [log](logs/verify_chapter_handoff.txt) |
| `python3 tools/verify_revision_two.py` | exit 0 | [log](logs/verify_revision_two.txt) |
| `python3 tools/verify_story_choice.py` | exit 0 | [log](logs/verify_story_choice.txt) |
| `python3 tools/verify_twilight_expedition.py` | exit 0 | [log](logs/verify_twilight_expedition.txt) |
| `python3 tools/verify_twilight_habitat.py` | exit 0 | [log](logs/verify_twilight_habitat.txt) |
| `python3 tools/verify_sunlit_shallows.py` | exit 0 | [log](logs/verify_sunlit_shallows.txt) |
| `python3 tools/verify_twilight_stalker.py` | exit 0 | [log](logs/verify_twilight_stalker.txt) |
| `python3 tools/verify_twilight_survey.py` | exit 0 | [log](logs/verify_twilight_survey.txt) |
| `python3 tools/verify_twilight_tunnels.py` | exit 0 | [log](logs/verify_twilight_tunnels.txt) |
| `python3 tools/build_playtest.py --allow-dirty` | exit 0; actual release export and standalone package | [manifest](export.json), [import](logs/build-import.log), [export](logs/build-export.log) |

The full suite includes five new unit tests and nine new integration tests;
all existing test files/assertions and route timeouts are unchanged. An earlier
development suite exposed a JSON numeric-version comparison bug (two preexisting
report round-trips failed). The comparison was corrected, and the entire suite
then passed. Final routes also verify the rating by reopening the written JSON. Live regression
coverage also checks that immediate TELEGRAPH and a direct Stalker scare establish
first engagement, even if no separate INVESTIGATE frame was presented.

The validation/full-test commands were run with
`CI_LOG_DIR=/workspace/below-the-abyss/build/combat-final`; campaign route logs used
`CI_LOG_DIR=/workspace/below-the-abyss/build/combat-routes`. Paths affect evidence
output only. The final new route was repeated after calm-effects assertions were
added. All twelve `verify_*.py` files present at implementation time are listed.

The final driver also explicitly checks the existing facing-flip threshold with
real input (`facing=2.116666… / 0.533333…` at 60 Hz). Its final parser command
`godot --headless --path . --check-only --script res://tests/fixtures/drive_combat_box.gd`
exited 0; see [log](logs/driver-parser.txt).

## Native captures

Xvfb `:99`, Mesa llvmpipe OpenGL compatibility renderer. Screenshot commands:

```sh
DISPLAY=:99 BTA_EVIDENCE_DIR=/workspace/below-the-abyss/docs/testing/combat-testbox/screenshots \
  godot --path . --audio-driver Dummy --rendering-method gl_compatibility \
  --disable-render-loop --fixed-fps 60 \
  --script res://tests/fixtures/drive_combat_box.gd --quit-after 90000
DISPLAY=:99 BTA_EVIDENCE_DIR=/workspace/below-the-abyss/docs/testing/combat-testbox/screenshots \
  godot --path . --audio-driver Dummy --rendering-method gl_compatibility \
  --disable-render-loop --fixed-fps 60 \
  --script res://tests/fixtures/drive_combat_box.gd --quit-after 90000 -- --controller --small
```

Both exit 0 and print both course/measurement results, one-torpedo kill and the
input-route completion token. [Keyboard log](logs/native-keyboard.txt) includes
an earlier ObjectDB/six-resource warning at exit; it is not hidden or counted
as a clean engine log. Verbose diagnosis identified the existing mix thread holding
six AudioStreamWAV loop playbacks during accelerated shutdown. The capture fixture
now allows a 50 ms real-time handoff after freeing the scene, without changing
gameplay timing or any existing timeout. The final [controller log](logs/native-controller.txt)
and the final keyboard rerun with `--verbose` have no leaks or engine/script errors.
The latter produced the final 1280 × 800 images:
[verbose log](logs/native-keyboard-verbose.txt). No timeout was raised to get these
results. Native PNG sizes and SHA-256 are in the [capture manifest](screenshots/manifest.json).
No human or physical-controller result is implied.

## Actual exported package, including every negative

Final tested source digest/build ID:
`14378dcc249f2b8f7724ae03f6933274d9411b96`.
Binary SHA-256:
`044a752408c70028f6cb4cedf82b1e662e3bbeb06c2ed4849394b9107be2fcc4`.
The development export records the main base commit and `development_dirty=true`;
its build ID is the builder's digest of final non-doc/test source. That digest
was independently recomputed after export and matched. Build stamping restores
the original source `build_info.json`. The archive is an ignored local artifact,
not a published release or a claim of PR CI success.

Positive command:

```sh
python3 tools/smoke_playtest.py build/below-the-abyss-playtest-linux-14378dcc249f.zip \
  --log docs/testing/combat-testbox/logs/release-positive.txt
```

Expected/observed exit 0, all fourteen positive tokens: eight existing proofs and
six combat proofs. It extracts the binary away from the source tree, checks the
binary checksum, isolates user data, loads the scene using the real export-only
Playtest button, and verifies default recording remains OFF.

Each command below is the positive command with its log changed to
`docs/testing/combat-testbox/logs/release-<case>.txt` and one additional argument
`--break-<case>-wiring`. Every command must exit **1**, and its raw engine log must
contain `RELEASE_<CASE_IN_UPPERCASE_WITH_UNDERSCORES>_WIRING_FAIL`. Merely exiting
nonzero without that specific token does not count. The
[machine-readable matrix](logs/release-matrix.json) preserves the full exact
command, actual exit and expected token for each case, including the positive.

| Cases (each independently run on the same real package) | Expected/observed |
| --- | --- |
| resource, visibility, registration | All 3 exit 1 with their specific failure tokens |
| depth-rating, depth-section, failure | All 3 exit 1 with their specific failure tokens |
| stalker-registration, stalker-passive, stalker-hearing, stalker-scare | All 4 exit 1 with their specific failure tokens |
| tunnel-geometry, tunnel-gates, tunnel-vents | All 3 exit 1 with their specific failure tokens |
| combat-entry | exit 1; `RELEASE_COMBAT_ENTRY_WIRING_FAIL` |
| combat-registration | exit 1; `RELEASE_COMBAT_REGISTRATION_WIRING_FAIL` |
| combat-stalker-registration | exit 1; `RELEASE_COMBAT_STALKER_REGISTRATION_WIRING_FAIL` |
| combat-stun | exit 1; `RELEASE_COMBAT_STUN_WIRING_FAIL` |
| combat-handling | exit 1; `RELEASE_COMBAT_HANDLING_WIRING_FAIL` (RESPONSIVE selector) |
| combat-weighty-handling | exit 1; `RELEASE_COMBAT_WEIGHTY_HANDLING_WIRING_FAIL` |

Total: **one positive and nineteen expected negatives**, not only the newly added
cases. Negative engine ERROR lines are intentional injected-failure evidence.
The CI workflow runs the new real-input route and adds all six combat cases to
the existing negative loop, checking the corresponding token. Local passes do
not replace the eventual PR's own CI. No merge is requested.
