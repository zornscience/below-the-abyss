extends GutTest
var rig: SonarTestRig
func before_each() -> void:
	rig = SonarTestRig.new()
	add_child_autofree(rig)
	rig.sonar.reflection_preferences = func() -> Dictionary: return SettingsStore.default_accessibility()
func test_target_echo_waits_for_wavefront_then_returns_without_extra_dispatch_or_cost() -> void:
	rig.target(&"echo-target",Vector2(50,0))
	assert_eq(rig.sonar.request_ping(),OK)
	rig.sonar.advance(0.499)
	assert_eq(rig.sonar._returns.size(),0)
	rig.sonar.advance(0.001)
	assert_eq(rig.sonar._returns.size(),1)
	var echo: SonarReflection = rig.sonar._returns[0]
	assert_eq(echo.global_position,Vector2(50,0))
	rig.sonar.advance(0.25)
	assert_almost_eq(echo.global_position.x,25.0,0.001)
	assert_eq(rig.bus.history_count(),1)
	assert_eq(rig.resources.battery,96.0)
	rig.sonar.reset_session()
	assert_true(echo.is_queued_for_deletion())
	assert_eq(rig.sonar._returns.size(),0)
	assert_eq(rig.bus.history_count(),1)
func test_return_positions_match_at_30_60_120_steps() -> void:
	for rate: int in [30,60,120]:
		rig.sonar.reset_session()
		rig.sonar._reflection_started(Vector2(80,0),0,100)
		var echo: SonarReflection = rig.sonar._returns[0]
		for step: int in range(rate/2): echo.advance(1.0/rate)
		assert_almost_eq(echo.global_position.x,30.0,0.0001)
func test_reduced_particles_suppresses_returns_and_reduced_motion_uses_static_feedback() -> void:
	var prefs: Dictionary = SettingsStore.default_accessibility()
	prefs.reduced_particles = true
	rig.sonar.reflection_preferences = func() -> Dictionary: return prefs
	rig.sonar._reflection_started(Vector2(50,0),0,100)
	assert_eq(rig.sonar._returns.size(),0)
	prefs.reduced_particles = false
	prefs.reduced_motion = true
	rig.sonar._reflection_started(Vector2(50,0),0,100)
	var echo: SonarReflection = rig.sonar._returns[0]
	echo.advance(0.2)
	assert_eq(echo.global_position,Vector2(50,0))
	assert_true(echo.reduced)
func test_removed_receiver_cleans_echo_without_writing_acoustic_history() -> void:
	var receiver: Node2D = Node2D.new()
	add_child(receiver)
	var echo: SonarReflection = SonarReflection.new()
	add_child_autofree(echo)
	echo.configure(Vector2(100,0),receiver,100,false)
	receiver.free()
	echo.advance(0.1)
	assert_true(echo.is_queued_for_deletion())
	assert_eq(rig.bus.history_count(),0)

func test_expired_freed_echoes_are_pruned_before_next_reflection_and_memory_is_bounded() -> void:
	rig.sonar._reflection_started(Vector2(80,0),0,100)
	rig.sonar._returns[0].free()
	rig.sonar._reflection_started(Vector2(90,0),0,100)
	assert_eq(rig.sonar._returns.size(),1)
	for index: int in range(40): rig.sonar._reflection_started(Vector2(100+index,0),0,100)
	assert_eq(rig.sonar._returns.size(),32)
	assert_eq(rig.bus.history_count(),0)
