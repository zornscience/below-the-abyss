#!/usr/bin/env python3
"""Real-input chapter, fauna, thermal damage/pause and separate-process refit recovery."""
import sys
import time
from validate_godot import LOGS, run_check


def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    prefix = f"bta054-{time.time_ns()}"
    try:
        for device, outcome in [("keyboard", "observe"), ("controller", "collect")]:
            common = ["--fixed-fps", "60", "--script", "res://tests/fixtures/drive_twilight_habitat.gd",
                      "--quit-after", "120000", "--", "--comfort", "--no-excavation",
                      f"--profile={prefix}-{device}", f"--input={device}", f"--outcome={outcome}"]
            for resume in (False, True):
                output = run_check(f"twilight-{device}-{'continue' if resume else 'fresh'}",
                                   common + (["--twilight-resume"] if resume else []), timeout=360)
                token = "CHAPTER_HANDOFF_INPUT_PASS" if resume else "TWILIGHT_HABITAT_WALK_PASS"
                if token not in output:
                    raise RuntimeError(f"Missing {token}")
    except (OSError, RuntimeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
    print("PASS: wildlife, optional vent warning/damage/bypass, pause, both input devices, Continue and refit")


if __name__ == "__main__":
    main()
