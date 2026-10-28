# Below the Abyss — Game Design Document
Version 0.1 | 2026-10-25 | Status: preproduction | All names and numerical values provisional

## 1. Product definition
**Genre:** single-player 2D side-view exploration adventure and environmental mystery. **Platforms:** Windows, Linux, macOS via Steam. **Engine:** Godot 4.x. **Visual style:** modern illustrated 2D with layered parallax, restrained volumetric-like lighting, animated particulate matter and bioluminescence. **Audience:** players who enjoy discovery, atmospheric tension, navigation and narrative exploration. **Campaign target:** 6–10 hours, contingent on playtesting and budget. **Monetization:** premium one-time purchase, no online requirement.

### High concept
Pilot a small scientific submarine to investigate a vanished deep-sea expedition. Use active sonar to map unseen terrain and passive acoustics to identify threats. Recover research, upgrade the vessel, and descend into an interconnected handcrafted ocean to understand an anomalous signal.

### Player fantasy
'I am an intrepid submarine pilot and scientist, venturing farther into the unknown with only my instruments, ingenuity, and courage.'

### Design pillars
1. Curiosity is rewarded: optional discoveries yield story, navigational shortcuts, and research.
2. Information has a cost: active sonar reveals but broadcasts; passive listening is safer but less precise.
3. Preparation enables exploration: upgrades unlock routes and choices rather than grind.
4. Tension comes from uncertainty and understandable threats, not jump scares or unfair instant deaths.

### Non-goals for v1
No multiplayer, combat-centric progression, base building, hunger/thirst, procedural overworld, crafting trees, or full fluid simulation. No mandatory online AI or network connection.

## 2. Core loop
At station: select objective, repair/refill, install upgrades → leave station → navigate region, manage battery/oxygen/hull → sonar and scan discoveries → collect logs/samples → return or use unlocked route → research and unlock next destination.

**Target expedition duration:** 10–20 minutes in early game; revisit after testing. **Failure:** on hull destruction or oxygen exhaustion, respawn at most recent station/checkpoint with a clearly explained limited penalty (e.g. loss of unbanked samples); do not delete permanent discoveries. **Accessibility:** adjustable survival pressure and generous checkpointing.

## 3. Controls and camera
Side-view movement with horizontal and vertical thrust, acceleration, drag, modest inertia. Keyboard: WASD/arrows to thrust, mouse aim for scanner (optional), dedicated sonar, interact, map, light toggle. Full remapping and gamepad equivalents required. Camera follows with dead zone, look-ahead, and smoothing; no camera motion that obscures hazards. All controls must work without mouse precision on gamepad.

## 4. Player vessel and survival
One starting vessel, NERIS-01 (working name). State: hull integrity, battery charge, oxygen reserve, current depth, crush-depth rating, noise signature, equipment slots, inventory of research samples. Damage sources: collisions, hazards, creatures, excessive depth with warning and grace period. Resources drain predictably; station fully replenishes. Player must have enough reserve to turn back from the first critical discovery. Survival difficulty settings: Story (lower drain), Standard (default), Expedition (higher drain), all with the same narrative.

**Initial prototype tuning values, not canon:** battery 100 units, oxygen 100 units, sonar pulse cost 4 battery, sonar cooldown 4 seconds, hull 100 units, first safe operating depth 300 m. Tune via resources rather than constants.

## 5. Sonar design
### Active sonar
Button press sends expanding visible wavefront; a gameplay query determines detections based on distance, occlusion, target reflectivity and region modifiers. Map/contacts are revealed as wavefront reaches them, not instantaneously. Pulse drains battery and produces an acoustic event detectable by creatures. A cooldown prevents spamming. Range and resolution improve through upgrades.

### Passive sonar
Displays bearings and qualitative signal classes (machinery, fauna, geological, unknown) when acoustic emitters are in range. Passive mode does not reveal solid terrain. Ambiguity is intentional but never should make navigation impossible.

### Player choices
Quiet travel minimizes detection but reduces speed. Active pulse clarifies a dangerous route but may provoke an investigation. A creature's reaction must have a readable cause: sound cue, HUD contact, animation, or behavior.

### Design guardrails
Avoid requiring constant repeated pings. Do not make every pulse trigger combat. Provide low-risk spaces and alternatives such as landmarks, lights, and discovered map tiles.

## 6. Handcrafted world
Interconnected authored scenes, with logical shortcuts and equipment gates. Regions:
- Continental Shelf (0–300 m, approximate): station, movement tutorial, first sonar contact, safe fauna.
- Twilight Reef (300–1,000 m): bioluminescence, cave navigation, scanner upgrades.
- The Graveyard (1,000–2,500 m): wreck fields, expedition records, acoustic predator.
- Thermal Rift (2,500–4,000 m): vents, currents, navigation under environmental pressure.
- The Abyss (4,000 m+): anomalous architecture, narrative resolution.
These ranges are fiction-facing progression targets, not scientific constraints or final level measurements. Reconcile map geography and travel times during level design.

### Region content contract
Each region requires a primary goal, at least one optional discovery, a navigational landmark, one memorable environmental event, an upgrade gate or alternative route, and a safe return path. Maps persist exploration state; undiscovered secrets are not spoiled by UI.

## 7. Creatures and ecology
Fauna are primarily environmental characters, not loot dispensers. Example archetypes:
- Lantern Drifters: passive, respond to illumination.
- Rift Stalkers: investigate sound, territorial, avoidable with quiet travel.
- Leviathan: rare scripted encounter and environmental mystery, not a repeatable boss fight.
AI states: Idle, Patrol, Investigate, Pursue, Flee, Return. Per-creature resources define hearing thresholds, sight, territory and cooldowns. Telegraph threat and offer escape paths.

## 8. Research and upgrades
Research records include scan subject, location, description, recovered samples, and unlock relationships. Upgrades: pressure hull, battery, propulsion, acoustic array, lighting, scanner/sampling arm, navigation. Each upgrade should change the player's route options or tactics. Avoid currencies that force repetitive harvesting.

## 9. Narrative and missions
**Act I — The Lost Expedition:** retrieve a missing research beacon and learn of anomalous transmissions. **Act II — The Signal:** investigate the wreck field and thermal rift, discovering that the anomaly affects wildlife and instruments. **Act III — Below the Abyss:** locate the source and resolve the fate of the expedition. Story is delivered through recovered recordings, environmental evidence, brief station dialogue and exploration. No essential clue should exist in only one easily missed collectible.

Mission state model: Locked → Available → Active → Completed/Failed (failure only for optional timed tasks). Objective tracking should be data-driven and resilient to save/load. Main campaign has no permanently missable critical objectives.

## 10. Art and audio direction
Modern illustrated 2D: crisp painted silhouettes, layered seabed/cave backdrops, cool teal/indigo palette punctuated by warm submarine lights and selective bioluminescence. Assets should be authored at target reference resolution and composed as layers for parallax. Normal maps and Godot 2D lighting where beneficial, but do not sacrifice legibility or low-end performance. Animate submarine thrusters, suspended particles, fauna, and sonar rings. Avoid noisy full-screen effects.

Sound: subdued music, mechanical hull creaks, propeller rumble, distinct passive contacts, strong active sonar pulse. Audio cues must have visual equivalents. Dynamic mix ducks music for critical cues.

## 11. UX, accessibility and quality
Remappable keyboard/gamepad, scalable text, subtitles, color-independent warnings, reduced flashing, camera shake toggle, adjustable sound mix, pause anywhere outside transitions, manual and autosave, clear resource warnings. UI should remain legible at 1280×800 for Steam Deck. Target 60 FPS on a documented midrange baseline, then profile real hardware.

## 12. Vertical slice: playable definition
One authored region with station, 20–40 minutes of polished gameplay, a cave navigation challenge, active and passive sonar, one passive creature and one acoustic predator, a recoverable expedition log, one upgrade, a return loop, save/load, and an ending hook. Player can complete it without developer assistance. Conduct at least five external playtests; measure confusion, sonar usage, completion, and whether players want to continue.

## 13. Commercial positioning and validation
Working price hypothesis: USD $14.99, subject to comparable-title research and playtesting. Create Steam page only after genuine gameplay screenshots and a clear trailer exist. Avoid claiming Steam Deck Verified or macOS support before device testing. Working title 'Below the Abyss' requires trademark and store-name clearance before public branding.

## 14. Open design questions
Final protagonist identity; scientific realism level; exact nature of anomaly; fail-state penalty; exact map dimensions; dialogue volume; art production pipeline; accessibility presets; final pricing; supported minimum hardware.

## Approved playtest-feedback revision (2026-10-27)

The user requested optional contextual tutorials with a saved disable switch, a
quieter HUD, an illustrated station overview, meaningful wildlife observation,
slower travel drain, a visible expedition wreck, removal of route directions, and
more environmental detail. They explicitly selected excavatable terrain and a
substantially expanded first chapter. These additions remain exploration focused:
no kill rewards, combat progression, ammunition economy or mandatory fighting.

The current prototype extends the shelf to a hydrophone, chimney field and grounded
expedition wreck. Recover their scientific records and return for debrief; old
completed saves retain their earned conclusion. The observer supports optional
nonviolent biological research; additional grazers react to sound. Torpedoes are
optional excavation/damage tools, with modest energy cost and bounded radial blasts.
Station/wreck/perimeter structures remain protected. Native screenshots, exact
balance values, compatibility policy and manual acceptance checks are in
[the feedback record](docs/feedback/README.md). The 20–40 minute human pacing target
and five external sessions are still evaluation gates, not completed claims.

## Approved second playtest revision

The user explicitly requested a clean illustrated title, more shaded environment/
fauna, slower water-like vessel acceleration, horizontal facing-based accelerating
torpedoes with wakes/bright refractive blasts and a ten-round complement/HUD count.
Deliberate docking now automatically repairs/refills/rearms. Mission offers arrive
by base radio, marking an unconfirmed last-contact report rather than exposing an
undiscovered wreck. A harmless wreck scavenger flees on approach; scientific scanning
recovers encrypted logs that decode at base and lead to a next-region dossier.

Research points replace free production upgrades: two commissioning points plus
one outer-survey and one decoding reward, four total in this prototype, spent across
six sequential sonar/hull talents. The user chose free reassignment at the station.
No farming/kill rewards, ammunition economy, additional playable region or final
campaign budget. Earlier explicit-service/free-upgrade behavior remains in regression
fixtures only. [Complete decisions and acceptance](docs/feedback-two/README.md).

## Approved Resonance foundation (BTA-046)

One optional Zone 1 light-bloom plankton patch offers an intentional, exclusive choice:
record a three-second non-destructive scan (+15 hidden Resonance) or collect a
specimen for Crane, killing the sampled bloom (-15). Leaving or interrupting the
scan makes no decision. Wick, Okafor and Crane respond in short text; the intact
plankton forms a spiral, then scatters, and remains lit after observation or is
extinguished by bottling. Reduced effects use a static spiral. No numeric score
or tier is shown. The supplied [Story Bible](docs/story/README.md) anchors these
responses and visuals without later-zone spoilers or campaign renaming.

The reusable hidden state starts at zero, clamps to [-100,100] and exposes provisional
Listener/Neutral/Hostile bands at +/-40 for later consumers. This PR does not connect
those bands to wildlife, trust, existing dialogue, branches or endings. Existing
combat, talents, missions and rewards are unchanged; observing or collecting grants
no research points/inventory. Permanent decisions survive Continue and route reset.
[Acceptance, exact controls and evidence](docs/testing/bta-046/README.md).

## Canonical first expedition — BTA-047

The normal title begins **The Sunlit Shallows**, in the Bible's 0–200 m band.
Halcyon Station / Meridian Deep Institute introduces Lantern-2, Wick and the
search for Lantern-1 and missing acoustician Dr. Mara Voss. Public Tethys funding
is established without revealing Crane's private connections. The player can ask
Okafor a short optional question before intentionally accepting the dive.

Pylons, kelp and reefs lead to the existing geometric plankton encounter, then an
emergency buoy near Twin Spires. Sonar identifies; deliberate scanning recovers
Mara's exact line: "It isn't empty down there. Tell Elias the Choir is a voice."
Both bloom decisions permit recovery and return. The decision remains visibly
intact/extinguished and is recalled in the station debrief, without numeric scoring.

One compact objective line and optional contextual Wick cards support continuous
piloting. Dialogue is short, written, manually advanced and archived. Deliberate
return/docking and submission acknowledge the first expedition, pointing toward
the Twilight Shelf without opening Zone 2. Existing research technology remains
accessible; this chapter adds no currency or point award. Combat is optional.

The grounded shallow wreck and outer course stay explicitly **prototype** content,
not Mara's vessel or a canonical later-zone reveal. Old progress is archived, never
renamed or reinterpreted. Full route, acceptance criteria and remaining human
playtesting questions: [BTA-047](docs/testing/bta-047/README.md).

## Approved compact interface — BTA-048

The production HUD uses small existing glyphs and normalized resource percentages,
with textual depletion/danger cues. Depth stays near the upper center; accepted
mission objectives remain upper right. Compact sonar/ordnance/passive/threat status
uses corners and temporary damage/context feedback remains readable. The bottom
center stays open. Ordinary radio is a non-blocking preview/unread badge plus an
intentional scrollable transcript; the submarine keeps moving and simulating while
reading. Mission offers still require explicit acceptance. Briefing, station, bloom
choice and debrief interactions retain their deliberate behavior. No gameplay balance,
progression, save content, lore or environmental art changes are implied. See
[layout, controls, comparisons and manual acceptance](docs/testing/bta-048/README.md).

## Approved cinematic identity — BTA-049

The Halcyon Descent title presents a distant warm scientific installation over a
dark ocean, Lantern-2's illustrated searchlight and cliffs fading into depth. Cool
negative space supports restrained actual menu controls. This is the same vessel
and modular station art used at the immediate Halcyon departure, not promotional
3D imagery or new geography. Existing Begin/Continue/options/recovery/legacy access
and all exploration mechanics remain intact. Comfort modes provide a static version;
no narrative spoilers, new regions, objectives or mechanics.


The user-requested BTA-049 revision replaces the geometric title masters with shared
painted hardware, rock and optics. Compact, centered, scrollable dialogs keep the
underwater scene visible; semantic 16 px body text, 18–20 px headings and 17 px main
menu controls replace oversized defaults. Existing Compact/Standard/Large, contrast
and comfort preferences remain. This changes presentation only; it adds no content,
mechanic, progression or save field. Visual acceptance remains a reviewer decision.


## Approved Sunlit Shallows environmental art — BTA-050

The user requested a substantial illustrated pass for the existing canonical
0–200 m chapter. Organic kelp variants, worn basalt/mineral detail, layered hazy
scenery, scientific station infrastructure, marine snow/bubbles and painted fish/
emergency-buoy presentation enrich the same route. The geometric plankton remains
unchanged in a natural surrounding garden. All details remain decorative; terrain
outlines, passage clearance, camera, target positions, progression, resources,
choices and UI remain authoritative. No new region, discovery, mission or mechanic.
[Native comparisons, performance and pending human-review limits](docs/testing/bta-050/README.md).


### Sunlit Shallows survey extension — BTA-051 prototype

The first expedition follows the shallow continental course beyond Twin Spires,
clears one fractured rockfall using an excavation torpedo, and searches an
approximate emergency-buoy report with active sonar. Quiet scientific observations
along the way are optional; a hydrothermal shaft provides a clearly warned,
retraceable pressure hazard, not access to another story zone. The exact Mara
recording, light-bloom Resonance decision and Halcyon debrief remain unchanged.
Scientific XP is independent of alignment: first species 20, study 30, one point
per 100, initially capped at two bonus research points. Historical prototype
rewards and free station talent reassignment remain available. Intended first-time
pacing is 15–20 minutes, pending human evaluation.
