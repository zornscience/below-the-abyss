# BTA-020 acoustic contract and verification

> BTA-021 composes this contract for active sonar. Default dispatch/history
> behavior remains unchanged; see the acceptance extension below and
> [active sonar verification](active_sonar.md). BTA-022 also composes this contract
> for [passive listening](passive_sonar.md), adding read-only `get_emitter(id)`
> and `source_removed(source_id)` lifecycle notification without changing history.

Godot **4.6.3.stable.official.7d41c59c4**, typed GDScript, no new dependencies,
autoloads, input actions or changes to existing gameplay scenes. This module is
under `scripts/sonar/` to match the TDD directory layout; it does not implement
active/passive sonar or creature behavior.

## Minimal reproducible demonstration

From the repository root after import:

```sh
python3 tools/install_gut.py
python3 tools/validate_godot.py
godot --headless --path . res://scenes/main/acoustic_contract_example.tscn
```

Expected exit status: **0**. Output includes:

```text
ACOUSTIC_EXAMPLE deliveries=[&"boundary", &"near"] duplicate=Already exists eligible=2 far=0 filtered=0
```

The emitter at (0,0) emits one event of strength 10 and range 100. Receivers at
50 and exactly 100 units receive it once, in lexical ID order. A receiver at 101
units and one allowing a different event type receive nothing. Repeating the
same ID/payload returns ERR_ALREADY_EXISTS without another delivery. The example
exits 1 if its conditions fail; integration tests instantiate it without quitting
and assert both result and deliveries. It has no graphics or audio to screenshot.

The standard main scene still opens the continental-shelf briefing:

```sh
godot --path .
godot --path . res://scenes/main/movement_prototype.tscn
```

## API contract

| Type | Contract |
| --- | --- |
| AcousticEvent | `create(id, source, type, category, position, strength, range, timestamp)` returns a valid snapshot value or null; `is_valid()`, `snapshot()`, `same_payload(other)` |
| AcousticEmissionProfile | Resource: event_type, classification, strength, range_units; `is_valid()` |
| AcousticReceiverProfile | Resource: accepted_event_types, accepted_classifications, excluded_source_ids, maximum_range_units, minimum_strength; `is_valid()` |
| AcousticDispatchProfile | Resource: NONE/LINEAR attenuation and maximum_event_history; `is_valid()` |
| AcousticEmitter | Node2D: authored source_id/profile; `bind_bus(bus)`, `emit_event(event_id, simulation_time)`, `publish(event,acceptance=Callable())`, `get_bus()`; accepted-only `event_emitted(event)` signal |
| AcousticReceiver | Node2D: authored receiver_id/profile/enabled; `bind_bus(bus)`, `get_bus()`; `event_received(event, received_strength, distance_units)` signal |
| AcousticBus | Node: configure(profile), register/unregister_emitter/receiver, check_dispatch(emitter,event), dispatch(emitter,event,acceptance=Callable()), emitter_count(), receiver_count(), history_count(); `event_dispatched(event_id, delivery_count)` signal |

`bind_bus(null)` unbinds. All registrations require live in-tree endpoints and
bus in the same SceneTree; all calls belong on the main thread. Each endpoint
can have only one bus. Invalid IDs/profiles return ERR_INVALID_PARAMETER; nodes
outside the tree return ERR_UNCONFIGURED. Duplicate authored IDs owned by a
different node return ERR_ALREADY_EXISTS. Re-registering the same endpoint is
idempotent. Cross-bus binding returns ERR_ALREADY_IN_USE; unbind first. Explicit
unregister of an absent node returns ERR_DOES_NOT_EXIST. Lifecycle exit clears
links automatically. Stable endpoint IDs must not change while registered.

A minimal composition root can add a bus and endpoints, then bind them:

```gdscript
var bus: AcousticBus = AcousticBus.new()
add_child(bus)
var emitter: AcousticEmitter = AcousticEmitter.new()
emitter.source_id = &"vessel-01"
add_child(emitter)
var receiver: AcousticReceiver = AcousticReceiver.new()
receiver.receiver_id = &"observer-01"
receiver.position = Vector2(50, 0)
add_child(receiver)
receiver.event_received.connect(_on_acoustic_event)
receiver.bind_bus(bus)
emitter.bind_bus(bus)
# Caller owns this stable sequence and simulation clock, not OS time or instance IDs.
emitter.emit_event(&"expedition-01/vessel-01/000001", 12.5)
```

Use `dispatch(emitter,event)` when a caller already holds an original validated
event snapshot, such as retrying it after a backpressure error. The emitter must
still be registered under event.source_id; an impostor node is rejected. Source
origin need not equal its current position when dispatching a held snapshot;
the event origin records where emission occurred. `emit_event` samples current
world position and current emission profile. Successful publication may have
zero eligible listeners and still consumes an event ID.

`AcousticEvent` fields are `event_id`, `source_id`, `event_type`, `classification`,
`origin`, `strength`, `range_units`, `simulation_time`. IDs/types/classifications
are case-sensitive 1–128-character ASCII tokens using letters, digits and
`_./:-`. Position must be finite; strength/range/time must be finite and >=0.
Coordinates/ranges are world units (pixels in the current prototype), independent
of authored depth meters. Strength is abstract linear signal strength, not dB.
Time is producer-supplied simulation seconds; no wall clock, delivery timer or
ordering-by-time is implied. Distinct events can share timestamps. IDs must be
unique across sources for this bus/session; session/source/sequence is an example
scheme, not automatically generated behavior. No new persistence format is added.

### Eligibility, ordering and mutation

- Snapshot all valid enabled receivers at publication. Empty type/classification
  allow lists accept any; matching is exact and source exclusions override them.
- Euclidean distance <= min(event range, receiver maximum range). Zero range
  means coincident only. Nonfinite receiver positions or invalid live profiles
  are skipped safely without preventing other deliveries.
- NONE attenuation preserves signal strength. LINEAR uses
  `strength * max(0, 1 - distance / event_range)`; at zero range/coincident it
  preserves strength. Received strength must be >= the receiver threshold.
  Thus exactly zero strength at the boundary is eligible with threshold zero.
- Deliver once to each eligible registration in explicit lexical receiver-ID
  order, independent of registration or StringName interning order. Callback
  position/profile/enabled changes affect future events, not the current snapshot.
- Check lifetime and registration generation again before delivery. Immediate or
  queued receiver deletion, exit and unbind/rebind cancel a pending callback.
  Newly registered receivers do not join an in-progress event. Queuing bus
  deletion stops remaining deliveries; do not free the executing bus inline.
- Nested dispatch and configure return ERR_BUSY; they are not queued or counted
  in history. Signal handlers may register/unregister endpoints. Event content
  is copied per receiver; consumers must treat its public views as read-only.
  GDScript underscore fields are conventionally private, not protected storage.

The bus owns no physics/world transform: explicitly registered endpoints must use
the same world coordinate frame. A bus defines a logical acoustic space, not an
automatic bridge between different World2D instances or regions.

### Duplicate and capacity semantics

For the bus lifetime, an accepted event ID remains consumed. Same ID/same payload
returns ERR_ALREADY_EXISTS. Same ID/different source, classification, position,
strength, range or time returns ERR_INVALID_DATA. Neither invokes a receiver,
including newly registered or newly in-range listeners; there is no catch-up.
The ledger is independent of receiver removal/recreation and source unbinding.
Removing/readding the same bus retains it. Freeing the bus ends that session.

The default ledger limit is 4096 accepted IDs. No eviction or TTL can permit a
replay. At capacity, new events return ERR_OUT_OF_MEMORY before callbacks. A
validated `configure` can increase capacity, preserving history; shrinking below
retained count is rejected. The bus copies its dispatch profile so mutating a
shared authored Resource does not silently alter active rules. Receiver settings
are validated and snapshotted for each event. Invalid events, rejected sources,
reentrancy and full-ledger rejection do not reserve a new ID.

## BTA-021 atomic acceptance extension

`check_dispatch(emitter,event)` exposes the same validation/source/dedup/capacity
checks used by dispatch. An optional boolean acceptance Callable runs only after
those checks, under the reentrancy lock and before ledger insertion/receivers.
A false result returns ERR_UNAVAILABLE, with no ID reservation or notification.
The payload is frozen before invoking it. Active sonar supplies the existing
atomic try_consume_battery API; it never charges on invalid/duplicate/rejected
publication. This is not a rollback mechanism for arbitrary callback side effects.
Successful acceptance commits the event. Existing callers without the gate keep
their original semantics; there is still no eviction, TTL or history reset.
Focused tests cover false/true gates, duplicate/conflicting IDs, payload freezing
and reentrant rejection; all original acoustic tests remain enabled.

## Automated verification

Run the entire suite with the existing commands:

```sh
python3 tools/install_gut.py
python3 tools/validate_godot.py
python3 tools/run_tests.py
git diff --check
```

Managed cloud setup, if needed:

```sh
export XDG_CACHE_HOME=/workspace/.cache
export XDG_DATA_HOME=/workspace/.local/share
export XDG_CONFIG_HOME=/workspace/.config
```

For focused acoustic tests after import:

```sh
godot --headless --path . --script res://addons/gut/gut_cmdln.gd \
  -gexit -gdisable_colors -gconfig= \
  -gtest=res://tests/unit/test_acoustic_event.gd,res://tests/unit/test_acoustic_bus.gd,res://tests/integration/test_acoustic_lifecycle.gd
```

The 28 focused tests cover event fields/factory validation, malformed tokens,
nonfinite/boundary numbers, snapshot isolation, profile validation, registration
conflicts/idempotence/removal, unbound/cross-bus endpoints, inclusive event and
receiver radius, zero range, filters/thresholds, optional attenuation, stable
lexical ordering, duplicate/conflicting IDs, capacity without eviction, retained
history, invalid sources, emitter notifications, reentrancy, callback mutation,
large finite coordinates, free/queue-free/tree exit/reentry, registration
replacement mid-event, bus teardown, world position/time and the example itself.

The unchanged Actions workflow installs checksum-pinned Godot 4.6.3/GUT 9.6.1,
imports, parses every authored script, smoke-launches the original default main
and runs all test suites. The example is additionally asserted in GUT, so no
workflow relaxation or special standalone smoke exception is needed. Logs and
JUnit reports remain in the existing 14-day artifact. Final full-suite counts and
hosted results are recorded in the pull request. Local results: **143/143 tests,
4,002 assertions, zero failures/errors/skips**; **56 parser checks**, import,
startup smoke, actionlint and whitespace checks pass. All 115 existing tests
remain enabled, with 28 acoustic tests added. The standalone example exits 0.

## Manual checks and limits

1. Run the headless example; verify the two named eligible deliveries, duplicate
   rejection, no far/filtered delivery and exit 0. Rerun in a new process: it is a
   new bus/session with the same deterministic output.
2. Inspect/tune the example emission and receiver subresources in the editor.
   Range 100 includes the boundary receiver; 99 excludes it. A different type
   allow list rejects a receiver without altering any world object. Restore the
   example before normal tests because it intentionally asserts its baseline.
3. Use a small composition scene to configure LINEAR attenuation and a positive
   minimum strength; compare center, half-range and edge values with the formulas.
   Unbind or free a receiver, then publish a new ID: it must not receive.
4. Run `godot --path .` and the preserved movement fixture. Verify existing
   movement, resources, depth/damage, HUD, settings and exploration restart still
   work. Sonar must remain NOT IMPLEMENTED; no cost, pulse, reveal or AI occurs.

This is instantaneous dispatch over registered receivers, O(N log N) for N
receivers per event, with bounded O(accepted-event-count) history. There is no
propagation delay, occlusion, acoustic material model, physical decibel model,
spatial broadphase, multi-threading, replay/persistence/network protocol or UI.
Future visuals/detections/AI must consume the contract separately. Existing
physical-controller/native-platform/novice playtesting limits remain unchanged;
headless tests make no new platform claim. No screenshot is applicable to this
text-only infrastructure milestone.
