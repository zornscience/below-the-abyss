class_name PilotContext
extends PanelContainer
## Context-only interaction feedback; no persistent route directions or objective paragraphs.
var _scene: ShelfPrototype
var caption: Label
var progress: ProgressBar
func setup(scene: ShelfPrototype) -> void:
	_scene = scene
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = preload("res://resources/balance/instrument_theme.tres")
	var content: VBoxContainer = VBoxContainer.new()
	add_child(content)
	caption = Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.max_lines_visible = 3
	UiTypography.style(caption,&"hud")
	content.add_child(caption)
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.custom_minimum_size.y = 6
	content.add_child(progress)
	hide()
func _process(_delta: float) -> void:
	var state: Dictionary = _scene.submarine.scanner.snapshot()
	var text: String = ""
	var binding: String = _scene.input_context.describe(&"interact")
	progress.visible = state.active_id != &""
	progress.value = state.progress*100.0
	if _scene.journey!=null and not _scene.journey.hazard_prompt().is_empty():
		text = _scene.journey.hazard_prompt()
	elif _scene.journey!=null and not _scene.journey.expedition.prompt().is_empty():
		text = _scene.journey.expedition.prompt()
		progress.visible = _scene.journey.expedition.action!=&""
		progress.value = _scene.journey.expedition.elapsed/TwilightExpedition.ACTION_SECONDS*100.0
	elif _scene.journey!=null and not _scene.journey.caves_shrine.prompt().is_empty():
		text = _scene.journey.caves_shrine.prompt()
	elif _scene.journey!=null and _scene.journey.near_tether():
		text = binding+" · Return to Halcyon / refit"
	elif _scene.station.is_in_range(_scene.submarine.global_position):
		text = _scene._station_failure if _scene._station_failure_remaining>0.0 else (binding+" · Dock at Shelf Base" if _scene.station.can_interact(_scene.submarine) else _scene.station.docking_hint(_scene.submarine))
	elif state.active_id != &"":
		text = "SCANNING %.0f%% · %s cancel" % [state.progress*100.0,binding]
	elif _scene.chapter!=null and _scene.chapter.can_review_buoy():
		text = binding+(" · Review recording / finish chapter" if _scene.journey!=null and _scene.journey.can_finish() else " · Replay Mara’s archived buoy message")
	elif _scene.bloom!=null and _scene.bloom.in_range():
		text = _scene.bloom.prompt()
	elif _scene.submarine.scanner.candidate_id() != &"":
		text = binding+" · Scan "+_scene.research.definition(_scene.submarine.scanner.candidate_id()).title
	elif _scene.submarine.scanner._feedback_seconds > 0.0 and not state.text.begins_with("SCANNER"):
		text = state.text.get_slice(" · ",0)
	if _scene.chapter!=null and _scene.chapter.active: text = text.replace("Shelf Base","Halcyon Station").replace("NERIS","Lantern-2")

	caption.text = text
	visible = not text.is_empty() and _scene.submarine.is_physics_processing()
	var viewport_size: Vector2 = get_viewport_rect().size
	var width: float = minf(340,viewport_size.x*0.34)-16 if _scene.hud.quiet else minf(480.0,viewport_size.x-48.0)
	# Set one width per frame. Alternating wide/quiet sizes invalidates wrapping
	# before containers can sort and can leave a one-line prompt hundreds of pixels tall.
	size = Vector2(width,0)
	if _scene.hud.quiet:
		var tracker: Control = _scene.mission_tracker
		position = Vector2(viewport_size.x-width-16,tracker.get_global_rect().end.y+8 if tracker!=null else 180.0)
	else:
		position = Vector2((viewport_size.x-width)*0.5,(_scene.hud.get_node("%InstrumentDeck") as Control).get_global_rect().position.y-size.y-42.0)
