#!/usr/bin/env python3
"""Reject calls with potential side effects inside runtime GDScript assertions.

Conservative call allowlist, not a general purity proof. Ignore strings/comments,
including multiline strings, and inspect balanced multiline assertion expressions.
"""
from pathlib import Path
import re
import sys

PURE = {'assert', 'is_finite', 'is_valid', 'has'}


def violations(source):
    chars = list(source)
    index = 0
    while index < len(source):
        if source[index] == '#':
            end = source.find('\n', index)
            end = len(source) if end < 0 else end
        elif source[index] in "\"'":
            quote = source[index]
            delimiter = quote * 3 if source.startswith(quote * 3, index) else quote
            end = index + len(delimiter)
            while end < len(source):
                if source[end] == '\\':
                    end += 2
                    continue
                if source.startswith(delimiter, end):
                    end += len(delimiter)
                    break
                end += 1
        else:
            index += 1
            continue
        for pos in range(index, min(end, len(source))):
            if chars[pos] != '\n':
                chars[pos] = ' '
        index = end
    clean = ''.join(chars)
    errors = []
    for match in re.finditer(r'\bassert\s*\(', clean):
        depth, end = 1, match.end()
        while end < len(clean) and depth:
            depth += (clean[end] == '(') - (clean[end] == ')')
            end += 1
        calls = set(re.findall(r'\b(\w+)\s*\(', clean[match.start():end]))
        if depth or calls - PURE:
            errors.append((source.count('\n', 0, match.start()) + 1,
                           'unterminated assertion' if depth else 'non-allowlisted call: ' + ', '.join(sorted(calls - PURE))))
    return errors


def main():
    errors = []
    for path in Path('scripts').rglob('*.gd'):
        errors.extend(f'{path}:{line}: {reason}' for line, reason in violations(path.read_text()))
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    print('PASS: runtime assertions contain only allowlisted pure checks')
    return 0


if __name__ == '__main__':
    sys.exit(main())
