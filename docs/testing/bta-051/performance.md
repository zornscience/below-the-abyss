# BTA-051 measured performance

Godot 4.6.3 Compatibility on X11 / Mesa llvmpipe, two raster threads.
Separate runs on the same cloud VM, no concurrent Godot workloads. No fixed FPS.
Each live sample has 20 warm-up frames and 60 wall-frame intervals, while normal
MAIN simulation runs. Frames include catch-up physics and shared-host variation.
Process/physics and memory columns are final monitor snapshots, not GPU timers.
Median uses the upper middle sample; p95 uses index floor(N*0.95), matching baseline.

| Shared view / mode / width | Before median/p95 ms | After median/p95 ms | Draw calls before/after | Texture MiB before/after | CPU process/physics after ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1280-normal-departure | 81.85 / 115.83 | 89.85 / 119.24 | 288 / 281 | 106.09 / 114.63 | 92.73 / 8.94 |
| 1280-normal-plankton | 82.26 / 98.16 | 99.61 / 135.99 | 285 / 281 | 106.09 / 114.63 | 97.02 / 25.64 |
| 1280-normal-twin-spires | 68.78 / 80.64 | 94.78 / 192.62 | 80 / 81 | 106.09 / 114.63 | 171.38 / 13.08 |
| 1280-reduced-departure | 75.04 / 86.03 | 106.14 / 262.20 | 285 / 279 | 106.09 / 114.63 | 165.62 / 9.42 |
| 1280-reduced-plankton | 79.59 / 126.90 | 104.90 / 138.75 | 284 / 280 | 106.09 / 114.63 | 139.89 / 11.36 |
| 1280-reduced-twin-spires | 68.86 / 95.04 | 84.39 / 122.65 | 78 / 79 | 106.09 / 114.63 | 81.44 / 8.21 |
| 1920-normal-departure | 130.63 / 207.22 | 163.95 / 242.43 | 298 / 289 | 114.76 / 123.30 | 189.07 / 8.31 |
| 1920-normal-plankton | 180.36 / 220.46 | 221.79 / 436.05 | 302 / 296 | 114.76 / 123.30 | 188.93 / 18.98 |
| 1920-normal-twin-spires | 125.28 / 215.35 | 163.81 / 255.07 | 87 / 89 | 114.76 / 123.30 | 153.01 / 6.95 |
| 1920-reduced-departure | 178.06 / 508.22 | 145.69 / 213.46 | 295 / 287 | 114.76 / 123.30 | 165.28 / 13.51 |
| 1920-reduced-plankton | 147.34 / 263.02 | 223.21 / 397.00 | 300 / 294 | 114.76 / 123.30 | 328.48 / 15.37 |
| 1920-reduced-twin-spires | 172.39 / 681.73 | 157.25 / 281.71 | 85 / 86 | 114.76 / 123.30 | 140.18 / 10.46 |
| 800-normal-departure | 43.88 / 69.93 | 54.20 / 88.04 | 81 / 78 | 101.81 / 110.35 | 55.28 / 4.71 |
| 800-normal-plankton | 55.81 / 113.16 | 59.61 / 83.36 | 266 / 264 | 101.94 / 110.48 | 75.05 / 6.58 |
| 800-normal-twin-spires | 39.59 / 160.84 | 43.08 / 79.58 | 69 / 66 | 101.94 / 110.48 | 61.04 / 4.25 |
| 800-reduced-departure | 37.94 / 55.65 | 56.50 / 98.08 | 78 / 76 | 101.94 / 110.48 | 47.45 / 13.26 |
| 800-reduced-plankton | 43.55 / 73.02 | 69.84 / 88.29 | 265 / 263 | 101.94 / 110.48 | 70.74 / 7.41 |
| 800-reduced-twin-spires | 33.55 / 58.97 | 60.95 / 88.58 | 70 / 65 | 101.94 / 110.48 | 56.50 / 11.24 |

Shared views have identical player coordinates, zoom and old camera framing,
checked by the capture tool. The old camera limits are applied in this fixture
only. Terrain/state intentionally differ: this is not identical physics geometry.
The old emergency-buoy pose is retained for diagnostic context but excluded
from the shared-view comparison; the real buoy moved. Expanded views below use
actual new camera limits. All baseline rows, including regressions, remain in raw JSON.

| Expanded view / mode / width | Median/p95 ms | Draw calls | Texture/static MiB | CPU process/physics ms |
| --- | ---: | ---: | ---: | ---: |
| 1280-normal-expanded-buoy | 80.14 / 92.63 | 65 | 114.63 / 103.62 | 75.17 / 7.58 |
| 1280-normal-expanded-school | 89.28 / 174.87 | 63 | 114.63 / 103.55 | 74.20 / 15.66 |
| 1280-normal-expanded-vent | 70.74 / 91.65 | 50 | 114.63 / 103.56 | 63.14 / 6.04 |
| 1280-reduced-expanded-buoy | 88.05 / 147.57 | 63 | 114.63 / 103.66 | 76.96 / 20.56 |
| 1280-reduced-expanded-school | 134.38 / 212.87 | 62 | 114.63 / 103.58 | 125.94 / 9.13 |
| 1280-reduced-expanded-vent | 100.76 / 138.18 | 49 | 114.63 / 103.60 | 98.92 / 16.70 |
| 1920-normal-expanded-buoy | 145.52 / 190.08 | 70 | 123.30 / 112.22 | 115.25 / 17.67 |
| 1920-normal-expanded-school | 175.83 / 265.49 | 70 | 123.30 / 112.13 | 142.62 / 8.61 |
| 1920-normal-expanded-vent | 145.74 / 194.17 | 59 | 123.30 / 112.16 | 156.76 / 10.38 |
| 1920-reduced-expanded-buoy | 151.94 / 239.34 | 68 | 123.30 / 112.25 | 196.59 / 8.42 |
| 1920-reduced-expanded-school | 219.86 / 404.79 | 68 | 123.30 / 112.16 | 281.45 / 20.42 |
| 1920-reduced-expanded-vent | 175.16 / 240.72 | 55 | 123.30 / 112.19 | 156.36 / 18.51 |
| 800-normal-expanded-buoy | 41.78 / 74.68 | 54 | 110.48 / 99.35 | 54.06 / 12.16 |
| 800-normal-expanded-school | 58.19 / 179.27 | 56 | 110.48 / 99.28 | 72.94 / 18.00 |
| 800-normal-expanded-vent | 43.77 / 79.74 | 44 | 110.48 / 99.29 | 44.97 / 4.69 |
| 800-reduced-expanded-buoy | 63.10 / 127.46 | 54 | 110.48 / 99.40 | 56.29 / 405.90 |
| 800-reduced-expanded-school | 86.40 / 134.47 | 55 | 110.48 / 99.33 | 64.28 / 18.88 |
| 800-reduced-expanded-vent | 58.34 / 84.69 | 43 | 110.48 / 99.34 | 58.41 / 11.27 |

## Controlled scanner workload

Seven batches of 1000 paused scanner.snapshot() calls, all subjects known.
The controlled comparison uses the same eight legacy subjects: baseline
**244.864 ms**, after **47.065 ms** per 1000 calls (**80.8% lower**).
The expanded sixteen-target workload measures **91.144 ms**; it is a
different workload and is not used to claim that percentage improvement.
[Before raw](before/scanner-benchmark.txt) · [Eight-target after](after/scanner-control.txt)
· [Sixteen-target after](after/scanner-expanded.txt). This measures API CPU work,
not rendering FPS. Reproduce with the fixture and --baseline-targets.

## Interpretation

**Median wall-frame time regressed in 16 of 18 shared-view samples.**
Texture allocation increased by about 8.54 MiB with the new species atlas and
subject thumbnails. Lower scanner CPU work and some lower draw counts do not
establish an overall rendering improvement. Rendering performance remains open
for review and target-hardware profiling; these results are not acceptance.

This software renderer cannot establish 60 FPS on modest desktop GPU hardware.
Values above 16.67 ms miss that target on this host. Draw counts and texture bytes
are engine monitor observations, not per-pass GPU costs or a rendering-quality approval.
The larger region adds visible art/terrain and schools; controlled hot-path reductions
do not guarantee a lower whole-frame time at every view. Original PNG masters and
texture resolution are unchanged. No screen-reading postprocessing pass was added.

Confirmed interventions: scanner immutable-definition cache (separate controlled
benchmark), lazy decoration construction, bounded geometry cache/invalidation,
inactive prototype geometry exclusion, suspended legacy wildlife and ambient field,
batched school draws and bounded camera-local sediment. Existing art uses shared
lossless mipmapped textures; alpha overdraw and raster memory remain material costs.
No unverified texture-compression tradeoff was applied.

## Reproduce on Fedora / NVIDIA

Use the pinned engine and compatible NVIDIA driver on the actual desktop. Close
competing game/editor processes. Do not set LIBGL_ALWAYS_SOFTWARE or LP_NUM_THREADS
for the hardware run. Record Fedora/kernel/driver/GPU/CPU, display mode and power state.

```sh
godot --version
godot --path . --rendering-method gl_compatibility --verbose
python3 tools/capture_sunlit_survey.py --output /tmp/bta051-nvidia
godot --headless --path . --script res://tests/fixtures/profile_scanner.gd -- --baseline-targets
```

The native log must name the intended hardware renderer, not llvmpipe. Run normal
and reduced modes at 800×600, 1280×800 and 1920×1080 (the capture tool does all six).
Repeat at least three times; report each sample and host conditions. Also fly the
entire chapter with the profiler open: rendering, scripting, physics, material/texture
memory, draw calls and spikes during excavation/pings/scan popups. Use the editor
profiler or an externally launched game with remote inspection; optional driver tools
are not project dependencies. Check alpha-heavy kelp and shafts, not only empty water.
A 60-frame cloud probe does not substitute for a long hardware capture or human playtest.

[Baseline raw](before/profile.json) · [After raw](after/capture.json)
· [Architecture/optimization scope](../../decisions/bta-051-expanded-shallows.md).
