# DC-5 — Drowned Caves memory crystal choice: evidence

Fifth issue of `docs/design/drowned-caves-brief.md`. **No human playtest exists. All text and art are drafts,
and the upgrade is a placeholder default the designer has not named.**

## The decision, as the Bible and the brief define it

Story Bible p. 6: a Vael memory crystal rests in a shrine. **Leave it** and the Listeners notice (the first
guide lights appear in the next zone). **Take it for Tethys** and you get a major upgrade, the shrine collapses
behind you and the Keepers turn cold. Brief decision B: one bounded, one-time, Resource-authored upgrade, no
credits; decision E: +15 resonance for the crystal; decision D: nothing hostile.

## What was built

| Area | Change |
| --- | --- |
| The encounter | `zone3-memory-crystal`: two exclusive story choices in the shared story catalog. **Leave: +15 resonance**, flags `zone3-crystal-left` and `zone3-listeners-noticed`. **Take: -15**, flags `zone3-crystal-taken` and `zone3-keepers-cold`. Neither has a research record, so no points or experience. The flags change words and later zones; here nothing is hostile. |
| The shrine | `DrownedCavesShrine` in the far chamber, 850 units south of the chamber centre. Interact beside it: a page with "Leave the crystal in its niche" and "Take the crystal for Tethys"; taking asks to confirm and states the upgrade and that the shrine cannot be restored. Back decides nothing. A prompt appears only beside the shrine, in the caves. |
| The upgrade (**placeholder default**) | `resources/campaign/tethys_calibration.tres`: **+200 sonar range**, once, derived from the saved *take* decision in `ExpeditionRevision.capabilities`. There is **no new award**: it cannot disagree with the story state, and Continue or a fresh launch re-derives it. Change the number in the Resource. |
| The collapse | After taking, rubble is drawn over the niche. It has **no collision**, so the choice can never block a route. |
| Save | The choice is committed atomically with its resonance and flags through the story writer, like Twilight's net. It is refused unless the vessel is in the caves, beside the shrine and in clear water. The schema rejects a crystal decision in a checkpoint whose Twilight debrief is not claimed. Schema 10, twelve fields, journey two fields. |
| Guidance | Until the shrine is decided, the line after Mara's log mentions "a crystal shrine" as optional. |

Not changed: missions, research points, experience, hull ranks, combat, audio, the Twilight debrief text.

## Why +200 sonar, and what it costs (please decide)

The Bible says "a major upgrade" without naming it. I excluded the alternatives for stated reasons:

- **Hull rating**: would make Twilight's tuned depth gate trivial.
- **Torpedo upgrades**: combat; `docs/HANDOFF.md` §7 says build no more combat before the test box is played.
- **Engine**: changes the handling the combat box is meant to test.
- **Sonar range**: no gating or combat, and Twilight already has the same kind of reward (+100 for a captured sentinel). It stacks with that one.

The cost: a ping's audible range equals its reveal radius, so **a larger radius makes creatures hear pings from farther**, including the Rift Stalker in Twilight. 200 units is a tenth of the top rank, and it is one number to change or replace.

## The draft text, for editing

Shrine page, leave response, take confirmation and take response are in `scripts/story/drowned_caves_data.gd` and
`resources/story/crystal_leave.tres` / `crystal_take.tres`. Bible facts used: a Vael memory crystal in a shrine;
memories kept in living crystal; the Listeners notice if it is left; the shrine collapses, the Keepers turn cold
and Tethys rewards you if it is taken; Crane wants it for Tethys. The lines about what the crystal "would do if it
were moved", and Okafor's "We cannot undo it", are mine and are the ones to read first.

## Tests

`tests/integration/test_drowned_caves_shrine.gd` (11 tests): the two choices valid and exclusive with +15 and -15;
the shrine in open water away from the anchor and the other records; the prompt and interact only beside the
shrine and only in the caves; Back deciding nothing; leaving (resonance, flags, no capability change, response
page, atomic checkpoint, exclusivity); taking (confirmation, resonance, flags, +200 sonar once, no stacking, the
collapse flag); the calibration surviving Continue and a fresh launch; no points, experience, award or mission
change; the decision refused away from the shrine, at Halcyon and in Twilight; a crystal decision before the
debrief rejected by the schema; guidance.

Mutations run once by hand, each failing a test then reverted: no calibration for taking; leaving granting it;
taking scoring positive; no proximity gate; no debrief rule in the schema; no sonar re-apply after the decision;
taking without confirmation; the shrine live everywhere. **One was not caught and cannot be by a unit test: the
rubble drawing.** The `taken()` state it depends on is tested; the painted result needs human eyes or a
screenshot, and has not been seen.

## Release safety

`ReleaseSmoke._verify_caves_shrine` runs in the exported binary after the site check. It requires both choices in
the story catalog and the calibration Resource valid, then drives the real page buttons: Interact beside the shrine,
Take, Confirm. It requires the decision, the -15 resonance, the authored sonar increase, a checkpoint that contains
the decision and decodes, and the collapsed state. It prints `RELEASE_CAVES_SHRINE_WIRING_PASS`;
`--break-caves-shrine-wiring` disables the shrine and must fail with `RELEASE_CAVES_SHRINE_WIRING_FAIL`.
`tools/smoke_playtest.py` and the Linux and Windows CI loops include it.

Local result on a real Linux export: positive 5 of 5; all 25 `--break-*-wiring` negatives fail with their specific
token. The Windows run is CI-only.

## Manual route

Launch a playtest build with `--drowned-caves`, finish Twilight and the debrief, descend and fly to the far chamber.
Go to the shrine at the south of the chamber and press Interact. Choose Leave: the crystal keeps its glow. In a new
run choose Take, confirm, and see the rubble and a longer ping reach. Quit and Continue: the longer reach stays.

## Known limitations

- **The upgrade is my default, not your decision.** See above.
- The collapse drawing and the shrine art are placeholder shapes, and the collapse has not been seen.
- A caves save containing either decision cannot be opened by an older build.
- The Keepers, the Listeners and the next zone's guide lights have no presence yet: the flags only record the choice.
- A taker's larger ping is heard from farther by creatures, including the Stalker in Twilight.
- There is no way to undo the choice; that matches the Bible and the confirmation says so.
- Windows: only the CI smoke runs it. No human has flown the caves.
