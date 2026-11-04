# BTA-056 release results

Runtime source: `37fc7b568be8ad49469f763d3c5630749d785f92`. Godot `4.6.3.stable.official.7d41c59c4` / GUT 9.6.1,
Compatibility. Clean export (`development_dirty: false`); later evidence-only commits
do not change runtime assets, scenes or scripts.

| Check | Local result |
| --- | --- |
| Full GUT | **735/735**, **44,736 assertions**, **848.975s**; [log](logs/gut.txt), [JUnit](logs/unit-tests.xml) |
| Import / parser / startup | Pass, **304 scripts**; [log](logs/validation.txt), [inventory](logs/parser.log) |
| New focused suite | 8/8; physical hull clearance, optionality, persistence, sighting pause, range, guidance, hidden images |
| Final optional survey + chapter | 4/4 processes, keyboard/release + controller/capture, fresh + Continue; [log](logs/survey-final.txt) |
| Existing input routes | Expanded/revised expedition, both bloom paths, canonical Sunlit Shallows, handoff, habitat and both Twilight choices/Continue; [final results](logs/final-checks.txt) |
| Actual prior BTA-055 saves | 2/2 copied profiles, refit resumed, original files unchanged, no replay; [log](logs/legacy-final.txt) |
| Native full chapter/survey | 4/4 processes at 1280×800 and 800×600; [driver](logs/native-pipeline.txt), [gallery](README.md#retained-native-evidence) |
| Python tooling | 7/7; [log](logs/python.txt) |
| Linux export / standalone | Pass; [manifest](logs/manifest.json), [export](logs/linux-export.json), [smoke](logs/standalone-result.txt) |

## Measured pacing, not human acceptance

Native final-source simulation timings exclude Chapter 1 preparation and paused
reading. Optional survey and the subsequent required-evidence route are separate.

| Outcome/input | Optional circuit | Required evidence + return/debrief | Combined deep simulation |
| --- | --- | --- | --- |
| release | 170.717 s | 238.583 s | 6.82 min |
| capture | 211.367 s | 343.250 s | 9.24 min |

BTA-055 native repeat-route baseline was 252.550s release / 343.250s capture.
The optional circuit adds measurable exploration; it does not establish the agreed
**30–45-minute first-time human target**. No mandatory waits, slower engine or longer
scan durations were added to pad it. Different steering and frame scheduling can
change route timing. Follow the human evaluation protocol in README before claiming
that pacing, discoverability or artwork meets player expectations.

## Compatibility and limits

Same schema 10 checkpoint, mission objective/reward contracts, stable old anchors and
all catalogue IDs. New optional IDs are validated; old campaign migrations remain
covered by the complete suite. Copying two actual BTA-055 profiles confirmed refit,
progress, reserves, choices and talents restore without replay. The first ad-hoc
legacy harness assumed every previous profile was a deep-space save; retained
profiles correctly saved after refitting. The corrected harness asserts the saved
journey phase instead of forcing deployment. No product migration was needed.

Native captures use software-rendered Mesa/Xorg, muted audio and synthesized real
input events. The unsupported-VSync warning is retained. No physical gamepad,
human playtest, target-GPU FPS, audible-mix review or professional art acceptance is
claimed. Added art is one static 2172×724 lossless mipmapped atlas; no new fullscreen
postprocess, particle batch, acoustic dispatcher, global clock or per-frame texture.
Subject sprites are noncolliding illustrated scan markers, not physical salvage;
final prop integration needs artist review. The first-light cue uses world distance
and terrain line of sight, not viewport visibility. At 800×600 the initial animal
can be partly below the view/behind the existing bottom HUD; the closer net survey
capture shows it clearly. Camera framing is unchanged and needs human evaluation.
The actual animal sighting is presentation only and can recur after Continue with
no state/reward effect. No Zone 3, translation, new economy or mission expansion.

The first extended Sunlit controller attempt hit the existing 300-second harness
limit while running its optional studies, without an engine/assertion error. Only that
all-studies/recovery scenario now has a bounded 480-second budget; all other
canonical runs retain 300 seconds. The complete 12-process matrix was rerun and
passed. Error/exit checks, gameplay timings and every assertion remain intact.
[Initial timeout](logs/sunlit-timeout-detail.txt), [final matrix](logs/sunlit.txt),
[consolidated final results](logs/final-checks.txt). Runtime files are identical to
abc4411; the follow-ups changed verification tooling/fixture expectations only.

The earlier habitat fixture required complete progress equality after an active
ping near the squid. New optional subjects are legitimately discoverable there.
Its updated assertions allow only the four added optional POI IDs, require every
prior discovery to remain, and keep research/missions/upgrades exactly equal.
No discovery/dispatcher behavior was disabled. The full habitat input/Continue
matrix passed after this expectation fix; the modified fixture was parsed again.
[Initial assertion](logs/habitat-initial-detail.txt), [final matrix](logs/habitat.txt),
[follow-up parser](logs/habitat-parser-followup.txt).

Hosted CI and PR publication status are recorded separately after the final attempt.

## Exact verified Linux package commands

```sh
python3 tools/build_playtest.py
python3 tools/smoke_playtest.py build/below-the-abyss-playtest-linux-37fc7b568be8.zip --log build/bta056-verification/standalone-smoke.log
```

The verified package was generated from clean source `37fc7b5`. Rebuilding after
an evidence-only commit produces a new build ID; use the package path printed by
the build command. No binary release was published.
