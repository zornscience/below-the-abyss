class_name SunlitShallowsData
extends RefCounted
## Canonical chapter records extend, rather than rename, the prototype ledger.
const MISSION: StringName = &"sunlit-shallows-expedition"
const BUOY: StringName = &"sunlit-lantern1-buoy-record"
const POI: StringName = &"sunlit-lantern1-buoy"
const ECHO: StringName = &"sunlit-lantern1-buoy-echo"
const BOUNDS: Rect2 = SunlitSurveyData.BOUNDS
const MESSAGE: String = "It isn't empty down there. Tell Elias the Choir is a voice."
static func missions() -> MissionCatalog:
	var catalog: MissionCatalog = ShelfChapterData.missions()
	catalog.missions.append(load("res://resources/story/sunlit_mission.tres") as MissionDefinition)
	return catalog
static func upgrade_records(records: Dictionary) -> Dictionary:
	var old: Dictionary = records
	if old.size()==2: old = ShelfChapterData.upgrade_missions(old)
	if not ShelfChapterData.missions().valid_records(old): return {}
	var result: Dictionary = missions().initial_records()
	for id: String in old: result[id] = old[id].duplicate(true)
	return result
static func valid_records(records: Dictionary) -> bool:
	return missions().valid_records(records)
