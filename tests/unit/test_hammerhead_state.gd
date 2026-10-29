extends GutTest
const PROFILE: PredatorProfile = preload("res://resources/creatures/sunlit_hammerhead.tres")

func test_visual_warning_holds_motion_and_cannot_damage_before_pursuit() -> void:
	var state: PredatorState = PredatorState.new()
	assert_eq(state.configure(PROFILE),OK)
	state.set_target(Vector2(18880,910),true)
	state.advance(0,Vector2(18800,910))
	assert_eq(state.phase,PredatorState.Phase.ALERT)
	assert_eq(state.speed(),0.0)
	assert_eq(state.contact_cost(40,true),0.0)
	state.advance(2.5,Vector2(18800,910))
	assert_eq(state.phase,PredatorState.Phase.PURSUE)
	assert_eq(state.contact_cost(40,true),6.0)
	assert_eq(state.contact_cost(40,true),0.0)
	assert_eq(state.contact_cost(40,false),0.0)

func test_obscured_targets_and_targets_outside_optional_lagoon_do_not_trigger() -> void:
	var state: PredatorState = PredatorState.new()
	state.configure(PROFILE)
	state.set_target(Vector2(18880,910),true,false)
	state.advance(0.5,Vector2(18800,910))
	assert_eq(state.phase,PredatorState.Phase.QUIET)
	state.set_target(Vector2(18880,400),true)
	state.advance(0.5,Vector2(18800,910))
	assert_eq(state.phase,PredatorState.Phase.QUIET)

func test_ram_budget_and_escape_match_30_60_120_steps() -> void:
	var totals: Array[float] = []
	for rate: int in [30,60,120]:
		var state: PredatorState = PredatorState.new()
		state.configure(PROFILE)
		state.set_target(Vector2(18880,910),true)
		state.advance(0,Vector2(18800,910))
		var damage: float = 0
		for step: int in range(rate*5):
			state.advance(1.0/rate,Vector2(18800,910))
			damage += state.contact_cost(40,true)
		totals.append(damage)
		state.set_target(Vector2(18880,400),true)
		state.advance(1.0/rate,Vector2(18800,910))
		assert_eq(state.phase,PredatorState.Phase.DISENGAGE)
		assert_eq(state.contact_cost(40,true),0.0)
	assert_eq(totals,[12.0,12.0,12.0])
