class_name TwilightTunnelCatalog
extends RefCounted
const DATA: TunnelSetProfile = preload("res://resources/world/twilight_tunnels.tres")
## The Drowned Caves (DC-2) reuse the same profile type and gate rules as their own set.
const CAVES: TunnelSetProfile = preload("res://resources/world/drowned_caves_tunnels.tres")
## A stable gate id from either region. Cut validation and replay use this, so a caves cut survives a save.
static func gate_profile(id: String) -> TunnelProfile:
	for group: TunnelSetProfile in [DATA,CAVES]:
		for profile: TunnelProfile in group.systems:
			if profile.gate_id==id: return profile
	return null
static func contours(original: Array[PackedVector2Array],group: TunnelSetProfile = DATA) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for index: int in range(original.size()):
		var replacement: TunnelProfile
		for profile: TunnelProfile in group.systems:
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

static func is_valid(vessel_span: float,group: TunnelSetProfile = DATA,minimum: int = 2) -> bool:
	if group.systems.size()<minimum: return false
	var ids: Array[String] = []
	var replaced: Array[int] = []
	for resource: Resource in group.systems:
		var profile: TunnelProfile = resource as TunnelProfile
		if profile==null or not profile.is_valid(vessel_span) or profile.replace_index in replaced: return false
		for id: String in [String(profile.stable_id),profile.gate_id,String(profile.payoff_id)]:
			if id.is_empty(): continue
			if id in ids: return false
			ids.append(id)
		if not profile.vent_id.is_empty():
			if String(profile.vent_id) in ids: return false
			ids.append(String(profile.vent_id))
		replaced.append(profile.replace_index)
	return true
