#!/usr/bin/env python3
"""Two-device real-input squeezes, cuts, retreats, impacts and fresh-process Continue."""
import time
from validate_godot import LOGS, run_check

def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    for device in ['keyboard', 'controller']:
        profile = 'bta061-'+device+'-'+str(time.time_ns())
        args = ['--fixed-fps','60','--script','res://tests/fixtures/drive_twilight_tunnels.gd',
                '--quit-after','180000','--','--profile='+profile,'--input='+device]
        for resume in [False, True]:
            output = run_check('tunnels-'+device+('-continue' if resume else ''),
                               args+(['--tunnel-resume'] if resume else []),timeout=600)
            token = 'TUNNEL_CONTINUE_INPUT_PASS' if resume else 'TUNNEL_INPUT_PASS'
            if token not in output: raise RuntimeError('Missing '+token)
    print('PASS: both devices, both squeezes/dead ends/gates, impacts and fresh-process Continue')

if __name__ == '__main__': main()
