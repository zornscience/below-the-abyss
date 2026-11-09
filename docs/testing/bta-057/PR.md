**Issue:** BTA-057 — Twilight Shelf sonar-driven visibility, Phase 1.

**What changed:** Twilight is dim but readable outside a short headlight/passive
radius. Accepted sonar pulses reveal scenery and cached collision-derived outlines
at wavefront arrival, then fade. A free close terrain cue, textual proximity/pulse
status, and Standard/Reduced accessibility setting preserve quiet navigation.
Existing headlight stops, simulation clock, paid emission and acoustic dispatcher
remain authoritative. In-flight profile changes cannot change accepted pulse speed.

**Out of scope / deliberately not changed:** Sunlit Shallows lighting, map screen,
expedition schema, story/research/economy/combat, mission IDs, authored geometry and
ShelfPrototype architecture. No new media assets, dependencies, regions or Steam code.

**Acceptance criteria evidence:**
[Complete mapping and evidence](https://github.com/zornscience/below-the-abyss/blob/bta-057-sonar-visibility/docs/testing/bta-057/README.md).
Rendering reads actual CollisionPolygon2D data; no second hand-authored terrain.
The vessel/HUD remain legible. High Contrast boosts visibility, Reduced Flashing
softens echoes, and pauses/restarts clear or freeze transient presentation correctly.
Personal preferences retain legacy defaults; no terrain map persistence is added.

**Automated test command and result:** 739/739 GUT tests (44,767 assertions), 310 parser checks plus final follow-ups, startup, all eight
existing verify routes, 10 Python tests and release lint passed. Exact final counts, commands,
logs and export source identity are in the evidence document. No assertions were
loosened and no timeouts were raised. The suite caught a controller focus regression;
placing Darkness after existing toggles preserved the old navigation assertions.

**Release safety:** main lacked the requested ReleaseSmoke/linter, so both are added.
Five existing Twilight registration side effects now execute outside assert(). The
release smoke checks real accepted emission and advancing reveal-clock wiring.
The same extracted exported binary passes normally and fails with
`RELEASE_VISIBILITY_WIRING_FAIL` after deliberately disconnecting that subscription.
CI retains the positive, negative and static assertion-safety checks.

**Manual playtest steps:** In Twilight, approach terrain quietly, ping with F / X or
remapped controls, watch arrival/fade and move away from the fixed pulse origin.
Pause/restart/Continue. Select Reduced using keyboard/controller, explicitly Save,
quit/reload; test High Contrast/Reduced Flashing/Motion at both window sizes. Confirm
Sunlit Shallows remains lit and the map/progression are unchanged. Full route in README.

**Screenshots/video (if visual):** Eight actual native Godot captures: lit diagnostic
baseline, Standard darkness, mid-pulse and Reduced at 1280×800 / keyboard and 800×600 /
controller. Both inputs select and save Reduced through real focus navigation.
[Gallery](https://github.com/zornscience/below-the-abyss/blob/bta-057-sonar-visibility/docs/testing/bta-057/README.md#native-comparison-and-visual-inspection).

**Known limitations and follow-up issues:** **60 FPS has NOT been established.**
Software llvmpipe measurements are 145.038→190.268 ms/frame at 1280×800 and
30.512→52.454 ms/frame at 800×600. The software host was below 60 FPS even lit;
physical baseline-GPU profiling is still required. This is a performance acceptance
gap, not a claim of optimization or target compliance. Static collision cache and
eight visual pulse slots match current authored content/default profile.
**No human playtest results exist. None are claimed.** Native/automated inputs are
not physical-controller or human usability acceptance. No automatic merge.

**Cross-platform impact:** Shared Godot 4.6.3 Compatibility shader and GDScript;
Linux standalone tested. Windows/macOS/physical GPU validation remains unperformed.

The branch is pushed. Automated draft creation was blocked by GitHub API `Forbidden`;
no hosted Actions status or actual PR creation is claimed. Local evidence is complete.
