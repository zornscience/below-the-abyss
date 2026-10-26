class_name StationProfile
extends Resource
## Free prototype services; limits are per explicit activation, not stock/currency.

@export var stable_id: StringName = &"shelf-base"
@export var display_name: String = "Shelf Base"
@export var docking_radius: float = 140.0
@export var maximum_docking_speed: float = 40.0
@export var hull_per_service: float = 100.0
@export var battery_per_service: float = 100.0
@export var oxygen_per_service: float = 100.0
@export var notices: Array[StationNotice] = []


func is_valid() -> bool:
	if not PointOfInterest.valid_id(stable_id) or display_name.strip_edges().is_empty() or display_name.length() > 64 \
		or not is_finite(docking_radius) or docking_radius <= 0.0 or docking_radius > 1000.0 \
		or not is_finite(maximum_docking_speed) or maximum_docking_speed < 0.0 or maximum_docking_speed > 240.0 \
		or notices.size() > 16:
		return false
	for limit: float in [hull_per_service, battery_per_service, oxygen_per_service]:
		if not is_finite(limit) or limit < 0.0 or limit > 1000000.0:
			return false
	var seen: Dictionary[StringName, bool] = {}
	for notice: StationNotice in notices:
		if notice == null or not notice.is_valid() or seen.has(notice.stable_id):
			return false
		seen[notice.stable_id] = true
	return true
