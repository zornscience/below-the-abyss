# Below the Abyss

A 2D underwater exploration and adventure game built with Godot 4.

Current build: **BTA-051 — Expanded Sunlit Shallows and research XP**,
on **The Sunlit Shallows**, the canonical first expedition.
Pilot **Lantern-2** from **Halcyon Station** to study a geometric light bloom and
recover missing acoustician Mara Voss's emergency buoy. Bring the recording home
for a first-expedition debrief. The Twilight Shelf is a future chapter, not playable.

- **Start:** Begin/Continue The Sunlit Shallows, Options and Quit on the illustrated
  title. **New Game** confirms and archives the current campaign before starting fresh;
  control/audio/accessibility preferences stay. Accept a short briefing; asking Okafor about the anomalies is optional.
- **Pilot:** WASD/arrows or left stick; F/X sonar, E/A interact/scan/dock,
  M/Back map/research, P/Start pause. Bindings are remappable. Optional Wick tutorial
  cards can be disabled under Pause → Help & tutorials.
- **Investigate:** follow Halcyon's pylons east, study the bloom, then consult the map, clear the fractured passage and search the reported area. Sonar identifies subjects; deliberate scans recover records. Read
  the recovered message in the expedition log. Return through the cleared shallow route.
- **Choose:** scan the bloom unharmed or bottle a specimen for Crane. Its visual
  outcome and Wick/Okafor/Crane dialogue persist without a numeric morality score.
  Neither branch blocks completion or can be repeated for rewards.
- **Instruments:** compact HULL / POWER / OXYGEN percentages at upper left; depth
  centered above the environment, accepted objectives at upper right. Low/empty
  resources and danger warnings use text/symbols as well as color.
- **Radio:** R / left shoulder opens queued messages. Tab/right shoulder cycles
  actions, Enter/A selects and Escape/B closes. Previews and transcripts leave
  movement running; explicit briefing, bloom choices and station menus still pause.
- **Dock:** slow down and deliberately use E/A. Station services repair/refill/rearm;
  passing through base does not. Submit **First expedition debrief** after returning
  with evidence. Research technology and free reassignment remain accessible.
- **Optional tools:** ten facing-fired torpedoes (Space/right trigger/right-stick
  click), accelerating wakes and comfort-aware blasts remain available. Combat is
  not required. Sonar pings cost substantially more battery than normal cruising.

[BTA-050 environment: asset inventory, native comparisons, performance and manual review](docs/testing/bta-050/README.md).

[BTA-049 review revision: typography, bounded dialogs, painted art and native before/after evidence](docs/testing/bta-049/revision/README.md).
[Original title implementation record](docs/testing/bta-049/README.md).

[Compact layout, radio controls, comparisons and verification](docs/testing/bta-048/README.md).

[Complete chapter route, APIs, compatibility, verification and native screenshots](docs/testing/bta-047/README.md).
The shallow grounded wreck is a **separate prototype vessel, never Lantern-1**.
Existing saves retain their records, talents and claims. Use the title's **Prototype
expedition / legacy checkpoint** option (when legacy progress exists), or
`godot --path . -- --prototype-expedition`, for the previous expanded course.
Its [feedback-round-two controls, four-point progression and wreck route](docs/feedback-two/README.md)
remain documented. The [Resonance foundation](docs/testing/bta-046/README.md) and
[prior feedback](docs/feedback/README.md) are historical implementation records.

**The external five-player study has not run.** The [BTA-044 toolkit](docs/playtesting/README.md)
provides opt-in local reports, participant/facilitator materials and anonymous
analysis. Automated routes and the user's feedback do not constitute five human
sessions. The 20–40 minute unfamiliar-player chapter target still needs measurement.

Pause → **Accessibility** provides Compact/Standard/Large text, softer effects,
reduced motion, disabled motes and high contrast. All gameplay actions can be
remapped for keyboard/controller; menu recovery bindings remain available.
See [accessibility](docs/accessibility.md), [art direction](docs/art_direction.md),
[audio direction](docs/audio_direction.md) and historical [narrative slice](docs/narrative_slice.md).

Pause → **Audio settings** retains independent volumes/mute and explicit Save.
The existing soundscape, station services, upgrades, map/research and optional
creatures remain available. Art/audio/narrative are prototype studies for review.

The supplied [Story Bible and prototype alignment](docs/story/README.md) define
the geometric plankton encounter and character roles. The normal game presents the first canonical chapter; the other seven zones are
not playable.

## Requirements

- **Godot 4.6.3 stable**, standard edition (GDScript), pinned in `.godot-version`.
  The verified Linux binary reports `4.6.3.stable.official.7d41c59c4`.
- Git, Python 3.9+, and curl for the checksum-pinned GUT test dependency.
  No .NET SDK or export templates are required to run the source project.
  The [standalone Linux package](docs/playtesting/build.md) requires matching official export templates.

Read [AGENTS.md](AGENTS.md), [GDD.md](GDD.md), [TDD.md](TDD.md), and
[CODEX_PLAN.md](CODEX_PLAN.md) before implementation.

## Import and launch

From the repository root, with the pinned Godot executable on PATH as `godot`:

```sh
godot --version
godot --headless --path . --editor --import
godot --path . --editor
```

Run the main scene directly:

```sh
godot --path .
```

For headless startup validation (exits after 60 engine iterations):

```sh
godot --headless --path . --quit-after 60
```

Import and smoke commands must exit with status 0 and no Godot errors.
The illustrated Sunlit Shallows title should open before its interactive briefing.
This smoke check validates startup, not gameplay or a unit test suite.

In the managed cloud environment, initialize writable Godot cache paths before
running these commands:

```sh
export XDG_CACHE_HOME=/workspace/.cache
export XDG_DATA_HOME=/workspace/.local/share
export XDG_CONFIG_HOME=/workspace/.config
mkdir -p "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"
cd /workspace/below-the-abyss
```

## Continental-shelf exploration graybox (BTA-014)

This historical course is available with
`godot --path . scenes/main/shelf_prototype_fixture.tscn`; normal launch uses the
canonical first expedition documented above. Select Begin/Resume with arrows/Tab/Enter or D-pad/stick/A.
Pilot east through **02 Cave** to **03 Twin Spires**, then return west through the
lower passage and ascend to **01 Shelf Base**. The required course stays above
260 m; an optional overlook and signed pressure trench branch off it. All filled
rock/platform geometry is solid; thin brackets/lines and arrows are nonsolid
navigation marks. The local surface reference is Y=0 at 0.25 m per unit.

Escape/P/Start opens the test-route menu, with Resume, Input settings and Restart.
Restart resets the complete vessel/test session at base while preserving saved
input settings. Entering base itself provides no repair/refill service. The
on-screen loop check is ephemeral test telemetry, with no rewards or persistence.
An automated input-driven full flight takes about **42 seconds**, ending with
100 hull and battery/oxygen reserves; first-time manual playtesting remains needed.

See [layout, acceptance evidence, screenshots and manual route](docs/testing/continental_shelf.md)
and [design decisions](docs/decisions/bta-014-continental-shelf.md).

The original movement/depth/HUD course remains available as a development fixture:

```sh
godot --path . res://scenes/main/movement_prototype.tscn
# That original fixture with optional resource-test controls:
godot --path . res://scenes/main/movement_prototype.tscn -- --debug-controls
```

## Save and Continue (BTA-035)

Launch with `godot --path .`. Choose **Continue saved expedition** when a validated
checkpoint exists. After beginning/continuing, pause with Escape/Start and choose
**Save expedition** from clear terrain outside pressure danger and predator pursuit.
Docking, successful station operations and safe emergency-buoy recovery also save
checkpoints. The buoy recording and vessel pose commit before its message opens. Read the explicit
success/failure message before exiting; there is no implicit quit autosave.

**New Expedition…** asks for confirmation and resets vessel/temporary route while
keeping all permanent progress. Cancel leaves the checkpoint alone. **Restart Test
Route** remains a separate development action. Keyboard and controller navigation
work in pause/confirmation/station menus.

The normal game now uses `user://saves/expedition.json` (version 7; migrates versions 1–6) with a recoverable
checkpoint backup. Existing narrow save files are validated/imported and preserved;
their store APIs then delegate writes to the coordinator. Standalone component
fixtures still use their original stores. Custom isolated settings scenes inject
`expedition_path` to enable coordinated saves. Corrupt/incompatible data blocks
starting/writing and offers explicit recovery rather than overwriting progress.

Continue resets temporary echoes, contacts, partial scans and creature pursuit;
velocity starts at zero and sonar cooldown is restored. Obstructed/out-of-region
positions recover to clear base without restoring supplies, with a readable notice.
See [architecture/schema/migration/recovery](docs/decisions/bta-035-general-save-system.md)
and [complete walkthrough, exact tests and two-process native evidence](docs/testing/expedition_save.md).
The narrow-store sections below describe their standalone formats; the normal
shelf game now routes those persistent records through this canonical checkpoint.

## Historical prototype mission board (BTA-034)

Dock with **E / controller A**, choose **Mission board / notices**, then **Missions**.
Intentionally accept the main Shelf expedition and optional Calibration study. Use
arrows/Tab/D-pad and Enter/A; Escape/B/Start backs out one page at a time. Details
↑/↓ buttons scroll mission text without a mouse. Simulation stays paused while docked.

Scan the nearby calibration plate for the optional objective. Identify Twin Spires
with active sonar and complete the existing return route for the main expedition.
The in-expedition HUD shows state and objective counts. Return to the board to
explicitly claim each completed acknowledgement; there are no economic rewards.
Earlier permanent discoveries/scans count at acceptance, and current COMPLETE route
telemetry counts too. Accepted progress and claimed acknowledgements persist through
restart/reload in separate `user://saves/missions.json` state.

Corrupt/incompatible files block writes and remain preserved. The board provides
Sync / retry progress and explicit checkpoint recovery, retaining known claims.
See the [API/evidence/save policy](docs/decisions/bta-034-mission-framework.md) and
[complete playable walkthrough, test commands and native screenshots](docs/testing/mission_framework.md).

## Persistent upgrades (BTA-033)

Dock at Shelf Base with **E / controller A**, then choose **Prototype upgrades**.
Select either FREE installation with arrows/D-pad and Enter/A. The page shows
baseline/upgraded values, installed state and local-save status. Escape/B/Start
returns to services, then piloting. No research, materials or currency are required.

The acoustic array increases new ping radius from 900 to 1200 world units while
keeping cost 4 and cooldown 4 seconds. The pressure hull increases the HUD's safe
rating to 400 m (CAUTION at 360 m); existing pressure damage still applies beyond
that rating. Installation never repairs or refills resources. IDs persist separately
in `user://saves/upgrades.json`; route restart and station services retain them.
Unreadable files block installation and remain preserved, with explicit backup
recovery in the upgrades page. Recovery replaces IDs with the last valid backup.

See [API/balancing/save contract](docs/decisions/bta-033-persistent-upgrades.md) and
[commands, manual playtest and native before/after screenshots](docs/testing/submarine_upgrades.md).

## Station services (BTA-032)

At Shelf Base, slow down inside the docking ring and press **E / controller A**
(the existing remappable Interact action). Normal piloting prioritizes the station
inside its radius; outside, Interact still performs scientific scanning. Leave
development mode off; that mode retains its existing resource debug controls.

Services pause simulation and show resource-before/resource-after previews. Repair,
charge, refill or Service all explicitly applies FREE prototype service, capped by
configurable per-activation limits and existing maxima. Full/disabled services show
why they are unavailable. Merely returning, docking or reading notices changes no
resources. Arrows/Tab/D-pad navigate, Enter/A selects, Escape/B/Start goes back or
returns to piloting. Notices remain informational; the separate Missions page provides explicit acceptance and acknowledgement claims.

Services retain the expedition route, sonar history and permanent discoveries/research.
**Restart Test Route** remains a separate development reset. See the
[API and balancing decisions](docs/decisions/bta-032-station-services.md) and
[verification commands, native screenshots and manual playtest](docs/testing/station_services.md).

## Optional predator encounter (BTA-031)

The signed upper pocket before Twin Spires is optional. Stay on the main passage
at roughly **120m** to bypass it, including while using sonar. Inside the pocket,
a qualifying **F/controller X** ping starts a **2.5-second warning** before pursuit.
The HUD labels the predator warning and instructs **RETREAT ↓ PAST 115m**.

Pursuit is slower than the submarine, bounded to the habitat, limited to six seconds
and a 180-unit ping-origin leash. Leaving the area or a blocked path disengages it.
Contact costs **5 hull**, at most once per **3 seconds**, only during pursuit and
with no terrain in between. Passive listening is silent. Neither creature can
push or block the vessel. Pause freezes the encounter; Restart preserves permanent
research/discoveries and acoustic history.

See [actual keyboard/controller escape evidence, screenshots and manual protocol](docs/testing/predator_encounter.md)
and [reuse, state, safety and damage contracts](docs/decisions/bta-031-predator-encounter.md).
Independent human usability and physical-controller/native-platform tests remain
pending; the documented graphical playthrough used real Godot with injected input.

## Harmless acoustic creature (BTA-030)

Enter the signed optional overlook near **(1400,400)**, above the main route, and
press **F / controller X** (existing remappable sonar_ping). The placeholder shows
PATROL → INVESTIGATE → RETURN → PATROL, reacts to the sampled sound origin and
cannot chase outside its bounded habitat. Pings still have their normal cost and
cooldown. Repeated sounds cannot extend one investigation indefinitely. Passive
listening itself emits nothing and never attracts it.

The creature collides only with terrain; the vessel can pass through it. There
are no attacks or contact damage. All existing pauses freeze it; Restart restores
its test state without clearing acoustic history or permanent research/discoveries.
Movement/perception/patrol timing tune through `resources/creatures/shelf_observer.tres`.

See [commands, actual screenshots and manual playtesting](docs/testing/acoustic_creature.md)
and [FSM, acoustic arbitration, navigation and lifecycle contracts](docs/decisions/bta-030-acoustic-creature.md).

## Scientific scanning and research (BTA-024)

Use normal mode (`godot --path .`). Discover a subject with active sonar, approach
within its configured radius, then press **E / controller A** (remappable Interact)
once to start and again to cancel. The HUD reports progress, range/interruption,
pause and completion. Leaving range resets partial progress; pausing freezes it.
Scanning preserves movement and sonar controls and has no extra energy cost.

The calibration plate near (760,480) takes 3 seconds; the geological formation
near the overlook at (1710,440) takes 4 seconds. Both use a 240-unit radius and
require the corresponding permanent sonar POI. **M / Back-Select → Research log**
shows only completed records, with keyboard/controller navigation. Completed scans
are idempotent and remain across Restart/relaunch; partial progress is not saved.

Research uses its own validated version-1 `user://saves/research.json`, with atomic
writes, previous-valid backup and visible retry/recovery. It does not change the
discovery schema or implement general game saves. Development mode retains E/A
for existing resource-test tools; scan using normal mode.

See [commands, actual screenshots and manual playtesting](docs/testing/scientific_scanning.md)
and [API, timing, persistence, restart decisions and limitations](docs/decisions/bta-024-scientific-scanning.md).

## Discoveries and exploration map (BTA-023)

Press **M / controller Back-Select** (the existing remappable `open_map` action).
Close with the same action or Escape/B/Start; navigate using arrows/Tab/D-pad/stick
and select with Enter/A. The map pauses simulation and returns to the previous
piloting/briefing state. Only landmarks reached by an eligible active-sonar
wavefront appear. Passive contacts, proximity and route completion never discover.
Permanent landmarks remain after temporary echoes fade and after Restart.

Discoveries auto-save to `user://saves/discoveries.json`, separate from vessel,
settings and route state. Invalid/incompatible files are preserved and block
writes; visible map controls offer retry and explicit backup recovery. Restart
never clears discoveries. No hidden terrain, secret markers/counts, mission or
reward is shown on the map. Research log is a separate completed-record page.

See [commands, actual screenshots and manual playtesting](docs/testing/discovery_map.md)
and [registry API, versioned save format, restart/recovery decisions and limitations](docs/decisions/bta-023-discovery-map.md).

## Passive sonar (BTA-022)

Listening is automatic during play, with no extra control or battery cost. The
HUD shows up to three recent MECHANICAL, GEOLOGICAL or MARINE LIFE contacts,
relative arrows/signed bearings, approximate strength and an eight-second expiry.
Station machinery, rock friction and marine ambience publish bounded, stable-ID
ambient events. Pause freezes their simulation clocks; Restart clears contacts
and begins a new producer epoch while retaining acoustic duplicate history.
Passive contacts never reveal world objects or record discoveries.

```sh
godot --headless --path . res://scenes/main/passive_sonar_example.tscn
```

See [commands, screenshots and manual acceptance](docs/testing/passive_sonar.md)
and [API, tuning, memory/time contracts and limitations](docs/decisions/bta-022-passive-sonar.md).

## Active sonar (BTA-021)

Run `godot --path .`, Begin/Resume and press **F / controller X** (default
`sonar_ping` bindings). An accepted ping costs **4 battery**, has a **4-second
cooldown**, and expands at **600 world units/second** to **900 units**. Temporary
placeholder targets reveal when the front reaches their sampled distance and
remain visible for six seconds from arrival. Out-of-range/filtered targets stay
hidden. The ring stays at its emitted world position while the vessel moves.

The HUD reports READY, COOLING, LOW BATTERY or BLOCKED/OFFLINE, numeric cost/time
and the last ping's echo count. Existing settings remap the action. Route,
settings and developer-control pauses freeze all sonar clocks. Route restart
cancels pulses/reveals and issues a fresh producer epoch without clearing the
acoustic ledger. The original movement fixture has no injected sonar bus and
honestly displays OFFLINE.

Tuning is in `resources/balance/prototype_sonar.tres`; reusable scripts/scenes
compose the existing AcousticEmitter/AcousticReceiver and battery API. An atomic
acceptance gate prevents rejected/invalid/duplicate pings from charging energy.
There is no second dispatcher, occlusion, moving-target interception, terrain
reveal. The optional harmless creature can observe eligible acoustic events.
Scientific scanning is a separate intentional action. The BTA-023 registry records selected wavefront
arrivals independently of temporary echoes. The exploration loop still requires no sonar.

See [contracts, screenshots and manual verification](docs/testing/active_sonar.md)
and [design decisions](docs/decisions/bta-021-active-sonar.md). Reproduce screenshots:

```sh
godot --path . --script res://tests/fixtures/capture_active_sonar.gd
```

## Acoustic event contract (BTA-020)

After import, run the independent text-only example:

```sh
godot --headless --path . res://scenes/main/acoustic_contract_example.tscn
```

It exits 0 after delivering one event exactly once to the near and boundary
receivers, rejecting a duplicate ID, and excluding far/type-filtered receivers.
The example is also asserted by the normal GUT suite.

`AcousticEvent.create(...)` validates explicit stable IDs, type/classification,
world position, signal strength, range and caller-owned simulation time. Inject a
scene-owned `AcousticBus` into generic `AcousticEmitter`/`AcousticReceiver` nodes;
no autoload or default-gameplay scene changes are required. Configurable Resources
provide emission values, receiver filters/thresholds/range, optional linear
attenuation and a bounded event ledger. Delivery follows explicit lexical receiver
ID order, with snapshot isolation, lifecycle cleanup and no duplicate replay for
the bus lifetime. Ledger capacity fails explicitly instead of evicting IDs.

See [API contracts, example and verification](docs/testing/acoustic_contract.md)
and [design decisions](docs/decisions/bta-020-acoustic-contract.md) for exact
binding/error/identity/attenuation semantics, focused tests, limits and manual checks.
BTA-020 remains the generic foundation; BTA-021 adds the separately composed
active sonar above. Its ledger semantics are preserved with an optional atomic
producer-acceptance gate before insertion/delivery.

## Movement prototype (BTA-010)

For the original course, run `godot --path . res://scenes/main/movement_prototype.tscn`.
Move with WASD/arrows or left stick/D-pad
(default bindings). Release to coast; reverse thrust to brake. Escape/P/Start
opens input settings and stops the motor. Save changes and select Return to
movement; unsaved edits are discarded on return.

Motion is configured in `resources/balance/prototype_motion.tres`: acceleration
600 px/s², maximum speed 240 px/s, damping 3 s⁻¹. The reusable CharacterBody2D uses
fixed 60-Hz physics, swept wall sliding, interpolation and a smoothed Camera2D.
All cave/submarine visuals are explicitly temporary geometry.

See [movement verification](docs/testing/submarine_movement.md) for the model,
controls, screenshot, test results and manual keyboard/controller/frame-cap course.

## Submarine resources (BTA-011)

Hull, battery and oxygen start at 100 units, configured in
`resources/balance/prototype_resources.tres`. During active simulation, idle
battery drains at 0.005 units/second, full thrust adds 0.025 units/second, and oxygen
drains at 0.03 units/second (playtest-feedback balance). Hull changes through its damage/repair APIs; BTA-012 now supplies pressure and
severe-impact damage sources. Movement remains available at zero hull; game-over
and respawn behavior remain outside scope.

Launch `godot --path . -- --debug-controls`, then press Interact
(E/controller A by default) to open the separate development test panel.
Use keyboard arrows/Tab/Enter or controller D-pad/stick/A to consume/repair/refill.
Focusing test controls stops movement and drains; Return to piloting resumes them.
Input settings also stop drains. Indicators show numeric values, EMPTY/DEPLETED,
and one notification per emptying; a positive refill rearms depletion.

See [resource APIs and manual verification](docs/testing/submarine_resources.md)
for configuration, signal/transfer contracts, screenshots, test results, and the
keyboard/controller/refill/frame-cap playtest. This is temporary instrumentation,
not the production HUD or station/game-over system.

## Depth and hull damage (BTA-012)

The original movement fixture's authored surface is local Y=0, with 0.25 m per authored unit. Spawn is
130 m deep. CAUTION starts at 260 m; depth strictly beyond the 300 m safe rating
starts a two-second grace period, then four hull units/second of pressure damage.
In the original movement fixture, descend between X=200–450 into the marked
deeper shaft to demonstrate pressure. The default shelf instead has an optional
trench at X=2880–3280.

Severe impacts use inward normal speed: above 150 px/s, damage is 0.1 per excess
px/s, capped at 20. A full-speed perpendicular hit typically costs 9 hull.
Contact latching and cooldown suppress repeated wall push/jitter damage.
Existing settings and resource checks freeze all simulation clocks while active.

See [depth/damage verification](docs/testing/depth_damage.md) and
[design decisions](docs/decisions/bta-012-depth-damage.md) for mapping, boundaries,
maximum-depth API, screenshots, tests and keyboard/controller playtesting.
The maximum-depth API is ready for a future caller; no upgrade system is added.

## Prototype HUD (BTA-013)

Launch `godot --path .` and Begin/Resume for the production HUD in the shelf.
The original course remains in `scenes/main/movement_prototype.tscn`. Rounded dark instrument cards,
authored vector marks, numeric values/capacities and normalized bars show vessel
resources. Depth warnings spell out **SAFE**, **CAUTION** and **DANGER**, with
ASCEND instructions, authoritative grace time and persistent DEPLETED labels.
Impact and pressure feedback have separate 2.5-second display lifetimes.
No flashing, camera effects, UI focus or gameplay writes are introduced.

The reference window is 1280×800; native Control layouts preserve 16+ pixel text
at smaller sizes, with a minimum supported window of 800×600. Larger and tall
windows retain edge anchoring and a clear gameplay center. The HUD scene is
`scenes/ui/submarine_hud.tscn`; bind an initialized resource, hull and damage
component using `SubmarineHud.bind_sources(...)`. It snapshots initial values,
then follows their signals. Only the grace detail is sampled because that API
has no change signal. Unbound/destroyed sources show INSTRUMENTS DISCONNECTED.

Development instrumentation is opt-in and lives in a separate CanvasLayer:

```sh
godot --path . -- --debug-controls
```

Press E/controller A (or your remapped Interact action) to open resource tests.
Arrows/Tab/Enter or D-pad/stick/A navigate the wrapping button panel. Simulation
stops while testing; Return to piloting resumes it. The regular HUD stays visible
and shows the real domain values. Debug depletion counts and resource mutations
are excluded from the reusable HUD. The editor also exposes `development_mode`
on GameRoot; it defaults to false.

See [HUD verification and screenshots](docs/testing/submarine_hud.md) and
[design decisions](docs/decisions/bta-013-hud.md) for test evidence, layout and
signal contracts, keyboard/controller steps, and screenshot reproduction.

## Input/settings test menu (BTA-004)

Run `godot --path . res://scenes/ui/input_test_menu.tscn` independently. Use arrows/Tab and Enter with a
keyboard; D-pad/left stick and A with a controller. Shoulder buttons cycle focus.
Escape/B cancels. The menu supports choosing an action, capturing a new binding,
adjusting the analog dead zone, saving/reloading/resetting settings, and quitting.
The movement readout and pause/sonar feedback demonstrate inputs only.

Settings save explicitly to `user://settings.json`; invalid loads preserve the
file and use defaults at startup. Menu recovery bindings stay fixed. Rebinding
replaces one device group and preserves the other; conflicting bindings are
rejected. Default dead zone is 0.25, configurable from 0.10 to 0.90.

See [input/settings verification](docs/testing/input_settings.md) for the default
mapping table, model/schema, screenshot, limitations, and complete keyboard-only
and controller-only manual steps. Desktop hardware/controller validation is
separate from synthetic automated input tests.

## Directory layout

Empty directories are retained with `.gitkeep` files and match TDD section 3:

```text
assets/{art,audio,fonts,shaders}/
scenes/{main,player,creatures,regions,stations,ui,props}/
scripts/{core,player,sonar,ai,missions,world,persistence,ui}/
resources/{equipment,creatures,missions,regions,balance}/
tests/{unit,integration,fixtures}/
tools/
docs/{design,decisions,testing}/
.github/workflows/
```

No exports or native Windows/macOS runtime validation are included.

## Continuous integration (BTA-002)

[`godot-validation.yml`](.github/workflows/godot-validation.yml) runs on every
pull request targeting `main` (including fork PRs) and on pushes to `main`.
It uses Ubuntu 24.04, read-only repository permissions, and no project secrets.
The checkout and artifact actions are pinned to full commit SHAs.

The workflow downloads the standard Linux x86_64 **Godot 4.6.3 stable** archive
from the official `godotengine/godot-builds` release and verifies its SHA-512
against the pinned entry from that release's
[`SHA512-SUMS.txt`](https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/SHA512-SUMS.txt).
The validator logs and requires the exact engine version
`4.6.3.stable.official.7d41c59c4` and checks `.godot-version` agrees.

Run the same validator locally from the repository root with Godot on PATH:

```sh
python3 tools/install_gut.py
python3 tools/validate_godot.py
python3 tools/run_tests.py
```

Python 3.9+ is required; it uses only the standard library. Set `GODOT_BIN` to
an executable path if needed. Initialize the writable XDG directories above in
the managed cloud environment.

The validator runs these engine commands in order:

```sh
godot --headless --path . --version
godot --headless --path . --editor --import
# Repeated for each authored .gd file, including scripts not used by a scene:
godot --headless --path . --check-only --script res://path/to/script.gd
godot --headless --path . --quit-after 60
```

The parser command repeats for authored scripts, including the sample tests.
Pinned `addons/gut/` is excluded from individual script parsing because its
internal static dependencies require GUT loader ordering (standalone parsing of
`version_numbers.gd` causes a circular initialization error). Headless import
still validates project resources and registers GUT classes, and the GUT runner
loads/exercises the framework. Other authored scripts and addons retain explicit
parser checks. The separate unit-test step follows the existing validation step.

Nonzero exits, timeouts, and logged Godot errors fail validation, including errors
Godot reports with exit status zero. Engine operations have time limits, and the
job has a ten-minute limit. The smoke check runs the configured main scene for
60 engine iterations; it does not validate gameplay, rendering, input, or audio.

Logs are written under ignored `build/ci-logs/` (override with `CI_LOG_DIR`).
Open the **Godot validation** Actions run and download its
`godot-validation-<run_id>-<run_attempt>` artifact for the installation log,
engine version, import output, parser inventory/per-script results, smoke output,
and summary. Artifacts are retained for 14 days and uploaded even after failure;
only phases reached before a failure have logs. Local runs refresh validation
logs to avoid reporting stale results. GUT installation output, unit-test logs,
JUnit XML, and a test-count summary are included in the same artifact. CI does
not export builds.

## Automated GDScript tests (BTA-003)

The test-only dependency is **GUT 9.6.1**, whose upstream compatibility table
specifies Godot 4.6.x. It is pinned to commit
`c80954f47bed74a0a2c471d472c0389f98e0a8f6`, with archive SHA-256
`343ba244e66e110273f4f6ca5343c16858eae19c0e35e9b45d404cf3385eba81`.
The [installer](tools/install_gut.py) downloads this exact commit over verified
HTTPS and checks the digest before copying only `addons/gut/`. This dependency
is ignored by Git and installed fresh in CI. An existing installation is verified
without overwriting its source files; a mismatch fails with the affected path.
Preserve any local addon edits before deliberately removing/reinstalling it.
Installation needs access to `codeload.github.com`; test execution is offline.

GUT is MIT-licensed by Tom "Butch" Wesley. The installer retains the complete
upstream `addons/gut/LICENSE.md` and copyright notices. See the
[pinned upstream README](https://github.com/bitwes/Gut/blob/c80954f47bed74a0a2c471d472c0389f98e0a8f6/README.md)
and [GUT 9.6.1 documentation](https://gut.readthedocs.io/en/v9.6.1/).
This test dependency's license does not select a license for this project.
No editor plugin activation is needed for headless tests.

From the repository root, after initializing XDG paths above when in the cloud:

```sh
python3 tools/install_gut.py
python3 tools/validate_godot.py
python3 tools/run_tests.py
```

These are the exact commands used by GitHub Actions after installing Godot.
`GODOT_BIN` and `CI_LOG_DIR` work for both runners. The unit-test command requires
an imported project, verifies the exact engine version, and runs the equivalent of:

```sh
godot --headless --path . --script res://addons/gut/gut_cmdln.gd \
  -gexit -gdisable_colors -gjunit_xml_file=res://build/ci-logs/unit-tests.xml
```

[`.gutconfig.json`](.gutconfig.json) recursively discovers `test_*.gd` in
`tests/unit/` and `tests/integration/`. Tests extend `GutTest`; test methods start
with `test_` and use typed GDScript. The original sample suite checks a JSON round trip and instantiation of the main
scene. BTA-004 adds settings, binding, and menu integration suites; BTA-010 adds
submarine velocity and real physics/camera integration suites; BTA-011 adds
resource transfer, signal, drain and prototype-panel coverage; BTA-012 adds
depth mapping, warning, pressure and collision-damage coverage; BTA-013 adds
HUD initial/signal updates, depletion, rebinding, feedback and responsive-layout
coverage. BTA-014 adds route telemetry, spawn/terrain/depth/connectivity, real input-driven
exploration/return, restart, settings, camera and menu coverage. All previous
suites remain enabled against their original course fixture. BTA-020 adds event,
registration, filtering, ordering, duplicate, attenuation and lifecycle suites
plus an independently launchable headless contract example. BTA-021 adds sonar
cost/acceptance/cooldown, wavefront timing, reveal/range/lifecycle, restart,
input/remapping, HUD and frame-rate coverage without removing prior tests.
BTA-023 adds stable discovery IDs, validated atomic discovery persistence/recovery,
wavefront/passive isolation, restart/reload, map visibility, remapping, controller
navigation, responsive layout and 30/60/120-step coverage.
The wrapper enforces a 420-second timeout and fails on nonzero runner exits,
logged Godot errors, missing/malformed JUnit output, zero tests, an entirely
skipped run, or failing/error test cases. It deletes previous results first.
All normal tests must pass; the summary reports the current suite count. The
original two harness samples remain part of the expanded suite.

Results are in `build/ci-logs/unit-tests.log`, `unit-tests.xml`, and
`unit-tests-summary.log`. Read the counts to distinguish passed, failed, and
skipped tests. These files and `gut-install.log` upload with the existing
14-day CI artifact, including on test failure.

To reproduce the intentional assertion failure independently:

```sh
python3 tools/run_tests.py --failure-demo
```

This command selects only `tests/fixtures/intentional_failure.gd`, writes
`failure-demo.log`, `failure-demo.xml`, and `failure-demo-summary.log`, and
**must exit 1** with one failed test. It does not treat the failure as success.
The fixture directory is excluded from normal discovery so the regular suite
stays green. To demonstrate a failing CI run, temporarily copy this fixture to
`tests/unit/test_intentional_failure.gd` on a review branch and push it to an open
PR. The existing unit-test step must fail and retain its report; remove the
copied file afterward and push again. Do not merge the failing demonstration.

The sample tests prove harness wiring; BTA-004 covers input/settings, and
BTA-010 covers movement and collisions; BTA-011 covers resource state and signals.
Other gameplay tests belong to the
issues that introduce those systems. Exports and platform certification remain outside scope.

## License

**License decision pending.** No project license has been selected or granted
by this scaffold. Godot has its own MIT license; this does not determine the
license of this repository.

## BTA-051 — expanded Sunlit Shallows survey

The canonical chapter now has an extended shallow course, one excavation-torpedo
rockfall and an optional deep vent branch. Open the map after Okafor's radio call:
solid charted terrain, hatched unknown sectors and a reported search circle are
distinct. The report is not the emergency buoy's exact position. Face the fractured
rock and use Space / right trigger to open a hull-sized passage; return to Halcyon
for rearming if necessary. No wildlife combat is required. The buoy becomes visible
only after an in-range active sonar wavefront reaches it.

First-time scientific species/study records give 20/30 research XP. Each 100 XP
adds one research point, capped at two additional points in this chapter. The
technology page and research log show this separately from legacy finite rewards
and hidden Resonance. Old scans retain their records without retroactive XP.
Repeat Interact can review nearby completed subjects without an award. The existing
atomic expedition checkpoint is now version 7, migrating versions 1–6; there is
no separate XP save. If the vessel is depleted, use Pause → Continue for the last
safe checkpoint, or Restart Test Route; permanent records and cleared terrain remain.

[Route, acceptance mapping, native evidence, commands and limitations](docs/testing/bta-051/README.md)
· [architecture and save migration](docs/decisions/bta-051-expanded-shallows.md)
· [performance and Fedora/NVIDIA profiling](docs/testing/bta-051/performance.md).
The 15–20 minute first-time chapter length is a human-playtest target, not a claim
established by automated steering or accelerated simulation.

PR #35 review adds passages/dead ends, rough rock, a three-shot cave-in, eel/turtle/
hammerhead, underwater impact/radio effects and New Game. [Review evidence, save
compatibility and manual route](docs/testing/bta-051/revision/README.md).

### Surface expedition polish (BTA-052)

Halcyon now launches at 20 m beneath a wave surface, above an open-water shelf with
optional excavation caves. Visible specimens scan directly; sonar locates the hidden
buoy with the original outward-only sweep. Ammo joins the resource HUD; radio types,
scrolls and dismisses automatically. Focus text panes to scroll with D-pad/arrow keys
instead of extra Text Up/Down buttons. Five icon-labelled research branches include
engine and torpedo tuning, with higher finite prices and compatible legacy purchases.
A quiet score uses the existing Music slider/mute.

[Design, save schema 8 migration, commands, input route and review limitations](docs/testing/bta-052/README.md).

The visual-review revision fixes submerged background placement, rounds collision-matched
rock contours, distinguishes warm ochre destructible rock, adds radio portraits and
a sheltered buoy search, and improves animal motion and hammerhead pursuit.
[Revision details, native captures, verification and manual route](docs/testing/bta-052/revision/README.md).

### Chapter handoff and deep exploration foundation (BTA-053)

After recovering the buoy recording and resolving the bloom decision, Interact at
the buoy or use the expedition log to finish the chapter without the long return
swim. Keep exploring and manual return remain available. The completed chapter
unlocks a Twilight Shelf exploration preview: full supplies at 350 m, branching
western/eastern loops and a central ascent tether for Halcyon refit/resume. Continue
preserves actual reserves. The planned wreck/sentinel story is not yet implemented.

[Controls, schema-9 migration, exact commands and evidence](docs/testing/bta-053/README.md).
