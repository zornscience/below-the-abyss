# Verification record — feedback iteration

Pinned Godot: **4.6.3.stable.official.7d41c59c4**, GUT **9.6.1**.
Source baseline for these changes: `519e98f3ed58ff5ec660ff14b220d1a9e3c65bcf`
(PR #25, not merged when this branch was created).

| Check | Observed result |
| --- | --- |
| `python3 tools/run_tests.py` | 471/471 passed, 25,655 assertions, zero failures/errors/skips, 305.501s. One final legacy-profile regression subsequently added and independently passed (6 assertions); final CI runs the resulting 472-test suite. |
| Post-run Continue/wildlife reset regression | Passed, 7 assertions. Confirms excavation replay and newly added outer grazers reset on Continue. |
| Full controller expedition | Passed: four required scans, return/debrief, **100 hull**, battery **73.6624**, oxygen **90.2625**, **zero terrain cuts**. Route telemetry **320.7167 simulation seconds**; excludes menus and is not human completion time. |
| Native graphical capture | Nine actual Godot screenshots, 1280×800 and 800×600/Large; Compatibility renderer/Mesa llvmpipe, Xorg :99, Dummy audio. Assertions passed. Source fixture stages positions intentionally. |
| Import / all scripts / startup | Passed: headless import, **201 script checks**, startup smoke; no engine/script errors. |
| Python tooling | **5/5 passed**. |
| Hosted CI / Linux package | Review run and package artifact recorded below once available. |

[Native capture log](logs/native-capture.log), [controller route log](logs/controller-flight.log),
[local GUT summary](logs/gut-summary.log). Complete CI logs are workflow artifacts.
The only native warning was the virtual display's unsupported V-Sync setting;
no engine/script errors were observed. No physical controller, hardware audio,
Windows/macOS package or external five-person study was claimed.

All feedback-only changes: [file inventory](changed-files.md).

Manual acceptance course and known prototype limits: [feedback README](README.md).
