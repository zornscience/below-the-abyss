#!/usr/bin/env python3
"""Original 32-second looping ambient score. Standard-library PCM synthesis; no samples.
Project licensing pending. Committed master is reproducible, not a third-party recording.
"""
from pathlib import Path
import math
import struct
import wave
RATE = 22050
SECONDS = 32
CHORDS = ((50,53,57,60,64),(46,50,53,57,60),(48,53,57,60,67),(48,52,55,57,62))

def score():
    frames=bytearray()
    voices=[(i,n,round((440*2**((n-69)/12))*SECONDS)/SECONDS) for i,chord in enumerate(CHORDS) for n in chord]
    for sample in range(RATE*SECONDS):
        t=sample/RATE
        left=right=0.0
        for index,note,freq in voices:
            distance=math.sin(math.pi*(t-(index*8+4))/SECONDS)
            envelope=math.exp(-(distance/.34)**4)
            gain=.052*envelope/(1+(note-46)*.035)
            carrier=2*math.pi*freq*t
            left+=gain*(math.sin(carrier)+.12*math.sin(2*carrier))
            right+=gain*(math.sin(carrier+.12)+.12*math.sin(2*carrier+.08))
        frames.extend(struct.pack('<hh',round(max(-.7,min(.7,left))*32767),round(max(-.7,min(.7,right))*32767)))
    path=Path(__file__).resolve().parents[1]/'assets/audio/sunlit_music.wav'
    with wave.open(str(path),'wb') as output:
        output.setparams((2,2,RATE,0,'NONE','not compressed'))
        output.writeframes(frames)
    print(path)
if __name__=='__main__': score()
