class_name ShelfChapterData
extends RefCounted
## Authored outer-shelf extension. Stable IDs remain independent of scene instances.
const BOUNDS: Rect2i = Rect2i(0, 0, 24000, 1800)
const OUTER: StringName = &"shelf-outer-search"
const WRECK: StringName = &"shelf-wreck-recovery"
const WILDLIFE: StringName = &"shelf-wildlife-study"
const POINTS: Array[Dictionary] = [
	{"id":"outer-hydrophone", "echo":"outer-hydrophone-echo", "title":"Abandoned hydrophone", "at":Vector2(6500,800)},
	{"id":"outer-vent-garden", "echo":"outer-vent-echo", "title":"Mineral chimney garden", "at":Vector2(12800,1120)},
	{"id":"lost-expedition-wreck", "echo":"expedition-wreck-echo", "title":"Lost expedition submarine", "at":Vector2(21600,1390)},
	{"id":"observer-habitat", "echo":"observer-habitat-echo", "title":"Resonant grazer habitat", "at":Vector2(1530,360)}]
const SCIENCE: Array[Dictionary] = [
	{"id":"outer-hydrophone-record", "poi":"outer-hydrophone", "at":Vector2(6500,800), "type":"artificial", "title":"Hydrophone memory", "seconds":5.0,
	"text":"The hydrophone retains the expedition's final heading: along the outer shelf, through the mineral chimneys, into water around 350 metres deep. The crew shut down their transmitter, but continued listening. The quiet after each transmission was the clue they chose to follow."},
	{"id":"outer-vent-study", "poi":"outer-vent-garden", "at":Vector2(12800,1120), "type":"geological", "title":"Chimney field survey", "seconds":6.0,
	"text":"Mineral deposits grow around warm fissures. Cable insulation matching the expedition's receiver lead is caught in the eastern chimneys. A damaged pressure housing lies farther along the deep shelf. These are material traces, not proof that a creature attacked the vessel."},
	{"id":"lost-expedition-blackbox", "poi":"lost-expedition-wreck", "at":Vector2(21600,1390), "type":"artificial", "title":"Expedition flight recorder", "seconds":8.0,
	"text":"The missing survey submarine rests on the sea floor with its observation bow fractured and ballast released. Its recorder documents an emergency grounding after a power failure. The portable acoustic receiver was removed before the grounding. There is no crew aboard. The final readable instruction is: If the sequence stops, keep recording."},
	{"id":"observer-ecology", "poi":"observer-habitat", "at":Vector2(1510,420), "type":"biological", "title":"Resonant grazer field notes", "seconds":5.0,
	"text":"This harmless grazer turns toward strong nearby sounds and then returns to its feeding circuit. Listening passively does not disturb it. Scanning it while quiet reveals a living acoustic landmark; harming it is unnecessary for the expedition and earns no reward."}]
static var ROCKS: Array[Dictionary] = [
	{"id":"outer-canopy", "points":PackedVector2Array([Vector2(3980,0),Vector2(24000,0),Vector2(24000,260),Vector2(22000,330),Vector2(19500,230),Vector2(16000,300),Vector2(14000,240),Vector2(11000,340),Vector2(8000,220),Vector2(5000,330),Vector2(3980,260)])},
	{"id":"outer-bed", "points":PackedVector2Array([Vector2(3980,1500),Vector2(6500,1400),Vector2(9000,1500),Vector2(11500,1430),Vector2(14500,1550),Vector2(18000,1510),Vector2(20500,1550),Vector2(24000,1550),Vector2(24000,1800),Vector2(3980,1800)])},
	{"id":"relay-ridge", "points":PackedVector2Array([Vector2(4800,1000),Vector2(5600,850),Vector2(6000,900),Vector2(6100,1100),Vector2(5600,1170),Vector2(4800,1150)])},
	{"id":"chimney-sill", "points":PackedVector2Array([Vector2(8500,680),Vector2(8800,580),Vector2(10800,650),Vector2(11100,750),Vector2(10600,880),Vector2(8900,870)])},
	{"id":"chimney-crown", "points":PackedVector2Array([Vector2(11800,360),Vector2(12000,240),Vector2(14500,260),Vector2(14300,550),Vector2(13800,600),Vector2(12600,520)])},
	{"id":"deep-arch", "points":PackedVector2Array([Vector2(15500,620),Vector2(16100,490),Vector2(18100,600),Vector2(18300,760),Vector2(17700,880),Vector2(16000,850)])},
	{"id":"wreck-overhang", "points":PackedVector2Array([Vector2(20100,400),Vector2(20700,300),Vector2(23400,340),Vector2(23400,850),Vector2(22500,930),Vector2(21000,750)])},
	{"id":"wreck-soft-plug", "points":PackedVector2Array([Vector2(19400,750),Vector2(19600,750),Vector2(19600,1530),Vector2(19400,1530)])}]
static func terrain_ids() -> Array[String]:
	var ids: Array[String] = ["ceiling","seabed-and-trench","central-shelf","overlook-pillar","west-spire","east-spire"]
	for rock: Dictionary in ROCKS:
		ids.append(rock.id)
	return ids
static func discoveries() -> DiscoveryCatalog:
	var catalog: DiscoveryCatalog = load("res://resources/regions/shelf_discoveries.tres").duplicate(true) as DiscoveryCatalog
	catalog.survey_bounds = Rect2(BOUNDS)
	for item: Dictionary in POINTS:
		var point: PointOfInterest = PointOfInterest.new()
		point.stable_id = StringName(item.id)
		point.sonar_target_id = StringName(item.echo)
		point.display_name = item.title
		point.map_position = item.at
		catalog.points.append(point)
	return catalog
static func research() -> ResearchCatalog:
	var catalog: ResearchCatalog = load("res://resources/regions/shelf_research.tres").duplicate(true) as ResearchCatalog
	for item: Dictionary in SCIENCE:
		var target: ScanDefinition = ScanDefinition.new()
		target.stable_id = StringName(item.id)
		target.required_poi_id = StringName(item.poi)
		target.classification = item.type
		target.title = item.title
		target.description = item.text
		target.position = item.at
		target.duration = item.seconds
		catalog.targets.append(target)
	return catalog
static func missions() -> MissionCatalog:
	var catalog: MissionCatalog = load("res://resources/missions/shelf_missions.tres").duplicate(true) as MissionCatalog
	var descriptions: Array[Dictionary] = [
		{"id":OUTER,"title":"Beyond the spires","text":"Investigate the abandoned outer-shelf hydrophone and survey the mineral chimney field. Read their scientific records for the expedition's last heading.","targets":["outer-hydrophone-record","outer-vent-study"]},
		{"id":WRECK,"title":"The lost expedition","text":"Find the grounded expedition submarine on the deep outer shelf and recover its flight recorder. Prepare the pressure hull at base before a deep descent. Return to Shelf Base to submit the expedition review.","targets":["lost-expedition-blackbox"]},
		{"id":WILDLIFE,"title":"A living soundscape","text":"Optional: use a deliberate scientific scan to study the harmless grazer. It investigates strong sound; quiet listening and observation do not disturb it.","targets":["observer-ecology"]}]
	for item: Dictionary in descriptions:
		var definition: MissionDefinition = MissionDefinition.new()
		definition.stable_id = item.id
		definition.title = item.title
		definition.description = item.text
		definition.optional = item.id == WILDLIFE
		definition.acknowledgement_id = StringName(String(item.id)+"-ack")
		definition.acknowledgement = "Research received / " + item.title
		for id: String in item.targets:
			var objective: MissionObjective = MissionObjective.new()
			objective.stable_id = StringName("scan-"+id)
			objective.kind = MissionObjective.Kind.SCAN
			objective.target_id = StringName(id)
			objective.description = "Complete the scientific study: " + id.replace("-"," ")
			definition.objectives.append(objective)
		catalog.missions.append(definition)
	return catalog
static func upgrade_missions(records: Dictionary) -> Dictionary:
	var base: MissionCatalog = load("res://resources/missions/shelf_missions.tres") as MissionCatalog
	if not base.valid_records(records):
		return {}
	var result: Dictionary = missions().initial_records()
	for id: String in records:
		result[id] = records[id].duplicate(true)
	return result


static func narrative() -> NarrativeCatalog:
	var catalog: NarrativeCatalog = load("res://resources/narrative/shelf_chapter.tres").duplicate(true) as NarrativeCatalog
	for entry: NarrativeEntry in catalog.entries:
		if entry.evidence == NarrativeEntry.Evidence.BRIEFING:
			entry.text = "SHELF BASE / Expedition orders\n\nA survey submarine is missing. Begin with the reference plate and Twin Spires survey, then follow the recovered hydrophone and chimney-field evidence out onto the outer shelf. Locate the grounded vessel and scan its flight recorder. Return to Shelf Base for the expedition review.\n\nPrepare the pressure hull before descending beyond 300 metres. Sonar locates subjects; deliberate scientific scans recover records. Read those records for clues. The map records discoveries without drawing a route. Wildlife research is optional; weapons are not required to complete the expedition."
		if entry.evidence == NarrativeEntry.Evidence.CONCLUDED:
			entry.text = "SHELF BASE / Expedition review acknowledged\n\nThe recorder confirms that the submarine made an emergency grounding after a power failure. The portable receiver had already been removed, and no crew remained aboard. Finding their vessel resolves where the expedition stopped travelling; it does not explain where they went.\n\nThe crew were listening for the silence between transmissions. Their final instruction remains: If the sequence stops, keep recording.\n\nNERIS is safely home. Your research and discoveries remain available."
	for index: int in range(3):
		var item: Dictionary = SCIENCE[index]
		var entry: NarrativeEntry = NarrativeEntry.new()
		entry.stable_id = StringName(item.id+"-narrative")
		entry.title = item.title
		entry.text = item.text
		entry.evidence = [NarrativeEntry.Evidence.HYDROPHONE,NarrativeEntry.Evidence.VENT,NarrativeEntry.Evidence.WRECK][index]
		catalog.entries.append(entry)
	return catalog
