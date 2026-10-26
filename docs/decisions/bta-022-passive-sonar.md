# BTA-022: temporary passive acoustic contacts

PassiveReceiver composes the existing AcousticReceiver and subscribes through the
scene-owned AcousticBus. AmbientSoundEmitter composes AcousticEmitter. Neither
component creates another dispatcher, singleton, active pulse, battery cost,
world marker, reveal, discovery, creature, or audio asset. Ambient classifications
are mechanical, geological and marine_life; these are sound categories, not
scientific identifications. Unknown categories remain UNKNOWN in the HUD.

## Reusable API

| Component | Public interface after scene readiness |
| --- | --- |
| PassiveReceiver | `configure(PassiveSonarProfile) -> Error`, `bind_bus(AcousticBus) -> Error`, `advance(delta) -> Error`, `set_suspended(bool)`, `reset_session()`, `contacts_snapshot() -> Array[Dictionary]`, `status_text()`, `contacts_changed` signal |
| AmbientSoundEmitter | Authored `source_id`, `session_id`, `configuration`; `configure(AmbientEmissionProfile) -> Error`, `bind_bus(bus) -> Error`, `next_event_time() -> float`, `emit_next() -> Error`, `reset_session()`, `last_result` |
| AmbientAcousticField | Authored emitter children; `bind_bus(bus) -> Error`, `advance(delta) -> Error`, `reset_session() -> Error` |
| PassiveContactsPanel | `bind_source(PassiveReceiver)`, `set_compact(bool)`; weak, read-only presentation |

Profile validation copies accepted tuning; invalid configuration/time advances
return errors without modifying the current valid state. Binding null unbinds;
endpoints obey the original same-tree, one-bus and unique stable-ID requirements.
`advance` must be called once by the owner per active simulation step, not by
multiple clocks. A field owns its scheduled emitters; do not additionally call
`emit_next` from another scheduler. Contact signals are also emitted as active
time/pose changes so the HUD countdown and bearing can refresh without polling
world objects. Suspended listening rejects events rather than replaying them later.

## Contracts and deterministic time

Receiver eligibility (event/source/classification filters, minimum raw received
strength, inclusive emitter/receiver ranges and optional bus attenuation) remains
owned by AcousticBus. PassiveReceiver additionally accepts only ambient events,
even if its profile is configured with wildcard types. The public snapshot contains
source/event IDs, classification, approximate relative bearing/strength and expiry;
it deliberately omits absolute source position and distance. Bearings use the
last heard origin and current receiver pose: local +X is 0°, positive clockwise
in Godot's downward-Y space, wrapped to [-180°, 180°). They are quantized to 15°.

Strength is a sampled approximation: clamp(received strength / reference, 0, 1),
optionally multiplied by clamp(1 - distance / event range, 0, 1), then rounded to
0.2 increments. Reference defaults to 1. This optional perceptual distance falloff
is additional to any configured bus attenuation. Raw strength eligibility is
checked before approximation; a valid contact at the range boundary can read 0%.
It is not a range estimate, physical acoustics model, or continuously tracked source.

All publishers and listeners in an acoustic space must use the same simulation
time epoch. The field schedules absolute first_delay + sequence × interval
rather than accumulating interval timers. Due publications sort by deadline,
then stable source ID. Receiver expiry is event timestamp + 8 seconds, inclusive
at the boundary (1e-9 tolerance), so large catch-up steps cannot extend old sounds.
The existing submarine motor advances passive time; the shelf advances its field
only while that motor is enabled. Route/settings/debug pauses suspend reception,
publication, and expiry together. There is no wall-clock timer or global clock.

The default receiver holds one contact per source, retaining the strongest three
with lexical source-ID tie breaking (configurable maximum 1–8). Newer events update
that contact; older timestamps and duplicate current IDs cannot extend it. The
bus remains the sole lifetime deduplication ledger. No second unbounded ID cache
is introduced. Snapshots are copies and contact records contain no Node references.

## Lifecycle, memory and existing history

AcousticBus adds only a read-only get_emitter lookup and source_removed signal
on emitter deregistration/cleanup. It retains the existing validation, atomic
active-ping acceptance, deterministic dispatch, duplicate rejection, payload
conflict rejection, and fail-closed bounded history. Removed sources immediately
lose contacts; weak field/HUD references and normal queued deletion avoid stale
listeners. Late listeners do not replay history.

Ambient sources emit IDs session/source/epoch/sequence. Restart increments source
epochs, clears passive contacts and resets simulation clocks without resetting or
evicting the bus history. Reconstructed producers on a surviving bus require a
fresh session namespace. Each authored source is capped at 128 events per epoch;
three sources cost at most 384 ledger entries. Fields accept at most eight sources,
profiles at most 256 events each. Invalid/full/rejected publication halts that
source without repeated retries. The existing 4096-entry bus capacity is unchanged:
long sessions or many restarts can exhaust it, at which point both ambient and
active publication honestly fail closed until a fresh scene is created.

## Shelf composition and HUD

The station machinery is at (250, 500), range 1200, first event at 2s and interval
6s; rock friction at (1180, 850), range 1400, first 3s/interval 8s; marine ambience
at (2080, 430), range 1000, first 4s/interval 10s. They are logical acoustic sources,
not creature entities, recorded audio, narrative discoveries or refill stations.
No collision, route, depth, resource balance or active target was changed.

The read-only HUD shows up to three contacts with text category, arrow/signed
bearing, approximate percentage/bar and remaining simulation seconds. Below
1100px, it uses compact single-line rows retaining category, bearing, strength
and expiry. No HUD control takes focus or intercepts gameplay input. The original
movement fixture has no injected ambient space and shows passive OFFLINE.

Limitations: no occlusion, Doppler, localization, passive audio playback, moving
source tracking, physical uncertainty simulation or persistence. Native Windows,
macOS and physical-controller playtests remain manual. See the verification guide
for actual Linux renders, tests and a reproducible receive-only example.
