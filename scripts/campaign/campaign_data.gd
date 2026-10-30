class_name CampaignData
extends RefCounted
const AWARDS: Array[String] = ["commission","outer-survey","wreck-decoded","twilight-expedition","twilight-specimen"]
const MESSAGES: Array[String] = ["dispatch","relay","wreck-recovered","next-signal","survey-complete"]
const BRANCHES: Array[String] = ["sonar","hull","torpedo_acceleration","torpedo_area","engine"]
const PRICING: ResearchTree = preload("res://resources/campaign/research_tree.tres")
static func fresh() -> Dictionary:
	return {"ranks":{"sonar":0,"hull":0,"torpedo_acceleration":0,"torpedo_area":0,"engine":0},"legacy_ranks":{"sonar":0,"hull":0},"awards":["commission"],"messages":[],"decoded":false,"science":ResearchExperienceData.fresh()}
static func earned(data: Dictionary) -> int:
	return (2 if "commission" in data.awards else 0)+(1 if "outer-survey" in data.awards else 0)+(1 if "wreck-decoded" in data.awards else 0)+(2 if "twilight-expedition" in data.awards else 0)+(1 if "twilight-specimen" in data.awards else 0)+ResearchExperienceData.points(data.science)
static func legacy_count(data: Dictionary) -> int:
	return int(data.legacy_ranks.sonar)+int(data.legacy_ranks.hull)
static func new_count(data: Dictionary) -> int:
	var count: int = 0
	for branch: String in BRANCHES: count += int(data.ranks[branch])
	return count-legacy_count(data)
static func next_cost(data: Dictionary) -> int:
	return PRICING.first_rank_cost if new_count(data)==0 else PRICING.rank_cost
static func spent(data: Dictionary) -> int:
	var count: int = new_count(data)
	return legacy_count(data)+(PRICING.first_rank_cost+(count-1)*PRICING.rank_cost if count>0 else 0)
static func available(data: Dictionary) -> int:
	return earned(data)-spent(data)
static func refund_cost(data: Dictionary,branch: String) -> int:
	if branch not in BRANCHES or data.ranks[branch]<=0: return 0
	var next: Dictionary = data.duplicate(true)
	if branch in ["sonar","hull"] and next.ranks[branch]==next.legacy_ranks[branch]: next.legacy_ranks[branch] -= 1
	next.ranks[branch] -= 1
	return spent(data)-spent(next)
static func _ids(value: Variant, allowed: Array[String]) -> bool:
	if not value is Array or value.size()>allowed.size(): return false
	var seen: Array[String] = []
	for id: Variant in value:
		if not id is String or id not in allowed or id in seen: return false
		seen.append(id)
	return true
static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size()!=6 or not data.get("ranks") is Dictionary or data.ranks.size()!=BRANCHES.size() or not data.get("decoded") is bool or not ResearchExperienceData.valid(data.get("science")) or not data.get("legacy_ranks") is Dictionary or data.legacy_ranks.size()!=2: return false
	for branch: String in BRANCHES:
		if not InputBindings.is_integer(data.ranks.get(branch)) or data.ranks[branch]<0 or data.ranks[branch]>3: return false
	for branch: String in ["sonar","hull"]:
		if not InputBindings.is_integer(data.legacy_ranks.get(branch)) or data.legacy_ranks[branch]<0 or data.legacy_ranks[branch]>data.ranks[branch]: return false
	if not _ids(data.get("awards"),AWARDS) or not _ids(data.get("messages"),MESSAGES) or "commission" not in data.awards: return false
	return available(data)>=0 and bool(data.decoded)==("wreck-decoded" in data.awards)
static func migrate_previous(old: Variant) -> Dictionary:
	# Version-7 and earlier allocations retain their effects and original paid cost.
	if not old is Dictionary or old.size()!=5 or not old.get("ranks") is Dictionary or old.ranks.size()!=2 or not old.get("decoded") is bool or not ResearchExperienceData.valid(old.get("science")): return {}
	for branch: String in ["sonar","hull"]:
		if not InputBindings.is_integer(old.ranks.get(branch)) or old.ranks[branch]<0 or old.ranks[branch]>3: return {}
	if not _ids(old.get("awards"),AWARDS) or not _ids(old.get("messages"),MESSAGES) or "commission" not in old.awards or bool(old.decoded)!=("wreck-decoded" in old.awards) or int(old.ranks.sonar)+int(old.ranks.hull)>earned(old): return {}
	var data: Dictionary = fresh()
	for key: String in ["awards","messages","decoded","science"]: data[key] = old[key]
	for branch: String in ["sonar","hull"]:
		data.ranks[branch] = int(old.ranks[branch])
		data.legacy_ranks[branch] = int(old.ranks[branch])
	return data
static func migrate(progress: Dictionary) -> Dictionary:
	var data: Dictionary = fresh()
	data.science = ResearchExperienceData.reconcile(data.science,progress.research)
	data.ranks.sonar = 1 if "sonar-range-1200" in progress.upgrades else 0
	data.ranks.hull = 1 if "pressure-hull-400" in progress.upgrades else 0
	data.legacy_ranks = {"sonar":data.ranks.sonar,"hull":data.ranks.hull}
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
	for id: String in previous.science.credited:
		if id not in candidate.science.credited: return false
	for id: String in previous.science.imported:
		if id not in candidate.science.credited and id not in candidate.science.imported: return false
	return not previous.decoded or candidate.decoded
static func merge_earned(restored: Dictionary, current: Dictionary) -> Dictionary:
	var result: Dictionary = restored.duplicate(true)
	for key: String in ["awards","messages"]:
		for id: String in current[key]:
			if id not in result[key]: result[key].append(id)
	result.decoded = bool(restored.decoded) or bool(current.decoded)
	result.science = ResearchExperienceData.merge(restored.science,current.science)
	return result
static func normalized(data: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	for branch: String in BRANCHES: result.ranks[branch] = int(result.ranks[branch])
	for branch: String in ["sonar","hull"]: result.legacy_ranks[branch] = int(result.legacy_ranks[branch])
	return result
