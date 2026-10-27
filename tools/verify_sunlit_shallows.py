#!/usr/bin/env python3
"""Drive the canonical chapter, both paths/devices, plus real separate-process recovery."""
import sys
import time
from validate_godot import LOGS, run_check


def launch(profile, outcome, device, suffix, extra=()):
    args = ["--fixed-fps", "60", "--script", "res://tests/fixtures/drive_sunlit_shallows.gd",
            "--quit-after", "24000", "--", "--comfort", f"--profile={profile}",
            f"--outcome={outcome}", f"--input={device}", *extra]
    output = run_check(f"sunlit-{outcome}-{device}-{suffix}", args, timeout=180)
    token = "SUNLIT_BUOY_CHECKPOINT_PASS" if "--stop-at-buoy" in extra else "SUNLIT_CHAPTER_WALK_PASS"
    if token not in output:
        raise RuntimeError(f"Missing {token}: {suffix}")


def main():
    LOGS.mkdir(parents=True, exist_ok=True)
    prefix = f"bta047-{time.time_ns()}"
    try:
        for outcome in ("observe", "collect"):
            for device in ("keyboard", "controller"):
                profile = f"{prefix}-{outcome}-{device}"
                launch(profile, outcome, device, "full")
                launch(profile, outcome, device, "continue", ["--resume"])
        for outcome, device in [("observe", "keyboard"), ("collect", "controller")]:
            profile = f"{prefix}-mid-{outcome}"
            launch(profile, outcome, device, "quit-at-buoy", ["--stop-at-buoy"])
            launch(profile, outcome, device, "continue-from-buoy", ["--resume", "--checkpoint=buoy"])
    except (OSError, RuntimeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
    print("PASS: canonical chapter, both paths/devices, full and mid-expedition Continue, no combat")


if __name__ == "__main__":
    main()
