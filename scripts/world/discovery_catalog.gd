class_name DiscoveryCatalog
extends Resource
## Public survey extent is deliberately coarse; no hidden cave/secret geometry.

@export var region_id: StringName = &"continental_shelf"
@export var survey_bounds: Rect2 = Rect2(0, 0, 4100, 1800)
@export var points: Array[PointOfInterest] = []


func is_valid() -> bool:
	if not PointOfInterest.valid_id(region_id) or not survey_bounds.position.is_finite() \
		or not survey_bounds.size.is_finite() or survey_bounds.size.x <= 0.0 or survey_bounds.size.y <= 0.0 \
		or points.is_empty() or points.size() > 128:
		return false
	var ids: Dictionary[StringName, bool] = {}
	var targets: Dictionary[StringName, bool] = {}
	for point: PointOfInterest in points:
		if point == null or not point.is_valid() or not survey_bounds.has_point(point.map_position) \
			or ids.has(point.stable_id) or targets.has(point.sonar_target_id):
			return false
		ids[point.stable_id] = true
		targets[point.sonar_target_id] = true
	return true
