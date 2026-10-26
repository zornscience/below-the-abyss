class_name ResearchCatalog
extends Resource

@export var region_id: StringName = &"continental_shelf"
@export var targets: Array[ScanDefinition] = []


func is_valid() -> bool:
	if not PointOfInterest.valid_id(region_id) or targets.is_empty() or targets.size() > 128:
		return false
	var ids: Dictionary[StringName, bool] = {}
	for target: ScanDefinition in targets:
		if target == null or not target.is_valid() or ids.has(target.stable_id):
			return false
		ids[target.stable_id] = true
	return true
