# DC-6 — Drowned Caves debrief and chapter close: evidence

Sixth and last issue of `docs/design/drowned-caves-brief.md`. **No human playtest exists. All new text is a draft
for the designer to edit, and the Zone 4 teaser is a single line, not a feature.**

## What was built

| Area | Change |
| --- | --- |
| Descent on by default | The Halcyon dock offers "Descend to the Drowned Caves" once the Twilight debrief is claimed. Until now it was hidden behind `--drowned-caves`. **A tester who finishes Twilight now sees it without any flag.** Launch with `-- --no-drowned-caves` (after the `--`) to hide it for a session that should stop at Twilight. |
| Caves debrief | At the dock, after Mara's required cave log is recorded, "Drowned Caves expedition debrief" opens a page titled "HALCYON / THE DROWNED CAVES". It is derived from saved state, so it is never stored: the sentinel outcome, how many cave records you recorded, the crystal decision (left, taken, or undecided) and the sonar calibration if taken. It ends with one teaser line: the Furnace Vents are the next investigation and are **not playable in this build**. Showing it saves and awards nothing. |
| Twilight wording | The Twilight debrief's last line and the mission acknowledgement now say "The Drowned Caves are open: descend from the Halcyon dock whenever you are ready", replacing "not playable". |
| Descent offer and notices | Rewritten without "foundation" wording; the offer states the oxygen tank minutes computed from the cave resource. |
| Expedition log | The dock log lists recorded cave entries after the Twilight entries. |
| **A bug from DC-1, fixed** | A stray `if` split the dock's `if/elif` button chain, so in some states the first-expedition debrief button could appear beside the Twilight one. The chain is rejoined and a test pins the buttons as mutually exclusive. |

Not changed: save schema (10, twelve fields), missions, points, experience, combat, hull ranks, audio, the shrine,
the site, the guide.

## Draft text, for editing

`ChapterJourney.caves_debrief_text()` and `descent_offer` in `scripts/story/chapter_journey.gd`; the two Twilight
lines in `scripts/story/twilight_expedition.gd` and `twilight_shelf_data.gd`. The Furnace Vents name comes from
Story Bible p. 7; the teaser sentence is mine.

## Tests

`tests/integration/test_drowned_caves_debrief.gd` (10 tests): default-on with exclusive dock buttons; the new wording
and Twilight text; the debrief waits for Mara's log and for Halcyon; four sentinel/crystal state variants; the
teaser, the record count and no hostile words; showing the debrief saves and awards nothing; the dock log lists cave
records. `test_drowned_caves.gd` covers the `--no-drowned-caves` switch. Eight mutations were run by hand, each failing
a test, then reverted.

## Release safety

`ReleaseSmoke._verify_caves_debrief` runs in the exported binary after the return to Halcyon. The harness no longer
forces the descent on, so a passing run also proves it is on by default in the real export. It requires the
CavesDebrief button, no ChapterDebrief button, the debrief text and teaser, the calibration line, a Back button that
returns to the dock, and an unchanged checkpoint file. It prints `RELEASE_CAVES_DEBRIEF_WIRING_PASS`;
`--break-caves-debrief-wiring` disables the debrief and must fail with `RELEASE_CAVES_DEBRIEF_WIRING_FAIL`.
`tools/smoke_playtest.py` and the Linux and Windows CI loops include it.

Local result on a real Linux export: positive 5 of 5; all 26 `--break-*-wiring` negatives fail with their specific
token. The Windows run is CI-only.

## Manual route

Launch a playtest build (no flag), finish Twilight and claim the debrief, press "Descend to the Drowned Caves", fly
through the squeeze or the long way, record Mara's log in the far chamber, optionally the other records and the
shrine, return to the anchor and dock. Choose "Drowned Caves expedition debrief" and check the page matches what
you did. Repeat with `-- --no-drowned-caves`: no descent button.

## Known limitations

- **No human has played the chapter.** Pacing, oxygen tension, the squeeze and the 20 to 30 minute target are all unmeasured.
- Every new line of text and all cave art are drafts; the +200 sonar upgrade is a default the designer has not named.
- The Keepers, the Listeners, the Wardens and next-zone guide lights have no presence: the flags only record choices.
- The Zone 4 teaser promises nothing playable.
- Because the descent is now visible by default, testers will reach untested content. The Windows executable has only run in CI.
- Older `docs/testing/dc-1` to `dc-5` pages mention the `--drowned-caves` flag; it is no longer needed.
