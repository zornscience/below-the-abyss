# BTA-056 — Twilight Shelf exploration and pacing polish

Based on main `8dbbd07` after merged PR #39/BTA-055. This is a focused extension
of the existing shelf and expedition, not a new chapter or replacement architecture.

## Playable changes

Two narrow central chimneys connect the departure shelf, a cross-gallery and the
lower return passage. Each chimney has 300 authored units of width; rock detail
uses the same rounded contours for collision, painted trim and map. Blind cargo
pockets branch from the gallery and can be backed out of without torpedoes. Existing
outer loops, protected bounds, spawn, vent locations and required scan anchors stay
fixed. Only the former central solid mass is carved. Western objective guidance
now follows a pilot choosing the west before investigating the eastern cable.

Four optional observations add a cable anchor, waterlogged cargo timber, ballast
pocket and cool thermal margin. They use normal deliberate Interact scanning, the
existing research registry, lifetime science-XP cap and expedition log. They do not
add mission objectives, allowances, Resonance changes or a mandatory route. Optional
observations remain scannable after the common debrief. Sonar is useful but not
required to scan a visible subject; passive contacts remain temporary.

Before the net survey, one clear-water sighting refers to the **actual** sentinel
within 900 units with unobstructed terrain line of sight. No ghost creature or new
sound/discovery event is spawned. The hint freezes with simulation and cannot grant
anything. It is transient: Continue can show the contextual hint again, but existing
notification deduplication prevents spam during that session. A resolved/absent
animal or completed net survey suppresses it. The net approach prompt no longer
offers a scan beyond the scanner's radius.

A new illustrated subject atlas replaces generic instrument plates and primitive
scratches. Research records now show their completed subject image inside the
scrollable detail pane; hidden records expose neither title nor image. Existing
semantic typography, controller focus and bounded panels are retained. Animal
records use the actual sentinel master. Art is generated, not a claim of human-
painted professional acceptance; see the [asset inventory](../../../assets/art/twilight/README.md).

## Layout and manual playtest

Launch `godot --path .` with Godot 4.6.3. Use a separate test profile or back up your
campaign; New Game is intentionally destructive after its existing confirmation.
Complete Sunlit Shallows or Continue an existing Twilight expedition. Defaults are
WASD / left stick to pilot, E / A to Interact, F / X to ping and M / Back for map;
use the actual binding prompts if remapped. No combat is required.

1. Arrive at the central ascent tether at 350 m. Choose west or east freely. Descend
   through either chimney in the central rock, explore the transverse gallery,
   scan both cargo-pocket subjects and reverse out of the closed ends. Cross to the
   other chimney and exit above or below. Passages must read as open, rock as solid.
2. Follow the eastern physical cable past its optional anchor. Compare the intact
   anchor with the required severance, then recover Mara's existing first logger.
3. Explore the western whaler and record its untranslated marking. Optional detached
   Mara loggers remain at their prior positions. Check the research images and text
   scroll at 800×600, Large Text and High Contrast using both input devices.
4. Approach the eastern lower basin. Notice the same living light before reaching
   the net. Observe the cooler thermal-margin subject from its east side; do not
   cross the active plume. Verify eruption warning/damage and a safe bypass remain.
5. Scan the net, intentionally release or capture on separate campaigns, then take
   any open return loop to the ascent tether. Return to Halcyon, archive the debrief
   and optionally refit. Either choice still completes the chapter.
6. Save, quit and Continue. Optional records, prior evidence, decisions, resources
   and talents persist; no new science credit or choice reward. Revisit completed
   subjects. Pause midway through piloting or viewing the animal; simulation stops.
7. Repeat muted with Reduced Motion/Effects/Particles; sighting and hazards must
   remain understandable from text/shape without relying on sound or flashing.

For reviewers only, authored navigation coordinates (not extra player markers):

| Route | Points |
| --- | --- |
| Inner loop | tether (33000,1400) → west chimney (31950,1400) → (31950,2300) → east junction (33450,2300) → (33450,2900) → existing east return (35800,2900) → (35800,1400) → tether |
| Blind branches | from gallery to (31100,2300) and (34100,2300), then reverse |
| Optional anchor | (34900,1440) |
| Thermal observation | (36500,3100), east of the plume |

[Every changed file](changed-files.txt).

## Save compatibility

Same schema **10**, twelve top-level fields and atomic checkpoint/backup/recovery.
No new independent save file or mission ledger. Four authored research IDs (and
matching `-poi` / `-echo` IDs) extend the existing strict catalogues. Incoming schema
1–9 migrations and existing schema-10 saves preserve their records and actual
reserves without inferring new scans or replaying signals. Prior six Twilight scan
IDs/positions, mission ID/objectives, three outcomes and rewards remain unchanged.
Earlier binaries may reject newly recorded IDs even though the structural schema
is unchanged: keep backups and use this or newer builds after saving optional scans.
New passages remove rock; prior valid poses remain navigable, with existing safe
spawn validation/fallback still authoritative. No physics/talent/drain tuning.

## Reproducible verification

```sh
export XDG_CACHE_HOME=/workspace/.cache
export XDG_DATA_HOME=/workspace/.local/share
export XDG_CONFIG_HOME=/workspace/.config
python3 tools/validate_godot.py
python3 tools/run_tests.py
python3 tools/verify_twilight_survey.py
python3 tools/verify_expanded_expedition.py
python3 tools/verify_revision_two.py
python3 tools/verify_story_choice.py
python3 tools/verify_sunlit_shallows.py
python3 tools/verify_chapter_handoff.py
python3 tools/verify_twilight_habitat.py
python3 tools/verify_twilight_expedition.py
python3 -m unittest discover -s tests/python -v
python3 tools/build_playtest.py
# Use the exact package path printed by the preceding command:
python3 tools/smoke_playtest.py build/below-the-abyss-playtest-linux-SHA.zip --log build/playtest/standalone-smoke.log
```

The new survey verifier uses keyboard and controller input, traverses both blind
pockets/chimneys, intentionally scans four optional subjects, opens the research
record, completes the original expedition and then starts a separate Continue
process for each outcome. It is also part of the existing GitHub Actions job.
Logs distinguish the optional circuit from the unchanged required-evidence route.
Automated input is not a human or physical-controller playtest.

[Exact results and source identity](release-results.md). Local checks passed; hosted GitHub Actions status could not be queried through the blocked API.

## Pacing protocol and limitations

The agreed **30–45-minute first-time human** main expedition and optional 10–15
minutes are targets, not established results. Automated steering knows every
coordinate and reads no narrative. Compare required-evidence runs separately from
optional full surveys; measure simulation and wall time independently. Do not
inflate durations by idling, slowing controls or adding mandatory text.

Human evaluation remains required: recruit first-time players, give only the
opening objective, record first choice of direction, wrong turns, time to identify
cable/marking/net, optional records found, resource/refit decisions, total active
play and reading/pause time. Ask whether each blind pocket felt useful, whether the
thermal approach felt fair and whether a return shortcut was understood. Report
median/range and navigation confusion before changing more terrain or mission
requirements. No claim that this milestone meets the duration target or professional
art acceptance; no suitable modest-GPU hardware or physical gamepad testing here.
No Zone 3, translation, later lore, new economy, new combat or extra missions.

## Retained native evidence

Native Godot Compatibility on Xorg :98 / Mesa llvmpipe, muted audio. The 800×600
route uses Large Text, High Contrast and Reduced Motion/Effects/Particles; 1280×800
uses normal presentation. Screenshots are original viewport captures, not generated
mockups. On-demand render-loop warm-up is not a realtime performance benchmark.

| Scene | 1280×800 keyboard/release | 800×600 controller/capture, comfort settings |
| --- | --- | --- |
| inner chimney | [view](screenshots/1280/inner-chimney.png) | [view](screenshots/800/inner-chimney.png) |
| twilight cargo timber | [view](screenshots/1280/twilight-cargo-timber.png) | [view](screenshots/800/twilight-cargo-timber.png) |
| cargo pocket | [view](screenshots/1280/cargo-pocket.png) | [view](screenshots/800/cargo-pocket.png) |
| anchor clue | [view](screenshots/1280/anchor-clue.png) | [view](screenshots/800/anchor-clue.png) |
| illustrated research record | [view](screenshots/1280/illustrated-research-record.png) | [view](screenshots/800/illustrated-research-record.png) |
| thermal observation | [view](screenshots/1280/thermal-observation.png) | [view](screenshots/800/thermal-observation.png) |
| first living glimpse | [view](screenshots/1280/first-living-glimpse.png) | [view](screenshots/800/first-living-glimpse.png) |
| twilight net survey | [view](screenshots/1280/twilight-net-survey.png) | [view](screenshots/800/twilight-net-survey.png) |
| unclassified marking | [view](screenshots/1280/unclassified-marking.png) | [view](screenshots/800/unclassified-marking.png) |
| twilight discovered map | [view](screenshots/1280/twilight-discovered-map.png) | [view](screenshots/800/twilight-discovered-map.png) |
| sentinel outcome | [view](screenshots/1280/sentinel-outcome.png) | [view](screenshots/800/sentinel-outcome.png) |
| twilight persistent debrief | [view](screenshots/1280/twilight-persistent-debrief.png) | [view](screenshots/800/twilight-persistent-debrief.png) |

[Dimensions, provenance and image hashes](screenshots.json).

| Subject comparison | BTA-055 before | BTA-056 after |
| --- | --- | --- |
| Whaler marking at its unchanged anchor | [native before](../bta-055/screenshots/1280/unclassified-marking.png) | [native after](screenshots/1280/unclassified-marking.png) |

The comparison shows the same authored subject, not pixel-aligned camera poses.
The inner gallery has no before counterpart: it was previously solid rock.

Reproduce graphical evidence on a desktop (create the output directory first):

```sh
mkdir -p /tmp/bta056-native
BTA_EVIDENCE_DIR=/tmp/bta056-native godot --path . --audio-driver Dummy \
  --rendering-method gl_compatibility --disable-render-loop --fixed-fps 60 \
  --script res://tests/fixtures/drive_twilight_survey.gd --quit-after 180000 -- \
  --no-excavation --profile=bta056-review-keyboard --input=keyboard \
  --outcome=observe --sentinel=release
```

Run again with the same profile and `--twilight-resume` for quit/Continue. A different
profile with `--input=controller --outcome=collect --sentinel=capture --small
--high-contrast --comfort` captures the accessibility case. These fixture profiles
are reset by fresh runs; never use your personal campaign profile name. On this
cloud host also set DISPLAY=:98, LIBGL_ALWAYS_SOFTWARE=1 and LP_NUM_THREADS=1.

For local verification outputs stored under `build/`, create `build/.gdignore` before
capturing screenshots there so the editor does not import generated evidence as
project art. Export already excludes `build/` and `docs/`.

## Review handoff

[Create the review PR](https://github.com/zornscience/below-the-abyss/compare/main...bta-056-twilight-polish?expand=1)
using [PR.md](PR.md). The branch and all evidence are pushed. Automatic creation
returned `Post "https://api.github.com/graphql": Forbidden`; see the
[publication record](logs/pr-publication.txt). No PR was opened or merged, and
hosted CI status remains unverified. All reported passing checks are local.
