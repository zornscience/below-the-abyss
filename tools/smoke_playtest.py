#!/usr/bin/env python3
"""Launch the exported package, away from source/editor and with isolated local data."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('package',type=Path)
    parser.add_argument('--log',type=Path,required=True)
    parser.add_argument('--break-visibility-wiring',action='store_true')
    parser.add_argument('--break-registration-wiring',action='store_true')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='bta-standalone-') as tmp:
        root = Path(tmp)
        # Only our known package inventory; reject unsafe archive paths.
        expected = {'below-the-abyss/'+name for name in ['below-the-abyss.x86_64','START_HERE.md','FEEDBACK.md','LOCAL_REPORTS.md','GODOT_LICENSE.txt','GODOT_COPYRIGHT.txt','manifest.json']}
        with zipfile.ZipFile(args.package) as z:
            if set(z.namelist()) != expected:
                raise SystemExit('Unexpected package contents')
            z.extractall(root)
        binary = root/'below-the-abyss/below-the-abyss.x86_64'
        binary.chmod(0o755)
        import hashlib
        manifest = json.loads((binary.parent/'manifest.json').read_text())
        if hashlib.sha256(binary.read_bytes()).hexdigest() != manifest['sha256']:
            raise SystemExit('Packaged binary checksum mismatch')
        env = os.environ.copy()
        for key, folder in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
            env[key] = str(root/folder)
        result = subprocess.run([str(binary),'--headless','--quit-after','60','--','--release-smoke']+(['--break-visibility-wiring'] if args.break_visibility_wiring else [])+(['--break-registration-wiring'] if args.break_registration_wiring else []),cwd=binary.parent,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60)
        args.log.parent.mkdir(parents=True,exist_ok=True)
        args.log.write_text(result.stdout)
        if result.returncode or re.search(r'^\s*(ERROR:|SCRIPT ERROR:|Parse Error:)',result.stdout,re.M):
            raise SystemExit(f'Standalone smoke failed: see {args.log}')
        if 'RELEASE_REGISTRATION_WIRING_PASS' not in result.stdout:
            raise SystemExit('Missing release registration wiring proof')
        if 'RELEASE_VISIBILITY_WIRING_PASS' not in result.stdout:
            raise SystemExit('Missing release visibility wiring proof')
        if list((root/'data').rglob('playtests/*.json')):
            raise SystemExit('Default launch unexpectedly recorded telemetry')
        print(f"PASS: extracted standalone release launch, default telemetry OFF, build {manifest['build_id']}")


if __name__ == '__main__': main()
