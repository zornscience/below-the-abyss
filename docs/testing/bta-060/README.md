# BTA-060 — Twilight listening predator and torpedo defence

Base: `ccr-faf5a894-y8zz7k` (`61245be`), because main did not contain the brief's
“Corrected after reading code” note. That base contains merged BTA-058/BTA-059.
The user explicitly approves the brief despite its draft header. One issue, no merge.

**Human playtest results for this change do not exist. Every number is a hypothesis
for the user's playtest.** Automated input and native captures are not player acceptance.

## What changed / acceptance mapping

1. ChapterJourney composes one scene-owned TwilightHunt and one RiftStalker, using
   the existing AcousticCreature scene, CreatureState arbitration/patrol/return,
   collision-safe navigation and fixed-step movement. `twilight_stalker.tres` owns
   tuning. No ShelfPrototype refactor, autoload, new dispatcher or persisted state.
   The creature exists only while Twilight is active. It resets quietly to its authored
   patrol point on checkpoint restore/Continue and chapter entry, not to a saved chase.
2. It hears the existing vessel ping and `neris-01/torpedo` explosion events. Code
   reading confirmed the launcher already publishes one explosion from `_impact`;
   neither launcher nor BlastEffect is changed. New hearing uses receiver range,
   strength and type filters and only the two vessel source IDs. Receipt-local AI
   deadlines handle the different sonar/launcher epochs after transfers/Continue;
   canonical event payloads, IDs, origins, timestamps and the bus ledger are untouched.
   The internal navigation goal is clamped inside territory for outside sounds.
3. Sound starts investigation. Pursuit additionally requires a sensed vessel inside
   territory, within sensing radius and visible through terrain. Warning holds the
   creature still for 2.5 s before pursuit. Quiet travel, passive listening and scanning
   never start an episode, even when the player is close. Leaving territory, losing
   visibility, gaining distance or exhausting the pursuit/episode deadline ends pursuit.
   The safe upper loop, tether and every required record are outside the territory.
4. The new actor has no BlastReceiver, health bar, scan reward, death reward or kill
   authority. It ignores destruction requests. Its layer-8 collider is a weapon contact
   target for the existing torpedo ray; the vessel's terrain-only mask does not collide
   with it. A real aimed shot therefore detonates at the creature without damaging it.
   The existing launcher consumes the unchanged Twilight five battery and one round.
5. Detonation is heard through the original bus first; the existing `detonated` signal
   then selects the nearest scare-enabled actor within its own profile radius. That
   actor stops briefly, flees to the farther authored patrol refuge, then returns.
   Other eligible listeners retain their investigations. Selection is bounded and
   deterministic (authored actor order breaks distance ties), not a second emission.
   One Stalker is present in production; two model instances test nearest-versus-farther
   arbitration without adding another production creature. Existing eel/squid/jelly
   profiles, harmless behavior, BlastReceivers and damage rules remain unchanged.
   They are not silently made invulnerable or forced to flee by the new defence rule.
6. A moving `marine_life` ambient source produces the existing LIFE passive contact.
   The hunter never treats that ambient signal as a lure. Movement changes, a static
   warning ring and world caption, and the existing temporary ImpactFeedback slot
   show WARNING/PURSUE/STUN/FLEE without a new HUD element, flashing or camera shake.
   Existing artwork and fauna-swim shader are reused with an instance tint; the older
   eel is untouched. Reduced Motion uses the existing animation preference. No asset
   or provenance claim is added.
7. One TutorialDirector card uses the existing one-card, once-per-session mechanism
   and tutorials-off preference. **Wording for user review:** “Sound draws hunters.
   A close blast briefly stuns the nearest hunter and makes it flee; farther listeners
   may investigate. Quiet travel and distance let us escape.” One ordinary nonblocking
   radio line, once per scene session, says: **“Wick: That living contact turned toward
   our sound. It is closing in. Quiet travel and distance give us a way out.”** No story
   flags, choices, dialogue canon, permanent HUD rows or rewards are added.
8. ReleaseSmoke proves the real exported actor/receiver registration, passive LIFE
   receipt, actual ping and explosion hearing, and an actual fired projectile hitting
   the weapon-contact collider and invoking stun without a kill. Four new negative
   flags remove registration, passive emission, hearing eligibility or the detonation
   callback; each must fail with its own marker. Prior six negative cases remain.

## Resource table and reasons

All distances/speeds are game units, not acoustic decibels or measured biological data.

| Active rule | Provisional value | Reason |
| --- | ---: | --- |
| Territory | Rect2(33300,2700,2200,650) | Optional central lower shelf; upper loop, tether and required records stay outside |
| Patrol points | (33900,3080), (34800,3060) | Clear authored water within the existing geometry |
| Hearing maximum | 1800 u; minimum strength 0.2 | Meaningful on the 12000-u shelf; larger than original predator's 500 u |
| Effective sound range | min(emission range, 1800 u) | Base ping remains 900 u; upgraded pings/blasts can reach farther. No sonar upgrade/cost change |
| Accepted sounds | active_sonar / explosion; vessel sources only | Quiet thrust, scan and passive listening do not lure |
| Priorities | explosion 30 / ping 20 | Reuse existing deterministic arbitration |
| Patrol / investigate | 40 / 110 u/s | Visible change after sound without instant pursuit |
| Sense radius | 450 u plus terrain visibility | Hearing alone does not reveal the moving player |
| Warning | 2.5 s, stationary | Readable time to act; cannot be skipped by a point-blank ping |
| Pursuit | 170 u/s, at most 6 s | Below normal 240-u/s vessel speed; finite encounter |
| Target distance | 700 u and inside territory | Quiet travel/distance and the boundary offer escape |
| Investigation cap / recovery | 18 s / at least 4 s and patrol recovery | New sounds cannot indefinitely extend a chase or starve recovery |
| Return | 130 u/s | Bounded movement back to the nearest patrol point, no ordinary teleport |
| Contact | 50 u; 5 hull per hit; 3 s cooldown | Modest damage through the existing hull API, never a full-hull instant kill |
| Weapon-contact radius | 24 u | An aimed center-line shot is required; the actor never blocks the vessel |
| Scare radius | 240 u | A direct hit or nearby detonation helps; distant blasts still draw attention |
| Stun / flee | 1.5 s / 5 s at 190 u/s | Time to escape, followed by visible retreat and recovery |
| Repeated blast during flee | Cannot extend the current stun/flee | Spending ammunition does not create an endless stun lock |
| Passive source | LIFE / 1600-u emission / strength 1 / every 3 s | Existing receiver still limits contacts to its own 1400-u range and normal expiry |
| Sight/target sampling | 0.25 s | Four checks/replans per second; fresh obstruction check before a damaging contact |
| Navigation | 90-u grid, 168 candidate cells | Existing bounded static-terrain navigation, not per-frame graph construction |

The new model uses territorial/target-distance limits; the original predator's
QUIET→ALERT→PURSUE→DISENGAGE behavior and all of its Resources remain untouched.
Profile values are copied into runtime rules, not used as mutable actor state.

## Verified behavior

- Eight focused tests cover filter thresholds/range, no passive attraction, canonical
  event immutability, investigation, warning/pursuit, escape, stun/flee/return, closest
  selection, no BlastReceiver/kill/reward, actual hull signal/damage, real fired-shot
  collision and single explosion, regional scope, pause and checkpoint reset binding.
- A complete real-input Twilight chapter recovered evidence, resolved the sentinel,
  debriefed and saved with **zero Twilight pings and no Stalker encounter**. It uses
  the existing authored upper-loop paths and record positions, not new hard-coded
  coordinates. The supplied route chooses the safe upper connection between branches.
- Separate keyboard and controller injected-input routes deliberately pinged, reached
  warning and pursuit, then escaped quietly. Each finished at 95 hull: one modest hit,
  not a test assumption that an encounter must be harmless.
- Actual ray/projectile tests prove a round is spent, five Twilight battery is spent,
  exactly one launcher explosion is emitted, and the non-damageable actor is stunned.
- Existing Chapter 1, prototype, depth, thermal, survey, narrative and Continue routes
  run unchanged. No existing assertion or timeout was weakened or changed in this issue.
- Save schema stays at version 10 with twelve top-level fields. Creature state, warning
  history and card presentation are session-only. Continue resets the actor quietly;
  supplies, ammunition, permanent records and BTA-059 failure behavior remain owned by
  the same coordinator. No depth, research, darkness, cost or torpedo-emission tuning.

## Native evidence

| State | 1280×800 | 800×600 |
| --- | --- | --- |
| Warning | [warning](warning-1280x800.png) | [warning](warning-800x600.png) |
| Pursuit | [pursuit](pursuit-1280x800.png) | [pursuit](pursuit-800x600.png) |
| Scare/stun | [scare](scare-1280x800.png) | [scare](scare-800x600.png) |

These are native Godot/Mesa captures with commissioned 1000-m rating, tutorials off
and a settled camera. The fixture holds actor motion for comparable framing, drives
warning through a real ping and scare through an actual aimed shot, and advances the
model to pursuit. They are controlled state captures, not human gameplay recordings;
the separate routes prove actual moving pursuit/escape. No darkness shader was changed.

## Manual keyboard and gamepad route

Controls: WASD/arrows or left stick to thrust; F / controller X to ping; Space /
right trigger or right-stick click to fire; E / A to interact; P / Start to pause;
R / left shoulder to review the radio. Current remaps take precedence.

1. Continue/deploy to Twilight. Keep quiet and use the upper connection between the
   established wreck and cable routes, then resolve the net and return to the tether.
   The required evidence remains available without entering the Stalker's territory.
2. With tutorials enabled, approach the optional central lower-shelf water near the
   new optional studies. Read the one card and observe the existing LIFE contact;
   turning tutorials off must suppress the card. Quiet proximity alone must not attack.
3. Ping while near the living contact. Observe its movement/caption, the temporary
   WARNING text and Wick line, then pursuit after the warning. Repeat muted, with
   Reduced Motion/Flashing and High Contrast at both window sizes; no cue depends on
   sound or color alone. There is no camera shake or new permanent HUD line.
4. Stop pinging and retreat into the open safe water outside its territory. It stops
   damaging and returns; it does not chase to the tether or through rock. Repeat with
   both keyboard and gamepad. Measure hesitation, clarity and distance yourself.
5. During an encounter, match the hunter's depth, face it with a short horizontal thrust, then fire an aimed torpedo. A hit detonates and
   briefly stuns it, then it flees. Check one round and five battery spent, no health
   bar, death, reward or Resonance change. A distant blast can lure rather than scare.
   Existing wildlife still has its previous damage rules; this does not grant immunity
   to the other creatures. Firing repeatedly during flee spends supplies without
   extending the existing stun window.
6. Pause, save/quit and Continue: the Stalker returns quietly to its territory, with
   actual vessel supplies retained. If hull reaches zero, verify BTA-059's explanation
   and hull-only tether respawn. Region changes must hide/suspend the Stalker entirely.

## Limits and review

One production scare-enabled predator is intentional. The simultaneous nearest/other
rule is tested with multiple opted-in model actors; no second production Stalker is
silently added. Old fauna's hearing eligibility, clock behavior and combat rules are
preserved. The hunter is a new use of an existing eel illustration, not final species
art. Sight samples at 4 Hz; contact damage always gets a current obstruction check.
Navigation retains its existing static-geometry limitations. Continue can end a chase
by resetting its transient state, as explicitly allowed by the request. Oxygen
exhaustion still has the pre-existing limitation recorded in BTA-059.

No physical-controller, Windows/macOS, Steam Deck certification, target-GPU 60 FPS,
or human balance acceptance is claimed. Frame samples in the capture log include
software rendering, synchronous screenshots and concurrent tests; they are not an
isolated AI cost comparison. New graph construction is on activation/reset, target
and sight work is bounded to 4 Hz, and nearest selection allocates only on detonation.
See [validation](validation.md) for commands/results and [changed files](changed-files.txt).
