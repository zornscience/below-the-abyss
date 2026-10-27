# BTA-035: canonical expedition checkpoints

> Historical BTA-035 format: the playtest-feedback revision now writes schema 3
> and migrates versions 1/2. See [terrain and expanded-progress compatibility](../feedback/README.md#saves-and-restart-policy).

## Ownership and migration

`SaveCoordinator` is scene-owned and composes the existing stores/components; no
autoload, dependency, region or gameplay detector is added. In the normal shelf
scene it owns one canonical `user://saves/expedition.json`. The checkpoint includes
vessel state, current region, route telemetry and permanent progress together.
Settings remain independent in `user://settings.json`.

Existing discovery, research, upgrade and mission stores retain their validation,
standalone APIs and original files. Each has an optional `checkpoint_writer`
Callable. Once the coordinator has validated/imported the profile, existing domain
save calls use this port, passing the proposed ID set/mission records. This is
important for upgrades and claims, whose persistence must succeed before exposing
an installation/reward. No second set of ongoing per-domain files is written.
The old files and backups remain available for investigation rather than being
removed, rewritten or renamed just because the player upgraded the application.

On first use, the existing stores validate/load their established formats. Valid
progress is imported; missing files mean empty/new progress. Any unreadable legacy
file, or missing primary with an existing backup, blocks migration and starting
play. The pause screen's Recover expedition backup can validate all pending legacy
backups first, invoke the existing explicit recovery APIs, preserve rejected data,
and retry migration. Invalid/unavailable backups leave play blocked with a message.
Do not remove the preserved files merely to make migration succeed.

On subsequent launches a validated canonical checkpoint is authoritative. Any
successfully read legacy progress is merged monotonically (set union for IDs,
maximum state/union of flags for missions), so it cannot downgrade the checkpoint.
Unreadable legacy originals are preserved; the valid canonical snapshot provides
the current profile. Domain backup buttons now direct players to expedition backup
recovery, preventing an archived ledger from becoming a conflicting writer. Map/
research retry saves use the canonical port. Standalone component fixtures retain
the old store behavior without a coordinator.

The default game enables saves automatically. Custom composition/test scenes that
use an isolated settings path must explicitly inject `ShelfPrototype.expedition_path`
to enable the coordinator. Otherwise the pause menu honestly reports that expedition
saving is not configured for that development fixture. This avoids writing a user's
normal checkpoint from older standalone test fixtures. New save/load integrations
and graphical evidence always inject their own checkpoint path.

## Versioned format and validation

Current schema version is **2**, with exactly seven top-level fields:

```json
{
  "format": "bta-expedition",
  "schema_version": 2,
  "region_id": "continental_shelf",
  "legacy_imported": true,
  "player": {
    "position": [760, 480], "rotation": 0,
    "hull": 80, "battery": 60, "oxygen": 70, "sonar_cooldown": 2
  },
  "progress": {
    "discoveries": ["shelf-navigation-marker"],
    "research": ["shelf-calibration-plate"],
    "upgrades": ["sonar-range-1200"],
    "missions": {
      "shelf-expedition": {"state": "available", "objectives": []},
      "shelf-calibration-study": {"state": "claimed", "objectives": ["scan-calibration-plate"]}
    }
  },
  "route": {"stage": 1, "elapsed_seconds": 12.5}
}
```

`ExpeditionSchema` is pure validation/migration; `ExpeditionStore` handles bounded
JSON I/O; `SaveCoordinator` owns gameplay snapshot/application and safe-state gates.
Files are limited to 65536 bytes. Exact keys, types, known region/IDs, unique IDs,
mission state/flag consistency and finite numeric bounds are required. Current
resource capacities come from the authored prototype resource configuration, with
cooldown bounded to the existing four seconds and rotation to [-π,π]. No resource
paths, scripts, scene trees, runtime instance IDs or arbitrary executable objects
are deserialized. Velocity is deliberately absent and extra physics fields fail
validation. Route time is bounded to 100 hours and stage to the existing four states.

The committed `tests/fixtures/expedition_v1.json` describes the supported earlier
unified schema: the same structure with a four-field player object lacking rotation
and cooldown. Version 1 migrates in memory to rotation zero/cooldown zero, retaining
all progress/resources; a later successful save writes version 2. Loading does not
silently rewrite the original. Other older/newer versions are incompatible,
preserved and blocked. Existing per-domain version-1 files use the explicit legacy
import path rather than being mistaken for unified checkpoints.

## Commit and recovery guarantees

Writes validate before touching disk, revalidate existing primary/backup and reject
stale candidates that would remove known permanent progress. A same-directory `.tmp`
is flushed/closed and atomically renamed. As in BTA-034's mission checkpoint, `.bak`
contains the **latest proposed checkpoint**, written before the primary, so a newly
claimed acknowledgement is recoverable if the primary later becomes unreadable.
The coordinator updates its in-memory checkpoint and reports success only after
both writes succeed. A primary write failure can leave a newer valid backup; it
requires explicit recovery, never a false Saved message.

Missing primary plus existing backup blocks new writes until recovery. Corruption,
unsupported schemas and invalid values preserve original bytes. Explicit recovery
validates the backup, preserves primary as `.rejected`, refuses to overwrite an
existing rejected file, and monotonically merges known permanent progress. The
backup is not an undo mechanism for claims/upgrades. Coordinator busy guards cover
writes, restores, recovery and status callbacks; rejected reentrant operations do
not produce another commit. One writer per profile/process is supported; no
cross-process lock or general transaction/message-queue framework is claimed.

Atomic replacement and `flush()` do not promise durability through every filesystem
or power-loss failure. Destroying or manually rolling back all copies cannot be
recovered. A failure during recovery may already have preserved the old primary as
`.rejected`; backup remains for retry. Inspect/preserve files before retrying conflicts.

## Continue, position safety and transient state

Startup validates a checkpoint before offering **Continue saved expedition**. It
restores permanent records quietly to avoid duplicate installations, scan records,
mission completion/claim events and rewards. Vessel state is applied only when
Continue is chosen. Every section is schema-validated before any vessel restoration.

The saved center/rotation is checked against authored region bounds and the actual
submarine collision shape in the 2D physics world, excluding its own RID. If it is
outside the region or intersects solid geometry, Continue uses the authored clear
Shelf Base spawn, sets rotation/velocity to zero and resets ephemeral route telemetry.
Supplies and permanent progress remain intact. If even the base is obstructed,
Continue aborts before changing vessel state. Nonfinite/malformed coordinates reject
the whole document rather than entering a physics query. Files are not automatically
rewritten merely because a fallback was necessary.

Safe positions retain rotation and route stage/time. Velocity is always zero, not
restored from a potentially stale physics frame. Active pulses/temporary echoes,
passive contacts, partial scans, ambient schedules, creature investigation/pursuit,
pressure grace and collision-contact state reset safely. Upgrades reconstruct
absolute capabilities via the existing API, and saved sonar cooldown is restored;
loading cannot bypass ping energy costs or produce a new pulse. The current bus
history remains unchanged during same-process Continue; a fresh process has its own
new bus, with no replay of old events. Producer reset epochs prevent within-bus ID
reuse. Ambient events after resuming are new simulation emissions, not replayed saves.

Hull/battery/oxygen restoration uses validated snapshot APIs that notify changed
readings without synthetic damage/depletion events. Pool/node identities seen by
HUD bindings stay intact. Mission restoration never emits completion/reward events.
Accepted mission progress and claims remain independent of temporary route resets.

## Save experience and checkpoints

Manual Save expedition is available from the pause menu after beginning/continuing.
It requires paused simulation, a clear vessel position, no current depth danger,
and no predator ALERT/PURSUE state. Unsafe attempts explain why no save occurred.
Docking and successful repair/refill are automatic vessel checkpoints; mission
accept/claim and upgrade installation while docked commit their proposed progress
and current vessel state through the existing domain APIs. Merely passing through
base still restores nothing.

Outside the station, discovery/research/mission writes commit permanent records
while retaining the last safe vessel checkpoint. The status explicitly distinguishes
progress committed/checkpoint retained from an entire expedition saved. This avoids
autosaving the vessel in pursuit or pressure danger. Save status appears in pause
and station interfaces, including readable failure messages; no success is reported
on a failed write. There is no implicit quit autosave: save or dock before exiting.

**New Expedition** has an explicit confirmation, initially focused on Cancel. It
replaces position/supplies/temporary route with a fresh departure while retaining
permanent discoveries, research, mission flags/claims and both upgrades. It can be
chosen while paused, including after a dangerous encounter, and validates base
clearance before committing. Cancel leaves checkpoint/state unchanged. Corrupted
profiles must recover before New Expedition can replace anything. **Restart Test
Route** remains a separate development reset, not an erase-progress operation.

## Deliberate limits

One authored region and one checkpoint, no slot browser, campaign, economy, new
upgrades or new gameplay. No autosave of unsafe moving vessel state. No seamless
creature/physics continuation, general serialization of Nodes, platform cloud save,
Windows/macOS runtime certification or physical-controller certification. Existing
input/settings and runtime gameplay systems otherwise remain in place.
