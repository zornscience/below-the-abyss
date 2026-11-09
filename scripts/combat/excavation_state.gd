class_name ExcavationState
extends RefCounted
const MAX_CUTS: int = 256
const MAX_RADIUS: float = 240.0
static func valid(records: Variant) -> bool:
	if not records is Array or records.size() > MAX_CUTS:
		return false
	for cut: Variant in records:
		if not cut is Dictionary or cut.size() != 3 or not cut.get("rock") is String \
			or not cut.get("at") is Array or cut.at.size() != 2 \
			or not _number(cut.get("radius"), 1, MAX_RADIUS):
			return false
		var profile: TunnelProfile = TwilightTunnelCatalog.gate_profile(cut.rock)
		var bounds: Rect2 = profile.world_gate().grow(MAX_RADIUS) if profile!=null else Rect2(0,0,24000,1800)
		if profile==null and cut.rock not in ShelfChapterData.terrain_ids(): return false
		if not _number(cut.at[0],bounds.position.x,bounds.end.x) or not _number(cut.at[1],bounds.position.y,bounds.end.y): return false
	return true

static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=minimum and float(value)<=maximum
