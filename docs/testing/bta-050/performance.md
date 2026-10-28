# BTA-050 observed performance

X11 / Godot Compatibility / Mesa llvmpipe, two raster threads; same cloud VM,
separate runs without competing Godot processes. Actual MAIN simulation runs
during each sample. No fixed FPS; 20 warm-up frames then 60 wall-frame samples.
These are application intervals, not GPU timestamps or hardware certification.

| View | Mode | Size | Before median/p95 ms | After median/p95 ms | Before/after draw calls | Before/after texture MiB |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| departure | normal | 800 | 125.25 / 373.68 | 160.24 / 204.03 | 367 / 81 | 49.81 / 101.81 |
| plankton | normal | 800 | 120.30 / 257.28 | 146.35 / 268.21 | 548 / 269 | 49.94 / 101.94 |
| twin-spires | normal | 800 | 86.17 / 175.86 | 140.76 / 210.93 | 376 / 67 | 49.94 / 101.94 |
| departure | reduced | 800 | 77.24 / 143.97 | 127.60 / 250.81 | 217 / 78 | 49.94 / 101.94 |
| plankton | reduced | 800 | 79.12 / 153.69 | 141.49 / 269.66 | 398 / 268 | 49.94 / 101.94 |
| twin-spires | reduced | 800 | 75.65 / 122.61 | 101.59 / 174.00 | 230 / 66 | 49.94 / 101.94 |
| departure | normal | 1280 | 179.49 / 320.97 | 180.66 / 216.66 | 566 / 288 | 54.09 / 106.09 |
| plankton | normal | 1280 | 198.82 / 317.57 | 216.03 / 488.06 | 587 / 287 | 54.09 / 106.09 |
| twin-spires | normal | 1280 | 225.16 / 442.70 | 179.10 / 297.58 | 383 / 80 | 54.09 / 106.09 |
| departure | reduced | 1280 | 144.36 / 267.09 | 174.03 / 807.01 | 416 / 285 | 54.09 / 106.09 |
| plankton | reduced | 1280 | 145.38 / 245.55 | 359.56 / 706.55 | 437 / 286 | 54.09 / 106.09 |
| twin-spires | reduced | 1280 | 119.73 / 147.89 | 251.84 / 350.86 | 233 / 78 | 54.09 / 106.09 |
| departure | normal | 1920 | 305.20 / 446.59 | 412.48 / 925.96 | 4197 / 298 | 62.76 / 114.76 |
| plankton | normal | 1920 | 232.87 / 268.19 | 437.41 / 747.17 | 4199 / 302 | 62.76 / 114.76 |
| twin-spires | normal | 1920 | 216.06 / 254.81 | 494.10 / 703.46 | 3988 / 87 | 62.76 / 114.76 |
| departure | reduced | 1920 | 222.93 / 332.48 | 305.13 / 472.84 | 4047 / 295 | 62.76 / 114.76 |
| plankton | reduced | 1920 | 274.66 / 414.40 | 412.05 / 864.90 | 4049 / 300 | 62.76 / 114.76 |
| twin-spires | reduced | 1920 | 247.01 / 586.04 | 313.67 / 478.07 | 3838 / 85 | 62.76 / 114.76 |

## Final monitor snapshots

Process/physics below are the last-frame monitor snapshot, not averages or GPU time.

| View / mode / width | Before process/physics ms | After process/physics ms | Before/after renderer objects |
| --- | ---: | ---: | ---: |
| departure / normal / 800 | 121.64 / 14.83 | 108.86 / 23.62 | 1575 / 882 |
| plankton / normal / 800 | 96.60 / 13.63 | 99.72 / 17.08 | 1988 / 1315 |
| twin-spires / normal / 800 | 60.20 / 15.20 | 179.75 / 61.53 | 1616 / 835 |
| departure / reduced / 800 | 76.18 / 15.78 | 91.07 / 13.12 | 1425 / 879 |
| plankton / reduced / 800 | 59.93 / 17.54 | 93.14 / 23.43 | 1839 / 1314 |
| twin-spires / reduced / 800 | 63.53 / 11.73 | 112.92 / 68.21 | 1486 / 833 |
| departure / normal / 1280 | 292.69 / 12.94 | 161.00 / 11.09 | 1935 / 1254 |
| plankton / normal / 1280 | 125.03 / 19.65 | 171.05 / 25.96 | 2047 / 1348 |
| twin-spires / normal / 1280 | 219.02 / 15.88 | 145.22 / 9.36 | 1784 / 1012 |
| departure / reduced / 1280 | 240.70 / 21.28 | 184.89 / 13.32 | 1785 / 1250 |
| plankton / reduced / 1280 | 270.07 / 20.15 | 355.30 / 42.87 | 1897 / 1346 |
| twin-spires / reduced / 1280 | 85.76 / 13.36 | 139.65 / 36.90 | 1634 / 1009 |
| departure / normal / 1920 | 301.87 / 9.63 | 1037.94 / 6.80 | 5637 / 1340 |
| plankton / normal / 1920 | 189.87 / 13.41 | 321.91 / 35.66 | 5681 / 1388 |
| twin-spires / normal / 1920 | 184.40 / 22.68 | 504.79 / 47.45 | 5389 / 1023 |
| departure / reduced / 1920 | 184.95 / 19.07 | 250.27 / 12.46 | 5487 / 1335 |
| plankton / reduced / 1920 | 231.17 / 15.47 | 243.48 / 28.85 | 5531 / 1384 |
| twin-spires / reduced / 1920 | 164.79 / 15.72 | 290.68 / 34.70 | 5239 / 1019 |

## Interpretation and limits

The new chapter removes the old octave-noise material and hidden procedural
atmosphere/relief/garden draw lists, uses two particle batches and adds painted
texture/alpha layers. Draw-count reduction is measurable; raster masters/mipmaps
consume additional memory and still incur texture sampling/overdraw. Changes
in wall time include CPU/physics catch-up and shared-host variability; a lower
draw count is not a claim of faster GPU rendering. See all rows, including regressions.

No per-pass GPU timers are available here. The 60 FPS modest desktop GPU target
remains unverified, and software-rendered values above 16.67 ms miss that target.
Test on real target hardware before performance approval. Source physics,
navigation, camera, UI scale and resource rules were not changed to improve numbers.

[Baseline raw data](before/profile.json) · [After raw data](after/profile.json)
Regenerate with `python3 tools/report_sunlit_environment.py`.
