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
| Final import/parser/startup | Finishing; result will be added before review |
| Clean Linux release export and extracted-package smoke | Next, after the clean source commit; result will be added before review |
| Hosted GitHub Actions | Not yet observed; local checks are not a hosted run |

No human playtest, physical gamepad test, real-GPU performance measurement or
complete Chapter 2 narrative/pacing claim. Native screenshots use Godot Compatibility
under Xorg/Mesa llvmpipe with muted audio; on-demand rendering is not a benchmark.
