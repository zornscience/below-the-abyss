# Three-person combat/handling test — facilitator sheet

**No human results have been collected. All numbers are hypotheses.** Recruit
three people who have not seen the game. Ten minutes of play each, with a short
consent/setup explanation before the timer. Use the same build and control device
within each person's two handling runs. Include at least one keyboard and one
physical-gamepad participant. Record only anonymous participant numbers on your
separate notes, not names or identifying information.

## Preparation

Open the playtest export's existing Playtest page → Developer / Open combat test
box. Explain movement, ping, torpedo, pause and cradle refit controls; do not tell
the participant which strategy is best. Demonstrate text/shape warnings with sound
muted if requested. Recording is optional: show the local-only explanation and
let them choose. Declining must not prevent play. No screenshots, inputs, hardware
identity or automatic uploads are logged. Ask separately before sharing a report.

Use WEIGHTY then RESPONSIVE for people 1 and 3; reverse that order for person 2.
This tiny sample is exploratory, not a controlled statistical result. If possible,
avoid telling them which profile is expected to feel better. The developer panel
necessarily reveals the selected name, so record that potential bias.

## Ten-minute schedule

| Time | Facilitator action |
| --- | --- |
| 0–5 min | Select first profile, refit/reset wave, start a fresh optional local recording. Say: “Explore, try the controls, and deal with the creatures however you like. Please say what you expect and what you notice.” Let them choose quiet play, stun, shooting or escape. Note actual first engagement on a stopwatch, the first excitement and first boredom moment. Avoid leading strategy hints. |
| At 5 min | Pause. Ask: **“How did the handling feel: weighty, about right, sluggish, or twitchy? Why?”** Let them choose the matching Finish option, which ends/exports that session. Note overshoot, braking and direction-change comments separately. Refit/reset wave, select other profile, and start a new optional recording so rating/time are attributable. |
| 5–10 min | Same open task with the second profile. Invite a short repeated course around the columns and through a mouth if they have not compared movement. Note help given, collisions, readable/missed warnings, use of stun/tunnels/running, and an actual Stalker chase or its absence. |
| At 10 min | Ask the handling question again and finish that session. Ask: “Which handling would you keep, and why?”; “Would you play another ten minutes: yes or no, and why?”; “What caused the hits you took?”; “Was any chase tense?”; “Was this more exciting than quiet exploration?” |

If they die, observe whether the refit return and resume are understood; do not
force a death. Stop immediately if they want to stop. Do not count a facilitator
demonstration as their engagement or stun use. Record interruptions and assistance.
If a report was declined or failed to write, use consensual manual notes and label
missing metrics; do not invent them. Treat wall-clock pause time separately from
active play. Keep the full ten-minute play allowance where interruptions permit.

## Per-person notes (two rows, one per profile)

| Person / order / device | Profile / actual active minutes | First engagement | Deaths / collision deaths | Collisions/min / pings/min | Torpedoes / stun uses | Swarm kills / stuns / hunter scares | Rating + reason |
| --- | --- | --- | --- | --- | --- | --- | --- |
| | | | | | | | |

From readable local summaries, copy actual counters and active duration.
Collisions/min = collisions × 60 / active_seconds; pings/min likewise. Keep the
JSON files local unless the participant chooses to share those files only.
`unrated` is missing feedback. Synthetic fixture ratings are excluded entirely.
Separately note first excitement/boredom, cause of any confusing hit, warning
readability, tunnel/stun/escape choices, tense-chase description and desire to
continue. Keep build ID, profile order and any comfort changes with the notes.

## Decision after all three

Use the brief's exploratory criteria: **Go** if most want another ten minutes
and a Stalker chase is described as tense; **Change** if players ignore stun,
spam ping or run from everything; **Stop** if nobody finds combat more exciting
than current Twilight. Discuss handling separately: fast reversal may improve
control while longer coasting worsens stopping. Report all three participants,
including negative/unfinished sessions. Three people cannot establish a market
claim or authorize campaign integration. Bring the observed evidence back to the
user before deciding any next issue.
