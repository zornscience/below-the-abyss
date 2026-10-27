#!/usr/bin/env python3
"""Export and package Linux x86_64; never upload or publish a build."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ENGINE = "4.6.3.stable.official.7d41c59c4"


def run(args, log=None):
    result = subprocess.run(args, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    if log:
        log.write_text(result.stdout)
    if result.returncode or re.search(r"^\s*(ERROR:|SCRIPT ERROR:|Parse Error:)", result.stdout, re.M):
        raise RuntimeError(f"Build command failed; see {log or result.stdout}")
    return result.stdout.strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-dirty", action="store_true", help="Explicit development export; source digest is the build ID")
    args = parser.parse_args()
    godot = os.environ.get("GODOT_BIN", "godot")
    if run([godot, "--version"]) != ENGINE:
        raise SystemExit(f"Requires {ENGINE}")
    dirty = bool(run(["git", "status", "--porcelain"]))
    if dirty and not args.allow_dirty:
        raise SystemExit("Commit/stash source first, or explicitly use --allow-dirty for a development build")
    commit = run(["git", "rev-parse", "HEAD"])
    build_id = commit
    if dirty:
        digest = hashlib.sha1()
        paths = set(run(["git", "ls-files", "--cached", "--others", "--exclude-standard"]).splitlines())
        for name in sorted(paths):
            path = ROOT / name
            if path.is_file() and not name.startswith(("docs/", "tests/")):
                digest.update(name.encode() + b"\0" + path.read_bytes())
        build_id = digest.hexdigest()
    out = ROOT / "build/playtest"
    out.mkdir(parents=True, exist_ok=True)
    stamp = ROOT / "resources/playtesting/build_info.json"
    original = stamp.read_bytes()
    info = {"game_version": "0.1.0-playtest", "build_id": build_id}
    try:
        stamp.write_text(json.dumps(info) + "\n")
        run([godot, "--headless", "--path", str(ROOT), "--editor", "--import"], out / "import.log")
        run([godot, "--headless", "--path", str(ROOT), "--export-release", "Linux Playtest", str(out / "below-the-abyss.x86_64")], out / "export.log")
    finally:
        stamp.write_bytes(original)
    binary = out / "below-the-abyss.x86_64"
    binary.chmod(0o755)
    shutil.copy(ROOT / "docs/playtesting/playtester_guide.md", out / "START_HERE.md")
    shutil.copy(ROOT / "docs/playtesting/feedback_form.md", out / "FEEDBACK.md")
    shutil.copy(ROOT / "docs/playtesting/telemetry.md", out / "LOCAL_REPORTS.md")
    shutil.copy(ROOT / "docs/licenses/godot_LICENSE.txt", out / "GODOT_LICENSE.txt")
    shutil.copy(ROOT / "docs/licenses/godot_COPYRIGHT.txt", out / "GODOT_COPYRIGHT.txt")
    manifest = {**info, "source_commit": commit, "development_dirty": dirty, "engine": ENGINE, "platform": "Linux x86_64", "sha256": hashlib.sha256(binary.read_bytes()).hexdigest()}
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    package = ROOT / "build" / f"below-the-abyss-playtest-linux-{build_id[:12]}.zip"
    with zipfile.ZipFile(package, "w", zipfile.ZIP_DEFLATED) as z:
        for name in ["below-the-abyss.x86_64", "START_HERE.md", "FEEDBACK.md", "LOCAL_REPORTS.md", "GODOT_LICENSE.txt", "GODOT_COPYRIGHT.txt", "manifest.json"]:
            z.write(out / name, "below-the-abyss/" + name)
    print(json.dumps({"package": str(package), "manifest": manifest}, indent=2))


if __name__ == "__main__":
    main()
