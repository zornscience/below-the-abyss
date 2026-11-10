class_name TwilightTunnelCatalog
extends RefCounted
const DATA: TunnelSetProfile = preload("res://resources/world/twilight_tunnels.tres")
static func gate_profile(id: String) -> TunnelProfile:
	for profile: TunnelProfile in DATA.systems:
		if profile.gate_id==id: return profile
	return null
static func contours(original: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for index: int in range(original.size()):
		var replacement: TunnelProfile
		for profile: TunnelProfile in DATA.systems:
			if profile.replace_index==index: replacement = profile
		if replacement==null: result.append(original[index])
		else: result.append_array(replacement.rock_polygons())
	return result
static func records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for profile: TunnelProfile in DATA.systems:
		result.append({"id":String(profile.payoff_id),"title":profile.payoff_title,"at":profile.origin+profile.branch[-1],"type":"geological","text":profile.payoff_text,"clear_path":true})
	return result

static func payoff_ids() -> Array[String]:
	var result: Array[String] = []
	for profile: TunnelProfile in DATA.systems: result.append(String(profile.payoff_id))
	return result

static func is_valid(vessel_span: float) -> bool:
	if DATA.systems.size()<2: return false
	var ids: Array[String] = []
	var replaced: Array[int] = []
	for resource: Resource in DATA.systems:
		var profile: TunnelProfile = resource as TunnelProfile
		if profile==null or not profile.is_valid(vessel_span) or profile.replace_index in replaced: return false
		for id: String in [String(profile.stable_id),profile.gate_id,String(profile.payoff_id)]:
			if id in ids: return false
			ids.append(id)
		if not profile.vent_id.is_empty():
			if String(profile.vent_id) in ids: return false
			ids.append(String(profile.vent_id))
		replaced.append(profile.replace_index)
	return true
