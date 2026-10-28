# Below the Abyss — Technical Design Document
Version 0.1 | 2026-10-25 | Target: Godot 4.x stable, typed GDScript

## 1. Architecture principles
1. Build a playable vertical slice before advanced infrastructure.
2. Keep game rules independent of scene visuals; parameterize balance using Resources.
3. Prefer composition and signals to inheritance-heavy systems and hardcoded node paths.
4. Avoid global singleton sprawl: autoload only truly global services (GameState, SaveService, AudioSettings, SceneRouter).
5. Keep persistent identifiers stable; never use transient instance IDs in saves.
6. Profile before optimizing; avoid C++/GDExtension until a measured bottleneck.
7. Support keyboard/mouse and gamepad in every UI flow.

## 2. Stack
Godot 4.x stable, GDScript (static typing), Godot 2D physics/rendering, Resource definitions for authored data, versioned JSON for saves, Git/GitHub, headless Godot for import/smoke checks and GUT or an equivalent pinned Godot test framework for logic tests. Godot export templates pinned to engine version. Windows/Linux/macOS desktop builds; Steamworks integration only after core gameplay is independent and tested.

## 3. Repository layout
```
project.godot
AGENTS.md
README.md
assets/{art,audio,fonts,shaders}/
scenes/{main,player,creatures,regions,stations,ui,props}/
scripts/{core,player,sonar,ai,missions,world,persistence,ui}/
resources/{equipment,creatures,missions,regions,balance}/
tests/{unit,integration,fixtures}/
tools/
docs/{design,decisions,testing}/
.github/workflows/
```
Source naming: `snake_case.gd`, `PascalCase` class_name, signals in past tense (`pulse_emitted`), methods and fields snake_case. Explicit types on public interfaces.

## 4. Scene hierarchy (initial)
```
GameRoot (Node)
├── WorldRoot (Node2D)
│   ├── CurrentRegion (Node2D)
│   ├── PlayerSubmarine (CharacterBody2D)
│   └── WorldEffects (Node2D)
├── Camera2D
├── UI (CanvasLayer)
└── Audio (Node)
```
PlayerSubmarine child components: Sprite/AnimatedSprite2D, CollisionShape2D, Light2D, SubmarineMotor, ResourceSystem, HullSystem, SonarEmitter, PassiveReceiver, Scanner, InteractionArea. Favor small focused scripts. Physics in `_physics_process(delta)` and presentation in `_process(delta)`.

## 5. Core data contracts
`SubmarineStats` Resource: max_hull, max_battery, max_oxygen, safe_depth_m, thrust, drag, acoustic_signature, equipment_slots.
`EquipmentDefinition` Resource: stable_id, display_name, slot, modifiers, unlock_requirements.
`AcousticProfile` Resource: reflectivity, emission_class, base_noise, hearing_multiplier.
`CreatureDefinition` Resource: stable_id, senses, patrol_speed, investigate_duration, threat_level.
`MissionDefinition` Resource: stable_id, prerequisites, objective definitions, completion effects.
`RegionDefinition` Resource: stable_id, scene_path, depth_band, music_profile, ambient_profile.

Resources are authored data, not mutable global state. Runtime values live in components and serializable state objects. Validate IDs at editor/test time.

## 6. Simulation contracts
### Movement
Use CharacterBody2D with custom acceleration and damping for predictable handling; apply `move_and_slide()` and derive collision impacts from relative speed. Buoyancy is a tuned upward force, not a fluid simulation. Set physical units consistently (world pixels versus depth meters); world depth is derived from authored region offsets rather than arbitrary global Y assumptions.

### Battery, oxygen, hull
A single ResourceSystem applies costs with methods `try_consume_battery(amount)->bool`, `restore_battery(amount)`, and fixed-step drains. Clamp to [0,max]. `HullSystem.apply_damage(amount, source_id)` emits `hull_changed` and `vessel_destroyed` once. No HUD script changes gameplay state directly.

### Sonar
`SonarEmitter.request_ping()` checks cooldown and battery, then emits `pulse_emitted(event)` and spawns a wavefront visual. `AcousticEvent` holds origin, source_id, event_type, strength, timestamp/tick. Detection results are computed through an injectable query service for unit testing. Visual wavefront reveal is timed by `distance / visual_wave_speed`; gameplay hearing is separately determined by event propagation rules. Raycast or collision-mask occlusion is optional for v1 and must be specified consistently. Avoid per-frame checks against every object: use physics broadphase queries or registered targets plus spatial filtering.

`PassiveReceiver` listens for emitter events and displays bearing and signal class with bounded uncertainty. Passive listening must not accidentally trigger active sound events.

### Creatures
Shared state machine with Idle/Patrol/Investigate/Pursue/Flee/Return. Inputs: visual contact, acoustic event, damage, territory. Use deterministic state transition tests with injected inputs. Cap pathfinding and perception update rates.

### Interaction and missions
`Interactable` contract exposes `can_interact(context)` and `interact(context)`; mission updates use typed domain events (`log_recovered`, `region_entered`, `scan_completed`) and stable IDs. MissionService validates prerequisites and idempotently applies completion rewards. Essential progression cannot depend on a nonpersistent transient node.

### Implemented BTA-042 narrative projection

NarrativeEntry/NarrativeCatalog Resources validate original text, stable IDs and
bounded evidence selectors. Scene-owned NarrativeService projects the existing
MissionService, DiscoveryRegistry and ResearchRegistry into a rereadable log;
Begin survey delegates acceptance of the two existing missions, and station debrief
delegates their existing docking-guarded, idempotent claims. No new mission ledger,
checkpoint field, store, reward or event dispatcher. Research/POI/mission IDs and
schema versions remain unchanged; old saves reconstruct their eligible entries.
MissionService.records_restored explicitly distinguishes silent restoration from
real completion/acknowledgement signals. Generic registry refreshes update UI;
record_unlocked/chapter_concluded are bounded presentation events from actual domain
transitions, never replayed during load. The start/pause page contains the concise
opening briefing; ExpeditionLog supplies focus navigation and text-scroll buttons.
See [story/API/IDs/save decisions](docs/narrative_slice.md) and
[verification and actual native walkthrough](docs/testing/narrative_slice.md).

## 7. World and level pipeline
Build one authored region as a Godot scene with TileMapLayer or collision polygons, parallax backdrops, POI markers, acoustic targets and spawn points. Use separate static collision and interaction layers. Start with discrete transitions at tunnels/airlocks. Seamless neighboring-region streaming is deferred until demonstrated necessary. Keep a region checklist for spawn safety, return route, discovery, landmark, optional secret and performance budget.

## 8. Rendering and art pipeline
Target a consistent 2D reference composition (e.g. 1920×1080, responsive to 16:10). Import layered PNG/WebP textures; use Godot 2D lights, CanvasItem shaders and parallax sparingly. Maintain a style guide for color, silhouette, lighting, texture scale and depth fog. Implement light/particle quality tiers. Art source files retained separately where licensed. Avoid relying on image generation for game-ready animation without human cleanup.

## 9. Input, UI and audio
Godot InputMap actions: `move_left`, `move_right`, `move_up`, `move_down`, `sonar_ping`, `interact`, `toggle_lights`, `open_map`, `pause`. Every action gets keyboard and gamepad bindings. UI navigation uses Godot focus controls, minimum readable font sizes, no color-only states. Use audio buses Master/Music/Ambience/Effects/UI and route critical sound cues to optional visual indicators.

### Implemented BTA-041 presentation audio

The shelf owns SoundscapeMixer + GameplayAudio; no audio autoload or gameplay
AcousticBus registration. AudioCue/SoundscapeProfile Resources define semantic
playback requests, category routing and bounded voice/rate/mix controls. Accepted
active pings, wavefront echoes, passive contact snapshots, scanner/research signals,
resource/damage APIs, station UI/services and existing creature phases drive audio.
Five looping players and ten one-shot slots use original offline-synthesized PCM.
SettingsStore version 1 accepts an optional strictly validated audio object and
legacy input-only preferences; expedition schema stays version 2. Critical cues
retain visual equivalents, including the low-resource badge. Headless tests exercise
routing/requests without starting audio playback handles. See
[audio direction, API, source/licensing and accessibility](docs/audio_direction.md)
and [native verification](docs/testing/soundscape.md).

### Implemented BTA-043 input and accessibility policy

Scene-owned InputContext observes deliberate input, formats remap-aware hints and
releases held actions on active-controller loss; ShelfPrototype pauses or retains
the current modal. Fixed UI recovery actions remain independent of gameplay
remapping. Menu navigation/confirm takes priority over remapped Pause/Map actions.
UiAccessibility caches authored font/styles and coalesces preference/resize/node
updates. Large menus reparent content into focus-following scroll containers;
small-screen HUD variants preserve numeric/state information and separate warning
slots. Cosmetic flags modify existing mote/parallax/propeller/sonar presentation,
never simulation or acoustic history. No new singleton/dependency or gameplay loop.
AccessibilityPanel has live preview, explicit Save and scoped cancellation/defaults.
SettingsStore version 1 accepts optional strictly validated accessibility alongside
legacy input/audio documents, adding defaults in memory only. Invalid preferences
remain unchanged until explicit Save preserves rejected bytes in a non-overwriting
.invalid file before atomic replacement. Input defaults are scoped separately from
audio/accessibility. Campaign schema remains version 2. See
[controls, architecture, recovery and limitations](docs/accessibility.md) and
[tests/native evidence](docs/testing/accessibility.md).

### Implemented BTA-044 local playtest instrumentation

PlaytestObserver is a scene-owned read-only adapter, composed only for playtest
mode/builds. Explicit session consent starts PlaytestRecorder; no preference or
campaign field enables it automatically. Monotonic wall time is split by vessel
simulation state. Existing sonar/research/discovery/mission/damage/narrative signals
supply bounded allowlisted events. The existing route sampler also exposes base
entry/departure observations without changing stage/progression logic; checkpoint
restore synchronizes occupancy and emits a restore notification silently to adapters.
PlaytestStore validates bounded JSON, atomically replaces it with a previous-valid
backup, and derives readable text; no network/API or raw input/log hook. New launches
never resume recording. Reports and anonymous feedback remain separate unless the
participant explicitly shares an ID. The Linux release preset excludes test fixtures
and hides developer controls; explicit nested hearing Resources preserve existing
creature settings through binary export, with no hearing/motion balance changes.
See [toolkit, privacy/format and pending human-study gate](docs/playtesting/README.md).

## 10. Persistence schema
Store under `user://saves/slot_N.json` using a schema version and separate backup file. Example:
```
{
  "schema_version": 1,
  "save_id": "slot_1",
  "region_id": "continental_shelf",
  "player": {"position": [120.0, 450.0], "hull": 95.0, "battery": 60.0, "oxygen": 88.0},
  "equipment_ids": ["basic_sonar"],
  "completed_mission_ids": [],
  "discovered_poi_ids": [],
  "world_flags": {}
}
```
Validate schema, numeric bounds and IDs on load. Write to a temporary file and replace only after successful flush/close; preserve last-known-good backup. Add migration functions for each version change. Do not serialize Godot scene trees or executable objects. Handle malformed saves with user-visible recovery options.

### Implemented BTA-035 checkpoint contract
The scene-owned SaveCoordinator uses `user://saves/expedition.json`, schema version 5 (migrating versions 1–4),
for vessel pose/resources, region, route telemetry and permanent discovery/research/
mission/upgrade records. Valid legacy stores import monotonically without deleting
their files; their optional checkpoint-writer port then routes normal-game commits
to the canonical file. Continue validates before restoration, zeros velocity, clears
transient effects and falls back to clear base if the saved pose is obstructed.
Manual saving requires a safe pause; station interactions checkpoint automatically.
New Expedition requires confirmation and retains permanent records. Latest-checkpoint
backup recovery preserves rejected files and claims. Version 1 has an explicit
migration fixture; incompatible versions are blocked, never silently overwritten.
See [the implemented schema and recovery decisions](docs/decisions/bta-035-general-save-system.md)
and [verification/walkthrough](docs/testing/expedition_save.md). Slots, arbitrary scene
serialization and later-region persistence remain unimplemented.

## 11. Testing and CI
Headless project import and parser validation on every pull request. Unit tests for energy bounds, sonar cooldown/range, mission idempotence, AI transitions and save migration. Integration tests for ping→contact→creature investigation, upgrade→depth gate, and save→reload→objective state. Maintain a minimal smoke scene for automated startup. Build release exports using pinned Godot binaries/templates; Windows and Linux CI exports, macOS export plus native macOS smoke test and signing/notarization workflow when distribution is ready. CI export success is not evidence of platform runtime correctness.

## 12. Performance and platform targets
Initial target: stable 60 FPS at 1080p on a documented midrange GPU, with Steam Deck readability at 1280×800. Profile overdraw, 2D lights, particle counts, large textures, physics query frequency and AI updates. Offer graphics quality settings and VSync. Keep platform-dependent paths behind OS APIs, never assume case-insensitive filesystems. Test Linux/Windows/macOS input, save paths, audio, fullscreen/windowed behavior and controller detection.

## 13. Steam integration and shipping
Core game runs without Steam. Steam-specific achievements, overlay and cloud saves live behind a service adapter; fallback is a no-op implementation. Never commit Steam credentials. Check Steamworks requirements and platform signing at implementation time. Publish only tested binaries. Keep third-party licenses, attribution, asset provenance and trademark clearance documented.

## 14. Security and privacy
No required account, telemetry or network access. Treat saves as untrusted input. Restrict loading to expected resource IDs and schema; avoid dynamic script execution from user data. Store no personal information beyond local preferences and optional Steam identifiers handled by Steamworks.

## 15. Architecture decisions to record
ADR-001: Godot 4/GDScript. ADR-002: authored regions over procedural world. ADR-003: discrete region transitions first. ADR-004: versioned JSON saves. ADR-005: Steam optional service adapter. Revisit only with evidence and approval.

## Playtest-feedback extension (2026-10-27)

The scene-owned `ShelfExpansion` composes cloned authored catalogs with the existing
shelf and exposes the previous compact version through a development fixture.
`TutorialDirector` owns optional hint sequencing; SettingsStore's optional validated
onboarding group preserves legacy mappings and adds a collision-free weapon binding.
`PilotContext` and the quiet HUD project existing domain state without route text.
The station coordinator adds a graphical overview and retains service/domain APIs.

`TorpedoLauncher` owns stepped swept projectiles, bounded effects and registered
`BlastReceiver`s. Explosions use the existing AcousticEmitter/Bus contract; neither
active-sonar duplicate/history semantics nor passive-listening behavior changes.
`DestructibleRock` shares exact clipped polygons between visuals and collision.
Excavation has authored IDs, a bounded deterministic replay journal and protected
boundaries; no third-party terrain dependency or singleton is introduced.

Expedition schema 3 adds terrain cuts and a legacy-conclusion flag; strict version
1/2 migration, atomic checkpoints and explicit backup recovery are retained.
Terrain is replayed before checkpoint collision clearance. Permanent progress and
terrain survive route resets; temporary wildlife/projectiles reset. Details and
limits: [feedback implementation and verification](docs/feedback/README.md).

## Second feedback implementation

ExpeditionRevision is a scene-owned adapter over the existing acoustic, mission,
research, discovery, service, upgrade and checkpoint contracts. Production title/
dock/radio pages are separate, with focus navigation and fixed text-scroll controls.
SubmarineUpgrades accepts a validated capability projection from ResearchTree /
CampaignData while preserving active pulse/history/cooldown and depth APIs. Award IDs
are unique and available points derive from earned awards minus allocated ranks.
Capabilities reconstruct from baselines; legacy install IDs migrate to Rank I.

Schema 4 adds validated ordnance/campaign state, migrates versions 1/2/3 and preserves
atomic backup/recovery. New ranks commit before capability changes. Recovery merges
earned flags monotonically, while allocation changes remain intentional and free.
The shared creature FSM adds FLEE for a bounded, collision-safe wreck encounter.
Accelerating torpedoes integrate exact travel distance and own bounded fading wakes;
local impact refraction is cosmetic and suppressed by comfort options. Authored
Resources supply production motion, ordnance tuning and research capabilities.
[Architecture, exact commands, limits and graphical evidence](docs/feedback-two/README.md).

## Resonance foundation (BTA-046)

StoryState is a scene-owned Node, with validated authored ChoiceData Resources and
a frozen StoryChoiceCatalog. It is the single authority for hidden Resonance,
mutually exclusive encounter decisions and whitelisted story flags. No autoload,
second mission ledger or new save file. Ordinary deltas are bounded to ±15; an
explicit exceptional-weight definition may use ±25, with no future-zone content.
Tiers are Listener >=40, Neutral -39..39, Hostile <=-40; values clamp to [-100,100].

Expedition schema 5 adds `story: {resonance, flags, decisions}`. Validation checks
the ordered clamped sum against known unique decisions/encounters and their flags.
Versions 1–4 migrate to zero/empty story without inferring past morality or losing
ordnance, campaign, mission, research, discovery, terrain or vessel records. Existing
atomic checkpoint/backup/recovery ports remain authoritative. Restoration is silent;
UI projections refresh explicitly. Monotonic compatible history merges preserve
live choices during recovery; opposite branches fail without overwriting files.

The bloom research-completion gate writes the positive choice and its research ID
in one checkpoint transaction before either gameplay completion signal. Failed
writes leave both uncommitted. Collection uses the same StoryState commit port.
The narrow LightBloomEncounter adapter reuses sonar eligibility, the typed scanner,
Interact, simulation pause and accessibility policy; canonical names are confined
to authored response text. No existing campaign/save IDs are renamed.
See [contracts, tests and limitations](docs/testing/bta-046/README.md).

The supplied [Story Bible](docs/story/README.md) now anchors the bloom as geometric
plankton. Arrival presentation is scene-owned, pauses alongside vessel simulation
and uses a static alternative for reduced effects. Collection removes the glowing
patch rather than leaving a plant stump; the response illustration shows an unlit
vial. This presentation alignment changes no choice IDs, deltas, flags, save schema,
mission/sonar/scanner contracts or checkpoint semantics.

## Canonical chapter adapter — BTA-047

Scene-owned `SunlitShallows` projects authored narrative Resources over existing
MissionService, ResearchRegistry, StoryState and GrayboxRouteCheck signals.
MissionObjective adds STORY_CHOICE and RETURN_AFTER_SCAN; the latter requires a
real base-entry event after eligible evidence, rather than old COMPLETE telemetry.
The chapter has one stable mission record; there is no second ledger/log save.
Prior permanent bloom/scanning evidence counts on acceptance; rewards are idempotent.

The scanner's existing completion gate commits the buoy research record together
with a clear, non-dangerous vessel checkpoint **before** scan_completed or dialogue.
Save failure grants nothing. Narrative presentation callbacks let the existing log
project canonical entries and debrief; silent restoration never re-emits evidence.
Read-only buoy replay and log access do not rescan or repeat rewards.

Expedition schema 6 retains the existing eleven top-level fields. Versions 1–5,
old two/five-mission catalogues and narrow-store imports remain validated. The
six-mission catalogue adds an available/unaccepted canonical mission, retaining
old records verbatim. Scene projection preserves unseen records in the coordinator;
monotonic recovery keeps decisions, acknowledgements and buoy evidence. Loading
alone does not replace the old checkpoint. Explicit chapter launch discloses its
new departure pose; the legacy prototype title option remains available.

Canonical display names are presentation mappings; source acoustic/save IDs and the
old shallow wreck are unchanged. Protected limits at y=800/x=3900 prevent entering
future depths; camera/map bounds match the first course. Explicit prototype mode
disables these chapter-only bounds and restores existing outer-course behavior.
See [APIs, commands, migrations and verification](docs/testing/bta-047/README.md).

## Compact production interface — BTA-048

ResourceGauge normalizes finite current/positive-maximum readings before display-only
rounding. The compact path uses existing glyphs, exact-third status colors and explicit
LOW/EMPTY/INVALID text. SubmarineHud owns compact reflow and exposes identity_container
for relocated secondary instruments; accessibility/tutorial/context consumers use the
new placements. Historical development-layout APIs remain for regression fixtures.

Scene-owned MissionTracker is a read-only projection of accepted MissionService,
SunlitShallows and narrative state. RadioNotifications owns a bounded transient queue
of existing IDs, previews, unread badge and a scrollable reader, without pausing or
mutating vessel motion. ExpeditionRevision remains the authority for eligibility,
mission acceptance, persistent acknowledgement and checkpoint writes. The buoy uses
its existing research/log state, with no additional acknowledgement ledger. Expedition
schema 6 is unchanged. Settings schema 1 compatibly adds a remappable open_radio action,
choosing unused descriptors without altering existing bindings. No dependencies or
new gameplay systems. A scene-supplied optional sonar input guard suppresses only
the physics step of a consumed radio control press; ordinary quick pings and movement
remain independent. [Contracts and evidence](docs/testing/bta-048/README.md).

## Halcyon Descent presentation — BTA-049

Scene-owned HalcyonDescent composes shared illustrated PNG assets with a local 30 Hz
redraw budget, bounded deterministic motes and slow draw-only parallax. No gameplay
RNG, physics/input handling, saved timer or new setting. Reduced Motion freezes the
composition; particle/effects preferences remove drift density/illumination variation.
The covered WorldRoot is render-hidden while the title page is visible and its prior
visibility is restored on exit. Simulation and checkpoints remain owned by existing
services. Title Godot controls retain the original focus loop and callbacks inside
a responsive, focus-following left column. The playable sprite and title share one
1619x971 painted master, fitted to the unchanged 80x48 world footprint. HalcyonDeparture shares the
station modules at the existing dock; it adds no bodies, shapes, targets or triggers.
No schema, stable ID, terrain polygon, camera or navigation rule changes.

### BTA-049 review revision: semantic typography and dialog bounds

UiTypography owns role-based pixel sizes and Compact/Standard/Large multipliers.
Controls declare `typography_role`; body/dialog buttons default to 16 px, menu buttons
17, heading 20, section 18, secondary 14 and instruments 16 (depth measurement 18).
The shared Theme bootstraps 16 px. UiAccessibility reapplies semantic sizes directly,
never multiplying a previous override, and retains the existing contrast/focus policy.
Custom-drawn map/talent labels read the same scale. Large remains 125%; Compact is
90% with a 14 px floor. The title adapts to viewport width separately.

UiDialogLayout constrains presentation rectangles with at least 24 px side/32 px
vertical viewport clearance. Existing scroll/focus/callback owners retain their APIs,
pause and recovery rules. Dynamic dialogs use a dimmed world backdrop; logs/settings
retain their node references and accessible scroll controls. Resize ownership stays
in the scene-owned accessibility coordinator, preventing callbacks to freed panels.

Painted hardware, basalt and optics are imported assets with recorded provenance.
Texture-local surface displacement uses explicit cosmetic phase, no engine TIME or
screen reads, and freezes in comfort modes. Shared vessel footprint, terrain polygons,
carving, camera, navigation, domain signals, checkpoints and schema are unchanged.
[Native review matrix and reproducible commands](docs/testing/bta-049/revision/README.md).
