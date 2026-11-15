# Below the Abyss — Claude Code Implementation Plan
Version 0.1 | 2026-10-25

## 1. Working agreement
Claude Code is an implementation partner, not autonomous game director. Every task has scope, dependencies, acceptance criteria, tests and review. One issue per feature, one branch per issue, pull request before merge. No major architecture changes, unapproved dependencies, generated art commitments, or changes to game design without human approval.

## 2. Definition of done for every issue
- Behavior meets acceptance criteria and can be demonstrated in an example scene.
- Typed GDScript passes parser/import checks and project launches headlessly.
- Relevant automated tests added or updated; manual test instructions included for graphics/input.
- No new Godot errors, missing resource references or unexplained warnings.
- Keyboard/gamepad behavior considered and accessibility impact noted.
- Documentation and changelog/decision record updated where needed.
- PR includes screenshot/video when visual and test evidence; reviewer approves.

## 3. Milestones and issue backlog
Dependencies are strict: finish each foundational issue before dependent systems.

### M0 — Repository and reproducible build
- **BTA-001 Initialize project:** Godot 4 project, directory layout, README, .gitignore, license decision placeholder, AGENTS.md. AC: clean clone imports and runs empty main scene.
- **BTA-002 CI validation:** pinned Godot version, headless import and parse, smoke launch, artifact retention. AC: failing syntax breaks CI; successful CI reports engine version.
- **BTA-003 Test harness:** install pinned GUT or equivalent, sample passing and intentionally failing test verified. AC: headless command reproducible locally and in CI.
- **BTA-004 Input/settings scaffold:** named actions and remapping model, settings persistence. AC: keyboard and controller navigation of a test menu.

### M1 — Core submarine prototype
- **BTA-010 Submarine controller:** acceleration, damping, collisions, camera. AC: navigate test cave smoothly at multiple frame rates; no wall penetration.
- **BTA-011 Resource system:** hull/battery/oxygen, signals and balance resources. AC: values clamp; consumption never goes below zero; tests pass.
- **BTA-012 Depth and damage:** authored world depth, safe-depth warnings, collision damage. AC: depth gate telegraphs danger and respects upgrades.
- **BTA-013 HUD:** resource bars, depth, sonar state. AC: values reflect signals and are legible at 1280×800.
- **BTA-014 First region graybox:** safe base, cave, return route, collision layers. AC: start→POI→base loop playable in under 10 minutes.

### M2 — Signature sonar and discovery
- **BTA-020 Acoustic event contract:** event data, registered emitters/receivers. AC: one event reaches eligible listeners without duplicates.
- **BTA-021 Active sonar:** energy/cooldown, expanding visual pulse, detection results. AC: objects reveal at wavefront arrival; out-of-range objects remain hidden; tests cover cost/cooldown.
- **BTA-022 Passive sonar:** bearing/contact UI and acoustic classifications. AC: receives ambient emitter, consumes no ping energy and does not alert creatures.
- **BTA-023 Discovery registry/map:** stable POI IDs, persistent revealed states. AC: discovery survives save/reload; no undiscovered secrets shown.
- **BTA-024 Scientific scanner:** scan targets, progress, research entries. AC: target scanned once, record appears in database, mission event fires.

### M3 — Game loop and AI
- **BTA-030 Creature FSM:** patrol/investigate/return with tuning Resources. AC: controlled acoustic event causes investigate, timeout causes return.
- **BTA-031 Threat encounter:** acoustic predator, warnings, escape. AC: players can evade without combat; external playtest confirms reaction is understandable.
- **BTA-032 Station interaction:** repair/refill and mission board. AC: departure/return cycle restores resources as designed.
- **BTA-033 Upgrade system:** one sonar upgrade and one depth upgrade. AC: each upgrade changes a demonstrable capability, persists across reload.
- **BTA-034 Mission framework:** main objective plus optional scan, idempotent completion. AC: save/load does not duplicate rewards.
- **BTA-035 Save system:** versioned JSON, validation, backup/recovery. AC: corruption handled gracefully; schema migration fixture passes.

### M4 — Vertical slice and external testing
- **BTA-040 Illustrated art pipeline:** style guide, layered background, submarine animation and effects. AC: cohesive scene, acceptable readability at low brightness.
- **BTA-041 Soundscape:** ambient loops, sonar cues, threat audio and visual equivalents. AC: critical information not audio-only.
- **BTA-042 Narrative slice:** expedition log, station briefing, final hook. AC: 20–40 minute complete path, no softlocks.
- **BTA-043 Controller/accessibility pass:** remapping, scalable HUD, reduced effects. AC: complete slice with controller alone.
- **BTA-044 External playtest:** at least five players unfamiliar with game. AC: log completion time, confusion points, sonar frequency, and desire to continue.
- **BTA-045 Slice release candidate:** cross-platform exports and smoke tests. AC: native runtime tested on each claimed platform.

### M5 — Full production (only after slice gate)
Add authored Twilight Reef, Graveyard, Thermal Rift and Abyss content incrementally; expand narrative, creatures, research and upgrades. Treat each region as a complete milestone with level checklist, save tests and playtests. Avoid committing to 6–10 hour campaign until production throughput is measured.

### M6 — Steam demo and launch
Create Steamworks adapter, cloud-save policy, achievement tests, store art/trailer, localization-ready strings, platform signing/notarization as needed, QA matrix, build provenance, privacy and license notices. Verify current Steam requirements before submission. Ship no platform that has not passed native testing.

## 4. First six Claude Code prompts (ready to paste)
### Prompt 1 — Scaffold
"Read GDD.md, TDD.md, CODEX_PLAN.md and AGENTS.md. Implement BTA-001 only. Create a minimal Godot 4.x project with a bootable main scene, prescribed directories, .gitignore and README. Do not add gameplay, dependencies or assets. Report changed files, exact launch commands, and manual verification steps."

### Prompt 2 — CI
"Implement BTA-002 only. Add GitHub Actions validation for a pinned Godot 4.x stable release. Run headless import and project smoke validation. Fail on parser errors. Document how to reproduce locally. Do not introduce export/signing secrets."

### Prompt 3 — Tests
"Implement BTA-003 only. Choose a maintained Godot 4-compatible test framework, pin its version, add sample deterministic tests and a headless test command. Explain the dependency/license and do not change gameplay."

### Prompt 4 — Movement
"Implement BTA-010 only. Create a CharacterBody2D submarine with tunable thrust, acceleration, damping and collisions, a following Camera2D and a graybox test scene. Use typed GDScript. Ensure movement behaves consistently with physics tick. Add testable pure movement calculations where practical. Include keyboard and gamepad actions."

### Prompt 5 — Resources
"Implement BTA-011 only. Add typed Resource definitions and a reusable submarine resource component for hull, battery and oxygen with clamped values and change signals. Add tests for drain, recharge, invalid values and insufficient energy. Do not build HUD or sonar."

### Prompt 6 — Active sonar
"After BTA-020 is merged, implement BTA-021 only. Add sonar pulse cost/cooldown, event emission, range-based target detection and a wavefront visual whose reveal timing follows travel distance. Use injectable detection logic and test cooldown, cost, range and single event emission. Do not implement creature AI or passive sonar in this PR."

## 5. PR template
**Issue:** BTA-###
**What changed:**
**Out of scope / deliberately not changed:**
**Acceptance criteria evidence:**
**Automated test command and result:**
**Manual playtest steps:**
**Screenshots/video (if visual):**
**Known limitations and follow-up issues:**
**Cross-platform impact:**

## 6. Review gates
**Gate A (end M1):** controls are fun and clear, no game-breaking collision bugs, 60 FPS in graybox.
**Gate B (end M2):** sonar meaningfully changes navigation and creates readable choices.
**Gate C (end M3):** full return/research/upgrade loop works with saves and no softlocks.
**Gate D (end M4):** five external playtests; most complete slice without help and at least three express interest in continuing. If not, iterate before expansion.
**Gate E (pre-Steam):** native smoke test for every advertised OS, full controller flow, accessibility checklist, crash-free extended playtest and verified store assets/licenses.

## 7. Time and risk assumptions
M0–M2 may take 2–4 months part-time; M3–M4 another 3–6 months; full production 9–20+ months total or longer. These are illustrative and heavily depend on available weekly hours, art production, iteration and testing. Claude Code accelerates coding but cannot substitute for design judgment or real playtests.

## 8. First action checklist
1. Create private GitHub repository `below-the-abyss`.
2. Pin exact Godot 4.x stable release after verifying installed toolchain.
3. Commit GDD, TDD, CODEX_PLAN and AGENTS.md.
4. Open BTA-001 through BTA-004 as GitHub issues.
5. Ask Claude Code to implement BTA-001 in a branch; review and merge only after clean clone test.
6. Keep an `art-provenance.csv` with asset source, author, license and permissions.

## Authorized post-BTA-044 playtest iteration

Implement the user's consolidated feedback on a separate review branch: optional
saved tutorials, quieter instruments/context prompts, graphical station hub,
meaningful wildlife research, longer outer-shelf/wreck chapter, slower travel drain,
and optional torpedoes with radial NPC damage and excavatable terrain (both scope
choices explicitly confirmed by the user). Preserve numbered milestone fixtures and
cover actual expanded MAIN with new integrations and an input-driven full route.

Acceptance: [feedback matrix and manual checks](docs/feedback/README.md), native
Godot screenshots, all prior GUT rules, parser/import/startup, Python tooling,
controller chapter walkthrough and standalone export smoke. Review through a PR;
no automatic merge. Human pacing/five-player evaluation remains outstanding.

## Authorized second feedback revision

Implement the user's requested title/docking/art/handling/torpedo improvements,
radio-led mission flow, scared wreck encounter, encrypted-log return/decoding and
finite research-point technology tree. Free point reassignment at the station was
explicitly selected. Preserve domain detectors/contracts and old regression fixtures;
verify production MAIN separately through controller input, save/recovery, unit tests,
native screenshots and standalone exports. No next-region gameplay or campaign-wide
research tree is implied. Review in a separate PR; do not merge automatically.
See [acceptance and manual course](docs/feedback-two/README.md).

## BTA-046 Resonance foundation and first story choice

BTA-045 remains reserved for the slice release candidate. On review of main after
PR #27, the tracker has no separate issue/milestone number reserved for Resonance,
so this focused user-authorized implementation uses BTA-046.

- Scene-owned StoryState, stable authored choices, hidden bounded Resonance and flags.
- Atomic schema-5 checkpoint extension, silent version-1–4 migration and no replay farming.
- One optional Zone 1 bloom: timed scan/unharmed or destructive specimen collection.
- Reuse scanning/sonar/Interact/accessibility; isolated Wick/Okafor/Crane response text.
- GUT, parser/import/startup, both input devices and separate-process Continue, Linux export.
- Native graphical evidence, commands, manual acceptance and limitations in
  [BTA-046 verification](docs/testing/bta-046/README.md). No new region/endings or automatic merge.

### Authorized Story Bible alignment follow-up

After PR #28 the user supplied the Story Bible and approved aligning the encounter.
Replace the rooted bloom with geometric plankton and a presentation-only arrival
spiral/scatter; show a static alternative for reduced effects. Align the three
character voices, archive the source PDF and explicitly distinguish the shallow
prototype wreck from canonical Lantern-1. Preserve schema 5, all stable IDs, flags,
balancing, progression and gameplay. No later zones or wider Resonance mechanics.
Review in a separate follow-up PR; do not merge automatically.

## BTA-047 — The Sunlit Shallows

User-authorized complete canonical Zone 1, based on the supplied Story Bible,
starting from main after PR #29. The issue/milestone tracker contains no newer
reserved number; BTA-045 release candidate and BTA-046 Resonance retain their IDs.

- Interactive Halcyon briefing, Lantern-2/Wick and contextual first-dive guidance.
- Existing exclusive light-bloom decision; new sonar-discovered, deliberately
  scanned Lantern-1 emergency buoy with Mara's exact message and permanent log.
- Meaningful return/debrief using the existing mission ledger, scientific records,
  domain return signals and atomic checkpoint. Both choices complete without combat.
- Compatible presentation mapping: retain prototype NERIS/Shelf Base/wreck IDs and
  prior records; never identify the shallow prototype wreck as Lantern-1.
- Schema 6 accepts prior versions and two/five/six-mission catalogues; no new save
  file, campaign architecture, economy, playable Zone 2 or ending.
- Preserve technology, station services, creatures, weapons and legacy route fixtures.
- Full GUT/import/parser/startup/Linux export, actual-input fresh/Continue routes,
  native screenshots, small-window/muted/comfort verification. Human comprehension
  and pacing remain separate evaluation gates.

[Implementation, route, migration, evidence and limitations](docs/testing/bta-047/README.md).
Review in a separate PR; do not merge automatically.

## BTA-048 — Compact HUD, radio notifications and mission tracker

User-authorized interface redesign based on main after merged PR #30. Replace the
production resource deck with icon/percentage readings, center depth/rating, retain
all warnings/secondary instruments and leave the bottom center clear. Project
accepted canonical/legacy objectives from existing services into an upper-right
tracker. Ordinary radio arrival and transcript expansion must preserve simulation,
velocity and movement; explicit acceptance/acknowledgement still uses the existing
ledger/checkpoint. Add a conflict-free, compatible remappable radio action. No new
story, gameplay, dependencies, save fields or region. Verify native comparisons,
all supported sizes/accessibility, complete actual-input routes, full regression
suite and Linux release. [Decisions, commands, route and evidence](docs/testing/bta-048/README.md).
Review in a separate PR; do not merge automatically.

## BTA-049 — Cinematic title and visual identity

User-authorized presentation milestone based on main after merged PR #31. Compose
The Halcyon Descent using original shared Lantern-2/three-module Halcyon SVGs,
layered cliffs, dark navigation space and restrained cosmetic motion. Preserve
all existing title callbacks, Continue/recovery/prototype access and PR #31 HUD.
Demonstrate the shared art only at the immediate canonical dock, preserving all
terrain/camera/navigation/physics and save contracts. Respect comfort/text/contrast
preferences and all input devices. Verify GUT, import/parser/startup, canonical
input routes, native captures/performance observations and clean Linux export.
No region, mission, mechanic or narrative expansion. Review in a separate PR; no merge.
See [workflow and evidence](docs/testing/bta-049/README.md).


### BTA-049 requested review revision (same branch)

Audit all UI text roles and replace scattered oversized values with UiTypography;
constrain narrative, station, log and settings dialogs without changing their input,
pause, save or recovery rules. Replace the initial geometric title masters with
recorded AI-generated illustrated hardware, water, cliff, basalt and optics assets,
shared with gameplay; retain collision geometry and stable IDs. Capture native
before/after UI at 800x600 and 1280x800 plus 1920x1080 and Large/High Contrast.
Preserve all prior tests/routes/export. Do not create another PR or merge. PR #32
was already merged externally before this request, so follow-up commits on its
existing branch cannot become part of that closed review diff. See the revision
record for exact validation results and remaining external review limits.


## BTA-050 — Sunlit Shallows environmental art overhaul

User-authorized art-only milestone from main after merged PR #33 (`8e13432`).
Replace canonical geometric vegetation/scenery/fauna with reusable illustrated
assets, layered atmospheric perspective, textured geology and Halcyon/buoy detail.
Keep every collision, mission/research location, camera rule, resource, input/UI,
progression and save contract. Scope dressing to the existing 0–200 m chapter;
prototype mode restores its prior presentation. No region, mission, decision,
upgrade, economy or dependency expansion. Honor existing comfort flags and avoid
per-frame procedural geology/excess particles. Verify full tests/routes/export,
actual-input chapter, native same-pose comparisons and measured software-renderer
frame/draw/memory observations at all three sizes. No target-GPU or human visual
acceptance claim without those reviews. Separate branch/PR; never merge automatically.
[Implementation and evidence](docs/testing/bta-050/README.md).


## BTA-051 — expanded Sunlit Shallows and performance optimization

User-authorized focused milestone after merged PR #34. Enlarge only the canonical
opening chapter, contextual map/report guidance, a physical excavation traversal
gate, optional rated-depth vent, sonar-only buoy, lightweight illustrated schools,
scientific notifications and atomic capped research XP. Preserve both bloom paths,
legacy records and all prior controls/services/technology. Reuse all existing
acoustic, mission, scan and save contracts. No Zone 2 or future-story reveal.

Acceptance/evidence: [BTA-051](docs/testing/bta-051/README.md). Human first-time
15–20 minute pacing and target-GPU 60 FPS remain explicit unverified targets.

## BTA-051 PR #35 review revision

User-authorized additional shallow passages and dead ends, collision-matched rough
rock and three-shot excavation, illustrated eel/turtle and optional escapable
hammerhead ram, bounded underwater effects, radio/bubble sound and swimming bloom.
Title New Game explicitly confirms and archives all campaign stores; preferences
remain. Existing schema-7 checkpoint/legacy IDs, chapter, services and research stay
compatible. [Implementation, API/save rules, evidence and limitations](docs/testing/bta-051/revision/README.md).

## BTA-052 — Surface expedition and instrument polish

User-directed follow-up to PR #35: open-water shelf with optional excavation caves,
above-water Halcyon/deeper departure, direct visible scanning, compact ammo/scroll UI,
typed auto-dismissing radio, five priced/icon-labelled research branches, compatible
schema-8 migration, original outward sonar (returns removed on review), illuminated terrain, animated
existing fauna, red beacon, detailed torpedo artwork and original quiet score.
Preserve canonical story, hidden buoy, old IDs/progress and development prototype.
Acceptance/verification/evidence: docs/testing/bta-052/README.md. Review only; no merge.

Visual-review follow-up stays on the BTA-052 branch: submerged-only background,
rounded matching terrain/collision/map, warm destructible geology, opt-in sheltered
buoy reception, propulsion-driven animal animation, bounded stronger hammerhead,
original radio portrait atlas, and removal of obsolete canonical prototype markings.
No new milestone or save schema. Evidence: docs/testing/bta-052/revision/README.md.

## BTA-053 — Buoy handoff and Twilight Shelf foundation

First implementation step of the user-approved chapter design and revised handoff.
Scope: optional buoy/log finish, atomic shared checkpoint transition and recovery,
full deep deployment with authored pressure fit, central return/refit tether, and
bidirectional graybox loops. Preserve manual/legacy routes and all prior systems.
Do not implement the full sentinel/log/glyph narrative or its rewards in this PR.

[Implementation, verification and manual route](docs/testing/bta-053/README.md).

## BTA-054 — Twilight environment, wildlife and erupting vents

User-authorized follow-up to merged PR #37: illustrated level detail, natural NPCs
and a reusable non-depth hull hazard. Preserve the two loops and existing campaign
contracts; use warning/quiet windows and bypasses, deterministic simulation-time
thermal damage, existing acoustic AI, pause/comfort settings and existing saves.
Do not implement the later sentinel/log/glyph narrative or new rewards in this pass.
[Acceptance, commands, evidence and limits](docs/testing/bta-054/README.md).

## BTA-055 — Twilight Shelf expedition and narrative

Authorized by the user's “Do BTA-055”: finish the approved cable/wreck/log/first
marking/sentinel investigation on the BTA-054 branch, preserving both approaches,
hazards, refitting, research, Chapter 1 and legacy saves. BTA-054 was the branch
dependency during implementation and is now merged as PR #38 (main `55d1769`);
this review contains only BTA-055 changes.

Use existing research, mission, StoryState and checkpoint authorities; three Mara
loggers (two optional), release/capture/casualty outcomes, explicit station debrief,
once-only 2 RP plus capture-only 1 RP/+100 sonar calibration. No new currency,
Zone 3, full translation, Mara-fate reveal, ending or combat framework.
Verify all GUT/import/parser/startup/export checks, both ordered real-input courses,
separate-process Continue and native mute/comfort/small-screen captures. Distinguish
automated timing from the unverified 30–45-minute human pacing target. Review through
a separate PR targeting main; do not merge automatically.
[Acceptance, commands and evidence](docs/testing/bta-055/README.md).

## BTA-056 — Twilight Shelf Exploration and Pacing Polish

Authorized by the user's “Do this: BTA-056”. Begin after merged PR #39/BTA-055.
Add connected central passages, two reversible observation pockets, optional cable
and thermal observations, an actual-animal glimpse and subject-specific research
art. Preserve mandatory evidence/choices/rewards and all prior systems. Validate
actual hull clearance, optionality, persistence and keyboard/controller complete
routes. Record native screenshots and simulation timings separately from the
unverified 30–45-minute first-time human pacing target. No later region or artificial
waiting. Evidence and manual protocol: docs/testing/bta-056/README.md.

## BTA-057 — Twilight sonar visibility / Phase 1

User-approved dim-but-readable Standard darkness plus Reduced preference, Twilight
only. Scene-owned presentation reuses accepted sonar wavefront timing and actual
collision contours. Keep close-range quiet navigation, headlight and textual cues.
No expedition schema/map/story/progression changes. Release assertions must not own
side effects; verify the actual exported wiring positively and with disconnection.
Evidence and limitations: docs/testing/bta-057/README.md. No human playtest claims.
