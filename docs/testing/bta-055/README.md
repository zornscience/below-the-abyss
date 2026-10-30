# BTA-055 — The Twilight Shelf: The Severed Line

Based on the published BTA-054 branch `838a862`, which is not yet merged into main
(`67a6a0e`, PR #37). **Merge/review BTA-054 first.** This branch depends on its art,
wildlife and thermal-vent systems; no automatic merge is authorized.

The chapter's canon is the user-supplied Story Bible, p. 6, and its implementation
uses the approved [Twilight design](../../design/twilight-shelf.md). Dialogue and
three field-log transcriptions are newly authored adaptations, not quotations from
the PDF. No Mara fate, Lantern-1 wreck location, Choir explanation or Crane secret
is disclosed. The wooden whaler is not Lantern-1. The marking is untranslated.

## Expedition

Begin at the existing fully commissioned 350 m pocket, with Halcyon out of view.
Investigate the western whaler gallery and eastern severed cable in either order.
Scan the cable cut, recover Mara's first field log, record the whaler marking and
scan the trapped sentinel/net. Two detached loggers are optional. Visible subjects
use normal Interact scanning; active sonar still reveals at wavefront arrival and
passive contacts remain temporary and non-discovering.

Interact at the scanned net to release the animal or secure its living cradle.
Capture requires confirmation. Both take six simulation seconds; moving outside
240 units or Interact cancels before commitment. Pausing freezes progress. After
commitment, repeat interaction is read-only. Release uses the existing bounded,
collision-safe acoustic creature navigation toward the local return passage.

Use the starting ascent tether to return to Halcyon. Refitting remains available
before finishing the investigation. Returning with all required evidence completes
the mission; **Twilight expedition debrief → Archive expedition** claims it once.
The conclusion establishes the Drowned Caves as the next investigation without
opening that region. Resume remains available for optional records/exploration.

## State, rewards and weapon rule

No independent chapter ledger or file. ResearchRegistry owns scans, StoryState owns
one exclusive sentinel decision, MissionService owns acceptance/objectives/claim,
and the existing atomic checkpoint owns their transactions and recovery.

- Release +15 hidden Resonance; capture −15. No numeric morality UI. The immediate
  response reads the actual choice, not the ±40 tiers. Release stores a future-guide
  flag; capture stores a wary-Warden flag. No Zone 3 implementation.
- Common one-time debrief allowance: **2 research points**. Live-capture delivery:
  **+1 research point** and a unique **+100 world-unit sonar range** calibration.
  Costs/cooldowns are unchanged. Rebuild from baseline + talents + delivered award;
  reopening/refitting/reloading never stacks the effect. No second currency.
- Optional logger scans use the existing 30-XP first-record rule and lifetime cap
  of two science bonus points. No separate optional-research payout.
- The critical animal is damageable using the existing BlastReceiver. Killing it
  commits a −15 loss decision, preserves the net as scannable evidence and permits
  completion, but grants no live bounty/calibration. There is no kill reward.
  A released animal can also be killed; an extra permanent casualty flag invalidates
  its future-guide eligibility without replaying a choice or reward. Future chapter
  code must check both release and absence of this casualty flag.
- Failed casualty writes leave a visible pending report and block unrelated saves;
  Interact retries. Other failed choices/claims grant nothing and preserve prior
  checkpoints. Partial creature health is transient, as in existing wildlife; a
  committed death/decision is permanent. No new combat system.

## Save compatibility

Expedition schema **10**, same twelve top-level fields and same checkpoint path.
Versions **1–9** remain validated and migrate without inferring new evidence,
choices or allowances. The mission catalogue extends 2/5/6 records to seven while
preserving old IDs/states. Old deep-preview saves accept the new available mission
on intentional Continue; position, supplies, ammo and research allocations survive.
Loading/recovery does not replay choice/claim events or commission/refill a vessel.
Existing atomic replacement, write-ahead backup, rejected-file recovery, monotonic
history and conflict checks remain authoritative. Old builds reject schema 10;
keep backups and use the updated build for these campaigns.

Only the Twilight active region changes drain tuning: idle 0.003, full thrust 0.009
battery/s, oxygen 0.02/s. A conservative 45-minute continuous full-thrust budget with
ten four-unit pings leaves **27.6 battery / 46 oxygen**. These are model results,
not a 45-minute human playtest. Region transitions preserve actual values before
applying the appropriate profile; Continue does not refill. Hull/pressure and all
weapon/engine talent tuning remain in their existing authorities.

## Verification

Results and native evidence are added after final verification. Reproduce with
Godot `4.6.3.stable.official.7d41c59c4`, GUT 9.6.1 and Compatibility:

```sh
godot --path .
python3 tools/validate_godot.py
python3 tools/run_tests.py
python3 tools/verify_twilight_expedition.py
python3 tools/verify_twilight_habitat.py
python3 tools/verify_chapter_handoff.py
python3 tools/verify_sunlit_shallows.py
python3 tools/verify_expanded_expedition.py
python3 tools/verify_revision_two.py
python3 tools/verify_story_choice.py
python3 -m unittest discover -s tests/python -v
python3 tools/build_playtest.py
python3 tools/smoke_playtest.py build/below-the-abyss-playtest-linux-<build-id>.zip
```

The new fixture uses actual movement, Interact, sonar, pause, and keyboard/controller
focus-next/accept events, never teleports or programmatic button activation. It runs
west-first/release and east-first/capture, then separate-process Continue/debrief
replay checks. Native captures use the same route at 1280×800 normal visuals and
800×600 Large Text/High Contrast/reduced presentation, both muted.

## Manual playtest

1. Finish the buoy chapter, then Begin deep expedition. Check full initial reserves,
   350 m and the nearby ascent tether. Read or dismiss Wick's short radio.
2. Choose west first: find the whaler and record its scratched marking. Or choose
   east first: follow the broken cable and scan its clean cut, then the instrument
   below it. Missing optional loggers must not block these objectives.
3. Traverse the lower connector, passing above the erupting jets. Locate the net in
   the lower eastern basin. Scan it, then Interact again to inspect the choice.
4. Leave without choosing, cancel an operation by moving away, and pause mid-action.
   No choice, score or reward should commit until the six-second operation completes.
5. Complete release or capture on separate campaigns. Inspect the visual result,
   contextual response, research record and expedition log. No number is shown for
   Resonance. Optionally test the clearly documented lethal weapon outcome.
6. Return through the upper gully to the ascent tether. Deliberately return to Halcyon;
   inspect services/technology, then submit the Twilight debrief. Check one allowance
   and the capture-only additive sonar calibration. Reopen the debrief: no duplicate.
7. Resume, pause/save, quit/Continue. Verify actual supplies, evidence, choice and
   awards. Repeat with controller, mute, comfort preferences and 800×600. Use the map
   and research/log pages; undiscovered entries must remain hidden.

## Limitations and review gates

The agreed **30–45-minute main expedition is a human pacing target**, not a result
of passing automation. Automated route timing, human evaluation and graphics review
are reported separately. No artificial waiting is used to claim that duration.
Unfamiliar-human comprehension, actual pacing, audible mix, physical gamepad and
modest-desktop GPU/60 FPS acceptance require real playtesting.

No playable Drowned Caves, glyph translation, Vael explanation, ending, new economy,
general combat framework or replacement save architecture. Thermal ecology remains
the BTA-054 system. Sentinel art is an original generated PNG; provenance, dimensions,
import policy and licensing limits are recorded separately. Visual quality remains
subject to user/artist review.
