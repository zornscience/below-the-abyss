class_name StoryChoiceCatalog
extends Resource
@export var choices: Array[ChoiceData] = []
@export var extra_flags: Array[StringName] = []
func definition(id: StringName) -> ChoiceData:
	for choice: ChoiceData in choices:
		if choice.stable_id == id:
			return choice
	return null
func is_valid() -> bool:
	if choices.is_empty() or choices.size() > 256 or extra_flags.size() > 128:
		return false
	var ids: Array[StringName] = []
	var owners: Dictionary[StringName, StringName] = {}
	for choice: ChoiceData in choices:
		if choice == null or not choice.is_valid() or choice.stable_id in ids:
			return false
		ids.append(choice.stable_id)
		for flag: StringName in choice.flags:
			if owners.has(flag): return false
			owners[flag] = choice.stable_id
	var seen: Array[StringName] = []
	for flag: StringName in extra_flags:
		if not PointOfInterest.valid_id(flag) or owners.has(flag) or flag in seen:
			return false
		seen.append(flag)
	return true
