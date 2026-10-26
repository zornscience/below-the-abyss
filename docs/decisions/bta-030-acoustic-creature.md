# BTA-030: harmless acoustic-reactive creature foundation

The shelf owns one AcousticCreature in the optional overlook. It composes the
existing AcousticReceiver, a pure CreatureState model and bounded CreatureNavigation.
CreatureProfile Resources hold speeds, hearing filters, priorities, patrol points,
area/radius, investigation/recovery/stuck timing and grid spacing. No autoload,
dependency, attack, pursuit, hull damage, combat, stealth, mission or BTA-031 threat
encounter is introduced. The creature emits no acoustic events and has no save data.

## Acoustic eligibility, arbitration and history

The existing scene-owned AcousticBus registers creature/shelf-observer. Its normal
range, strength, classification, source and enabled filters still govern receipt.
The creature listens for active_sonar and ambient by default, with hearing range
650 units and minimum received strength 0.2. It uses the bus-provided strength and
distance, plus region-local origin converted from the immutable event snapshot.
The behavior additionally requires the origin to be inside the body's permitted
center bounds. An outside sound can be heard by the endpoint but cannot lure the
creature out of its optional habitat. No second acoustic dispatcher or scene scan
is introduced. No acoustic implementation or event-ID/history semantics changed.

Receipts enter one bounded pending-best slot and are consumed by simulation steps.
Priority is a total deterministic order: configured event-type priority descending
(default active_sonar 20, ambient 10), received strength descending, timestamp
newest first, then lexical source ID and event ID ascending. Same-step overlapping
sounds therefore select the same winner regardless of receipt order. Later higher-
ranked sounds may retarget the current investigation but never extend its original
deadline. Weaker sounds do not displace its focus. Selection never changes the
accepted event payload or identifier.

The model retains only one pending candidate, one focus and the last selected ID.
Repeated pending/current IDs are rejected defensively. The existing bounded bus
ledger remains the authority for lifetime duplicate/conflicting-payload suppression:
there is no unbounded per-creature ID cache, history eviction, TTL or history reset.
Fresh IDs from repeated sounds can retarget; no re-publication is generated.
Stale sounds older than the configurable 2-second memory are rejected. Timestamps
more than that interval ahead of the shared clock are rejected; nearer future
receipts wait until their simulation timestamp. Publishers/listeners must share
the same active simulation epoch. Sounds during pause or RETURN are ignored,
not accumulated/replayed after recovery.

Hearing is synchronous eligibility through the existing bus, independent of the
active-sonar *visual/reveal* wavefront. An eligible ping can start investigation
on the next simulation step; discovery still waits for its existing wavefront.
Passive listening itself publishes nothing, so it cannot attract the creature.
Actual qualifying ambient emitters may attract it when their origins are inside
its habitat. Authored shelf ambience origins are outside this optional habitat;
tests inject a controlled in-area ambient source to demonstrate that contract.

## States and timing

| State | Behavior / exit |
| --- | --- |
| PATROL | Follow authored points cyclically; eligible selected sound starts INVESTIGATE |
| INVESTIGATE | Navigate to sampled sound origin; arrival, 6-second absolute deadline or 1.5 seconds blocked starts RETURN |
| RETURN | Ignore new sounds; navigate to nearest patrol point (index breaks distance ties), then resume next point |

Return begins a 2-second minimum recovery interval; patrol must also be recovered
before another investigation can start. This prevents overlapping sounds from
starving recovery. Unreachable patrol/return points advance to the next authored
point after the stuck interval; if all are blocked, the creature waits/tries the
bounded route and reports blocked state rather than warping or crossing terrain.
No state targets the moving player, only the sampled sound origin.

The CharacterBody2D adapter uses fixed 1/120-second internal steps for motion and
state timing, regardless of 30/60/120 outer physics steps. advance_simulation accepts
finite deltas in [0,1] (at most 120 internal steps per call); invalid advances change
nothing. Normal engine fixed deltas are far below this bound. Brain-only advance
has validated simulation delta and absolute deadlines. Constant configured speeds
are 55 patrol, 85 investigation and 65 return units/s. Motion remains continuous
at state changes; it uses cardinal paths/constant speeds rather than animation or
acceleration steering. There is no teleport-on-arrival shortcut.

## Bounded, collision-safe navigation

The default local habitat is Rect2(1380,210,620,250). The body radius is 16; center
bounds shrink the habitat by that radius. This is above the main route at Y=480.
Patrol points are (1510,420), (1510,250), (1890,250), (1890,420). The existing solid
overlook pillar requires detours. No terrain/collision boundary or required route
was moved. A sign points toward the optional observer area.

Navigation builds an AStar2D cardinal graph with at most 1024 cells (40-unit spacing
by default). Circle-overlap tests reject occupied nodes; swept circle queries
validate every edge. Start/goal anchors also require a clear swept connection;
solid/outside goals fail closed. Graph rebuild is deferred until active physics,
after authored terrain registration, and occurs again on explicit route restart.
Paths replan on goal changes or failed-path retries every 0.5 simulation seconds.
The graph is static terrain navigation, not a general dynamic-agent avoidance system.

Actual motion always uses move_and_collide with the configured circle, even if
geometry changed after the graph was built. A stale path cannot tunnel through a
new thin wall: blocked motion triggers RETURN, and clear local return connections
allow recovery. Probe/body radii match so a valid stopped body is not falsely
considered embedded. Position is never clamped or assigned during ordinary motion.
The explicit test-route restart alone restores the validated authored spawn.
Authored spawn/patrol clearance is tested; use unscaled region parents (translation/
rotation are supported, nonuniformly scaled CharacterBody physics is not claimed).

Creature collision_layer=0 and mask=1: it collides with terrain, while the vessel
can pass through it. There is no contact callback into hull/resources, no blocking
player collider and no way for it to close a passage. A real vessel sweep test,
pillar detour test and newly inserted two-unit-wall test verify this behavior.

## Ownership, pause/restart and APIs

| Component | Public integration |
| --- | --- |
| CreatureProfile | Validated/copyable Resource, hearing Resource and event_priorities tuning |
| CreatureState | configure, offer(event,strength,distance,local_origin), advance(delta,position,blocked), destination, speed, snapshot, reset_session; state_changed |
| CreatureNavigation | build(profile,region), clear(point), segment_clear(from,to), route(from,to) |
| AcousticCreature | bind_bus, set_suspended, advance_simulation, reset_session; read-only brain diagnostics/receiver composition |

The submarine's set_simulation_enabled emits a signal used by the shelf to suspend
the creature immediately. Route, settings, map/research and debug controls freeze
motion, state time and receiver eligibility together; no render-time polling or
wall-clock timers are used. Pending pre-pause receipts retain simulation age.
Restart resets position, FSM/cooldown/pending/path state and clock, keeps the same
receiver identity and preserves the existing acoustic ledger. Old event IDs remain
rejected after restart. Research/discovery persistence and route telemetry retain
their previous independent contracts. Receiver tree exit cleans up through the
existing bus lifecycle; no additional singleton/listener ledger is needed.

Limits: no occlusion-based hearing, physical acoustic travel, continuous moving-
source interception, dynamic navigation baking, animation, creature saves or threat
behavior. Prototype polygon/caption are placeholder geometry. Native Windows/macOS,
physical-controller and hardware performance playtests remain manual; Linux GUT,
injected input and actual Godot/X11 rendering are the verified environment.
