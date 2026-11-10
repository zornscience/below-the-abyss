class_name TunnelProfile
extends Resource
## Local centrelines compile the rock and also describe the traversable graph.
@export var stable_id: StringName
@export var origin: Vector2
@export var replace_index: int
@export var seed: int
@export var outer: PackedVector2Array
@export var main: PackedVector2Array
@export var branch: PackedVector2Array
@export var shortcut: PackedVector2Array
@export var squeeze: PackedVector2Array
@export var normal_width: float = 192.0
@export var squeeze_width: float = 124.0
@export var normal_probe: Vector2
@export var gate_id: String
@export var gate_bounds: Rect2
@export var fire_from: Vector2
@export var payoff_id: StringName
@export var payoff_title: String
@export_multiline var payoff_text: String
@export var approach: PackedVector2Array
@export var return_path: PackedVector2Array
@export var vent_id: StringName
@export var vent_at: Vector2

func world_path(path: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = path.duplicate()
	for index: int in range(result.size()): result[index] += origin
	return result
func world_gate() -> Rect2:
	return Rect2(origin+gate_bounds.position,gate_bounds.size)
func is_valid(vessel_span: float) -> bool:
	if not PointOfInterest.valid_id(stable_id) or not PointOfInterest.valid_id(StringName(gate_id)) or not PointOfInterest.valid_id(payoff_id): return false
	if outer.size()<4 or main.size()<6 or branch.size()<2 or shortcut.size()!=2 or squeeze.size()!=2: return false
	if not origin.is_finite() or replace_index<0 or not is_finite(normal_width) or not is_finite(squeeze_width): return false
	if not vent_id.is_empty() and (not PointOfInterest.valid_id(vent_id) or not vent_at.is_finite()): return false
	for path: PackedVector2Array in [outer,main,branch,shortcut,squeeze,approach,return_path]:
		for at: Vector2 in path:
			if not at.is_finite(): return false
	if normal_width<vessel_span*2.5 or squeeze_width<vessel_span*1.5 or squeeze_width>vessel_span*2.0: return false
	if not _on_path(branch[0],main) or _on_path(branch[-1],main) or not _on_path(shortcut[0],main) or not _on_path(shortcut[-1],main): return false
	var found: bool = false
	for index: int in range(main.size()-1):
		if main[index]==squeeze[0] and main[index+1]==squeeze[1]: found = true
	if not found or approach.is_empty() or return_path.is_empty(): return false
	if approach[-1]!=origin+main[0] or return_path[0]!=origin+main[-1]: return false
	for path: PackedVector2Array in [main,branch,shortcut]:
		for index: int in range(path.size()-1):
			var delta: Vector2 = path[index+1]-path[index]
			if delta.is_zero_approx() or (delta.x!=0 and delta.y!=0): return false
	return gate_bounds.position.is_finite() and gate_bounds.size.is_finite() and gate_bounds.has_area() \
		and _on_path(gate_bounds.get_center(),shortcut) and _on_path(fire_from,shortcut) \
		and not gate_bounds.has_point(shortcut[0]) and not gate_bounds.has_point(shortcut[-1])
static func _on_path(at: Vector2,path: PackedVector2Array) -> bool:
	for index: int in range(path.size()-1):
		if Geometry2D.get_closest_point_to_segment(at,path[index],path[index+1]).distance_to(at)<0.1: return true
	return false
static func length(path: PackedVector2Array) -> float:
	var total: float = 0
	for index: int in range(path.size()-1): total += path[index].distance_to(path[index+1])
	return total
func long_path() -> PackedVector2Array:
	var result: PackedVector2Array = []
	var taking: bool = false
	for at: Vector2 in main:
		if at==shortcut[0]: taking = true
		if taking: result.append(at)
		if at==shortcut[-1]: break
	return result
func rock_polygons() -> Array[PackedVector2Array]:
	# Roughen in local space, preserving the existing rounded rock language.
	var pieces: Array[PackedVector2Array] = [SunlitSurveyData.rough_contour(outer,seed)]
	var serial: int = 0
	for path: PackedVector2Array in [main,branch,shortcut]:
		for index: int in range(path.size()-1):
			var width: float = normal_width
			if path==branch or (path[index]==squeeze[0] and path[index+1]==squeeze[1]): width = squeeze_width
			var a: Vector2 = path[index]
			var b: Vector2 = path[index+1]
			var rect: Rect2 = Rect2(Vector2(minf(a.x,b.x),minf(a.y,b.y))-Vector2.ONE*width*0.5,(b-a).abs()+Vector2.ONE*width)
			var opening: PackedVector2Array = SunlitSurveyData.rough_contour(SunlitSurveyData._rect(rect),seed+serial+1)
			pieces = _subtract(pieces,opening,rect.get_center().x)
			serial += 1
	pieces = _join(pieces)
	var result: Array[PackedVector2Array] = []
	for piece: PackedVector2Array in pieces: result.append(world_path(piece))
	return result
static func _subtract(pieces: Array[PackedVector2Array],opening: PackedVector2Array,x: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for piece: PackedVector2Array in pieces:
		if Geometry2D.intersect_polygons(piece,opening).is_empty():
			result.append(piece)
			continue
		# As in DestructibleRock, split through the cut to avoid hole contours.
		for side: int in [-1,1]:
			var half: PackedVector2Array = PackedVector2Array([Vector2(x,-10000),Vector2(x+side*50000,-10000),Vector2(x+side*50000,10000),Vector2(x,10000)])
			for part: PackedVector2Array in Geometry2D.intersect_polygons(piece,half):
				for rest: PackedVector2Array in Geometry2D.clip_polygons(part,opening):
					if rest.size()>=3 and not Geometry2D.is_polygon_clockwise(rest): result.append(rest)
	return result

static func _join(pieces: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	# Rejoin construction seams so the existing visibility pass outlines only rock
	# boundaries. A union with a hole is deliberately kept as separate simple pieces.
	var merged: bool = true
	while merged:
		merged = false
		for left: int in range(pieces.size()):
			for right: int in range(left+1,pieces.size()):
				var union: Array[PackedVector2Array] = Geometry2D.merge_polygons(pieces[left],pieces[right])
				if union.size()!=1: continue
				pieces[left] = union[0]
				pieces.remove_at(right)
				merged = true
				break
			if merged: break
	return pieces
