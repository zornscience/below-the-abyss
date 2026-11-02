class_name TwilightShelfData
extends RefCounted
## Authored chapter facts. Registries and the existing mission ledger own progress.
const MISSION: StringName = &"twilight-severed-line"
const ENCOUNTER: StringName = &"zone2-net-sentinel"
const RELEASE: StringName = &"zone2-sentinel-release"
const CAPTURE: StringName = &"zone2-sentinel-capture"
const LOST: StringName = &"zone2-sentinel-lost"
const NET: Vector2 = Vector2(37700,3190)
const RECORDS: Array[Dictionary] = [
	{"id":"twilight-severed-cable","title":"The severed line","at":Vector2(35950,1940),"type":"artificial","text":"Wick: The outer jacket is weathered. The exposed fibres are not. This was a clean separation, not a cable pulled apart by a falling rock.\n\nOkafor: Record both ends. Leave the line where it is; its position may tell us more than a sample."},
	{"id":"twilight-mara-log-one","title":"Mara / field log 01","at":Vector2(35800,2820),"type":"artificial","text":"Mara Voss / recovered survey instrument\n\nThe breaks repeat at the anchors. Not the weakest points: the anchors. I stopped transmitting and waited. Something moved beside the line, keeping pace with me. When I turned the lamp away, its lights remained.\n\nI am recording the gaps as well as the sound. Elias will understand why."},
	{"id":"twilight-whaler-marking","title":"Unclassified hull marking","at":Vector2(29100,3100),"type":"artificial","text":"A repeated arrangement has been scratched into the old whaler's timber, beneath later damage. This historic ship is not Lantern-1.\n\nWick: The arrangement repeats. That is a description, not a translation.\n\nOkafor: Keep the spacing and the surrounding wood in the record. We do not yet know what we are looking at."},
	{"id":"twilight-net-survey","title":"Living contact / drift net","at":NET,"type":"biological","text":"A luminous, long-bodied animal is held in a Tethys drift net. Its light contracts when the mesh tightens. The net's retrieval cradle still has power.\n\nOkafor: We can loosen it without taking the animal.\n\nCrane: A living specimen could answer questions a recording cannot. If you secure it, bring it back alive.\n\nApproach again and Interact to choose. No weapon is required."},
	{"id":"twilight-mara-log-two","title":"Mara / field log 02 (optional)","at":Vector2(28050,1860),"type":"artificial","text":"Mara Voss / detached logger\n\nThere are hulls here that should never have shared a century, let alone an anchorage. I found marks under the growth on one of them. I almost called them damage. Then I found the same spacing again.\n\nI have photographed them without cleaning the surface. Let the context survive the discovery."},
	{"id":"twilight-mara-log-three","title":"Mara / field log 03 (optional)","at":Vector2(38450,1720),"type":"artificial","text":"Mara Voss / isolated survey recorder\n\nI shut off the pulse and held position. The animal did not approach until the water was quiet again. I cannot tell whether it was curiosity or caution.\n\nPatience is an observation method too. I will try the quieter descent next.\n\n[The next descent is not charted by this damaged recorder.]"}
]
static func record(id: StringName) -> Dictionary:
	for item: Dictionary in RECORDS:
		if StringName(item.id)==id: return item.duplicate(true)
	return {}
static func knows(id: StringName) -> bool:
	return not record(id).is_empty()
static func discoveries() -> DiscoveryCatalog:
	var catalog: DiscoveryCatalog = ShelfChapterData.discoveries(true)
	catalog.survey_bounds = Rect2(0,0,39000,4000)
	for item: Dictionary in RECORDS:
		var point: PointOfInterest = PointOfInterest.new()
		point.stable_id = StringName(item.id+"-poi")
		point.sonar_target_id = StringName(item.id+"-echo")
		point.map_position = item.at
		point.display_name = item.title
		catalog.points.append(point)
	return catalog
static func research() -> ResearchCatalog:
	var catalog: ResearchCatalog = ShelfChapterData.research(true)
	for item: Dictionary in RECORDS:
		var definition: ScanDefinition = ScanDefinition.new()
		definition.stable_id = StringName(item.id)
		definition.required_poi_id = StringName(item.id+"-poi")
		definition.position = item.at
		definition.title = item.title
		definition.description = item.text
		definition.classification = item.type
		definition.requires_sonar = false
		definition.radius = 190
		definition.duration = 5.0
		definition.subject_texture = preload("res://assets/art/sunlit/plate_thumbnail.png")
		catalog.targets.append(definition)
	return catalog
static func missions() -> MissionCatalog:
	var catalog: MissionCatalog = SunlitShallowsData.missions()
	var mission: MissionDefinition = MissionDefinition.new()
	mission.stable_id = MISSION
	mission.title = "The Severed Line"
	mission.description = "Investigate the broken sensor line, recover Mara's first field log, record the old whaler's marking and resolve the trapped animal encounter. Return through the ascent tether for a Halcyon debrief. Optional loggers are not required."
	mission.acknowledgement_id = &"twilight-expedition-acknowledged"
	mission.acknowledgement = "Halcyon has archived the evidence. The Drowned Caves are the next investigation; that region is not playable."
	for id: StringName in [&"twilight-severed-cable",&"twilight-mara-log-one",&"twilight-whaler-marking",&"twilight-net-survey",ENCOUNTER,&"twilight-mara-log-one"]:
		var objective: MissionObjective = MissionObjective.new()
		var returned: bool = mission.objectives.size()==5
		objective.stable_id = &"twilight-return-to-halcyon" if returned else StringName("record-"+String(id))
		objective.kind = MissionObjective.Kind.RETURN_AFTER_SCAN if returned else (MissionObjective.Kind.STORY_CHOICE if id==ENCOUNTER else MissionObjective.Kind.SCAN)
		objective.target_id = id
		objective.description = "Return through the ascent tether for debrief." if returned else ("Resolve the trapped sentinel encounter." if id==ENCOUNTER else "Record "+record(id).title+".")
		mission.objectives.append(objective)
	catalog.missions.append(mission)
	return catalog
static func upgrade_records(records: Dictionary) -> Dictionary:
	var old: Dictionary = records
	if old.size()<6: old = SunlitShallowsData.upgrade_records(old)
	if not SunlitShallowsData.valid_records(old): return {}
	var result: Dictionary = missions().initial_records()
	for id: String in old: result[id] = old[id].duplicate(true)
	return result
static func ready(research: ResearchRegistry,story: StoryState) -> bool:
	for id: StringName in [&"twilight-severed-cable",&"twilight-mara-log-one",&"twilight-whaler-marking",&"twilight-net-survey"]:
		if not research.is_completed(id): return false
	return story.resolved(ENCOUNTER)
