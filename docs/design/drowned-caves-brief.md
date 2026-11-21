# The Drowned Caves (Zone 3) — chapter brief

**Status: DRAFT FOR USER APPROVAL. No implementation is authorised by this document.**
Each numbered issue below becomes one issue and one PR after the user approves this brief and
answers the open decisions in §4. All numbers are provisional and live in Resources, never constants.
Issue numbers (DC-1…DC-6) are placeholders; real BTA numbers are assigned on approval.

## 1. Why this exists

The user asked for the next chapter. The Story Bible (`docs/story/Below_the_Abyss_Story_Bible.pdf`,
page 6) defines it as **Zone 3, The Drowned Caves (1,000–2,000 m)**. The Twilight debrief already points
at it: "The Drowned Caves are the next investigation; that region is not playable"
(`TwilightShelfData.missions()`), and Mara's third log ends "The next descent is not charted by this damaged
recorder." Both are deliberate hooks, not implementation.

`docs/design/twilight-redesign-brief.md` §4 says "No Zone 3 … no story or dialogue canon changes" until an
approved brief exists. This is that brief. A chapter is a multi-PR milestone (Twilight was BTA-053 to 061);
it cannot be one change, and several parts of it are story decisions the designer owns.

### Canon taken from the Bible (page 6)

> Flooded limestone caves that were dry land during the Ice Age. Tight passages make oxygen the main
> pressure. Deep inside, ancient human handprints and paintings show tall glowing figures and a battle.
> Beside them, Vael glyphs tell the same story from their side. This is the site of first contact. Mara's
> logs show she found it too and realized the Choir is a language. Wick can now translate simple glyphs,
> and you learn of the Vow of Silence.
>
> **Key choice:** A Vael memory crystal rests in a shrine. Leave it, and the Listeners notice: the first
> guide lights appear in the next zone. Take it for Tethys, and you get a major upgrade, but the shrine
> collapses behind you and the Keepers turn cold.

The Bible also says the Twilight sentinel choice pays off here: a **released** sentinel "guides you through
Zone 3"; a **captured** one marks you with the Wardens.

### What the code says (verified, not guessed)

| Fact | Where | Consequence |
| --- | --- | --- |
| Twilight's authored basin reaches **1,120 m** (`gate_rank = 2`); the gate rank rates it safe, lower ranks buckle. | `resources/balance/twilight_depth_gate.tres` | Zone 2 as built already overlaps the Bible's 1,000 m start of Zone 3. |
| Effective hull ratings in Twilight are 1,000 / 1,100 / 1,150 / 1,200 m (rank 1–4 on a 1,000 m baseline). | twilight-redesign-brief §1 (measured then) | **A 1,000–2,000 m zone exceeds every rating the player can reach.** See decision A. |
| Depth is a per-region linear map from local Y (`meters_per_unit`). | `scripts/world/depth_mapping.gd` | A region can be authored at any scale; the number the player reads is a Resource. |
| Tunnels, closable gates, vents and a two-shot excavation rule already exist. | `scripts/world/twilight_tunnels.gd`, `resources/world/twilight_*_tunnel.tres` | "Tight passages" reuse them; no new navigation tech. |
| Oxygen drain is `0.03/s` in Twilight; zero starts a 60 s countdown; expiry recovers at Halcyon with a free restock. | `resources/balance/twilight_resources.tres`, `vessel_recovery.tres` | "Oxygen is the main pressure" is a Resource retune plus a layout, not new rules. Failure costs only position, by design. |
| The sentinel choice is stored as story decisions `zone2-sentinel-release / capture / lost`. | `TwilightShelfData` | The payoff can read existing state; no new save field is needed for it. |
| Save schema 10 has twelve top-level fields; Twilight added none. | `docs/design/twilight-redesign-brief.md` §4 | Target: **no schema change**. |
| Twilight, Sunlit and the combat box have had **no stranger playtest**. | `docs/HANDOFF.md` §6 | See §5, the main risk. |

## 2. Proposed scope

One chapter, ~20–30 minutes for a first-time player (a target, not a measurement). Content contract from
`GDD.md` §6, each item mapped:

| Requirement | Proposal |
| --- | --- |
| Primary goal | Reach the first-contact chamber and record the paintings, the glyph wall and Mara's cave log. |
| Optional discovery | Two optional side passages with geology / cave-fauna records (blind pockets, no compulsion), like BTA-056. |
| Navigational landmark | A lit stalactite column visible from the entrance and from the chamber's approach. |
| Memorable environmental event | The sentinel guide (if released) or a silent, unlit approach (if captured/lost). |
| Gate or alternative route | A flooded squeeze that a pressure-rank or an excavation shot opens; the long way round stays open. |
| Safe return path | A cave anchor and ascent line (the Twilight tether pattern) so oxygen failure is never a dead end. |

Explicitly **out of scope**: combat, new creatures, currency, Zone 4, Tethys drones, a glyph puzzle or glyph
HUD, the Stalker, a Warden fight, any audio asset purchase.

## 3. Proposed issues (one PR each, merged in order)

1. **DC-1 Region foundation.** Zone 3 region Resources (layout, depth mapping, pressure fit), entry from the
   Twilight basin after debrief, chapter journey object parallel to `TwilightExpedition`. Continue/save
   round-trip with no schema change. Release-smoke wiring plus a negative `--break-*-wiring` case.
2. **DC-2 Cave navigation and oxygen.** Authored passages, one squeeze gate, return anchor, oxygen retune by
   Resource. Reuses tunnels/excavation. Teaches nothing it cannot signal with text and a visual cue.
3. **DC-3 Sentinel payoff.** Released: guide-light waypoints toward the chamber (optional, never required).
   Captured/lost: no guide, text-only Keeper reaction. **No hostility** (see decision D).
4. **DC-4 First-contact site.** Paintings, glyph records, Mara's cave log, Wick's simple-glyph annotations as
   authored text, the Vow of Silence as a record. All new text flagged for designer review.
5. **DC-5 Memory crystal choice.** Leave/take, Resonance ±15, shrine collapse presentation, the reward.
6. **DC-6 Debrief and chapter close.** Halcyon acknowledgement, Zone 4 teaser line ("not playable"), docs,
   release smoke, human-playtest instructions.

Every issue: keyboard and gamepad parity, non-colour/non-audio cues, Reduced Flashing/Motion/High Contrast,
1280×800 and 800×600, no new permanent HUD line, no side effects in `assert()`, new wiring covered by
`ReleaseSmoke` with a negative case, `tools/lint_release_safety.py` passing, and the Windows and Linux
packages smoked in CI.

## 4. Decisions only the designer can make (recommended default in bold)

| # | Question | Recommended default |
| --- | --- | --- |
| A | **Depth.** The Bible says 1,000–2,000 m; no reachable hull rating exceeds ~1,200 m. | **Give Zone 3 its own pressure-fit baseline (as Twilight has) so ranks 1–4 rate it safely, and author the cave at the Bible's numbers.** Alternative: compress the displayed depths to ~1,000–1,200 m. Adding hull ranks is an economy change and is not recommended. |
| B | **Crystal reward.** The Bible says "a major upgrade" for taking it; the Zone 2 reward is "credits". The GDD forbids a currency and farming. | **One bounded, one-time Resource-authored upgrade in the existing research system (like the sentinel's +100 sonar-range calibration). No credits.** Which upgrade is yours to name. |
| C | **Glyph translation.** "Wick can now translate simple glyphs." `docs/story/README.md` says glyph puzzles and a glyph HUD need separate scoping. | **Text-only annotations on scanned records. No puzzle, no HUD.** |
| D | **Warden consequence for a captured sentinel.** The Bible says the Wardens mark you. `HANDOFF.md` §7 says build no more combat until the combat test box is played. | **Defer all hostility.** Captured/lost changes dialogue and removes the guide only. Warden pursuit waits for the playtest result. |
| E | **Resonance numbers.** The Bible fixes ±15 for a zone choice and calls tuning provisional. | **±15 for the crystal; ±1–3 small actions are not built in this chapter.** |
| F | **New canon text.** Mara's cave log, glyph annotations and the Vow of Silence are authored adaptations. | **Draft from the Bible, flag every new line, designer edits before merge.** |
| G | **Target duration.** | **20–30 min for a first-time player, unmeasured until a human plays it.** |

## 5. Risk the designer should weigh before approving

- **Building a third chapter on unvalidated ground.** Nobody outside the project has played Sunlit, Twilight or
  the combat box. If pacing or controls are wrong, every chapter inherits it. Zone 3 involves no combat, so
  `HANDOFF.md` does not forbid it, but the cheapest way to spend the next hours may still be the playtest.
  A published draft pre-release (`playtest-2026-11-20`) is waiting for that.
- **Oxygen-as-pressure plus tight passages is the likeliest frustration** in a game whose failure already
  costs nothing. The recovery design means "tense" must come from visible choices, not loss. Expect to retune
  after human play.
- **Six PRs of review.** Each is a day-scale change for the designer to read, as Twilight was.

## 6. What approval means

Approving this brief authorises DC-1 only, once decisions A–D have answers. Each later issue starts after the
previous one merges and its CI is green. Nothing here changes `GDD.md`, the save schema, the Story Bible or
any existing record ID.
