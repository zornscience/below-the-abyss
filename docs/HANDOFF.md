# Handoff brief — Below the Abyss (written 2026-11-10)

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
  case that must fail. CI runs all of them (19 negatives per PR #48's report).
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
python3 tools/build_playtest.py             # real Linux export (--allow-dirty for local edits)
python3 tools/smoke_playtest.py build/below-the-abyss-playtest-linux-*.zip --log /tmp/x.log
python3 tools/smoke_playtest.py <zip> --log /tmp/x.log --break-<name>-wiring   # must FAIL
```
- Native screenshots: `xvfb-run -a ... godot --path . --rendering-method gl_compatibility --script <fixture>`
  with `root.get_texture().get_image().save_png(...)` (see `tests/fixtures/capture_*.gd`). Software GL is slow.
- Single test file: `... --script res://addons/gut/gut_cmdln.gd -gexit -gdir=res://tests/integration -gselect=<name>`.
- The review sandbox blocks `partner.steamgames.com` and `steamdb.info`; Steam facts here are unverified.

## 4. State of the code (verify before relying)

`main` is at merge of **PR #50** (`ce69fc6`, CI artifact logs). Merged: BTA-057 sonar-driven Twilight
visibility, 058 resource tension, 059 depth gate + respawn flow + research economy, 060 Rift Stalker, 061
tunnels and excavation gates, step-1 UX (quiet HUD, radio dismiss and hints, guidance cards), radio id-shape
fix, audio audit, combat-direction drafts, **PR #48 combat test box**, and **PR #49** (the documentation
branch `ccr-faf5a894-y8zz7k`: market review, control-feel requirement, market requirements, this file).
- Last full verification by Claude: `main` at `c773f4d` (after PR #46): 781/781 tests, release smoke
  positive and 13/13 negatives. PR #48 (795/795 and 19 negatives per its own report) was merged without
  re-verification by Claude; no later full local re-run is recorded here.
- No human playtest of the combat test box exists.

## 5. Design direction and decisions (designer-approved unless marked)

Reference game: **Metroid Fusion** (mystery, investigation, a pursuer you cannot beat early, ability-gated
exploration, sparse reactive music). Docs: `docs/design/gdd-revision-combat-proposal.md` (DRAFT; `GDD.md` is
NOT yet updated), `twilight-redesign-brief.md` (executed through BTA-061), `combat-testbox-brief.md`.
- Combat: torpedo-first; active sonar stun; **drops = battery/torpedo resupply only** (no currency/XP).
- First-slice technologies: Resonant pulse, Silent running, existing Pressure shell depth gate.
- Stalker: unbeatable early; **defeating it is an optional path to a darker ending**, a player choice,
  branching late. Story canon (what it is, what the endings mean) needs the designer's approval.
- Rejected/deferred: terrain on the map (needs a schema change), Glyph key and Breaker torpedo (need story approval).
- Failure: respawn at the Twilight ascent tether, hull restored, supplies kept (BTA-059, awaiting formal approval of penalty).
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
- Gaps: oxygen depletion has no failure flow; no GPU/Steam Deck performance data (only software GL);
  `ShelfPrototype` is a god object with ~1,100 outside references; legacy prototype modes and four
  legacy save stores remain (removal needs approval); tunnel profiles replace rock shapes by list index
  (fragile); README still says BTA-055; `.git` is ~500 MB from committed screenshots.

## 7. Recommended next steps, in order

1. Designer runs the combat test box (playtest export only; see `docs/testing/combat-testbox/README.md`
   and `docs/design/combat-testbox-brief.md`) with at least three people who have not seen the game; apply
   the go/change/stop criteria. Do not build more combat until that result exists.
2. If go: update `GDD.md` from the proposal; then issues for Resonant pulse + Silent running, Stalker arc,
   reactive music, BTA-062 (local darkness and pacing; still not built), the terrain-map schema issue
   (needs approval), a Stalker-defeat ending prototype.
3. Audio: license or CC0 sound effects, curated Gemini music, then an engine issue (region beds, bus
   effects, spatial emitters, music layers). Proposed BTA-063/064 in `docs/audio_audit.md`.
4. Later: five external playtests, README refresh, screenshot storage, structural refactors (with approval).

## 8. Prompting Claude Code (what has worked)

Prompt skeleton: read-list (AGENTS/GDD/TDD/CODEX_PLAN + the relevant brief); ONE issue; **base branch**;
approved decisions; what the code already does (verified, "re-verify"); problem with measured numbers;
numbered requirements; out of scope; release-build safety (assert lint, ReleaseSmoke + negatives, real
export); tests as rules not coordinates; deliverables (PR template, numbers table, screenshots at
1280x800 and 800x600, keyboard + gamepad route, "no human playtest results exist"); "do not merge, wait
for the PR's own CI". Use the most capable available model at high effort for cross-system issues, medium for data/tuning.
Ground every prompt in a fresh read of the code; two earlier prompts rested on wrong assumptions.
