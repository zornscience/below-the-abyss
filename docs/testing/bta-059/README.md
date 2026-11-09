# BTA-059 — Optional depth gate and funded research

Base: `ccr-faf5a894-y8zz7k` at `e5af1ca`, because main lacked the corrected
“Corrected: the earlier wording contradicted itself” decision G. BTA-058 is already
in that base. The user's issue instruction approves the brief despite its draft header.

**Human playtest results do not exist. Every tuning number is a hypothesis for the
user's playtest.** The following penalty and economy figures are proposed for PR
review, not claims of player acceptance.

Complete [changed-file list](changed-files.txt).

## Acceptance and changed behavior

- `twilight_depth_gate.tres` / `DepthGateProfile`: rank 2, 1120 m crossing, approach,
  exit, lower waypoints and basin floor. `TwilightShelfLayout` extends the existing
  rock/shader/collision perimeter downward and opens access past the old bottom mass.
  Both old upper loops and required evidence remain accessible without descending.
  No tunnel, new region, darkness change, creature or asset is added.
- `TwilightShelfData` adds seven optional scientific studies: five on the safe shelf,
  two in the basin. Shared research/discovery/sonar registration builds their existing
  markers. Catalog/map bounds include them; only discovered points enter the map.
  The exact record-count assertion now expects 17 (10 existing + 7 authorized
  additions), not a weakened lower bound. The habitat discovery whitelist also includes the seven authorized optional additions; its strict membership and unchanged-progress assertions remain. Other existing assertions/timeouts are intact.
- `TwilightDepthGate`, composed by ChapterJourney, temporarily projects basin depth
  into the existing depth value near either approach. Away from the approaches it
  restores normal text. One TutorialDirector card uses the existing single-card,
  once-per-session mechanism and respects tutorials-off. **Card wording for review:**
  “The optional basin reaches 1120 m. Compare that with your hull rating. Hull rank 2
  is rated for it; lower ranks have only a brief pressure grace before damage. The
  upper shelf remains open. No required evidence lies below.” Numbers come from the
  Resource. Existing DANGER / ASCEND / PRESSURE DAMAGE ACTIVE text and hull feedback
  provide visual equivalents without flashing or an audio dependency.
- Hull destruction had no production respawn flow. Twilight now pauses simulation,
  cancels the current scan, and shows a centered explanation with one respawn button.
  Its one-line, ellipsis-trimmed footer says Enter/A respawns and Esc/B stays on the
  panel. Mouse confirmation also works. Cause text distinguishes pressure, collision
  and thermal exposure; restored checkpoints derive failure from zero hull.
- **Proposed least-punitive penalty for approval:** restore hull and relocate to the
  ascent tether; retain actual battery, oxygen, ammunition and every permanent
  discovery, research record, choice and award. Cancel only unfinished scan progress.
  There is no “unbanked sample” inventory to confiscate. Zero-hull and respawn snapshots
  use the existing atomic coordinator/schema 10; no new persisted field. Failed writes
  keep the panel open with a retry explanation instead of silently resuming unsaved.
- `ResearchExperienceData` and `twilight_experience.tres` add a bounded Twilight
  allowance derived from the existing credited/imported ID lists. Sunlit's original
  rates and cap remain identical. The research log's existing summary includes the
  aggregate cap when commissioned. Free reassignment and talent prices are unchanged.
- ReleaseSmoke, smoke_playtest and CI check runtime hull-rank application, real deep
  subject/geometry registration and hull-failure pause/presentation. Negative cases
  reset rating, disable the actual layout, or disconnect destruction wiring. Existing
  resource/visibility/registration checks remain in place.

## Depth and timing arithmetic

Twilight effective rating is `1000 + research_tree.hull_ratings[rank] − 300`.
The untouched pressure profile grants 2 s grace, then constant 4 hull/s. From full
100 hull, destruction occurs after `2 + 100 / 4 = 27 s` continuously beyond rating.
There is no new escalation multiplier or instant crush threshold.

| Hull rank | Effective rating | Authored depth | Measured unsafe time | Hull after crossing |
| --- | ---: | ---: | ---: | ---: |
| 0 | 1000 m | 1120 m | 24.2167 s | 11.1333 |
| 1 | 1100 m | 1120 m | 19.5667 s | 29.7333 |
| 2 | 1150 m | 1120 m | 0 s | 100 |
| 3 | 1200 m | 1120 m | safe by the same rule | 100 in rule test |

The route uses the actual fitted motion (base acceleration 120 units/s², maximum
240 units/s) and the existing driver steering form `(offset×1.1 − velocity×0.7)`
with braking at waypoints, capped at the normal full-thrust 240 units/s. Earlier
chapter survey drivers deliberately cap at 160; that slower pace cannot be treated
as the safe timing for an under-rated crossing. Initial acceleration to 240 takes
2 s and 240 units. Lower horizontal travel is 3100 units / 240 = 12.9167 s at cruise;
unsafe vertical displacement is 2×480 units at rank 0 and 2×80 at rank 1, plus
braking/turn time measured by the driver. Pressure exposure is sampled each actual
physics tick, not inferred from only distance/speed. Unit tests prove 2 s grace,
4 hull after 26 s and destruction at 27 s for both lower ranks; the scripted route
also lingers, observes durable zero hull and respawns without resource refill.

These are roughly the requested 20–24 s figures (19.57 and 24.22). Rank 0 has about
2.78 s additional pressure budget; rank 1 has about 7.43 s. The constant rule cannot
make both ranks equally desperate on this shape: rank 1's smaller unsafe stretch
necessarily leaves more slack. No silent damage retuning was used. Stopping to scan
or entering with damaged hull can be fatal; rank 2 is the safe investigation choice.
Human piloting, accessibility and engine upgrades still require playtesting.

## Research economy arithmetic and old saves

**Proposed numbers for approval:** preserve Sunlit 20 XP/species, 30 XP/study,
100 XP/point, cap 2. Add Twilight 40 XP/study, 100 XP/point, cap 2. The aggregate
extra-point ceiling rises from 2 to 4 through two independently capped Resources;
this avoids retuning Sunlit or loosening the existing per-profile 0–2 validator.
There are 9 optional pre-gate Twilight subjects in this allowance: the four existing
anchor/timber/ballast/thermal studies plus five new safe-shelf studies. Two further
new optional basin subjects also award 40, inside the same Twilight cap.

| Case | XP and points before the gate | Result |
| --- | --- | --- |
| Rush, no optional scans | 2 commissioning + 1 survey + 1 decode = 4; 0 scan bonus | Cannot buy rank 2's total 2+3=5 point cost |
| Most safe-shelf subjects (7/9) | 7×40=280 XP → min(2, floor(280/100))=2 | 4+2=6 points; rank 2 leaves one spare |
| Five unique safe-shelf subjects | 5×40=200 XP → 2 points | Same 6-point budget, without grinding |
| Existing save with all four old studies | They become imported, awarding 0 retroactive XP; five NEW safe studies yield 5×40=200 | Gate remains fundable without entering it |
| Full Sunlit bonus already earned | 4 base + 2 retained Sunlit + 2 Twilight = 8 | Rank 2 leaves 3 spare, rather than 1; preserved-earned-points caveat for review |
| Two basin studies | 2×40=80 additional recorded XP, subject to the same cap | Optional, never counted as needed to fund entry |

No end-of-chapter +2/+1 awards are counted. Previously earned Sunlit XP points remain
unchanged; a player who already studied Sunlit thoroughly can legitimately arrive
with extra points. A player who spends points on another branch can freely reassign.
“Rush cannot buy” means a no-optional-scan, no-previous-scan-bonus budget, not stripping
points from experienced saves. Existing credited IDs retain their exact values.
Previously completed but uncredited Twilight study IDs are accepted then normalized
into imported IDs on load; their first-record rewards cannot be replayed. Each ID
is credited once, never per fish, per reload or per scan repetition. No old save
receives points merely for opening this build. Older binaries may reject the newly
recorded subject IDs; retain checkpoint backups and continue with this/newer builds.

## Native evidence and manual route

| State | 1280×800 | 800×600 |
| --- | --- | --- |
| Before descent | [warning](warning-1280x800.png) | [warning](warning-800x600.png) |
| Hull stress | [stress](hull-stress-1280x800.png) | [stress](hull-stress-800x600.png) |
| Failure panel | [failure](failure-1280x800.png) | [failure](failure-800x600.png) |
| Deep section | [basin](deep-section-1280x800.png) | [basin](deep-section-800x600.png) |

Keyboard: WASD/arrows thrust, F sonar, E scan/interact, M research/map, P pause,
Enter confirm, Escape remain on the failure panel. Gamepad: left stick/D-pad,
X sonar, A scan/interact/confirm, Back map, Start pause, B remain. Remapped bindings
continue to apply; recovery uses existing fixed UI actions.

1. Continue/deploy normally; visit Research technology and freely reassign to hull
   rank 0, then repeat at ranks 1 and 2. Scan safe-shelf optional subjects to observe
   the new first-record budget; opening an older completed record must award nothing.
2. From the established lower western loop, inspect the open basin approach beside
   the pressure-margin study. Compare BASIN depth and RATED depth before descending.
   Read or disable the single Wick card. The normal upper return loop stays open.
3. With rank 2, descend to the basin, inspect both studies, cross it and ascend through
   the other opening. Return by the existing upper loop/tether; no required evidence
   or completion depends on the basin. Repeat with keyboard and gamepad.
4. With a full hull and lower ranks, deliberately cross without scanning/stopping;
   note remaining hull. Then repeat while lingering: pressure cues precede damage,
   and a failure panel pauses the vessel. At both window sizes check the footer.
5. Press Esc/B: stay paused. Press Enter/A: restore hull at the tether, preserving
   battery/oxygen/ammo and permanent records. Pause safely, quit and Continue to
   check supplies. Also quit on the failure panel and Continue: zero hull must restore
   the explanation, not strand the player. A failed checkpoint write must offer retry.

## Limitations

Oxygen depletion still has no production failure/respawn flow; it is deliberately
unchanged here. Respawning at zero oxygen does not refill it. Hull destruction flow
is Twilight-only; Sunlit and legacy fixtures retain their prior behavior. There is
no unbanked-sample inventory and no new explosion asset. The explanation is the
minimal honest failure presentation. No physical-controller, cross-platform,
target-GPU 60 FPS or human fairness/pacing acceptance is claimed. Software Mesa
captures under concurrent validation reported large render times; see capture log,
not a performance certification. The new adapter compares location/depth each frame,
refreshes text only on changes and attempts the card once per preference change;
geometry and registrations are built once, not per frame.

Exact commands, counts and export outcomes: [validation](validation.md).
