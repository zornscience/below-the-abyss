# Linux and Windows playtest builds

Requires the exact Godot standard engine 4.6.3.stable.official.7d41c59c4, its matching
standard Linux and Windows x86_64 export templates (one archive), Git and Python 3.9+ for packaging. No export
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
a pinned SHA512 from the official release, then installs only the Linux and Windows x86_64 templates into
XDG_DATA_HOME/godot/export_templates/4.6.3.stable. A manifest marks the verified
installation. Existing templates without that marker are not blindly trusted.
Template/hash failures are errors, never a claimed successful package.

The export uses Linux Playtest and Windows Playtest in export_presets.cfg, which share
the same settings: release, x86_64, Compatibility renderer, embedded PCK, playtest
feature and exclusions (tests/python/test_playtest_packaging.py enforces the match).
Windows is exported from Linux; it is unsigned, has no console wrapper and keeps the
stock Godot icon/version resource (application/modify_resources=false, so no rcedit). Required runtime resources, including
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

By default both platforms are built (`--platform linux|windows|all`). Output:
build/playtest/below-the-abyss.x86_64, build/playtest-windows/below-the-abyss.exe,
build/below-the-abyss-playtest-linux-<build-id>.zip and
build/below-the-abyss-playtest-windows-<build-id>.zip. These outputs are gitignored.
The dependent CI jobs retain manifests and smoke logs for 3 days; package zips are only passed between jobs (1 day). No build is automatically published publicly or sent to participants. Unzip a copy elsewhere
and launch its executable without Godot installed. Keep manifest/checksum alongside
any voluntarily distributed artifact. See verification.md for recorded smoke/native
evidence and unverified platforms/performance.

## Windows release smoke

`tools/smoke_playtest.py` recognises the package from its inventory and refuses to
run a Windows zip on Linux (or the reverse). The `playtest-windows` CI job runs on
`windows-latest`, fetches the zip that `playtest-linux` built in the same run, and
runs the full release smoke (every `RELEASE_*_PASS` token, including
RELEASE_OXYGEN_WIRING_PASS) plus every `--break-*-wiring` negative. On Windows the
smoke isolates user data with APPDATA/LOCALAPPDATA and also reads Godot's
`--log-file`, because the exe is a GUI-subsystem program whose piped stdout is not
a guaranteed channel.

## Publishing a draft pre-release (manual)

Actions → Godot validation → Run workflow → branch `main`, enter a new tag such as
`playtest-2026-11-15`. Every check runs first. Only if all pass does the
`publish-playtest-prerelease` job (the only job with `contents: write`) create a
**draft pre-release** with both zips and SHA256SUMS.txt. It refuses a branch other
than main, an existing tag or release, or a malformed tag. It never runs on push or
pull request. A draft does not create the tag until someone publishes it.

## Downloading and sharing a build

The repository is private, so **testers cannot download from GitHub**: release
assets of a private repository (draft or published) require a GitHub account with
access to it. Do not add testers as collaborators to give them a download.

1. On GitHub open the repository → Releases. Drafts are visible only to people with
   write access. Open the "Playtest <tag>" draft and expand Assets.
2. Download `below-the-abyss-playtest-windows-<build-id>.zip` (and/or the Linux zip)
   and `SHA256SUMS.txt`.
3. Upload the zip to a file-sharing service you control (any service that gives a
   link-only or per-person share) and send each tester the link plus the zip's
   SHA256 line from `SHA256SUMS.txt`.
4. Testers can check the file before extracting. Windows PowerShell:
   `Get-FileHash .\below-the-abyss-playtest-windows-<build-id>.zip -Algorithm SHA256`
   (or `certutil -hashfile <zip> SHA256`); Linux: `sha256sum <zip>`.
5. Delete the draft (or leave it unpublished) when the round ends. The draft is
   only a private hand-off point, never a public release.

## Windows "unknown publisher" warning (unsigned build)

The exe is not code-signed, so Windows marks it as coming from an unknown
publisher. Tell testers this is expected for this playtest and give them these
steps:

1. Extract the whole zip first (right-click → Extract All… → Extract). Do not run
   the exe from inside the zip window.
2. Optional, avoids step 4: before extracting, right-click the zip → Properties →
   tick **Unblock** at the bottom of the General tab → OK.
3. Open the extracted `below-the-abyss` folder and double-click `below-the-abyss.exe`.
4. If a blue "Windows protected your PC" box appears ("Microsoft Defender
   SmartScreen prevented an unrecognized app from starting"), click **More info**,
   check it shows App: below-the-abyss.exe and Publisher: Unknown publisher, then
   click **Run anyway**. Windows remembers this for that copy of the file.

Browsers may also warn when downloading an uncommon exe inside a zip; in Edge use
"…" → Keep → Show more → Keep anyway, in Chrome choose Keep. If Windows 11
**Smart App Control** is on, it blocks unsigned apps with no "Run anyway" button;
there is no workaround short of signing, and turning Smart App Control off cannot be
undone without reinstalling Windows, so such testers should not be asked to do it.
These dialog wordings follow Microsoft's current UI and have not been checked on a
real Windows machine for this project.
