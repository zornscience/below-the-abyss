#!/usr/bin/env python3
"""Rebuild original BTA-041 PCM sounds; Python standard library only, fixed seeds.
No recordings, downloaded samples, speech or learned/generative model output.
"""
import math
from pathlib import Path
import random
import struct
import wave

RATE = 22050
ROOT = Path(__file__).resolve().parents[1] / 'assets/audio'
TAU = math.tau

def write(name, duration, recipe, loop=False):
    count = round(duration * RATE)
    rng = random.Random(name)
    # Integer cycles make the continuous tonal/noise bed periodic at its seam.
    partials = [(rng.randint(12, 2000), rng.random() * TAU, rng.random()) for _ in range(24)]
    values = []
    low = 0.0
    for i in range(count):
        t = i / RATE
        if loop:
            low = sum(math.sin(TAU * k * t / duration + p) * a / (1 + k / 90) for k,p,a in partials) / 12
            if recipe == 'engine':
                value = .16 * math.sin(TAU * 48 * t) + .07 * math.sin(TAU * 96 * t) + low * .1
            elif recipe == 'tension':
                value = .10 * math.sin(TAU * 41 * t) + .08 * math.sin(TAU * 43 * t) + low * .12
            elif recipe == 'scan':
                value = .12 * math.sin(TAU * 360 * t) * (.6 + .4 * math.sin(TAU * 2 * t))
            else:
                value = low * .8 + .05 * math.sin(TAU * (32 if recipe == 'ocean' else 73) * t)
        else:
            low += .12 * (rng.uniform(-1, 1) - low)
            attack = min(1, t / .025)
            tail = max(0, 1 - t / duration) ** 2
            freq = {'ping': 730, 'echo': 1050, 'mechanical': 180, 'geological': 75,
                    'biological': 520, 'unknown': 250, 'creak': 110, 'impact': 65,
                    'damage': 150, 'battery': 440, 'oxygen': 590, 'hull': 300,
                    'dock': 330, 'service': 660, 'scan_start': 820, 'complete': 880,
                    'acknowledge': 990, 'predator_alert': 140, 'predator_pursue': 90,
                    'retreat': 210, 'ui': 650}[recipe]
            chirp = 40 if recipe in ('biological', 'ping', 'creak') else 0
            tone = math.sin(TAU * (freq * t + chirp * t * t))
            if recipe in ('impact', 'damage', 'geological', 'creak'):
                tone = .5 * tone + low * 2
            # Two soft beats are identifiable without harsh alarm loops.
            if recipe in ('battery', 'oxygen', 'hull', 'predator_alert', 'predator_pursue'):
                tone *= .3 + .7 * math.sin(TAU * 3 * t) ** 2
            value = .42 * tone * attack * tail
        values.append(max(-.8, min(.8, value)))
    with wave.open(str(ROOT / f'{name}.wav'), 'wb') as out:
        out.setnchannels(1); out.setsampwidth(2); out.setframerate(RATE)
        out.writeframes(b''.join(struct.pack('<h', round(v * 32767)) for v in values))

if __name__ == '__main__':
    ROOT.mkdir(parents=True, exist_ok=True)
    for name in ('ocean', 'current', 'engine', 'tension', 'scan'):
        write(name, 8 if name in ('ocean', 'current') else 2, name, True)
    for name in ('ping', 'echo', 'mechanical', 'geological', 'biological', 'unknown',
                 'creak', 'impact', 'damage', 'battery', 'oxygen', 'hull', 'dock',
                 'service', 'scan_start', 'complete', 'acknowledge', 'predator_alert',
                 'predator_pursue', 'retreat', 'ui'):
        write(name, 1.8 if name in ('ping', 'creak', 'predator_alert') else .65, name)
