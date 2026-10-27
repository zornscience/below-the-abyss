# BTA-042 verification

## Commands

Pinned Godot **4.6.3.stable.official.7d41c59c4**, GUT **9.6.1**. From repository root:

```sh
# Managed cloud only (normal desktop Godot directories also work):
export XDG_CACHE_HOME=/workspace/.cache
export XDG_DATA_HOME=/workspace/.local/share
export XDG_CONFIG_HOME=/workspace/.config
python3 tools/install_gut.py
python3 tools/validate_godot.py
python3 tools/run_tests.py
godot --path .
```

Focused narrative tests:

```sh
godot --headless --path . --script res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_narrative_service.gd,res://tests/integration/test_narrative_slice.gd -gexit -gdisable_colors
```

GitHub Actions retains the unchanged pinned installer, import/parser/startup checks
and full GUT suite on PRs into main/pushes to main. Logs and JUnit remain in the
14-day `godot-validation-<run>-<attempt>` artifact. The PR records the actual final
run/head/status and complete test totals. No old test is disabled or weakened.

## Recorded automated results

- Exact Godot **4.6.3.stable.official.7d41c59c4** verified; pinned GUT **9.6.1** verified.
- Import + **165 authored script parser checks** + startup smoke: **PASS**, no errors.
- Complete GUT: **414/414 passing**, **50 scripts**, **25,175 assertions**, **198.239s**;
  **0 failures, 0 errors, 0 skipped**. This includes all 392 prior tests and 22 new
  narrative unit/integration cases, including partial-debrief failure/retry.
- Existing actionlint and `git diff --check`: pass.
- Native chapter and separate-process Continue: pass, no Godot errors/leaks.

The PR records the hosted Actions run and artifact for its exact final head.

## Actual native walkthrough

On a working native X11 display, run these **in order**:

```sh
DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 godot --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/fixtures/capture_narrative_slice.gd
DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 godot --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/fixtures/capture_narrative_slice.gd -- --continue-story
```

The first process clears only its isolated `user://bta042-native*` fixture profiles.
The second preserves those files and starts a genuinely fresh Godot process.
Neither command writes the player's normal settings/checkpoint. The fixture pilots
with real input actions through existing RouteMarkers; it never writes vessel
position/velocity, inserts discovery/research flags, completes a scan directly,
sets route stages or inserts mission acknowledgements.

[Retained native stdout trace](bta-042-native-trace.txt).

Actual sequence:

1. Read the concise start briefing, open Expedition log with keyboard, intentionally
   Begin survey with controller A (existing MissionService accepts both objectives).
2. Launch/Continue the now-initialized checkpoint, fly east to `(760,480)`, ping F,
   wait for the real wavefront. Read the damaged-marker clue. Passive contact list
   is nonempty, while only active sonar records the POI.
3. Resume, intentionally Interact E to scan outside the docking ring. Wait for the
   actual three-second scanner; the field-record entry becomes available only then.
4. Read the recovered record; fly UpperGate → Cave → EastChamber → TwinSpires.
   Ping and wait to identify the spires. The predator remains QUIET, bypassed.
5. Follow ReturnTurn → LowerEast → LowerWest → BaseRise → spawn. Existing route
   sampling records COMPLETE and the main mission becomes completed.
6. Dock E; open the station expedition log. No ending yet. Intentionally submit the
   debrief with controller A: existing mission claims persist exactly once, and
   the concluding record/hook unlocks. Scroll its text at 800x600 using A on Text ↓.
7. Return to station services, explicitly Service all, return to pilot, pause and
   Save expedition. Confirm real saved status, then exit the process.
8. Launch the second command; controller Continue restores seven eligible log
   entries, concluded state and research. Observe **zero replayed narrative events**
   from node creation through Continue. Open the ending again, then verify movement.

Measured automated completion from opening briefing to final debrief:
**51.391 seconds wall time**, **44.883 seconds on active route telemetry**.
Exactly **one chapter-concluded event**; seven eligible entries, optional geology
unscanned. Fresh-process Continue: **7 entries, concluded=true, replayed events=0**,
movement after load succeeds. Both commands exited 0 without Godot errors/leaks;
Mesa llvmpipe emitted its known unsupported-VSync warning. This is software-rendered
native evidence using injected keyboard/controller input, not a human playtest.
It does **not** establish 20–40 minutes of unfamiliar-player gameplay.

## Screenshots

Actual Godot native renders; no generated mockups/compositing:

| View | Evidence |
| --- | --- |
| Concise skippable station briefing | [Start page](bta-042-opening.png) |
| Expanded briefing with focus controls | [Expedition log](bta-042-briefing.png) |
| First clue after actual wavefront | [Reference marker record](bta-042-first-clue.png) |
| Scientific completion in-world | [Scan recovered](bta-042-scan-recovered.png) |
| Primary recovered expedition text | [Field record](bta-042-field-record.png) |
| Real Twin Spires survey and return guidance | [Spires](bta-042-spires.png) |
| Docked, eligible, ending still hidden | [Before debrief](bta-042-return-review.png) |

<details><summary>Ending / debrief screenshots (spoilers)</summary>

- [Final acknowledgement](bta-042-debrief.png)
- [800x600 log](bta-042-compact-log.png)
- [800x600 scrollable concluding hook](bta-042-compact-hook.png)
- [Fresh-process restored ending](bta-042-continued-log.png)

</details>

## Manual first chapter

1. Launch `godot --path .` in normal mode. On the start/pause page read the concise
   four-line briefing. Open **Expedition log / briefing** with arrows/Tab/Enter or
   D-pad/stick/A. Detail text scrolls with **Text ↑ / ↓**; Escape/B skips/returns.
   The log remains available later, without restarting the chapter.
2. Select **Begin survey / count earlier evidence** intentionally. Both existing
   mission-board objectives become accepted; the earlier board remains usable.
   Back to pause, then Begin/Resume (or Continue after the acceptance checkpoint).
3. Move east to the marked plate near `(760,480)`. Use remappable sonar F/controller X.
   After wavefront arrival, inspect the first clue in the log. Approach and press
   remappable Interact E/A to scan. Do not confuse a sonar echo with a scan. Observe
   progress; moving out of range cancels/reset progress. Pause and reread without
   draining supplies or completing scans while paused.
4. Finish the scan; read the recovered field record in the log or Research log via
   M/Back. Follow the cave toward Twin Spires and ping the landmark. Passive contacts
   remain temporary, non-discovering and silent to AI. Keep to the main passage;
   predator habitat, harmless observer and geological overlook are optional.
5. Follow the lower BASE arrows west and ascend to Shelf Base. Watch numerical
   hull/battery/oxygen and depth warnings. Passing through base never refills.
6. Slow inside the docking radius; Interact to open services. Choose **Expedition
   log / debrief**, then **Submit expedition debrief**. Check the saved confirmation
   and CHAPTER CONCLUDED text; scroll to read the hook. Reopen/repeat: no extra
   acknowledgement, resource reward or duplicated entry should appear.
7. Back returns to the paused station; intentionally service supplies if desired.
   Exit services, safely pause/Save, quit completely and relaunch/Continue. Reread
   all available records. Compare mission claims, discoveries, research, upgrades
   and resources; there should be no replayed ending/scan/ping event on load.
8. Repeat with sound muted and with keyboard/controller alone at 1280x800 and 800x600.
   Verify every critical instruction/state is readable and both text-scroll actions
   remain reachable. A physical controller and human readability/pacing session are
   still required; synthetic events are not ergonomics certification.

## Order, restart and failure exercises

Use an isolated profile or preserve existing save files before manual recovery tests.

- Skip acceptance, discover/scan the plate, visit spires and return first. Accept
  later in the log: existing evidence and current COMPLETE route count immediately.
- Accept, return before scanning, then scan the nearby plate and dock again. The
  missing scan remains possible; no hidden collectible is required.
- Claim either existing mission separately on the station board. Finish/claim the
  other later: the narrative conclusion recognizes the same permanent claims.
- Restart Test Route after accepted progress: scans/discoveries and registered return
  objectives remain. Unaccepted route telemetry is deliberately temporary; if it was
  explicitly restarted before accepting, repeat the short route. No permanent clue
  is deleted. New Expedition also retains permanent records.
- Simulate a failed save during the second debrief claim in the isolated automated
  test: the first stays durable, the second stays completed, and retry claims only
  the missing acknowledgement. No false ending or duplicate reward occurs.
- Corrupt/incompatible canonical save: start remains blocked, briefing remains
  readable, Begin survey is disabled and the rejected file is untouched. Use the
  existing explicit checkpoint recovery; old v1/v2 files need no narrative migration.

## Coverage and limitations

Unit coverage validates authored IDs/text/conditions, spoiler gating, intentional
acceptance, actual evidence distinctions, out-of-order progression, optional clues,
registered return persistence, silent restore, invalid data/save failures and fresh
mission ledgers at 30/60/120-step sampling. Integration covers real active wavefront
and scanner events, passive isolation, docking-gated idempotent debrief, canonical
reload/Continue, restart/services, old v1 checkpoint compatibility, corruption guard,
partial-claim write failure/retry, keyboard/controller focus and responsive scrolling.
Existing full suites retain acoustic history, AI, physics, sonar, saves and all prior
acceptance checks; no new narrative clock or gameplay dispatcher exists.

Narrative text/visuals are original prototype content for review. Human story clarity,
pacing, emotional response, physical controllers, desktop GPU performance and native
Windows/macOS have not been assessed. No voice performance or subjective listening
claim. The existing instructional world-sign overlap is not changed. The current
short geography is not evidence for the 20–40 minute target, and time was not padded
with forced reading, waits or modified resource balance.
