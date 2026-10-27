#!/usr/bin/env python3
"""Exercise both bloom choices with keyboard/controller, then Continue in new processes."""
import sys
import time
from validate_godot import LOGS, run_check


def main() -> None:
    LOGS.mkdir(parents=True, exist_ok=True)
    prefix = f"bta046-{time.time_ns()}"
    try:
        for outcome in ("observe", "collect"):
            for device in ("keyboard", "controller"):
                arguments = ["--fixed-fps", "60", "--script",
                    "res://tests/fixtures/drive_story_choice.gd", "--quit-after", "12000", "--",
                    "--comfort", f"--outcome={outcome}", f"--input={device}", f"--profile={prefix}-{outcome}-{device}"]
                for resume in (False, True):
                    label = f"story-{outcome}-{device}-{'continue' if resume else 'fresh'}"
                    output = run_check(label, arguments + (["--resume"] if resume else []), timeout=120)
                    if "STORY_CHOICE_WALK_PASS" not in output:
                        raise RuntimeError(f"{label} did not complete its assertions")
    except (OSError, RuntimeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
    print("PASS: both bloom outcomes, keyboard/controller, mute and separate-process Continue")


if __name__ == "__main__":
    main()
