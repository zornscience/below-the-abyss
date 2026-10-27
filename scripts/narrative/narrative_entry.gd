class_name NarrativeEntry
extends Resource
## Authored text, unlocked from existing persistent domain evidence only.

enum Evidence { BRIEFING, ACCEPTED, MARKER, SCAN, SPIRES, RETURNED, CONCLUDED, GEOLOGY, HYDROPHONE, VENT, WRECK }
@export var stable_id: StringName
@export var title: String
@export_multiline var text: String
@export var evidence: Evidence = Evidence.BRIEFING


func is_valid() -> bool:
	return PointOfInterest.valid_id(stable_id) and not title.strip_edges().is_empty() \
		and title.length() <= 80 and not text.strip_edges().is_empty() and text.length() <= 1600 \
		and evidence in Evidence.values()
