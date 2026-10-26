# BTA-023: permanent POI discoveries and a limited exploration map

The shelf composition owns a DiscoveryRegistry Node, a narrow DiscoveryStore and
an ExplorationMap. No autoload, dependency, mission/reward, scan, region streaming,
terrain mapping or general game-save system is added. Resources hold authored
metadata; runtime discovery state belongs to the registry.

## Stable identity and eligible discovery

PointOfInterest contains stable_id, sonar_target_id, display_name and region-local
map_position. IDs are 1–64 lowercase ASCII letters/digits/hyphens/underscores.
DiscoveryCatalog validates region ID, finite positive public survey extent, up to
128 definitions, unique POI IDs/target bindings, and positions within that extent.
Accepted catalogs are deeply copied. Existing shelf targets demonstrate three
POIs: shelf-navigation-marker ↔ shelf-marker, shelf-overlook ↔ overlook-marker,
and shelf-twin-spires ↔ spire-marker. Their map coordinates match the existing
scene targets; route geometry, signs, resource balance and acoustic IDs are unchanged.
The existing cave-marker remains a temporary echo without a POI binding.

States are HIDDEN and DISCOVERED. All POIs start hidden unless a validated prior
discovery file restores them. connect_sonar_target attaches explicitly to the
existing SonarRevealTarget.revealed_for_ping signal. Acoustic receipt and pulse
emission alone do not discover: the existing SonarPulse must reach an eligible,
live target first. Normal target removal/generation checks remain authoritative.
Discovery does not depend on is_revealed(), which can already be false when a
large simulation step crosses both arrival and echo expiry. First arrival marks
the stable POI exactly once and signals point_discovered; later pings are idempotent.

discover(id, evidence_id) is a trusted gameplay-adapter interface, not a public UI
command or anti-cheat boundary. It validates authored identity and evidence token;
it does not manufacture a second acoustic event dispatcher or history. Passive
contacts, route telemetry, map opening, proximity, and map selection never call it.
No acoustic contracts or existing event/duplicate/history implementations change.
The registry stores no ping history, timestamps, runtime instance IDs or contact state.
Lexical String comparison explicitly orders snapshots and saved IDs deterministically.

| API | Contract |
| --- | --- |
| configure(catalog) -> Error | Validate/copy once; subsequent configuration cannot clear permanent state |
| connect_sonar_target(target) -> Error | Explicit arrival-signal adapter; weak target handles, idempotent binding; unknown target has no POI |
| discover(id, evidence_id) -> Error | Known valid POI/evidence required; duplicate returns ERR_ALREADY_EXISTS without signals |
| state_of(id), discovered_ids(), discovered_points() | Hidden by default; sorted copied discovered metadata only; no total-secret count exposed |
| restore_discoveries(ids) -> Error | Validate whole list before merging; no partial application or erasure of pending discoveries |
| survey_bounds(), region_id() | Public authored map-space contract, independent of secret terrain |
| point_discovered(id), registry_changed | New-discovery side effects vs read-only presentation refresh |

Bindings are scene-local and use normal Godot signal receiver cleanup; deleted
registries disconnect automatically. Replaced/exited targets cannot retain a strong
registry-owned reference. Stable authored IDs must not change while bound.

## Narrow versioned persistence

Default path: user://saves/discoveries.json. An explicit discovery_path export
supports isolated profiles/tests. For existing fixtures using a custom settings_path
and no discovery_path, it defaults to settings_path + .discoveries.json, protecting
the real player discovery file. Changing a key binding never changes either path.
Only discovery IDs are stored:

```json
{
  "format": "bta-discoveries",
  "schema_version": 1,
  "region_id": "continental_shelf",
  "discovered_poi_ids": ["shelf-navigation-marker"]
}
```

The reader caps files at 16 KiB, requires exactly these four fields, an integral
version 1, matching format/region, an array of at most 128 unique known stable IDs
and correct types. Unknown versions return ERR_UNAVAILABLE; malformed, oversized,
unknown-ID or wrong-region data returns ERR_INVALID_DATA. All validation completes
before merging into runtime state. No executable objects/resources or arbitrary
paths are loaded from JSON. This is not a BTA-035 save slot or schema migration.

Missing primary files are a clean first run. Invalid/incompatible/unreadable files
are preserved, automatic writes are blocked and the map reports the problem.
New discoveries remain available in memory even when saving fails. Retry save
revalidates/reloads a manually repaired file, merges pending discoveries and saves.
Recover backup is an explicit user action: validate .bak first, preserve the current
primary as .rejected, merge backup IDs without losing pending discoveries, then
write. Existing .rejected blocks another recovery rather than overwriting evidence.
A missing/bad backup changes no discovery state or existing files.

Each write uses a same-directory .tmp, checks write/flush errors, closes, then
renames. Before replacing a valid primary, its validated contents are atomically
written to .bak; backup failure prevents primary replacement. The primary is
revalidated before saving so later external corruption cannot be silently erased.
Interrupted .tmp files are ignored on load; failure removes the temporary file
when possible. Explicit recovery preserves both backup and rejected evidence.
This is a single-writer local prototype, with no interprocess lock or filesystem
power-loss/fsync guarantee. Native rename/permission behavior requires platform
playtesting. The backup holds the previous successful primary, not necessarily
the newest unsaved discovery. No automatic recovery or silent version downgrade.

## Map, input and restart semantics

Existing remappable open_map (M / controller Back-Select by default) opens/closes
the map; Escape/B/Start also closes. Fixed accessible menu navigation (arrows,
Tab, D-pad, stick, Enter/A) selects discovered landmark buttons, mirrored as numbered
squares and a highlighted ring; triangle + YOU identifies the vessel. Labels and
shape distinctions work without color. Focus wraps through close, retry, recovery
and discovered entries. Selected entries show their full name below the map.

The map uses region-local coordinates, a coarse 4100×1800 public survey rectangle,
a reference grid and surface Y=0. It deliberately omits all interior/cave/trench
geometry, hidden markers, undiscovered labels/counts, passive contacts and rewards.
The public rectangle is authored independently of secret terrain. There is no fog
mask, pan/zoom, minimap, pathfinding or terrain reveal. At 800×600 the same controls
and text remain visible; a scroll list accommodates additional authored POIs.

Map opening freezes the existing motor, resource drain, pressure damage, active
pulse/cooldown/reveal clocks, passive expiry and ambient scheduling. Closing returns
to the prior piloting/briefing state. Settings or focused debug controls prevent
opening another modal. Map opening does not spend battery or publish events.

Test-route restart resets vessel, active/passive temporary state and route check
as before, while retaining the registry, discovery file and acoustic ledger.
Restart has no discovery-clear path. Fresh scene startup loads discoveries but
does not restore temporary echoes, route progress or vessel state. For a genuinely
clean test, close the game and move the discovery file plus .bak aside explicitly;
there is deliberately no in-game permanent-discovery reset button.

Native Windows/macOS, physical controller and screen-reader integration remain
unverified. Text/focus equivalents and injected controller events are tested on
Linux; this is not a claim of platform certification or full assistive-technology
support. See the verification guide for actual screenshots and commands.
