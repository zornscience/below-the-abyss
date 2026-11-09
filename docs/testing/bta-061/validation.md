# BTA-061 commands and retained results

Working directory: `/workspace/below-the-abyss`. Before engine commands:

```sh
export XDG_CACHE_HOME=/workspace/.cache
export XDG_DATA_HOME=/workspace/.local/share
export XDG_CONFIG_HOME=/workspace/.config
```

Godot: `4.6.3.stable.official.7d41c59c4`; pinned GUT 9.6.1; Python 3.12.

| Command | Result |
| --- | --- |
| `python3 tools/lint_release_safety.py` | PASS; runtime assertions contain only allowlisted pure checks |
| `python3 -m unittest discover -s tests/python` | PASS; 10 tests |
| `CI_LOG_DIR=$PWD/build/bta061-release-checks python3 tools/validate_godot.py` | PASS; pinned engine, import, 336 script checks, startup smoke |
| `CI_LOG_DIR=$PWD/build/bta061-release-checks python3 tools/run_tests.py` | PASS; 781 tests, 45,489 assertions, no failures/errors/skips |
| `python3 tools/verify_chapter_handoff.py` | PASS |
| `python3 tools/verify_depth_gate.py` | PASS |
| `python3 tools/verify_expanded_expedition.py` | PASS |
| `python3 tools/verify_revision_two.py` | PASS |
| `python3 tools/verify_story_choice.py` | PASS |
| `python3 tools/verify_sunlit_shallows.py` | PASS |
| `python3 tools/verify_twilight_expedition.py` | PASS |
| `python3 tools/verify_twilight_habitat.py` | PASS |
| `python3 tools/verify_twilight_stalker.py` | PASS |
| `python3 tools/verify_twilight_survey.py` | PASS |
| `python3 tools/verify_twilight_tunnels.py` | PASS; final data, both devices, both squeezes/gates/dead ends, impacts and fresh-process Continue |
| `python3 tools/build_playtest.py --allow-dirty` | PASS; real Linux release export/package; [manifest](logs/linux-export.json) |
| `git diff --check` | PASS |

Route orchestration uses at most two route tools concurrently and preserves each
underlying exit code. Each tool keeps its own existing timeouts and assertions.
[Route results](logs/route-results.txt) and `logs/verify_*.txt` contain commands/tokens.
No pre-existing assertion was removed or loosened and no existing timeout was raised.

Focused command: **13 tests / 385 assertions passed**:

```sh
godot --headless --path . --script res://addons/gut/gut_cmdln.gd \
  -gexit -gconfig= \
  -gtest=res://tests/unit/test_twilight_tunnels.gd,res://tests/integration/test_twilight_tunnels.gd
```

This covers Resource validity, actual vessel dimensions, generated geometry, real
capsule casts and widths, one-shot blocked/two-shot open, exact battery debit,
registered radio delivery, zero XP, actual acoustic receipt, shared cut cap,
Continue/transfer supplies and cuts, repeated-cut return edges and the vent cycle.
The existing regional-cost suite also gained checks after upgrade reapplication and
Continue. The final full suite includes all those tests.

Development findings: the first full run failed a newly written subset test that
re-clipped already clipped polygons at large world coordinates. Diagnostic remnants
were triangular areas of 0.000079–0.001084 square units. The final test instead checks
strict non-increasing rock area and every actual capsule return edge after every edit;
no collision tolerance was added. A native pilot initially fired in the wrong direction
because its fixed six-frame turn did not reliably overcome reverse drift. It now waits
for actual rightward velocity before firing and verifies facing. Native capture teardown
now awaits process/render submission after freeing the scene; the final 800×600 run
exits without the earlier residual-render-resource error. An existing habitat route also
caught a new optional study echo passing through rock.
The two new subjects now use the existing clear-path echo option; both original
habitat pilots pass without changing their discovery assertions or fixtures. A new
focused test verifies blocked shelf sightlines and open branch sightlines. The new
Resource approach also adds an orthogonal turn above the gallery, avoiding the
keyboard pilot clipping its roof on a diagonal steering approach. The polygon-subset
and native capture issues were test/fixture fixes, not changes to impact, excavation, gate costs or lighting.

## Real exported application

Development content digest: `9759e1a5306243edddfbf877a0d285f04b634daa`.
Package: `build/below-the-abyss-playtest-linux-9759e1a53062.zip`.
Executable SHA-256: `8c00a2e88dd635f9c7bd67a7a71f4f88eda645281a92c979a7d8ff06d0028be2`.
Manifest identifies a dirty development export based on `ee38c74`; it does not claim a
clean release commit. Docs/tests are excluded from the builder's content digest.

```sh
package=build/below-the-abyss-playtest-linux-9759e1a53062.zip
python3 tools/smoke_playtest.py "$package" --log docs/testing/bta-061/logs/release-positive.txt
# Each following invocation must exit 1 and emit its specific WIRING_FAIL token.
for wiring in registration visibility resource depth-rating depth-section failure \
  stalker-registration stalker-passive stalker-hearing stalker-scare \
  tunnel-geometry tunnel-gates tunnel-vents; do
  python3 tools/smoke_playtest.py "$package" \
    --log "docs/testing/bta-061/logs/release-$wiring.txt" "--break-$wiring-wiring"
done
```

Positive: **exit 0**, all eight pass tokens, default telemetry off. All thirteen
negatives: **exit 1**, expected marker present, retained in the corresponding log.
[Matrix](logs/export-smoke-results.txt). `.github/workflows/godot-validation.yml` runs
the three additional flags alongside the existing negative-wiring checks.

| New negative | Actual broken wiring | Required failure token |
| --- | --- | --- |
| `--break-tunnel-geometry-wiring` | Disable collision on a compiled tunnel body; positive also checks expected body count, CollisionPolygon2D presence and matching visibility outlines | `RELEASE_TUNNEL_GEOMETRY_WIRING_FAIL` |
| `--break-tunnel-gates-wiring` | Remove a stable gate ID from the excavation registry | `RELEASE_TUNNEL_GATES_WIRING_FAIL` |
| `--break-tunnel-vents-wiring` | Remove a tunnel vent from its update registry and disable it | `RELEASE_TUNNEL_VENTS_WIRING_FAIL` |

These are the extracted standalone release binary, outside source/editor and with
isolated data directories. The source-only headless run is not used as export proof.

## Native captures and input routes

Xvfb display `:99`, Mesa llvmpipe OpenGL compatibility renderer; existing Godot art,
normal darkness, default HUD scale, muted audio, reduced motion/flashing/particles.
No resizing, cropping, overlays or synthetic UI. Header verification confirms **26 PNGs**:
13 at 1280×800 and 13 at 800×600. [Image index](README.md#native-images-and-scripted-evidence).

```sh
export BTA_EVIDENCE_DIR=$PWD/docs/testing/bta-061/screenshots
DISPLAY=:99 godot --path . --audio-driver Dummy --rendering-method gl_compatibility \
  --disable-render-loop --fixed-fps 60 --script res://tests/fixtures/drive_twilight_tunnels.gd \
  --quit-after 180000 -- --profile=bta061-gates-keyboard --input=keyboard
DISPLAY=:99 godot --path . --audio-driver Dummy --rendering-method gl_compatibility \
  --disable-render-loop --fixed-fps 60 --script res://tests/fixtures/drive_twilight_tunnels.gd \
  --quit-after 180000 -- --profile=bta061-gates-controller --input=controller --small
```

Both native routes finish with `TUNNEL_INPUT_PASS`, four gate cuts, both payoffs scanned,
unchanged XP, both deliberate impacts and both shortcuts traversed. Final hull/battery:
keyboard **82.2380 / 53.3511**, controller **82.4554 / 55.4159**. Controller damage totals
are exactly **17.5446 collision**, including the deliberate 9.0 and 8.5446 dead-end hits;
its careful traversals add no hull loss. The keyboard route likewise records exactly **17.7620 collision** from its deliberate
9.0 and 8.7620 hits; its final orthogonal shelf approach and careful traversals add no damage. Pings and travel consume the
remaining battery in addition to four shots at five each. No human timings are inferred.

The verification tool uses separate processes and the actual title Continue UI for both
keyboard and controller, then traverses both saved shortcuts.
Retained native logs are in `logs/native-*.txt`. Software-rendered capture wall time is
not a performance result. The gate-pair capture helper walks closer using real inputs to fit the entire plug in
the native 800×600 view, then returns to the authored firing point. Camera/HUD settings
remain normal. Its final source was additionally checked with
`godot --headless --path . --check-only --script res://tests/fixtures/drive_twilight_tunnels.gd`
(PASS), and both native routes completed after that fixture-only framing adjustment.
Use fresh `--profile` values when repeating the examples; the listed profiles identify
the actual captured runs. Godot reports unsupported V-Sync on this driver; the final
captures have no engine `ERROR:`/`SCRIPT ERROR:` diagnostics.

**Human playtest results do not exist. Every number remains a hypothesis.**
PR-specific remote CI is separate from these local checks; no merge is requested.
