#!/usr/bin/env python3
"""Build a caves-ready playtest profile: Sunlit and Twilight done, debrief claimed, last
checkpoint at the Halcyon dock with "Descend to the Drowned Caves" offered.

The profile is played, not written by hand. Step 1 runs the CI whole-chapter route
(tests/fixtures/drive_twilight_expedition.gd) with real controller input. Step 2 continues
from its Twilight checkpoint on the game's default save paths and returns to Halcyon at the
tether (tests/fixtures/finish_playtest_profile.gd). The result is the save the real game wrote.

Output layout matches docs/playtesting/recovery_playtest.md, so OUT replaces the hand-played
recovery-template folder:

    OUT/data/godot/app_userdata/Below the Abyss/saves/expedition.json   (+ .bak)
    OUT/config/  OUT/cache/                                             (empty)
    OUT/PROFILE.json                                                    (what was built, from what)

The participant's settings are not included: the game starts with its defaults.
This runs a debug (editor) binary. Launching the template once in the playtest export
(the facilitator's check in the script) is still required.
"""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from validate_godot import ANSI, ERROR, GODOT, LOGS, ROOT

USER_DIR = Path("godot/app_userdata/Below the Abyss")
SAVE = USER_DIR / "saves/expedition.json"
DRIVER_PROFILE = "playtest-profile"
BLOOM = {"collect": "zone1-light-bloom-collect", "observe": "zone1-light-bloom-observe"}
SENTINEL = {"release": "zone2-sentinel-release", "capture": "zone2-sentinel-capture"}
SCHEMA_VERSION = 10
SCHEMA_FIELDS = 12


def default_out(bloom: str, sentinel: str) -> Path:
    return ROOT / "build/playtest-profiles" / f"{bloom}-{sentinel}"


def xdg(base: Path) -> dict:
    env = {k: v for k, v in os.environ.items() if k != "BTA_EVIDENCE_DIR"}
    env.update(XDG_DATA_HOME=str(base / "data"), XDG_CONFIG_HOME=str(base / "config"),
               XDG_CACHE_HOME=str(base / "cache"))
    return env


def validate_profile(save: dict, bloom: str, sentinel: str) -> None:
    """Raise ValueError unless the save is a dock checkpoint holding the requested choices."""
    if save.get("schema_version") != SCHEMA_VERSION or len(save) != SCHEMA_FIELDS:
        raise ValueError(f"expected schema {SCHEMA_VERSION} with {SCHEMA_FIELDS} fields, got "
                         f"{save.get('schema_version')} with {len(save)}")
    if save.get("journey", {}).get("phase") != "refit":
        raise ValueError(f"last checkpoint is not at the Halcyon dock: {save.get('journey')}")
    decisions = save.get("story", {}).get("decisions", [])
    for wanted in (BLOOM[bloom], SENTINEL[sentinel]):
        if wanted not in decisions:
            raise ValueError(f"missing story decision {wanted}: {decisions}")
    awards = save.get("prototype", {}).get("campaign", {}).get("awards", [])
    if "twilight-expedition" not in awards:
        raise ValueError(f"Twilight debrief allowance not claimed: {awards}")


def manifest(save: dict, bloom: str, sentinel: str, commit: str) -> dict:
    ranks = save["prototype"]["campaign"]["ranks"]
    return {
        "built_by": "tools/build_playtest_profile.py (scripted controller input, not human play)",
        "source_commit": commit,
        "bloom": bloom,
        "sentinel": sentinel,
        "ranks": ranks,
        "research": sorted(save.get("progress", {}).get("research", [])),
        "region_id": save.get("region_id"),
        "journey": save.get("journey"),
    }


def run(name: str, arguments: list, env: dict, token: str, timeout: int) -> str:
    """Same rules as validate_godot.run_check (exit code and logged Godot errors), with an
    isolated user directory."""
    command = [GODOT, "--headless", "--path", str(ROOT), *arguments]
    log = LOGS / f"{name}.log"
    print(f"Running {name}: {command}", flush=True)
    with log.open("w", encoding="utf-8") as output:
        try:
            result = subprocess.run(command, cwd=ROOT, env=env, stdout=output,
                                    stderr=subprocess.STDOUT, timeout=timeout, check=False)
        except subprocess.TimeoutExpired as error:
            raise RuntimeError(f"{name} timed out after {timeout} s; see {log}") from error
    text = ANSI.sub("", log.read_text(encoding="utf-8", errors="replace"))
    if result.returncode != 0:
        raise RuntimeError(f"{name} exited {result.returncode}; see {log}")
    if ERROR.search(text):
        raise RuntimeError(f"{name} logged a Godot error; see {log}")
    if token not in text:
        raise RuntimeError(f"{name} did not print {token}; see {log}")
    return text


def commit() -> str:
    head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True)
    dirty = subprocess.run(["git", "status", "--porcelain"], cwd=ROOT, capture_output=True, text=True)
    return head.stdout.strip() + ("-dirty" if dirty.stdout.strip() else "")


def build(bloom: str, sentinel: str, out: Path) -> dict:
    if out.exists() and any(out.iterdir()):
        raise RuntimeError(f"{out} is not empty. Choose another --out or remove it first.")
    LOGS.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="bta-profile-") as scratch:
        work = Path(scratch)
        run("profile-chapters", ["--fixed-fps", "60", "--script",
                                 "res://tests/fixtures/drive_twilight_expedition.gd",
                                 "--quit-after", "180000", "--", f"--profile={DRIVER_PROFILE}",
                                 "--input=controller", f"--outcome={bloom}",
                                 f"--sentinel={sentinel}"],
            xdg(work), "TWILIGHT_EXPEDITION_INPUT_PASS", timeout=600)
        played = work / "data" / USER_DIR / f"{DRIVER_PROFILE}.json.expedition.json"
        (out / "data" / SAVE).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(played, out / "data" / SAVE)
    run("profile-dock", ["--fixed-fps", "60", "--script",
                         "res://tests/fixtures/finish_playtest_profile.gd", "--quit-after", "36000"],
        xdg(out), "PLAYTEST_PROFILE_DOCK_PASS", timeout=300)
    # Keep only what a release build reads for the campaign. Settings stay at first-run defaults.
    user = out / "data" / USER_DIR
    (user / "settings.json").unlink(missing_ok=True)
    shutil.rmtree(user / "logs", ignore_errors=True)
    for folder in ("config", "cache"):
        shutil.rmtree(out / folder, ignore_errors=True)
        (out / folder).mkdir()
    save = json.loads((out / "data" / SAVE).read_text(encoding="utf-8"))
    validate_profile(save, bloom, sentinel)
    # A fresh launch on a throwaway copy, as a facilitator would check it. The template is untouched.
    with tempfile.TemporaryDirectory(prefix="bta-profile-check-") as scratch:
        copy = Path(scratch) / "copy"
        shutil.copytree(out, copy)
        run("profile-check", ["--fixed-fps", "60", "--script",
                              "res://tests/fixtures/finish_playtest_profile.gd", "--quit-after",
                              "36000", "--", "--check"],
            xdg(copy), "PLAYTEST_PROFILE_CHECK_PASS", timeout=300)
    details = manifest(save, bloom, sentinel, commit())
    (out / "PROFILE.json").write_text(json.dumps(details, indent=2) + "\n", encoding="utf-8")
    return details


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--bloom", choices=sorted(BLOOM), default="collect")
    parser.add_argument("--sentinel", choices=sorted(SENTINEL), default="release",
                        help="the lost outcome is not supported by the scripted route")
    parser.add_argument("--out", type=Path, help="default: build/playtest-profiles/<bloom>-<sentinel>")
    args = parser.parse_args()
    out = (args.out or default_out(args.bloom, args.sentinel)).resolve()
    created = not out.exists()
    try:
        details = build(args.bloom, args.sentinel, out)
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        if created:
            shutil.rmtree(out, ignore_errors=True)
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
    print(json.dumps(details, indent=2))
    print(f"PASS: caves-ready profile at {out}")


if __name__ == "__main__":
    main()
