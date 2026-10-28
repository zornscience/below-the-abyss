class_name SunlitRockDressing
extends Node2D
## Pure paint cache. Bodies and their current polygons remain authoritative.
const PAINT: Shader = preload("res://assets/shaders/sunlit_rock.gdshader")
const EDGE: Texture2D = preload("res://assets/art/sunlit/rock_edge.png")
const AREA: Array[Vector2] = [Vector2(120,180),Vector2(22000,180),Vector2(22000,2600),Vector2(120,2600)]
const MAX_MESH_CACHE: int = 64
# Numeric geometry only; no scene Nodes, gameplay state or persisted instance IDs.
static var _mesh_cache: Dictionary[String,Array] = {}
var _surfaces: Array[Dictionary] = []
var _paint: ShaderMaterial
var _fractured: ShaderMaterial
var _active: bool = false
var _queued: bool = false
var _dirty: bool = true
var _pieces: Array[PackedVector2Array] = []

func configure(region: Node2D,boundary: Node2D) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_paint = ShaderMaterial.new()
	_paint.shader = PAINT
	_paint.set_shader_parameter("painted_rock",preload("res://assets/art/sunlit/basalt_strata.png"))
	_fractured = _paint.duplicate(false) as ShaderMaterial
	_fractured.set_shader_parameter("mineral_tint",Color(1.4,1.15,0.75))
	for node: Node in region.get_node("Terrain").get_children():
		if node is GrayboxRock: _remember(node,node.get_node("Silhouette") as CanvasItem,not String(node.name).begins_with("Station"))
		elif node is DestructibleRock: _remember(node,node,true)
	for node: Node in boundary.get_children():
		if node is Polygon2D: _remember(node,node,true)
	var layout: SunlitRegionLayout = region.get_node_or_null("SunlitRegionLayout") as SunlitRegionLayout
	if layout!=null:
		for node: GrayboxRock in layout.bodies: _remember(node,node.get_node("Silhouette") as CanvasItem,true)
	refresh()

func _remember(source: Node2D,target: CanvasItem,painted: bool) -> void:
	_surfaces.append({"source":weakref(source),"target":weakref(target),"original":target.material,"painted":painted,"geometry":[],"trims":[]})

func set_active(value: bool) -> void:
	_active = value
	if value and _dirty: refresh()
	for item: Dictionary in _surfaces:
		var target: CanvasItem = item.target.get_ref() as CanvasItem
		if is_instance_valid(target) and item.painted:
			var source: Node = item.source.get_ref()
			target.material = (_fractured if source is DestructibleRock and source.rock_id=="sunlit-cavein" else _paint) if value else item.original

func contains_stone(point: Vector2) -> bool:
	for piece: PackedVector2Array in _pieces:
		if Geometry2D.is_point_in_polygon(point,piece): return true
	return false

func _geometry(item: Dictionary) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var source: Node2D = item.source.get_ref() as Node2D
	if not is_instance_valid(source): return result
	if source is CollisionObject2D and source.collision_layer==0: return result
	if source.get_parent() is CollisionObject2D and source.get_parent().collision_layer==0: return result
	var polygons: Array[PackedVector2Array] = []
	if source is DestructibleRock: polygons = source.pieces
	elif source is GrayboxRock: polygons.append(source.outline)
	elif source is Polygon2D: polygons.append(source.polygon)
	for polygon: PackedVector2Array in polygons:
		var converted: PackedVector2Array = []
		for point: Vector2 in polygon: converted.append(to_local(source.to_global(point)))
		result.append(converted)
	return result

func refresh() -> void:
	_dirty = true
	if not _active or _queued: return
	_queued = true
	for item: Dictionary in _surfaces:
		if _geometry(item)==item.geometry: continue
		# Only changed trim is removed immediately. Unchanged geometry stays cached.
		for node: Polygon2D in item.trims:
			remove_child(node)
			node.queue_free()
		item.trims.clear()
		item.geometry = []
	_rebuild.call_deferred()

func _rebuild() -> void:
	_queued = false
	if not is_inside_tree() or not _active: return
	_dirty = false
	_pieces.clear()
	var collected: Array[Array] = []
	for item: Dictionary in _surfaces:
		var geometry: Array[PackedVector2Array] = _geometry(item)
		_pieces.append_array(geometry)
		collected.append(geometry)
	var context: String = var_to_bytes(_pieces).hex_encode().sha256_text()
	for index: int in range(_surfaces.size()):
		var item: Dictionary = _surfaces[index]
		var geometry: Array = collected[index]
		if geometry==item.geometry: continue
		item.geometry = geometry
		if not item.painted or geometry.is_empty(): continue
		var key: String = context+var_to_bytes(geometry).hex_encode().sha256_text()
		if not _mesh_cache.has(key):
			if _mesh_cache.size()>=MAX_MESH_CACHE: _mesh_cache.erase(_mesh_cache.keys()[0])
			_mesh_cache[key] = _build_specs(geometry)
		for spec: Dictionary in _mesh_cache[key]:
			var trim: Polygon2D = Polygon2D.new()
			trim.position = spec.origin
			trim.polygon = spec.vertices
			trim.uv = spec.uv
			trim.texture = EDGE
			trim.color = Color(0.65,0.78,0.73,0.8)
			add_child(trim)
			item.trims.append(trim)
	set_active(_active)

func _build_specs(geometry: Array) -> Array:
	var specs: Array = []
	for polygon: PackedVector2Array in geometry:
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
				if middle.x<120 or middle.x>22000 or middle.y<180 or middle.y>2600: continue
				if contains_stone(middle-inward*2.0): continue
				var strip: PackedVector2Array = PackedVector2Array([a,b,b+inward*72,a+inward*72])
				for inside: PackedVector2Array in Geometry2D.intersect_polygons(strip,polygon):
					for clipped: PackedVector2Array in Geometry2D.intersect_polygons(inside,PackedVector2Array(AREA)):
						var vertices: PackedVector2Array = []
						var uv: PackedVector2Array = []
						for point: Vector2 in clipped:
							vertices.append(point-a)
							var u: float = (point-a).dot(along)/a.distance_to(b)
							if step%2==1: u = 1.0-u
							uv.append(Vector2(u,(point-a).dot(inward)/72.0)*EDGE.get_size())
						specs.append({"origin":a,"vertices":vertices,"uv":uv})
	return specs
