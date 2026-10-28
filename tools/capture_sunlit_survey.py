#!/usr/bin/env python3
"""Capture/profile BTA-051 natively; shared views retain the old camera framing in the fixture only."""
import argparse
import json
import os
from pathlib import Path
import re
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SHARED = ('departure', 'early-exploration', 'kelp-seabed', 'plankton', 'twin-spires', 'return-halcyon')
EXPANDED = ('expanded-school', 'expanded-arch', 'expanded-vent', 'expanded-buoy')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--baseline', type=Path)
    parser.add_argument('--preview', action='store_true')
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    command = [os.environ.get('GODOT_BIN', 'godot'), '--path', str(ROOT), '--audio-driver', 'Dummy',
               '--rendering-method', 'gl_compatibility', '--script',
               'res://tests/fixtures/capture_sunlit_survey.gd', '--quit-after', '90000']
    if args.preview:
        command += ['--', '--preview']
    with (output / 'native-runtime.txt').open('w') as log:
        result = subprocess.run(command, cwd=ROOT,
                                env={**os.environ, 'BTA_EVIDENCE_DIR': str(output)},
                                stdout=log, stderr=subprocess.STDOUT, timeout=1800)
    text = (output / 'native-runtime.txt').read_text()
    if result.returncode or 'SUNLIT_SURVEY_CAPTURE_PASS' not in text or re.search(
            r'^\s*(ERROR:|SCRIPT ERROR:|USER ERROR:)|leaked at exit|\[Physics interpolation\]', text, re.M):
        raise SystemExit('Native capture failed: ' + str(output / 'native-runtime.txt'))
    data = json.loads((output / 'capture.json').read_text())
    old = json.loads((args.baseline / 'capture.json').read_text()) if args.baseline else {}
    for width, height in ([(1280, 800)] if args.preview else [(800, 600), (1280, 800), (1920, 1080)]):
        for mode in (['normal'] if args.preview else ['normal', 'reduced']):
            for pose in SHARED + EXPANDED:
                key = f'{width}-{mode}-{pose}'
                image = (output / (key + '.png')).read_bytes()
                assert image[:8] == b'\x89PNG\r\n\x1a\n'
                assert struct.unpack('>II', image[16:24]) == (width, height), key
                if old and pose in SHARED:
                    for field in ('viewport', 'player', 'camera_zoom'):
                        assert data[key][field] == old[key][field], (key, field)
                    a = [float(x) for x in re.findall(r'-?\d+(?:\.\d+)?', old[key]['camera_center'])]
                    b = [float(x) for x in re.findall(r'-?\d+(?:\.\d+)?', data[key]['camera_center'])]
                    assert max(abs(x-y) for x, y in zip(a, b)) < 0.5, (key, 'camera framing')
                    # Authored geometry intentionally changes. Never require an identical
                    # terrain hash, and never describe these as identical physics scenes.
    print(f'PASS: {len(data)} native screenshots; exact dimensions; '
          f'{sum("performance" in value for value in data.values())} live samples; no errors. '
          'Six shared views compare player/zoom/framing; expanded views use actual new camera limits.')


if __name__ == '__main__':
    main()
