#!/usr/bin/env python3
"""Native captures/profile; fail on errors, wrong dimensions or changed authored geometry/camera."""
import argparse
import json
import os
from pathlib import Path
import re
import struct
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
POSES = ('departure','early-exploration','kelp-seabed','plankton','twin-spires','emergency-buoy','return-halcyon')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--baseline',type=Path)
    parser.add_argument('--project',type=Path,default=ROOT)
    parser.add_argument('--preview',action='store_true')
    parser.add_argument('--stills-only',action='store_true')
    parser.add_argument('--wide',action='store_true')
    args=parser.parse_args()
    output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    command=[os.environ.get('GODOT_BIN','godot'),'--path',str(args.project.resolve()),'--audio-driver','Dummy',
             '--rendering-method','gl_compatibility','--script','res://tests/fixtures/capture_sunlit_environment.gd',
             '--quit-after','30000']
    extra=[]
    if args.preview:extra.append('--preview')
    if args.stills_only:extra.append('--stills-only')
    if args.wide:extra.append('--wide')
    if extra:command += ['--',*extra]
    with (output/'native-runtime.txt').open('w') as log:
        result=subprocess.run(command,cwd=args.project,env={**os.environ,'BTA_EVIDENCE_DIR':str(output)},
                              text=True,stdout=log,stderr=subprocess.STDOUT,timeout=900)
    text=re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]','',(output/'native-runtime.txt').read_text())
    if result.returncode or 'SUNLIT_ART_CAPTURE_PASS' not in text or re.search(
            r'^\s*(ERROR:|SCRIPT ERROR:|USER ERROR:)|leaked at exit|\[Physics interpolation\]',text,re.M):
        raise SystemExit('Capture failed: '+str(output/'native-runtime.txt'))
    data=json.loads((output/'capture.json').read_text())
    if not args.stills_only and not args.preview:
        shutil.copyfile(output/'capture.json',output/'profile.json')
        shutil.copyfile(output/'native-runtime.txt',output/'profile-runtime.txt')
    for width,height in ([(1280,800)] if args.preview else [(800,600),(1280,800),(1920,1080)]):
        for mode in (['normal'] if args.preview else ['normal','reduced']):
            for pose in POSES:
                key=f'{width}-{mode}-{pose}'
                assert key in data,key
                image=(output/(key+'.png')).read_bytes()
                assert image[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',image[16:24])==(width,height),key
    if args.baseline:
        old=json.loads((args.baseline/'capture.json').read_text())
        assert old.keys()==data.keys()
        for key in old:
            for field in ['viewport','player','camera_zoom','terrain_sha256']:
                assert old[key][field]==data[key][field],(key,field,old[key][field],data[key][field])
            # Camera code/limits are unchanged; native smoothing can vary below one pixel.
            old_center=[float(x) for x in re.findall(r'-?\d+(?:\.\d+)?',old[key]['camera_center'])]
            new_center=[float(x) for x in re.findall(r'-?\d+(?:\.\d+)?',data[key]['camera_center'])]
            assert max(abs(a-b) for a,b in zip(old_center,new_center))<0.5,(key,'camera alignment')
    if args.preview:
        print('PASS: seven preview captures; exact dimensions, no errors.')
        return
    if args.stills_only:
        print('PASS: 42 native stills; exact dimensions; no errors; matched geometry/poses/camera.' if args.baseline else 'PASS: 42 native baseline stills; exact dimensions; no errors.')
        return
    print('PASS: 42 native captures, 18 actual-playable frame samples, exact dimensions, no errors;'
          ' matching terrain/poses/camera.' if args.baseline else
          'PASS: 42 native baseline captures and 18 actual-playable frame samples; exact dimensions, no errors.')

if __name__=='__main__':main()
