#!/usr/bin/env python3
"""Exercise the full expanded chapter through controller events and real movement."""
import sys
from validate_godot import LOGS, run_check


def main() -> None:
    LOGS.mkdir(parents=True, exist_ok=True)
    try:
        output = run_check("expanded-expedition", ["--fixed-fps", "60", "--script",
            "res://tests/fixtures/drive_expanded_expedition.gd", "--quit-after", "60000"], timeout=150)
        if "EXPANDED_FLIGHT_PASS" not in output:
            raise RuntimeError("Expanded route did not complete its assertions")
    except (OSError, RuntimeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
    print("PASS: expanded controller expedition, scans, debrief, no excavation, full hull")


if __name__ == "__main__":
    main()
