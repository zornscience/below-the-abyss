class_name DrownedCavesData
extends RefCounted
## Zone 3. The map/scan IDs are stable across reloads. Mara is NOT found here.
const SPAWN: Vector2 = Vector2(43300, 4480)
const EXIT: Vector2 = Vector2(43300, 4480)
const SHRINE: Vector2 = Vector2(54100, 6840)
const CAMERA: Rect2i = Rect2i(41900, 3900, 14500, 4100)
const ENCOUNTER: StringName = &"zone3-memory-crystal"
const LEAVE: StringName = &"zone3-crystal-leave"
const TAKE: StringName = &"zone3-crystal-take"
const UNDERSTOOD: StringName = &"zone3-glyph-understood"
const REQUIRED: Array[StringName] = [&"caves-human-handprints", &"caves-vael-account", &"caves-mara-log-four"]
const RECORDS: Array[Dictionary] = [
	{"id":"caves-human-handprints","title":"The handprint wall","at":Vector2(46000,4670),"kind":"artificial","text":"Limestone that once faced open air bears small human handprints beside taller, luminous figures. At the centre, a painted hand is raised without a weapon. On the far edge, both groups are shown falling. The image records violence, but not who began it."},
	{"id":"caves-vael-account","title":"The other testimony","at":Vector2(48050,5560),"kind":"artificial","text":"A living crystal seam holds repeating glyphs. Wick: Three stable patterns: WAIT, ANSWER, REMAIN. Below them: figures shielding smaller figures, and a circle closed around a cavern. The order is a request, not a firing sequence."},
	{"id":"caves-mara-log-four","title":"Mara / field log 04","at":Vector2(50750,5710),"kind":"artificial","text":"Mara Voss / acoustic notebook. I compared the cave wall with the whaler's marks. Different media. Same intervals. The Choir is not background noise; it pauses when something listens. Do not send another pulse until you know what silence means."},
	{"id":"caves-mara-log-five","title":"Mara / field log 05 (optional)","at":Vector2(53350,5590),"kind":"artificial","text":"I found two accounts of the same meeting. Neither tells me who cast the first stone. Both remember losing children. If I carried that memory away, would I have learned anything or simply made a second loss?"},
	{"id":"caves-silt-current","title":"The silt channel (optional)","at":Vector2(48500,6530),"kind":"geological","text":"A cold density current runs along the floor. Slow down and let the suspended mineral grains settle. The channel is passable without violence."},
	{"id":"caves-warden-shelter","title":"Sentinel shelter (optional)","at":Vector2(47200,5980),"kind":"biological","text":"A narrow refuge contains the same light pattern as the sentinel on the Twilight Shelf. The passage is quiet. If it was released and survived, one living guide may have used this route."},
	{"id":"caves-memory-shrine","title":"The memory shrine","at":SHRINE,"kind":"artificial","text":"A living archive rests inside a limestone cradle. Three light marks repeat across it: WAIT, ANSWER, REMAIN. Wick: This is not a power cell. The light changes with our presence. Interact after scanning the two accounts and Mara's record."}
]
static func knows(id: StringName) -> bool:
	for item: Dictionary in RECORDS:
		if StringName(item.id)==id: return true
	return false
static func record(id: StringName) -> Dictionary:
	for item: Dictionary in RECORDS:
		if StringName(item.id)==id: return item.duplicate(true)
	return {}
static func append_research(catalog: ResearchCatalog) -> void:
	for item: Dictionary in RECORDS:
		var definition: ScanDefinition = ScanDefinition.new()
		definition.stable_id = StringName(item.id)
		definition.required_poi_id = StringName(item.id+"-poi")
		definition.position = item.at
		definition.title = item.title
		definition.description = item.text
		definition.classification = item.kind
		definition.requires_sonar = false
		definition.radius = 200
		definition.duration = 4.0
		definition.subject_texture = TwilightShelfData.subject_texture(&"twilight-whaler-marking")
		catalog.targets.append(definition)
static func append_discoveries(catalog: DiscoveryCatalog) -> void:
	for item: Dictionary in RECORDS:
		var point: PointOfInterest = PointOfInterest.new()
		point.stable_id = StringName(item.id+"-poi")
		point.sonar_target_id = StringName(item.id+"-echo")
		point.map_position = item.at
		point.display_name = item.title
		catalog.points.append(point)
static func evidence_complete(research: ResearchRegistry) -> bool:
	for id: StringName in REQUIRED:
		if not research.is_completed(id): return false
	return research.is_completed(&"caves-memory-shrine")
