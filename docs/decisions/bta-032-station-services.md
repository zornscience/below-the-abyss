# BTA-032: explicit station services

## Contract and balancing

`ServiceStation` is a reusable scene-owned Node2D configured with a validated
`StationProfile` Resource. The shelf base is at world `(420, 480)`. Its inclusive
interaction radius is 140 world units (35 authored meters); maximum docking speed
is 40 units/second. The station adds no collision walls and changes no route geometry.

`can_interact(vessel)` is a read-only eligibility query. `interact(vessel)` opens a
weakly held session and returns an Error; it does not pause or change any resources.
The scene coordinator stops vessel velocity, pauses the existing simulation and
presents the menu only after success. `end_interaction()` closes the session.
`quote(hull|battery|oxygen|all)` returns Error/reason, FREE cost, before/after values
and transfer amounts. It revalidates the live vessel, range, speed, availability and
vessel physics pause. `perform(...)` revalidates instead of trusting an earlier
quote, then calls only `SubmarineHullSystem.restore_hull`,
`SubmarineResourceSystem.restore_battery` and `restore_oxygen`, in that order.
`service_applied(result)` reports actual values. Existing domain signals update the
HUD. No configure/reset API is used. A busy guard rejects reentrant service and
session-closing callbacks. Deleted vessels, unknown services, offline stations,
out-of-range vessels and unavailable transfers fail without mutation.

Prototype services are explicitly FREE, with unlimited supply and no currency,
stock, inventory or persistent economy. Each activation is capped independently by
three configurable finite nonnegative limits (default 100 each), then clamped to
existing domain maxima. Zero disables a service. Already-full services are unavailable.
This makes a complete expedition sustainable without introducing progression or
balancing an economy ahead of BTA-034. Simply entering or crossing the base, opening
the menu and reading a notice never repairs or refills anything.

## Input, pause and lifetime

In normal piloting, existing remappable Interact (default E / controller A) chooses
the station whenever inside its radius. A too-fast/offline station attempt is
consumed with a readable reason, never accidentally starting a nearby scan. Outside
the radius the existing scientific scanner retains Interact. Development mode keeps
its pre-existing Interact resource tools; switch it off to operate station services.

The station menu uses existing keyboard/controller UI actions, skips disabled
buttons, starts focused on Return to piloting, and supports Escape/B/Start. Back
from notices returns to services; back from services undocks. Existing simulation
pause coordination freezes resource consumption, pressure, sonar clocks/expiry,
scanner, creatures and route telemetry while the menu is open. The UI continues
processing. There is no tree-wide pause or new singleton. The model assumes the
existing scene-owned coordinator controls simulation; it also checks the vessel's
physics-processing flag before a transfer.

Legitimate services preserve position, route stage/time, actor state, acoustic
IDs/history, sonar cooldown, discoveries and research records. Restart Test Route
remains a separate development reset: it closes any station session and runs the
existing reset semantics, including prototype resource restoration, while retaining
permanent discoveries/research. Undocking is not a restart.

## Informational board and limits

`StationNotice` contains only validated stable ID, title and description. Profiles
accept at most 16 unique notices; snapshots are copied. The board only displays
these authored texts. It has no acceptance, objectives, rewards, completion events
or saved mission state. Two shelf notices demonstrate the foundation.

There is one station and one-vessel session per station. No docking animation,
autopilot, stock/currency economy, upgrade system, mission progression or general
save format is introduced. Limits are per activation, not a scarcity simulation.
