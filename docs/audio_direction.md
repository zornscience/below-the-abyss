# BTA-041 underwater soundscape

## Identity

Quiet, close machinery against a broad, low ocean bed. Sparse received mechanical,
geological, biological and unknown contacts make the shelf feel inhabited; silence
between cues is intentional. The strong rising active ping contrasts with a short,
higher return. Curious biological chirps differ from the predator's lower paired
warning/pursuit tones. Escalation changes texture, not sudden excessive loudness.
These are original synthesized prototype sounds for review, **not professionally
mastered audio**. Headphone/speaker listening and human mix approval remain required.
No constant music or new narrative implication is introduced.

## Ownership and buses

`default_bus_layout.tres` defines Master ← Music / Ambience / Effects / UI.
`SoundscapeMixer` is owned by the shelf scene, with no autoload. `AudioCue` and
`SoundscapeProfile` Resources describe semantic cue IDs, streams, bus, gain,
minimum interval, per-cue/global voice limits, fade, duck and warning tuning.
Gameplay asks `mixer.request(cue_id) -> bool`; true means a valid presentation
request accepted by the voice budget, not proof of an audible speaker output.
Unknown/unavailable streams, muted categories, rate limits or saturation return
false, drop the cue and never interrupt gameplay or queue stale cues.

Five continuous players plus at most ten one-shot players exist per scene (hard
configuration cap sixteen one-shots). Completed voices are reused. Slot occupancy
uses the WAV duration so headless/native scheduling has the same bounded behavior.
Native Godot uses AudioStreamPlayer and its audio mixer. In headless CI no playback
handles are started: the same acceptance/routing/occupancy paths are tested, but
headless results are explicitly not audible-output evidence. This avoids Godot
4.6.3 Dummy playback handles lingering at headless engine shutdown.

`GameplayAudio` observes the existing domain APIs/signals, disconnects on exit,
and retains at most the passive receiver's bounded live contact snapshot. It does
not register with, publish to, clear, or alter AcousticBus. Audible sounds are
presentation; **AcousticEvent remains a gameplay contract**, with unchanged stable
IDs, deterministic delivery, duplicate suppression and bounded non-evicting history.
Audible playback, listening, mute and settings cannot attract creatures.

## Event mapping and visual equivalents

| Semantic cue/layer | Authoritative trigger | Route | Existing/added visual equivalent |
| --- | --- | --- | --- |
| ocean/current | scene atmosphere, sampled depth | Ambience | water/depth instruments; decorative only |
| engine | simulation enabled + existing thrust input | Effects | vessel motion/propeller |
| tension | nearby predator phase or exceeded safe depth | Ambience | WARNING/PURSUIT/SAFE and depth DANGER text |
| ping | SonarEmitter.pulse_emitted after accepted dispatch/cost | Effects | expanding wave and cooldown |
| echo | SonarEmitter.echo_revealed at wavefront arrival | Effects | legitimate target echo/HUD count |
| mechanical/geological/biological/unknown | newly received PassiveReceiver contact event ID | Effects | bearing, classification, approximate strength, expiry |
| scan_start / scan loop | scanner active-ID transition / real ongoing scan | Effects | SCANNING percentage; cancellation/out-of-range text |
| complete | ResearchRegistry.scan_completed | Effects | COMPLETE and research-log entry (one acknowledgement) |
| creak | actual pressure_damage_applied, rate limited | Effects | pressure damage / ASCEND |
| impact | actual collision_damage_applied | Effects | impact hull-loss feedback |
| damage | decreasing hull with a real damage source, rate limited | Effects | hull number/bar and damage instruments |
| hull/oxygen/battery | existing pool reaches configured low fraction | Effects | numeric pools, **! LOW / RETURN**, DEPLETED |
| dock/service | station UI opens / service_applied after success | UI | dock menu and before/after service result |
| biological | nearby harmless observer enters INVESTIGATE | Effects | HARMLESS / INVESTIGATE caption |
| unknown | entering existing predator HUD vicinity in quiet phase | Effects | optional encounter signage/quiet predator HUD |
| predator_alert/predator_pursue/retreat | nearby real predator phase changes | Effects | WARNING/PURSUIT/SAFE and retreat instructions |
| acknowledge | MissionService.mission_completed | UI | expedition/station objective status |
| ui | visible keyboard/controller/mouse focus changes | UI | focus outline |

Passive audio is intentionally centered, with qualitative classification only. It
adds no directional precision beyond the visible bearing, no source reveal or new
acoustic transmission. Short per-class intervals avoid each physics snapshot
replaying a contact. Duplicate event snapshots do not replay it. Simultaneous echo
returns may coalesce within a 0.15-second audio interval; every legitimate visual
reveal still occurs. No audio is emitted for failed energy/cooldown/duplicate pings.

Resource warning priority is hull → oxygen → battery, spaced two presentation
seconds apart and announced once per low episode; resource/predator alarms share a one-at-a-time voice
gate (no queued stale alarm). Refill above threshold + 5%
rearms. Muted/dropped warnings are consumed without deferred replay. The low
threshold defaults to 20% in the soundscape Resource and is shared with the HUD
badge. A warning never changes drains, depletion, damage or movement.

## Mixing and lifetime

Ocean/current volumes crossfade with depth from 0 to configured 350 m; near-surface
current recedes as the low bed increases. Machinery volume/pitch follows thrust;
scanner progress has a quiet continuous texture. Unsafe pressure adds slight
stress. Nearby ALERT introduces restrained tension; PURSUE strengthens it;
DISENGAGE/safety fades it out. Existing state clocks and physics remain authoritative.

An exponential fade (0.8 seconds default response) smooths depth, threat, engine
and menu changes independently of presentation frame rate. Important ping/return,
research and predator cues duck ambience to 65% for 1.2 seconds, with smooth return.
Music is a routed, adjustable reserved category; this region intentionally contains
no music stream. Menus/station reduce atmosphere to 35% and fade engine/scanner/
threat down. Disabling simulation stops one-shots; focus/docking/service cues can
then play in the menu. No gameplay clock advances to keep an audio loop alive.

Restart and Continue clear one-shots, rate-limit timers, passive presentation IDs,
warning latches and scan/threat presentation state. Continuous ocean phase and
preferences survive route restart; temporary state is reconstructed after Continue.
No discovery/research/mission completion or ping is manufactured during load.
Only the existing coordinator's transient-reset adapter changes; checkpoint schema
version 2 and all persistent game records stay unchanged.

## Preferences and accessibility

Pause/start → **Audio settings / independent volumes and mute**. Keyboard arrows/
Tab + Enter and controller D-pad/stick + A navigate; left/right adjusts sliders.
Escape/B/Start returns and discards unsaved changes. Save explicitly commits;
failed writes show a reason and restore stored state. Preview remains adjustable.
A scrolling focus-following panel supports 1280x800 and 800x600. The input/remapping
menu remains intact and distinct.

`SettingsStore` adds validated optional `audio` to its existing version-1 document:
Master, Music, Ambience, Effects, UI are finite numbers in [0,1], and muted is a
boolean. Legacy three-field input-only files remain valid and gain default audio
in memory. Unknown keys/invalid types/nonfinite/out-of-range values reject the
whole load without partial changes or overwriting the file. Defaults: 80/50/65/80/
70 percent. Explicit saves use the existing temporary-file/rename contract. This
additive extension does not alter expedition/save schemas. Input-menu reset/save
retains its existing whole-preferences reset contract, including audio defaults.

Every critical cue has text, numbers, bars or a visible state; stereo direction is
never required. Master mute silences all buses, zero category values mute that
category. Unmuting cannot replay suppressed cues. All game rules still operate
while muted. No flashing, camera shake or mandatory headphone dependence is added.

## Provenance and production

Run `python3 tools/synthesize_audio.py` to rebuild 26 original source WAVs with
standard-library fixed-seed synthesis. There are no recordings, downloaded samples,
commercial libraries, model-generated audio or new dependencies. Source recipes
are retained. `assets/audio-provenance.csv` records each file, seed/recipe, sample
rate, duration, loop and measured peak/RMS. Authorship: repository-authored BTA-041
procedural synthesis. **Project license decision remains pending**; this is source
provenance, not a declaration of a new license or professional mastering.

All sources are 22050 Hz mono signed 16-bit PCM WAV, about 1.8 MiB total. Five loops
are periodic at their sample boundary; WAV import mode 2 explicitly forces forward
looping, full sample range. No normalization, resampling, trim or lossy compression
is applied. Ocean/current are eight seconds; machinery/tension/scan two seconds;
cues 0.65–1.8 seconds. Fixed harmonics/seeded low-frequency partials keep boundaries
continuous and avoid runtime synthesis or large memory. The engine resamples its
mix normally. Individual assets remain peak-bounded; authored gains make ambience
quiet and sonar/warnings more prominent. These numerical levels are not LUFS or
perceptual/true-peak mastering certification.

## Performance and expansion

No real-time sample synthesis, audio analysis, world-physics audio queries, new
listeners or per-frame asset loads. Resources cache imported PCM; the five layers
continue at zero gain rather than allocating players on state changes. Per-frame
presentation work scans only ten voices, five layers, three resources and existing
bounded contacts. No unbounded event cache, loop/tween growth or reverb chain.

60 FPS on modest desktop hardware is a target, not proven by this software-rendered
VM. See [verification](testing/soundscape.md) for actual native frame observations,
tests, the mix example and limitations. Future reviewed sound replacements should
keep semantic IDs, tested event gating, visual equivalents, headroom, loop seams,
licenses and authored source recipes. Avoid mixing sound playback into AcousticBus,
sonar detection, AI state rules or checkpoint serialization.
