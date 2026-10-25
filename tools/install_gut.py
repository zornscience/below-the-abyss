#!/usr/bin/env python3
"""Install the exact MIT-licensed GUT 9.6.1 addon, without modifying its files."""

import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
COMMIT = "c80954f47bed74a0a2c471d472c0389f98e0a8f6"
SHA256 = "343ba244e66e110273f4f6ca5343c16858eae19c0e35e9b45d404cf3385eba81"
URL = f"https://codeload.github.com/bitwes/Gut/zip/{COMMIT}"


def main() -> None:
    target = ROOT / "addons/gut"
    with tempfile.TemporaryDirectory(prefix="bta-gut-") as temporary:
        archive = Path(temporary) / "gut.zip"
        subprocess.run([
            "curl", "--fail", "--location", "--retry", "3",
            "--connect-timeout", "15", "--max-time", "180",
            URL, "--output", str(archive),
        ], check=True)
        if hashlib.sha256(archive.read_bytes()).hexdigest() != SHA256:
            raise RuntimeError("GUT archive checksum mismatch; refusing installation")
        prefix = f"Gut-{COMMIT}/addons/gut/"
        with zipfile.ZipFile(archive) as source:
            files = {
                name[len(prefix):]: source.read(name)
                for name in source.namelist()
                if name.startswith(prefix) and not name.endswith("/")
            }
        if "LICENSE.md" not in files or "gut_cmdln.gd" not in files:
            raise RuntimeError("GUT archive is missing required files")
        if any(Path(name).is_absolute() or ".." in Path(name).parts for name in files):
            raise RuntimeError("Unsafe archive path")
        if target.exists():
            # Godot may add import caches. Verify every upstream source file
            # without overwriting local changes or unrelated generated files.
            for name, contents in files.items():
                path = target / name
                if not path.is_file() or path.read_bytes() != contents:
                    raise RuntimeError(f"{path} differs from the pin; refusing to overwrite it")
        else:
            staged = Path(temporary) / "gut"
            for name, contents in files.items():
                path = staged / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(contents)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copytree(staged, target)
    print(f"GUT 9.6.1 installed/verified at {target}; commit {COMMIT}; SHA-256 {SHA256}")


if __name__ == "__main__":
    main()
