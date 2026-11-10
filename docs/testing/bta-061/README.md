# BTA-061 — Twilight tunnels and optional torpedo shortcuts

Base: current `main`, `ee38c74` (includes BTA-058/059/060 and the corrected brief).
Branch: `bta-061-tunnels`. One issue; no merge.

**Human playtest results do not exist. Every number is a hypothesis for the user's
playtest. Automated pilots and native captures do not establish player acceptance.**

## Acceptance mapping

| Requirement | Implementation and evidence |
| --- | --- |
| 1. Data drives geometry and tests | `resources/world/twilight_{west,east}_tunnel.tres` hold local outer polygons, centrelines, widths, branch, squeeze, shortcut, gate ID/bounds, payoff and shelf approach/return paths. `TwilightTunnelCatalog` compiles them into `TwilightShelfLayout`; tests and both-device pilots consume the same Resources. Two existing rock masses are replaced; other original outlines retain their seeds. Subtraction uses local-space `rough_contour`, then unions construction seams into three simple rock polygons per system. Existing art and shaders only. |
| 2. Two exploration spaces | Each has two open shelf connections, a winding bypass, a squeeze, a branching blind recess with optional study, and a closed shortcut. Actual collider sweep tests cover the whole authored graph, not selected point coordinates. The real-input route passes both squeezes and reverses out of both dead ends without collision damage during those careful traversals. Full-thrust dead-end approaches apply existing impact damage. |
| 3. Established risk | The west descent intersects a normal `ThermalVent`. Existing quiet/warning/eruption/cooling, terrain occlusion, text prompt, damage feedback and accessibility preferences are unchanged. The same chimney atlas cell is reused. New vent participates in the existing context and save-safety checks. No random damage rule or instant-kill rule is added. Existing BTA-059 hull-zero flow remains authoritative; collider tests verify the tether through every tunnel vent phase with gates closed and after repeated cuts. |
| 4. Optional gates | `TwilightTunnels` registers both `DestructibleRock` instances with plain statements outside assertions. Geometry supplies hardness; two baseline radius-150 torpedoes open each actual hull passage. Real gate detonations test the existing acoustic receiver, including one heard gate and one unheard gate. |
| 5. Return always possible | Capsule casts verify approach, main path, branch and shelf return, plus reverse edges at the shared cut cap. Shortcut is blocked before excavation and clear after two shots. Every repeated cut decreases or preserves rock area and leaves every authored return edge clear. The existing outer and inner shelf loops still pass their original tests. |
| 6. Existing persistence | Extend the existing terrain validator only for the two authored stable gate IDs, with bounded Twilight coordinates. Old IDs retain the exact old bounds. Both regions' rocks are registered before Continue; inactive gates have collision disabled, never their geometry reset. Continue replays the same journal, and transfers preserve cuts in both directions and actual supplies. Test asserts schema 10 and twelve top-level fields. No persisted field added. |
| 7. Optional payoffs | Two geological studies compose with the original 17 records via `all_records()`. Existing scanner, discovery, research, journal and discovered-point map presentation are used. Both new IDs are absent from both XP study lists; completion adds **zero XP / zero points**, changes no caps or allowance arithmetic, and is absent from all mission objectives. New echoes use the existing clear-path option, so rock blocks premature outside discovery. Their existing scan-result radio path accepts the Resource's IDs; both messages are tested at the radio. |
| 8. Scope and release | Twilight chapter selection enables the new walls/gates/vent. Sunlit geometry and legacy fixtures are unchanged. No cost Resource, Stalker profile, depth rule, research rule, lighting setting, asset, map terrain, HUD element or permanent HUD text changed. No new tutorial card. ReleaseSmoke verifies geometry/visibility, gate registration and vent registration with three corresponding negative cases, alongside all older export proofs. |

The gate test exposed one prerequisite bug: `TorpedoLauncher.configure_capabilities`
rebuilt its profile from the Shallows default, undoing Twilight's selected five-battery
cost when upgrades were reapplied during Continue/transfer. It now preserves the
currently selected cost. Values are unchanged: Sunlit 2, Twilight 5. Existing regional
cost tests gained assertions after reapplication and Continue; none were relaxed.

## Vessel measurement and authored tuning

The scene's capsule has `height = 64`, `radius = 16`, and its CollisionShape2D is rotated
90 degrees: **64 units horizontal × 32 vertical**, fixed horizontal orientation.
Widths below use the conservative **64-unit maximum span**, including horizontal halls.
Squeezes run vertically, so their cross-passage hull span really is 64. Tests cast that
actual shape with its local transform, excluding only the vessel's own RID.

| Tunnel | Normal passage | Squeeze | Branch / dead end | Optional payoff |
| --- | --- | --- | --- | --- |
| Western lower loop | Authored 192 = 3.00× vessel; measured normal probe 193.96 = 3.03× | Authored 124 = 1.9375×; measured narrowest central probe 125.08 = 1.95×; 290-unit authored segment | 300-unit blind recess off return leg; reverse to its junction | `twilight-tunnel-layers` / Tunnel layers; 0 XP |
| Eastern ballast loop | Authored 192 = 3.00×; measured normal probe 197.03 = 3.08× | Authored 124 = 1.9375×; measured narrowest central probe 115.32 = 1.80×; 320-unit authored segment | 200-unit blind recess off outer leg; reverse to junction | `twilight-tunnel-grains` / Sheltered grains; 0 XP |

Measurements are physics raycasts across the generated contours at the Resource's normal
probe and five central squeeze fractions. End caps overlap adjacent normal passages;
segment length is not a promise of uniformly narrow width. The full capsule sweep
additionally checks bends, end caps and dead ends.

| Gate | Authored world bounds | Baseline shots / battery | Stalker hearing | Long route / shortcut between the same junctions |
| --- | --- | --- | --- | --- |
| `twilight-west-shortcut` | `(30950,3380)`, size `280×200` | **2 × 5 = 10** | Outside: nearest territory-centre-envelope distance from gate bounds is 2094.70 > 1800 | **1940 / 1200** units; saves 740 (38.1%) |
| `twilight-east-shortcut` | `(34420,2200)`, size `280×200` | **2 × 5 = 10** | Inside: farthest gate-bound corner to territory-centre-envelope corner is 1777.99 < 1800 | **1500 / 700** units; saves 800 (53.3%) |

Lengths exclude the common approach and exit legs. Full main paths are 2940 and 1800
units; side branches are additional out-and-back trips. Hearing uses the unchanged
1800-unit explosion emission and receiver range, strength filter, bus and territory.
The bus currently has no attenuation. Real fired shots additionally verify delivery:
western shot leaves the hunter quiet; eastern shot starts investigation. Its goal stays
inside its existing territory; this does not promise it can pursue through tunnel rock.

Both shortcuts avoid their winding squeeze; the western shortcut also avoids the rising
jet. Their value includes repeat travel and avoiding that exposure, not just distance.

Hardness is the **280-unit rough plug thickness versus 150-unit blast radius**, with no
HP pool or hidden shot counter. Torpedoes hit successive remaining faces; one shot is
insufficient, two clear the real capsule corridor. Both gates together cost **4 rounds,
20 of 100 battery**, leaving 80 before pings and travel. Off-centre/missed shots may cost
more. All action-cost Resources and blast upgrades are untouched. Pings still cost 5;
passive travel remains slow, and zero battery still permits thrust on every bypass.

The vent is `twilight-tunnel-vent` at the west Resource's local `vent_at`, just below the
lower bend. Its jet overlaps the latter part of the squeeze. Wait at the upper mouth,
outside exposure, through the existing countdown; take the next quiet window. It uses
8 s quiet + 4 s warning + 3 s eruption + 5 s cooling = **20 s cycle**, **4 hull/s** during
exposure (at most 12 for a whole eruption), and existing terrain-occlusion rules.
Stopping inside the jet can still cost hull. Waiting and braking are deliberate choices.

## Journal, limits and visibility

Both gates share the existing **256 cut-record cap** with all Sunlit excavation. One blast
can consume a record per rock it changes; here gates are separated and one shot changes
one gate. At the limit `excavate` returns zero without changing geometry or the journal;
the fired torpedo still uses its ordinary ammunition and battery. An incomplete gate
stays blocked and the winding route remains available. A 257-record restore is rejected
without replacing the valid journal. Repeating cuts cannot add rock; the return graph is
checked after each edit and with a full journal and both gates closed.

The existing visibility shader and settings are unchanged. Contours rebuild on the
existing `geometry_changed` signal, so an excavated gate does not leave a closed visual
outline behind. Original static rock contours plus every new gate/chimney contour are
included. Construction seams are joined before rendering, rather than drawn as false
passage boundaries. The map still presents discovered numbered subjects, never terrain.

## Native images and scripted evidence

[Command/results and export matrix](validation.md). [Changed files](changed-files.txt).
Native images are original Godot OpenGL captures at **1280×800** (keyboard) and **800×600**
(gamepad events), not resized composites. `-small` denotes native 800×600. Both runs use
standard darkness, default HUD scale, reduced motion/flashing/particles and muted audio.
The transient vent text remains readable without audio or colour discrimination.

| View | 1280×800 | 800×600 |
| --- | --- | --- |
| West tunnel entrance | [image](screenshots/tunnels-twilight-west-tunnel-entrance.png) | [image](screenshots/tunnels-twilight-west-tunnel-entrance-small.png) |
| West squeeze | [image](screenshots/tunnels-twilight-west-tunnel-squeeze.png) | [image](screenshots/tunnels-twilight-west-tunnel-squeeze-small.png) |
| West payoff / dead end | [image](screenshots/tunnels-twilight-west-tunnel-dead-end.png) | [image](screenshots/tunnels-twilight-west-tunnel-dead-end-small.png) |
| West gate before | [image](screenshots/tunnels-twilight-west-tunnel-gate-before.png) | [image](screenshots/tunnels-twilight-west-tunnel-gate-before-small.png) |
| West gate after | [image](screenshots/tunnels-twilight-west-tunnel-gate-after.png) | [image](screenshots/tunnels-twilight-west-tunnel-gate-after-small.png) |
| East tunnel entrance | [image](screenshots/tunnels-twilight-east-tunnel-entrance.png) | [image](screenshots/tunnels-twilight-east-tunnel-entrance-small.png) |
| East squeeze | [image](screenshots/tunnels-twilight-east-tunnel-squeeze.png) | [image](screenshots/tunnels-twilight-east-tunnel-squeeze-small.png) |
| East payoff / dead end | [image](screenshots/tunnels-twilight-east-tunnel-dead-end.png) | [image](screenshots/tunnels-twilight-east-tunnel-dead-end-small.png) |
| East gate before | [image](screenshots/tunnels-twilight-east-tunnel-gate-before.png) | [image](screenshots/tunnels-twilight-east-tunnel-gate-before-small.png) |
| East gate after | [image](screenshots/tunnels-twilight-east-tunnel-gate-after.png) | [image](screenshots/tunnels-twilight-east-tunnel-gate-after-small.png) |
| Vent warning countdown | [image](screenshots/tunnels-vent-warning.png) | [image](screenshots/tunnels-vent-warning-small.png) |
| Vent eruption, safe waiting point | [image](screenshots/tunnels-vent-erupting.png) | [image](screenshots/tunnels-vent-erupting-small.png) |
| Vent quiet window | [image](screenshots/tunnels-vent-quiet.png) | [image](screenshots/tunnels-vent-quiet-small.png) |

The automated fixture seeds a completed Sunlit chapter with normal production APIs, then
uses physical-key / joypad events for movement, scanning, aiming, firing and Save UI.
A second process uses the actual title Continue UI and traverses both saved shortcuts.
It neither teleports through tunnels nor supplies invented coordinates. The focused
physics tests separately verify shared Sunlit/Twilight cuts and supply restoration.

## Manual route: keyboard and gamepad

1. Complete Sunlit and deploy through Halcyon. Use **WASD / left stick**, **F / X** to ping,
   **E / A** to scan, **Space / right trigger** to fire, **P / Start** to pause. Observe the
   vessel's facing before firing; torpedoes launch horizontally in that direction.
2. Take the open western loop past the whaler, then approach the new mouth below the
   gallery. At its first fork, leave the warm fractured plug closed. Wait outside the
   rising jet for the existing **Quiet window** text; ease down the squeeze, follow the
   lower hall and turn into the return-leg blind recess. Scan the layers, brake and
   reverse out. Continue to the open shelf and return to the tether using the bypass.
3. Revisit that mouth. Face the plug and fire two deliberate shots, allowing the normal
   cooldown. Compare battery/ammunition and the cleared silhouette. Traverse the shortcut
   in both directions. With enough hull, deliberately approach the dead end at full thrust;
   compare its impact cost with the earlier careful approach, then reverse out.
4. From the tether take the inner gallery to the eastern ballast pocket. Follow the new
   rising squeeze and winding passage above it, explore/scan the blind side recess and
   exit to open water. Return to the mouth, face the second plug, fire two shots and use
   its shortcut. Listen for / watch the existing Stalker response; the west gate was
   outside hearing and this one is within it. Retreat remains available without combat.
5. Return to the tether, **Pause → Save**, close/reopen, and **Continue**. Check actual
   supplies and both openings. Return to Halcyon, refit, depart again and recheck the cuts.
   Repeat with the other input device and at both native sizes; test muted audio and
   reduced effects. Optional scans must not complete the story or award research points.
6. For the cut-cap edge case use the automated tests; do not require a human to spend
   256 shots. At that cap verify the uncut long route remains usable and the tether safe.

## Known limitations

- Hypotheses only: shortcut value, squeeze comfort, vent timing, collision cost and scan
  reward appeal need human testing. The pilots know the authored route and are not a
  substitute for an unfamiliar player's navigation. No human playtest results exist.
- Counts are for baseline, centred horizontal shots. A poor aim can waste rounds; the
  existing cap has no new HUD warning and can leave a gate partly cut. The bypass is the
  guaranteed fallback. This issue does not change the existing cap or weapon behaviour.
- Native captures use Linux software OpenGL (llvmpipe) with rendering forced for captures;
  they establish native layout/readability, not frame-rate, physical-controller feel or
  native Windows/macOS readiness. The new input events follow production bindings.
- Existing unrelated Twilight scan radio IDs still emit registration warnings in legacy
  tests. The two new tunnel scan-result IDs are explicitly accepted and tested; no extra
  tutorial/radio lore or required story evidence is authored here.
