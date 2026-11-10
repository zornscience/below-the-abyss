Add a disposable combat test box to the playtest export so torpedo combat, a short
sonar stun, a sound-hunting Stalker and two handling profiles can be evaluated
before any campaign combat decision. Enter through the existing Playtest page's
developer button; ordinary title UI has no combat entry.

Four sound-triggered swarmers telegraph small hull bites and die to one torpedo.
Accepted normal-cost pings stun nearby eligible swarmers for two seconds; the
existing unkillable Stalker keeps its torpedo scare/stun behavior. Hull zero
returns to the isolated refit. Quiet travel, calm effects and keyboard/controller
paths are supported. WEIGHTY references the unchanged campaign motion Resource;
RESPONSIVE quadruples acceleration and lowers damping, giving faster reversal
and longer hands-off coast. No campaign, save schema, assets or rewards change.

Base: `main` at `40de716`; branch `testbox-combat`, preserving all prior commits.

- [Changed-file inventory](https://github.com/zornscience/below-the-abyss/blob/testbox-combat/docs/testing/combat-testbox/changed-files.txt): separate scene, Resource/state/stun
  modules, optional local-report extension, small launcher composition ports,
  export-only Playtest entry/proof, CI and tests, screenshots and evidence.
- [Acceptance mapping, all tuning values/reasons and measured handling table](https://github.com/zornscience/below-the-abyss/blob/testbox-combat/docs/testing/combat-testbox/README.md).
  Actual-input rest-to90: 1.8 / 0.45 s; reverse-to90: 3.8 / 0.95 s; top speed
  240 for both; hands-off stop 197.588 / 264.116 units at 60 Hz.
- [Commands/results](https://github.com/zornscience/below-the-abyss/blob/testbox-combat/docs/testing/combat-testbox/VALIDATION.md): release-safety lint; 10 Python tests;
  Godot import/parser/startup; **795/795 GUT tests**; **all twelve verification
  routes**; actual release export, positive and **all nineteen expected negatives**.
  Six combat negatives independently remove entry, swarmer registration, Stalker
  registration, stun, responsive selector and weighty selector wiring.
- [Ten native screenshots, 1280 × 800 and 800 × 600](https://github.com/zornscience/below-the-abyss/blob/testbox-combat/docs/testing/combat-testbox/README.md#verification-screenshots-and-manual-play),
  [keyboard/gamepad manual routes](https://github.com/zornscience/below-the-abyss/blob/testbox-combat/docs/testing/combat-testbox/README.md#keyboard-route), and
  [three-person facilitator sheet with the handling question](https://github.com/zornscience/below-the-abyss/blob/testbox-combat/docs/testing/combat-testbox/FACILITATOR.md).
- Privacy: existing observer/store, fresh explicit opt-in, fixed combat categories
  and rating, local JSON/text only; campaign report v1 remains unchanged and box
  reports use v2. Expedition save schema remains 10. No network or automatic sharing.

**Human playtest results do not exist. Every tuning number is a hypothesis.**
Synthetic input/rating checks establish behavior and storage, not fun or preference.
The requested market-review document was absent on the base; no missing findings
were invented. Other limitations: no physical gamepad/platform certification,
small-screen world-caption clipping mitigated by existing full HUD notices,
unproven real-player fairness, and a native fixture audio-thread shutdown warning
resolved with a fixture-only handoff (earlier warning log retained). See the full limitations/evidence.

Review only. Do not merge or request merge until this PR's own CI is green.
