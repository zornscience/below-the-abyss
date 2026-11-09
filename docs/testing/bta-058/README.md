# BTA-058 — Twilight resource tension

Based on `ccr-faf5a894-y8zz7k` (`df06463`): main did not contain the approved
redesign brief. The brief's file still says draft; the user's issue instruction
explicitly approves it and overrides its broader hazard-cost proposal: vent and
other hull-damage behavior remain unchanged here.

## Behavior and acceptance mapping

1. `twilight_action_costs.tres` is the sole Twilight action tuning authority.
   ChapterJourney selects it only while `phase == twilight`, alongside the existing
   regional drain profile. Sunlit, refit and legacy prototype phases restore their
   captured original costs (4 ping / 2 torpedo). No shared authored profile is mutated.
2. Sonar's regional session override survives upgrade profile reapplication,
   including Continue. Cost changes preserve cooldown, pulses, range, event identity,
   supplies, ordnance, and talent effects. Torpedo selection changes only energy cost.
3. Travel drain and oxygen are unchanged. Thermal vents, collisions, depth damage,
   narrative, rewards, geometry, art and schema 10's twelve fields are unchanged.
4. Insufficient energy rejects ping and torpedo before emission/projectile/ammo/
   cooldown mutation. Neither partially consumes battery. Empty battery never gates
   thrust. The existing ascent-tether return services supplies and rearms normally.
5. Existing POWER `! LOW`/`! EMPTY`, sonar `LOW BATTERY · 5 power`, and torpedo
   `LOW BATTERY` text reuse current patterns. No permanent HUD element or new copy.
   Native captures: [1280×800](low-battery-1280x800.png),
   [800×600](low-battery-800x600.png). Captured at 1 battery with native Godot/Mesa
   llvmpipe through Xvfb; the renderer reports unsupported VSync, not gameplay errors.
6. ReleaseSmoke checks real cost selection after upgrade reapplication and actual
   ping/torpedo battery debits. `--break-resource-wiring` deliberately restores shallow
   costs after selection: the exported application must exit 1 with
   `RELEASE_RESOURCE_WIRING_FAIL`. CI checks that marker as well as failure status.

## Tuning hypotheses, not acceptance by players

**Human playtest results for this change do not exist. Every number below is a
hypothesis for the user's playtest.** A careful player refitting roughly once and a
reckless player being pushed to refit are design targets, not automated findings.

| Quantity | Twilight arithmetic | Sunlit/legacy action baseline |
| --- | --- | --- |
| Battery pool | 100 | unchanged |
| Ping | 5 battery; floor(100 / 5) = 20 pings without travel or shots | 4; 25 pings |
| Torpedo | 5 battery; floor(100 / 5) = 20 energy-funded shots; magazine still limits to 10 | 2; 50 energy-funded shots, magazine 10 |
| Idle drain | 0.003/s; 100 / 0.003 = 33,333.33s = 555.56min | unchanged |
| Full thrust drain | idle 0.003 + additional thrust 0.009 = 0.012/s; 8,333.33s = 138.89min | unchanged |
| Oxygen | 0.02/s; 100 / 0.02 = 5,000s = 83.33min | unchanged |

Thorough-expedition example: 30 minutes with thrust engaged 50% of the time uses
`1800 × (0.003 + 0.009 × 0.5) = 13.5` battery for travel. Three torpedoes use 15.
`floor((100 − 13.5 − 15) / 5) = 14` pings; 14 pings leave 1.5 battery.
At 45 minutes and the same duty cycle/three shots, travel uses 20.25 and 12 pings
leave 4.75. Six shots on the 30-minute budget leave room for 11 pings.
Repeated cooldown pings exhaust 100 battery in 20 accepted pings even without travel.
Oxygen still lasts about 83 minutes: an observation for user review, deliberately
not retuned. Actual route length, duty cycle and player hesitation need human measurement.

## Manual keyboard and gamepad playtest

1. Begin/Continue Sunlit; check a ping costs 4, a shot 2. Deploy to Twilight through
   the normal chapter handoff; check ping costs 5 and shot costs 5. Use F / controller
   X for sonar, Space / right trigger or right-stick click for torpedo, movement keys /
   left stick. Current remapped bindings take precedence.
2. Explore both loops with deliberate pings, a few optional torpedoes and existing
   vent exposure. Record accepted pings/shots, time, thrust estimate, remaining reserves
   and when you decide to return. Do not infer balance acceptance from automation.
3. At low power verify POWER warning, sonar cost and torpedo state in both supplied
   window sizes, muted and with comfort/high-contrast preferences. No cue needs sound
   or color alone. At less than 5 battery neither action should spend ammo or energy.
4. At zero battery, thrust back to the authored ascent tether, E / controller A to
   return/refit, then Resume expedition. Movement and tether interaction remain usable;
   services restore supplies/rearm. Passing the tether alone never refills.
5. Pause safely, save with depleted supplies, quit and Continue. Actual battery,
   oxygen, hull and ammunition must remain as saved; ping cost stays 5 and talent range
   stays fitted. Refit and resume; verify supplies replenish only at service.

## Scope and limitations

Changed files comprise the action-cost Resource/type, small cost APIs on the two
existing action components, ChapterJourney selection, ReleaseSmoke/Python smoke/CI,
new rule/integration tests and native capture fixture/evidence. No ShelfPrototype
refactor or persisted state. Selection performs constant work on chapter preparation;
there is no new per-frame loop, allocation or rendering work. No target-GPU 60 FPS,
Windows/macOS, human balance, or physical controller hardware claim is made.

See `validation.md` for exact commands and current outcomes.
