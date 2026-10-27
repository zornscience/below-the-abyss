extends GutTest
func _choice(id: String, amount: int, exceptional: bool = false) -> ChoiceData:
	var data: ChoiceData = ChoiceData.new()
	data.stable_id = StringName(id)
	data.encounter_id = StringName(id+"-encounter")
	data.resonance_delta = amount
	data.exceptional_weight = exceptional
	data.flags = [StringName(id+"-flag")]
	data.action_text = "Test decision"
	data.response_text = "Authored response."
	return data
func _state(catalog: StoryChoiceCatalog = StoryState.CATALOG) -> StoryState:
	var state: StoryState = StoryState.new()
	add_child_autofree(state)
	assert_eq(state.configure(catalog),OK)
	return state
func test_fresh_state_is_zero_neutral_and_has_no_flags_or_decisions() -> void:
	var state: StoryState = _state()
	assert_eq(state.resonance(),0)
	assert_eq(state.tier(),StoryState.Tier.NEUTRAL)
	assert_eq(state.snapshot(),StoryState.fresh())
func test_all_provisional_tier_boundaries() -> void:
	for value: int in [-100,-41,-40]: assert_eq(StoryState.tier_for(value),StoryState.Tier.HOSTILE)
	for value: int in [-39,-1,0,1,39]: assert_eq(StoryState.tier_for(value),StoryState.Tier.NEUTRAL)
	for value: int in [40,41,100]: assert_eq(StoryState.tier_for(value),StoryState.Tier.LISTENER)
func test_authored_bloom_choices_are_valid_and_mutually_exclusive() -> void:
	assert_true(StoryState.CATALOG.is_valid())
	var state: StoryState = _state()
	watch_signals(state)
	assert_eq(state.apply_choice(LightBloomEncounter.OBSERVE),OK)
	assert_eq(state.resonance(),15)
	assert_true(state.has_flag(&"zone1-light-bloom-unharmed"))
	assert_eq(state.apply_choice(LightBloomEncounter.OBSERVE),ERR_ALREADY_EXISTS)
	assert_eq(state.apply_choice(LightBloomEncounter.COLLECT),ERR_ALREADY_EXISTS)
	assert_signal_emit_count(state,"resonance_changed",1)
	assert_signal_emit_count(state,"choice_applied",1)
	assert_signal_emit_count(state,"flag_changed",1)
	assert_signal_not_emitted(state,"tier_changed")
func test_negative_outcome_has_one_negative_effect() -> void:
	var state: StoryState = _state()
	assert_eq(state.apply_choice(LightBloomEncounter.COLLECT),OK)
	assert_eq(state.resonance(),-15)
	assert_false(state.has_flag(&"zone1-light-bloom-unharmed"))
	assert_true(state.has_flag(&"zone1-light-bloom-collected"))
func test_clamping_and_meaningful_tier_signals_with_distinct_choices() -> void:
	var catalog: StoryChoiceCatalog = StoryChoiceCatalog.new()
	for index: int in range(8): catalog.choices.append(_choice("up-"+str(index),15))
	for index: int in range(16): catalog.choices.append(_choice("down-"+str(index),-15))
	var state: StoryState = _state(catalog)
	watch_signals(state)
	for index: int in range(8): assert_eq(state.apply_choice(StringName("up-"+str(index))),OK)
	assert_eq(state.resonance(),100)
	assert_signal_emit_count(state,"tier_changed",1)
	for index: int in range(16): assert_eq(state.apply_choice(StringName("down-"+str(index))),OK)
	assert_eq(state.resonance(),-100)
	assert_signal_emit_count(state,"tier_changed",3)
	assert_true(StoryState.valid_snapshot(state.snapshot(),catalog))
func test_provisional_exceptional_weight_is_supported_without_future_zone_content() -> void:
	var ordinary: ChoiceData = _choice("ordinary",25)
	assert_false(ordinary.is_valid())
	var catalog: StoryChoiceCatalog = StoryChoiceCatalog.new()
	catalog.choices = [_choice("exceptional",25,true)]
	var state: StoryState = _state(catalog)
	assert_eq(state.apply_choice(&"exceptional"),OK)
	assert_eq(state.resonance(),25)
	catalog.choices[0].resonance_delta = 26
	assert_false(catalog.is_valid())
func test_invalid_authored_ids_and_duplicate_catalog_entries_reject() -> void:
	var catalog: StoryChoiceCatalog = StoryChoiceCatalog.new()
	catalog.choices = [_choice("one",15),_choice("one",-15)]
	assert_false(catalog.is_valid())
	catalog.choices = [_choice("UPPERCASE",15)]
	assert_false(catalog.is_valid())
	var state: StoryState = _state()
	assert_eq(state.apply_choice(&"unknown"),ERR_INVALID_PARAMETER)
	assert_eq(state.resonance(),0)
func test_failed_persistence_does_not_mutate_or_emit_rewards() -> void:
	var state: StoryState = _state()
	state.persistence_required = true
	watch_signals(state)
	assert_eq(state.apply_choice(LightBloomEncounter.COLLECT),ERR_UNAVAILABLE)
	state.checkpoint_writer = func(_data: Dictionary,_id: StringName) -> Error: return ERR_CANT_CREATE
	assert_eq(state.apply_choice(LightBloomEncounter.COLLECT),ERR_CANT_CREATE)
	assert_eq(state.snapshot(),StoryState.fresh())
	assert_signal_not_emitted(state,"choice_applied")
	assert_signal_not_emitted(state,"resonance_changed")
func test_port_receives_candidate_before_exposure_and_reentrancy_is_rejected() -> void:
	var state: StoryState = _state()
	state.checkpoint_writer = func(candidate: Dictionary,id: StringName) -> Error:
		assert_eq(state.resonance(),0)
		assert_eq(candidate.resonance,15)
		assert_eq(id,LightBloomEncounter.OBSERVE)
		assert_eq(state.apply_choice(LightBloomEncounter.COLLECT),ERR_BUSY)
		return OK
	assert_eq(state.apply_choice(LightBloomEncounter.OBSERVE),OK)
func test_restore_is_validated_and_completely_silent() -> void:
	var state: StoryState = _state()
	state.apply_choice(LightBloomEncounter.OBSERVE)
	var saved: Dictionary = state.snapshot()
	var restored: StoryState = _state()
	watch_signals(restored)
	assert_eq(restored.restore(saved),OK)
	assert_eq(restored.resonance(),15)
	assert_signal_not_emitted(restored,"choice_applied")
	assert_signal_not_emitted(restored,"resonance_changed")
	assert_signal_not_emitted(restored,"tier_changed")
	assert_signal_not_emitted(restored,"flag_changed")
	assert_eq(restored.apply_choice(LightBloomEncounter.OBSERVE),ERR_ALREADY_EXISTS)
func test_malformed_inconsistent_duplicate_or_conflicting_snapshots_reject() -> void:
	for bad: Variant in [null,{}, {"resonance":101,"flags":[],"decisions":[]}, {"resonance":true,"flags":[],"decisions":[]}, {"resonance":15,"flags":[],"decisions":[]}, {"resonance":0,"flags":["unknown"],"decisions":[]}, {"resonance":0,"flags":[],"decisions":["unknown"]}]:
		assert_false(StoryState.valid_snapshot(bad))
	var state: StoryState = _state()
	state.apply_choice(LightBloomEncounter.OBSERVE)
	var bad: Dictionary = state.snapshot()
	bad.decisions.append(String(LightBloomEncounter.COLLECT))
	assert_false(StoryState.valid_snapshot(bad))
	bad = state.snapshot()
	bad.flags.append(bad.flags[0])
	assert_false(StoryState.valid_snapshot(bad))
func test_validated_extra_flag_api_does_not_change_resonance_or_repeat() -> void:
	var catalog: StoryChoiceCatalog = StoryState.CATALOG.duplicate(true) as StoryChoiceCatalog
	catalog.extra_flags = [&"test-visited"]
	var state: StoryState = _state(catalog)
	assert_eq(state.set_flag(&"test-visited"),OK)
	assert_eq(state.set_flag(&"test-visited"),ERR_ALREADY_EXISTS)
	assert_eq(state.set_flag(&"unknown"),ERR_INVALID_PARAMETER)
	assert_eq(state.set_flag(&"zone1-light-bloom-collected"),ERR_INVALID_PARAMETER)
	assert_eq(state.resonance(),0)
func test_history_merge_preserves_decisions_and_refuses_opposite_branches() -> void:
	var positive: StoryState = _state()
	positive.apply_choice(LightBloomEncounter.OBSERVE)
	var negative: StoryState = _state()
	negative.apply_choice(LightBloomEncounter.COLLECT)
	assert_eq(StoryState.merge_snapshots(positive.snapshot(),StoryState.fresh()).data,positive.snapshot())
	assert_eq(StoryState.merge_snapshots(positive.snapshot(),negative.snapshot()).error,ERR_BUSY)
	assert_false(StoryState.extends_history(StoryState.fresh(),positive.snapshot()))
func test_live_restore_cannot_erase_an_applied_decision_to_replay_it() -> void:
	var state: StoryState = _state()
	state.apply_choice(LightBloomEncounter.OBSERVE)
	watch_signals(state)
	assert_eq(state.restore(StoryState.fresh()),ERR_BUSY)
	assert_eq(state.resonance(),15)
	assert_eq(state.apply_choice(LightBloomEncounter.OBSERVE),ERR_ALREADY_EXISTS)
	assert_signal_not_emitted(state,"choice_applied")
