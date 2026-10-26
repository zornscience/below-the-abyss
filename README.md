# Below the Abyss

A 2D underwater exploration and adventure game built with Godot 4.

Current milestone: **BTA-013**. A reusable, signal-driven instrument HUD displays
hull, battery, oxygen, authored depth, safe operating depth and text pressure
warnings. Damage feedback and persistent depleted states accompany the existing
movement/resource/depth prototype. Sonar is explicitly unimplemented; no new
survival or later-milestone mechanics are added.

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

Import and smoke commands must exit with status 0 and no Godot errors. The
movement prototype is expected; later gameplay systems are not implemented.
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

## Movement prototype (BTA-010)

Run `godot --path .`, or press F5. Move with WASD/arrows or left stick/D-pad
(default bindings). Release to coast; reverse thrust to brake. Escape/P/Start
opens input settings and stops the motor. Save changes and select Return to
movement; unsaved edits are discarded on return.

Motion is configured in `resources/balance/prototype_motion.tres`: acceleration
600 px/s², maximum speed 240 px/s, damping 3 s⁻¹. The reusable CharacterBody2D uses
fixed 60-Hz physics, swept wall sliding, interpolation and a smoothed Camera2D.
All cave/submarine visuals are explicitly temporary geometry.

See [movement verification](docs/testing/submarine_movement.md) for the model,
controls, screenshot, test results and manual keyboard/controller/frame-cap course.

## Submarine resources (BTA-011)

Hull, battery and oxygen start at 100 units, configured in
`resources/balance/prototype_resources.tres`. During active simulation, idle
battery drains at 0.25 units/second, full thrust adds 1.5 units/second, and oxygen
drains at 0.5 units/second. Hull changes through its damage/repair APIs; BTA-012 now supplies pressure and
severe-impact damage sources. Movement remains available at zero hull; game-over
and respawn behavior remain outside scope.

Launch `godot --path . -- --debug-controls`, then press Interact
(E/controller A by default) to open the separate development test panel.
Use keyboard arrows/Tab/Enter or controller D-pad/stick/A to consume/repair/refill.
Focusing test controls stops movement and drains; Return to piloting resumes them.
Input settings also stop drains. Indicators show numeric values, EMPTY/DEPLETED,
and one notification per emptying; a positive refill rearms depletion.

See [resource APIs and manual verification](docs/testing/submarine_resources.md)
for configuration, signal/transfer contracts, screenshots, test results, and the
keyboard/controller/refill/frame-cap playtest. This is temporary instrumentation,
not the production HUD or station/game-over system.

## Depth and hull damage (BTA-012)

The cave's authored surface is local Y=0, with 0.25 m per authored unit. Spawn is
130 m deep. CAUTION starts at 260 m; depth strictly beyond the 300 m safe rating
starts a two-second grace period, then four hull units/second of pressure damage.
Descend between X=200–450 into the marked deeper shaft to demonstrate pressure.

Severe impacts use inward normal speed: above 150 px/s, damage is 0.1 per excess
px/s, capped at 20. A full-speed perpendicular hit typically costs 9 hull.
Contact latching and cooldown suppress repeated wall push/jitter damage.
Existing settings and resource checks freeze all simulation clocks while active.

See [depth/damage verification](docs/testing/depth_damage.md) and
[design decisions](docs/decisions/bta-012-depth-damage.md) for mapping, boundaries,
maximum-depth API, screenshots, tests and keyboard/controller playtesting.
The maximum-depth API is ready for a future caller; no upgrade system is added.

## Prototype HUD (BTA-013)

Launch `godot --path .` for the production HUD. Rounded dark instrument cards,
authored vector marks, numeric values/capacities and normalized bars show vessel
resources. Depth warnings spell out **SAFE**, **CAUTION** and **DANGER**, with
ASCEND instructions, authoritative grace time and persistent DEPLETED labels.
Impact and pressure feedback have separate 2.5-second display lifetimes.
No flashing, camera effects, UI focus or gameplay writes are introduced.

The reference window is 1280×800; native Control layouts preserve 16+ pixel text
at smaller sizes, with a minimum supported window of 800×600. Larger and tall
windows retain edge anchoring and a clear gameplay center. The HUD scene is
`scenes/ui/submarine_hud.tscn`; bind an initialized resource, hull and damage
component using `SubmarineHud.bind_sources(...)`. It snapshots initial values,
then follows their signals. Only the grace detail is sampled because that API
has no change signal. Unbound/destroyed sources show INSTRUMENTS DISCONNECTED.

Development instrumentation is opt-in and lives in a separate CanvasLayer:

```sh
godot --path . -- --debug-controls
```

Press E/controller A (or your remapped Interact action) to open resource tests.
Arrows/Tab/Enter or D-pad/stick/A navigate the wrapping button panel. Simulation
stops while testing; Return to piloting resumes it. The regular HUD stays visible
and shows the real domain values. Debug depletion counts and resource mutations
are excluded from the reusable HUD. The editor also exposes `development_mode`
on GameRoot; it defaults to false.

See [HUD verification and screenshots](docs/testing/submarine_hud.md) and
[design decisions](docs/decisions/bta-013-hud.md) for test evidence, layout and
signal contracts, keyboard/controller steps, and screenshot reproduction.

## Input/settings test menu (BTA-004)

Run `godot --path . res://scenes/ui/input_test_menu.tscn` independently. Use arrows/Tab and Enter with a
keyboard; D-pad/left stick and A with a controller. Shoulder buttons cycle focus.
Escape/B cancels. The menu supports choosing an action, capturing a new binding,
adjusting the analog dead zone, saving/reloading/resetting settings, and quitting.
The movement readout and pause/sonar feedback demonstrate inputs only.

Settings save explicitly to `user://settings.json`; invalid loads preserve the
file and use defaults at startup. Menu recovery bindings stay fixed. Rebinding
replaces one device group and preserves the other; conflicting bindings are
rejected. Default dead zone is 0.25, configurable from 0.10 to 0.90.

See [input/settings verification](docs/testing/input_settings.md) for the default
mapping table, model/schema, screenshot, limitations, and complete keyboard-only
and controller-only manual steps. Desktop hardware/controller validation is
separate from synthetic automated input tests.

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
with `test_` and use typed GDScript. The original sample suite checks a JSON round trip and instantiation of the main
scene. BTA-004 adds settings, binding, and menu integration suites; BTA-010 adds
submarine velocity and real physics/camera integration suites; BTA-011 adds
resource transfer, signal, drain and prototype-panel coverage; BTA-012 adds
depth mapping, warning, pressure and collision-damage coverage; BTA-013 adds
HUD initial/signal updates, depletion, rebinding, feedback and responsive-layout
coverage. All previous suites remain enabled.
The wrapper enforces a 180-second timeout and fails on nonzero runner exits,
logged Godot errors, missing/malformed JUnit output, zero tests, an entirely
skipped run, or failing/error test cases. It deletes previous results first.
All normal tests must pass; the summary reports the current suite count. The
original two harness samples remain part of the expanded suite.

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

The sample tests prove harness wiring; BTA-004 covers input/settings, and
BTA-010 covers movement and collisions; BTA-011 covers resource state and signals.
Other gameplay tests belong to the
issues that introduce those systems. Exports and platform certification remain outside scope.

## License

**License decision pending.** No project license has been selected or granted
by this scaffold. Godot has its own MIT license; this does not determine the
license of this repository.
