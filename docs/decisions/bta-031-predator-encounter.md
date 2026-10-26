# BTA-031: optional acoustic predator encounter

One signed predator pocket sits above the continental-shelf east chamber, separate
from BTA-030's harmless overlook observer. The required exploration/scanning routes
remain unchanged and can bypass the encounter. No combat, weapons, missions,
services, upgrades, species pipeline, creature persistence or general saves are added.

## Reuse and ownership

PredatorProfile extends CreatureProfile; PredatorState extends CreatureState;
PredatorCreature extends AcousticCreature. The original patrol/return logic,
acoustic arbitration/validation, navigation graph, 1/120 internal simulation step,
move_and_collide motion, bounds and receiver lifecycle remain in BTA-030. Two
no-op pre/post-step hooks and an overridable arrival predicate support the threat
extension; ordinary harmless actors retain their original behavior. No movement,
pathfinder, dispatcher or acoustic-history implementation is duplicated.

The scene root injects the existing submarine as a weak target and the existing
AcousticBus. Stable receiver ID is creature/shelf-predator; default trigger source
is neris-01/sonar. The existing enabled/type/classification/range/strength filters
still apply. The default profile accepts active_sonar, range 500, strength ≥0.2.
The sampled source origin must also lie inside the actor's permitted center bounds.
Pings on the main passage therefore remain safe even when heard by the endpoint.
No passive-listening action or scan publishes a lure, and the predator emits no
sound event. It tracks the injected vessel only after an eligible acoustic trigger.

The inherited pending-best slot gives deterministic type/strength/timestamp/source/
event-ID ordering before an episode. Once warning begins, further sounds cannot
restart its warning, retarget or extend its pursuit. The inherited current-ID guard
rejects duplicate reactions; the unchanged bus remains the lifetime deduplication
and conflicting-payload authority. No extra event ledger, ID mutation, history
reset or eviction is introduced. Old accepted events stay rejected after restart.

## Warning, pursuit, disengagement

| Threat phase | Underlying BTA-030 state | Behavior |
| --- | --- | --- |
| QUIET | PATROL | Optional patrol; no automatic proximity attack |
| ALERT | INVESTIGATE | Approach the heard origin at 40 units/s; visible 2.5s warning, no damage |
| PURSUE | INVESTIGATE | Track the vessel at 90 units/s, for at most 6s |
| DISENGAGE | RETURN/PATROL | Stop damage, ignore sounds, return to nearest patrol point and recover |

The warning and pursuit deadlines derive from the accepted event's simulation
timestamp. Repeated events cannot extend them. Arrival at the sound does not skip
the warning; even a ping directly overlapping the creature must serve the complete
warning before damage becomes possible. The inherited investigation cap (10.5s)
bounds the whole episode. Profile validation requires at least a one-second warning,
nonnegative damage ≤10, cooldown ≥1s and an investigation cap covering warning+pursuit.

Pursuit stops immediately when the player leaves the center bounds, moves more
than 180 units from the original ping origin, exceeds 220 units from the predator,
is removed, the pursuit deadline expires, or the inherited blocked-path timeout
fires. There is no chase beyond the habitat, teleport or pursuit through walls.
Return uses the inherited nearest-point and blocked-waypoint fallback, followed
by the inherited four-second recovery gate. Dynamic target destinations are
sampled at most every 0.25 simulation seconds for path planning; escape/limit
checks still run every fixed step. Default submarine maximum speed is 240 units/s,
well above pursuit speed, and the nearby downward exit needs no combat or equipment.

## Optional area and safe retreat

The habitat is Rect2(3000,300,330,145), with a 16-unit body radius. Permitted centers
are its inset rectangle, ending at Y=429. The non-solid entry line is at Y=430;
the signed retreat cue is past 115m (Y=460 under the existing 0.25m/unit mapping).
The original upper passage at Y≈480/120m is outside trigger/pursuit bounds. Required
spire navigation and scientific targets need not enter the pocket. The harmless
observer remains in its separate X=1380–2000 habitat.

Patrol positions (3200,350), (3280,360), (3240,400) use the existing bounded
CreatureNavigation graph and swept motion. No terrain geometry was changed.
Both actors have collision_layer=0, mask=1: terrain collision remains, but neither
can push, block or trap the vessel. The open downward retreat joins the original
passage; signs and HUD describe depth in meters rather than requiring engine Y
coordinates. The current authored cue is tested against DepthRegion. Changing
mapping/territory requires reauthoring the configurable retreat_hint accordingly.

## Modest contact damage

Only PURSUE can request contact damage. The adapter checks ≤40 units of proximity
and an unobstructed swept-circle segment, then calls the existing
SubmarineHullSystem.apply_damage(amount, shelf-predator/contact). This proximity
proxy avoids a player-blocking physical collider. No damage occurs during warning,
quiet, disengagement, pause, through terrain, or after a target is removed.

The state model latches its next allowed damage time before callbacks. Default
cost is 5 hull and cooldown 3 simulation seconds: a six-second episode permits at
most two hits/10 hull. Repeated substeps, contact jitter and duplicate sounds cannot
cause extra hits. HullSystem retains clamping/depletion behavior; tests cover
remaining hull below the configured cost. Actual applied damage drives a brief
HUD feedback signal. Leaving the area disables further damage even if still near
the body. No knockback, weapons, game-over or respawn system is implemented; existing
prototype movement/restart behavior at zero hull remains unchanged.

## HUD, pause and restart

A read-only, weakly bound ThreatIndicator uses the existing HUD theme and reserves
a small area below depth instruments, above the protected central view. Text uses
PREDATOR / WARNING with countdown, PURSUIT with remaining time, contact feedback,
SAFE / DISENGAGING and SAFE / MAIN PASSAGE. The retreat hint is visible during
warning/pursuit. Text, exclamation mark and world outline provide non-color cues;
there is no flashing or new input. Font/layout/focus tests cover 1280×800, 800×600
and 1920×1080. Warnings remain distinct from the existing safe-depth instrument.

Existing simulation_enabled_changed wiring suspends the predator immediately
alongside the harmless actor for route/settings/map/research/debug pauses. Motion,
warning, pursuit and contact cooldown freeze together; receiver eligibility is
disabled. Restart resets aggression, cooldown, path and spawn with the same receiver
identity. Existing bus history, research/discovery files and route reset contracts
remain independent. A new warning must precede any post-restart aggression.

Limits: sampled vessel position and distance-based pursuit, not a general vision or
species AI system; inherited static navigation with collision-safe fallback for
later obstacles; no physical sound propagation/occlusion-based hearing, animation,
combat or persistent predator state. Use unscaled region parents as in BTA-030.
Graphical evidence is an agent-driven Godot keyboard/controller playthrough, not
an independent human usability study. External human understandability validation,
physical-controller hardware, native Windows/macOS and target performance remain
manual follow-up verification; no such certification is claimed.
