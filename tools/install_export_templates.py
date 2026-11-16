#!/usr/bin/env python3
"""Install only the Linux and Windows x86_64 templates from the checksum-pinned official Godot archive."""
import hashlib
import os
import sys
from pathlib import Path
import tempfile
import urllib.request
import zipfile

VERSION = "4.6.3"
SHA512 = "da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68"
URL = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/Godot_v{VERSION}-stable_export_templates.tpz"
# Both platforms come from the one verified archive; nothing else is extracted.
TEMPLATES = [
    "linux_release.x86_64",
    "linux_debug.x86_64",
    "windows_release_x86_64.exe",
    "windows_debug_x86_64.exe",
    "version.txt",
]


def template_root():
    # Where the Godot editor looks for templates: %APPDATA%/Godot on Windows, XDG data elsewhere.
    if sys.platform == "win32":
        return Path(os.environ["APPDATA"]) / "Godot/export_templates/4.6.3.stable"
    return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "godot/export_templates/4.6.3.stable"


def main():
    root = template_root()
    # Reuse only after checking an installation's manifest, never just its filename.
    marker = root / "bta-official-sha512.txt"
    if marker.exists() and marker.read_text().strip() == SHA512 and all((root / f).is_file() for f in TEMPLATES):
        print(f"Pinned templates already installed: {root}")
        return
    with tempfile.TemporaryDirectory(prefix="bta-templates-") as tmp:
        archive = Path(tmp) / "templates.tpz"
        print("Downloading official templates (approximately 1.2 GiB); verifying SHA512")
        urllib.request.urlretrieve(URL, archive)
        digest = hashlib.sha512()
        with archive.open("rb") as source:
            for block in iter(lambda: source.read(1024 * 1024), b""):
                digest.update(block)
        if digest.hexdigest() != SHA512:
            raise SystemExit("Template checksum mismatch; installation cancelled")
        root.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive) as z:
            for name in TEMPLATES:
                (root / name).write_bytes(z.read("templates/" + name))
        marker.write_text(SHA512 + "\n")
    print(f"Verified templates installed: {root}")


if __name__ == "__main__":
    main()
