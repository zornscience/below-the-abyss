# Below the Abyss — Playtester guide

Thank you for trying an unfinished scientific submarine exploration chapter. Explore
independently; there is no required speed. The briefing inside the game explains
your objective. You may stop whenever you wish, and feedback is welcome even if
you do not finish. Please do not read developer walkthroughs before your session.

## Install and start

Unzip the Linux package into a folder you can write to. Open a terminal there:

```sh
chmod +x below-the-abyss.x86_64
./below-the-abyss.x86_64
```

The editor, Python and an internet connection are not required. Keep the included
instructions and manifest. This build targets Linux x86_64 desktop with a working
OpenGL 3.3-compatible display/driver. Verification used Debian 13, native X11 and
Mesa llvmpipe software rendering; this is a tested environment, not a measured
minimum gaming-PC specification. Windows, macOS, physical controllers and Steam Deck
have not been tested. If it does not launch, send the facilitator the build ID from
manifest.json and the non-personal error description. Do not change permissions or
install untrusted system software on someone else's computer.

## Controls

| Action | Keyboard | Generic Godot controller names |
| --- | --- | --- |
| Move | WASD / arrows | Left stick / D-pad |
| Interact / dock / scan or cancel scan | E | A |
| Active sonar | F | X |
| Map / research | M | Back / Select |
| Pause | Escape / P | Start |
| Menu navigation | Arrows, Tab / Shift+Tab | D-pad / stick, shoulders |
| Select / back | Enter or Space / Escape | A / B |

Passive listening is automatic. Controls can be remapped in Input settings; Save
keeps edits, Return discards unsaved edits. Fixed menu controls remain available
for recovery. Read long records using Text ↑/↓ buttons. Unplugging the active
controller should pause movement; keyboard recovery remains available.

## Comfort, saves and leaving

Pause → Accessibility offers Compact/Standard/Large text, contrast and reduced
visual effects. Audio settings offer mute and separate mix levels. Save each page
to keep preferences. All essential information is also visible with sound muted.
You can change these settings before starting and at any point later.

Pause and choose Save expedition in safe terrain, then wait for the success message.
Station interactions also checkpoint. Relaunch and choose Continue saved expedition.
There is no automatic quit save: save progress explicitly before exiting. New
Expedition asks for confirmation and keeps permanent discoveries, research and
installed upgrades; it is not a fresh participant profile. If recovery is offered,
ask the facilitator before replacing a checkpoint with its backup.

Playtest / local reports → Finish session and quit game ends the application.
The desktop window close button also works. Recording is optional and never saves
campaign progress for you.

## Optional local reports

Recording starts OFF at every launch. In Playtest / local reports, read the disclosure
and choose I agree / Start local recording only if you want to. It records a random
session ID, build version, gameplay/menu durations and named gameplay-event counts.
It does not record names, emails, input streams, device IDs or precise location,
and never transmits reports. You may play without recording.

Disable recording / Save summary stops collection immediately and writes a JSON
report plus readable text. Export current JSON + readable summary can be used while
recording or afterwards. The screen displays the folder; Open local report folder
opens it where supported. Sharing is your choice: send only the selected JSON or
summary voluntarily to the facilitator. Do not send your full Godot data directory,
save files, desktop screenshots, or unrelated logs. Read LOCAL_REPORTS.md for exact
limits and interruption behavior. You can delete local reports at any time.

## Feedback and problems

Complete FEEDBACK.md after playing (about five minutes). Please describe where you
were confused and what you expected, including anything you liked. No name/email
is requested. Include a session ID only if you explicitly want your feedback linked
to the optional local report. No recording or report is required to provide feedback.

For a bug, note the build ID, what you were trying, what happened, whether it repeats,
and whether you could continue. An approximate gameplay landmark is useful; do not
include personal information or your computer's username. Tell the facilitator
immediately if the game crashes, traps you, or cannot save. A stopped or incomplete
session is useful evidence and is never a reason to invent an ending or a duration.

## Uninstall / remove local data

Delete the extracted package folder to uninstall. Godot keeps preferences, saves
and optional reports separately, normally under
`~/.local/share/godot/app_userdata/Below the Abyss/` on Linux (or under your configured
XDG_DATA_HOME). `playtests/` contains optional reports only. Delete that subfolder to
remove telemetry; deleting the whole game data folder also deletes preferences and
permanent progress. Ask the facilitator if this is a shared or existing player profile.
