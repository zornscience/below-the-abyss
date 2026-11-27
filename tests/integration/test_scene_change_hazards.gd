extends GutTest
## Deferred UI callbacks must tolerate a scene change that takes the scene out of the tree in
## the same frame. Unguarded, they dereference a null tree or viewport: a script error here,
## a segfault in a release export (reproduced on a real Linux export before this fix).
## Release proof: ReleaseSmoke._arm_scene_change_hazards before the combat-box scene change.
const MAIN: PackedScene = preload("res://scenes/main/main.tscn")
var game: ShelfPrototype
var path: String


func before_each() -> void:
	InputBindings.apply(InputBindings.defaults(),0.25)
	path = "user://scene-change-hazards-%d.json" % Time.get_ticks_usec()
	game = MAIN.instantiate() as ShelfPrototype
	game.settings_path = path
	game.expedition_path = path+".expedition.json"
	add_child_autofree(game)
	await wait_physics_frames(3)
	game.chapter.start()
	game.chapter.launch()
	game.revision.ui.title_page.hide()
	game.route_layer.hide()
	game.resume_route()
	await wait_physics_frames(2)


func after_each() -> void:
	for action: StringName in InputBindings.ACTIONS+InputBindings.MENU_ACTIONS: Input.action_release(action)
	await get_tree().process_frame
	for stem: String in ["", ".expedition.json", ".discoveries.json", ".research.json", ".missions.json", ".upgrades.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".invalid", ".rejected"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path+stem+suffix))


## Queue each hazard, then leave the tree in the same frame, as a scene change does.
func _arm_then_leave_tree() -> void:
	game.submarine.set_simulation_enabled(true)
	game.submarine.set_simulation_enabled(false)
	game.accessibility_service.queue_apply()
	game.revision.ui.show_story_page("TEST","Scene-change hazard check.","Continue",func() -> void: pass,&"SceneChangeHazard",func() -> void: pass)
	game.revision.ui.radio_page.hide()
	game.submarine.hull_system.apply_damage(game.submarine.hull_system.hull,&"collision")
	remove_child(game)
	assert_false(game.is_inside_tree(),"precondition: the scene has left the tree")
	for frame: int in range(4): await get_tree().process_frame


func test_deferred_ui_callbacks_survive_leaving_the_tree_in_the_same_frame() -> void:
	await _arm_then_leave_tree()
	# Any null dereference above is an unexpected error, which fails this test.
	assert_false(game.journey.recovery.pending,"no recovery starts for a scene that has left the tree")
	assert_true(is_instance_valid(game),"the scene is intact and can be freed normally")


func test_the_same_callbacks_still_run_while_the_scene_is_in_the_tree() -> void:
	# Positive control: the guards skip only out-of-tree work. In the tree, a hull failure still
	# triggers recovery, and the tutorial card is laid out from the live viewport.
	game.submarine.hull_system.apply_damage(game.submarine.hull_system.hull,&"collision")
	for frame: int in range(4): await get_tree().process_frame
	assert_true(game.journey.recovery.pending,"recovery still starts in the tree")
	game.tutorial_card.size = Vector2.ZERO
	game.submarine.set_simulation_enabled(false)  # queues the deferred tutorial layout
	await get_tree().process_frame
	assert_gt(game.tutorial_card.size.x,0.0,"tutorial layout still runs in the tree")
