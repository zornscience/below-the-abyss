#!/usr/bin/env python3
"""Actual-input quiet chapter and keyboard/gamepad ping and escape paths."""
import time
from validate_godot import LOGS, run_check

def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    prefix = 'bta060-'+str(time.time_ns())
    for device, quiet in [('keyboard',True),('keyboard',False),('controller',False)]:
        label = 'stalker-'+device+('-quiet' if quiet else '-hunted')
        output = run_check(label,['--fixed-fps','60','--script','res://tests/fixtures/drive_twilight_stalker.gd',
                  '--quit-after','180000','--','--comfort','--no-excavation','--profile='+prefix+'-'+label,
                  '--input='+device,'--outcome=observe','--sentinel=release']+(['--quiet-stalker'] if quiet else []),timeout=600)
        token = 'STALKER_QUIET_CHAPTER_PASS' if quiet else 'STALKER_ESCAPE_PASS'
        if token not in output: raise RuntimeError('Missing '+token)
    print('PASS: quiet complete chapter and both-device ping/pursuit/escape')

if __name__ == '__main__': main()
