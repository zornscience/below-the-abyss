#!/usr/bin/env python3
"""Real controls: both handling courses, swarmer stun/kill and Stalker chase/escape."""
from validate_godot import LOGS, run_check

def main():
    LOGS.mkdir(parents=True,exist_ok=True)
    for device in ['keyboard','controller']:
        output=run_check('combat-'+device,['--fixed-fps','60','--script','res://tests/fixtures/drive_combat_box.gd',
                         '--quit-after','90000','--']+(['--controller'] if device=='controller' else []),timeout=600)
        for token in ['COMBAT_COURSE_PASS weighty','COMBAT_COURSE_PASS responsive','COMBAT_ONE_TORPEDO_PASS','COMBAT_INPUT_PASS']:
            if token not in output: raise RuntimeError('Missing '+token)
    print('PASS: both devices, handling measurements/courses, sonar stun, one-shot swarmer, Stalker escape and local opt-in rating')
if __name__=='__main__': main()
