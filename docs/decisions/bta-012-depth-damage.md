# BTA-012 depth and damage decisions

## Authored depth frame

DepthRegion owns a DepthMapping Resource and converts world coordinates to the
region's local frame first. Positive local Y points deeper. The mapping is
max(0, (local_y - water_surface_local_y) × meters_per_unit), sampled at the
submarine center. This avoids assigning depth from an arbitrary global Y value.

The prototype's water-surface reference is local Y=0, represented explicitly by
WaterSurfaceReference and the mapping Resource. Scale is 0.25 m/authored unit.
The reference plane extends behind the closed test cave ceiling; reaching an
open ocean surface is not part of this fixture. A different authored region can
set a negative surface-reference Y to represent a deeper entry without relying
on its global placement. Region translation/rotation/scale are handled by
to_local; depth is along that authored local Y axis. Invalid coordinates/mappings
and singular or near-singular transforms do not produce a valid depth sample.

## Effective operating limit

The profile's safe_operating_depth_m is the base rating (300 m). The damage
component's get_maximum_depth_m / set_maximum_depth_m interface exposes the
effective safe operating rating. These are not separate safe/death thresholds.
Traversal is allowed beyond the rating, with exposure-based pressure damage.

A future equipment adapter can set a new rating without changing mapping,
movement or hull code. This issue adds no inventory, purchase, unlock, upgrade
selection or persistence. A changed rating starts a new grace assessment;
reapplying the identical value does not reset grace. The authored Resource is
not mutated. Warning margin must remain below the effective rating.

## Warning and pressure policy

Default warnings are SAFE below 260 m, CAUTION from 260 through 300 m inclusive,
and DANGER strictly beyond 300 m. The warning state signal emits only on a state
transition; UI text also includes numerical depth/rating and an ascent instruction.
Color supplements text without flashing or an audio dependency.

Continuous unsafe exposure has a two-second grace period, followed by a constant
four hull units per simulation second. A step that crosses the grace boundary
charges only its damaging fraction. Returning to or above the safe boundary
(depth <= rating) restores grace; merely changing menus does not. There is no
instant death/crush event or depth-scaled damage multiplier. The constant rate
keeps exposure understandable and bounded for this prototype.

## Collision policy

The motor reports relative inward normal approach speed, not total speed:
max(0, -(attempted_velocity - collider_velocity) dot contact_normal).
Tangential motion and acceleration while already blocked therefore do not count
as severe impacts.

Only speeds strictly above 150 px/s qualify. Damage is min(20, (speed - 150) ×
0.1), then capped by remaining hull through SubmarineHullSystem.apply_damage.
Each swept physics step aggregates its maximum approach speed into one
observation. A global 0.75-second cooldown and one qualifying hit per continuous
contact episode suppress corner bursts and repeated contact damage. An episode
ends when a physics step has no collision. A qualifying contact suppressed during
cooldown is consumed, not queued for a later hit while contact continues.

The episode latch is deliberately global across contacts. This conservative
prototype policy needs no collider identity, save ID or per-collider history.
Pressure and collision use stable source labels, pressure and collision.

## Simulation ownership and scope

The existing motor advances the damage component once per physics tick after
movement/depth sampling. Pressure, grace and cooldown clocks stop with the motor
during settings and resource test controls. Battery/oxygen logic and the hull
API remain unchanged. No view directly mutates hull.

The submarine prefab can be used in isolated collision fixtures without a
DepthRegion; it samples zero depth there and does not infer pressure from global
Y. A level must bind its authored region to enable world depth; the prototype
does so before its first tick.

Hull loss is bounded and emits existing notifications, including vessel_destroyed
on emptying. There is no game over, respawn, movement shutdown, sonar, creature,
mission, upgrade gameplay or production HUD in BTA-012.
