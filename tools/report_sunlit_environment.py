#!/usr/bin/env python3
"""Turn the two retained native manifests into a transparent frame/cost comparison."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'docs/testing/bta-050'

def main():
    before=json.loads((BASE/'before/profile.json').read_text())
    after=json.loads((BASE/'after/profile.json').read_text())
    lines=['# BTA-050 observed performance','',
           'X11 / Godot Compatibility / Mesa llvmpipe, two raster threads; same cloud VM,',
           'separate runs without competing Godot processes. Actual MAIN simulation runs',
           'during each sample. No fixed FPS; 20 warm-up frames then 60 wall-frame samples.',
           'These are application intervals, not GPU timestamps or hardware certification.','',
           '| View | Mode | Size | Before median/p95 ms | After median/p95 ms | Before/after draw calls | Before/after texture MiB |',
           '| --- | --- | --- | ---: | ---: | ---: | ---: |']
    snapshots=['','## Final monitor snapshots','',
               'Process/physics below are the last-frame monitor snapshot, not averages or GPU time.','',
               '| View / mode / width | Before process/physics ms | After process/physics ms | Before/after renderer objects |',
               '| --- | ---: | ---: | ---: |']
    for width in (800,1280,1920):
        for mode in ('normal','reduced'):
            for pose in ('departure','plankton','twin-spires'):
                key=f'{width}-{mode}-{pose}';b=before[key]['performance'];a=after[key]['performance']
                lines.append(f"| {pose} | {mode} | {width} | {b['median_ms']:.2f} / {b['p95_ms']:.2f} | {a['median_ms']:.2f} / {a['p95_ms']:.2f} | {b['draw_calls']:.0f} / {a['draw_calls']:.0f} | {b['texture_mib']:.2f} / {a['texture_mib']:.2f} |")
                snapshots.append(f"| {pose} / {mode} / {width} | {b['process_ms']:.2f} / {b['physics_ms']:.2f} | {a['process_ms']:.2f} / {a['physics_ms']:.2f} | {b['objects']:.0f} / {a['objects']:.0f} |")
    lines+=snapshots+['','## Interpretation and limits','',
        'The new chapter removes the old octave-noise material and hidden procedural',
        'atmosphere/relief/garden draw lists, uses two particle batches and adds painted',
        'texture/alpha layers. Draw-count reduction is measurable; raster masters/mipmaps',
        'consume additional memory and still incur texture sampling/overdraw. Changes',
        'in wall time include CPU/physics catch-up and shared-host variability; a lower',
        'draw count is not a claim of faster GPU rendering. See all rows, including regressions.','',
        'No per-pass GPU timers are available here. The 60 FPS modest desktop GPU target',
        'remains unverified, and software-rendered values above 16.67 ms miss that target.',
        'Test on real target hardware before performance approval. Source physics,',
        'navigation, camera, UI scale and resource rules were not changed to improve numbers.','',
        '[Baseline raw data](before/profile.json) · [After raw data](after/profile.json)',
        'Regenerate with `python3 tools/report_sunlit_environment.py`.','']
    (BASE/'performance.md').write_text('\n'.join(lines))
    print('PASS: wrote 18 unfiltered native frame/cost comparisons.')

if __name__=='__main__':main()
