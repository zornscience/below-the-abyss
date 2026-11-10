# Combat test box — one-page brief (DRAFT FOR APPROVAL)

**Purpose.** Find out in ten minutes whether the proposed action is fun, before building anything
permanent. This is a disposable graybox, not a feature of the campaign.

## What to build (one issue, one PR, high effort)

A single separate scene reachable only from a developer or playtest option (not from the title menu
for ordinary players), reusing the existing submarine, controls, torpedo launcher, active sonar,
acoustic bus, hull system and the BTA-060 Rift Stalker code. One open arena with a few rock columns
and two tunnel mouths, using existing rock art. No story, no saves, no persistence, no new HUD
elements beyond the existing hull and battery gauges and threat notices.

| Element | Behaviour |
| --- | --- |
| Swarmer (new, 3–5 of them) | Small, fast, drawn to pings and blasts, bites for small hull damage, dies to one torpedo, can be stunned by sonar. Telegraphs its dash. |
| Sonar stun (new) | The existing active ping stuns eligible swarmers in a short range for about 2 s. Costs the normal ping battery and cooldown. Does not stun the Stalker. |
| Stalker (existing, tuned for this scene) | Cannot be killed. Hunts by sound. A torpedo scares and stuns it briefly (existing rule). |
| Torpedoes | Existing launcher, existing costs. |
| Resupply | None in the first version. After a wave the player returns to a refit point. |

## Rules for the build

- Reuse; add only the swarmer and the stun effect. No new currency, pickups or progression.
- Fairness rules from the brief still hold: every attack is telegraphed with a visual and text cue;
  no instant death; hull zero respawns at the arena's refit point.
- Release-safe code: no side effects in `assert()`; extend `ReleaseSmoke` for the new wiring with a
  negative case; the radio id check no longer needs registration.
- Tests are rules, not coordinates. Do not weaken existing tests.
- Deliver the PR template, native screenshots at 1280×800 and 800×600, a keyboard and a gamepad
  route, and state plainly that no human playtest exists.

## Control feel (market-driven requirement)

Market research on comparable games names clunky controls as the most common reason small-team
Metroidvanias are punished. Our water-like inertia was an earlier designer request, so it must be
measured, not assumed.

- Provide TWO handling profiles for the box only, as Resources: **Weighty** (the current campaign
  motion profile, unchanged) and **Responsive** (higher acceleration, lower drag, faster turn). A
  developer option switches between them in the box, with a visible text label of the active profile.
- Report a table for each profile: time to 90 % top speed from rest, stopping distance from top
  speed, time for a 180 degree turn, and top speed.
- Log per session which profile was used, collisions per minute, deaths by collision, and a
  post-session rating question (weighty / about right / sluggish / twitchy).
- Campaign motion Resources and Sunlit/Twilight values do NOT change in this issue.

## How we judge it (the point of the box)

Run it with at least three people who have not seen the game, ten minutes each. Record, per person:
- time to first engage, deaths, pings per minute, torpedoes fired, handling profile used,
  collisions per minute;
- the first moment they said or showed excitement, and the first moment they were bored;
- whether they used the stun, the tunnels, or ran;
- "Would you play another ten minutes?" (yes / no / why).

**Go** if most want to continue and the Stalker produces at least one chase they describe as tense.
**Change** the design if players ignore the stun, spam pings, or run from everything.
**Stop** the combat direction if nobody finds it more exciting than the current Twilight.

## Not in scope

Alien technology, bosses, drops, the terrain map, story, new regions, art or music production,
refactoring `ShelfPrototype`.
