## Issue
BTA-059 — Depth hazard with a hull-rank gate and a funded research budget.

Adds an optional 1120 m basin, seven optional studies, and a Twilight-only hull-failure/respawn panel. The existing 2 s grace / constant 4 hull per second rule is unchanged. Rank 2 is safe at 1150 m; measured lower-rank crossings use about 24.22 s / 19.57 s of the 27 s full-hull budget. All required evidence and the existing safe upper loop remain outside the gate.

Base dependency: `ccr-faf5a894-y8zz7k` (`e5af1ca`) because main lacked the corrected decision G. This preserves all earlier commits, including BTA-058. Do not merge automatically.

**Proposed penalty for approval:** restore hull at the ascent tether; retain actual battery, oxygen, ammo and all permanent records/choices; cancel only unfinished scan progress. There is no unbanked-sample inventory. Zero-hull failure and respawn use existing atomic schema-10 snapshots, with no new fields. Oxygen depletion remains a known limitation.

**Proposed economy for approval:** preserve Sunlit's rates and two-point allowance; add a separate 40-XP/study Twilight allowance capped at two points (aggregate cap four). Nine optional safe-shelf subjects are available: seven scans ×40=280 XP→2 points, plus 2 commissioning +1 survey +1 decode=6 total, versus rank 2's 2+3=5 cost. Five new safe subjects alone fund the same two-point allowance for old saves whose prior studies are imported. Historical records gain no retroactive XP; no point loss or repeat rewards. End-of-chapter awards are excluded from the gate budget; free reassignment is unchanged.

Changed files, acceptance mapping, depth/timing table, full XP/old-save arithmetic, exact commands/results, eight native screenshots, keyboard/gamepad manual route and limitations: [BTA-059 evidence](docs/testing/bta-059/README.md), [validation](docs/testing/bta-059/validation.md).

The card wording is flagged for review in the evidence. Human playtest results do not exist; every number is a hypothesis. Rank 1 has more pressure slack than rank 0 under the unchanged constant-damage rule. No Windows/macOS, physical-controller or target-GPU performance acceptance is claimed.

Economy caveat for approval: a save already carrying the full two-point Sunlit bonus can reach eight pre-debrief points after the new allowance, leaving three spare rather than one. Preserving earned points and raising the allowance cannot guarantee a single spare point for every existing save. The stated six-point target excludes an already-earned Sunlit bonus.

Validation: 758 GUT tests passed (0 failures/errors/skips), six focused tests/130 assertions, all eight existing route tools plus the new depth route, 10 Python tests, release-safety lint, 321 script checks/import/startup, real Linux export positive/six negative cases, and eight native captures. Full results and limitations are linked above.
