# Analysis procedure (study not yet run)

Keep consent/contact administration outside anonymous study files. Collect at least
five distinct unfamiliar participants. Repeated recordings are not participants.
Copy results_template.json to a private location outside Git and add one coded row
per actual participant; never populate the repository template with invented results.

Each row has these fields (shown as a **schema example, not a participant result**):

```json
{
  "participant_code": "P01",
  "unfamiliar": true,
  "completed": null,
  "completion_minutes": null,
  "ratings": {"enjoyment":null,"objective_clarity":null,"navigation":null,"sonar":null,"controls":null,"difficulty":null,"readability":null,"audio":null,"narrative":null},
  "want_continue": null,
  "navigation_difficulties": [],
  "issues": [],
  "share_session_id": false,
  "session_id": null
}
```

Completed is true/false/null (unknown); time is measured completion minutes only,
otherwise null. Ratings are 1–5 or null. Interest is Yes/Maybe/No/null. Anonymous
codes use uppercase A–Z, 0–9 and hyphen, ≤16 characters; do not derive them from
names or other identifiers. Navigation/issue tags are listed in the worksheet.
Do not put free-text comments or personal details in machine-readable rows. Keep
redacted nuanced observations/forms separately; code themes consistently after
review. Mark assistance in the observation worksheet and evaluate it alongside the
aggregate result (the script does not infer unaided completion).

For optional explicit linkage set share_session_id=true and the voluntarily shared
32-hex report ID. Without permission session_id must remain null. No automatic
matching by timing, machine data or folder names occurs.

```sh
python3 tools/analyze_playtests.py --feedback /private/study/feedback.json --reports /private/study/shared-reports --output /private/study/analysis-new.json
# Feedback-only / empty template demonstration:
python3 tools/analyze_playtests.py --feedback docs/playtesting/results_template.json --output /tmp/bta-empty-analysis.json
# Reproducible synthetic-fixture tests (not human evidence):
python3 -m unittest discover -s tests/python -v
```

The script uses only Python standard libraries, reads primary *.json reports,
rejects duplicates/malformed/oversized input, and creates a new output (never
replaces an existing result). Backups/txt are ignored. Unknown keys, raw input,
arbitrary telemetry detail/free text, invalid ratings/nonfinite values and
unconsented links fail. Missing/unanswered values remain null.

Output separates participant outcomes from optional session aggregates. Completion
percentage uses known outcomes and explicitly reports its denominator/unknown count;
median uses measured completed durations only. Interest percentage is Yes among
answered Yes/Maybe/No responses, with its denominator. Sonar distribution is across
shared sessions, not inferred people. Navigation and issue frequency count people,
with critical→major→minor review suggestions ranked by severity then frequency.
Recommendations are prompts for human investigation, not proof of a cause or an
automatic balance/narrative change. Unfinished sessions remain incomplete evidence.

Evaluate interventions, missing data, selection bias and the redacted comments after
reviewing the aggregate. Record critical blockers, common confusion, completion and
interest outcomes and a justified follow-up priority list. **At least five unfamiliar
human sessions plus evaluated feedback remain required.** The script never certifies
that gate, even if a synthetic input contains five rows.
