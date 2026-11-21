# DC-2 — Drowned Caves cave navigation and oxygen: evidence

Second issue of `docs/design/drowned-caves-brief.md` (decisions A–D approved 2026-11-21). **No human
playtest exists.** Every number below is a hypothesis. This is still a foundation, not a chapter: no
objectives, records, creatures or story. Builds on DC-1 (`docs/testing/dc-1/README.md`).

## What was built

| Area | Change |
| --- | --- |
| Passages | The DC-1 sealed wall is gone. The passage (500 units tall) now narrows into a carved tunnel system and ends in a **far chamber**, which ends against a sealed wall (DC-4's first-contact site goes there). Cave extent is about 13,800 × 2,400 units, about 1,000–1,600 m on the shared depth map. |
| Flooded squeeze | One authored squeeze: 124 units wide against a 64-unit hull (about 1.9×), 290 units long, on the **long route**. |
| Gated shortcut | A rock plug beside the squeeze. Two real torpedoes open it (one does not). It reuses the Twilight `DestructibleRock` / excavation rules exactly. |
| Reuse, not copy | The same `TunnelProfile` resource, `TwilightTunnels` node and excavation system as Twilight. Changes to shared code: a profile's payoff record is optional; the catalog functions take a tunnel set; `TwilightTunnels` takes a `systems` set; cut validation finds a gate in either set. Twilight data and behaviour are unchanged (its tests pass untouched). |
| Oxygen (decision: retune by Resource) | `resources/balance/drowned_caves_resources.tres`: oxygen drain **0.3 / s**, ten times Twilight's 0.03. A full tank lasts about **333 s (5.6 min)**. Battery rates and capacities are Twilight's. |
| Hints | Two non-modal Wick cards: **the squeeze** (within 900 units of the passage end: hull width, long route always open, two torpedoes for the shortcut) and **oxygen is the clock** (once oxygen is below 80%: the tank time computed from the Resource, the anchor refill, the 60 s countdown). Both are text plus the existing hint card, once per session, off in Twilight. |
| Honest labelling | Guidance, pause brief, descent offer and arrival notice describe the actual build and still say there are no objectives. |

Not changed: save schema (still 10, twelve fields), the journey phases, story, records, research
points, combat, audio, the Rift Stalker, darkness. All new player-facing text is flagged for designer
review.

## Authored numbers (derived from the data, not coordinates in tests)

| Quantity | Value |
| --- | --- |
| Anchor to far chamber, long route | 11,590 units |
| Anchor to far chamber, shortcut | 10,850 units (**740 shorter**) |
| Round trip at top speed (240 u/s), long route | 97 s |
| Full tank | 333 s, 3.45 times that round trip |

A test keeps the tank between 2 and 4 times the authored round trip, derived from the layout and the
motion Resource, so a retune that breaks the intent fails.

## Tests

`tests/integration/test_drowned_caves_navigation.gd` (12 tests): data validity and scale, Twilight
lookup unchanged, long route open and shortcut closed with real collision, a hull wider than the
squeeze rejected and a narrower one admitted, one torpedo not enough and two enough, a cut being a valid
checkpoint that replays on Continue and survives the Halcyon round trip, Twilight and cave gates never
active together, the oxygen rate (a real physics step drains at the authored rate and Twilight returns to
its own), the tank band, oxygen exhaustion running the countdown and recovering at Halcyon, both hints, and
the hints staying out of Twilight (with a positive control at the same spot).

Mutations run once by hand, each failing a test then reverted: cave gates missing from cut validation;
caves resources not applied; cave hints firing in Twilight; cave gate never enabled; oxygen not retuned;
squeeze as wide as the passage. **The Twilight-hint mutation was not caught at first**: another hint (sonar,
depth) held the single hint slot, so the negative test could not fail. It now clears those hints and has a
positive control.

## Release safety

`ReleaseSmoke._verify_caves_gate` runs in the exported binary after the DC-1 descent check. It requires the
gate rock registered with the real excavation system, parented to the cave tunnels and solid; the caves on
their own oxygen rate; one real excavation of the gate to carve; and the resulting journal to be valid and to
restore. It prints `RELEASE_CAVES_GATE_WIRING_PASS`; `--break-caves-gate-wiring` unregisters the gate and must
fail with `RELEASE_CAVES_GATE_WIRING_FAIL`. Both `tools/smoke_playtest.py` and the Linux and Windows CI loops
include it.

Local result on a real Linux export: positive 5 of 5; all 22 `--break-*-wiring` negatives fail with their
specific token. A first version fired two blasts at the same point; the second had nothing left to cut (a
harness mistake, not a game defect, since the test fires two real torpedoes), so the smoke now checks one real
cut. The Windows run is CI-only.

## Manual route

Launch a playtest build with `--drowned-caves`, finish the Twilight debrief, descend from the Halcyon dock.
Fly east. Expect the squeeze hint near the passage end, then either take the squeeze (thrust gently) or stop
short of the plug and fire two torpedoes. Expect the oxygen hint after the first minute, the gauge falling about
a third per minute, and a countdown plus recovery at Halcyon if it reaches zero. The far chamber ends in rock.

## Known limitations

- **The shortcut barely matters for oxygen.** It saves 740 units, about 3 seconds each way at top speed, about
  2% of a tank. Its real value is skipping the squeeze handling. If playtesters should feel an oxygen
  trade-off, the long route needs a longer detour; that is a layout change for after a human has flown it.
- A full tank is 5.6 minutes with a 97 s top-speed round trip. A first-time player will take longer, but this
  has not been measured. Failure costs only position, by design, so tension must come from the visible gauge.
- The caves stay lit (the headlight only). The earlier DC-1 note that "visibility is DC-2" is withdrawn:
  the designer's feedback was that playing everything in the dark would be annoying, and no darkness or echo
  reveal was added.
- The blind pocket off the long route (a required part of the tunnel data) is an empty dead end: there are no
  records until DC-4.
- No second hint is shown if another hint is on screen at that moment (one at a time, existing rule).
- Passage and squeeze scale are untuned graybox values; nobody has flown them.
- Windows: only the CI smoke runs it.
