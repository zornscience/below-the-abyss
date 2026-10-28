class_name SunlitSurveyData
extends RefCounted
## Hand-authored Zone 1 geography. The vent is a closed optional shaft, not Zone 2.
const BOUNDS: Rect2 = Rect2(120,220,21800,2380)
const CAMERA: Rect2i = Rect2i(0,0,22000,2600)
const BUOY: Vector2 = Vector2(20800,620)
const SEARCH: Rect2 = Rect2(18600,260,3300,490)
const REPORT: Vector2 = Vector2(20000,500)
const GATE: Rect2 = Rect2(4550,220,70,580)
const CLEARED: StringName = &"sunlit-cleared-passage"
const VENT: Rect2 = Rect2(13200,800,1600,1700)
const MAIN_ROUTE: Array[Vector2] = [Vector2(1280,480),Vector2(3500,480),Vector2(4300,480),
	Vector2(4900,480),Vector2(5400,600),Vector2(6850,600),Vector2(7100,360),
	Vector2(8500,360),Vector2(8750,620),Vector2(9750,620),Vector2(9800,300),
	Vector2(11500,300),Vector2(11900,400),Vector2(13000,400),Vector2(14000,480),
	Vector2(14700,650),Vector2(16600,650),Vector2(16900,320),Vector2(19000,320),
	Vector2(19500,480),Vector2(20800,620)]
const STUDIES: Array[Dictionary] = [
	{"id":"sunlit-silver-shoal","title":"Silver shelf shoal","kind":"biological","at":Vector2(6000,600),"school":0,"text":"Silver schooling fish coordinate turns using nearby neighbours. A school is one species record, not an award for every individual. Quiet observation avoids disturbing the group."},
	{"id":"sunlit-amber-darter","title":"Amber kelp darter","kind":"biological","at":Vector2(9100,620),"school":1,"text":"Amber darters shelter beside rock faces. Their small changes in spacing keep the group together while leaving room to turn. A close submarine or loud pulse can briefly scatter them."},
	{"id":"sunlit-blue-grazer","title":"Blue shelf grazer","kind":"biological","at":Vector2(15500,650),"school":2,"text":"Blue grazers feed around mineral-encrusted basalt. Their coordinated movement follows the shape of the habitat. Listening passively emits no sound and does not startle them."},
	{"id":"sunlit-basalt-arch","title":"Basalt arch survey","kind":"geological","at":Vector2(10600,610),"text":"Cooling fractures divide basalt into durable blocks. Erosion opens passages between them; the arch and its supporting columns remain solid. Inspect the lower opening before entering."},
	{"id":"sunlit-mineral-terrace","title":"Mineral terrace","kind":"geological","at":Vector2(7650,450),"text":"Thin mineral films coat old basalt surfaces. Their uneven colour records local water chemistry rather than a constructed pattern. The shallow terrace offers a clear route above the ridge."},
	{"id":"sunlit-sediment-fan","title":"Suspended sediment fan","kind":"geological","at":Vector2(17800,350),"text":"Fine particles settle where water slows behind a ridge. A fresh disturbance briefly lifts them again. Sediment can make a contact difficult to see, so approach and confirm with sonar."},
	{"id":"sunlit-pillow-basalt","title":"Pillow basalt band","kind":"geological","at":Vector2(16800,710),"text":"Rounded cooling surfaces preserve the boundary between older lava and cold seawater. Mineral films trace the exposed fractures. This is geological field evidence, not an artificial structure."},
	{"id":"sunlit-vent-survey","title":"Hydrothermal shaft margin","kind":"geological","at":Vector2(14000,1090),"text":"Warm mineral-rich water rises through a basalt fracture. This local shaft descends below the vessel's pressure rating. Its shallow margin can be surveyed without entering damaging pressure; the descent is optional and returns along the same open shaft."}]

static func terrain() -> Array[PackedVector2Array]:
	return [
		_rect(Rect2(3900,0,18100,220)),
		PackedVector2Array([Vector2(3900,800),Vector2(13200,800),Vector2(13450,960),Vector2(13450,2340),Vector2(13750,2500),Vector2(14250,2500),Vector2(14550,2340),Vector2(14550,960),Vector2(14800,800),Vector2(22000,800),Vector2(22000,2600),Vector2(3900,2600)]),
		_rect(Rect2(21920,0,80,2600)),
		PackedVector2Array([Vector2(5500,220),Vector2(6500,220),Vector2(6460,400),Vector2(6100,440),Vector2(5550,390)]),
		PackedVector2Array([Vector2(7200,800),Vector2(7220,560),Vector2(7600,500),Vector2(8100,520),Vector2(8200,800)]),
		PackedVector2Array([Vector2(8850,220),Vector2(9700,220),Vector2(9680,480),Vector2(9250,510),Vector2(8880,450)]),
		_rect(Rect2(10000,380,1200,70)),_rect(Rect2(10000,440,120,210)),_rect(Rect2(11080,440,120,210)),
		PackedVector2Array([Vector2(12100,800),Vector2(12200,570),Vector2(12800,570),Vector2(12900,800)]),
		PackedVector2Array([Vector2(15000,220),Vector2(16300,220),Vector2(16240,480),Vector2(15700,515),Vector2(15060,470)]),
		PackedVector2Array([Vector2(17300,800),Vector2(17400,470),Vector2(17900,440),Vector2(18500,490),Vector2(18600,800)])]

static func _rect(rectangle: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rectangle.position,Vector2(rectangle.end.x,rectangle.position.y),rectangle.end,Vector2(rectangle.position.x,rectangle.end.y)])

static func points() -> Array[PointOfInterest]:
	var result: Array[PointOfInterest] = []
	for item: Dictionary in STUDIES:
		var point: PointOfInterest = PointOfInterest.new()
		point.stable_id = StringName(item.id+"-poi")
		point.sonar_target_id = StringName(item.id+"-echo")
		point.display_name = item.title
		point.map_position = item.at
		result.append(point)
	var passage: PointOfInterest = PointOfInterest.new()
	passage.stable_id = CLEARED
	passage.sonar_target_id = &"sunlit-cleared-passage-echo"
	passage.display_name = "Cleared rockfall passage"
	passage.map_position = GATE.get_center()
	result.append(passage)
	return result

static func studies() -> Array[ScanDefinition]:
	var result: Array[ScanDefinition] = []
	for item: Dictionary in STUDIES:
		var scan: ScanDefinition = ScanDefinition.new()
		scan.stable_id = StringName(item.id)
		scan.required_poi_id = StringName(item.id+"-poi")
		scan.title = item.title
		scan.classification = item.kind
		scan.description = item.text
		scan.position = item.at
		scan.duration = 5.0 if item.kind=="biological" else 6.0
		scan.radius = 260.0
		scan.subject_texture = preload("res://assets/art/sunlit/school_species.png") if item.kind=="biological" else preload("res://assets/art/sunlit/basalt_strata.png")
		if item.kind=="biological": scan.subject_region = Rect2(int(item.school)*724,0,724,724)
		result.append(scan)
	return result
