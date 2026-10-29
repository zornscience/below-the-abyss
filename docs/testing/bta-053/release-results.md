# BTA-053 release verification

Pinned Godot `4.6.3.stable.official.7d41c59c4`, GUT 9.6.1. Local managed Linux host,
2026-10-29. Main base `2a81d25` (merged PR #36).

| Check | Result |
| --- | --- |
| Entire GUT suite | 686/686; 42,721 assertions; 559.381 s; [text](logs/gut.txt), [JUnit XML](logs/unit-tests.xml) |
| New exact headless handoff matrix | 4/4 processes; fresh/Continue × keyboard Observe/controller Collect; [log](logs/handoff-headless.txt) |
| Existing canonical chapter and recovery matrix | 12/12 processes; [log](logs/canonical-routes.txt) |
| Legacy expanded/revised expeditions and 8-process bloom choice matrix | Passed; [log](logs/legacy-routes.txt) |
| Python playtest analysis | 7/7; [log](logs/python.txt) |
| Native input-driven walkthrough | 4/4 processes; keyboard 1280×800 and controller 800×600 Large Text/High Contrast; [captures and logs](README.md#verification-results) |
| Final import/parser/startup | Passed; **286 scripts**; [log](logs/validation.txt), [inventory](logs/parser-inventory.txt) |
| Clean Linux release export and extracted-package smoke | Passed from clean source commit `0d940c31ed1811d35de3d71d490632a4c10b9902`; [manifest](logs/manifest.json), [build](logs/linux-export.txt), [export engine](logs/export-engine.txt), [standalone](logs/standalone-smoke.txt), [result](logs/standalone-result.txt) |
| Hosted GitHub Actions / PR | API blocked: `Post "https://api.github.com/graphql": Forbidden`; branch pushed, no hosted run observed; [attempt](logs/github-pr-attempt.txt) |

No human playtest, physical gamepad test, real-GPU performance measurement or
complete Chapter 2 narrative/pacing claim. Native screenshots use Godot Compatibility
under Xorg/Mesa llvmpipe with muted audio; on-demand rendering is not a benchmark.

The exported package is `build/below-the-abyss-playtest-linux-0d940c31ed18.zip`.
Its embedded executable SHA256 is
`27df6dc59d84e2c5c9287b418a0bd548138a438f47f1674ce866cd887a678921`.
The manifest reports `development_dirty: false`. The following evidence-only commit
changes documentation/logs; runtime content is identical to the tested export.
Normal native runs report the software driver's unsupported-VSync warning; no Godot
engine/script errors occurred. Headless validation and standalone launch logged no errors.

Open the prepared review at
[main → bta-053-chapter-handoff](https://github.com/zornscience/below-the-abyss/compare/main...bta-053-chapter-handoff?expand=1),
using [PR.md](PR.md) as the body. No PR was created automatically because the current
managed network policy excludes the required API domain. No merge was attempted.
