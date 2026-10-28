Halcyon now launches above an open-water shelf with optional excavation caves. The main expedition remains completable without firing a torpedo. This implements the requested instrument, radio, scanning, research and presentation polish while preserving story locations, stable IDs and atomic saves.

- Resource-deck ammunition; removed floating helper instructions and redundant text-scroll buttons. Focus reading panes to scroll with keyboard/controller, wheel or scrollbar.
- Typewriter incoming radio, automatic tail scrolling/dismissal and retained readable archive. Reduced Motion uses immediate text; automatic dismissal never accepts a mission.
- Direct visible scanning with terrain visibility checks; hidden buoy still requires sonar. Cosmetic returning echoes reuse outbound arrival and never add acoustic events.
- Five icon-labelled research branches, including torpedo acceleration/blast area and engine acceleration. First new rank costs 2 RP, subsequent ranks 3 RP; finite budget and free reassignment.
- Above-water station, fixed ocean ceiling, greater descent, optional blocked tunnels, first-surface headlight illumination, animated existing fauna, red beacon, detailed torpedo artwork and original quiet Music-bus score.

**Validation:** 665/665 GUT tests (41,641 assertions); pinned Godot import, 280 parser checks plus 11 rechecks and startup; 12 canonical input processes; eight story-choice input processes; both legacy full routes; seven Python tests; zero-excavation fresh/Continue; clean Linux export and extracted standalone smoke. Actual native captures cover 800×600 Large Text/High Contrast/reduced settings, 1280×800 and 1920×1080. These are local workflow-equivalent results; GitHub Actions has not been run because this environment's PR API request returns Forbidden.

**Saves:** schema 8 migrates versions 1–7 in the existing checkpoint/backup/recovery path. Old purchased sonar/hull fits preserve their effects and original paid cost. New capabilities reconstruct baselines; in-flight torpedoes snapshot their blast parameters. Stable IDs, permanent records and old terrain journals remain. Blocked old poses use validated-base relocation with resources retained. No additional save file.

[Complete implementation, manual playtest route, commands, limitations and 29 native screenshots](https://github.com/zornscience/below-the-abyss/blob/bta-052-surface-expedition-polish/docs/testing/bta-052/README.md).

Review limits: no human playtest, audible mix approval or target-GPU 60 FPS claim. Artwork provenance and project licensing status are documented. No new region, mission, economy or campaign architecture. Do not merge automatically.
