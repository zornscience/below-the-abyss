# BTA-042 / The Quiet Run

## Overview and roles

NERIS leaves Shelf Base to recover a scientific account of the missing expedition's
last shelf survey. A damaged field-reference face, a deliberately acquired scan,
the Twin Spires baseline and a safe return form one coherent chapter. The ending
recognizes what the player accomplished and leaves a specific next question.

NERIS is the player's scientific submarine. Shelf Base speaks as an unnamed station
watch; the missing survey crew remains unnamed and absent. No new organization,
biography, antagonist, fate for the crew or explanation of the anomaly is established.
The voice is restrained: observe, retain uncertainty, return safely. All original
prose is repository-authored for review; project licensing remains undecided. No
third-party text, recordings, fonts, generated images or new audio assets are used.

## Worldbuilding constraints

Keep the GDD premise: a missing scientific expedition and unexplained acoustic
activity, investigated with sonar and scientific observation. The recovered text
reports the *earlier crew's observations*; it does not change the live simulation,
make a sonar return arrive early, prove time reversal, identify a creature species,
or reveal the central mystery. The damaged mount is not evidence of violence.
The optional predator remains an avoidable wildlife encounter, not a plot gate.

The environmental additions are original nonsolid line geometry on existing
landmarks: the reference face/broken mounting ear at `(760,480)` and the empty
retaining strap at `(3560,650)`. No wall, collision polygon, waypoint, sonar receiver,
scan radius/duration, resource drain or creature behavior changes. The existing
calibration plate's authored research description now carries the field strip;
its stable ID, title, detection prerequisites and scientific scanner API stay intact.

## Progression and player guidance

The existing start/pause page immediately presents the concise station briefing:
NERIS, Shelf Base, the missing survey, unexplained sequence, plate scan, Twin Spires
and safe return. It is four short lines, with **Expedition log / briefing** beside
Audio settings for expansion/rereading. Begin/Resume can skip expanded reading.
There is no cinematic, forced dwell, new key binding or compulsory modal.

In the log, **Begin survey / count earlier evidence** intentionally accepts the
existing `shelf-expedition` and `shelf-calibration-study` missions. The original
mission board remains usable; either interface delegates to the same MissionService.
The science study remains optional for the earlier route-only mission, but its
one always-available plate scan is explicitly required for this narrative chapter.
No hidden optional collectible or predator/geology encounter gates the chapter.

| Chapter | Required evidence/action | Guidance |
| --- | --- | --- |
| Departure | Read/skip briefing; intentionally accept the two board objectives | Plate east of base: Sonar → approach → Interact to scan |
| Unusual readings | Existing active-wavefront discovery of the reference marker | Damaged mount and field strip become described in log |
| Expedition evidence | Real completion of the existing 3-second plate scan | Recovered record; follow cave to identify Twin Spires with sonar |
| Return | Existing main mission's `return-to-base` objective | Follow lower BASE arrows; dock at Shelf Base |
| Debrief/hook | Both existing mission acknowledgements explicitly claimed at station | CHAPTER CONCLUDED; records remain rereadable |

The in-expedition route-guidance line now shows the current narrative instruction;
the existing scan, mission-status, depth/resource instruments and LOOP COMPLETE
prefix remain. Guidance for a completed route still directs a missing scan or late
acceptance correctly. Station access remains remappable Interact within its radius,
with station priority over scanning; being near base never refills resources.

## Stable narrative IDs and evidence contract

`resources/narrative/shelf_chapter.tres` contains validated `NarrativeEntry` Resources
with unique stable IDs, bounded title/text and an evidence enum. Future entries
are excluded from the UI entirely until eligible, rather than shown as spoiler
placeholders. No undiscovered text is copied into labels or entry buttons.

| Narrative ID | Persistent authority |
| --- | --- |
| `shelf-station-briefing` | Always available authored station communication |
| `shelf-survey-orders` | Existing main mission is accepted/completed/claimed |
| `shelf-damaged-marker` | DiscoveryRegistry: `shelf-navigation-marker` |
| `shelf-expedition-field-record` | ResearchRegistry: `shelf-calibration-plate` scan complete |
| `shelf-spires-observation` | DiscoveryRegistry: `shelf-twin-spires` |
| `shelf-safe-return` | Existing main mission retains `return-to-base` objective |
| `shelf-concluding-debrief` | Both missions claimed, with actual plate research and spire discovery present |
| `shelf-optional-strata-note` | Optional `shelf-overlook-formation` research complete |

NarrativeService is a projection and intent adapter, not another mission ledger.
`begin_survey()` delegates existing acceptance/reconciliation; `debrief(station)`
delegates existing docking/pause-guarded station claims. It grants no new rewards,
resources, inventory, currency, upgrades or mission objectives. A failure after one
claim keeps that durable claim and allows retry of the remaining one; neither
acknowledgement nor the concluding event can be granted twice.

`record_unlocked(stable_id)` is a bounded presentation notification for genuine
new domain evidence. `chapter_concluded` follows the first real final acknowledgement.
Initial setup and restore/recovery rebuild silently. The existing MissionService
adds only `records_restored` to distinguish silent restore from actual claims;
normal mission semantics, IDs, objective definitions and return detection stay.
Generic registry refreshes update the log without inventing domain events. The
existing soundscape supplies the scan/research cues and one debrief acknowledgement;
no acoustic event is emitted by narrative or audio presentation.

## Save/load and ordinary objective-order variations

There is **no new save file, field or schema migration**. The chapter reconstructs
from the existing canonical expedition schema v2 (v1 checkpoint migration remains),
or the existing narrow domain stores in standalone component fixtures. Permanent
narrative flags are the existing accepted/completed/claimed states and discoveries/
scans. Read/unread markers are not stored: unlocked entries remain available whether
read, skipped or reopened. This avoids a competing or stale story save.

- Discoveries and completed scans earned before acceptance count immediately.
- A currently COMPLETE route counts on late acceptance, following MissionService's
  existing policy. After acceptance, a recorded return objective is permanent.
- Restart Test Route/New Expedition retain accepted missions, completed objectives,
  claims, discoveries and scans. A route completed *without ever registering the
  mission* is still temporary telemetry; explicitly restarting it before acceptance
  requires another short loop. Previously scanned/discovered evidence remains.
- Returning before scanning works: the plate stays accessible east of base. Scan
  later, dock and debrief. A prior main acknowledgement plus later science claim,
  or prior science acknowledgement plus later main claim, both conclude correctly.
- Existing fully acknowledged profiles reconstruct the conclusion; they do not
  replay story events, research completion, mission rewards or acoustic pings.
- Corrupt/incompatible checkpoints remain preserved. The briefing can be read while
  progress actions stay blocked by the existing coordinator guard. Use its recovery
  UI. Failed writes do not pretend that the whole debrief was saved.

The log has no timers. Pause freezes all existing simulation; partial scans retain
their existing pause/cancel rules. Native 800x600 and 1280x800 Control layouts use
20px detail text, focus outlines, focus-following entry list, and explicit Text ↑/↓
buttons for keyboard/controller scrolling. Escape/B returns to the prior paused
station/pause page; returning from the station log does not undock automatically.
All essential information is readable when sound is muted.

## Ending (spoilers)

<details><summary>Concluding debrief and future hook</summary>

The player brings back a field strip reporting that the expedition's receiver kept
marking an interval after its transmitter was isolated. The missing instrument at
Twin Spires supports a location, not a theory of the signal.

Shelf Base compares the recovered note with the departure manifest. The portable
receiver was checked out after the planned final survey; its removal appears
deliberate. The strip's last instruction is: **“If the sequence stops, keep
recording.”** They were preparing to listen to the silence.

The crew's disappearance and the acoustic source remain unresolved. The next
investigation points below the shelf; this milestone adds no region, travel gate,
new mission chain, voice performance or playable future chapter. The current
chapter explicitly concludes with NERIS safely home and the log available to review.

</details>

## Scope, duration and verification

The content forms a complete short prototype chapter on the existing route. The
20–40 minute unfamiliar-player target is **not established**. The actual native
automated completion took **51.391 seconds wall time**, including **44.883 seconds
on the active-route timer**; automation does not simulate human reading, hesitation
or exploration. No artificial waits, enlarged region or balance changes pad time.
Human pacing/clarity testing is needed before claiming the target or narrative
quality gate. See [exact commands, native evidence and manual walkthrough](testing/narrative_slice.md).
