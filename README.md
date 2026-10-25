# Below the Abyss

A 2D underwater exploration and adventure game built with Godot 4.

Current milestone: **BTA-002**. The project boots an empty `GameRoot` scene,
validated by GitHub Actions.
Gameplay, controls, settings, assets, and a test framework are not implemented.

## Requirements

- **Godot 4.6.3 stable**, standard edition (GDScript), pinned in `.godot-version`.
  The verified Linux binary reports `4.6.3.stable.official.7d41c59c4`.
- Git. No third-party packages, .NET SDK, or export templates are needed to
  import or run this scaffold.

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
window is expected; there are no scripts, resources, or interactive elements yet.
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

A test harness belongs to BTA-003. No exports or native Windows/macOS runtime
validation are included.

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
python3 tools/validate_godot.py
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

The parser command is an example: this scaffold currently contains no GDScript,
so the parser log explicitly reports zero script checks. Import still validates
the project resources; future scripts are discovered automatically.

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
logs to avoid reporting stale results. CI does not export builds or implement a
unit test framework.

## License

**License decision pending.** No project license has been selected or granted
by this scaffold. Godot has its own MIT license; this does not determine the
license of this repository.
