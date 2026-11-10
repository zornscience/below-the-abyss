class_name CombatArenaProfile
extends Resource
@export var bounds: Rect2
@export var refit: Vector2
@export var refit_radius: float = 150.0
@export var solids: Array[Rect2] = []
@export var mouths: Array[Rect2] = []
@export var course: PackedVector2Array
@export var swarm_spawns: PackedVector2Array
@export var measurement_start: Vector2
@export var swarmer_probe: Vector2
@export var stun_probe: Vector2
@export var chase_probe: Vector2
@export var escape: Vector2
@export var stalker_base: RiftStalkerProfile
@export var stalker_bounds: Rect2
@export var stalker_patrol: PackedVector2Array
func stalker_profile() -> RiftStalkerProfile:
	var result: RiftStalkerProfile = stalker_base.duplicate(true) as RiftStalkerProfile
	result.navigation_bounds = stalker_bounds
	result.patrol_points = stalker_patrol
	return result
func polygons() -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = []
	for index: int in range(solids.size()):
		pieces.append(SunlitSurveyData.rough_contour(SunlitSurveyData._rect(solids[index]),800+index))
	for index: int in range(mouths.size()):
		pieces = TunnelProfile._subtract(pieces,SunlitSurveyData.rough_contour(SunlitSurveyData._rect(mouths[index]),850+index),mouths[index].get_center().x)
	return TunnelProfile._join(pieces)
func is_valid() -> bool:
	return bounds.has_area() and bounds.has_point(refit) and refit_radius>64 and swarm_spawns.size()>=3 and swarm_spawns.size()<=5 and mouths.size()==2 and course.size()>=4 and stalker_base!=null and stalker_profile().is_valid() and not stalker_bounds.has_point(refit)
