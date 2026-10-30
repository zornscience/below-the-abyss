# BTA-055: Twilight Shelf expedition and narrative

**Dependency:** built on `bta-054-twilight-environment` (`838a862`), which has not yet
been merged. Review/merge BTA-054 first. This PR targets main; until that merge its
comparison includes the environmental milestone. The BTA-055-only changed-file
inventory and verification are linked below. Do not merge automatically.

The Twilight Shelf now connects the illustrated environment to a playable investigation:
follow severed cables, recover Mara's first field log, record the whaler's untranslated
marking and resolve a trapped luminous sentinel encounter. West-first and east-first
approaches work; two extra field loggers are optional. Return through the existing
ascent tether, refit and intentionally archive the Halcyon debrief.

- Reuse scientific scanning, sonar wavefront discovery, temporary passive contacts,
  MissionService, StoryState, existing acoustic creature/navigation and shared UI.
- Release/capture take six simulation seconds, can be cancelled and pause correctly.
  Capture requires confirmation and living delivery. Killing the animal records a
  loss, never a live specimen, and leaves the main evidence route completable.
- Choice +/-15 hidden Resonance; future-guide/wary/loss flags, no numeric score.
- Atomic one-time 2-RP debrief; captured living delivery adds 1 RP and a unique
  additive +100 sonar range, preserving ping cost/cooldown and paid talents.
- Schema 10, same twelve fields/checkpoint file. Versions 1–9 and 2/5/6 mission
  catalogues preserve their records. No new save file/ledger/economy/dispatcher.
- Original illustrated sentinel and net masters with provenance, comfort-aware
  motion, quieter curved cable and existing compact responsive dialogs.
- Region-only resource budget supports a conservative 45-minute continuous-thrust
  model with ten pings and >25% battery/oxygen reserve; no refill on Continue.

[Implementation, exact commands and manual route](https://github.com/zornscience/below-the-abyss/blob/bta-055-twilight-expedition/docs/testing/bta-055/README.md)
· [BTA-055-only changed files](https://github.com/zornscience/below-the-abyss/blob/bta-055-twilight-expedition/docs/testing/bta-055/changed-files.txt)
· [Artwork provenance](https://github.com/zornscience/below-the-abyss/blob/bta-055-twilight-expedition/assets/art/twilight/sentinel-provenance.json)

Final automated results, native screenshots and export identity are recorded in the
linked evidence report once verification completes. No hosted-CI or human acceptance
claim is made in advance.

**Pacing limit:** the 30–45-minute main expedition is a novice-human target. Preliminary
experienced automated deep routes took approximately 3:46 keyboard and 5:00 controller,
without torpedoes. Those are not human playtests. Final measured values and native
captures are retained honestly; human comprehension, pacing and visual acceptance
remain open review gates. No artificial delays pad the route.

No Drowned Caves gameplay, glyph translation, Mara-fate/Choir/Crane-secret reveal,
ending, campaign-wide economic redesign or combat framework. The whaler is not
Lantern-1. New logs/dialogue are authored adaptations of the Bible, not quotations.
