#!/usr/bin/env python3
"""Export and package Linux and/or Windows x86_64; never upload or publish a build."""
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
# Per platform: export preset, output folder, executable name, manifest label.
# The Linux entry keeps its historical paths so existing CI globs are unchanged.
PLATFORMS = {
    "linux": ("Linux Playtest", "build/playtest", "below-the-abyss.x86_64", "Linux x86_64"),
    "windows": ("Windows Playtest", "build/playtest-windows", "below-the-abyss.exe", "Windows x86_64"),
}
DOCS = ["START_HERE.md", "FEEDBACK.md", "LOCAL_REPORTS.md", "GODOT_LICENSE.txt", "GODOT_COPYRIGHT.txt", "manifest.json"]


def run(args, log=None):
    result = subprocess.run(args, cwd=ROOT, text=True, encoding="utf-8", errors="replace", stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    if log:
        log.write_text(result.stdout, encoding="utf-8")
    if result.returncode or re.search(r"^\s*(ERROR:|SCRIPT ERROR:|Parse Error:)", result.stdout, re.M):
        raise RuntimeError(f"Build command failed; see {log or result.stdout}")
    return result.stdout.strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-dirty", action="store_true", help="Explicit development export; source digest is the build ID")
    parser.add_argument("--platform", choices=["all", *PLATFORMS], default="all", help="Which package(s) to export (default: all)")
    args = parser.parse_args()
    platforms = list(PLATFORMS) if args.platform == "all" else [args.platform]
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
    for key in platforms:
        (ROOT / PLATFORMS[key][1]).mkdir(parents=True, exist_ok=True)
    first_out = ROOT / PLATFORMS[platforms[0]][1]
    stamp = ROOT / "resources/playtesting/build_info.json"
    original = stamp.read_bytes()
    info = {"game_version": "0.1.0-playtest", "build_id": build_id}
    try:
        stamp.write_text(json.dumps(info) + "\n")
        run([godot, "--headless", "--path", str(ROOT), "--editor", "--import"], first_out / "import.log")
        for key in platforms:
            preset, folder, exe, _ = PLATFORMS[key]
            out = ROOT / folder
            run([godot, "--headless", "--path", str(ROOT), "--export-release", preset, str(out / exe)], out / "export.log")
    finally:
        stamp.write_bytes(original)
    results = []
    for key in platforms:
        results.append(package(key, info, commit, dirty, build_id))
    print(json.dumps(results, indent=2))


def package(key, info, commit, dirty, build_id):
    _, folder, exe, label = PLATFORMS[key]
    out = ROOT / folder
    binary = out / exe
    binary.chmod(0o755)
    shutil.copy(ROOT / "docs/playtesting/playtester_guide.md", out / "START_HERE.md")
    shutil.copy(ROOT / "docs/playtesting/feedback_form.md", out / "FEEDBACK.md")
    shutil.copy(ROOT / "docs/playtesting/telemetry.md", out / "LOCAL_REPORTS.md")
    shutil.copy(ROOT / "docs/licenses/godot_LICENSE.txt", out / "GODOT_LICENSE.txt")
    shutil.copy(ROOT / "docs/licenses/godot_COPYRIGHT.txt", out / "GODOT_COPYRIGHT.txt")
    manifest = {**info, "source_commit": commit, "development_dirty": dirty, "engine": ENGINE, "platform": label, "sha256": hashlib.sha256(binary.read_bytes()).hexdigest()}
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    archive = ROOT / "build" / f"below-the-abyss-playtest-{key}-{build_id[:12]}.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
        for name in [exe, *DOCS]:
            z.write(out / name, "below-the-abyss/" + name)
    return {"package": str(archive), "manifest": manifest}


if __name__ == "__main__":
    main()
