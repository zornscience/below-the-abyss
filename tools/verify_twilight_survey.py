#!/usr/bin/env python3
"""Optional inner circuit, both input devices, complete chapter and durable records."""
import sys
import time
from validate_godot import LOGS, run_check


def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    prefix = f"bta056-{time.time_ns()}"
    try:
        for device, bloom, sentinel in [("keyboard", "observe", "release"), ("controller", "collect", "capture")]:
            common = ["--fixed-fps", "60", "--script", "res://tests/fixtures/drive_twilight_survey.gd",
                      "--quit-after", "180000", "--", "--comfort", "--no-excavation",
                      f"--profile={prefix}-{device}", f"--input={device}", f"--outcome={bloom}",
                      f"--sentinel={sentinel}"]
            for resume in (False, True):
                output = run_check(f"twilight-survey-{device}-{'continue' if resume else 'fresh'}",
                                   common + (["--twilight-resume"] if resume else []), timeout=600)
                token = "TWILIGHT_EXPEDITION_CONTINUE_PASS" if resume else "TWILIGHT_EXPEDITION_INPUT_PASS"
                if token not in output or (not resume and "TWILIGHT_SURVEY_INPUT_PASS" not in output):
                    raise RuntimeError(f"Missing {token}")
    except (OSError, RuntimeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
    print("PASS: optional gallery, pockets, anchor and thermal scans; both chapter choices/input devices and Continue")


if __name__ == "__main__":
    main()
