# Verification — second feedback revision

Pinned engine **4.6.3.stable.official.7d41c59c4**, GUT **9.6.1**.
Base: merged PR #26, `ac8995887f05a0fabc701d9630a293a45bedd4d4`.

| Check | Actual local result |
| --- | --- |
| Full GUT suite | **506/506 passed**, 25,865 assertions, zero failures/errors/skips, **340.524s**. |
| Engine/import/all parsers/startup | **PASS**, exact pinned engine, **218 script checks**, no engine/script errors. |
| Complete production controller route | Passed with actual controller events and real movement: title → dock/talents → radio acceptance → four scans → scared NPC → return → automatic refill/decoding → persistent rewards/Continue. First measured route: **467.7333 simulation seconds**, 100 hull, **72.6004 battery before docking**, battery 100 / ammunition 10 after docking, **four lifetime research points**, no terrain cuts. Final repeat is also run in CI. |
| Native graphics | **12 screenshots**, 1280×800 and 800×600/Large, Compatibility/Mesa llvmpipe under Xorg :99, Dummy audio. Native driver assertions passed; only virtual-display unsupported V-Sync warning. |
| Focused regression follow-up | 31 tests / 337 assertions passed, including old station interaction, revised progression/ordnance, collision and comfort behavior. |
| Python tooling | Existing five-test suite is retained and run locally/in CI. |
| Standalone release / hosted CI | The review PR records actual run/build results and retained artifacts. [Current branch workflow runs](https://github.com/zornscience/below-the-abyss/actions?query=branch%3Aplaytest-feedback-round-two). No queued run is asserted successful by this document. |

[Local GUT summary](logs/gut-summary.log),
[controller route](logs/controller-flight.log), [native capture](logs/native-capture.log).
Complete hosted import/parser/GUT/XML/route/export/smoke logs are workflow artifacts.
Build manifests contain the exact source/merge-ref ID, engine, dirty-state flag and
executable SHA-256; hosted PR-merge builds have different IDs from local branch builds.

The native capture stages positions and is presentation evidence, not route proof.
The separate full-route driver uses actual controller UI/input and no submarine
teleports. The older compact course and first feedback revision remain regression
fixtures; the new integration suite and route explicitly test production MAIN.

[All changed files](changed-files.md) · [API/decisions/manual walkthrough/screenshots/limits](README.md).

The five-person external study is still not run. No physical-controller, hardware
sound, other OS runtime, final-art or human playtime claim is made. The next story
dossier is present; the next region is explicitly not playable yet.
