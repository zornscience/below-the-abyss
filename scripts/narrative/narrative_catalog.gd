class_name NarrativeCatalog
extends Resource

@export var entries: Array[NarrativeEntry] = []


func is_valid() -> bool:
	if entries.is_empty() or entries.size() > 32:
		return false
	var ids: Array[StringName] = []
	for entry: NarrativeEntry in entries:
		if entry == null or not entry.is_valid() or entry.stable_id in ids:
			return false
		ids.append(entry.stable_id)
	return true
