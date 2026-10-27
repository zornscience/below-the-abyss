class_name CampaignData
extends RefCounted
const AWARDS: Array[String] = ["commission","outer-survey","wreck-decoded"]
const MESSAGES: Array[String] = ["dispatch","relay","wreck-recovered","next-signal","survey-complete"]
static func fresh() -> Dictionary:
	return {"ranks":{"sonar":0,"hull":0},"awards":["commission"],"messages":[],"decoded":false}
static func earned(data: Dictionary) -> int:
	return (2 if "commission" in data.awards else 0)+(1 if "outer-survey" in data.awards else 0)+(1 if "wreck-decoded" in data.awards else 0)
static func available(data: Dictionary) -> int:
	return earned(data)-int(data.ranks.sonar)-int(data.ranks.hull)
static func _ids(value: Variant, allowed: Array[String]) -> bool:
	if not value is Array or value.size()>allowed.size(): return false
	var seen: Array[String] = []
	for id: Variant in value:
		if not id is String or id not in allowed or id in seen: return false
		seen.append(id)
	return true
static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size()!=4 or not data.get("ranks") is Dictionary or data.ranks.size()!=2 or not data.get("decoded") is bool: return false
	for branch: String in ["sonar","hull"]:
		if not InputBindings.is_integer(data.ranks.get(branch)) or data.ranks[branch]<0 or data.ranks[branch]>3: return false
	if not _ids(data.get("awards"),AWARDS) or not _ids(data.get("messages"),MESSAGES) or "commission" not in data.awards: return false
	return available(data)>=0 and bool(data.decoded)==("wreck-decoded" in data.awards)
static func migrate(progress: Dictionary) -> Dictionary:
	var data: Dictionary = fresh()
	data.ranks.sonar = 1 if "sonar-range-1200" in progress.upgrades else 0
	data.ranks.hull = 1 if "pressure-hull-400" in progress.upgrades else 0
	var missions: Dictionary = progress.missions
	if missions.has("shelf-outer-search") and missions["shelf-outer-search"].state=="claimed": data.awards.append("outer-survey")
	if "lost-expedition-blackbox" in progress.research and missions.has("shelf-wreck-recovery") and missions["shelf-wreck-recovery"].state=="claimed":
		data.decoded = true
		data.awards.append("wreck-decoded")
	return data
static func contains_earned(candidate: Dictionary, previous: Dictionary) -> bool:
	for key: String in ["awards","messages"]:
		for id: String in previous[key]:
			if id not in candidate[key]: return false
	return not previous.decoded or candidate.decoded

static func merge_earned(restored: Dictionary, current: Dictionary) -> Dictionary:
	var result: Dictionary = restored.duplicate(true)
	for key: String in ["awards","messages"]:
		for id: String in current[key]:
			if id not in result[key]: result[key].append(id)
	result.decoded = bool(restored.decoded) or bool(current.decoded)
	return result
static func normalized(data: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	for branch: String in ["sonar","hull"]: result.ranks[branch] = int(result.ranks[branch])
	return result
