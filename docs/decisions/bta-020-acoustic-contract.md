# BTA-020: scene-owned acoustic event dispatch

BTA-020 establishes value, registration and delivery contracts without connecting
acoustics to the vessel, HUD or region. There is no sonar request, visual pulse,
reveal, hearing behavior, energy cost or sound playback. Future active/passive
sonar and creature components can compose the same emitter/receiver endpoints.

`AcousticEvent` is a RefCounted value with explicit event ID, source ID, type,
classification, world-space origin, nonnegative linear strength, nonnegative
world-unit range and caller-owned simulation timestamp in seconds. The factory
rejects invalid values. Strings are case-sensitive ASCII tokens of 1–128
characters (letters, digits, underscore, dot, slash, colon, hyphen); numeric values
must be finite and nonnegative and origin must be finite. Zero strength/range
are valid, with zero range limited to coincident receivers. No runtime instance
ID, wall clock or random generator contributes to identity. Producers supply a
stable session/source/sequence token and retain its original payload on retry.
This is a runtime contract, not a save/wire schema.

Public properties expose read-only views; underscore fields are private by
GDScript convention rather than a security boundary. The bus defensively copies
accepted events into its history and makes a separate snapshot for each receiver.
An endpoint cannot mutate another endpoint's payload or the retained canonical
value. Signal subscribers on a single endpoint share that endpoint's snapshot
and must respect the read-only contract.

An explicitly injected `AcousticBus` Node owns one acoustic space/session. It is
never an autoload, clock or gameplay service. Typed Node2D endpoints bind after
entering the same SceneTree; IDs must remain fixed while bound. Source IDs and
receiver IDs are unique in their respective registries, and each endpoint binds
to at most one bus. Rebinding to the same bus/node is idempotent; conflicting IDs
and cross-bus binding fail explicitly. A producer can dispatch only through its
registered source identity. Unbind before changing identity or moving buses.

Publish is synchronous and main-thread only. The bus validates the event/source,
rejects repeated/conflicting IDs and checks its bounded history before invoking
consumers. It snapshots registered receivers' valid enabled/filter/range/strength
eligibility and sorts IDs by explicit case-sensitive String comparison. Godot's
native StringName sort is not relied on: tests caught nonlexical ordering.
Callbacks cannot change the current event's remaining eligibility by moving a
receiver or editing its profile; those changes apply to the next event. Removal,
exit, queued deletion and unregister/re-register cancel a pending delivery. New
registrations wait for a future event. A monotonically assigned registration
generation distinguishes a pending snapshot from a replacement registration;
it is internal, transient and never an event identifier or persisted node ID.

Registries and pending deliveries use WeakRef endpoints. Tree-exiting callbacks
remove registrations and clear the endpoint's bus link. Explicit unbind detaches
the lifecycle callback; bus exit detaches live endpoints. Pruning also excludes
queued deletion immediately. Removing and readding a node requires explicit
rebinding. Removing/readding the same bus retains its event history. Queue bus
deletion from callbacks; do not immediately free the currently executing bus.

Nested dispatch/configuration returns ERR_BUSY rather than recursing or quietly
queuing work. Registration/unregistration during delivery is supported. No
per-frame scene search, physics query, propagation schedule or background thread
is introduced. Eligibility scans only registered receivers on an explicit event.

Profiles keep tuning outside dispatch rules: emission type/classification/
strength/range; receiver allow lists, source exclusions, maximum range and minimum
strength; bus attenuation mode and history capacity. The bus copies its validated
profile. Receiver profiles and positions are snapshotted per publication. Empty
allow lists mean any; exclusions win. Euclidean range is inclusive and bounded
by both event and receiver range. Distance uses double intermediates to avoid
Vector2 float32 square overflow. Optional linear attenuation is strength ×
max(0, 1 − distance/event range), with a zero-range coincident special case.
The minimum-strength comparison is inclusive; zero at the boundary is eligible
if the receiver's minimum is zero. These are abstract signal units, not decibels.

History is bounded (default 4096 accepted IDs), never silently evicted. A repeated
ID/same payload returns ERR_ALREADY_EXISTS; an ID with different content returns
ERR_INVALID_DATA. Both deliver nothing, including to late/newly in-range listeners.
Once full, new events return ERR_OUT_OF_MEMORY without delivery. Configure a
larger capacity or create a new bus for a genuinely new session; lowering capacity
below retained count is rejected. Configuration does not clear history. There is
no TTL/reset API that could silently break exactly-once delivery within the bus
lifetime. This deliberately favors explicit backpressure over bounded-cache replay.

Delivery receipt means only that a registered receiver met this instantaneous
contract. It is not detection, mapping, object reveal, scan completion or AI
reaction. Propagation delay, occlusion, broadphase acceleration, event forwarding,
networking, persistence and future acoustic classifications remain separate work.
