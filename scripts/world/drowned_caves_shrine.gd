class_name DrownedCavesShrine
extends Node2D
## DC-5: the Vael memory crystal shrine in the far chamber. One exclusive choice (a story encounter, so
## it is saved atomically with its Resonance and flags): leave the crystal, or take it for Tethys. The
## taker's calibration is derived from the saved decision (ExpeditionRevision.capabilities), so there is
## no award to desync. The shrine's collapse is drawn, never solid, so the choice cannot block a route.
## PLACEHOLDER ART in plain shapes; all text is a draft for the designer to edit.
var scene: ShelfPrototype
var journey: ChapterJourney
var enabled: bool = false
var _contrast: bool = false
func setup(game: ShelfPrototype,owner_journey: ChapterJourney) -> void:
	scene = game
	journey = owner_journey
	z_index = 1
	scene.story.choice_applied.connect(_decided)
	scene.settings.settings_changed.connect(_preferences)
	_preferences()
	set_enabled(false)
func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	queue_redraw()
func resolved() -> bool:
	return scene.story.resolved(DrownedCavesData.CRYSTAL_ENCOUNTER)
func taken() -> bool:
	return scene.story.has_decision(DrownedCavesData.CRYSTAL_TAKE)
func near_shrine() -> bool:
	return enabled and scene.submarine.global_position.distance_to(DrownedCavesData.shrine_at())<=DrownedCavesData.SHRINE_RADIUS
func prompt() -> String:
	if not near_shrine(): return ""
	var binding: String = scene.input_context.describe(&"interact")
	return binding+" · "+("Review the shrine" if resolved() else "Examine the crystal and decide")
## Interact beside the shrine. Returns true when it handled the press.
func interact() -> bool:
	if not near_shrine(): return false
	_pause()
	if resolved(): _show_response()
	else:
		scene.revision.ui.show_story_page(DrownedCavesData.SHRINE_TITLE,DrownedCavesData.SHRINE_TEXT,"Leave the crystal in its niche",_leave_crystal,&"LeaveCrystal",_close)
		scene.revision.ui.add_story_option("Take the crystal for Tethys",_confirm_take,&"TakeCrystal")
	return true
func _pause() -> void:
	scene.submarine.velocity = Vector2.ZERO
	scene.submarine.set_simulation_enabled(false)
	scene.revision.ui.notifications.collapse()
func _close() -> void:
	scene.revision.ui.radio_page.hide()
	scene.resume_route()
func _confirm_take() -> void:
	scene.revision.ui.show_story_page("CONFIRM / TAKE THE CRYSTAL",DrownedCavesData.TAKE_CONFIRM_TEXT % DrownedCavesData.CALIBRATION.sonar_range_bonus,"Take the crystal",_take_crystal,&"ConfirmTake",_close)
func _leave_crystal() -> void:
	_choose(DrownedCavesData.CRYSTAL_LEAVE)
func _take_crystal() -> void:
	_choose(DrownedCavesData.CRYSTAL_TAKE)
func _choose(id: StringName) -> void:
	if not near_shrine() or resolved():
		_close()
		return
	var result: Error = scene.story.apply_choice(id)
	if result!=OK:
		scene.revision.ui.add_story_notice("The decision was not recorded. Nothing changed. Recover the checkpoint and try again.")
func _decided(_id: StringName,encounter: StringName) -> void:
	if encounter!=DrownedCavesData.CRYSTAL_ENCOUNTER: return
	scene.upgrades.reapply()
	queue_redraw()
	journey.refresh()
	if enabled:
		_pause()
		_show_response()
func _show_response() -> void:
	var id: StringName = DrownedCavesData.CRYSTAL_TAKE if taken() else DrownedCavesData.CRYSTAL_LEAVE
	scene.revision.ui.show_story_page("THE SHRINE",scene.story.definition(id).response_text,"Return to piloting",_close,&"ReturnFromShrine",_close)
func _preferences() -> void:
	_contrast = bool(scene.settings.snapshot().accessibility.get("high_contrast",false))
	queue_redraw()
# ---------------------------------------------------------------- placeholder art
func _draw() -> void:
	var at: Vector2 = DrownedCavesData.shrine_at()
	var stone: Color = Color(0.62,0.66,0.64,0.95) if _contrast else Color(0.42,0.46,0.45,0.9)
	var width: float = 5.0 if _contrast else 3.0
	if scene!=null and taken():
		# The collapse: rubble over the niche. Drawn only; it has no collision.
		for index: int in range(9):
			var piece: Vector2 = at+Vector2(-120.0+index*30.0,60.0-absf(index-4.0)*18.0)
			draw_colored_polygon(PackedVector2Array([piece+Vector2(-22,18),piece+Vector2(-6,-20),piece+Vector2(24,-4),piece+Vector2(18,20)]),stone)
		return
	# A niche (an arch over a pedestal) with the crystal and a ring, so it reads without colour.
	draw_arc(at+Vector2(0,40),110.0,PI,TAU,28,stone,width)
	draw_line(at+Vector2(-110,40),at+Vector2(-110,120),stone,width)
	draw_line(at+Vector2(110,40),at+Vector2(110,120),stone,width)
	draw_rect(Rect2(at+Vector2(-70,100),Vector2(140,26)),Color(stone,0.8))
	var glow: Color = Color(1,1,1,0.9) if _contrast else Color(0.55,0.95,0.85,0.9)
	draw_circle(at+Vector2(0,20),90.0,Color(glow,0.10))
	draw_colored_polygon(PackedVector2Array([at+Vector2(0,-40),at+Vector2(26,20),at+Vector2(0,80),at+Vector2(-26,20)]),Color(glow,0.85))
	draw_arc(at+Vector2(0,20),64.0,0.0,TAU,28,glow,width)
