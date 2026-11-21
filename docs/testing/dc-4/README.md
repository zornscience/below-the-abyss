# DC-4 — Drowned Caves first-contact site: evidence

Fourth issue of `docs/design/drowned-caves-brief.md`, built on the designer's "go with the defaults" of
2026-11-21. **No human playtest exists. All new text and all art are drafts for the designer to edit.**
Still no mission, no story page and no research reward.

## The designer's defaults, as applied

| # | Decision | Applied |
| --- | --- | --- |
| 1 | What is required | Only Mara's chamber log. The paintings and the glyph wall are optional codex scans. |
| 2 | Mara's logs | Two: field log 04 (required, far chamber) and field log 05 (optional, in the squeeze's blind pocket, which was an empty dead end). |
| 3 | Glyph vocabulary | Three plain meanings, proposed by me because the Bible leaves it open: **silence, deep water, withdrawal**. |
| 4 | The Vow of Silence | Learned from Wick's note on the glyph wall, as text only. No puzzle, no HUD. |
| 5 | The paintings | Placeholder shapes drawn in code (handprints, two tall glowing figures, a small group, glyph rows, two recorders). No asset was invented. |
| 6 | Rewards | None: no research points, no experience (tested). |
| 7 | Saves | Records live in the existing research list. No mission, no schema change. |
| 8 | The Resonance glyph on the HUD | Deferred; the Bible lists it as an open decision. |

## What was built

| Area | Change |
| --- | --- |
| Records | `DrownedCavesData`: four scan records (`caves-mara-log-one` required, `caves-paintings`, `caves-glyph-wall`, `caves-mara-log-two`) with positions derived from the layout and the tunnel profile. |
| Shared catalogs | `TwilightShelfData.catalog_records()` = Twilight's records plus these four. The research and discovery catalogs, and therefore the save validator's allowed ids, use it. `all_records()` stays Twilight-only because its callers build Twilight subjects, sonar echoes and log entries. Twilight's authored list is unchanged (17 records, tested). |
| Discovery bounds | The Twilight discovery catalog's survey bounds grew from 39,000 x 5,200 to 57,000 x 8,200 so the cave points validate. Only the legacy prototype map, which has no chapter bounds, frames the whole catalog; it will show the old region smaller. |
| Scan gate | `DrownedCavesSite` chains the existing research completion gate. A cave scan is an atomic checkpoint, refused at zero oxygen as "NOT RECORDED", exactly as in Twilight. Other chapters' ids pass through to their own gates. |
| Text on scan | Each scan delivers its authored text as a Wick or Mara radio entry and lists it in the expedition log (also at the Halcyon dock). |
| Guidance | "scan Mara's recorder" until the required log is done, then "Mara's log recorded · the paintings and glyph wall are optional · return to the anchor". |
| Scan targets | Enabled only in the caves, as Twilight's are only in Twilight. |
| Labelling | The descent offer, pause brief and arrival notice now say there is a first-contact site and still say there is no mission or story page. |

Not changed: save schema (10, twelve fields), journey phases, the Twilight debrief text (still says the caves
are not playable), the sentinel payoff, oxygen, combat, audio.

## The draft text, for editing

Bible facts used: ancient human handprints and paintings of tall glowing figures and a battle; Vael glyphs
telling the same story from their side; Mara realising the Choir is a language; Wick reading simple glyphs;
the Vow of Silence; first contact ending in violence on both sides. Everything else below is mine.

- **Cave paintings / first contact (Wick):** handprints in pale pigment ringing the wall; taller painted
  figures outlined in a faintly glowing pigment; one scene of the two groups facing each other and one of a
  struggle. Wick says the pigment is older than anything dated on the shelf and that the scenes do not say
  who began it. Okafor says to keep the order of the scenes and not clean the wall.
- **Vael glyph wall / the other side (Wick):** light-writing in the same order as the scenes. Wick reads three
  marks (silence, deep water, withdrawal) repeated after the struggle "as if they were being sworn", calls it a
  Vow of Silence and says he does not know who it was made to or what it cost.
- **Mara / field log 04 (required):** she sat before the wall until her lamp dimmed; the marks repeat in the
  order of the song she has recorded for months; "It is a language, and the wall is the same story told twice,
  once by each side"; she will stop calling the Choir a sound; she left the recorder for the next person and
  asks them not to clean the wall.
- **Mara / field log 05 (optional, blind pocket):** the squeeze took more air than planned; she shut everything
  off to listen; the song was closer and slower "as if it were being said carefully for someone still
  learning it"; she counted breaths so as not to count the oxygen.

The exact wording is in `scripts/story/drowned_caves_data.gd`. Two lines go beyond the Bible and are the ones
to look at first: Wick's "I do not know who it was made to, or what it cost them", and Mara's "said carefully
for someone still learning it".

## Tests

`tests/integration/test_drowned_caves_site.gd` (12 tests): four records registered in the shared catalogs with
Twilight's list unchanged; every record a valid log entry and the text inside the Bible's facts; positions in
open water in the far chamber and the pocket; each record scanned with the real scanner and its text and source
delivered and logged; a scan being a checkpoint that decodes and survives Continue, with a forged cave id
rejected; scans refused out of range and outside the caves; Twilight scans still working; no points, no
experience and no mission change; guidance; and a cave scan at zero oxygen refused and a Twilight scan at zero
oxygen still refused through the chain.

Mutations run once by hand, each failing a test then reverted: cave records missing from the catalog; records
scannable everywhere; no text on scan; records missing from the log; guidance never completing; the optional log
moved into rock; the scan gate not installed; the gate swallowing other chapters. **The last two were not caught
at first**: the checkpoint test could not tell the gate from the autosave that fires when the sim pauses. They are
now caught by the zero-oxygen tests.

## Release safety

`ReleaseSmoke._verify_caves_site` runs in the exported binary after the guide check. It requires all four records
in the research catalog with live scan targets, then performs a real scan of the required record and requires it
to complete, deliver its authored text, and commit a checkpoint the schema accepts and that contains the id. It
prints `RELEASE_CAVES_SITE_WIRING_PASS`; `--break-caves-site-wiring` disables the site and must fail with
`RELEASE_CAVES_SITE_WIRING_FAIL`. `tools/smoke_playtest.py` and the Linux and Windows CI loops include it.

Local result on a real Linux export: positive 5 of 5; all 24 `--break-*-wiring` negatives fail with their
specific token. The Windows run is CI-only.

## Manual route

Launch a playtest build with `--drowned-caves`, finish Twilight and the debrief, descend. Fly east through the
squeeze (or open the shortcut) to the far chamber. Press Interact beside the recorder: Mara's log plays and the
tracker says the rest is optional. Scan the paintings and the glyph wall for Wick's notes. Return through the
squeeze, scan the optional log in the pocket off the long route, and fly back to the anchor.

## Known limitations

- **The art is placeholder shapes.** The paintings, glyphs and recorders are circles and lines, not a design.
- A cave save containing these record ids cannot be opened by an older build.
- The glyph vocabulary is my proposal, not canon. If the Vael words matter later, three meanings are all that
  exist.
- Nobody has judged the text, the length of the log, or whether the pocket log is worth the squeeze.
- The legacy prototype map frames a wider survey area than before.
- The Twilight debrief still says the Drowned Caves are not playable; that is DC-6.
- Windows: only the CI smoke runs it. No human has flown the caves.
