# BTA-051 — expanded shallow survey and atomic science XP

**PR #35 feedback update:** [revised geography, three-shot gate, compatibility and New Game](../testing/bta-051/revision/README.md) records the final behavior; initial capture/performance evidence remains historical.

Base: merged PR #34, main ce64e08. Canon is docs/story/Below_the_Abyss_Story_Bible.pdf.
This expands only the existing Sunlit Shallows expedition. The local optional vent
is not a playable Twilight Shelf or a revelation about Lantern-1's eventual fate.

## Composition and authoritative state

SunlitSurveyData authors the canonical extension, studies, search report and route.
SunlitRegionLayout owns protected collision-bearing basalt and one existing
DestructibleRock, `sunlit-cavein`. SunlitFieldGuide adapts existing discovery,
research, acoustic, radio and mission signals. It owns no second mission ledger.
SunlitDressing and ExcavationSediment are cosmetic, separate from terrain.

The original Halcyon/light-bloom core remains. The former eastern cap is replaced
by a winding corridor to world x=21920. Alternating ridges allow upper/lower
approaches; the arch has a lower opening and the vent is a retraceable optional
branch. The required route stays at y≤800, or 200 m under the unchanged 0.25 m/unit
mapping with surface y=0. The vent ends at y=2500 (625 m), below all existing fitted
300/400/450/500 m ratings. Damage always uses the actual hull API, grace and rate;
there is no proximity damage trigger. The shallow vent-margin study is possible
without entering pressure damage. World signs and urgent text accompany the HUD.

The rough 380-unit-thick rockfall takes three well-placed 150-unit blasts.
Completion requires a swept 600×68 whole-hull opening, not a detonation, count
or narrow puncture. Checks cache
the current topology. Existing excavation records persist cuts; the ordinary
DiscoveryRegistry records `sunlit-cleared-passage` once when an opening qualifies.
Ammunition remains ten and deliberate Halcyon docking rearms it. The western return
route remains open even with no ammunition. Protected basalt prevents excavation
into unfinished space. There is no required wildlife combat.

The buoy keeps its original stable IDs and exact message but moves to (20800,620).
The map initially reports an approximate area centered at (20000,500). Its exact
sprite, scan eligibility and map point remain hidden until the existing active
sonar wavefront reveals its target. It has no collision body to betray its location.
First discovery is permanent even after echo brackets expire; passive contacts
never discover it. Old saves that already found the buoy keep that discovery.

Archived distant prototype markers are excluded from the canonical map presentation
without deleting their permanent records; prototype mode restores them. This avoids
mistaking the unrelated shallow prototype wreck for Lantern-1 when bounds expand.

The map distinguishes charted solids, hatched unsurveyed sectors and the dashed
reported search area. Sector charting derives from existing permanent POIs;
there is no fog save or parallel progress system. Focusable zoom/pan/follow controls
reuse current menu inputs and are absent from the legacy prototype view.

## Wildlife and scientific presentation

Six schools contain 5–12 individuals each (48 total). Three are species records,
not per-instance rewards. Each school has one AcousticReceiver and one MultiMesh,
no fish physics bodies. A static habitat query conservatively disables a school
whose rectangle intersects solid terrain; the bounded model stays inside it.
There is no expensive per-fish navigation. Motion uses fixed 1/60 steps, smooth
heading changes, coordinated targets, speed variation and neighbour separation.
Distant schools suspend their model; this is intentionally not globally elapsed
wildlife simulation. Passive ambient sounds cannot startle them. Loud active sonar
and explosions use the unchanged scene bus, bounded local duplicate history and
existing bus event epochs. The shared AcousticBus/history contract is unmodified.

The canonical ambient field uses the same existing emitters/field APIs: Halcyon's
mechanical activity and a geological vent source. Old prototype acoustic sources
and creatures remain available in prototype mode, suspended in canonical mode.
No ghost wreck acoustics are transplanted into the canonical chapter.

A compact scientific notification uses the actual subject atlas/thumbnail, name,
classification, description and first-time XP. It never owns focus or consumes
piloting input. Four queued records maximum; eight visible simulation seconds.
Pressure danger, radio previews, tutorial cards and modals take priority. Full text
remains in Research Log; nearby repeat Interact reviews it with zero XP. It is
separate from critical resource/status instruments and supports semantic typography.

## Schema 7 and migration

The existing expedition file remains the sole canonical checkpoint. It retains
its eleven top-level fields. `prototype.campaign` gains exactly one field:

```json
"science": {"credited": ["sunlit-silver-shoal"], "imported": []}
```

Both arrays contain unique, disjoint, allowlisted scan IDs. Every eligible completed
record must occur in exactly one array; an award without its research record is
invalid. XP is derived from authored credited IDs, never stored as a mutable total.
ResearchExperienceRules is a validated Resource: species 20, scientific studies 30,
100 XP per extra point, maximum two extra points. Historical/prototype earned points
and assigned ranks are unchanged. Existing free station reassignment still applies.
Resonance, mission rewards and this scientific budget are independent.

Versions 1–6 migrate in memory. Eligible old completed records become `imported`
with zero retroactive XP. No old discoveries, scans, choices, flags, resonance,
mission objectives/claims, terrain cuts, vessel checkpoint or talent ranks are
reset. Existing legacy catalogues still normalize through their existing migrations.
Reading does not write files or replay completion/choice/reward signals. A later
legitimate checkpoint writes version 7. The new studies can provide both bonus
points even when prior records are historical. Released XP rules are part of this
schema's meaning: changing awards for already released IDs requires an explicit
migration, not editing weights and silently recalculating prior allocations.

The scanner's existing completion gate proposes both research and credit in one
candidate checkpoint before ResearchRegistry emits completion. Live revision state
uses the committed normalized candidate only after a successful write. Canonical
bloom observation uses the existing exclusive StoryState transaction. Collection
does not fabricate a scan or scientific award. Other historical/prototype completions
are reconciled as imported; they never acquire XP by replay.

The existing Store writes latest validated progress to backup before replacing the
primary atomically. A primary-write failure can therefore leave a complete new
candidate in the backup, while the live operation reports failure and grants no
record/XP/event. Explicit backup recovery can restore the complete pair silently.
It never restores half an award. Monotonic history and credit checks reject stale
writers. Continue/restart merge permanent earned IDs without stacking or replay.
Missing/corrupt/incompatible files retain existing explicit recovery semantics.

Safe checkpoints reject depleted hull or oxygen, preserving the previous checkpoint.
This does not add a death screen, penalty or respawn architecture. The existing
Pause → Continue or Restart Test Route remains the recovery interface; a once-only
text message explains it. Station docking restores resources only by deliberate
interaction. Services do not erase science, cuts, story or missions.

## Confirmed optimizations and limits

Scanner setup snapshots immutable primitive scan definitions once; hot range,
readiness and progress queries reuse them instead of recursively duplicating
Resources/textures. Public registry definitions remain separate Resource copies
with shared immutable artwork. Decorative rock meshes use a bounded 64-entry
numeric geometry cache and invalidate changed stone only. Canonical decoration
initialization is lazy; disabled prototype terrain is excluded from painting,
excavation and safe-position checks. Old visual/material state is restored for
prototype mode. Fish are batched, viewport-aware and redraw at most 20 Hz; ambient
sediment stays in a bounded camera-local patch rather than thinning across the
larger world. No source raster resolution or artwork has been reduced.

Native wall-frame/monitor measurements and the controlled scanner benchmark are
reported separately. The baseline world is smaller: shared camera framing is
fixture-only, and expanded samples use the actual new camera. Software llvmpipe
cannot certify modest desktop GPU 60 FPS. Human comprehension, visual approval and
15–20 minute first-time pacing remain external acceptance tasks.
