class_name DrownedCavesSite
extends Node2D
## DC-4: the first-contact site in the far chamber. Registers the four cave records with the real scan
## gate (each scan is an atomic checkpoint, as in Twilight), shows each record's text when it is
## scanned, lists completed records in the expedition log, and draws PLACEHOLDER art for the paintings,
## the glyph wall and the recorders. The art is plain shapes drawn in code: no asset was invented, and it
## awaits the designer's art direction. Progress lives in the existing research list; there is no mission.
var scene: ShelfPrototype
var journey: ChapterJourney
var enabled: bool = false
var _previous_gate: Callable
var _contrast: bool = false
func setup(game: ShelfPrototype,owner_journey: ChapterJourney) -> void:
	scene = game
	journey = owner_journey
	z_index = 1
	_previous_gate = scene.research.completion_gate
	scene.research.completion_gate = _scan_gate
	scene.research.scan_completed.connect(_scanned)
	scene.settings.settings_changed.connect(_preferences)
	_preferences()
	set_enabled(false)
func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	for id: StringName in DrownedCavesData.ids():
		var target: ScientificScanTarget = scene.region.get_node_or_null(String(id)) as ScientificScanTarget
		if target!=null: target.scan_enabled = value
func is_required_done() -> bool:
	return scene.research.is_completed(DrownedCavesData.REQUIRED)
func _scan_gate(id: StringName) -> Error:
	if not DrownedCavesData.knows(id): return _previous_gate.call(id) if _previous_gate.is_valid() else OK
	if not enabled or not scene.submarine.scanner._in_range(id): return ERR_UNAVAILABLE
	var proposed: Array[StringName] = scene.research.completed_ids()
	proposed.append(id)
	return scene.saves.commit_research_checkpoint(proposed)
func _scanned(id: StringName) -> void:
	if not enabled or not DrownedCavesData.knows(id): return
	var item: Dictionary = DrownedCavesData.record(id)
	scene.revision.ui.notifications.enqueue(String(id),String(item.text),String(item.source))
	queue_redraw()
	journey.refresh()
## Completed records as expedition-log entries, so they appear in the dock log at Halcyon too.
func entries() -> Array[NarrativeEntry]:
	var result: Array[NarrativeEntry] = []
	for item: Dictionary in DrownedCavesData.records():
		if not scene.research.is_completed(StringName(item.id)): continue
		var entry: NarrativeEntry = NarrativeEntry.new()
		entry.stable_id = StringName(item.id)
		entry.title = item.title
		entry.text = item.text
		result.append(entry)
	return result
func _preferences() -> void:
	_contrast = bool(scene.settings.snapshot().accessibility.get("high_contrast",false))
	queue_redraw()
# ---------------------------------------------------------------- placeholder art
func _draw() -> void:
	var pale: Color = Color(1,1,1,0.95) if _contrast else Color(0.78,0.86,0.82,0.85)
	var glow: Color = Color(0.55,0.95,0.85,0.9)
	var width: float = 5.0 if _contrast else 3.0
	var paintings: Vector2 = DrownedCavesData.record(DrownedCavesData.PAINTINGS).at
	# Handprints: a palm and four fingers, in a loose row under the figures.
	for index: int in range(7):
		var hand: Vector2 = paintings+Vector2(-420.0+index*140.0,130.0+(index%2)*30.0)
		draw_circle(hand,26.0,Color(pale,0.55))
		for finger: int in range(4):
			draw_circle(hand+Vector2(-21.0+finger*14.0,-34.0-(finger%3)*5.0),8.0,Color(pale,0.55))
	# Two tall figures with a faint glow, and a smaller group facing them.
	for figure: Vector2 in [paintings+Vector2(-200.0,-40.0),paintings+Vector2(200.0,-40.0)]:
		draw_circle(figure,120.0,Color(glow,0.10))
		draw_arc(figure+Vector2(0,-120.0),30.0,0.0,TAU,24,glow,width)
		draw_line(figure+Vector2(0,-90.0),figure+Vector2(0,110.0),glow,width)
		draw_line(figure+Vector2(-70.0,-30.0),figure+Vector2(70.0,-30.0),glow,width)
	for index: int in range(3):
		var small: Vector2 = paintings+Vector2(-40.0+index*40.0,60.0)
		draw_arc(small+Vector2(0,-32.0),10.0,0.0,TAU,16,pale,width)
		draw_line(small+Vector2(0,-22.0),small+Vector2(0,30.0),pale,width)
	# The glyph wall: three distinct marks (a line, a ring and a stroke pair) repeated in rows.
	var wall: Vector2 = DrownedCavesData.record(DrownedCavesData.GLYPH_WALL).at
	for row: int in range(3):
		for column: int in range(6):
			var at: Vector2 = wall+Vector2(-300.0+column*120.0,-60.0+row*70.0)
			match (row+column)%3:
				0: draw_line(at+Vector2(0,-24.0),at+Vector2(0,24.0),glow,width)
				1: draw_arc(at,18.0,0.0,TAU,20,glow,width)
				2:
					draw_line(at+Vector2(-18.0,-18.0),at+Vector2(18.0,18.0),glow,width)
					draw_line(at+Vector2(18.0,-18.0),at+Vector2(-18.0,18.0),glow,width)
	# Mara's two recorders: a small case with a ring, so they read as objects, not decoration.
	for id: StringName in [DrownedCavesData.MARA_LOG_ONE,DrownedCavesData.MARA_LOG_TWO]:
		var at: Vector2 = DrownedCavesData.record(id).at
		var done: bool = scene!=null and scene.research.is_completed(id)
		draw_rect(Rect2(at-Vector2(22,14),Vector2(44,28)),Color(pale,0.35 if done else 0.8))
		draw_arc(at,40.0,0.0,TAU,28,Color(glow,0.5 if done else 0.95),width)
