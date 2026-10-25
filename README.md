# Below the Abyss

A 2D underwater exploration and adventure game built with Godot 4.

Current milestone: **BTA-001**. The project boots an empty `GameRoot` scene.
Gameplay, controls, settings, assets, CI, and a test framework are not implemented.

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

CI and a test harness belong to BTA-002 and BTA-003. No exports or native
Windows/macOS runtime validation are included in BTA-001.

## License

**License decision pending.** No project license has been selected or granted
by this scaffold. Godot has its own MIT license; this does not determine the
license of this repository.
