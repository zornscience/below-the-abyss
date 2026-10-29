class_name DestructibleRock
extends StaticBody2D
## Exact polygon subtraction; split through the blast before clipping to avoid hole contours.
const ROCK_PAINT: Texture2D = preload("res://assets/art/painted/basalt.png")
var rock_id: String
var original: PackedVector2Array
var pieces: Array[PackedVector2Array] = []
var fill: Color = Color("102c32")
var _edges: Array[PackedVector2Array] = []
func configure(id: String, polygon: PackedVector2Array, tint: Color) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	rock_id = id
	original = polygon.duplicate()
	fill = tint
	collision_layer = 1
	collision_mask = 2
	reset_shape()
func reset_shape() -> void:
	pieces = [original.duplicate()]
	_rebuild()
func carve(world_at: Vector2, radius: float) -> bool:
	if not world_at.is_finite() or not is_finite(radius) or radius <= 0.0 or radius > ExcavationState.MAX_RADIUS:
		return false
	var at: Vector2 = to_local(world_at)
	var circle: PackedVector2Array = []
	for index: int in range(32):
		circle.append(at + Vector2.from_angle(index * TAU / 32.0) * radius)
	var result: Array[PackedVector2Array] = []
	var changed: bool = false
	for piece: PackedVector2Array in pieces:
		if Geometry2D.intersect_polygons(piece, circle).is_empty():
			result.append(piece)
			continue
		changed = true
		# Half planes have ample bounded extent and put the blast center on their edge.
		for side: int in [-1, 1]:
			var half: PackedVector2Array = PackedVector2Array([Vector2(at.x, -10000),Vector2(at.x + side * 50000, -10000),Vector2(at.x + side * 50000, 10000),Vector2(at.x, 10000)])
			for part: PackedVector2Array in Geometry2D.intersect_polygons(piece, half):
				for remaining: PackedVector2Array in Geometry2D.clip_polygons(part, circle):
					if remaining.size() >= 3:
						result.append(remaining)
	var vertices: int = 0
	for part: PackedVector2Array in result:
		vertices += part.size()
	if not changed or result.size() > 64 or vertices > 2048:
		return false
	pieces = result
	_rebuild()
	return true
func _inside(at: Vector2) -> bool:
	for part: PackedVector2Array in pieces:
		if Geometry2D.is_point_in_polygon(at, part):
			return true
	return false
func _rebuild() -> void:
	for child: Node in get_children():
		if child is CollisionPolygon2D:
			remove_child(child)
			child.free()
	_edges.clear()
	for part: PackedVector2Array in pieces:
		var shape: CollisionPolygon2D = CollisionPolygon2D.new()
		shape.polygon = part
		add_child(shape)
		for index: int in range(part.size()):
			var a: Vector2 = part[index]
			var b: Vector2 = part[(index + 1) % part.size()]
			var normal: Vector2 = (b-a).orthogonal().normalized() * 0.5
			if _inside((a+b)*0.5+normal) != _inside((a+b)*0.5-normal):
				_edges.append(PackedVector2Array([a,b]))
	queue_redraw()
func _draw() -> void:
	for part: PackedVector2Array in pieces:
		var coordinates: PackedVector2Array = []
		for point: Vector2 in part: coordinates.append(point/384.0)
		draw_polygon(part,PackedColorArray([Color(0.62,0.72,0.76)]),coordinates,ROCK_PAINT)
	if material!=null: return # Painted geology has no prototype wire outline.
	for edge: PackedVector2Array in _edges:
		draw_line(edge[0], edge[1], Color("487b7d"), 2.0, true)
