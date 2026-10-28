# PR #35 revision: software-renderer observations

Godot 4.6.3 Compatibility, X11 / Mesa llvmpipe, two raster threads. No concurrent
Godot process, no fixed FPS and no disabled render loop during this measurement.
Each view has 20 warm-up frames and 60 live wall-frame intervals. The main simulation
runs; the fixture stages authored positions and is **not** a player-input walkthrough.
Process/physics are final Godot monitor snapshots, not GPU timers. Shared cloud host
variation and physics catch-up affect these short samples. This is not target-GPU approval.

Comparison is against the **initial PR #35** capture in ../after, in a separate
session on this VM. 5/36 medians are higher and 31/36 lower/equal.
Do not attribute differences causally to this patch or call them a performance fix.
The extra illustrated atlas increases reported texture allocation by about **8 MiB**.
Existing alpha-heavy scenery and software rasterization remain material costs. No
60 FPS claim is made; modest desktop GPU and physical-device testing remain required.

| View | Initial median/p95 ms | Review median/p95 ms | Draw calls initial/review | Texture MiB initial/review | Process/physics ms snapshot |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1280-normal-departure | 89.85 / 119.24 | 81.87 / 143.75 | 281 / 282 | 114.63 / 122.63 | 102.68 / 5.97 |
| 1280-normal-expanded-buoy | 80.14 / 92.63 | 95.04 / 152.14 | 65 / 74 | 114.63 / 122.63 | 106.47 / 12.26 |
| 1280-normal-expanded-school | 89.28 / 174.87 | 99.18 / 119.03 | 63 / 95 | 114.63 / 122.63 | 91.06 / 12.53 |
| 1280-normal-expanded-vent | 70.74 / 91.65 | 64.98 / 82.39 | 50 / 55 | 114.63 / 122.63 | 72.81 / 5.79 |
| 1280-normal-plankton | 99.61 / 135.99 | 80.77 / 95.66 | 281 / 280 | 114.63 / 122.63 | 82.00 / 4.48 |
| 1280-normal-twin-spires | 94.78 / 192.62 | 77.17 / 129.25 | 81 / 79 | 114.63 / 122.63 | 85.09 / 11.67 |
| 1280-reduced-departure | 106.14 / 262.20 | 76.01 / 94.86 | 279 / 279 | 114.63 / 122.63 | 72.04 / 4.35 |
| 1280-reduced-expanded-buoy | 88.05 / 147.57 | 85.55 / 211.53 | 63 / 71 | 114.63 / 122.63 | 122.67 / 32.84 |
| 1280-reduced-expanded-school | 134.38 / 212.87 | 87.98 / 460.24 | 62 / 93 | 114.63 / 122.63 | 155.95 / 16.64 |
| 1280-reduced-expanded-vent | 100.76 / 138.18 | 94.37 / 207.59 | 49 / 51 | 114.63 / 122.63 | 145.90 / 43.14 |
| 1280-reduced-plankton | 104.90 / 138.75 | 101.48 / 142.25 | 280 / 280 | 114.63 / 122.63 | 101.27 / 18.56 |
| 1280-reduced-twin-spires | 84.39 / 122.65 | 83.02 / 138.55 | 79 / 78 | 114.63 / 122.63 | 102.74 / 9.35 |
| 1920-normal-departure | 163.95 / 242.43 | 136.07 / 174.88 | 289 / 290 | 123.30 / 131.30 | 136.94 / 8.13 |
| 1920-normal-expanded-buoy | 145.52 / 190.08 | 153.22 / 471.51 | 70 / 84 | 123.30 / 131.30 | 132.89 / 6.55 |
| 1920-normal-expanded-school | 175.83 / 265.49 | 159.63 / 194.31 | 70 / 116 | 123.30 / 131.30 | 156.96 / 5.50 |
| 1920-normal-expanded-vent | 145.74 / 194.17 | 109.17 / 171.96 | 59 / 68 | 123.30 / 131.30 | 279.79 / 16.05 |
| 1920-normal-plankton | 221.79 / 436.05 | 184.56 / 220.69 | 296 / 296 | 123.30 / 131.30 | 184.31 / 4.77 |
| 1920-normal-twin-spires | 163.81 / 255.07 | 164.02 / 262.88 | 89 / 86 | 123.30 / 131.30 | 141.00 / 10.32 |
| 1920-reduced-departure | 145.69 / 213.46 | 153.55 / 306.23 | 287 / 287 | 123.30 / 131.30 | 218.72 / 6.46 |
| 1920-reduced-expanded-buoy | 151.94 / 239.34 | 118.97 / 148.09 | 68 / 82 | 123.30 / 131.30 | 118.10 / 7.14 |
| 1920-reduced-expanded-school | 219.86 / 404.79 | 121.55 / 138.90 | 68 / 113 | 123.30 / 131.30 | 103.62 / 17.13 |
| 1920-reduced-expanded-vent | 175.16 / 240.72 | 134.95 / 181.41 | 55 / 63 | 123.30 / 131.30 | 103.72 / 13.36 |
| 1920-reduced-plankton | 223.21 / 397.00 | 181.91 / 635.63 | 294 / 294 | 123.30 / 131.30 | 312.04 / 20.55 |
| 1920-reduced-twin-spires | 157.25 / 281.71 | 134.83 / 307.75 | 86 / 83 | 123.30 / 131.30 | 212.75 / 22.56 |
| 800-normal-departure | 54.20 / 88.04 | 48.58 / 63.01 | 78 / 78 | 110.35 / 118.35 | 50.65 / 4.97 |
| 800-normal-expanded-buoy | 41.78 / 74.68 | 32.09 / 55.12 | 54 / 57 | 110.48 / 118.48 | 158.87 / 5.24 |
| 800-normal-expanded-school | 58.19 / 179.27 | 38.20 / 47.57 | 56 / 71 | 110.48 / 118.48 | 38.55 / 6.50 |
| 800-normal-expanded-vent | 43.77 / 79.74 | 35.74 / 49.89 | 44 / 45 | 110.48 / 118.48 | 46.00 / 5.95 |
| 800-normal-plankton | 59.61 / 83.36 | 56.33 / 70.96 | 264 / 267 | 110.48 / 118.48 | 58.26 / 10.98 |
| 800-normal-twin-spires | 43.08 / 79.58 | 38.21 / 64.61 | 66 / 64 | 110.48 / 118.48 | 48.03 / 10.06 |
| 800-reduced-departure | 56.50 / 98.08 | 39.78 / 83.54 | 76 / 76 | 110.48 / 118.48 | 59.74 / 15.06 |
| 800-reduced-expanded-buoy | 63.10 / 127.46 | 37.63 / 63.41 | 54 / 54 | 110.48 / 118.48 | 46.41 / 11.19 |
| 800-reduced-expanded-school | 86.40 / 134.47 | 56.30 / 203.46 | 55 / 67 | 110.48 / 118.48 | 252.98 / 125.76 |
| 800-reduced-expanded-vent | 58.34 / 84.69 | 45.63 / 166.26 | 43 / 41 | 110.48 / 118.48 | 51.33 / 81.99 |
| 800-reduced-plankton | 69.84 / 88.29 | 46.00 / 61.43 | 263 / 265 | 110.48 / 118.48 | 51.60 / 6.19 |
| 800-reduced-twin-spires | 60.95 / 88.58 | 43.61 / 181.84 | 65 / 62 | 110.48 / 118.48 | 245.41 / 18.78 |

The full 36×60 raw frame arrays and memory/object counters are retained in
[capture.json](profile/capture.json), with [CSV](profile/summary.csv) and
[native runtime](profile/native-runtime.txt). All 66 PNGs were generated and their
dimensions checked before selecting 14 review stills to keep the PR size bounded.
The 74 complete input-walkthrough screenshots are retained separately.

Bounds: seafloor bubbles remain one 36-instance batch; normal impacts add three
batches (10 cloud / 28 bubbles / 12 fragments) for 2.6 simulation seconds and reuse
an existing brief local lens. The static probes **do not measure transient blast
cost**, which still needs sustained hardware profiling. Reduced comfort modes omit
those blast decorations. Three new actors reuse existing bounded navigation/hearing.
No whole-screen postprocessing pass or new shader dependency is added.

Reproduce the actual measurements with no other Godot workload:

```sh
python3 tools/capture_sunlit_survey.py --output /tmp/pr35-profile --baseline docs/testing/bta-051/after
```

On the actual desktop, use the intended GPU/driver and omit LIBGL_ALWAYS_SOFTWARE /
LP_NUM_THREADS. Repeat longer captures including the lagoon, blasts, pings and
scan notifications. The old [BTA-051 regressions](../performance.md) remain recorded.

## Same-position comparison

Authored player pose, zoom and camera framing are shared; terrain intentionally changes.
These are staged native captures, not photographs, mockups or completion evidence.

| Position | Initial PR #35 | This revision |
| --- | --- | --- |
| Lower arch, 800, normal | [Before](../after/800-normal-expanded-arch.png) | [After](profile/800-normal-expanded-arch.png) |
| Lower arch, 1280, normal | [Before](../after/1280-normal-expanded-arch.png) | [After](profile/1280-normal-expanded-arch.png) |
| Lower arch, 1920, normal | [Before](../after/1920-normal-expanded-arch.png) | [After](profile/1920-normal-expanded-arch.png) |

1920×1080 [normal departure](profile/1920-normal-departure.png),
[reduced departure](profile/1920-reduced-departure.png),
[normal plankton](profile/1920-normal-plankton.png),
[normal school](profile/1920-normal-expanded-school.png),
[normal buoy](profile/1920-normal-expanded-buoy.png).
