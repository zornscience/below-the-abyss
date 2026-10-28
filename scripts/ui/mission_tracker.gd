class_name MissionTracker
extends PanelContainer
## Projection of accepted mission/domain facts. Never owns progress or rewards.
var scene: ShelfPrototype
var title: Label
var detail: Label
func setup(value: ShelfPrototype) -> void:
	scene = value
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	theme = preload("res://resources/balance/instrument_theme.tres")
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	title = Label.new()
	detail = Label.new()
	for label: Label in [title,detail]:
		UiTypography.style(label,&"hud")
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.max_lines_visible = 3
		column.add_child(label)
	scene.missions.missions_changed.connect(refresh)
	scene.missions.records_restored.connect(refresh)
	scene.narrative.log_changed.connect(refresh)
	refresh()
func refresh() -> void:
	if scene==null: return
	var chapter: SunlitShallows = scene.chapter
	if chapter!=null and chapter.active:
		visible = chapter.state()!="available"
		title.text = "◇ THE SUNLIT SHALLOWS"
		var text: String
		if chapter.concluded(): text = "✓ Complete · Twilight Shelf is not yet playable"
		elif chapter.can_debrief(): text = "◇ Dock and submit expedition debrief"
		elif not scene.story.resolved(LightBloomEncounter.ENCOUNTER): text = "◇ Study the geometric light bloom"
		elif not scene.research.is_completed(SunlitShallowsData.BUOY): text = "◇ Find and recover Lantern-1’s buoy"
		else: text = "◇ Return to Halcyon with the recording"
		detail.text = text
	else:
		var lines: PackedStringArray = []
		var records: Dictionary = scene.missions.snapshot()
		var definitions: Array[MissionDefinition] = scene.missions.definitions()
		definitions.sort_custom(_priority.bind(records))
		for definition: MissionDefinition in definitions:
			if definition.stable_id==SunlitShallowsData.MISSION: continue
			var record: Dictionary = records[String(definition.stable_id)]
			if record.state not in ["accepted","completed"]: continue
			if lines.size()>=2: break
			if record.state=="completed": lines.append("✓ "+definition.title+" · debrief at base")
			else:
				for objective: MissionObjective in definition.objectives:
					if String(objective.stable_id) not in record.objectives:
						lines.append(("○ " if definition.optional else "◇ ")+definition.title+" · "+objective.description)
						break
		title.text = "EXPEDITION"
		detail.text = "\n".join(lines) if not lines.is_empty() else ("✓ Expedition acknowledged" if scene.narrative.is_concluded() else "No accepted objectives · radio / station")
		visible = scene.submarine.is_physics_processing()
	_reflow()
func _process(_delta: float) -> void:
	if scene!=null:
		visible = scene.submarine.is_physics_processing()
		_reflow()
func _reflow() -> void:
	var viewport: Vector2 = get_viewport_rect().size
	var width: float = minf(340,viewport.x*0.34)-16
	size = Vector2(width,0)
	position = Vector2(viewport.x-width-16,16)

func _priority(a: MissionDefinition,b: MissionDefinition,records: Dictionary) -> bool:
	var left: bool = records[String(a.stable_id)].state=="accepted"
	var right: bool = records[String(b.stable_id)].state=="accepted"
	if left!=right: return left
	if a.optional!=b.optional: return not a.optional
	return String(a.stable_id)<String(b.stable_id)
