#!/usr/bin/env python3
"""Verify explicit chapter finish, two deep routes and real separate-process refit/Continue."""
import sys
import time
from validate_godot import LOGS, run_check


def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    prefix = f"bta053-{time.time_ns()}"
    try:
        for device, outcome in [("keyboard", "observe"), ("controller", "collect")]:
            common = ["--fixed-fps", "60", "--script", "res://tests/fixtures/drive_chapter_handoff.gd",
                      "--quit-after", "90000", "--", "--comfort", "--no-excavation",
                      f"--profile={prefix}-{device}", f"--input={device}", f"--outcome={outcome}"]
            for resume in (False, True):
                label = f"handoff-{device}-{'continue' if resume else 'fresh'}"
                output = run_check(label, common + (["--twilight-resume"] if resume else []), timeout=300)
                token = "CHAPTER_HANDOFF_INPUT_PASS" if resume else "CHAPTER_HANDOFF_CHECKPOINT_PASS"
                if token not in output:
                    raise RuntimeError(f"Missing {token}: {label}")
    except (OSError, RuntimeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
    print("PASS: both buoy choices, keyboard/controller, west/east loops, deep Continue and Halcyon refit/resume")


if __name__ == "__main__":
    main()
