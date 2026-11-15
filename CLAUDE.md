# Claude Code instructions — Below the Abyss

@AGENTS.md

Also read `docs/HANDOFF.md` (state, decisions, risks), GDD.md, TDD.md and CODEX_PLAN.md
(the file keeps its name because other docs link to it) before changing code.

## Build, test and verify

Commands below are copied from `docs/HANDOFF.md` §3, which is the source if they drift.

```sh
# Engine: official Godot 4.6.3 (checksummed in .github/workflows/godot-validation.yml)
export GODOT_BIN=/path/to/Godot_v4.6.3-stable_linux.x86_64
python3 tools/install_gut.py            # may fail behind a proxy: clone bitwes/Gut at the pinned commit
$GODOT_BIN --headless --path . --editor --import --quit   # REQUIRED after switching branches
python3 tools/lint_release_safety.py
python3 -m unittest discover -s tests/python
python3 tools/validate_godot.py         # import, parser, startup (~300+ scripts)
python3 tools/run_tests.py              # full GUT suite, ~10 min; do not run two Godot jobs at once
python3 tools/verify_*.py               # scripted input routes (see CI workflow for the list)
python3 tools/install_export_templates.py   # ~1.2 GB, once
python3 tools/build_playtest.py             # real Linux export (--allow-dirty for local edits)
python3 tools/smoke_playtest.py build/below-the-abyss-playtest-linux-*.zip --log /tmp/x.log
python3 tools/smoke_playtest.py <zip> --log /tmp/x.log --break-<name>-wiring   # must FAIL
```

- Single test file: `$GODOT_BIN --headless --path . --script res://addons/gut/gut_cmdln.gd -gexit -gdir=res://tests/integration -gselect=<name>`.
- Native screenshots: `xvfb-run -a ... godot --path . --rendering-method gl_compatibility --script <fixture>` with
  `root.get_texture().get_image().save_png(...)` (see `tests/fixtures/capture_*.gd`). Software GL is slow.

## Rules that have caused real failures

- **Run only one Godot job at a time.** Do not start a second import, test, verify or export
  while one is running.
- **Re-import after switching branches** (`--editor --import --quit` above) before any test or
  verify run.
- **No side effects inside `assert()`.** It is stripped from release exports and hid a real bug
  (Twilight sonar/discovery wiring). Do the work in a plain statement, then assert on the result.
  `tools/lint_release_safety.py` enforces it.
- **Debug-only tests prove nothing about release builds.** New wiring needs a `ReleaseSmoke` check
  (`scripts/playtesting/release_smoke.gd`, playtest export only) and a negative `--break-*-wiring`
  case that must fail.
- Do not weaken assertions or raise timeouts to make a test pass.
- Wait for the PR's own CI to be green before anyone merges. Do not merge yourself unless asked.
