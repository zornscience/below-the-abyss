# Local telemetry contract v1

Opt-in, local only. Recording is OFF each launch, including the exported playtest.
Normal source runs create no observer/UI/files unless `-- --playtest` is supplied.
The release export has the `playtest` feature and offers a consent page. Return is
focused by default; entering the page does not consent. Disable ends a session,
saves a summary and stops all collection. Existing reports remain until deleted.
There is no transmission, analytics SDK, raw input hook, or automatic sharing.

## Data and timing

`user://playtests/<random-128-bit-session-id>.json` is version 1, with a human-readable
`<id>-summary.txt`. Fields: schema_version, session_id, game_version, build_id,
status (active/disabled/quit), active_seconds, menu_seconds, completed,
completion_seconds, completion_active_seconds, counts, damage_total, events,
omitted_events. Version/build are authored/stamped identifiers; no machine identity.

Time comes from monotonic wall ticks, split by existing vessel simulation-enabled
state; paused menus count separately, including reading/settings. Time before
opt-in is not recorded. Suspend/unfocus follows the game's existing simulation
state and does not add a gameplay pause. Completion time is from this session's
opt-in to a new chapter conclusion, with active time also reported. A continued,
already-completed chapter does not fabricate another completion or full-chapter
time. The facilitator's independently measured departure-to-conclusion time is
therefore the primary cross-participant completion metric.

Events contain only kind, allowlisted authored detail, relative seconds and numeric
amount. See PlaytestReport.DETAILS for the complete allowlist. Counts cover accepted
active pings, started/completed scans, actual new discoveries, mission acceptance/
completion/claims, base returns, route stages, resource warning episodes/depletion,
actual hull loss by source and one chapter conclusion. Existing hull/oxygen depletion
is reported as a **failure threshold**, not an implemented death/respawn mechanic.
No new failure gameplay is added. Low means ≤20%; an already-low/depleted restored
resource is baseline, not a new warning. Pressure warning transitions remain the
existing damage API's thresholds. Damage counts are actual applied hull changes,
so pressure can count multiple physics applications; damage_total is more useful
than comparing tick counts across physics rates.

The existing route sampler now publishes observational base-entry/departure edges
from the same `in_base` sample; this does not change route stages or mission rules.
Repeated returns count after the original loop completes. Checkpoint restoration
synchronizes occupancy silently. Domain restore notifications reset observational
baselines; sonar/discovery/scan/mission identity suppression remains independent
of, and never modifies, campaign or acoustic history. Restart retains one recording
session and its totals; Continue adds a restore milestone without replaying progress.
A new application launch always requires new consent and creates a new random ID.

No names, emails, IPs, device identifiers, precise world/GPS positions, filesystem
paths, input streams, screenshots or unrelated logs are in a report. Error labels
are fixed categories (write_failed/checkpoint_blocked), never arbitrary engine logs
that could contain paths. The UI displays a local folder path for the player's
convenience; that path is not exported. General engine crashes are not captured by
an error hook. Unfinished active checkpoints and facilitator bug reports provide
interruption evidence; do not claim a known crash cause from an unfinished session.

## Bounds, writing and interruption

At most 512 timeline events are retained; further events increment omitted_events
while counters/timing remain valid. At most 2,048 runtime dedup identities are kept;
capacity stops recording instead of evicting old IDs. Maximum duration is 24 hours,
maximum JSON size 128 KiB, maximum 64 primary reports per local directory. Full
storage never deletes old sessions; move/delete selected reports voluntarily.

Opt-in, manual Export, Disable and orderly quit flush the current report. During
recording a lightweight checkpoint writes every 15 seconds. Writes validate the
entire allowlisted document, flush/close a sibling .tmp and rename; a validated
previous primary is kept as .bak. Corrupt primaries and stale .tmp files block
replacement and remain untouched. IO failures are shown in the report page;
collection stays bounded in memory and gameplay is unaffected. This is not a
power-loss durability guarantee. Report quota/permissions may prevent a disk write;
Recording ON then describes memory collection, not an assertion that export succeeded.

A force kill/crash cannot write a final event: the latest valid primary stays active,
which analysis labels unfinished/interrupted. Up to 15 seconds since the last
checkpoint and all memory-only data may be lost. A crash before the first successful
write leaves no report. A valid backup can be copied elsewhere for analysis, but
never submit both copies of the same session: duplicates are rejected. Loading a
telemetry report never resumes collection or modifies campaign data.

JSON and text may be inspected and voluntarily shared. To delete them remove only
the playtests subdirectory. Campaign saves/preferences remain separate. Do not
share the entire Godot user data directory. Invalid input analysis fails explicitly,
retains source files, and invents no missing values.
