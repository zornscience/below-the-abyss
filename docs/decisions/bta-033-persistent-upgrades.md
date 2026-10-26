# BTA-033: two persistent absolute upgrades

## Authored capability contract

`resources/equipment/shelf_upgrades.tres` is an `UpgradeCatalog` with precisely two
`UpgradeDefinition` Resources. Stable IDs identify installations; never node IDs.
Each definition has a display name, one supported capability, an explicit baseline
and a strictly greater finite upgraded value. The catalog rejects duplicate IDs,
duplicate capability types, mismatched baselines or any count other than two.
No generic modifier stacking, slots, additional types or dependency is introduced.

| ID | Capability | Baseline | Installed |
| --- | --- | --- | --- |
| `sonar-range-1200` | Active-sonar maximum radius | 900 world units | 1200 world units |
| `pressure-hull-400` | Rated safe operating depth | 300 meters | 400 meters |

The sonar improvement is 33⅓% greater radius; at unchanged 600 units/second, its
outer wavefront arrives at 2 seconds rather than 1.5 seconds. Battery cost remains
4 and cooldown 4 simulation seconds. Strength, travel speed, reveal duration,
passive listening, scanning and creature perception profiles are unchanged. Larger
active events still pass through the existing AcousticBus and can be heard by
eligible creatures. There is no silent bypass of the acoustic contracts.

The existing 40-meter warning margin now produces CAUTION at 360 meters, through
the inclusive 400-meter rating; DANGER begins strictly beyond 400 meters. At the
existing 320–375-meter optional trench, an installed hull prevents pressure damage.
Beyond its new rating, the existing two-second grace and four hull/second damage
rules still apply. Current hull is never repaired by installation. The trench's
fixed signs describe the baseline hull and refer to the authoritative HUD rating.

## Runtime API and composition

`SubmarineUpgrades.setup(catalog, sonar, damage, path)` validates and snapshots the
catalog, binds existing components, loads ID-only state and reconstructs capabilities.
It is one-time setup per component. `definitions()` and `installed_ids()` return
copies. `is_installed(id)` is a query. `install(id)` returns an Error, rejects unknown
or duplicate IDs, and emits `upgrade_installed(id)` once only after successful saving
and application. `capabilities_changed` reports reconstruction. Reentrant installation
is rejected, including callbacks during saving and domain/UI notification.

`ServiceStation.install_upgrade(id)` revalidates the same live paused docking
session, range, speed, availability and busy guard as services. The UI calls this
interface rather than changing sonar/depth itself. The runtime component can be
reused by other scene coordinators; station eligibility belongs to the station.

Application starts from the copied validated baseline sonar profile and absolute
installed values. It uses `SonarEmitter.configure` (which snapshots tuning without
resetting pulse/time/cooldown/event state) and the existing
`SubmarineDamageSystem.set_maximum_depth_m` API. Old pulses keep their original
range/profile snapshots; only subsequent pings gain range. The acoustic source ID,
event sequence/epoch, duplicate suppression and bounded bus history are unchanged.
The existing sonar state and maximum-depth signals update HUD range and warning text.

`reapply()` reconstructs after Restart Test Route's existing damage configure/reset.
It does not load, install, multiply or append IDs. Services and opening/closing menus
never touch installation state. Route restart resets temporary state as before,
while reload reconstructs upgrades plus independent discoveries/research. No actor,
resource, route or acoustic history is serialized by this system.

## FREE installation and persistence

The GDD names research/upgrade relationships but no implemented prerequisite or
currency service exists. Both prototype installations are explicitly FREE, available
only through intentional activation on the docked station's Prototype upgrades page.
No research points, inventory, materials, economy, rewards or mission state are added.

`UpgradeStore` writes `user://saves/upgrades.json` by default. Test/composed scenes
may override `ShelfPrototype.upgrade_path`; scenes using an isolated settings path
use `<settings_path>.upgrades.json` unless explicitly overridden. Version 1 is:

```json
{
  "format": "bta-upgrades",
  "schema_version": 1,
  "catalog_id": "neris-prototype",
  "installed_upgrade_ids": ["pressure-hull-400", "sonar-range-1200"]
}
```

Only these four fields are accepted; files are capped at 4096 bytes. IDs must be
known unique strings (at most two), and the schema version must be integer 1.
Unknown fields, wrong catalog/format, invalid types, oversized/malformed content and
incompatible versions block installation and preserve the original file. A missing
file means baseline/new state. No numerical capability values are loaded from disk.

Writes revalidate any existing file, back up its valid previous content to `.bak`,
flush/close a same-directory `.tmp`, then rename it over the primary. Installation
persists candidate IDs **before** changing runtime capabilities: failed saves do not
grant a volatile upgrade or emit a completion event. This deliberately differs from
a pending research discovery, which can exist in memory before saving. There is no
claim of power-loss durability beyond the platform's flush/rename guarantees.

As with DiscoveryStore/ResearchStore, corrupt or incompatible primary data is not
silently discarded. The station shows the status and an explicit Recover backup /
replace installed IDs action. Recovery validates `.bak`, preserves the primary as
`.rejected`, refuses to overwrite an existing `.rejected`, writes the valid backup,
and reconstructs capabilities. **Recovery replaces the ID set and can roll back the
most recent installation**; it does not merge untrusted data. Missing/bad backups or
write failures leave capabilities unchanged. Inspect/move preserved files before
retrying blocked recovery; after manually repairing a primary, relaunch to reload.
An absent primary does not silently restore a backup; explicit recovery remains available.

## Scope and limitations

One vessel/catalog, two upgrades and a narrowly scoped local file. No migration from
future schemas, general game save, uninstall flow, purchases, upgrade tree, new
regions or mission progression. Existing authored baselines must remain compatible
with the catalog; changing balance in a future release requires deliberate catalog
validation/version policy. Physical controller ergonomics and platform-specific
filesystem behavior beyond the tested Linux environment remain manual verification.
