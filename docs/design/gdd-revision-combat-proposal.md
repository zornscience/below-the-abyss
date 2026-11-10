# GDD revision proposal — investigation with action (DRAFT FOR APPROVAL)

**Status: proposal only. `GDD.md` is NOT changed by this file.** On approval, the accepted
sections are merged into `GDD.md` and the superseded text is struck from it.
Reference the designer named: **Metroid Fusion** (mystery, investigation, a pursuer you cannot
yet beat, ability-gated exploration, sparse reactive music). The designer is open to free
human-made libraries and has Gemini (music) and ChatGPT (graphics) for generated assets.

## 1. What changes and why

| Today (GDD v0.1 + approved revisions) | Proposed | Reason (designer playtest) |
| --- | --- | --- |
| "No combat-centric progression"; kill rewards removed | **Combat is a pillar-level part of play**, torpedo-first | "Very little action", "nothing exciting" |
| Rift Stalker is a threat to avoid or scare | **A persistent stalker you cannot beat early** and later can | The SA-X feeling the designer wants |
| Equipment gates are research ranks | Add **alien technology** that grants abilities and opens old areas | Ability-gated exploration |
| Map shows numbered points only | **Terrain map that fills in** (needs its own save-schema issue) | Core to the genre; deferred twice |
| One music loop, generic cues | **Sparse reactive music** per zone with stingers | "Bland" sound and music |

Everything else in `GDD.md` stands (single-player, premium, no online requirement, Godot, Steam
later, accessibility rules, no multiplayer, no base building, no crafting trees, no procedural world).

## 2. Proposed pillars (replaces GDD §1 pillar list)

1. **Curiosity is rewarded.** Investigation drives the story: evidence, recordings, places.
2. **Information has a cost.** Sonar reveals and broadcasts. Sound brings hunters.
3. **Capability opens the world.** Found technology changes what you can do and where you can go.
4. **Tension comes from threats you can read.** Telegraphed, escapable, learnable. No unfair deaths.
5. **Action serves the mystery.** Fights and chases interrupt and deepen investigation; they are
   not a separate game.

## 3. Combat (torpedo-first)

- **Start state:** torpedoes only (existing launcher, 5 battery in Twilight). Active sonar gains a
  **stun effect**: a pulse briefly stuns eligible enemies in range (not the Stalker at first).
- **Enemies (target set for the first slice, not a promise):** a small swarmer that reacts to
  pings, an armoured guard that needs a specific hit, one boss. Every enemy telegraphs its attack.
- **Stalker (SA-X role):** cannot be killed or stunned for long until a specific technology is
  found. It hunts by sound, forces you to hide, flee or detour, and later becomes beatable.
- **Fairness:** readable cause for every hit, hull-damage feedback with text and visual cues,
  no instant death, respawn at the tether (existing, BTA-059).
- **Drops and rewards (DECISION NEEDED, default shown):** defeated enemies may drop **battery or
  torpedo resupply only**; no currency, no experience from kills, no farming loops. This changes
  the earlier "no kill rewards" and "no ammunition economy" revisions. Alternative: no drops at all.

## 4. Alien technology (progression by capability)

Technology is found in the story, not bought. Each piece changes route options. **Examples for
discussion, not commitments, and story canon needs the designer's approval:**

| Technology (working name) | Ability | Opens |
| --- | --- | --- |
| Resonant pulse | Active sonar stuns a wider cone; stuns the Stalker briefly | stalker counterplay, sonar-sealed doors |
| Glyph key | Reads the Vael glyph barriers (Story Bible) | alien doors and chambers |
| Pressure shell | Deeper rating (continues the existing hull-rank gate) | deep basins, later zones |
| Silent running | Lowers the noise signature | sneaking past the Stalker |
| Breaker torpedo | Cracks alien barriers; the Stalker's weak point | late gates, Stalker defeat |

## 5. The Stalker arc (proposal)

1. Warned, then hunted: you cannot win; ping less, hide, use tunnels. (Exists in prototype form.)
2. Counterplay: stun and silent running let you survive and gain ground.
3. Confrontation: a scripted boss sequence with the Breaker torpedo ends the hunt.
Safe spaces and the tether remain, per the guardrails: a low-risk place must always exist.

## 6. Map (Metroid-style) — separate approved issue

Terrain discovered by sonar and travel is drawn on the map and persists. This **needs a save
schema change and migration** and the earlier deferral stays until you approve that issue.

## 7. Music and sound direction (investigation first)

- **Sparse and tonal.** Long silence and ambience, short motifs, a pressure build before threats.
- **Reactive layers:** calm / uneasy / hunted per zone; a stinger on Stalker warning; music ducks
  for critical cues; silence is a tool. Driven by the existing threat value and new region state.
- **Sources, in order of safety:** (1) free human-made libraries with clear licences (CC0 or
  commercial-use-approved) for effects and ambience, (2) AI-generated music from Gemini for zone
  motifs, curated and loop-edited by the designer, (3) existing synthesized sounds as fallback.
- Requirements in `docs/audio_audit.md` §6 still apply (44.1/48 kHz, stereo music, clean loops).

## 8. Visual direction with generated images

- A **style guide with reference images** is the first deliverable, so every asset matches.
- Prefer backgrounds, props and portraits (static) over animated characters; animation needs
  consistent sprite sheets, which generation does poorly.
- Every image is a post-processed asset recorded with tool, date, prompt and the licence terms
  in force; no claim of copyright is made on generated media (AGENTS.md).

## 9. Legal and platform checks (the designer must do these; none are assumed)

- **Tool licence terms:** confirm that the Gemini and ChatGPT plans in use permit commercial
  use of outputs, and save a dated copy of those terms with the provenance entry.
- **Copyright:** purely generated material may not be copyrightable, so it may not be protectable.
  Assume nothing; get advice before launch.
- **Steam:** disclose AI-generated content in the store page as required. Verify current rules.
- **Free libraries:** record each source, author, licence text and URL; CC0 preferred; attribution
  licences require credits in the game.

## 10. Milestones (replaces the pre-Steam order; the playtest gate is not skipped)

1. **Combat test box** (graybox, see `combat-testbox-brief.md`): prove the fun in ten minutes.
2. Audio and style-guide pass on the Twilight Shelf with reactive music and sound.
3. Terrain map issue, if approved.
4. Rework the Twilight slice around the Stalker arc and the first alien technology.
5. **Five external playtests** (`docs/playtesting/`) before any new region.

## 11. Decisions recorded (designer, 2026-11-10)

1. **Drops:** battery and torpedo resupply only; no currency, no experience from kills, no farming
   (designer delegated; default adopted).
2. **First-slice technologies:** Resonant pulse and Silent running (pure mechanics, no story canon
   needed, both give Stalker counterplay) plus the existing Pressure shell depth gate. Glyph key and
   Breaker torpedo wait for story approval and the later arc.
3. **Stalker ending (designer):** defeating the Stalker is an OPTION that leads to a specific, darker
   ending, an alternative to the peaceful research and listening resolution. It must be a player
   choice, never forced. Scope note: the existing hidden Resonance state (BTA-046: Listener / Neutral
   / Hostile bands, provisional thresholds +/-40) is the natural carrier for this fork. Two endings
   double the content of the final act only, so branch late, not early. Story canon (what the
   Stalker is, why it hunts, what each ending means) needs the designer's Story Bible approval.
4. **Test box:** approved to proceed (designer delegated).

## 12. Open questions

1. Boss concept for the slice: the Stalker itself or a separate guardian?
2. The darker ending: what does the player lose or gain, and is it reversible before the end?
3. Story canon for alien technology and the Stalker's nature (Story Bible approval).
