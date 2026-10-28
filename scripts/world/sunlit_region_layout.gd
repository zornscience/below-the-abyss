class_name SunlitRegionLayout
extends Node2D
## Canonical collision-bearing authored extension. Decorations are separate children.
var bodies: Array[GrayboxRock] = []
var gate: DestructibleRock
var _legacy: Array[Dictionary] = []
var enabled: bool = false
var _checked_pieces: Array[PackedVector2Array] = []
var _clearance_checked: bool = false
var _passage_y: float = NAN

func configure(region: ContinentalShelf,excavation: ExcavationSystem) -> void:
	name = "SunlitRegionLayout"
	for polygon: PackedVector2Array in SunlitSurveyData.terrain():
		var rock: GrayboxRock = preload("res://scenes/props/graybox_rock.tscn").instantiate() as GrayboxRock
		rock.outline = polygon
		rock.name = "SunlitBasalt%d" % bodies.size()
		add_child(rock)
		bodies.append(rock)
	gate = DestructibleRock.new()
	gate.name = "FracturedPassage"
	region.get_node("Terrain").add_child(gate)
	gate.configure("sunlit-cavein",SunlitSurveyData.gate_contour(),Color("87948a"))
	excavation.register(gate)
	for child: Node in region.get_node("Terrain").get_children():
		if child==gate: continue
		var polygon: PackedVector2Array = child.original if child is DestructibleRock else (child.outline if child is GrayboxRock else PackedVector2Array())
		var minimum: float = INF
		var maximum: float = -INF
		for point: Vector2 in polygon:
			minimum = minf(minimum,point.x)
			maximum = maxf(maximum,point.x)
		if minimum>=3980.0 or maximum>10000:
			_legacy.append({"body":weakref(child),"layer":child.collision_layer,"visible":child.visible})
	for item: Dictionary in [{"at":Vector2(4220,350),"text":"RECENT ROCKFALL\nFRACTURED BASALT · EXCAVATION"},{"at":Vector2(13760,790),"text":"OPTIONAL VENT SHAFT\nCHECK FITTED DEPTH RATING · RETURN ↑"}]:
		var sign: Label = Label.new()
		sign.text = item.text
		sign.position = item.at
		UiTypography.style(sign,&"secondary")
		add_child(sign)
	set_enabled(false)

func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	for rock: GrayboxRock in bodies: rock.collision_layer = 1 if value else 0
	gate.visible = value
	gate.collision_layer = 1 if value else 0
	for record: Dictionary in _legacy:
		var body: CollisionObject2D = record.body.get_ref() as CollisionObject2D
		if is_instance_valid(body):
			body.collision_layer = 0 if value else int(record.layer)
			body.visible = false if value else bool(record.visible)

func passage_clear() -> bool:
	# Any full-hull opening counts. Cache topology; never clip polygons every frame.
	if _clearance_checked and gate.pieces==_checked_pieces: return is_finite(_passage_y)
	_checked_pieces = gate.pieces.duplicate(true)
	_clearance_checked = true
	_passage_y = NAN
	for offset: int in range(24):
		for direction: int in [-1,1]:
			var y: float = 480+offset*12*direction
			if y<256 or y>764: continue
			var swept: PackedVector2Array = SunlitSurveyData._rect(Rect2(4440,y-34,600,68))
			var blocked: bool = false
			for polygon: PackedVector2Array in gate.pieces:
				if not Geometry2D.intersect_polygons(swept,polygon).is_empty():
					blocked = true
					break
			if not blocked:
				_passage_y = y
				return true
	return false

func preserve_archived_opening(excavation: ExcavationSystem,discoveries: Array) -> void:
	# PR35 cleared gates are grandfathered; never reopen a permanently cleared route.
	# Same bounded journal/API, no new flags, event, score or completion emission.
	if String(SunlitSurveyData.CLEARED) not in discoveries or passage_clear(): return
	# Derived compatibility geometry consumes no extra cut slots, even at MAX_CUTS.
	# The already permanent cleared POI reconstructs this widening on each restore.
	for x: float in [4550.0,4690.0,4830.0,4930.0]: gate.carve(Vector2(x,480),150)
	excavation.geometry_changed.emit()
