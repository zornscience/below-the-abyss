#!/usr/bin/env python3
"""Measure the authored crossing and prove lingering failure and hull-only respawn."""
from validate_godot import LOGS, run_check

def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    output = run_check('depth-gate-route', ['--fixed-fps', '60', '--script',
                      'res://tests/fixtures/drive_depth_gate.gd'], timeout=180)
    for token in ['DEPTH_CROSSING rank=0', 'DEPTH_CROSSING rank=1',
                  'DEPTH_CROSSING rank=2', 'DEPTH_LINGER_RESPAWN_PASS', 'DEPTH_ROUTE_PASS']:
        if token not in output:
            raise RuntimeError('Missing ' + token)
    print('PASS: authored depth crossing, lower and gate ranks, lingering and durable respawn')

if __name__ == '__main__':
    main()
