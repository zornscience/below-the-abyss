class_name SunlitRockDressing
extends Node2D
## Paint and clipped trim only; existing bodies and polygons remain authoritative.
const PAINT: Shader = preload("res://assets/shaders/sunlit_rock.gdshader")
const EDGE: Texture2D = preload("res://assets/art/sunlit/rock_edge.png")
const AREA: Array[Vector2] = [Vector2(120,180),Vector2(3900,180),Vector2(3900,1000),Vector2(120,1000)]
var _surfaces: Array[Dictionary] = []
var _paint: ShaderMaterial
var _active: bool = false
var _queued: bool = false
var _dirty: bool = true
var _pieces: Array[PackedVector2Array] = []

func configure(region: Node2D,boundary: Node2D) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_paint = ShaderMaterial.new()
	_paint.shader = PAINT
	_paint.set_shader_parameter("painted_rock",preload("res://assets/art/sunlit/basalt_strata.png"))
	for node: Node in region.get_node("Terrain").get_children():
		if node is GrayboxRock:
			_remember(node,node.get_node("Silhouette") as CanvasItem,not String(node.name).begins_with("Station"))
		elif node is DestructibleRock: _remember(node,node,true)
	for node: Node in boundary.get_children():
		if node is Polygon2D: _remember(node,node,true)
	refresh()

func _remember(source: Node2D,target: CanvasItem,painted: bool) -> void:
	_surfaces.append({"source":weakref(source),"target":weakref(target),"original":target.material,"painted":painted})

func set_active(value: bool) -> void:
	_active = value
	if value and _dirty: refresh()
	for item: Dictionary in _surfaces:
		var target: CanvasItem = item.target.get_ref() as CanvasItem
		if is_instance_valid(target) and item.painted: target.material = _paint if value else item.original

func contains_stone(point: Vector2) -> bool:
	for piece: PackedVector2Array in _pieces:
		if Geometry2D.is_point_in_polygon(point,piece): return true
	return false

func refresh() -> void:
	_dirty = true
	if not _active: return
	if _queued: return
	_queued = true
	# Remove obsolete trim immediately; excavation cannot leave a painted false wall.
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_rebuild.call_deferred()

func _rebuild() -> void:
	_queued = false
	if not is_inside_tree() or not _active: return
	_dirty = false
	_pieces.clear()
	var painted: Array[PackedVector2Array] = []
	for item: Dictionary in _surfaces:
		var source: Node2D = item.source.get_ref() as Node2D
		if not is_instance_valid(source): continue
		var polygons: Array[PackedVector2Array] = []
		if source is DestructibleRock: polygons = source.pieces
		elif source is GrayboxRock: polygons.append(source.outline)
		elif source is Polygon2D: polygons.append(source.polygon)
		for polygon: PackedVector2Array in polygons:
			var converted: PackedVector2Array = []
			for point: Vector2 in polygon: converted.append(to_local(source.to_global(point)))
			_pieces.append(converted)
			if item.painted: painted.append(converted)
	for polygon: PackedVector2Array in painted:
		for index: int in range(polygon.size()):
			var start: Vector2 = polygon[index]
			var end: Vector2 = polygon[(index+1)%polygon.size()]
			var distance: float = start.distance_to(end)
			if distance<20: continue
			var along: Vector2 = (end-start)/distance
			var inward: Vector2 = along.orthogonal()
			if not Geometry2D.is_point_in_polygon((start+end)*0.5+inward*0.5,polygon): inward = -inward
			var count: int = ceili(distance/320.0)
			for step: int in range(count):
				var a: Vector2 = start+along*distance*step/count
				var b: Vector2 = start+along*distance*(step+1)/count
				var middle: Vector2 = (a+b)*0.5
				if middle.x<120 or middle.x>3900 or middle.y<180 or middle.y>900: continue
				if contains_stone(middle-inward*2.0): continue
				var strip: PackedVector2Array = PackedVector2Array([a,b,b+inward*72,a+inward*72])
				for inside: PackedVector2Array in Geometry2D.intersect_polygons(strip,polygon):
					for clipped: PackedVector2Array in Geometry2D.intersect_polygons(inside,PackedVector2Array(AREA)):
						_trim(clipped,a,along,inward,a.distance_to(b),step%2==1)
	set_active(_active)

func _trim(points: PackedVector2Array,origin: Vector2,along: Vector2,inward: Vector2,width: float,flipped: bool) -> void:
	var trim: Polygon2D = Polygon2D.new()
	trim.position = origin
	var vertices: PackedVector2Array = []
	var coordinates: PackedVector2Array = []
	for point: Vector2 in points:
		vertices.append(point-origin)
		var u: float = (point-origin).dot(along)/width
		if flipped: u = 1.0-u
		coordinates.append(Vector2(u,(point-origin).dot(inward)/72.0)*EDGE.get_size())
	trim.polygon = vertices
	trim.uv = coordinates
	trim.texture = EDGE
	trim.color = Color(0.65,0.78,0.73,0.8)
	add_child(trim)
