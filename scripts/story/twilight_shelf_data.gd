class_name TwilightShelfData
extends RefCounted
## Authored chapter facts. Registries and the existing mission ledger own progress.
const MISSION: StringName = &"twilight-severed-line"
const ENCOUNTER: StringName = &"zone2-net-sentinel"
const RELEASE: StringName = &"zone2-sentinel-release"
const CAPTURE: StringName = &"zone2-sentinel-capture"
const LOST: StringName = &"zone2-sentinel-lost"
const NET: Vector2 = Vector2(37700,3190)
const OPTIONAL_SURVEY: Array[StringName] = [&"twilight-line-anchor",&"twilight-cargo-timber",&"twilight-ballast-pocket",&"twilight-thermal-crust"]
const DEPTH_SURVEY: Array[StringName] = [&"twilight-depth-margin",&"twilight-depth-layers",&"twilight-upper-grains",&"twilight-cable-crust",&"twilight-wreck-silt",&"twilight-deep-crust",&"twilight-deep-sediment"]
const RECORDS: Array[Dictionary] = [
	{"id":"twilight-upper-grains","title":"Shelf grains / optional study","at":Vector2(30000,1400),"type":"geological","text":"Mixed coarse and fine grains on the upper shelf. An optional sediment comparison."},
	{"id":"twilight-cable-crust","title":"Cable margin crust / optional study","at":Vector2(35800,2500),"type":"geological","text":"Mineral crust beside the suspended cable. Record the surface without disturbing the line."},
	{"id":"twilight-wreck-silt","title":"Wreck margin silt / optional study","at":Vector2(29000,2600),"type":"geological","text":"Fine silt at the margin of the old wreck passage. Optional observation; no sample is required."},
	{"id":"twilight-depth-margin","title":"Pressure margin / optional study","at":Vector2(30000,3100),"type":"geological","text":"A mineral band borders the deeper basin. The existing upper shelf remains accessible without descending."},
	{"id":"twilight-depth-layers","title":"Sediment layers / optional study","at":Vector2(34100,3100),"type":"geological","text":"Layered sediment overlooks the deep basin. No expedition evidence requires this descent."},
	{"id":"twilight-deep-crust","title":"Deep crust / optional study","at":Vector2(31200,4480),"type":"geological","text":"A dark mineral crust on the basin floor. Optional observation; the upper shelf route remains open."},
	{"id":"twilight-deep-sediment","title":"Deep sediment / optional study","at":Vector2(33000,4480),"type":"geological","text":"Fine sediment has settled beneath the shelf. Record it without collecting a sample."},
	{"id":"twilight-severed-cable","title":"The severed line","at":Vector2(35950,1940),"type":"artificial","text":"Wick: The outer jacket is weathered. The exposed fibres are not. This was a clean separation, not a cable pulled apart by a falling rock.\n\nOkafor: Record both ends. Leave the line where it is; its position may tell us more than a sample."},
	{"id":"twilight-mara-log-one","title":"Mara / field log 01","at":Vector2(35800,2820),"type":"artificial","text":"Mara Voss / recovered survey instrument\n\nThe breaks repeat at the anchors. Not the weakest points: the anchors. I stopped transmitting and waited. Something moved beside the line, keeping pace with me. When I turned the lamp away, its lights remained.\n\nI am recording the gaps as well as the sound. Elias will understand why."},
	{"id":"twilight-whaler-marking","title":"Unclassified hull marking","at":Vector2(29100,3100),"type":"artificial","text":"A repeated arrangement has been scratched into the old whaler's timber, beneath later damage. This historic ship is not Lantern-1.\n\nWick: The arrangement repeats. That is a description, not a translation.\n\nOkafor: Keep the spacing and the surrounding wood in the record. We do not yet know what we are looking at."},
	{"id":"twilight-net-survey","title":"Living contact / drift net","at":NET,"type":"biological","text":"A luminous, long-bodied animal is held in a Tethys drift net. Its light contracts when the mesh tightens. The net's retrieval cradle still has power.\n\nOkafor: We can loosen it without taking the animal.\n\nCrane: A living specimen could answer questions a recording cannot. If you secure it, bring it back alive.\n\nApproach again and Interact to choose. No weapon is required."},
	{"id":"twilight-mara-log-two","title":"Mara / field log 02 (optional)","at":Vector2(28050,1860),"type":"artificial","text":"Mara Voss / detached logger\n\nThere are hulls here that should never have shared a century, let alone an anchorage. I found marks under the growth on one of them. I almost called them damage. Then I found the same spacing again.\n\nI have photographed them without cleaning the surface. Let the context survive the discovery."},
	{"id":"twilight-mara-log-three","title":"Mara / field log 03 (optional)","at":Vector2(38450,1720),"type":"artificial","text":"Mara Voss / isolated survey recorder\n\nI shut off the pulse and held position. The animal did not approach until the water was quiet again. I cannot tell whether it was curiosity or caution.\n\nPatience is an observation method too. I will try the quieter descent next.\n\n[The next descent is not charted by this damaged recorder.]"},
	{"id":"twilight-line-anchor","title":"Cable anchor / optional observation","at":Vector2(34900,1440),"type":"artificial","text":"The cable jacket is intact at this anchor. A short slack span drops beyond the eastern ledge.\n\nWick: The anchor has held. Look at the separation farther along the line before drawing a conclusion. The western gallery can be investigated independently."},
	{"id":"twilight-cargo-timber","title":"Timber pocket / optional observation","at":Vector2(31100,2300),"type":"artificial","text":"Waterlogged cargo timber rests in a blind recess. Its grain and fastenings resemble the western historic wreck. Scratches cross older wear; their original context is lost.\n\nOkafor: A useful comparison. Preserve the damage and grain alongside the marks. This pocket ends here; the cross-gallery remains open behind you."},
	{"id":"twilight-ballast-pocket","title":"Ballast pocket / optional observation","at":Vector2(34100,2300),"type":"geological","text":"Rounded ballast lies mixed with fresh mineral crust in the eastern blind pocket. There is no recorder beneath it.\n\nWick: No excavation is needed. Both chimneys connect to the open shelf; the lower passage returns toward the broken cable."},
	{"id":"twilight-thermal-crust","title":"Thermal margin / optional observation","at":Vector2(36500,3100),"type":"geological","text":"Pale mineral crust and tube worms occupy the cooler margin beside the eastern vent. The plume itself remains hazardous.\n\nOkafor: Observe from this side. We do not need to cross the eruption to record where life returns to the rock."}
]
static func all_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = RECORDS.duplicate(true)
	result.append_array(TwilightTunnelCatalog.records())
	return result
static func record(id: StringName) -> Dictionary:
	for item: Dictionary in all_records():
		if StringName(item.id)==id: return item.duplicate(true)
	return {}
static func knows(id: StringName) -> bool:
	return not record(id).is_empty()
static func discoveries() -> DiscoveryCatalog:
	var catalog: DiscoveryCatalog = ShelfChapterData.discoveries(true)
	catalog.survey_bounds = Rect2(0,0,39000,5200)
	for item: Dictionary in all_records():
		var point: PointOfInterest = PointOfInterest.new()
		point.stable_id = StringName(item.id+"-poi")
		point.sonar_target_id = StringName(item.id+"-echo")
		point.map_position = item.at
		point.display_name = item.title
		catalog.points.append(point)
	return catalog
static func research() -> ResearchCatalog:
	var catalog: ResearchCatalog = ShelfChapterData.research(true)
	for item: Dictionary in all_records():
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
		definition.subject_texture = subject_texture(StringName(item.id))
		catalog.targets.append(definition)
	return catalog
static func subject_texture(id: StringName) -> Texture2D:
	if id==&"twilight-net-survey": return preload("res://assets/art/twilight/sentinel.png")
	var texture: AtlasTexture = AtlasTexture.new()
	texture.atlas = preload("res://assets/art/twilight/research_atlas.png")
	# Authored regions measured against the original master, not an assumed grid.
	texture.region = Rect2(0,0,755,724) if id in [&"twilight-whaler-marking",&"twilight-cargo-timber"] else (Rect2(1550,0,622,724) if (id in [&"twilight-ballast-pocket",&"twilight-thermal-crust"] or String(id) in TwilightTunnelCatalog.payoff_ids()) else Rect2(760,0,785,724))
	texture.filter_clip = true
	return texture

static func missions() -> MissionCatalog:
	var catalog: MissionCatalog = SunlitShallowsData.missions()
	var mission: MissionDefinition = MissionDefinition.new()
	mission.stable_id = MISSION
	mission.title = "The Severed Line"
	mission.description = "Investigate the broken sensor line, recover Mara's first field log, record the old whaler's marking and resolve the trapped animal encounter. Return through the ascent tether for a Halcyon debrief. Optional observations and loggers are not required."
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
