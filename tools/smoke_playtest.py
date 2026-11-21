#!/usr/bin/env python3
"""Launch the exported package, away from source/editor and with isolated local data."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import zipfile


EXECUTABLES = {'linux': 'below-the-abyss.x86_64', 'windows': 'below-the-abyss.exe'}
PLATFORM_LABELS = {'linux': 'Linux x86_64', 'windows': 'Windows x86_64'}


def host_platform():
    return 'windows' if sys.platform == 'win32' else 'linux' if sys.platform.startswith('linux') else sys.platform


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('package',type=Path)
    parser.add_argument('--log',type=Path,required=True)
    parser.add_argument('--break-resource-wiring',action='store_true')
    parser.add_argument('--break-visibility-wiring',action='store_true')
    parser.add_argument('--break-registration-wiring',action='store_true')
    for flag in ['depth-rating','depth-section','failure','stalker-registration','stalker-passive','stalker-hearing','stalker-scare','tunnel-geometry','tunnel-gates','tunnel-vents','combat-entry','combat-registration','combat-stun','combat-handling','combat-stalker-registration','combat-weighty-handling','oxygen','caves','caves-gate']:
        parser.add_argument('--break-'+flag+'-wiring',action='store_true')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='bta-standalone-') as tmp:
        root = Path(tmp)
        # Only our known package inventory; reject unsafe archive paths.
        docs = ['START_HERE.md','FEEDBACK.md','LOCAL_REPORTS.md','GODOT_LICENSE.txt','GODOT_COPYRIGHT.txt','manifest.json']
        inventories = {platform: {'below-the-abyss/'+name for name in [exe]+docs} for platform, exe in EXECUTABLES.items()}
        with zipfile.ZipFile(args.package) as z:
            names = set(z.namelist())
            platform = next((key for key, expected in inventories.items() if names == expected), None)
            if platform is None:
                raise SystemExit('Unexpected package contents')
            if platform != host_platform():
                raise SystemExit(f'A {platform} package can only be smoke-tested on {platform}; this host is {host_platform()}')
            z.extractall(root)
        binary = root/'below-the-abyss'/EXECUTABLES[platform]
        binary.chmod(0o755)
        import hashlib
        manifest = json.loads((binary.parent/'manifest.json').read_text())
        if manifest.get('platform') != PLATFORM_LABELS[platform]:
            raise SystemExit('Manifest platform does not match package contents')
        if hashlib.sha256(binary.read_bytes()).hexdigest() != manifest['sha256']:
            raise SystemExit('Packaged binary checksum mismatch')
        env = os.environ.copy()
        # Isolate user:// (saves, telemetry, logs) from the real profile.
        # Godot reads XDG_* on Linux and APPDATA/LOCALAPPDATA on Windows.
        folders = [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')] if platform == 'linux' else [('APPDATA','data'),('LOCALAPPDATA','cache')]
        for key, folder in folders:
            env[key] = str(root/folder)
            (root/folder).mkdir(exist_ok=True)
        # The Windows executable is a GUI-subsystem program, so piped stdout is not a
        # guaranteed channel; Godot's own log file carries the same output there.
        engine_log = root/'engine-smoke.log'
        log_args = ['--log-file',str(engine_log)] if platform == 'windows' else []
        result = subprocess.run([str(binary),'--headless']+log_args+['--quit-after','60','--','--release-smoke']+(['--break-visibility-wiring'] if args.break_visibility_wiring else [])+(['--break-registration-wiring'] if args.break_registration_wiring else [])+(['--break-resource-wiring'] if args.break_resource_wiring else [])+['--break-'+flag+'-wiring' for flag in ['depth-rating','depth-section','failure','stalker-registration','stalker-passive','stalker-hearing','stalker-scare','tunnel-geometry','tunnel-gates','tunnel-vents','combat-entry','combat-registration','combat-stun','combat-handling','combat-stalker-registration','combat-weighty-handling','oxygen','caves','caves-gate'] if getattr(args,'break_'+flag.replace('-','_')+'_wiring')],cwd=binary.parent,env=env,text=True,encoding='utf-8',errors='replace',stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60)
        output = result.stdout
        if engine_log.is_file():
            output += '\n--- engine log file ---\n' + engine_log.read_text(encoding='utf-8',errors='replace')
        args.log.parent.mkdir(parents=True,exist_ok=True)
        args.log.write_text(output,encoding='utf-8')
        if platform == 'windows' and 'RELEASE_' not in output:
            raise SystemExit(f'Standalone smoke produced no release-smoke output on stdout or in the engine log: see {args.log}')
        if result.returncode or re.search(r'^\s*(ERROR:|SCRIPT ERROR:|Parse Error:)',output,re.M):
            raise SystemExit(f'Standalone smoke failed: see {args.log}')
        for wiring in ['GEOMETRY','GATES','VENTS']:
            if f'RELEASE_TUNNEL_{wiring}_WIRING_PASS' not in output:
                raise SystemExit('Missing exported tunnel '+wiring+' wiring proof')
        for wiring in ['ENTRY','REGISTRATION','STALKER_REGISTRATION','STUN','HANDLING','WEIGHTY_HANDLING']:
            if f'RELEASE_COMBAT_{wiring}_WIRING_PASS' not in output:
                raise SystemExit('Missing combat test-box '+wiring+' proof')
        if 'RELEASE_STALKER_WIRING_PASS' not in output:
            raise SystemExit('Missing exported Stalker wiring proof')
        if 'RELEASE_OXYGEN_WIRING_PASS' not in output:
            raise SystemExit('Missing exported oxygen recovery wiring proof')
        if 'RELEASE_CAVES_WIRING_PASS' not in output:
            raise SystemExit('Missing exported Drowned Caves foundation wiring proof')
        if 'RELEASE_CAVES_GATE_WIRING_PASS' not in output:
            raise SystemExit('Missing exported Drowned Caves squeeze gate and oxygen wiring proof')
        if 'RELEASE_DEPTH_GATE_PASS' not in output:
            raise SystemExit('Missing depth gate export proof')
        if 'RELEASE_RESOURCE_WIRING_PASS' not in output:
            raise SystemExit('Missing release resource cost wiring proof')
        if 'RELEASE_REGISTRATION_WIRING_PASS' not in output:
            raise SystemExit('Missing release registration wiring proof')
        if 'RELEASE_VISIBILITY_WIRING_PASS' not in output:
            raise SystemExit('Missing release visibility wiring proof')
        if list((root/'data').rglob('playtests/*.json')):
            raise SystemExit('Default launch unexpectedly recorded telemetry')
        print(f"PASS: extracted standalone release launch, default telemetry OFF, build {manifest['build_id']}")


if __name__ == '__main__': main()
