# BTA-014: continental-shelf exploration graybox

The default scene now hosts a handcrafted, bounded region with the existing
submarine, resources, damage, input/settings and HUD. The original composition
is retained as `scenes/main/movement_prototype.tscn`; its movement cave, resource
profiles and domain APIs remain unchanged. Historical integration suites and the
HUD screenshot fixture explicitly load that fixture. The harness smoke and new
region suite exercise the new default. No prior assertion or test is removed.

The 4100×1800 authored scene has a western station basin, an upper cave passage,
a central rock shelf, an eastern twin-spire landmark and a lower return passage.
The two sides of the shelf form an interconnected loop. An upper overlook is an
optional alternative around a small pillar. A bounded optional pressure trench
branches below the eastern junction; it is never on the required route. Filled
rock/platform silhouettes are solid. Thin colored brackets/lines and signs are
navigation/depth markings, not walls. No final artwork is introduced.

`GrayboxRock` copies one inspector-editable authored polygon into Polygon2D and
CollisionPolygon2D, including in the editor. It does not generate the world.
Static terrain uses layer 1 / mask 2, the unchanged vessel uses layer 2 / mask 1,
and route test Areas use layer 3 / mask 2. The latter never block movement. Test
zones use the vessel center against their authored rectangle and transform;
these are test measurements, not station interactions or a discovery framework.

Depth is authored region-local Y with a water-surface marker at (0,0) and 0.25 m
per unit. The station spawn (420,480) is 120 m deep. The required course stays at
or above Y=970 (242.5 m), below the default 260 m caution threshold. The trench
has readable caution at Y=1040 and the 300 m limit at Y=1200. Existing hull
pressure/collision rules remain authoritative; the HUD reports live rating,
grace and damage. World signs reference the current prototype defaults. There
is no positional gate, upgrade or new survival rule.

The first launch opens a paused briefing. A test menu offers Begin/Resume,
Input settings and Restart, using existing keyboard/controller UI actions.
Pause/Escape/Start opens it anywhere; Escape/B/Start resumes. Input settings use
the existing menu/save/remapping contracts. Pauses stop the motor, resource
simulation, pressure clocks and route timer; the camera/presentation may update.
A full test restart resets the existing components through their configuration
APIs, clears damage/contact state and transient HUD feedback, moves to the
spawn, snaps the existing smooth camera to base, clears debug counters and
restarts the ephemeral route check. It retains saved input settings. This reset
is an explicit test-session action available anywhere, not repair/refill on
station entry, a checkpoint, game over or respawn system.

`GrayboxRouteCheck` is a tiny nonpersistent playtest counter: leave base, pass
through the twin-spire volume, then enter base. It has no inventory, rewards,
mission definitions, narrative, persistence or locks. It cannot complete merely
by starting in base or returning without the landmark. The active timer excludes
briefing/menus and freezes when complete. Completion leaves piloting available,
and returning to base does not replenish anything. This is acceptance telemetry,
not the later mission system.

Camera limits come from the authored region bounds; smoothing and motor tuning
are unchanged. The overlay uses the existing HUD and a compact read-only test
status panel above the resource deck so world landmark text remains readable.
The required route is swept with the full capsule plus clearance, then flown
through real InputMap actions in integration tests without moving or assigning
velocity. The measured full flight is about 42 seconds, with meaningful battery
and oxygen reserves and no damage. Manual novice route time and native device
performance remain playtest work, not a claim derived from headless tests.

No sonar, scan/interaction system, creature, mission, station service, upgrade,
narrative, region streaming or later-milestone art/audio system is implemented.
