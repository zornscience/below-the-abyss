#!/usr/bin/env python3
"""Run pinned GUT tests, retain results, and reject missing/empty test reports."""

import argparse
import os
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

from validate_godot import LOGS, ROOT, VERSION, run_check


def annotate_failure(name: str, report: Path, message: str) -> None:
    """Expose actionable failures in check annotations as well as retained log ZIPs."""
    if os.environ.get("GITHUB_ACTIONS") != "true":
        return
    details = [message]
    if report.is_file():
        try:
            for case in ET.parse(report).getroot().findall(".//testcase"):
                for failure in case.findall("failure") + case.findall("error"):
                    details.append(f"{case.get('classname')}/{case.get('name')}: {failure.text or failure.get('message', '')}")
        except (OSError, ET.ParseError):
            pass  # The original validation error remains authoritative.
    log = LOGS / f"{name}.log"
    if log.is_file():
        lines = log.read_text(encoding="utf-8", errors="replace").splitlines()
        for index, line in enumerate(lines):
            if line.lstrip().startswith(("ERROR:", "SCRIPT ERROR:", "USER ERROR:")):
                details.append("\n".join(lines[index:index+6]))
    for detail in details[:10]:
        escaped = detail[:6000].replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
        print(f"::error title=GUT validation failure::{escaped}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--failure-demo", action="store_true",
                        help="Run only the intentional failure fixture; expect exit 1")
    options = parser.parse_args()
    name = "failure-demo" if options.failure_demo else "unit-tests"
    LOGS.mkdir(parents=True, exist_ok=True)
    report = LOGS / f"{name}.xml"
    summary = LOGS / f"{name}-summary.log"
    for path in (report, summary, LOGS / f"{name}.log"):
        path.unlink(missing_ok=True)
    try:
        version = run_check("test-engine-version", ["--version"], timeout=15)
        if VERSION not in version.splitlines():
            raise RuntimeError(f"Tests require {VERSION}")
        if not (ROOT / "addons/gut/gut_cmdln.gd").is_file():
            raise RuntimeError("Run python3 tools/install_gut.py and headless import first")
        arguments = [
            "--script", "res://addons/gut/gut_cmdln.gd", "-gexit",
            "-gdisable_colors", f"-gjunit_xml_file={report}",
        ]
        if options.failure_demo:
            arguments += ["-gconfig=", "-gtest=res://tests/fixtures/intentional_failure.gd"]
        command_error = None
        try:
            # The expanded mission/route walkthrough keeps real-time physics coverage.
            run_check(name, arguments, timeout=600)
        except RuntimeError as error:
            command_error = error
        # Removed before execution: an existing report cannot make a failed or
        # zero-test run look successful.
        result = ET.parse(report).getroot()
        cases = result.findall(".//testcase")
        failures = len(result.findall(".//failure"))
        errors = len(result.findall(".//error"))
        skipped = len(result.findall(".//skipped"))
        passed = len(cases) - failures - errors - skipped
        counts = f"tests={len(cases)}, passed={passed}, failures={failures}, errors={errors}, skipped={skipped}"
        print(counts, flush=True)
        if command_error:
            raise RuntimeError(f"{counts}; {command_error}")
        if not cases or passed < 1 or failures or errors:
            raise RuntimeError(f"Invalid/unsuccessful test results: {counts}")
        message = f"PASS: {counts}\n"
    except (OSError, RuntimeError, ET.ParseError) as error:
        message = f"FAIL: {error}\n"
        summary.write_text(message, encoding="utf-8")
        print(message, file=sys.stderr)
        annotate_failure(name, report, message)
        sys.exit(1)
    summary.write_text(message, encoding="utf-8")
    print(message, flush=True)


if __name__ == "__main__":
    main()
