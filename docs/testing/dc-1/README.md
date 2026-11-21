# DC-1 — Drowned Caves region foundation: evidence

Approved by the designer on 2026-11-21 (decisions A–D at the brief's recommended defaults, see
`docs/design/drowned-caves-brief.md`). **No human playtest exists.** This is a foundation: one
entry chamber, one passage that ends against a sealed wall, and the plumbing around it. It is not a
chapter. All evidence below is automated, from a Linux container with no GPU.

## What was built

| Area | Change |
| --- | --- |
| Journey phase | `ExpeditionJourneyState` accepts phase `caves` and region `drowned_caves`. A `caves` checkpoint is valid only when the journey is commissioned **and the Twilight debrief is claimed**, and its `region_id` must match. Phase and region sets are the only validator change. |
| Save compatibility | Schema version stays 10 with twelve top-level fields. Every older checkpoint still loads unchanged (tested). A checkpoint written in `caves` cannot be read by an older build, because the older validator rejects an unknown phase. |
| Pressure fit (decision A) | `resources/story/drowned_caves_pressure_fit.tres`, baseline 2,000 m. Ratings are 2,000 / 2,100 / 2,150 / 2,200 m for hull ranks 1–4, so every rank rates the Bible's 1,000–2,000 m range safe. Twilight's 1,000 m baseline and the 1,120 m basin gate are untouched. |
| Region | `DrownedCavesLayout`: graybox chamber with a stalactite column, a 500-unit passage and a sealed east wall, at about 1,000–1,600 m on the shared depth map. The anchor is at about 1,200 m. Geometry only; no records, creatures or objectives. |
| Entry | `ChapterJourney.offer_caves()` / `descend_caves()` through `SaveCoordinator.transfer_chapter("caves", true)`, only from Halcyon, only after the debrief is claimed, always fully supplied. The dock button appears only when `ChapterJourney.caves_entry_enabled` is set (launch with `--drowned-caves`; tests and the release smoke set it directly). |
| Return and recovery | The cave anchor returns to Halcyon through the existing refit transfer. Hull destruction or life-support expiry in the caves recovers at Halcyon with a free restock through the same checkpoint path. |
| Honest labelling | Pause menu, tracker, arrival notice and dock text all say "foundation build · entry chamber only · no objectives". |

Not changed: story, dialogue, the Twilight debrief text (it still says the caves are not playable),
research points, any currency, hull ranks, combat, audio, the Rift Stalker, `GDD.md`.

## Why the entry is hidden

A tester who finishes Twilight would otherwise be offered a dead-end chamber. The flag keeps the
foundation out of ordinary play until DC-6 turns it on.

## Tests

`tests/integration/test_drowned_caves.gd` (12 tests): refusal before the debrief is claimed, the
developer flag and full-restock rules, a valid checkpoint (region, schema version, field count,
decode), pressure rating for every rank, depth range, Continue, validator and schema forgery
rejection, an old Twilight checkpoint still loading, anchor return and the Twilight rating restored,
recovery from the caves, the recovery flow treating the caves as a campaign chapter, geometry and a
real vessel sweep from anchor to passage end.

Mutation checks run once by hand (each must fail a test, then was reverted): unlocking the caves
without the claimed debrief; dropping the caves pressure fit; ignoring the caves in recovery;
dropping the claimed-debrief validator rule; removing the sealed wall. The last one was **not**
caught at first (the probe sat outside the camera bounds, so the bounds check refused it, not rock);
the probe was moved inside the wall and the mutation is now caught.

## Release safety

`ReleaseSmoke._verify_caves` runs in the exported binary after the existing depth-gate checks. It
claims the Twilight debrief through the real evidence scans, the sentinel release, the tether refit
and the claim; descends through the real `descend_caves()`; then checks the phase, region in the
written checkpoint, pressure rating, solid geometry, an open anchor and passage end, a sealed east
wall, and the anchor return. It prints `RELEASE_CAVES_WIRING_PASS`. `--break-caves-wiring` disables
the cave geometry after the descent and must fail with `RELEASE_CAVES_WIRING_FAIL`. Both
`tools/smoke_playtest.py` and the Linux and Windows CI loops include it.

Local result on a real Linux export: positive run 5 of 5; all 21 `--break-*-wiring` negatives fail
with their specific token. The Windows run is CI-only.

### A crash found on the way

A first version of the smoke stage ended with the combat-box proof changing scene in the same frame
as the stage's last simulation toggles. Release exports segfaulted (a deferred `_layout_tutorial` and
`gui_get_focus_owner` call reached a null viewport after the scene left the tree); a debug export only
printed `SCRIPT ERROR`. The stage now flushes two frames before the scene change. The underlying
fragility in `ShelfPrototype._layout_tutorial` and the UI focus calls was **not** changed here, because
only this harness reaches it; it is recorded as a known hazard.

## Manual route

Launch a playtest build with `--drowned-caves`, finish the Twilight debrief, open the Halcyon dock and
choose "Descend to the Drowned Caves (foundation build)". Fly east through the passage to the sealed
wall. Return to the cave anchor and press Interact for Halcyon. Expected: no objectives, no records, the
pressure readout shows a rating of at least 2,000 m, and Continue after quitting resumes in the caves.

## Known limitations

- No human has flown the chamber; the passage width and scale are untuned graybox values.
- The caves use Twilight's resource and action-cost profile; oxygen pressure is DC-2.
- The caves are not dark and have no echo reveal; visibility is DC-2.
- A caves save cannot be opened by an older build.
- Windows: only the CI smoke runs it.
