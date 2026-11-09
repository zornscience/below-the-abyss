## Issue
BTA-060 — A listening predator for the Twilight Shelf, and torpedoes as a defensive tool.

One Twilight-only Rift Stalker investigates existing ping/explosion events, senses the vessel before a 2.5 s warning and bounded pursuit, and returns when the player retreats. A close aimed torpedo detonates on its weapon-only collider, briefly stuns it and makes it flee without health, death or rewards. The existing launcher still emits exactly one explosion; no sonar/torpedo cost, old wildlife/predator, depth, research, darkness or schema change.

Base dependency: `ccr-faf5a894-y8zz7k` (`61245be`) because main lacked the corrected “Corrected after reading code” brief. This preserves merged BTA-058/BTA-059 and the correction; no rebase or discarded commits. Do not merge automatically.

The profile uses 1800-u hearing (still limited by emission range; base ping 900), strength 0.2, 40/110/170/130-u/s patrol/investigate/pursue/return, a 450-u sense radius, 6 s pursuit, 700-u target-distance limit, 5 damage every 3 s, a 240-u scare radius and 1.5 s stun + 5 s flee at 190 u/s. The safe upper loop, tether and all required evidence remain outside its territory. Continue resets it quietly to territory without a new save field.

The nearest rule applies to scare-enabled profiles. Only one Stalker exists in production; multiple model instances test arbitration. Existing eel/squid/jelly behavior and damage rules are preserved. Their eligible reactions are not replaced by a global flee/kill-immunity rule.

Acceptance mapping, full profile table/reasons, changed files, exact commands/results, native screenshots at both requested sizes, keyboard/gamepad manual routes, wording flagged for review and limitations: [BTA-060 evidence](https://github.com/zornscience/below-the-abyss/blob/bta-060-listening-predator/docs/testing/bta-060/README.md), [validation](https://github.com/zornscience/below-the-abyss/blob/bta-060-listening-predator/docs/testing/bta-060/validation.md).

Validation: 766 GUT tests (0 failures/errors/skips), eight focused tests/84 assertions, all nine existing route tools plus the new quiet/hunted route tool, 329 script checks/import/startup, 10 Python tests, release safety, actual Linux export positive and all ten negative cases. The quiet full chapter used zero Twilight pings and had no encounter; keyboard and controller both induced warning/pursuit then escaped at 95 hull. No existing assertions or timeouts changed.

Human playtest results for this change do not exist; every number is a hypothesis. Existing illustration/shader reused, no new assets. No physical-controller, Windows/macOS or target-GPU performance claim. The card and one Wick line are flagged for user review in the evidence. Do not merge. Merge approval will only be requested after PR CI is green.
