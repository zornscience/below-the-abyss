# Combat test box — implementation and evidence

This branch adds a disposable combat and handling experiment. **Human playtest
results do not exist. Every tuning number is a hypothesis for the user's playtest.**
The automated routes establish rules and input behavior; they do not establish fun,
fairness for first-time players, market demand, or a preferred handling profile.

Base: current `origin/main` at `40de7164522548a204779dfaf250169f22370476`;
branch `testbox-combat`. Earlier contributors' commits are retained. Only the
explicitly requested test box is implemented. The draft briefs' recorded test-box
decision and the user's latest task authorize this experiment; broader campaign
combat and GDD revision remain proposals.

Read AGENTS.md, GDD.md, TDD.md, CODEX_PLAN.md and both combat briefs. The requested
`docs/market/market-review-2026-11-10.md` does not exist on this base, and the
proposal has no separately titled market-informed requirements section. A request
for that missing context was sent during implementation. The explicit handling
requirement in the task was followed; no missing market conclusions were invented.

## Acceptance mapping

| Requirement | Implementation and evidence |
| --- | --- |
| Separate disposable scene; export-only entry | `combat_box.tscn` / `CombatBox` creates an independent scene. Only the existing Playtest panel in an export with the `playtest` feature creates the developer entry button. Ordinary source/title UI has no entry. Release proof presses the real button and checks `current_scene`; source unit test checks absence. |
| Reuse vessel, controls, damage, weapons, sonar, bus, Stalker | Existing submarine scene, InputBindings/InputContext, SubmarineMotion, hull/resource systems, TorpedoLauncher, SonarEmitter, AcousticBus and RiftStalker. A small explicit-port setup on the launcher permits reuse without constructing/refactoring ShelfPrototype. Campaign setup delegates to those same ports; existing receiver setup and all rules stay intact. |
| Open arena, columns, two mouths, existing art | Resource-authored 3200 × 2000 arena, two columns and two cut-in passages; existing GrayboxRock, SunlitRockDressing shaders/textures and service-cradle art. Actual vessel capsule casts traverse both mouths in both directions. No asset or shader files added. |
| 3–5 swarmers; hearing, telegraph, bites, one-shot | Four `CombatSwarmer` instances use `SwarmerState` and `SwarmerProfile`. Only eligible sonar/explosion sounds engage them. A stationary direction line/ring and world caption precede every dash, with the existing HUD threat notice as a second text cue. Bites call the existing hull API once per dash. Actual projectile route kills one; minimum blast-edge damage also exceeds health. There are no reward/drop/progression services. |
| Normal ping with short stun | `SonarStun` listens only to an accepted existing ping; living, unpaused swarmers within 220 units and clear terrain sight are stunned for 2 s. Stalker is not in the typed target list. Normal battery/cooldown remain enforced by SonarEmitter. A stun pauses an active engagement; it does not erase the 12 s engagement window. Tests cover range boundary, duration, cooldown, pause and a subsequent live telegraph/bite. |
| Existing unkillable Stalker | Duplicate the existing Twilight profile and change only navigation territory/patrol points in the arena Resource. No BlastReceiver; existing damageable=false rule. Actual torpedo contact produces the existing scare/stun; sonar never does. |
| Two handling profiles, box only | WEIGHTY is the exact existing campaign Resource, not a copy. RESPONSIVE uses the same Resource type and pure velocity function. Developer buttons apply either Resource and display its name only in that panel. Pure 120 Hz and actual vessel/input 60 Hz runs confirm the table below. |
| Readable attacks, quiet play, hull-zero recovery | No proximity engagement while quiet. Swarmer telegraph and Stalker warning/pursue cues have visual and text equivalents. Small hull damage; zero hull pauses and returns the vessel to refit with full supplies/reset wave. Safe refit lies outside both AI territories. Controller disconnect releases actions and opens options. |
| Calm effects, keyboard/gamepad, limited HUD | Reduced flashing forced in box memory only, existing reduced ping/blast/visual paths; no camera shake. Loaded preferences and input bindings are reused. Only existing hull/battery gauges plus transient notices remain visible. Native screenshots and real InputEventKey/Joypad routes cover both sizes/devices. |
| Local opt-in measurement | `CombatBoxObserver` extends the existing observer and uses its recorder/store. Default reports remain strict version 1; explicitly opted-in box sessions use strict local report version 2 and fixed CombatMetrics fields. Recording starts OFF, switching scenes does not transfer consent. Tests exercise JSON round-trip, event-cap aggregates, fixed rating and disk readback. No network, free text, raw inputs or identity collection. |
| Campaign isolation | No story, research, missions, save coordinator, map, pickups or progression constructed. No campaign Resource, ShelfPrototype, save schema or GDD changes. Save schema remains 10 with twelve top-level fields. Existing tests/routes remain unchanged. |
| Release safety | No setup side effects in assert(). ReleaseSmoke creates a persistent proof that follows the real scene transition, checks both acoustic registrations, accepted-ping stun, then responsive and weighty selection. Six independently disconnected combat cases plus all thirteen prior negatives must fail with their specific token on the real package. CI runs the new route and all negatives. |

## Tuning hypotheses

Distances are world pixels; rates use simulation seconds. Arena-specific authored
positions, course and probes live in `resources/playtesting/combat_arena.tres`.
Tests derive destinations, boundaries and expected costs from Resources rather
than embedding level coordinates. Defaults on SwarmerProfile are also exported
Resource properties and may be overridden in `swarmer.tres`.

| Item | Value | Reason / consequence |
| --- | --- | --- |
| Swarmer count | 4 | Within requested 3–5; enough for a swarm without continuous crowding. |
| Quiet speed | 0 | Quiet proximity alone must never trigger attack. |
| Investigate / dash speed | 140 / 280 units/s | Investigation is slower than the vessel; a brief dash is faster than its 240 top speed. |
| Dash eligibility range | 350 units | Starts the readable telegraph while the player can still react. |
| Telegraph / dash / cooldown | 0.9 / 1 / 2 s | Deliberate warning, short locked-direction attack, recovery window. No retarget during telegraph/dash. |
| Sound engagement memory | 12 s | One sound creates a bounded episode; a stun does not permanently pacify it. |
| Hearing | sonar + explosion only; range 1000; minimum strength 0.2 | Pings/blasts have consequences; quiet thrust does not. Existing ping emission range is 900, so hearing is also limited by that event's range and existing attenuation/terrain reception. |
| Bite | 4 hull; range 42; once per dash; clear terrain sight | Small actual API damage, no contact spam or through-rock bite. Full hull is 100. |
| Health / collision radius | 12 / 18 units | Small existing creature silhouette. Existing blast minimum edge damage is 60 × 0.25 = 15, so even the accepted edge hit kills it. |
| Navigation | 100-unit grid; territory Rect(650,100,2300,1700) | Cheap existing pathfinding, refit excluded. Spawn points are individually assigned as Resource patrol anchors. |
| Inherited navigation defaults | arrival 12; unreachable 1.5 s; sound memory 2 s; recovery 2 s | Existing navigator defaults, not new attack timers. Exported patrol 35 and return 70 are unused because the new model is stationary in quiet and has no return phase. |
| Sonar stun | 220 units inclusive; 2 s; clear path required | Short defensive window, not a map-wide silence. One accepted ping can affect several swarmers. |
| Refit | radius 150 around authored cradle | Reuse Interact; restores supplies and wave only here or after hull-zero recovery. |
| Arena | 3200 × 2000; border 60; columns 180 × 450 and 200 × 450; mouths 220 × 320 and 240 × 330 | Space for handling/course/chase and two reversible shelter entrances. Geometry is authored independently of campaign terrain. |

All Stalker combat/hearing numbers remain those of
`resources/creatures/twilight_stalker.tres`; the arena copy changes only its
territory to Rect(800,180,2200,1500) and two patrol anchors. The refit sits outside.

| Existing Stalker values retained | Hypothesis / purpose of reuse |
| --- | --- |
| Patrol 40, investigate 110, return 130, pursue 170, flee 190 units/s | Preserve BTA-060 movement and escape relationship; player top speed stays 240. |
| Hearing 1800, minimum strength 0.2, sonar/explosion; passive strength 1, range 1600, interval 3 s | Preserve sound hunting and existing passive emissions. |
| Sense 450, target distance 700, pursuit distance 900 | Preserve finite acquisition and pursuit. |
| Warning 2.5 s, pursuit 6 s, investigation 18 s, recovery 4 s | Preserve existing readable warning and bounded hunt. |
| Contact 5 hull, radius 50, cooldown 3 s | Preserve small repeated contact damage through existing API. |
| Scare radius 240, stun 1.5 s, flee 5 s | A torpedo buys escape; never a kill. |
| Body radius 24, navigation grid 90, target replan 0.25 s | Preserve existing Stalker navigation. |

The box explicitly selects the **existing Twilight** resource/action profiles;
this is a scene composition choice, independent of a campaign chapter journey.
No profile is mutated. Oxygen still simulates in the reused vessel but is not an
arena HUD element and has no new arena failure rule; refit restores it.

| Existing supplies / actions | Arithmetic / implication |
| --- | --- |
| Hull, battery, oxygen capacities | 100 each, unchanged. |
| Ping 5 battery, 4 s cooldown | 100 / 5 = 20 theoretical pings before travel costs. Stun adds no cost or cooldown. |
| Torpedo 5 battery, 1.2 s cooldown, 10 ammunition | 100 / 5 = 20 battery-funded shots, but only 10 carried before refit. |
| Torpedo blast radius 150, damage 60; powered cruise 1100, acceleration 500, launch 80, lifetime 5 s | Existing modern torpedo mechanics, unchanged; unpowered profile values remain speed 800/lifetime 3 s. |
| Battery idle 0.003/s, thrust 0.009/s additional | Idle: 100/0.003 = 33,333.33 s = 555.56 min. Continuous thrust: 100/(0.003+0.009) = 8,333.33 s = 138.89 min. Slow passive drain remains unchanged. |
| Oxygen 0.02/s | 100/0.02 = 5,000 s = 83.33 min. Observation, not retuned. |
| Battery insufficient | Existing ping/torpedo requests reject without producing the action; thrust remains available. The arena adds no battery movement gate. |

### Handling arithmetic and actual-input confirmation

The existing hull points horizontally; “180 degree turn” here means **reversing
velocity from +top speed to 90% of -top speed**, not a rotating submarine sprite.
The visible facing flips earlier, when reverse horizontal velocity exceeds 12.
Both profiles retain identical top speed. Lower drag means longer coasting;
RESPONSIVE's greater braking/reverse acceleration is the intended responsiveness
experiment, not a claim of shorter hands-off stopping distance.

| Metric | WEIGHTY | RESPONSIVE |
| --- | --- | --- |
| Resource | exact `expedition_motion.tres` | `playtesting/responsive_motion.tres` |
| Acceleration A | 120 | 480 units/s² |
| Top speed V | 240 | 240 units/s |
| Damping d | 1.2 | 0.9 per second |
| Rest → 90% top, 0.9V/A | 1.800 s | 0.450 s |
| 180° reverse → 90% reverse, 1.9V/A | 3.800 s | 0.950 s |
| Facing threshold, (V+12)/A | 2.100 s | 0.525 s |
| Hands-off stop time, ln(V/0.5)/d | 5.145 s | 6.860 s |
| Continuous coast to existing 0.5 snap, (V−0.5)/d | 199.583 units | 266.111 units |
| Pure movement calculation at 120 Hz: coast | 198.586 units | 265.115 units |
| Actual vessel/input at 60 Hz: coast | 197.588 units | 264.116 units |
| Actual keyboard AND controller: facing flips | 2.117 s | 0.533 s |
| Actual keyboard AND controller: to90 / reverse90 / top | 1.800 s / 3.800 s / 240 | 0.450 s / 0.950 s / 240 |

Facing flips on the first frame strictly past the existing −12-unit threshold;
its small rounding difference also comes from the 60 Hz step. The coast difference
is expected discrete integration: the controller applies
decayed velocity before moving each frame. New tests bound this difference by
one frame's travel and keep time tolerance to a fixed step. Existing assertions
and timeouts were not weakened. Actual-input measurements use physical key and
joypad events through InputBindings and the vessel physics controller. Measurement
start placement and course targets are authored Resource data. These are automated
input events, not physical gamepad hardware or human handling judgments.

## Verification, screenshots and manual play

[Exact commands and results](VALIDATION.md), [changed files](changed-files.txt),
[three-person facilitator sheet](FACILITATOR.md) and [ready PR body](PR.md).
[Branch publication and PR API blocker](PR_STATUS.md).

| Native capture | 1280 × 800 | 800 × 600 |
| --- | --- | --- |
| Arena and two mouths | [PNG](screenshots/arena-1280x800.png) | [PNG](screenshots/arena-800x600.png) |
| Dash telegraph | [PNG](screenshots/dash-telegraph-1280x800.png) | [PNG](screenshots/dash-telegraph-800x600.png) |
| Sonar stun | [PNG](screenshots/sonar-stun-1280x800.png) | [PNG](screenshots/sonar-stun-800x600.png) |
| Visible Stalker chase | [PNG](screenshots/stalker-chase-1280x800.png) | [PNG](screenshots/stalker-chase-800x600.png) |
| Developer panel | [PNG](screenshots/developer-options-1280x800.png) | [PNG](screenshots/developer-options-800x600.png) |

These are native Godot viewport PNGs at the named sizes, not resized or composited.
The arena overview temporarily zooms the camera in the capture fixture only; all
other images use the normal arena camera. Capture runs are muted. At 800 × 600,
edge-adjacent world captions can clip, while the full on-screen threat notice
provides the text equivalent; developer controls scroll with focus.

### Keyboard route

1. Run the Linux playtest export. Use the existing Playtest / local reports option,
   then Developer / Open combat test box. Entry pauses in developer options;
   recording is OFF. Resume without recording and verify no report is created.
2. Pause with P/Escape, optionally consent to local combat recording. Select
   WEIGHTY, Resume. Use WASD/arrows to circle both columns and enter/exit both
   tunnel mouths. Coast, brake with opposite thrust and reverse; note overshoot.
3. Return to the visible cradle, E to refit. Pause and select RESPONSIVE. Repeat
   the same maneuvers; only the panel shows the active profile name.
4. Approach a small creature. Stay quiet first: it must not engage just because
   you are nearby. Face it and use F inside the short range: observe STUN text and
   a static ring. Wait for the stun to expire and its direction-line/TELEGRAPH;
   evade the dash. Fire Space while facing a swarmer: one hit kills it, no pickup.
5. Ping farther toward the hunter. Observe the existing WARNING then PURSUE text
   and visible creature. F does not stun it. Fire a torpedo near it to see STUN /
   FLEE without a kill; run back past the columns toward the refit. Quiet escape
   is possible. Refit supplies and wave with E.
6. As a separate destructive check, allow repeated telegraphed hits until hull
   zero: return to cradle, full hull/ammo, paused developer panel. Resume works.
   Choose Finish / [handling rating] to stop/export if recording was enabled.
   Return to campaign title; verify campaign Continue still restores its own save.

### Gamepad route

Repeat that route with left stick/D-pad movement, X ping, right trigger or
right-stick click torpedo, A Interact, Start pause, D-pad/stick/shoulder focus,
A select and B back. Confirm both handling buttons and the lower rating controls
are reachable by scrolling focus at 800 × 600. Disconnect during held movement:
actions release and options open; keyboard recovery remains available. Run muted
and check each attack's text/shape cue. This is a manual protocol, not a claim
that a person or physical controller completed it.

## Known limitations

- No human playtest results exist; all combat and handling tuning is provisional.
  The scripted `about_right` choice tests storage only and is not feedback.
- Requested market-review context was absent at the base revision. Broader combat
  proposals, monetization and campaign changes are not conclusions of this work.
- Native verification used Linux X11, Mesa llvmpipe and synthetic controller
  events, not physical controller hardware, Steam Deck, Windows or macOS. V-sync
  is unsupported by that display; no performance target is certified.
- Accelerated native fixture teardown initially reported six audio loop resources
  still held by the existing mix thread. A fixture-only 50 ms shutdown handoff
  now allows that thread to release them; both final native runs are clean. The
  earlier keyboard log is retained. Gameplay timing and existing timeouts are unchanged.
- Captions can overlap in a close swarm and world-edge text can clip; existing
  on-screen notices provide readable equivalents. Fairness under real simultaneous
  attacks still needs the three-person test, especially with WEIGHTY handling.
- The arena is disposable: no save/continue, story, drops, persistent profile or
  campaign upgrades. The local report version 2 is intentionally separate from
  campaign completion analysis. Forced termination can lose the latest checkpoint
  interval, as in the existing telemetry contract.
- Reports use wall time; accelerated automated route timestamps do not estimate
  ten-minute participant pacing. Use a facilitator stopwatch for comparison.

Review only. Do not merge or request merge until this PR's own CI is green.
