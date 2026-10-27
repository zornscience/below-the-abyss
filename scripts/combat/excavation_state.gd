class_name ExcavationState
extends RefCounted
const MAX_CUTS: int = 256
static func valid(records: Variant) -> bool:
	if not records is Array or records.size() > MAX_CUTS:
		return false
	for cut: Variant in records:
		if not cut is Dictionary or cut.size() != 3 or not cut.get("rock") is String or cut.rock not in ShelfChapterData.terrain_ids() \
			or not cut.get("at") is Array or cut.at.size() != 2 \
			or not _number(cut.at[0], 0, 24000) or not _number(cut.at[1], 0, 1800) \
			or not _number(cut.get("radius"), 1, 160):
			return false
	return true

static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=minimum and float(value)<=maximum
