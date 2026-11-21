class_name ExpeditionJourneyState
extends RefCounted
## Validated chapter location/commissioning, stored inside the expedition checkpoint.
const SHELF: String = "continental_shelf"
const TWILIGHT: String = "twilight_shelf"
const CAVES: String = "drowned_caves"
static func fresh() -> Dictionary:
	return {"phase":"sunlit","commissioned":false}
static func region(state: Dictionary) -> String:
	match state.phase:
		"twilight": return TWILIGHT
		"caves": return CAVES
	return SHELF
static func valid(value: Variant, progress: Dictionary) -> bool:
	if not value is Dictionary or value.size()!=2 or value.get("phase") not in ["sunlit","twilight","refit","prototype","caves"] or not value.get("commissioned") is bool: return false
	if value.phase in ["twilight","refit","caves"] and not value.commissioned: return false
	# The Drowned Caves are reachable only after the Twilight debrief is claimed.
	if value.phase=="caves":
		var twilight: Variant = progress.missions.get(String(TwilightShelfData.MISSION),{})
		if not twilight is Dictionary or twilight.get("state")!="claimed": return false
	if value.commissioned:
		var record: Variant = progress.missions.get(String(SunlitShallowsData.MISSION),{})
		if not record is Dictionary or record.get("state")!="claimed": return false
	return true
