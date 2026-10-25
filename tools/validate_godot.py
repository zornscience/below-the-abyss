#!/usr/bin/env python3
"""Run the same bounded, logged Godot checks locally and in GitHub Actions."""

import os
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
LOGS = Path(os.environ.get("CI_LOG_DIR", ROOT / "build/ci-logs")).resolve()
GODOT = os.environ.get("GODOT_BIN", "godot")
VERSION = "4.6.3.stable.official.7d41c59c4"
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
ERROR = re.compile(r"^\s*(?:SCRIPT ERROR:|ERROR:|USER ERROR:|Parse Error:)", re.MULTILINE)


def run_check(name: str, arguments: list[str], timeout: int = 120) -> str:
    """Keep the command's status and output; also reject Godot's logged errors."""
    command = [GODOT, "--headless", "--path", str(ROOT), *arguments]
    log = LOGS / f"{name}.log"
    print(f"Running {name}: {command}", flush=True)
    with log.open("w", encoding="utf-8") as output:
        output.write(f"Command: {command}\n")
        output.flush()
        try:
            result = subprocess.run(
                command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT,
                timeout=timeout, check=False,
            )
        except subprocess.TimeoutExpired as error:
            output.write(f"VALIDATION FAILURE: exceeded {timeout} seconds\n")
            raise RuntimeError(f"{name} timed out; see {log}") from error
    text = ANSI.sub("", log.read_text(encoding="utf-8", errors="replace"))
    print(text, flush=True)
    if result.returncode != 0:
        raise RuntimeError(f"{name} exited {result.returncode}; see {log}")
    if ERROR.search(text):
        raise RuntimeError(f"{name} logged a Godot error; see {log}")
    return text


def main() -> None:
    LOGS.mkdir(parents=True, exist_ok=True)
    # Clear this runner's previous results so artifacts cannot imply a skipped
    # phase succeeded. Keep install.log, produced separately by the workflow.
    for pattern in ("version.log", "import.log", "parser*.log", "smoke.log", "summary.log"):
        for path in LOGS.glob(pattern):
            path.unlink()
    try:
        if (ROOT / ".godot-version").read_text().strip() != "4.6.3":
            raise RuntimeError(".godot-version must match the pinned CI version 4.6.3")
        version = run_check("version", ["--version"], timeout=15)
        if VERSION not in version.splitlines():
            raise RuntimeError(f"Expected exact engine version {VERSION}")
        run_check("import", ["--editor", "--import"], timeout=180)
        # Check unreferenced authored scripts too. GUT requires its own loader
        # order (standalone version_numbers.gd initializes a circular dependency).
        # Its pinned files are exercised by project import and the GUT runner.
        scripts = sorted(
            path for path in ROOT.rglob("*.gd")
            if not {".git", ".godot", "build", "exports"}.intersection(
                path.relative_to(ROOT).parts
            )
            and path.relative_to(ROOT).parts[:2] != ("addons", "gut")
        )
        with (LOGS / "parser.log").open("w", encoding="utf-8") as output:
            output.write(f"Discovered {len(scripts)} GDScript file(s).\n")
            output.write("Pinned addons/gut checked by project import and GUT runner, not standalone parsing.\n")
            if not scripts:
                output.write("No GDScript files in this empty scaffold; no script checks executed.\n")
            for index, script in enumerate(scripts, start=1):
                relative = script.relative_to(ROOT).as_posix()
                output.write(f"{index}: {relative}\n")
                output.flush()
                run_check(f"parser-{index:04d}", ["--check-only", "--script", f"res://{relative}"])
        print((LOGS / "parser.log").read_text(), flush=True)
        run_check("smoke", ["--quit-after", "60"])
        message = f"PASS: {VERSION}; import; {len(scripts)} script checks; startup smoke.\n"
    except (OSError, RuntimeError) as error:
        message = f"FAIL: {error}\n"
        (LOGS / "summary.log").write_text(message, encoding="utf-8")
        print(message, file=sys.stderr)
        sys.exit(1)
    (LOGS / "summary.log").write_text(message, encoding="utf-8")
    print(message, flush=True)


if __name__ == "__main__":
    main()
