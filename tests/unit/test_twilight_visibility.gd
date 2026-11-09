extends GutTest
func test_wavefront_arrival_range_and_fade() -> void:
	var rules: TwilightVisibilityProfile = TwilightVisibilityProfile.new()
	assert_true(rules.is_valid())
	for steps: int in [30,60,120]:
		var age: float = 0
		for tick: int in range(steps): age += 1.0/steps
		assert_almost_eq(TwilightVisibilityProfile.echo_strength(300,age+0.000000001,300,600,2),1.0,0.00001)
	assert_eq(TwilightVisibilityProfile.echo_strength(300,0.99,300,600,2),0.0)
	assert_eq(TwilightVisibilityProfile.echo_strength(601,8,300,600,2),0.0)
	assert_eq(TwilightVisibilityProfile.echo_strength(300,2,300,600,2),0.5)
	assert_eq(TwilightVisibilityProfile.echo_strength(300,3,300,600,2),0.0)
func test_quiet_navigation_and_invalid_configuration() -> void:
	var rules: TwilightVisibilityProfile = TwilightVisibilityProfile.new()
	assert_gt(rules.close_strength(rules.safety_radius/2),0.0)
	assert_eq(rules.close_strength(rules.safety_radius),0.0)
	rules.safety_radius = rules.passive_radius
	assert_false(rules.is_valid())
	rules.safety_radius *= 2
	rules.reveal_seconds = -1
	assert_false(rules.is_valid())
func test_darkness_preference_roundtrip_and_legacy_defaults() -> void:
	var settings: SettingsStore = SettingsStore.new()
	var next: Dictionary = settings.snapshot().accessibility
	assert_false(next.has("darkness"))
	next.darkness = "reduced"
	assert_eq(settings.set_accessibility(next),OK)
	var path: String = "user://bta057-preference.json"
	assert_eq(settings.save_settings(path),OK)
	var restored: SettingsStore = SettingsStore.new()
	assert_eq(restored.load_settings(path),OK)
	assert_eq(restored.snapshot().accessibility.darkness,"reduced")
	next.darkness = "invalid"
	assert_eq(restored.set_accessibility(next),ERR_INVALID_PARAMETER)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
