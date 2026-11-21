# DC-3 — Drowned Caves sentinel payoff: evidence

Third issue of `docs/design/drowned-caves-brief.md` (decision D: no hostility). **No human playtest
exists.** Every number and line is a hypothesis; all new text is for designer review. Still a
foundation: no objectives, records or story beyond one line of text per outcome.

## What the Twilight choice now does in the caves

The Twilight sentinel choice already stores authored flags (`zone2-future-guide`, `zone2-sentinel-freed`,
`zone2-sentinel-captured`, `zone2-wardens-wary`, `zone2-sentinel-lost`, `zone2-wardens-hostile`) and the
flag `zone2-released-sentinel-lost` when a freed animal is later killed. DC-3 reads them and **saves
nothing**: availability is derived, schema 10 keeps twelve fields and the journey keeps two.

| Story state | Guide lights | One arrival line (Wick/Okafor) |
| --- | --- | --- |
| Released, still alive | 10 optional lights along the long route | "A light ahead, low and steady, where the passage bends. It is not ours… The animal you freed… You do not have to follow it." |
| Released, later killed | none | "No lights ahead… The animal that would have gone first is dead. We find the way ourselves." |
| Captured | none | "No lights. The water is quiet in a way I do not like… Nothing here has moved against us. Take it slowly." |
| Lost in the net | none | "No lights, and nothing answering… The animal died in the net. If anything here remembers that, it has not shown itself." |

The released case also changes the HUD guidance line to mention the lights and says following them is
optional ("or not").

## The lights

`DrownedCavesGuide` places a light every 1,200 units along the **always-open long route** (never the
gated shortcut), ending in the far chamber. A light is a soft glow, a bright core **and a ring**, so the
marker does not depend on colour alone, plus the text line above. Behaviour by setting:

- Default: a slow swell between 85% and 100% opacity, about 0.3 Hz, never a flash.
- Reduced motion **or** reduced flashing: steady at full opacity.
- High contrast: a thicker white ring.

Lights are inert: nothing collides with them, nothing requires them, nothing gates on them. They are
hidden at Halcyon and in Twilight and shown only in the caves.

## Decision D, and a wording note on the brief

No variant is hostile. The Warden flags `zone2-wardens-wary` and `zone2-wardens-hostile` change only
words, and no creature, hunt, damage or pursuit exists in the caves (tested). Hostility waits for the
combat test box result, as `docs/HANDOFF.md` §7 requires.

The brief (§3) described the captured/lost case as a "Keeper reaction". The Story Bible (page 6) says a
captured sentinel means **the Wardens mark you**; Keepers belong to the later crystal choice. The text
here is therefore about the water and the Wardens' absence, not Keepers. Say if you want it otherwise.

## Tests

`tests/integration/test_drowned_caves_guide.gd` (12 tests): the lights derived from the long route
(spacing, ends in the far chamber, none near the plug), every variant's text present and free of
hostile words, each outcome (released, captured, lost, released-then-killed) with the guide state, radio
line and guidance text, every light in open water and the trail flyable with real collision, lights only
in the caves across a Halcyon and Twilight round trip, a fresh launch that Continues in the caves, a
checkpoint restore refreshing the guide, no hunt or habitat and no new saved state, and the swell versus
steady behaviour.

Mutations run once by hand, each failing a test then reverted: a killed released sentinel still guiding;
captured and lost also getting lights; no refresh on checkpoint restore; lights following the gated
shortcut; reduced motion ignored; a hostile word in the text; lights shown outside the caves.

## Release safety

`ReleaseSmoke._verify_caves_guide` runs in the exported binary after the DC-2 gate check. The smoke
released the sentinel, so it requires the guide to be available, visible and parented to the cave layout,
with exactly the authored trail, every light in open water, and the arrival text delivered through the
real descent. It prints `RELEASE_CAVES_GUIDE_WIRING_PASS`; `--break-caves-guide-wiring` hides the guide and
must fail with `RELEASE_CAVES_GUIDE_WIRING_FAIL`. `tools/smoke_playtest.py` and the Linux and Windows CI
loops include it.

Local result on a real Linux export: positive 5 of 5; all 23 `--break-*-wiring` negatives fail with their
specific token. The Windows run is CI-only.

## Manual route

Launch a playtest build with `--drowned-caves`. Play Twilight, release the sentinel, debrief and descend.
Expect a Wick line about a light ahead and ten soft lights leading east along the squeeze route.
Repeat with a captured and a lost sentinel: no lights, a different single line, nothing attacks.

## Known limitations

- There is no animal. The lights are the whole presence; a visible guide creature would be new art and AI.
- The lights lead along the long route, which includes the squeeze. A player who takes the shortcut
  leaves the trail; nothing punishes that.
- Resonance is unchanged (the Twilight choice already scored it). Nothing here changes it again.
- Nobody has judged whether ten lights read as a guide or as decoration.
- A freed sentinel that is killed later is only detected through the existing flag; if a future change
  stops setting it the guide would wrongly return.
- Windows: only the CI smoke runs it. No human has flown the caves.
