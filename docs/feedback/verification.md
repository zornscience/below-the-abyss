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
| Hosted CI / Linux package | [PR #26 checks](https://github.com/zornscience/below-the-abyss/pull/26/checks) show the current review head and its retained validation/package artifacts. This records real runs, not a claim that a queued run passed. |

[Native capture log](logs/native-capture.log), [controller route log](logs/controller-flight.log),
[local GUT summary](logs/gut-summary.log). Complete CI logs are workflow artifacts.
The only native warning was the virtual display's unsupported V-Sync setting;
no engine/script errors were observed. No physical controller, hardware audio,
Windows/macOS package or external five-person study was claimed.

## Clean local standalone package

Built from committed source `ca3d8a03765a7db5c7301f5efefc5f8c7fa4d758`
(the following documentation-only commit does not change gameplay):

- ZIP: `build/below-the-abyss-playtest-linux-ca3d8a03765a.zip`.
- Binary SHA-256: `88ed2e2a23c76c5c16d0c0b7d99284ebbf53ad61a85255b2cb058a35a6df24f1`.
- Extracted actual release executable launched independently: **PASS**, local
  telemetry OFF by default. No editor/source tree required to run the game.
- An external input driver run with pinned Godot `--main-pack` from `/tmp` repeated
  the entire chapter against embedded exported content: **PASS**, identical
  320.7167s telemetry, 100 hull, 73.6624 battery, 90.2625 oxygen, zero cuts.
- Exported content probe confirmed playtest feature ON, GUT/test drivers and the
  legacy fixture absent. The native staged capture also passed against the pack.
  The pinned engine is used only by the external test harness; the included release
  executable runs the game independently.

[Standalone smoke](logs/standalone-smoke.log),
[packed controller flight](logs/packed-controller-flight.log),
[packed native capture](logs/packed-native-capture.log).
The hosted package has its own build/manifest ID from GitHub's PR merge ref; use its
artifact manifest rather than assuming it has the local package's SHA-256.

All feedback-only changes: [file inventory](changed-files.md).

Manual acceptance course and known prototype limits: [feedback README](README.md).
