# BTA-021: active sonar over the acoustic contract

The existing submarine gains a configurable SonarEmitter component. Its physics
step advances sonar and handles the existing sonar_ping action before the normal
resource drain. Input settings/remapping remain authoritative; F/controller X
are only the defaults. Scene composition explicitly supplies the existing battery
system, a scene-owned AcousticBus and a static WorldEffects parent. There is no
autoload, new dependency, creature response, passive sonar, scan, mission or map.

Default authored balance is 4 battery per accepted ping, 4-second cooldown,
600 world units/second, 900-unit maximum radius, 6-second temporary target reveal
and 0.2-second visual fade. Profiles are validated/copied; already emitted pulses
retain their own profile snapshot. Radius/speed are positive and capped at one
million units for rendering; cost/cooldown/strength/fade may be zero. Active-pulse
count is bounded/configurable (default eight). A zero-cost/zero-cooldown profile
still cannot exceed that limit or the acoustic ledger budget.

## Atomic energy acceptance without changing acoustic history

A separate preflight and refund would allow failed or duplicate dispatch to
briefly charge battery and emit misleading battery/depletion signals. Instead,
AcousticBus.check_dispatch exposes the existing validation/source/dedup/capacity
checks. dispatch accepts an optional boolean Callable, invoked under the existing
reentrancy lock only after those checks, before history insertion or receivers.
A false gate returns ERR_UNAVAILABLE without reserving the ID or delivering.
AcousticEmitter.publish forwards an already validated snapshot through this
same dispatcher; emit_event retains its original behavior through publish.

Sonar passes SubmarineResourceSystem.try_consume_battery(cost) as that gate.
Failed energy is all-or-nothing through the existing API. Invalid/conflicting/
duplicate IDs, an unregistered source, busy bus or full ledger never call it.
The accepted payload is frozen before the gate so battery callbacks cannot
change event content. A component-level request guard also prevents reentrant
pings from battery signals. Cooldown and visible pulse creation happen only
after accepted publication. A pending, detached pulse exists during synchronous
receiver callbacks solely to collect eligible echoes; failure frees it unseen.
Acceptance callbacks must be well-formed synchronous atomic boolean operations,
not arbitrary code that mutates state and then rejects/throws. Successful
acceptance is a commit: later consumer removals can cancel delivery, not refund
an accepted ping. Do not immediately free the executing bus/component in a
callback; normal Godot queued deletion remains the lifecycle contract.

The BTA-020 ledger semantics are otherwise unchanged: same ID/payload is rejected,
conflicting content is rejected, no eviction/TTL/reset is added, capacity fails
closed, and existing producers without a gate behave as before. Tests retain all
28 BTA-020 cases and add acceptance/reentrancy/payload-freezing checks.

## Arrival and temporary reveal

SonarRevealTarget composes an AcousticReceiver filtered for active_sonar. Its
receipt forwards the existing dispatcher's snapshot distance and event metadata
to SonarEmitter. Receipt alone never reveals. Only a matching pending pulse can
schedule an echo. There is no parallel scene scan or second dispatcher. Receiver
range/type/classification/source/strength filtering remains owned by AcousticBus.

A SonarPulse stays at the emitted world origin under WorldEffects, independent of
submarine motion. Its radius is min(maximum radius, age × speed). Each eligible
target is scheduled at event simulation time + distance/speed. Arrival records
sort by distance then stable target ID, and are marked done before callbacks.
Duplicate receipts and repeated target reveal calls are suppressed per ping.
A 1e-9-second comparison tolerance handles numerical step accumulation at exact
boundaries. The front cannot reveal an out-of-range target because it never
receives an eligible acoustic receipt. Zero-distance targets can reveal on the
first advance (including advance(0)), when the radius has reached zero.

Target handles and pulse handles are weak. Before arrival, lifetime, bus binding,
stable identity and registration generation must still match. Deleted, exited,
unbound/rebound targets and a removed/deleted bus cancel pending arrivals. Late
targets do not receive old events. Eligibility/distance are sampled at emission,
consistent with BTA-020; prototype targets are static. Moving-target interception,
occlusion, reflectivity and physics acoustic propagation are not claimed.

Temporary reveal expiry uses absolute simulation arrival+duration, not the end
of the frame that crosses arrival. This preserves visibility duration under
30/60/120 steps, overlapping pulses and large time advances. A large advance can
cross both arrival and expiry: the reveal notification still occurs once, while
the final target is hidden. Multiple pings extend expiry to the latest arrival.
Nothing is persisted and terrain itself is never revealed or hidden.

The owner advances all sonar clocks only from the existing motor physics step.
Route/settings/debug pauses stop radius, cooldown and target expiry together.
A route restart cancels pulses, resets target/session state and source clocks,
and rebinds the read-only HUD. It increments the producer epoch, preserving the
existing bus and its history while issuing fresh stable session/source/epoch/
sequence IDs. A newly constructed producer reusing a surviving bus must receive
a fresh session namespace; no instance IDs or wall-clock identity are used.

The HUD replaces NOT IMPLEMENTED with READY/COOLING/LOW BATTERY/BUSY/BLOCKED/OFFLINE,
numeric cooldown/cost and the last ping's echo count. Counts describe receipts
for that ping, not permanent discoveries or currently visible contacts. Existing
resource/depth/pressure instruments remain unchanged. The original movement
fixture has no injected acoustic space and honestly displays OFFLINE.
