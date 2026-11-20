# Zone 3: The Drowned Caves

**Canon:** Below the Abyss Story Bible (27 October 2026), Zone 3, pp. 2, 7, 9, 12. This is the next playable investigation after The Severed Line. New dialogue and puzzle text are authored adaptations, not quotations from Mara's existing logs.

## Dramatic question

The player knows the lines were deliberately cut but has no explanation. This chapter asks: **What happened when humans first met the hidden people, and why did both sides choose silence?** The cave wall and crystal preserve incompatible viewpoints. The answer is not a monster reveal or a named enemy.

**Depth:** 1,000–2,000 m; modeled by existing world depth = Y × 0.25. **Start:** 1,120 m. **Space:** winding limestone corridor and multiple lateral chambers. **Clear:** learn the light sequence, approach the archive, choose whether to leave or remove the crystal, return to Halcyon. Players may withdraw and return with their scans saved. No combat is required.

## Critical path (authored scenes)

1. Halcyon: after archiving the Twilight Shelf expedition, Wick commissions a 2,000 m pressure fit. Okafor: "The cave walls were above water before the last sea rise. Mara went looking for the markings." Crane: "The survey contract still includes recoverable material." The pilot descends.
2. **The handprint wall:** fingerprint-sized human hand silhouettes, taller figures made of light and images of a violent conflict; scan. Neither group is depicted as wholly innocent.
3. **The other testimony:** Vael glyphs repeat beside a memory seam. Scan while quiet; Wick decodes the tentative words "WAIT", "ANSWER", "REMAIN." This is partial translation only; full Vael speech is reserved for Zone 6.
4. **Mara's fourth log:** a damaged acoustic notebook establishes that the Choir pauses for an answer. Scan; a fifth optional note reflects on whether removing an archive is another act of harm. Do not reveal Mara's location.
5. **Choking silt channel:** a cold density current pushes the sub back toward rock, compounded by stronger oxygen drain (0.075/s). If the Zone 2 sentinel was released and survives, a luminous guide marks the gentler side and the current is halved. Without a guide, the passage remains fully playable.
6. **The memory shrine:** scan the crystal without collecting it, then solve a readable three-signal light-language challenge: *hold steady*, *two pulses*, *long pulse*. All choices use ordinary text-labeled buttons, usable on keyboard and gamepad. Incorrect sequences reset without damage; after mistakes Wick clarifies the three motifs.
7. **Major decision:** leave the memory in place (+15 Resonance, Listeners notice) or remove it (−15, permanent sonar +175, local arch collapses, Keepers grow colder). Both choices make the return route viable and are saved before visual consequences.
8. **Return and report:** at the entrance use the ascent route to Halcyon. The next mission is the Furnace Vents (Zone 4); this chapter does not reveal Tethys's concealed knowledge early.

## NPC writing

- **Wick:** practical, initially literal. "The two accounts agree on a loss. They do not agree on who began it." On successful pattern: "The marks are not a password. They are an invitation to stop making noise." On crystal removal: "Better range. Less memory. Those are separate measurements."
- **Okafor:** curious and cautious. "An object can be evidence without becoming our property." He refuses to flatten the accounts into heroes and villains.
- **Crane:** interested in physical artifacts, not openly villainous yet (betrayal belongs to Zone 4). "Bring back what can be safely preserved." Her request conflicts with Okafor's.
- **Mara:** encountered only in recorded notebooks; she remains missing until Zone 6.
- **Sentinel:** only if the prior rescue is valid and the creature remains alive. Nonverbal guide, not a new Vael diplomat.
- **Vael archive:** a preserved memory image. No living Vael contact before the Gardens.

## Implementation contracts

Uses the existing scene, scanner, research registry, StoryState, one authoritative SaveCoordinator checkpoint, and established input/dialogue interfaces. No change to the top-level checkpoint shape or new separate save. Zone 3 is tracked through the ship's stable map position while the journey remains commissioned, so legacy saves can be loaded unchanged. Reentering is available after returning to station. New decisions are mutually exclusive and cannot replay. If an archive write fails, neither consequence nor upgrade is applied.

Safety: quiet gameplay has no forced kill; 2,000 m baseline pressure rating is recomputed through existing capabilities; return path always stays open. The archive collapse blocks only a *side alcove*. The old Twilight mission remains complete and its rewards unchanged. No third-party assets. Existing art is reused; cave dressing uses procedural geometry.

## Manual acceptance route

1. Finish and claim The Severed Line. From Halcyon choose Drowned Caves. Verify checkpoint & full supplies. Depth is 1,100–2,000 m and no pressure damage inside the authored corridor.
2. Scan the human account, Vael account, Mara's log, and shrine in any order. Pause/Continue: all persist, and repeat scans never re-award. Verify optional records are optional.
3. Without prerequisites, interact at shrine: actionable missing-evidence instructions, no softlock.
4. Enter an incorrect light pattern; receive readable hint. Finish the correct pattern with keyboard and gamepad. Quit/Continue; translation stays saved.
5. On separate saves, leave/take. Verify exactly one ±15 decision, scenery response, sonar benefit only on take, and no duplicated benefits after checkpoint reload.
6. With the Zone 2 sentinel released and alive, see guide. With capture/loss, guide is absent but shrine reachable.
7. Return to Halcyon and redive. Verify completion and optional records survive.
8. Exhaust oxygen or destroy hull in the caves and verify the existing Halcyon recovery, permanent records retained. Validate a corrupted checkpoint is rejected. Review at 1280×800 and 800×600 with large UI and reduced motion.

**Limits:** No human playtesting has occurred. The final route's pacing and readability must be judged in a build; static code inspection is not a substitute. The following Furnace Vents are not implemented by this work.
