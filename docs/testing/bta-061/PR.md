## Problem and behavior

Twilight had no tunnel exploration spaces or registered excavation gates. Two Resource-authored
loops now provide a squeeze, a reversible blind branch with optional study, and an excavatable
shortcut each. Both connect back to the open shelf with gates closed. Required evidence and
chapter completion keep their existing paths.

Base: current **main `ee38c74`**, already containing BTA-058/059/060 and the corrected brief.
Branch: `bta-061-tunnels`. One issue. **Do not merge; PR-specific CI must be green first.**

**Human playtest results do not exist. Every number is a hypothesis for the user's playtest.**

## Acceptance and implementation

- **Data / two systems:** Resource polygons, centrelines, widths, junctions, gate IDs/bounds,
  payoff and approach/return paths drive both geometry and tests. Existing rough/rounded art
  and shaders are reused. The measured rotated capsule is **64×32 units**; widths use its
  conservative 64-unit maximum span.
- **Risk:** existing ThermalVent times the west squeeze, retaining 8/4/3/5-second phases,
  4 hull/s, occlusion, visual/text warnings and accessibility preferences. Actual keyboard
  and gamepad events pass both squeezes and reverse out of dead ends; deliberate full-speed
  impacts use the existing damage rule. No new damage rule or random death.
- **Gates / return:** both stable DestructibleRock IDs register outside assertions. Real capsule
  casts prove both approaches, bypasses, branches and exits, including reversed paths at the
  cap. One shot is insufficient; two clear each shortcut. Repeated cuts never increase rock
  area or block any authored return edge. The tether remains clear through the vent cycle.
- **Persistence:** both regions share the existing 256-record `terrain` journal. Continue and
  transfers preserve Sunlit and Twilight cuts plus actual supplies; schema stays **10 / twelve
  top-level fields**. At the cap cuts stop, weapons retain normal costs, and bypasses remain.
- **Optional studies:** existing scanner/research/discovery/map, existing clear-path echo option and registered scan-result radio
  path, **zero XP / zero points**, no mission objective changes. Map still has discovered points
  only. No new HUD, permanent HUD text, tutorial card, asset or local-darkness work.
- **Runtime selection:** only the active Twilight chapter enables the new geometry, gate collision
  and vent updates. All gates register before Continue and remain registered across regions;
  enabling never resets cuts. Existing visibility outlines rebuild on geometry changes.
- **Prerequisite fix:** capability reapplication used to reset a Twilight torpedo to Sunlit's 2
  battery after Continue/transfer. Preserve the selected regional cost: **Sunlit 2, Twilight 5**.
  No cost values or balance Resources change. Existing cost tests gained assertions.
- **Release:** real exported binary proves tunnel geometry + visibility, gate registration and
  vent registration; three new negatives remove/disable those actual connections. Existing
  export proofs and all thirteen negatives are retained and run in CI.

## Tuning arithmetic

| System | Widths versus 64-unit hull span | Branch / payoff | Gate / hardness | Battery / hearing | Bypass vs shortcut |
| --- | --- | --- | --- | --- | --- |
| West lower loop | Normal 192 (3×), measured 193.96; squeeze 124 (1.9375×), measured 125.08 (1.95×) | 300-unit blind branch; Tunnel layers, 0 XP | `twilight-west-shortcut`, rough 280×200 plug, radius-150 blasts; **2 shots** | **2×5 = 10**; outside 1800-unit hearing, nearest territory-envelope distance 2094.70 | **1940 / 1200** units |
| East ballast loop | Normal 192 (3×), measured 197.03; squeeze 124 (1.9375×), measured 115.32 (1.80×) | 200-unit blind branch; Sheltered grains, 0 XP | `twilight-east-shortcut`, rough 280×200 plug, radius-150 blasts; **2 shots** | **2×5 = 10**; inside hearing, farthest envelope-corner distance 1777.99 | **1500 / 700** units |

Gate hardness is geometry, not HP or a shot counter. Both gates together cost **four rounds,
20/100 battery**, before pings and travel. Lengths compare the same junctions and omit common
approach/exit legs. Off-centre shots may cost more; upgrades are unchanged. Pings remain five,
passive travel remains slow, oxygen unchanged. Real detonations test the unheard/heard cases;
the Stalker's territory still bounds investigation and pursuit.

## Validation and review evidence

**PASS:** release-safety lint; 10 Python tests; pinned Godot import, 336 script checks and
startup smoke; **781 GUT tests / 45,489 assertions**, no failures/errors/skips; **all 11
verify routes**; native input/captures at both sizes; `git diff --check`. The actual Linux
export passes the positive smoke (exit 0) and **all 13** expected-failure cases (exit 1,
matching marker). Focused coverage: **13 tests / 385 assertions**.

- [Exact commands, results, export digest/matrix and native reproduction](https://github.com/zornscience/below-the-abyss/blob/bta-061-tunnels/docs/testing/bta-061/validation.md)
- [Full acceptance mapping, tables, cap behavior, manual keyboard/gamepad route and limitations](https://github.com/zornscience/below-the-abyss/blob/bta-061-tunnels/docs/testing/bta-061/README.md)
- [Changed files](https://github.com/zornscience/below-the-abyss/blob/bta-061-tunnels/docs/testing/bta-061/changed-files.txt)
- [26 original native images: tunnel, squeeze, payoff, gates before/after and vent cycle at 1280×800 and 800×600](https://github.com/zornscience/below-the-abyss/blob/bta-061-tunnels/docs/testing/bta-061/README.md#native-images-and-scripted-evidence)

Manual review: deploy from Halcyon, take the west winding bypass and time the vent, scan/reverse
out of its blind branch, return and open its plug with two shots. Repeat from the eastern ballast
pocket; observe the existing hunter response to its louder shortcut. Save/Continue, return/refit,
depart and verify both openings. Repeat with WASD/F/E/Space/P and left-stick/X/A/RT/Start.

Limitations: no human playtest; scripted pilots know the geometry. Linux software OpenGL captures
verify layout, not FPS, physical-controller feel or other native platforms. Existing unrelated
scan-radio registration warnings remain; the two new scan-result IDs are tested. No merge
or remote CI success is claimed by local validation.
