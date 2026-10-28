#!/usr/bin/env python3
"""Capture native BTA-049 review screens; reject errors, omissions and wrong dimensions."""
import argparse
import os
from pathlib import Path
import re
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SCREENS = ("title", "briefing", "choice", "radio", "research", "expedition-log",
           "station", "technology", "debrief", "settings", "help")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--baseline", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    modes = [(800, 600, "standard"), (1280, 800, "standard")]
    if not args.baseline:
        modes += [(800, 600, "large"), (1920, 1080, "standard")]
    expected = {f"{w}-{scale}-{screen}.png": (w, h)
                for w, h, scale in modes for screen in SCREENS}
    for name in expected:
        (output / name).unlink(missing_ok=True)
    command = [os.environ.get("GODOT_BIN", "godot"), "--path", str(args.project.resolve()),
               "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
               "--fixed-fps", "60", "--script", "res://tests/fixtures/capture_interface_review.gd",
               "--quit-after", "16000"]
    if args.baseline:
        command += ["--", "--baseline"]
    environment = {**os.environ, "BTA_EVIDENCE_DIR": str(output)}
    result = subprocess.run(command, cwd=args.project, env=environment, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=300)
    (output / "native-runtime.txt").write_text(result.stdout)
    errors = re.search(r"^\s*(?:ERROR:|SCRIPT ERROR:|USER ERROR:|Parse Error:)|"
                       r"leaked at exit|ObjectDB instances leaked", result.stdout, re.M)
    if result.returncode or errors or "INTERFACE_REVIEW_CAPTURE_PASS" not in result.stdout:
        raise SystemExit("Native capture failed; inspect " + str(output / "native-runtime.txt"))
    for name, dimensions in expected.items():
        data = (output / name).read_bytes()
        if data[:8] != b"\x89PNG\r\n\x1a\n" or struct.unpack(">II", data[16:24]) != dimensions:
            raise SystemExit("Wrong native image dimensions: " + name)
        if "INTERFACE_CAPTURE " + name[:-4] not in result.stdout:
            raise SystemExit("Missing capture marker: " + name)
    print(f"PASS: {len(expected)} native screenshots; exact dimensions; no Godot errors or exit leaks.")


if __name__ == "__main__":
    main()
