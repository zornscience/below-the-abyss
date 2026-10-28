class_name ResearchExperienceData
extends RefCounted
## Subrecord of the existing atomic campaign checkpoint; never a separate save file.
const RULES: ResearchExperienceRules = preload("res://resources/campaign/sunlit_experience.tres")

static func fresh() -> Dictionary:
	return {"credited":[],"imported":[]}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=2 or not RULES.is_valid(): return false
	var seen: Array[String] = []
	for key: String in ["credited","imported"]:
		if not value.get(key) is Array or value[key].size()>64: return false
		for id: Variant in value[key]:
			if not id is String or RULES.award_for(StringName(id))==0 or id in seen: return false
			seen.append(id)
	return true

static func total(value: Dictionary) -> int:
	var result: int = 0
	for id: String in value.credited: result += RULES.award_for(StringName(id))
	return result

static func points(value: Dictionary) -> int:
	return mini(RULES.maximum_extra_points,total(value)/RULES.xp_per_point)

static func reconcile(value: Dictionary, completed: Array, awards: Array[StringName] = []) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	for token: Variant in completed:
		var id: String = String(token)
		if RULES.award_for(StringName(id))==0 or id in result.credited or id in result.imported: continue
		if StringName(id) in awards: result.credited.append(id)
		else: result.imported.append(id)
	result.credited.sort()
	result.imported.sort()
	return result

static func valid_against(value: Dictionary, completed: Array) -> bool:
	if not valid(value): return false
	for id: String in value.credited+value.imported:
		if id not in completed: return false
	for id: Variant in completed:
		if RULES.award_for(StringName(id))>0 and id not in value.credited and id not in value.imported: return false
	return true

static func merge(a: Dictionary,b: Dictionary) -> Dictionary:
	var result: Dictionary = a.duplicate(true)
	for key: String in ["credited","imported"]:
		for id: String in b[key]:
			if id not in result[key]: result[key].append(id)
	for id: String in result.credited: result.imported.erase(id)
	result.credited.sort()
	result.imported.sort()
	return result
