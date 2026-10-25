# Below the Abyss

A 2D underwater exploration and adventure game built with Godot 4.

Current milestone: **BTA-003**. The project boots an empty `GameRoot` scene,
validated by GitHub Actions.
GUT supplies deterministic sample tests. Gameplay, controls, settings, and assets
are not implemented.

## Requirements

- **Godot 4.6.3 stable**, standard edition (GDScript), pinned in `.godot-version`.
  The verified Linux binary reports `4.6.3.stable.official.7d41c59c4`.
- Git, Python 3.9+, and curl for the checksum-pinned GUT test dependency.
  No .NET SDK or export templates are required.

Read [AGENTS.md](AGENTS.md), [GDD.md](GDD.md), [TDD.md](TDD.md), and
[CODEX_PLAN.md](CODEX_PLAN.md) before implementation.

## Import and launch

From the repository root, with the pinned Godot executable on PATH as `godot`:

```sh
godot --version
godot --headless --path . --editor --import
godot --path . --editor
```

Run the main scene directly:

```sh
godot --path .
```

For headless startup validation (exits after 60 engine iterations):

```sh
godot --headless --path . --quit-after 60
```

Import and smoke commands must exit with status 0 and no Godot errors. A blank
window is expected; there are no gameplay scripts or interactive elements yet.
This smoke check validates startup, not gameplay or a unit test suite.

In the managed cloud environment, initialize writable Godot cache paths before
running these commands:

```sh
export XDG_CACHE_HOME=/workspace/.cache
export XDG_DATA_HOME=/workspace/.local/share
export XDG_CONFIG_HOME=/workspace/.config
mkdir -p "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"
cd /workspace/below-the-abyss
```

## Manual verification

1. Import `project.godot` with Godot 4.6.3 stable.
2. Open `scenes/main/main.tscn` and confirm its only node is `GameRoot` (Node).
3. Press **F6** to run this scene, then stop it with **F8**.
4. Press **F5** to run the configured project main scene. Confirm a blank window
   appears and the Debugger reports no errors or missing resources.
5. Close the game window or press **F8** to stop. Confirm `git status --short`
   shows no generated cache files; `.godot/` is ignored.

Keyboard/gamepad behavior and accessibility flows have no implementation in this
empty scaffold. Graphical desktop verification is required separately from
headless validation.

## Directory layout

Empty directories are retained with `.gitkeep` files and match TDD section 3:

```text
assets/{art,audio,fonts,shaders}/
scenes/{main,player,creatures,regions,stations,ui,props}/
scripts/{core,player,sonar,ai,missions,world,persistence,ui}/
resources/{equipment,creatures,missions,regions,balance}/
tests/{unit,integration,fixtures}/
tools/
docs/{design,decisions,testing}/
.github/workflows/
```

No exports or native Windows/macOS runtime validation are included.

## Continuous integration (BTA-002)

[`godot-validation.yml`](.github/workflows/godot-validation.yml) runs on every
pull request targeting `main` (including fork PRs) and on pushes to `main`.
It uses Ubuntu 24.04, read-only repository permissions, and no project secrets.
The checkout and artifact actions are pinned to full commit SHAs.

The workflow downloads the standard Linux x86_64 **Godot 4.6.3 stable** archive
from the official `godotengine/godot-builds` release and verifies its SHA-512
against the pinned entry from that release's
[`SHA512-SUMS.txt`](https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/SHA512-SUMS.txt).
The validator logs and requires the exact engine version
`4.6.3.stable.official.7d41c59c4` and checks `.godot-version` agrees.

Run the same validator locally from the repository root with Godot on PATH:

```sh
python3 tools/install_gut.py
python3 tools/validate_godot.py
python3 tools/run_tests.py
```

Python 3.9+ is required; it uses only the standard library. Set `GODOT_BIN` to
an executable path if needed. Initialize the writable XDG directories above in
the managed cloud environment.

The validator runs these engine commands in order:

```sh
godot --headless --path . --version
godot --headless --path . --editor --import
# Repeated for each authored .gd file, including scripts not used by a scene:
godot --headless --path . --check-only --script res://path/to/script.gd
godot --headless --path . --quit-after 60
```

The parser command repeats for authored scripts, including the sample tests.
Pinned `addons/gut/` is excluded from individual script parsing because its
internal static dependencies require GUT loader ordering (standalone parsing of
`version_numbers.gd` causes a circular initialization error). Headless import
still validates project resources and registers GUT classes, and the GUT runner
loads/exercises the framework. Other authored scripts and addons retain explicit
parser checks. The separate unit-test step follows the existing validation step.

Nonzero exits, timeouts, and logged Godot errors fail validation, including errors
Godot reports with exit status zero. Engine operations have time limits, and the
job has a ten-minute limit. The smoke check runs the configured main scene for
60 engine iterations; it does not validate gameplay, rendering, input, or audio.

Logs are written under ignored `build/ci-logs/` (override with `CI_LOG_DIR`).
Open the **Godot validation** Actions run and download its
`godot-validation-<run_id>-<run_attempt>` artifact for the installation log,
engine version, import output, parser inventory/per-script results, smoke output,
and summary. Artifacts are retained for 14 days and uploaded even after failure;
only phases reached before a failure have logs. Local runs refresh validation
logs to avoid reporting stale results. GUT installation output, unit-test logs,
JUnit XML, and a test-count summary are included in the same artifact. CI does
not export builds.

## Automated GDScript tests (BTA-003)

The test-only dependency is **GUT 9.6.1**, whose upstream compatibility table
specifies Godot 4.6.x. It is pinned to commit
`c80954f47bed74a0a2c471d472c0389f98e0a8f6`, with archive SHA-256
`343ba244e66e110273f4f6ca5343c16858eae19c0e35e9b45d404cf3385eba81`.
The [installer](tools/install_gut.py) downloads this exact commit over verified
HTTPS and checks the digest before copying only `addons/gut/`. This dependency
is ignored by Git and installed fresh in CI. An existing installation is verified
without overwriting its source files; a mismatch fails with the affected path.
Preserve any local addon edits before deliberately removing/reinstalling it.
Installation needs access to `codeload.github.com`; test execution is offline.

GUT is MIT-licensed by Tom "Butch" Wesley. The installer retains the complete
upstream `addons/gut/LICENSE.md` and copyright notices. See the
[pinned upstream README](https://github.com/bitwes/Gut/blob/c80954f47bed74a0a2c471d472c0389f98e0a8f6/README.md)
and [GUT 9.6.1 documentation](https://gut.readthedocs.io/en/v9.6.1/).
This test dependency's license does not select a license for this project.
No editor plugin activation is needed for headless tests.

From the repository root, after initializing XDG paths above when in the cloud:

```sh
python3 tools/install_gut.py
python3 tools/validate_godot.py
python3 tools/run_tests.py
```

These are the exact commands used by GitHub Actions after installing Godot.
`GODOT_BIN` and `CI_LOG_DIR` work for both runners. The unit-test command requires
an imported project, verifies the exact engine version, and runs the equivalent of:

```sh
godot --headless --path . --script res://addons/gut/gut_cmdln.gd \
  -gexit -gdisable_colors -gjunit_xml_file=res://build/ci-logs/unit-tests.xml
```

[`.gutconfig.json`](.gutconfig.json) recursively discovers `test_*.gd` in
`tests/unit/` and `tests/integration/`. Tests extend `GutTest`; test methods start
with `test_` and use typed GDScript. The sample suite checks a JSON round trip and
instantiation of the existing empty main scene; it adds no gameplay logic.
The wrapper enforces a 180-second timeout and fails on nonzero runner exits,
logged Godot errors, missing/malformed JUnit output, zero tests, an entirely
skipped run, or failing/error test cases. It deletes previous results first.
Expected sample result: **2 passed, 0 failed, 0 skipped**.

Results are in `build/ci-logs/unit-tests.log`, `unit-tests.xml`, and
`unit-tests-summary.log`. Read the counts to distinguish passed, failed, and
skipped tests. These files and `gut-install.log` upload with the existing
14-day CI artifact, including on test failure.

To reproduce the intentional assertion failure independently:

```sh
python3 tools/run_tests.py --failure-demo
```

This command selects only `tests/fixtures/intentional_failure.gd`, writes
`failure-demo.log`, `failure-demo.xml`, and `failure-demo-summary.log`, and
**must exit 1** with one failed test. It does not treat the failure as success.
The fixture directory is excluded from normal discovery so the regular suite
stays green. To demonstrate a failing CI run, temporarily copy this fixture to
`tests/unit/test_intentional_failure.gd` on a review branch and push it to an open
PR. The existing unit-test step must fail and retain its report; remove the
copied file afterward and push again. Do not merge the failing demonstration.

These samples prove harness/discovery/assertion/exit-code wiring only. Gameplay
unit tests belong to the later issues that introduce those systems. No input,
settings, test GUI, gameplay, exports, or platform runtime work is included here.

## License

**License decision pending.** No project license has been selected or granted
by this scaffold. Godot has its own MIT license; this does not determine the
license of this repository.
