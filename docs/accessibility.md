# Controller support and accessibility (BTA-043)

The Continental Shelf chapter supports keyboard-only and Godot-mapped controller
input, including every menu, confirmation, log, station page and checkpoint recovery.
No mouse precision or audible clue is required. This pass changes presentation and
input recovery; vessel physics, resource costs, story and campaign schemas are unchanged.

## Controls and navigation

| Action | Default keyboard | Godot controller layout |
| --- | --- | --- |
| Thrust | WASD or arrows | Left stick or D-pad |
| Interact / intentional scan / dock | E | A |
| Active sonar | F | X |
| Discovery map / research | M | Back / Select |
| Pause | Escape or P | Start / Menu |
| Choose menu control | Arrows, Tab / Shift+Tab | D-pad / stick, right / left shoulder |
| Confirm | Enter or Space | A |
| Back / cancel capture | Escape | B |

Inside a menu, fixed navigation/confirm takes priority over a remapped gameplay
Pause or Map binding. Escape/B always provide recovery. Start also backs out where
it is the current Pause binding; the guaranteed help advertises Escape/B.
Use the visible **Text ↑ / ↓** buttons in research, expedition and mission logs,
and **Notice text ↑ / ↓** on station notices. Long pages follow focused controls
and scroll without a mouse. Back returns through the current page before piloting;
modal confirmations cancel without accepting or discarding a checkpoint.

The existing `toggle_lights` mapping (L/Y) remains configurable but has no light-toggle
gameplay in this prototype. Passive listening is automatic and requires no input.
Station Interact retains priority inside the docking radius; outside it starts or
cancels scanning. Menus pause the existing simulation.

Pause → **Input settings** displays both device groups. Choose an action, choose
**Remap selected action**, then press a key, controller button or stick direction.
Escape/B cancels capture. A duplicate binding used by another gameplay action is
rejected without changing either action. Capturing replaces the chosen device
group's aliases for that action, retaining the other device group. Modifier chords
are unsupported; stick capture needs magnitude ≥0.6. Dead zone is configurable
from 0.1–0.9 (default 0.25). **Save** persists, **Reload** rereads, and Return discards
unsaved input edits. **Restore control defaults** resets bindings/dead zone only;
audio and accessibility preferences survive. Fixed menu controls cannot be removed.

HUD sonar/map/pause hints, the scan/dock hint, map close hint, pause movement hints
and observer instruction use current bindings. The last deliberate key/button or
stick motion ≥0.6 selects the prompt device; drift and release events do not.
Controller labels are generic Godot A/B/X/Start names, not platform-specific glyphs.
Loss of the last active controller releases held actions and pauses piloting.
Existing modals remain intact; capture is cancelled with keyboard recovery help.
Reconnect does not resume the vessel automatically. Keyboard remains usable.

## Readability and visual comfort

Pause → **Accessibility** previews changes immediately. **Save accessibility
preferences** keeps them; Return/Escape/B discards only accessibility edits since
the last successful Save. **Restore accessibility defaults only** is also a preview
until saved. It does not reset audio, bindings or progression.

- **Compact 90%, Standard 100%, Large 125%:** scales interface typography from its
  authored size with a 16px minimum. Large uses focus-following scroll containers
  for long menus. The HUD responds to window size rather than scaling a screenshot.
- At 800×600 Large, short captions retain maxima, current numeric resources, bars,
  SAFE/CAUTION/DANGER text, sonar readiness, contact bearings/classes/strength/expiry,
  mission progress and scan/dock state. Decorative vessel identity and redundant
  passive strength bars make room for instruments. Detailed objectives remain on
  the board/log. Navigation around the vessel stays visible.
- **Reduced flashing:** lowers the existing sonar ring's opacity and softens echo
  highlights. It preserves range, travel time, reveals and warning text. The
  life-support border (below) becomes a static border that thickens as time falls.
  By default that border pulses slowly: 0.5 pulses per second, rising to 1.5 per
  second over the last 20 seconds, with a hard cap of 2 per second. Its opacity
  moves between 60% and 100% and never reaches zero, so it is not a strobe. The
  pulse freezes whenever the simulation is paused.
- **Disable decorative particles:** hides motes and stops their update callback.
- **Reduced motion:** freezes decorative motes, propeller animation and background
  parallax. Actual vessel motion, camera following, sonar propagation and creature
  telegraphs remain functional. No camera shake exists, so no fictitious toggle
  is offered.
- **High contrast:** opaque dark instrument/menu panels, white text and light
  borders; focus also has a thicker outline, so it differs by shape as well as hue.
  Bar fills, icons, numeric values and state words retain their roles. The
  life-support border is a brighter red, 4 px thicker, with a white inner edge.

Resizing/settings trigger coalesced layout updates; there is no per-frame scene
walk. New sonar pulses inherit preferences without modifying acoustic dispatch.

## Playing without audio

Existing Audio settings retain Master/Music/Ambience/Effects/UI volumes, mute,
preview and explicit Save. The complete chapter has been run muted with Large UI
and all comfort options enabled. Critical cues have visible equivalents:

| Cue | Visible information |
| --- | --- |
| Active ping / echo | Expanding ring, temporary echo label, readiness/cost/cooldown/echo count |
| Passive contact | Bearing arrow/degrees, classification, approximate strength and expiry |
| Predator | WARNING/PURSUIT text, countdown and retreat direction |
| Low/depleted resources | Named numeric gauge, bar and LOW/DEPLETED state |
| Oxygen alarm at zero and at 10 s left (existing oxygen cue) | Red screen border and the text line `OXYGEN DEPLETED, LIFE SUPPORT 0:42`. The last 10 seconds read `LIFE SUPPORT CRITICAL` |
| Halcyon recovery | Fade to black and a text card that waits for Enter or A |
| Hull impact / pressure | Distinct IMPACT/PRESSURE hull-loss text, depth state and ascent instruction |
| Discovery / completed scan | Persistent map entry; scan progress/completion and research record |
| Mission / story | Objective counts, board state, rereadable text briefing and debrief |

No new audio-only information or gameplay events are introduced. Muting playback
does not mute the existing gameplay AcousticBus or change hearing/reveal rules.

## Persistence and compatibility

Preferences remain separate from campaign progress in `user://settings.json`,
version **1**. Optional `accessibility` has exactly these validated fields:

```json
{"ui_scale":"standard","reduced_flashing":false,"reduced_particles":false,"reduced_motion":false,"high_contrast":false}
```

Existing three-field input-only and four-field audio documents load unchanged on
disk; missing preference groups receive defaults in memory. Save writes the full
validated document to `.tmp`, flushes/closes, then replaces the primary through
the existing filesystem rename API. Unknown keys, invalid types/presets or invalid
bindings fail as a whole, retaining current in-memory preferences. The panel shows
invalid-load status. Explicit Save preserves rejected bytes as `.invalid` before
replacement; an existing `.invalid` is never overwritten. A second invalid primary
therefore blocks saving until the user backs up/moves those files externally.
There is no automatic deletion or silent repair of invalid data.

Settings version stays 1; expedition version stays 2. No campaign field, stable ID,
progression migration or acoustic-history contract changes. Continue, service,
upgrade installation and route restart retain saved accessibility. Campaign backup
recovery remains the existing explicit pause-menu operation, unrelated to settings
recovery. Windows replacement semantics and filesystem durability still need native
platform testing; rename is not a promise of survival through hardware failure.

## Manual verification

1. Run `godot --path .`. Set the window to 800×600, then 1280×800 and 1920×1080.
   Repeat with keyboard only and a real controller. Do not use the mouse.
2. Use Tab/shoulders and arrows/D-pad through pause, input/audio/accessibility,
   map/research, station services, notices/missions/upgrades and expedition log.
   Focus must remain visible after opening, backing out, scrolling and resizing.
   Cancel New Expedition once and verify the checkpoint remains unchanged.
3. Save Large, all comfort settings and high contrast. Save audio mute. Follow the
   [complete first-chapter route](testing/narrative_slice.md#manual-first-chapter):
   New Expedition confirmation → briefing → Begin survey → plate ping/scan → cave
   → Twin Spires ping → lower return passage → base dock → explicit debrief.
   Read the records with text-scroll buttons. No sound or mouse should be needed.
4. Open map/research during the route, pause a partial scan, then resume. Check
   discovery and scan completion stay distinct. Optional predator warnings,
   pressure warnings, impact damage and low/depleted gauges must be understandable
   with mute and reduced effects; retreat along the existing safe route.
5. Install the FREE sonar upgrade, explicitly Service all, pause and Save. Exit
   normally. Relaunch and Continue: records, upgrade, mute and Large remain, while
   no story conclusion event repeats. Exercise explicit checkpoint backup recovery
   on an isolated copied profile; confirm its reported result before Continue.
6. Remap sonar to an unused key/button; check the HUD hint and actual ping. Try a
   conflicting Interact binding and cancel capture. Save, relaunch and verify the
   custom binding. Restore control defaults and Save: audio/comfort settings remain.
7. Unplug the active controller while thrusting, while capturing a binding and in
   a confirmation. Verify thrust is released, capture cancelled, modal retained,
   keyboard recovery works and reconnect never automatically resumes play.
8. Toggle Standard/Compact/Large and contrast repeatedly. Watch all three passive
   contact slots, resource values, threat and simultaneous damage notices. No
   compounded scaling, clipped important text or lost focused control is acceptable.

## Limits and evidence

[Exact commands, automated results, native captures and timings](testing/accessibility.md).
All recorded controller events are synthetic `InputEventJoypadButton/Motion` through
real Godot input and focus, with no mouse or programmatic vessel movement. Physical
controllers, disconnect hardware/OS mapping, Windows/macOS, Steam Deck, screen-reader
support and human accessibility/usability studies remain unverified. This does not
claim platform certification, a measured target GPU frame rate, or that an automated
route establishes the narrative's unfamiliar-player duration target. Menu text is
English; arbitrary font/OS scaling, ultrawide/portrait and windows below 800×600
need further layout work. Comfort controls do not remove essential camera following
or the information-bearing expanding sonar wave.
