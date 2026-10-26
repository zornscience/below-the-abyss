# BTA-024: scientific scanning and completed research

Scientific scanning is separate from sonar discovery. The shelf composition owns
a ResearchRegistry, narrow ResearchStore and research-log page. The submarine
composes a reusable ScientificScanner. There is no singleton, dependency, mission,
reward, inventory, progression, scanner energy cost or general BTA-035 save system.
Existing acoustic dispatch, IDs, duplicate history, discovery files and navigation
geometry are unchanged.

## Authored target and completion contracts

ScanDefinition Resources define stable_id, required_poi_id, classification,
title/description, region-local position, scan radius in world units and duration
in simulation seconds. ResearchCatalog validates region, unique stable target IDs,
up to 128 entries, finite positive radius ≤1000, duration 0.25–60s, bounded text
and geological/biological/artificial categories. IDs reuse the authored lowercase
ASCII contract. Accepted runtime definitions are deeply copied. The shelf creates
non-colliding ScientificScanTarget placeholders from the authored catalog:

| Stable scientific target | Required sonar discovery | Position | Radius | Duration |
| --- | --- | --- | --- | --- |
| shelf-calibration-plate | shelf-navigation-marker | (760,480) | 240 units | 3 seconds |
| shelf-overlook-formation | shelf-overlook | (1710,440) | 240 units | 4 seconds |

240 world units correspond to 60m under the shelf's existing depth scale; the scan
radius is spatial distance, not a depth threshold. Placeholder observations are
explicitly labeled and make no final scientific/canonical content claim. No new
sonar receiver, acoustic source, collision obstacle or route requirement is added.
Undiscovered scan markers and names are hidden. Completed markers say RECORDED.

ScientificScanner.setup(research, discoveries, targets) validates matching region,
known target/required-POI IDs, unique live target bindings and bounded registration.
The owner supplies one active simulation clock. request_scan() selects the nearest
uncompleted, discovered target within its inclusive radius, using lexical target
ID to break equal-distance ties. It intentionally starts progress at zero; a second
activation cancels rather than automatically switching targets. There is no
hold-to-scan requirement, mouse precision or automatic start on proximity/sonar.

advance(delta) checks eligibility after movement, then accumulates simulation time.
Completion occurs at elapsed + 1e-9 ≥ duration. Invalid/nonfinite/negative time
changes no state. Leaving range or removing/exiting a target interrupts and resets
all partial progress; returning requires another intentional activation. Pause
freezes progress/feedback, rejects requests and resumes the same partial scan.
Restart cancels partial progress but preserves completed research. Timing is
step-consistent for eligible stationary subjects at 30/60/120 steps. Range is
sampled once after each physics movement, conservatively before granting that
step's progress; there is no continuous swept scanner or line-of-sight/occlusion.

No movement lock, thrust change, battery cost or acoustic emission is introduced.
The existing sonar action continues independently during scanning. Input is the
existing remappable interact (E/controller A defaults). Production shelf input
uses it only during piloting; modal menus consume their own input. Development
mode deliberately retains the existing E/A resource-test controls, so use normal
mode for scanning input. This avoids a settings-schema migration or duplicate
binding. No existing test/control behavior was removed.

ResearchRegistry.complete_scan(id) is the trusted scanner-adapter API. It inserts
the stable ID before emitting scan_completed(target_id), exactly once per known
uncompleted target, then records_changed. Repeated attempts return
ERR_ALREADY_EXISTS. The active scanner clears its pending state before callbacks.
Future mission consumers can subscribe to research.scan_completed; no mission
consumer is implemented. A save failure does not roll back completed runtime
research or re-emit the event. restore_completed validates the whole ID list before
merging and never emits scan_completed, so reload/recovery cannot replay it.
Completed_records returns sorted copies and never exposes uncompleted metadata.
Dependencies must outlive the scanner; target handles are weak and removable.

## Narrow research persistence

ResearchStore mirrors DiscoveryStore's failure/recovery policy in an independent
small store, leaving discovery's schema/API unchanged. Default path is
user://saves/research.json. An explicit GameRoot.research_path isolates profiles;
custom settings-path fixtures default to settings_path + .research.json rather
than writing the player's real file. Only completed stable IDs are serialized:

```json
{
  "format": "bta-research",
  "schema_version": 1,
  "region_id": "continental_shelf",
  "completed_target_ids": ["shelf-calibration-plate"]
}
```

Loading caps size at 16KiB and requires exactly these four fields, version 1,
matching format/region, correct types and ≤128 unique known target IDs. Validation
finishes before applying anything. Unknown versions fail with ERR_UNAVAILABLE;
malformed/oversized/unknown-ID/wrong-format data fails with ERR_INVALID_DATA.
Missing files are a clean first run. Invalid/incompatible originals block writes
and remain preserved; newly completed records stay in memory. The log reports
status and provides Retry save and explicit Recover backup controls.

Writing uses same-directory .tmp, checked write/flush, close and rename. Before
replacing a validated primary, its prior valid contents are atomically copied to
.bak; backup failure prevents primary replacement. Saving revalidates the primary
so external corruption is not silently overwritten. Temporary files are ignored
on load and cleaned on failure where possible. Retry revalidates a manually repaired
file and merges pending records. Recovery validates .bak first, preserves the
primary as .rejected (existing .rejected blocks replacement), merges backup with
pending records and writes. Bad/missing backups do not mutate records or originals.

This is single-writer local storage without interprocess locking or a hard power-
loss/fsync guarantee. No version migration is invented. Records store IDs and use
current authored observation text; historical text revisions are not serialized.
Research and discovery files are independent: a valid completed research record
remains readable if discovery data is missing/damaged, but does not grant a sonar
POI or reveal new scan targets. No partial progress, vessel state or route state
is saved. Restart never clears either permanent registry or file.

## Presentation and limitations

The existing route strip reports READY, OUT OF RANGE, SCANNING/numeric percentage,
PAUSED, CANCELLED, INTERRUPTED, COMPLETE and ALREADY RECORDED using text. Feedback
persists briefly in simulation time, avoiding one-frame messages. The map's Research
log button opens a separate read-only completed-record page. Text/category/state,
focusable entry buttons and shape markers avoid color-only information. Existing
fixed menu fallback bindings provide keyboard/controller navigation. B/Escape
returns from research to map, then to prior briefing/piloting; both pages pause
all existing simulation clocks. Neither page lists unknown targets or total-secret
counts. Current placeholder observations fit the 800×600 minimum; scroll containers
provide space for authored longer content, which needs its own accessibility review.

No line-of-sight query, sample collection, permanent creature entity, scientific
minigame, mission service, rewards or unlock logic. Native Windows/macOS, physical
controller, screen-reader and target-hardware performance tests remain manual.
Linux GUT, injected keyboard/controller and actual X11 rendering are the evidence.
See the testing guide for reproducible captures and acceptance steps.
