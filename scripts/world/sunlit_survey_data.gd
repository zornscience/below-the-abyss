class_name SunlitSurveyData
extends RefCounted
## Hand-authored Zone 1 geography. The vent is a closed optional shaft, not Zone 2.
const BOUNDS: Rect2 = Rect2(120,16,21800,2584)
const CAMERA: Rect2i = Rect2i(0,-320,22000,2920)
const BUOY: Vector2 = Vector2(20800,620)
const SEARCH: Rect2 = Rect2(18600,260,3300,490)
const REPORT: Vector2 = Vector2(20100,600)
const BUOY_ECHO_RANGE: float = 650.0
const BUOY_APPROACH: Array[Vector2] = [Vector2(19750,600),Vector2(19900,710),Vector2(20300,710),Vector2(20300,560),Vector2(20600,560),Vector2(20800,620)]
const GATE: Rect2 = Rect2(4550,220,380,580)
const CLEARED: StringName = &"sunlit-cleared-passage"
const VENT: Rect2 = Rect2(13200,800,1600,1700)
const SPAWN: Vector2 = Vector2(420,80)
const MAIN_ROUTE: Array[Vector2] = [Vector2(1280,480),Vector2(2350,480),Vector2(3500,480),
 Vector2(4300,180),Vector2(5100,180),Vector2(5400,600),Vector2(6000,600),
 Vector2(6100,260),Vector2(7100,260),Vector2(7650,370),Vector2(8500,360),
 Vector2(8650,200),Vector2(9800,200),Vector2(10600,200),Vector2(12300,200),
 Vector2(13000,400),Vector2(14000,480),Vector2(14700,260),Vector2(16400,260),
 Vector2(16600,650),Vector2(16900,320),Vector2(19000,320),
 Vector2(19650,320),Vector2(19750,320),Vector2(19750,600),Vector2(19900,710),Vector2(20300,710),
 Vector2(20300,560),Vector2(20600,560),Vector2(20800,620)]
const TUNNELS: Array[Dictionary] = [
 {"id":"sunlit-sediment-tunnel","mouth":Rect2(6350,880,120,260)},
 {"id":"sunlit-basalt-tunnel","mouth":Rect2(11500,880,120,260)},
 {"id":"sunlit-arch-mouth","mouth":Rect2(10000,520,120,280)}]
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
	var authored: Array[PackedVector2Array] = [
		# Open shelf. Only the invisible ocean surface is a ceiling.
		PackedVector2Array([Vector2(120,800),Vector2(6100,800),Vector2(6100,1140),Vector2(7050,1140),Vector2(7050,800),Vector2(11250,800),Vector2(11250,1140),Vector2(12200,1140),Vector2(12200,800),Vector2(13200,800),Vector2(13450,960),Vector2(13450,2340),Vector2(13750,2500),Vector2(14250,2500),Vector2(14550,2340),Vector2(14550,960),Vector2(14800,800),Vector2(18600,800),Vector2(18600,1020),Vector2(19600,1020),Vector2(19600,800),Vector2(22000,800),Vector2(22000,2600),Vector2(120,2600)]),
		_rect(Rect2(21920,0,80,2600)),
		# Grounded landmarks preserve their authored discovery coordinates.
		PackedVector2Array([Vector2(1450,800),Vector2(1630,580),Vector2(1710,520),Vector2(1800,590),Vector2(1970,800)]),
		PackedVector2Array([Vector2(3290,800),Vector2(3380,550),Vector2(3440,520),Vector2(3500,800)]),
		PackedVector2Array([Vector2(3660,800),Vector2(3710,550),Vector2(3790,630),Vector2(3860,800)]),
		PackedVector2Array([Vector2(5500,800),Vector2(5700,740),Vector2(6050,800)]),
		PackedVector2Array([Vector2(7200,800),Vector2(7220,560),Vector2(7600,500),Vector2(8100,520),Vector2(8200,800)]),
		# Blind upper alcove, accessible from the east; the main route passes above.
		_rect(Rect2(6400,330,50,470)),_rect(Rect2(6400,330,500,50)),_rect(Rect2(6600,490,360,310)),
		# Sheltered fauna caves, with a generous eastern entrance.
		_rect(Rect2(8750,330,950,150)),_rect(Rect2(8750,330,50,470)),
		_rect(Rect2(14900,330,1400,150)),_rect(Rect2(14900,330,50,470)),
		# Basalt arch study: optional horizontal excavation entrance.
		_rect(Rect2(10000,450,1200,70)),_rect(Rect2(11080,450,120,350)),
		# Two optional lower tunnels. Approaches are open vertical shafts;
		# horizontal plugs can be excavated by the submarine's facing-fired torpedoes.
		_rect(Rect2(6350,800,700,80)),_rect(Rect2(6950,800,100,340)),
		_rect(Rect2(11500,800,700,80)),_rect(Rect2(12100,800,100,340)),
		PackedVector2Array([Vector2(17300,800),Vector2(17400,470),Vector2(17900,440),Vector2(18500,490),Vector2(18600,800)]),
		# Buoy shelter: open west entrance, alternating baffles and a blind lower spur.
		_rect(Rect2(19800,400,1700,100)),_rect(Rect2(21380,400,120,400)),
		_rect(Rect2(20100,490,140,150)),_rect(Rect2(20400,640,150,160)),
		_rect(Rect2(20950,590,430,80))]
	var result: Array[PackedVector2Array] = []
	for index: int in range(authored.size()): result.append(rough_contour(authored[index],index))
	return result

static func rough_contour(polygon: PackedVector2Array,seed_value: int = 0) -> PackedVector2Array:
	# Authored reproducible contour detail, shared by paint, map and actual collision.
	# Endpoints remain fixed so attached structures keep their original joins.
	var extent: Rect2 = Rect2(polygon[0],Vector2.ZERO)
	for point: Vector2 in polygon: extent = extent.expand(point)
	var detail: float = minf(1.0,minf(extent.size.x,extent.size.y)/240.0)
	var result: PackedVector2Array = []
	for index: int in range(polygon.size()):
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index+1)%polygon.size()]
		var steps: int = maxi(1,ceili(a.distance_to(b)/150.0))
		var normal: Vector2 = (b-a).orthogonal().normalized()
		for step: int in range(steps):
			var t: float = float(step)/steps
			var erosion: float = 0.0 if step==0 else sin(step*2.19+index*1.73+seed_value)*12.0+sin(step*0.83+seed_value)*6.0
			erosion *= detail
			# Outer west seam is welded to the protected boundary; keep clipping exact.
			if is_equal_approx(a.x,120.0) and is_equal_approx(b.x,120.0): erosion = 0.0
			result.append(a.lerp(b,t)+normal*erosion)
	return rounded_contour(result)

static func rounded_contour(points: PackedVector2Array) -> PackedVector2Array:
	var smooth: PackedVector2Array = []
	for index: int in range(points.size()):
		var p: Vector2 = points[index]
		var before: Vector2 = points[posmod(index-1,points.size())]
		var after: Vector2 = points[(index+1)%points.size()]
		if (p-before).normalized().dot((after-p).normalized())>0.95:
			smooth.append(p)
			continue
		var radius: float = minf(40.0,minf(p.distance_to(before),p.distance_to(after))*0.22)
		var a: Vector2 = p.move_toward(before,radius)
		var b: Vector2 = p.move_toward(after,radius)
		# Keep outer world seams exactly welded to the protected boundary.
		if p.x<=120 or p.x>=21920 or p.y>=2600:
			smooth.append(p)
			continue
		for step: int in range(7):
			var t: float = step/6.0
			smooth.append(a.lerp(p,t).lerp(p.lerp(b,t),t))
	return smooth

static func gate_contour() -> PackedVector2Array:
	return plug_contour(GATE,39)

static func plug_contour(rectangle: Rect2,seed_value: int) -> PackedVector2Array:
	var contour: PackedVector2Array = []
	for point: Vector2 in PackedVector2Array([Vector2(0.04,0.08),Vector2(0.28,0),Vector2(0.74,0.02),Vector2(0.96,0.13),Vector2(1,0.40),Vector2(0.95,0.66),Vector2(1,0.89),Vector2(0.72,1),Vector2(0.18,0.99),Vector2(0,0.78),Vector2(0.02,0.46),Vector2(0,0.24)]):
		contour.append(rectangle.position+point*rectangle.size)
	return rough_contour(contour,seed_value)

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
		scan.requires_sonar = false
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
