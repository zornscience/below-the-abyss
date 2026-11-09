## Issue
BTA-058 — Make resources matter on the Twilight Shelf.

Twilight pings and torpedoes now each cost 5 battery, selected by the existing chapter journey's active Twilight phase from a Resource. Slow travel drain, oxygen, hazards, Sunlit/legacy tuning and schema 10 remain unchanged. The regional sonar cost survives upgrade reapplication and Continue. Insufficient energy rejects actions without spending ammunition or starting cooldown; thrust and tether refit remain available at zero battery.

Base dependency: main lacked the approved brief, so this branch starts from `ccr-faf5a894-y8zz7k` (`df06463`), preserving its fixes. The user's issue instruction approves the brief despite its draft header. Do not merge automatically.

Changed files and acceptance mapping, tuning arithmetic, native warning captures, exact commands/results, keyboard/gamepad manual steps and limitations: [BTA-058 evidence](docs/testing/bta-058/README.md), [validation](docs/testing/bta-058/validation.md).

Budget: 100 battery / 5 = 20 standalone pings or 20 energy-funded shots (magazine remains 10). A 30-minute expedition at 50% thrust uses 13.5 travel battery; three shots cost 15, leaving 14 pings and 1.5 reserve. At 45 minutes the same assumptions allow 12 pings. Idle empties in 555.56 min; full thrust includes idle and empties in 138.89 min. Oxygen stays 83.33 min—an observation for user review.

Human playtest results do not exist. Every tuning number is a hypothesis for the user's playtest; refitting once and felt hesitation remain unverified targets. No cross-platform or physical-GPU performance acceptance is claimed.

Validation: final full GUT PASS: tests=752, passed=752, failures=0, errors=0, skipped=0; 315 script checks/import/smoke, 10 Python tests, release safety, all eight route tools, real export positive/three negative cases, and both native warning sizes passed.
