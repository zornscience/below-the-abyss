class_name CreatureNavigation
extends RefCounted
## Bounded cardinal graph. Every node and edge is checked against static terrain.

var _graph: AStar2D = AStar2D.new()
var _rules: CreatureProfile
var _space: PhysicsDirectSpaceState2D
var _region: Node2D
var _shape: CircleShape2D = CircleShape2D.new()


func _query(at: Vector2) -> PhysicsShapeQueryParameters2D:
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(0.0, _region.to_global(at))
	query.collision_mask = 1
	query.collide_with_areas = false
	return query


func clear(at: Vector2) -> bool:
	return _rules.center_bounds().has_point(at) and _space.intersect_shape(_query(at), 1).is_empty()


func segment_clear(from: Vector2, to: Vector2) -> bool:
	if not clear(from) or not clear(to):
		return false
	var query: PhysicsShapeQueryParameters2D = _query(from)
	query.motion = _region.to_global(to) - _region.to_global(from)
	var fractions: PackedFloat32Array = _space.cast_motion(query)
	return fractions[0] >= 1.0


func build(profile: CreatureProfile, region: Node2D) -> Error:
	if profile == null or not profile.is_valid() or region == null or not region.is_inside_tree():
		return ERR_INVALID_PARAMETER
	_rules = profile.duplicate(true) as CreatureProfile
	_region = region
	_space = region.get_world_2d().direct_space_state
	_shape.radius = _rules.body_radius
	_graph.clear()
	var bounds: Rect2 = _rules.center_bounds()
	var columns: int = int(ceilf(bounds.size.x / _rules.grid_spacing))
	var rows: int = int(ceilf(bounds.size.y / _rules.grid_spacing))
	if columns * rows > 1024:
		return ERR_INVALID_PARAMETER
	for y: int in range(rows):
		for x: int in range(columns):
			var at: Vector2 = bounds.position + Vector2(x, y) * _rules.grid_spacing + Vector2.ONE * 0.5
			var id: int = y * columns + x
			if not clear(at):
				continue
			_graph.add_point(id, at)
			for neighbor: int in [id - 1 if x > 0 else -1, id - columns]:
				if _graph.has_point(neighbor) and segment_clear(at, _graph.get_point_position(neighbor)):
					_graph.connect_points(id, neighbor)
	return OK


func _anchor(at: Vector2) -> int:
	var best: int = -1
	var distance: float = INF
	for id: int in _graph.get_point_ids():
		var point: Vector2 = _graph.get_point_position(id)
		var current: float = at.distance_squared_to(point)
		if (current < distance or (current == distance and id < best)) and segment_clear(at, point):
			best = id
			distance = current
	return best


func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	if _rules == null or not clear(from) or not clear(to):
		return PackedVector2Array()
	if segment_clear(from, to):
		return PackedVector2Array([to])
	var start: int = _anchor(from)
	var end: int = _anchor(to)
	if start < 0 or end < 0:
		return PackedVector2Array()
	var path: PackedVector2Array = _graph.get_point_path(start, end)
	if not path.is_empty():
		path.append(to)
	return path
