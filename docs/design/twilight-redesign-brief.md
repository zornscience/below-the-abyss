# Twilight Shelf redesign brief — tension, depth, tunnels and a listening predator

**Status: DRAFT FOR USER APPROVAL. No implementation is authorised by this document.**
Each numbered issue below becomes one Codex issue and one PR, after the user approves this brief.
All numbers are provisional and must be tuned through Resources, never constants.

## 1. Why this exists (user playtest evidence)

Direct feedback from the designer's playthrough of the Twilight Shelf, build on `main` after PR #41:

- "Nothing felt tense." The only excitement was the net, "because I knew it was coming".
- "It was just navigating around." No challenge beyond the lava vents.
- Torpedoes were never used. No tunnels to explore. No depth hazard.
- Pings were used only to find where to scan. "The battery cost did not make me hesitate at all."
- No resource ever needed watching.
- Wants: tunnel exploration with navigation risk; a depth hazard gated by a hull-rank upgrade
  (or the player may chance it, and "barely make it before the hull buckles and the sub explodes");
  creatures attracted by pings **and** torpedo blasts that attack the sub; torpedoes with a real
  job (creature defence **and** tunnels); "playing the whole game in the dark would be annoying".
- Completion took "a few minutes". The designer knows the route, so this is not a novice
  measurement. The 30–45 minute target is still unverified.

### What the code says (measured, not guessed)

| Fact | Where | Consequence |
| --- | --- | --- |
| Twilight oxygen drain 0.02 / s, battery idle 0.003 / s, thrust 0.009 / s | `resources/balance/twilight_resources.tres` | Oxygen lasts ~83 min, battery effectively never drains. Nothing can run low in a 30 min run. |
| Ping costs 4 battery; pool is 100 | `prototype_sonar.tres` | 25 pings per full battery; the cost is never felt. |
| Shelf spans 350–760 m; rated depth 1000 m | `twilight_pressure_fit.tres` | The depth rule exists but the level never reaches it. |
| Hull ranks rate 300 / 400 / 450 / 500 m; Twilight adds a 1000 m baseline | `research_tree.tres`, `expedition_revision.gd` | Effective Twilight ratings are 1000 / 1100 / 1150 / 1200 m. A deep section can gate on rank. |
| Research points: 2 commissioning + 1 survey + 1 decode + 2 expedition + 1 specimen, plus scan XP capped at **2** extra | `research_tree.tres`, `research_experience_rules.gd` | "Plenty of scans to earn the hull points" requires raising a cap that the validator currently rejects above 2. This is an economy change. |
| Torpedo blasts emit **no** acoustic event ("no secondary acoustic emissions") | `blast_effect.gd`, `torpedo_launcher.gd` | Creatures cannot currently hear blasts. New behaviour, not tuning. |
| Torpedo damage 60; excavation mechanic already exists | `torpedo_profile.tres`, `excavation_system.gd` | Tunnel gating reuses an existing system. |
| Creature AI with Investigate / Pursue / Flee / Return exists | `scripts/ai/` (`PredatorCreature`, `HammerheadCreature`) | The hunting creature reuses existing AI; it is not new technology. |
| Echo reveal: radius 900 u, 600 u/s, fades over 6 s, cooldown 4 s | `prototype_sonar.tres`, `twilight_visibility_profile.gd` | Pinging every cooldown keeps most of the screen lit. Cost and risk must make that a choice. |

## 2. Decisions already made by the user

1. Torpedoes serve **both** creature defence and tunnels.
2. The depth gate is a **hull talent rank** (existing research branch). The level must offer
   plenty of scan opportunities to earn the points. The player may also attempt the deep section
   without the upgrade.
3. Creatures react to **pings and torpedo blasts**.
4. Sub explodes if the player stays too deep without the upgrade, but they must "barely be able to make it".
5. Tunnels with real navigation risk. Not dark everywhere.

## 3. Decisions still open (recommended default in bold)

| # | Question | Recommended default |
| --- | --- | --- |
| A | What does "the sub explodes" cost? | **Respawn at the ascent tether, lose unbanked scan progress for the current tunnel/route only, keep all permanent discoveries and research (GDD §2).** |
| B | Torpedo vs creature | **Scares and briefly stuns; never kills; no rewards.** (GDD non-goal: no combat progression.) |
| C | Which creature(s) | **One new acoustic predator ("Rift Stalker" per GDD §7), built on `PredatorCreature`. Existing eels/squid stay harmless.** |
| D | Blast reaction | **Blasts draw investigators from far away (loud) but frighten the one nearest the blast. Ambiguity is deliberate and readable.** |
| E | Target duration | **30–45 min for a first-time player (existing target). Not a measured fact until playtested.** |
| F | Extra scan points | **Raise the scan-XP cap so a thorough player can fund hull rank 2; do not let a rushing player be blocked.** See issue 059. |
| G | Deep section depth | **Authored at the rank-1 rating plus 50 m, so rank 1 (1100 m) is comfortable and baseline (1000 m) is a gamble.** Tune after playtest. |

## 4. Constraints for every issue

Read `AGENTS.md`, `GDD.md` (pillars, §5 sonar, §7 creatures, §11 accessibility), `TDD.md`, `CODEX_PLAN.md`
and `docs/design/twilight-shelf.md` first.

- **One issue per PR, merged in order.** Branch from current `main`. Do not touch another issue's files.
- **No scope creep.** No Zone 3, no new currency, no story or dialogue canon changes, no new
  regions. New player-facing text is limited to short mechanic hints and must be flagged for review.
- **Save schema 10 stays at twelve top-level fields.** Any persisted addition needs an explicit,
  tested migration and user approval. Prefer derived or session-only state.
- **Release-safe code.** `assert()` is stripped from release exports. Never put side effects in
  `assert()`. `tools/lint_release_safety.py` must pass. Any new wiring must be covered by
  `ReleaseSmoke` (`scripts/playtesting/release_smoke.gd`), with a negative case that fails when
  the wiring is removed. Run `tools/build_playtest.py` and `tools/smoke_playtest.py`.
- **Tests are rules, not coordinates.** Do not hard-code level coordinates in new tests; read authored data.
  Do not weaken existing assertions or raise timeouts to pass.
- **Accessibility.** Every new threat, hazard and cue needs a non-audio, non-colour-only equivalent,
  keyboard and gamepad parity, and must respect Reduced Flashing / Motion / High Contrast and the
  1280×800 and 800×600 layouts. No flashing alarms, no camera shake.
- **Fairness (GDD pillar 4).** No unreadable instant deaths. Every threat telegraphs, offers an
  escape, and its cause is visible, audible **and** textual.
- **HUD discipline.** Do not add permanent HUD lines. New information appears only when relevant.
- **Performance.** No per-frame allocation or deep copies. Report frame cost; do not claim 60 FPS
  without suitable hardware.
- **Honesty.** Human playtest results do not exist. State that plainly. Do not present automation
  as player acceptance.
- **Assets.** No generated or third-party assets without a provenance entry. Prefer existing art and shaders.

## 5. Issue sequence

Dependencies are strict. Each issue lists acceptance criteria that can be verified.

### BTA-058 — Make resources matter (smallest; do first)

**Goal.** Pings, torpedoes and hazards have felt costs, without reintroducing the constant travel
drain the user previously asked to slow down.

- Keep passive travel drain slow. Add costs to **actions**: ping, torpedo, thermal-vent hits and
  (issue 059) deep-section stress.
- Provide a tuning table (a Resource or doc, not code) with a stated target: a full battery should
  support roughly 12–15 pings **plus** some torpedoes and thrust across one thorough expedition, so
  that a careful player returns to refit once and a reckless one is pushed to. These targets are
  provisional; show the calculation.
- Low-resource warnings reuse existing text/visual patterns. No new permanent HUD element.
- **Acceptance.** Unit tests for the new drain/cost rules; a computed table of pings and
  torpedoes per full battery; existing refit/continue behaviour unchanged; no schema change;
  release smoke unchanged and passing.
- **Out of scope.** Creatures, depth, tunnels.

### BTA-059 — Depth hazard with a hull-rank gate and a funded research budget

**Goal.** A deep section that needs hull rank 2, can be attempted without it, and buckles the hull
if the player lingers.

- Author a deep branch whose depth exceeds the baseline Twilight rating (1000 m) by a small margin
  (decision G). Read `docs/decisions/bta-012-depth-damage.md` and reuse the existing warning/grace
  system; extend it only if it cannot express "barely make it".
- Without the rank: a visible, textual and audible hull-stress warning that escalates, a grace window,
  then escalating hull damage, then buckling (decision A). With the rank: no damage.
- The gate must be readable **before** committing: show the rating versus the section depth in the
  existing depth panel and in one Wick card. No hidden gates.
- **Research budget.** Raise the scan-XP cap (`maximum_extra_points`, currently validated to 0–2)
  and add enough optional Twilight scan subjects that a thorough player can afford hull rank 2
  (cost 2 + 3 = 5 points) without grinding. Show the arithmetic in the PR. Existing saves must not
  lose points and must not be silently over-granted; points are derived, so document exactly what
  existing saves gain. **This is an economy change; the user has approved the intent, but the
  final cap and subject count need confirmation in the PR.**
- **Acceptance.** Tests for rating-versus-depth with each rank; grace and damage timing; buckling
  and respawn per decision A; points derivation with the new cap and old saves; manual route that
  reaches the deep section with and without the rank. Release smoke covers the new wiring.
- **Out of scope.** New currencies, new talents, Zone 3.

### BTA-060 — Listening predator and torpedo defence

**Goal.** Pings and blasts have consequences; torpedoes become a defensive tool.

- **Blast sound.** Torpedo detonations emit an acoustic event through the existing acoustic bus
  (new behaviour; the current code forbids secondary emissions on purpose, so make this explicit
  and update the relevant docs/decision record). Only creatures that subscribe react.
- **Creature.** One acoustic predator built on the existing AI. States: Idle, Patrol, Investigate
  (toward a ping or blast), Pursue (once it senses the vessel), Flee, Return. Per-creature Resource
  for hearing thresholds, speed, territory, cooldowns.
- **Readable and fair.** Telegraph before pursuit (movement change, light, a short Wick radio line,
  passive-sonar contact class), never instant. Always an escape: quiet travel breaks pursuit, and
  a safe region exists. Damage is modest and goes through the existing hull API.
- **Torpedo defence (decision B).** A torpedo near the creature scares it away and briefly stuns it.
  It cannot be killed, awards nothing and costs ammunition, so it is a tool, not a farm.
- **Blast ambiguity (decision D).** A blast heard far away draws investigators; the creature
  closest to the blast flees. Document the rule in-game with one hint card.
- **Acceptance.** Unit tests for the state machine, hearing thresholds, blast events and escape; a
  scripted no-ping route still completes; a route with deliberate pinging draws the creature;
  at least one escape path verified with each input device. Release smoke registers the creature
  and its bus binding, with a negative case.
- **Out of scope.** Leviathan, rewards for fighting, more than one new creature type.

### BTA-061 — Tunnels with navigation risk and torpedo-gated shortcuts

**Goal.** Real exploration spaces, not straight cross-shaped passages.

- Author at least two tunnel systems using the **existing** collision/terrain data and art. A
  tunnel must have: a branch, a dead end, a squeeze that requires careful piloting, and a payoff
  (an optional scan subject or a shortcut). Navigation risk means collision cost, vent exposure,
  or oxygen/battery cost for a wrong turn, **not** random instant death.
- **Torpedo gates.** At least one shortcut blocked by excavatable rock, opened with torpedoes
  (reuse `ExcavationSystem`). The long route always exists, so nothing is required.
- **Always a way back.** No softlocks. Retreat remains possible, and sonar reveals the way.
- **Acceptance.** Reachability tests derived from authored data (no hard-coded coordinates); every
  tunnel exit connects to the open shelf; excavation gate opens and persists correctly through
  Continue within existing terrain save rules (no schema change); map shows discovered tunnels
  only after discovery (no spoilers).
- **Out of scope.** New art assets, new regions, changing existing required evidence locations.

### BTA-062 — Local darkness and pacing pass

**Goal.** Darkness where sonar matters, light where players need to read the world.

- The open shelf becomes dim but readable (raise ambient from the current 0.16 toward the Reduced
  level); full darkness applies only inside tunnels and caves, through the existing
  `TwilightVisibility` pass and `twilight_visibility.tres`. Do not add a second lighting system.
- Soften the hard-edged passive light disc around the vessel (cosmetic, same pass).
- Remove any new permanent HUD text introduced by earlier issues.
- Reduced mode and High Contrast must still beat Standard on visibility.
- **Acceptance.** Native screenshots at 1280×800 and 800×600 (open shelf, tunnel, mid-ping,
  Reduced); measured frame cost; Twilight route tests green; Sunlit Shallows unchanged.
- **Out of scope.** Persistent revealed-terrain map (needs its own approved schema issue).

## 6. Human playtest gate (not code)

After 058–062, before any new region: at least five external players unfamiliar with the game
(`docs/playtesting/`). Questions to measure: did anything feel tense, was the deep gate understood
before committing, did players ping deliberately, did anyone feel cheated by a death, did torpedoes
get used, how long did it take, and where did novices get lost. **No claim of acceptance until
real results exist.**

## 7. Execution notes

- **Model / effort for Codex.** Use the most capable model available at high reasoning effort for
  059, 060 and 061 (cross-system, release-build and balance risk). 058 and 062 can run at a
  medium effort. Do not start the next issue until the previous PR is reviewed and merged.
- **Review checklist for each PR.** Run the full suite and `tools/validate_godot.py`; build the
  playtest export and run both the positive and negative smoke cases; open the screenshots;
  check that no new permanent HUD text appeared; check that no schema field was added.
- **Known limits of automation.** Headless tests run on the debug editor and cannot judge feel.
  Treat every balance number here as a hypothesis to be changed by playtest evidence.
