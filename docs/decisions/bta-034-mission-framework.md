# BTA-034: deterministic prototype missions

## Authored definitions and states

`MissionObjective`, `MissionDefinition` and `MissionCatalog` are validated authored
Resources. Definitions use stable IDs, bounded readable text, unique objective IDs
and unique acknowledgement IDs. Objectives reference existing discovery IDs,
research target IDs or the `continental-shelf-loop` route adapter. Setup rejects
references absent from the supplied registries. The shipped catalog has exactly:

| Mission | Objectives | Non-economic acknowledgement |
| --- | --- | --- |
| `shelf-expedition` (main) | Discover `shelf-twin-spires`; complete the existing route back to base | `shelf-expedition-ack` |
| `shelf-calibration-study` (optional) | Complete scan `shelf-calibration-plate` | `shelf-calibration-ack` |

Both begin AVAILABLE. Intentional acceptance moves to ACCEPTED, all objective flags
move to COMPLETED, and an explicit station claim moves to CLAIMED. Duplicate accept
or claim returns `ERR_ALREADY_EXISTS`; premature claims are unavailable. Objective
flags and states are monotonic. There are no locked prerequisites, time limits,
failure states, campaign chains, inventory, currency or rewards beyond the authored
acknowledgement. The registry can validate up to 16 definitions and eight objectives
per mission; no additional missions are authored.

## Evidence policy and adapters

Previously completed **permanent discoveries and scans count at acceptance**. This
avoids requiring a second scan of a target whose scanner is deliberately idempotent.
Merely listening passively, receiving an acoustic event or reading a notice does not
count. The existing active-wavefront → DiscoveryRegistry and ScientificScanner →
ResearchRegistry paths remain authoritative.

The existing route's current COMPLETE stage also counts at acceptance. Unaccepted
route history is not saved: restarting/reloading before accepting removes that
current telemetry evidence, so the route must be completed again. Once accepted,
credited route evidence is mission progress and survives restart/reload. Objectives
can be satisfied in either order; claim still requires a live docked station session.
A new physical expedition is not forced when valid earlier evidence already exists.

`MissionService` connects `DiscoveryRegistry.point_discovered`,
`ResearchRegistry.scan_completed` and `GrayboxRouteCheck.stage_changed`. It reads
registry state to verify evidence (a forged notification alone cannot credit it).
The route adapter consumes COMPLETE from the existing route checker: it has no
new zone detection or geometry. The framework advances on events rather than wall
clock or frame count, making identical evidence deterministic at 30/60/120 steps.
Only the existing route checker integrates simulation time.

## API, lifecycle and rewards

One scene-owned `MissionService` per vessel/profile is composed by ShelfPrototype.
`setup(catalog, discoveries, research, route, path)` validates and snapshots authored
data and loads mission records. `definitions()` and `snapshot()` return copies.
`accept(id)`, `claim(id)`, `reconcile()` and `recover_backup()` return Errors.
`missions_changed` drives the station board and in-expedition objective summary.
`mission_completed(id)` and `acknowledgement_claimed(mission_id, acknowledgement_id)`
fire only after a newly committed transition. Loading completed/claimed records and
recovery never replay those signals. Busy guards prevent reentrant transitions.
The RefCounted route signal is explicitly disconnected at service exit; Node-owned
registry signal connections are cleaned up by Godot when the service is freed.

The acknowledgement **is the CLAIMED record interpreted through its authored stable
ID and text**, not a second reward grant into another subsystem. No external resource,
upgrade, inventory or reward balance is changed. UI reopening, repeated domain
signals, service use, route restart and healthy reload cannot award it again.
Downstream consumers should use stable IDs and the state snapshot, rather than
assuming signals are a transactional message queue. Cross-process concurrent writers
or arbitrary manual rollback of all files are not supported.

`ServiceStation.mission_action(accept|claim|sync|recover, id)` revalidates docking,
range, speed, pause and station availability. The UI never changes mission state
directly. Read-only notices remain accessible alongside the explicit mission page.
Gameplay stays paused through all station pages. Escape/B/Start backs out one page
at a time. Disabled actions are skipped by keyboard/controller focus; Details ↑/↓
buttons permit scrolling long descriptions without a mouse. HUD text reports both
accepted missions and objective counts; a storage error visibly replaces that line
with SAVE BLOCKED. Services and both upgrades remain separate.

## Versioned persistence and recovery

The narrowly scoped `MissionStore` defaults to `user://saves/missions.json`. An
explicit `ShelfPrototype.mission_path` overrides it. Test scenes with isolated
settings use `<settings_path>.missions.json`. Version 1 contains exactly four fields:

```json
{
  "format": "bta-missions",
  "schema_version": 1,
  "catalog_id": "shelf-prototype",
  "missions": {
    "shelf-expedition": {"state": "available", "objectives": []},
    "shelf-calibration-study": {"state": "claimed", "objectives": ["scan-calibration-plate"]}
  }
}
```

Validation caps files at 16384 bytes, requires known mission/objective IDs exactly
once, exact field sets and consistent states/flags. AVAILABLE cannot have progress;
ACCEPTED cannot already contain every objective; COMPLETED/CLAIMED must contain all.
Unsupported schemas, wrong catalog, unknown fields, malformed and inconsistent data
block writes and preserve files. Missing primary plus an existing backup also blocks
new writes until explicit recovery, avoiding accidental replacement of saved claims.

Writes use the same bounded JSON and flushed same-directory `.tmp` → rename pattern
as existing stores. **Mission `.bak` is a write-ahead checkpoint of the proposed new
state**, followed by the same primary write, rather than the previous revision used
by discovery/research/upgrade stores. This deliberate difference preserves a newly
claimed acknowledgement if the primary later corrupts. A transition is exposed in
memory and signaled only after both writes succeed. A failed primary write may leave
a valid checkpoint ahead of memory; explicit recovery adopts it without replaying
events. Every existing valid primary/checkpoint is checked before replacing it;
a stale caller cannot erase a claim. This is not a general game-save or journaling
framework and does not promise power-loss guarantees beyond platform flush/rename.

Explicit recovery validates `.bak`, preserves the primary as `.rejected`, refuses to
overwrite an existing rejected file, and merges valid current progress monotonically
with the checkpoint before writing. It never unclaims a known acknowledgement.
A corrupted backup cannot be silently overwritten. Preserve/inspect/move damaged
files before retrying; after manual repair, relaunch to reload. Both files missing
means a new mission profile; both destroyed or manually rolled back cannot be
reconstructed by this narrowly scoped store.

Failed persistence leaves runtime transitions uncommitted and shows an error.
Permanent discovery/research evidence can be reconciled using Sync / retry progress
once saving works. A bounded in-memory witness retains an accepted mission's route
return across a test-route restart if saving failed. Unsaved witnesses cannot survive
process termination when no checkpoint was written; resolve storage errors before
quitting. No route, actor, resource or acoustic state is serialized here.
