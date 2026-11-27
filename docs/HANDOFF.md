# Handoff brief: Below the Abyss (written 2026-11-10, state refreshed 2026-11-27)

For a model taking over. Read this first, then `AGENTS.md`, `GDD.md`, `TDD.md`, `CODEX_PLAN.md`.
Everything here is checked against the repo or marked as unverified.

## 1. The project and the people

- **Game:** *Below the Abyss*, a 2D submarine exploration/mystery game. Godot **4.6.3** (`.godot-version`),
  typed GDScript, GUT 9.6.1 tests (pinned; `addons/gut` is git-ignored, install with `tools/install_gut.py`).
  Repo `zornscience/below-the-abyss`, default branch `main`.
- **The designer (user)** makes all design decisions and tests by playing. Prefers blunt, critical
  review: state flaws first, no flattery, challenge weak premises.
- **Claude Code** implements issues as PRs (earlier PRs, up to #48, were written by a different agent,
  Codex/GPT-6.1). Separate Claude sessions have done review, verification, briefs and prompts. PRs are
  written from a prompt the designer hands off; the designer merges them.
- No budget for a human composer, sound designer or artist. Available: Gemini (music), ChatGPT
  (images), free human-made libraries (CC0 preferred). See §6 for the legal and market cautions.

## 2. Working rules (from AGENTS.md plus what went wrong)

- One issue per branch/PR. Typed GDScript, Resources and signals, saves are untrusted versioned data
  (schema **10**, exactly twelve top-level fields; do not change without approval and a migration).
- No new dependencies, network calls, assets without provenance, or story/art/scope changes without approval.
- **Never put side effects inside `assert()`**: it is stripped from release exports and hid a real bug
  (Twilight sonar/discovery wiring). `tools/lint_release_safety.py` enforces it.
- **Debug-only tests prove nothing about release builds.** Every new wiring needs a `ReleaseSmoke` check
  (`scripts/playtesting/release_smoke.gd`, playtest export only) AND a negative `--break-*-wiring`
  case that must fail. CI runs all of them (26 negatives as of PR #69).
- **Do not weaken assertions or raise timeouts to pass.** If a behaviour changes on purpose, say so in
  the commit (see the radio id test change).
- **Wait for the PR's own CI to be green before merging.** PR #43 merged 30 s after a failed run.
- **Verify claims with the real code, not by reading.** Examples: a subagent's "drift" finding was false;
  a PR's "radio line" never reached the player. Write a probe or a test that fails without the fix.
- **Base branch discipline.** Prompts have repeatedly told the implementing agent to extend files that only existed on an
  unmerged branch. State the base explicitly and confirm `main` contains it first.
- Report outcomes faithfully: failing tests with output, skipped steps said as skipped.

## 3. How to build, test and verify

```sh
# Engine: official Godot 4.6.3 (checksummed in .github/workflows/godot-validation.yml)
export GODOT_BIN=/path/to/Godot_v4.6.3-stable_linux.x86_64
python3 tools/install_gut.py            # may fail behind a proxy: clone bitwes/Gut at the pinned commit
$GODOT_BIN --headless --path . --editor --import --quit   # REQUIRED after switching branches
python3 tools/lint_release_safety.py
python3 -m unittest discover -s tests/python
python3 tools/validate_godot.py         # import, parser, startup (~300+ scripts)
python3 tools/run_tests.py              # full GUT suite, ~10 min; do not run two Godot jobs at once
python3 tools/verify_*.py               # scripted input routes (see CI workflow for the list)
python3 tools/install_export_templates.py   # ~1.2 GB, once
python3 tools/build_playtest.py             # real Linux + Windows export (--allow-dirty for local edits)
python3 tools/smoke_playtest.py build/below-the-abyss-playtest-linux-*.zip --log /tmp/x.log
python3 tools/smoke_playtest.py <zip> --log /tmp/x.log --break-<name>-wiring   # must FAIL
```
- Native screenshots: `xvfb-run -a ... godot --path . --rendering-method gl_compatibility --script <fixture>`
  with `root.get_texture().get_image().save_png(...)` (see `tests/fixtures/capture_*.gd`). Software GL is slow.
- Single test file: `... --script res://addons/gut/gut_cmdln.gd -gexit -gdir=res://tests/integration -gselect=<name>`.
- The review sandbox blocks `partner.steamgames.com` and `steamdb.info`; Steam facts here are unverified.

## 4. State of the code (verify before relying)

`main` is at the merge of **PR #69** (`7ba6d5c`). Merged before PR #50: BTA-057 sonar-driven Twilight
visibility, 058 resource tension, 059 depth gate + respawn flow + research economy, 060 Rift Stalker, 061
tunnels and excavation gates, step-1 UX (quiet HUD, radio dismiss and hints, guidance cards), radio id-shape
fix, audio audit, combat-direction drafts, **PR #48 combat test box**, and **PR #49** (the documentation
branch `ccr-faf5a894-y8zz7k`: market review, control-feel requirement, market requirements, this file).
Merged since:
- **#50** CI: compact log artifacts, 3-day retention, non-fatal upload.
- **#51** Docs: added `CLAUDE.md`, renamed Codex to Claude Code in the docs, refreshed the README current build.
- **#52** Investigation of oxygen exhaustion in Sunlit and Twilight (probes and findings, no gameplay change).
- **#53** Oxygen exhaustion: 60 s life-support countdown, then Halcyon recovery (supersedes the BTA-059 respawn).
- **#54** Recovery card polish: accept delay, simpler footer, tested casualty retry.
- **#55** Windows playtest package, Windows release smoke job and the manual draft pre-release workflow.
- **#56** Recovery card test: wall-clock slack bounded by the measured frame instead of 50 ms (test only).
- **#57** Fix casualty deadlock when the hull is destroyed during recovery (a pending Twilight casualty is
  now carried inside the recovery checkpoint, and a released sentinel's death is announced).
- **#58** Docs: HANDOFF and README brought in line with `main` through PR #57.
- **#59** Docs: Drowned Caves (Zone 3) chapter brief, `docs/design/drowned-caves-brief.md`.
- **#60 to #65** Drowned Caves DC-1 to DC-6 (details below).
- **#66** Docs: the designer's decision to keep the free recovery restock (§5).
- **#67** Docs: recovery-flow facilitator script, `docs/playtesting/recovery_playtest.md`.
- **#68** Recovery card test: the accept delay is measured in game time, not wall time (test only). It fixed
  a flaky failure where summed process deltas led the wall clock on CI.
- **#69** Fix a release segfault when a scene change lands in the same frame as deferred UI callbacks
  (details below).

**Drowned Caves (Zone 3).** The brief (decisions A to D approved 2026-11-21) splits the chapter into six
PRs, all merged:
- **DC-1 (#60)** region foundation: journey phase `caves`, a 2,000 m pressure fit, a graybox chamber with
  one sealed passage, entry from Halcyon after the Twilight debrief is claimed, anchor return and recovery.
- **DC-2 (#61)** cave navigation and oxygen: a flooded squeeze with a torpedo-gated shortcut, a far chamber
  and a 0.3/s oxygen rate (about 5.6 minutes per tank).
- **DC-3 (#62)** sentinel payoff: optional guide lights for a living released sentinel and one text-only
  line for every outcome, derived from story flags with no save change.
- **DC-4 (#63)** first-contact site: four scan records in the far chamber (Mara's required log, the
  paintings, the glyph wall with the Vow of Silence, one optional Mara log). The art is placeholder and
  the text is a draft for the designer to edit.
- **DC-5 (#64)** memory crystal choice: the shrine decision (leave +15, take -15). Taking it gives a
  placeholder one-time +200 sonar calibration, derived from the saved decision with no new award. The
  upgrade is a default the designer has not named.
- **DC-6 (#65)** debrief and chapter close: the descent is **on by default** (`-- --no-drowned-caves`
  hides it), a derived Halcyon caves debrief with a one-line Zone 4 teaser (not playable), and a fix for
  a DC-1 dock-button bug.

Evidence for each is in `docs/testing/dc-1/` to `docs/testing/dc-6/`. The chapter is built end to end
but **no human has played it**.

**Fixed hazard (2026-11-27, PR #69).** A release export segfaulted when a scene change landed in the same
frame as deferred UI callbacks (tutorial layout, accessibility reflow, story-read reset, recovery
trigger), which reached a null tree or viewport. Those callbacks now return when their node has left the
tree. The release smoke arms all of them in the frame of its combat-box scene change
(`_arm_scene_change_hazards`, token `RELEASE_SCENE_CHANGE_HAZARDS_ARMED`). Evidence:
`tests/integration/test_scene_change_hazards.gd`. There is no `--break-*` negative for it, because a
segfault prints no token. The proof is that the unguarded build crashes under the same smoke stage.

**Verification.**
- Latest full CI: GitHub Actions run 45928891621 on `a55293c` (PR #69 head) passed validate, the Linux
  package with its negatives and the Windows package with its smoke and negatives. Publish was skipped,
  as on every PR. `7ba6d5c` has the identical tree (`git diff a55293c 7ba6d5c` is empty).
- Claude's last local full run, on `a55293c` in a Linux container: GUT **908 of 908**, the release-safety
  lint, the Linux export smoke and **26 of 26** `--break-*-wiring` negatives failing as required. The
  Windows export was not built locally.
- No human playtest of the combat test box exists. No human has played the oxygen recovery flow or the
  Drowned Caves. The script for the recovery playtest is ready (#67) and has not been run.

## 5. Design direction and decisions (designer-approved unless marked)

Reference game: **Metroid Fusion** (mystery, investigation, a pursuer you cannot beat early, ability-gated
exploration, sparse reactive music). Docs: `docs/design/gdd-revision-combat-proposal.md` (DRAFT; `GDD.md` is
NOT yet updated), `twilight-redesign-brief.md` (executed through BTA-061), `combat-testbox-brief.md`.
- Combat: torpedo-first; active sonar stun; **drops = battery/torpedo resupply only** (no currency/XP).
- First-slice technologies: Resonant pulse, Silent running, existing Pressure shell depth gate.
- Stalker: unbeatable early; **defeating it is an optional path to a darker ending**, a player choice,
  branching late. Story canon (what it is, what the endings mean) needs the designer's approval.
- Rejected/deferred: terrain on the map (needs a schema change), Glyph key and Breaker torpedo (need story approval).
- Failure (approved 2026-11-15, **implemented in PRs #53, #54 and #57**, supersedes the BTA-059 tether
  respawn): zero oxygen starts a 60 s life-support countdown (`resources/balance/vessel_recovery.tres`,
  `grace_seconds = 60.0`) on simulation time. A Halcyon dock or tether refit cancels it. Expiry or hull
  destruction in either chapter recovers the vessel at Halcyon with a free full restock (no restore fraction,
  per `scripts/player/vessel_recovery_profile.gd`). Records and choices are kept. Oxygen drain is 0.048 per
  second in Sunlit (`prototype_resources.tres`) and 0.03 per second in Twilight (`twilight_resources.tres`).
  The save schema stays at 10 with twelve top-level fields (`ExpeditionSchema.VERSION`, size check in
  `expedition_schema.gd`). Evidence and limits: `docs/testing/oxygen-recovery/README.md`.
  Restock cost (decided 2026-11-24): recovery stays a free full restock with no cost for now. The designer
  accepts that running out of oxygen works as a free refuel. Revisit only after a playtest shows it matters.
- Decisions the designer owns and has NOT made: boss concept for the slice; what the darker ending costs;
  Story Bible canon for alien technology; whether the combat direction survives the playtest.

## 6. Risks to keep in front of the designer

- **Nobody outside the project has played it.** The plan's Gate D (five external playtests) is not met.
  The test box exists to answer "is this fun?" with 3+ strangers, 10 minutes each (`docs/testing/combat-testbox/FACILITATOR.md`).
- **Audio is code-generated** (30 files, 18 pure tones, one music loop). See `docs/audio_audit.md`.
- **AI assets:** Steam requires disclosure of shipped AI art/music/narrative (code help exempt, per the
  designer's checked source). Purely AI output may not be copyrightable. Keep originals, prompts, revisions
  and dated tool terms. Hand-finish identity assets; use CC0/libraries for effects. Get legal advice.
- **Market:** nearest comparable (Depths of Sanity) has 72 reviews. Plan for the low case. Controls and
  dynamic music are the named reasons small Metroidvanias are punished. Figures are provisional.
- Recovery after oxygen or hull failure has no penalty beyond the vessel's position, so suffocation is a
  free refuel. Kept on purpose for now (decided 2026-11-24, see §5). Watch for it in playtests.
- Open items owned by the designer (not decisions):
  - The repo is public and has no `LICENSE` file (the README says the license decision is pending).
    License choice and repo visibility are the designer's call.
  - The Windows exe was only run on a CI runner (`windows-latest`). Windows 11 Smart App Control may block
    unsigned builds. It is unverified on a real machine.
  - The tow cutscene was deferred until the designer has seen the recovery card in play. Any new Wick or
    Okafor lines are proposals needing approval.
  - No human has played the recovery flow.
- Gaps: no GPU/Steam Deck performance data (only software GL);
  `ShelfPrototype` is a god object with ~1,100 outside references; legacy prototype modes and four
  legacy save stores remain (removal needs approval); tunnel profiles replace rock shapes by list index
  (fragile); `.git` is ~500 MB from committed screenshots.

## 7. Recommended next steps, in order

1. Publish a draft pre-release from the manual workflow (`docs/playtesting/build.md`, "Publishing a draft
   pre-release"), then the designer plays the oxygen flow on Windows (steps in
   `docs/testing/oxygen-recovery/README.md`).
2. Designer runs the combat test box (playtest export only; see `docs/testing/combat-testbox/README.md`
   and `docs/design/combat-testbox-brief.md`) with at least three people who have not seen the game; apply
   the go/change/stop criteria. Do not build more combat until that result exists.
3. If go: update `GDD.md` from the proposal; then issues for Resonant pulse + Silent running, Stalker arc,
   reactive music, BTA-062 (local darkness and pacing; still not built), the terrain-map schema issue
   (needs approval), a Stalker-defeat ending prototype.
4. Audio: license or CC0 sound effects, curated Gemini music, then an engine issue (region beds, bus
   effects, spatial emitters, music layers). Proposed BTA-063/064 in `docs/audio_audit.md`.
5. Later: five external playtests, screenshot storage, structural refactors (with approval).

## 8. Prompting Claude Code (what has worked)

Prompt skeleton: read-list (AGENTS/GDD/TDD/CODEX_PLAN + the relevant brief); ONE issue; **base branch**;
approved decisions; what the code already does (verified, "re-verify"); problem with measured numbers;
numbered requirements; out of scope; release-build safety (assert lint, ReleaseSmoke + negatives, real
export); tests as rules not coordinates; deliverables (PR template, numbers table, screenshots at
1280x800 and 800x600, keyboard + gamepad route, "no human playtest results exist"); "do not merge, wait
for the PR's own CI". Use the most capable available model at high effort for cross-system issues, medium for data/tuning.
Ground every prompt in a fresh read of the code; two earlier prompts rested on wrong assumptions.
