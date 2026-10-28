#!/usr/bin/env python3
"""Report retained BTA-051 live monitors without converting software frames to GPU claims."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / 'docs/testing/bta-051'


def main():
    before = json.loads((EVIDENCE / 'before/profile.json').read_text())
    after = json.loads((EVIDENCE / 'after/capture.json').read_text())
    lines = ['# BTA-051 measured performance', '',
             'Godot 4.6.3 Compatibility on X11 / Mesa llvmpipe, two raster threads.',
             'Separate runs on the same cloud VM, no concurrent Godot workloads. No fixed FPS.',
             'Each live sample has 20 warm-up frames and 60 wall-frame intervals, while normal',
             'MAIN simulation runs. Frames include catch-up physics and shared-host variation.',
             'Process/physics and memory columns are final monitor snapshots, not GPU timers.',
             'Median uses the upper middle sample; p95 uses index floor(N*0.95), matching baseline.', '',
             '| Shared view / mode / width | Before median/p95 ms | After median/p95 ms | Draw calls before/after | Texture MiB before/after | CPU process/physics after ms |',
             '| --- | ---: | ---: | ---: | ---: | ---: |']
    expanded = []
    for key, entry in after.items():
        if 'performance' not in entry:
            continue
        b = entry['performance']
        if key not in before:
            expanded.append((key, b))
            continue
        a = before[key]['performance']
        lines.append(f'| {key} | {a["median_ms"]:.2f} / {a["p95_ms"]:.2f} | '
                     f'{b["median_ms"]:.2f} / {b["p95_ms"]:.2f} | {a["draw_calls"]:.0f} / {b["draw_calls"]:.0f} | '
                     f'{a["texture_mib"]:.2f} / {b["texture_mib"]:.2f} | {b["process_ms"]:.2f} / {b["physics_ms"]:.2f} |')
    lines += ['', 'Shared views have identical player coordinates, zoom and old camera framing,',
              'checked by the capture tool. The old camera limits are applied in this fixture',
              'only. Terrain/state intentionally differ: this is not identical physics geometry.',
              'The old emergency-buoy pose is retained for diagnostic context but excluded',
              'from the shared-view comparison; the real buoy moved. Expanded views below use',
              'actual new camera limits. All baseline rows, including regressions, remain in raw JSON.', '',
              '| Expanded view / mode / width | Median/p95 ms | Draw calls | Texture/static MiB | CPU process/physics ms |',
              '| --- | ---: | ---: | ---: | ---: |']
    for key, b in expanded:
        lines.append(f'| {key} | {b["median_ms"]:.2f} / {b["p95_ms"]:.2f} | {b["draw_calls"]:.0f} | '
                     f'{b["texture_mib"]:.2f} / {b["static_mib"]:.2f} | {b["process_ms"]:.2f} / {b["physics_ms"]:.2f} |')
    shared = [(before[key]['performance'], entry['performance']) for key, entry in after.items()
              if key in before and 'performance' in entry]
    regressions = sum(b['median_ms'] > a['median_ms'] for a, b in shared)
    lines += ['', '## Controlled scanner workload', '',
              'Seven batches of 1000 paused scanner.snapshot() calls, all subjects known.',
              'The controlled comparison uses the same eight legacy subjects: baseline',
              '**244.864 ms**, after **47.065 ms** per 1000 calls (**80.8% lower**).',
              'The expanded sixteen-target workload measures **91.144 ms**; it is a',
              'different workload and is not used to claim that percentage improvement.',
              '[Before raw](before/scanner-benchmark.txt) · [Eight-target after](after/scanner-control.txt)',
              '· [Sixteen-target after](after/scanner-expanded.txt). This measures API CPU work,',
              'not rendering FPS. Reproduce with the fixture and --baseline-targets.', '',
              '## Interpretation', '',
              f'**Median wall-frame time regressed in {regressions} of {len(shared)} shared-view samples.**',
              'Texture allocation increased by about 8.54 MiB with the new species atlas and',
              'subject thumbnails. Lower scanner CPU work and some lower draw counts do not',
              'establish an overall rendering improvement. Rendering performance remains open',
              'for review and target-hardware profiling; these results are not acceptance.', '',
              'This software renderer cannot establish 60 FPS on modest desktop GPU hardware.',
              'Values above 16.67 ms miss that target on this host. Draw counts and texture bytes',
              'are engine monitor observations, not per-pass GPU costs or a rendering-quality approval.',
              'The larger region adds visible art/terrain and schools; controlled hot-path reductions',
              'do not guarantee a lower whole-frame time at every view. Original PNG masters and',
              'texture resolution are unchanged. No screen-reading postprocessing pass was added.', '',
              'Confirmed interventions: scanner immutable-definition cache (separate controlled',
              'benchmark), lazy decoration construction, bounded geometry cache/invalidation,',
              'inactive prototype geometry exclusion, suspended legacy wildlife and ambient field,',
              'batched school draws and bounded camera-local sediment. Existing art uses shared',
              'lossless mipmapped textures; alpha overdraw and raster memory remain material costs.',
              'No unverified texture-compression tradeoff was applied.', '',
              '## Reproduce on Fedora / NVIDIA', '',
              'Use the pinned engine and compatible NVIDIA driver on the actual desktop. Close',
              'competing game/editor processes. Do not set LIBGL_ALWAYS_SOFTWARE or LP_NUM_THREADS',
              'for the hardware run. Record Fedora/kernel/driver/GPU/CPU, display mode and power state.', '',
              '```sh', 'godot --version',
              'godot --path . --rendering-method gl_compatibility --verbose',
              'python3 tools/capture_sunlit_survey.py --output /tmp/bta051-nvidia',
              'godot --headless --path . --script res://tests/fixtures/profile_scanner.gd -- --baseline-targets',
              '```', '',
              'The native log must name the intended hardware renderer, not llvmpipe. Run normal',
              'and reduced modes at 800×600, 1280×800 and 1920×1080 (the capture tool does all six).',
              'Repeat at least three times; report each sample and host conditions. Also fly the',
              'entire chapter with the profiler open: rendering, scripting, physics, material/texture',
              'memory, draw calls and spikes during excavation/pings/scan popups. Use the editor',
              'profiler or an externally launched game with remote inspection; optional driver tools',
              'are not project dependencies. Check alpha-heavy kelp and shafts, not only empty water.',
              'A 60-frame cloud probe does not substitute for a long hardware capture or human playtest.', '',
              '[Baseline raw](before/profile.json) · [After raw](after/capture.json)',
              '· [Architecture/optimization scope](../../decisions/bta-051-expanded-shallows.md).', '']
    (EVIDENCE / 'performance.md').write_text('\n'.join(lines))
    print('Wrote docs/testing/bta-051/performance.md')


if __name__ == '__main__':
    main()
