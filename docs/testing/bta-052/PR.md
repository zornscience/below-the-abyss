Halcyon now launches above an open-water shelf with optional excavation caves. This branch implements the requested instrument/radio/research polish and the subsequent visual/exploration review, preserving story IDs and atomic saves. The first expedition remains completable without firing a torpedo.

The latest review revision:

- Replaces the underwater baked-wave background with original horizon-free painted water and clips distant relief below the single ocean surface.
- Rounds shared rock/collision/map contours and gives all destructible plugs a distinct natural warm ochre sediment material against cool protected basalt.
- Removes the returning sonar effect, restoring main's original outward-only pulse implementation and existing timed reveals.
- Adds an alternating-baffle rock shelter around the unchanged buoy location. Its damaged reflector requires a clear angle within 650 units; the scanner cannot read through terrain. No combat/excavation is required.
- Improves propulsion-driven eel/turtle/hammerhead deformation and restores actual observer swimming. Expands hammerhead territory and pursuit, retaining a warning, modest cooldown-limited head ram and shallow escape.
- Adds original illustrated Okafor/Crane/Mara/Wick radio portraits with explicit speaker text. Radio stays bounded above secondary instruments and below ammunition at 800×600 Large Text.
- Hides obsolete canonical cave/overlook echoes, prototype predator/wreck/ink and technical chart labels while preserving old IDs/data and the development fixture.

The earlier work on this branch remains: resource-deck ammunition; focusable scrolling instead of redundant Text Up/Down; typewriter/automatic radio preview with readable archive; direct visible scanning; five icon-labelled finite research branches; above-water station, optional tunnels, local headlight illumination, red beacon, painted torpedo and quiet Music-bus score.

**Current local verification:** 669/669 GUT tests, 42,512 assertions; nine focused review regressions; pinned Godot 4.6.3 import, 280 parser checks and startup; native full keyboard Observe at 1280×800 and controller Collect at 800×600 Large Text/High Contrast/reduced settings/mute with zero shots; 1920×1080 menu/departure/map spot check; seven Python tests. Remaining checkpoint-route and Linux export results are recorded in the revision report after completion. These are local workflow-equivalent results, not a claim of observed GitHub Actions status.

**Saves:** schema 8 (versions 1–7 migrate through the existing checkpoint/backup path). This review adds no schema, save file or permanent flag. Blocked old poses use existing safe-base relocation, retaining reserves/evidence. Already-known buoys stay known. No new acoustic events/history semantics, choice rewards or mission ledger.

[Current review report: 28 native screenshots, comparison links, commands, manual route and limitations](https://github.com/zornscience/below-the-abyss/blob/bta-052-surface-expedition-polish/docs/testing/bta-052/revision/README.md). [Earlier branch implementation and schema migration](https://github.com/zornscience/below-the-abyss/blob/bta-052-surface-expedition-polish/docs/testing/bta-052/README.md).

Review limits: no human playtest, audible mix approval or target-GPU 60 FPS claim. Portrait appearances are provisional art proposals where canon specifies no physical features. Original-master provenance/imports and pending project licensing are documented. No Zone 2, mission, economy or replacement architecture. **Do not merge automatically.**
