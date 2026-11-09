#!/usr/bin/env python3
"""Reject side-effect-prone calls in runtime assertions. Pure validation allowlist."""
from pathlib import Path
import re
import sys
PURE = {'assert', 'is_finite', 'is_valid', 'has'}
errors = []
for path in Path('scripts').rglob('*.gd'):
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if re.search(r'\bassert\(', line):
            calls = re.findall(r'\b(\w+)\s*\(', line.split('#')[0])
            if set(calls) - PURE:
                errors.append(f'{path}:{number}: call in assert: {line.strip()}')
if errors:
    print('\n'.join(errors), file=sys.stderr)
    raise SystemExit(1)
print('PASS: runtime assertions contain only allowlisted pure checks')
