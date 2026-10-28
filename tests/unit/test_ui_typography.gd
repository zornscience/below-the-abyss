extends GutTest

func test_semantic_hierarchy_and_distinct_scales() -> void:
	assert_eq(UiTypography.size_for(&"menu_button"),17)
	assert_eq(UiTypography.size_for(&"body"),16)
	assert_eq(UiTypography.size_for(&"heading"),20)
	assert_eq(UiTypography.size_for(&"dialog_button"),16)
	for role: StringName in [&"body",&"heading",&"menu_button",&"hud"]:
		assert_lt(UiTypography.size_for(role,"compact"),UiTypography.size_for(role))
		assert_gt(UiTypography.size_for(role,"large"),UiTypography.size_for(role))
		assert_gte(UiTypography.size_for(role,"compact"),14)
	assert_lt(UiTypography.size_for(&"title","standard",800),UiTypography.size_for(&"title","standard",1280))

func test_scaling_does_not_accumulate_and_popup_matches_button() -> void:
	var button: OptionButton = OptionButton.new()
	add_child_autofree(button)
	UiTypography.style(button,&"body")
	for unused: int in range(3):
		for scale_name: String in ["large","compact","standard"]:
			UiTypography.apply(button,scale_name)
			assert_eq(button.get_theme_font_size("font_size"),UiTypography.size_for(&"body",scale_name))
			assert_eq(button.get_popup().get_theme_font_size("font_size"),button.get_theme_font_size("font_size"))

func test_wrapped_footer_actions_retain_real_width() -> void:
	var flow: HFlowContainer = HFlowContainer.new()
	add_child_autofree(flow)
	flow.size.x = 700
	var button: Button = Button.new()
	button.text = "Return to map"
	flow.add_child(button)
	UiTypography.apply(button,"standard")
	await wait_process_frames(3)
	assert_gt(button.size.x,100.0,"Wrapped footer actions cannot collapse into one-character vertical strips.")
	assert_lte(button.size.x,flow.size.x)

func test_dialog_bounds_preserve_margins_at_each_resolution() -> void:
	for dimensions: Vector2 in [Vector2(800,600),Vector2(1280,800),Vector2(1920,1080)]:
		var rect: Rect2 = UiDialogLayout.bounds(dimensions,Vector2(760,480))
		assert_true(Rect2(Vector2(24,32),dimensions-Vector2(48,64)).encloses(rect))
		assert_eq(rect.get_center(),dimensions*0.5)
		assert_lte(rect.size.x,760.0)
		assert_lte(rect.size.y,480.0)
