#!/usr/bin/env python3
"""Original fixed-seed PCM radio squelch, muffled underwater blast and gas bubbles.
Standard library only; no recordings or third-party samples. Project licence pending.
"""
import math
from pathlib import Path
import random
import struct
import wave
RATE=22050
ROOT=Path(__file__).resolve().parents[1]/'assets/audio'

def generate(name,seconds):
    rng=random.Random('bta051-'+name)
    low=0.0
    samples=[]
    for i in range(round(seconds*RATE)):
        t=i/RATE
        noise=rng.uniform(-1,1)
        low+=0.055*(noise-low)
        if name=='radio':
            squelch=(min(1,t/0.008)*math.exp(-t*19)+math.exp(-((t-.37)/.045)**2))
            value=noise*.11*squelch + .12*math.sin(2*math.pi*740*t)*math.exp(-((t-.10)/.04)**2)+.10*math.sin(2*math.pi*980*t)*math.exp(-((t-.22)/.05)**2)
        elif name=='underwater_blast':
            attack=min(1,t/.012)
            thump=math.sin(2*math.pi*(42*t+20*t*t))*math.exp(-t*6)
            cavity=math.sin(2*math.pi*58*t)*math.exp(-((t-.26)/.10)**2)
            value=attack*(.43*thump+.18*cavity+low*.8*math.exp(-t*2))
        else:
            value=0.0
            for start,freq in [(0,440),(.16,660),(.35,530)]:
                age=t-start
                if age>=0: value+=.16*math.sin(2*math.pi*(freq*age+800*age*age))*min(1,age/.006)*math.exp(-age*26)
        samples.append(struct.pack('<h',round(max(-.75,min(.75,value))*32767)))
    with wave.open(str(ROOT/(name+'.wav')),'wb') as file:
        file.setparams((1,2,RATE,0,'NONE','not compressed'))
        file.writeframes(b''.join(samples))

if __name__=='__main__':
    for name,seconds in [('radio',.55),('underwater_blast',1.8),('bubble',.7)]: generate(name,seconds)
