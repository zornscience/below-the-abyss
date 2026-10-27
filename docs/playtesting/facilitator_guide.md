# Facilitator protocol and observation worksheet

**Study status: NOT RUN. Zero external participants or evaluated human results are
claimed by this toolkit.** Recruit at least five people who have never played
Below the Abyss. Do not equate automated sessions or repeated runs with people.
Obtain permission for observation, feedback and optional local report sharing
separately. No recruitment messages, uploads or external contacts are automated.

## Before a session

Use the verified package/manifest and a fresh isolated OS/data profile for each
participant. New Expedition retains permanent progress and is NOT profile isolation.
On Linux a facilitator can launch from a terminal with:

```sh
XDG_DATA_HOME="$PWD/participant-data" XDG_CONFIG_HOME="$PWD/participant-config" XDG_CACHE_HOME="$PWD/participant-cache" ./below-the-abyss.x86_64
```

Use a different empty directory per participant, stored privately outside the
repository. Do not use names as directory/codes in shared reports. A participant
may change accessibility/audio/input settings before starting. Confirm the normal
start screen, no development controls, and recording OFF. Never enable recording
on a participant's behalf. Do not give route solutions, screenshots of discoveries,
or the developer narrative walkthrough. Use the same neutral briefing each time:

> Explore independently, using the briefing and instruments inside the game. You
> may pause, change settings, stop, or ask for technical help. Feedback is useful
> even if you do not finish. Optional local reporting can be declined.

## Consistent observation

1. Give the participant the build and spoiler-free player guide, with no walkthrough.
2. Explain how to report technical problems; check consent separately for observation
   and optional local data. Do not collect identities in worksheets or reports.
3. Start a stopwatch at intentional expedition departure; note reading/menu time
   if practical. Record the exact chosen timing rule consistently for all five.
   Telemetry starts only at consent and may cover a different window.
4. Let the person explore. Observe hesitation, repeated actions and misunderstandings
   without immediately helping. Do not interpret silence as understanding.
5. Intervene for technical failure, accessibility need, distress, explicit request,
   or sustained inability to proceed. Record the time, reason and exact assistance.
   Mark the outcome assisted; do not report it as unaided completion.
6. Record chapter completion only when its in-game debrief/conclusion occurs.
   Note wall completion duration, or mark incomplete/unknown. Do not replace missing
   times with route-automation timings. Stop if requested; never pressure completion.
7. Collect the short feedback form immediately, including interest in continuing.
8. Ask whether the participant voluntarily wants to share a selected local report.
   Link it to feedback only when an explicit shared session ID and permission are
   provided. Reports without consented links remain separate aggregate sessions.
9. Remove identifiers from free-text observations before sharing; store consent/contact
   administration separately from anonymous study data. Agree retention/deletion with
   participants; this offline toolkit does not manage recruitment/contact details.
10. After at least five unfamiliar people, evaluate outcomes, interventions and
    repeated problems. Review critical blockers first. Create a concrete follow-up
    plan; do not mark the external acceptance gate complete merely because files exist.

## Per-participant worksheet (blank)

Anonymous code (e.g. P01): ____  Build ID: ____  Unfamiliar: Yes / No
Observation permission: ____  Optional telemetry chosen by participant: ____
Control method (keyboard/controller; no device serial): ____
Window size / accessibility or mute adjustments, if volunteered: ____
Timing rule and departure start: ____  End / stopped: ____
Chapter completed: Yes / No / Unknown  Assisted: Yes / No
Measured completion minutes (completed only): ____

| Relative minute | Observable action / problem | Expected vs actual (participant's words) | Intervention / reason | Severity |
| --- | --- | --- | --- | --- |
| | | | | |

Navigation trouble tags: route_finding / return_route / map / landmarks / none
Usability issue tags: crash / save_load / softlock / objective_clarity / navigation /
sonar / controls / readability / audio / narrative

- **Critical:** crash, corrupted/lost progress, softlock, cannot operate an essential
  action. Stop or assist promptly; preserve an isolated affected profile with consent.
- **Major:** repeated confusion or a needed gameplay intervention, though progress
  remains possible. Record evidence and context rather than guessing a solution.
- **Minor:** inconvenience, cosmetic problem or a single recoverable hesitation.

Keep nuanced, redacted observations with the original anonymous forms. The analysis
input intentionally contains coded tags rather than unrestricted free text.
