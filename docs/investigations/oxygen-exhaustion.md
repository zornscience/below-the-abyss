# Investigation: what happens when oxygen reaches zero (Sunlit Shallows and Twilight)

Status: **findings and probes only. No gameplay change is made by this branch.**
Base: `main` at `9713ec7` (merge of PR #51). Measured 2026-11-15 on Godot 4.6.3 headless (debug editor
binary, Linux container, no GPU). Human playtest results do not exist; none are claimed.

Probes: `tests/integration/test_oxygen_exhaustion_probe.gd` (GUT, runs in CI with the full suite) and
`tests/fixtures/measure_oxygen_endurance.gd` (one-off timing fixture, not in CI: a real-time run lasts
about an hour per region).

## 1. Summary

1. **Oxygen at zero has no survival consequence anywhere in the campaign.** The vessel keeps
   simulating, moves, takes no hull damage, and no failure dialog opens. This contradicts GDD §2
   ("on hull destruction or oxygen exhaustion, respawn …"). HANDOFF §6 already lists the gap.
2. **The only gameplay effect is that every checkpoint path guarded by `oxygen>0` refuses to write.**
   The vessel keeps moving, but the player cannot record scans, save manually, or use the Sunlit
   off-screen finish. None of the refusal messages mention oxygen.
3. **Twilight respawn keeps oxygen at zero, as its dialog says.** After a hull death at zero oxygen the
   player respawns at the ascent tether with full hull and zero oxygen. The respawn checkpoint stores
   zero oxygen.
4. **Docking at Halcyon and the Twilight tether refit are not gated on oxygen.** Both refill it.
5. **No state on `main` is unrecoverable.** The fix has a trap, though: if oxygen exhaustion is made
   lethal without changing respawn, the game enters a respawn death loop (measured, §5).
6. **Measured full-to-empty time at normal travel: Sunlit 55.6 min, Twilight 83.3 min of play.**
   Wall-clock figures are in §4.

## 2. Code path (read, then confirmed by the probes)

| Step | Where | What it does |
| --- | --- | --- |
| Drain | `submarine_controller.gd:28` → `submarine_resource_system.gd:97` | Every physics step while the simulation runs: `oxygen -= rate × delta`, clamped at 0. Thrust does not change the oxygen rate (it changes battery only). |
| Rates | `prototype_resources.tres` (Sunlit) `0.03/s`; `twilight_resources.tres` `0.02/s` | Swapped by `chapter_journey.gd:143-148`, preserving current values. |
| Zero | `oxygen_depleted` signal (`submarine_resource_system.gd:44`) | Only listeners: the development resource panel counter (`prototype_resource_panel.gd:87`) and the playtest observer, which records it as a **`failure`** event (`playtest_observer.gd:177`) even though nothing fails. HUD gauge shows `! EMPTY`; `GameplayAudio` alarms at low fraction. |
| Save guard | `save_coordinator.gd:128` `safe_to_save()` | Requires `oxygen>0`. Used by `save_current()` (manual and post-dock save) and `finish_sunlit_return()` (`:491`). |
| Scan guard | `save_coordinator.gd:403` `commit_research_checkpoint()` | Requires `oxygen>0`. It is the completion gate for Sunlit (`sunlit_shallows.gd:279`) and Twilight (`twilight_expedition.gd:276`) scans. On refusal the scanner says `NOT RECORDED / Save unavailable; no outcome committed. Try again after recovery.` (`scientific_scanner.gd:139`). |
| Not guarded | `commit_story()` (`:376`), `commit_progress()` (`:172`), `transfer_chapter()` (`:508`), dock service (`service_station.gd:155`) | Story choices (including the Twilight sentinel, which also writes the vessel pose and supplies), discoveries, the tether refit and Halcyon docking all work at zero oxygen. |
| Hull death | `twilight_depth_gate.gd:40-80` (`show_failure` :47, `respawn` :63) | Only `vessel_destroyed` (hull) opens the respawn dialog. Its text: *"Respawn restores hull at the ascent tether. Battery and oxygen stay as they are."* `respawn()` writes `hull = max`, `position = SPAWN`; oxygen and battery are copied from the live snapshot. On Continue, the panel is re-derived from `hull<=0` only (`_restored`, `:46`). |
| Sunlit hull death | `sunlit_field_guide.gd:158` | No respawn flow; guidance tells the player to Continue the last checkpoint. Sunlit checkpoints that store the vessel all require `oxygen>0`, so a Sunlit Continue never restores zero oxygen. (Code read; not probed here.) |

## 3. Probe results (each fails if the behaviour it claims is absent)

`tests/integration/test_oxygen_exhaustion_probe.gd`, 6 tests, 118 asserts, all passing on `main`
(local run 13.3 s). The scene is the real `main.tscn`. The drain to zero is the real per-step drain
under held input actions. The respawn is confirmed with a real `ui_accept` input event, and the tether
transfer with a real `interact` event plus the `ReturnHalcyon` button.

| Scenario | Probe | Observed on `main` |
| --- | --- | --- |
| Oxygen reaches zero in open water, Sunlit | `test_probe1_sunlit_open_water_…` | Drains to exactly 0.0, `oxygen_depleted` once. 2 s later the vessel is still simulating, still moving under thrust, hull unchanged. Gauge reads `! EMPTY`. `safe_to_save()` false, `save_current()` and the scan checkpoint return `ERR_UNAVAILABLE`. Restoring 1 unit at the same pose makes `safe_to_save()` true, so oxygen alone is the blocker. |
| Same, Twilight | `test_probe1_twilight_open_water_…` | Same as Sunlit, and the failure dialog does not open. |
| Zero oxygen during Sunlit evidence | `test_probe1_sunlit_zero_oxygen_blocks_buoy_scan_…` | A buoy scan **starts** at zero oxygen, runs to 100 % and is **not recorded** (`NOT RECORDED / Save unavailable …`). The same scan at the same pose with 1 unit of oxygen is recorded. With evidence complete, `finish_sunlit_return()` is refused at zero oxygen and accepted at 1 unit. |
| Zero oxygen, hull death, Twilight respawn | `test_probe2_twilight_zero_oxygen_hull_death_…` | Death away from the tether. The dialog opens and contains *"Battery and oxygen stay as they are"*. The failure checkpoint stores hull 0 and oxygen 0. After `ui_accept`: position = `TwilightShelfLayout.SPAWN`, hull 100, **oxygen 0**, battery unchanged in the checkpoint. The checkpoint stays at 12 top-level fields and play resumes. A separate `continue_expedition()` lands at the tether, alive, oxygen 0, with no failure loop. |
| Zero oxygen at a station, Sunlit | `test_probe3_sunlit_zero_oxygen_at_halcyon_…` | Undocked at Halcyon, saving is still refused. `open_station()` succeeds and the report reads `Oxygen 0 → 100`. The docking checkpoint stores 100. |
| Zero oxygen at a station, Twilight (ascent tether) | `test_probe3_twilight_zero_oxygen_at_ascent_tether_…` | `interact` at the tether opens the Halcyon transfer, and `ReturnHalcyon` reaches the refit with oxygen 100 and a checkpoint of 100. Resuming the shelf keeps 100. |

### Negative check: the probes fail when the behaviour is removed

Each mutation was applied to `main`, the probe file was run, and the source was restored
(`git status` clean afterwards). Every mutation produced failures:

| Mutation (temporary, not committed) | Result |
| --- | --- |
| M1 oxygen 0 applies lethal hull damage | 4/6 tests fail (no damage, still moving, no failure, respawn, tether refit) |
| M2 `safe_to_save()` ignores oxygen | 4/6 fail (save refusal, finish refusal) |
| M3 respawn restores oxygen | probe 2 fails (`oxygen NOT restored`) |
| M4 dialog text drops the oxygen sentence | probe 2 fails |
| M5 respawn 600 u from the tether | probe 2 fails |
| M6 dock service skips oxygen | Sunlit probe 3 fails (`Oxygen 0 → 0`) |
| M7 tether refit refused at zero oxygen | Twilight probe 3 fails |
| M8 scan checkpoint ignores oxygen | 3/6 fail (buoy scan recorded at zero oxygen) |

## 4. Measured time from full to empty at normal travel

Method: `tests/fixtures/measure_oxygen_endurance.gd` loads the real `main.tscn`, launches the chapter
(Twilight: commissioning harness, then the real `transfer_chapter("twilight")`), asserts oxygen is full,
then holds real input actions at full stick deflection. The vessel patrols between two authored
open-water waypoints until oxygen reads 0. Sunlit uses `SunlitSurveyData.MAIN_ROUTE[0]↔[1]`. Twilight
uses `TwilightShelfLayout.WEST_LOOP[1]↔SPAWN`. The fixture fails on any pause, any hull loss or a
stall, so the figures cover uninterrupted travel. The resource profile is not read.

| Region | Mode | Physics frames | Simulated play time | Wall-clock time | Other |
| --- | --- | --- | --- | --- | --- |
| Sunlit | `--fixed-fps 60` | 200,000 | 3,333.33 s (**55.6 min**) | 453.7 s (accelerated) | 100 % full-thrust frames, 450 legs, 584,069 u, hull 100, **battery 0.052 at the same moment** |
| Twilight | `--fixed-fps 60` | 300,000 | 5,000.00 s (**83.3 min**) | 769.1 s (accelerated) | 100 % full-thrust frames, 384 legs, 1,015,442 u, hull 100, battery 40.0 left |
| Sunlit | real time (no `--fixed-fps`) | SUNLIT_RT_FRAMES | SUNLIT_RT_SIM | **SUNLIT_RT_WALL** | SUNLIT_RT_OTHER |
| Twilight | real time (no `--fixed-fps`) | TWILIGHT_RT_FRAMES | TWILIGHT_RT_SIM | **TWILIGHT_RT_WALL** | TWILIGHT_RT_OTHER |

Notes:
- The fixed-step runs give the in-game time a player experiences at 60 physics ticks per second. The
  real-time runs check that this matches wall-clock time in a normal (unaccelerated) process. Both
  only count time while the simulation runs. Pause, map, station, dialogs and title pages freeze the
  drain, so a player's session time to empty is longer by however long they spend in menus.
- Sunlit side effect: at continuous full thrust, **battery reaches empty within the same frame range
  as oxygen** (0.052 left). In Twilight, battery outlasts oxygen.
- Against the targets: Sunlit's expedition target is 15–20 min (BTA-051) and Twilight's novice target
  is 30–45 min (unverified). At normal travel oxygen outlasts both by about 2–3×, so a player who keeps
  moving will rarely reach zero. Reaching zero takes deliberate lingering, a very slow novice, or a
  later tuning change (BTA-058 left travel drain slow on purpose).

## 5. Is any state unrecoverable?

**On `main`: no unrecoverable state was found in the probed paths.**

- Oxygen does not limit movement, so a vessel at zero oxygen can always travel. Docking at Halcyon
  (Sunlit) and the tether refit (Twilight) both work at zero and refill it (probe 3).
- The Twilight respawn lands **on** the tether at zero oxygen, so a refit is one Interact away
  (probes 2 and 3).
- Checkpoints that can store zero oxygen: the hull-failure snapshot, the respawn checkpoint and a
  Twilight sentinel decision (`commit_story` writes the vessel without an oxygen guard). Continue from
  any of them leaves a living vessel that can travel to the tether.

**Degraded states the player is not told about.** These are recoverable, but the messages point the
wrong way:
- A scan at zero oxygen runs to 100 % and then reports `NOT RECORDED / Save unavailable … Try again
  after recovery.` Nothing tells the player that refilling oxygen fixes it. A player can repeat the
  scan indefinitely without success.
- Manual save refusal reads *"pause in clear terrain, outside pressure/thermal danger and predator
  alert/pursuit"*. Oxygen is not named.
- The off-screen finish at the buoy is refused with *"Return not saved. Evidence retained; retry after
  checkpoint recovery."* Oxygen is not named.
- Playtest telemetry records an oxygen depletion as a `failure`, but no failure happened. Any
  playtest report that counts failures will overstate them.

**Latent unrecoverable state (the trap for the fix).** Mutation M1 made oxygen zero lethal and left
respawn unchanged. The vessel died, respawned at the tether at zero oxygen, and died again on the next
physics step. `respawn confirmed` failed, and the tether refit (probe 3) could no longer be reached
because the vessel died before the Interact landed. Continue does not help either: the failure
checkpoint stores zero oxygen, and `_restored()` re-derives the dialog from a zero hull. **Any fix
that makes oxygen exhaustion lethal must also stop respawn and Continue from restoring zero oxygen.**

## 6. Proposed fix (not implemented; needs designer approval)

Constraints: reuse the existing respawn flow (`TwilightDepthGate`); schema 10 stays at twelve
top-level fields; no new persisted state. Recommended shape:

1. **Exhaustion damages the hull. It does not kill outright.** At `oxygen == 0` with the simulation
   running, apply the same warning → grace → hull-damage pattern as pressure (BTA-012). That pattern is
   currently a 2 s grace, then 4 hull/s, about 27 s from full hull. Damage goes through
   `SubmarineHullSystem.apply_damage(amount, &"oxygen")`, so death reaches the existing
   `vessel_destroyed → TwilightDepthGate` path unchanged. The grace timer is session-only, like the
   pressure grace, which `continue_expedition()` already resets through `damage_system.configure()`.
   Nothing new is saved. The grace and rate belong in a Resource and are tuned by the designer. The
   grace must exceed the time to reach and use the tether from the respawn point.
2. **Respawn restores oxygen as well as hull.** In `TwilightDepthGate.respawn()`, write
   `candidate.player.oxygen = max_oxygen` alongside `hull`. Battery stays as it is, which keeps the
   current "supplies kept" penalty for battery only. This removes the M1 loop. Without it the fix
   ships an unrecoverable state. The dialog text becomes: *"Respawn restores hull and oxygen at the
   ascent tether. Battery stays as it is. …"* (new player-facing text, flagged for review).
   Alternative for the designer: a floor (e.g. 25 %) instead of full. The tether refit is adjacent
   either way. This is the penalty decision HANDOFF §5 says is still awaiting approval.
3. **Cause text without a new field.** Extend the existing source-to-cause mapping in
   `show_failure()` with `&"oxygen" → "Oxygen reserve exhausted; life support failed"`. As with the
   other causes, `last_damage_source` is not persisted, so after Continue the generic "Hull integrity
   was depleted" appears. That is existing behaviour.
4. **Old saves.** Checkpoints written by today's respawn and sentinel paths can hold zero oxygen. With
   the fix, Continue starts the session-only grace at the saved pose. A tether save refits within the
   grace. A save elsewhere dies after the grace and then respawns with oxygen. No migration, no field.
5. **Sunlit.** There is no respawn flow. The existing Sunlit hull-failure guidance applies: Continue
   the last checkpoint, which always has oxygen above zero. This needs its own probe before the fix
   lands, because the Sunlit hull-death path was not probed here. Whether Sunlit should get a Halcyon
   respawn is a separate design decision.
6. **Messages.** Name oxygen in the three refusal messages (scan `NOT RECORDED`, manual save, buoy
   finish), and in the HUD/Wick warning when oxygen reaches zero. The warning must be textual, not
   colour- or audio-only. Change the playtest `failure` event to fire on the real failure (the
   respawn dialog), not on `oxygen_depleted`.
7. **Release safety.** New wiring (oxygen → hull damage) needs a `ReleaseSmoke` check and a
   `--break-oxygen-wiring` negative case that must fail, following the existing
   `--break-failure-wiring` pattern (`release_smoke.gd:112`).
8. **Acceptance.** Flip probes 1 and 2 to the new behaviour: hull damage after the grace,
   respawn with oxygen. Keep probe 3. Add a loop guard: after respawn, run the simulation for longer
   than the grace and assert no second failure. Re-run the endurance fixture. Rates are unchanged, so
   the measured times should be too.

Out of scope for the fix: changing the drain rates (that is a balance decision, BTA-058), new save
fields, a Sunlit respawn.

## 7. Reproduce

```sh
export GODOT_BIN=/path/to/Godot_v4.6.3-stable_linux.x86_64
$GODOT_BIN --headless --path . --editor --import --quit
$GODOT_BIN --headless --path . --script res://addons/gut/gut_cmdln.gd -gexit -gdir=res://tests/integration -gselect=test_oxygen_exhaustion_probe
# Timing (one Godot job at a time). Accelerated, ~8 min (Sunlit) and ~13 min (Twilight) on this container:
$GODOT_BIN --headless --path . --fixed-fps 60 --script res://tests/fixtures/measure_oxygen_endurance.gd -- sunlit
$GODOT_BIN --headless --path . --fixed-fps 60 --script res://tests/fixtures/measure_oxygen_endurance.gd -- twilight
# Real time (~56 and ~83 min):
$GODOT_BIN --headless --path . --script res://tests/fixtures/measure_oxygen_endurance.gd -- sunlit
$GODOT_BIN --headless --path . --script res://tests/fixtures/measure_oxygen_endurance.gd -- twilight
```

## 8. Limitations

- Headless debug binary in a cloud container, no GPU. Real-time pacing on player hardware is not
  measured. Frame-rate effects are bounded by physics running at a fixed 60 Hz in both modes.
- "Normal travel" here means continuous full-deflection patrol on an open-water line. Oxygen drain
  does not depend on thrust in the code, and the measured time matches that, but battery figures do
  depend on the route.
- The Sunlit hull-death path, the development/prototype modes and the combat test box were not probed.
- No human playtest. Nothing here shows whether a player notices oxygen running out.
