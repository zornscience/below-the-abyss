#!/usr/bin/env python3
"""Drive title, docking, radio acceptance, exploration, encrypted logs and research rewards."""
import sys
from validate_godot import LOGS, run_check

def main() -> None:
    LOGS.mkdir(parents=True, exist_ok=True)
    try:
        output = run_check("revised-expedition", ["--fixed-fps", "60", "--script",
            "res://tests/fixtures/drive_revision_two.gd", "--quit-after", "90000"], timeout=600)
        if "REVISION_TWO_FLIGHT_PASS" not in output:
            raise RuntimeError("Revised expedition did not complete its assertions")
    except (OSError, RuntimeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
    print("PASS: production controller expedition, docking, encrypted logs and finite research rewards")

if __name__ == "__main__":
    main()
