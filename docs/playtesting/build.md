# Linux playtest build

Requires the exact Godot standard engine 4.6.3.stable.official.7d41c59c4, its matching
standard Linux x86_64 export templates, Git and Python 3.9+ for packaging. No export
SDK, new third-party runtime dependency or analytics service is added.

```sh
# Set writable XDG paths in the managed cloud, as in the project README.
python3 tools/install_export_templates.py
python3 tools/install_gut.py
python3 tools/validate_godot.py
python3 tools/run_tests.py
python3 -m unittest discover -s tests/python -v
# From a clean committed checkout:
python3 tools/build_playtest.py
# Explicit uncommitted development verification only:
python3 tools/build_playtest.py --allow-dirty
```

The installer downloads the official standard template archive (~1.2 GiB), verifies
a pinned SHA512 from the official release, then installs only Linux templates into
XDG_DATA_HOME/godot/export_templates/4.6.3.stable. A manifest marks the verified
installation. Existing templates without that marker are not blindly trusted.
Template/hash failures are errors, never a claimed successful package.

The export uses Linux Playtest in export_presets.cfg: release, x86_64, Compatibility
renderer, embedded PCK and playtest feature. Required runtime resources, including
dynamically selected audio, are exported. Tests/GUT/docs/tools/example scenes and
the development movement fixture are excluded. The normal main scene opens; the
playtest feature hides/disables Restart Test Route and blocks --debug-controls.
The ordinary source development fixture remains available and unchanged in purpose.

The builder temporarily stamps resources/playtesting/build_info.json, restores it
in finally, imports, exports and packages the executable with START_HERE, FEEDBACK,
LOCAL_REPORTS, engine license and manifest. Build ID is the clean commit SHA; explicit
dirty exports use a source-content digest and manifest development_dirty=true.
The manifest includes game/engine versions, source commit and executable SHA256.
The procedure is version-pinned/repeatable, not a claim of byte-identical Godot
exports across machines. Review all logs; errors fail the command.

Output: build/playtest/below-the-abyss.x86_64 and
build/below-the-abyss-playtest-linux-<build-id>.zip. These outputs are gitignored.
The dependent CI job also retains a reviewable package/manifest/log artifact for 14 days. No build is automatically published publicly or sent to participants. Unzip a copy elsewhere
and launch its executable without Godot installed. Keep manifest/checksum alongside
any voluntarily distributed artifact. See verification.md for recorded smoke/native
evidence and unverified platforms/performance.
