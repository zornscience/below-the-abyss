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
	caption.add_theme_font_size_override("font_size",18)
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
	if _scene.station.is_in_range(_scene.submarine.global_position):
		text = binding+" · Dock at Shelf Base"
	elif state.active_id != &"":
		text = "SCANNING %.0f%% · %s cancel" % [state.progress*100.0,binding]
	elif _scene.submarine.scanner.candidate_id() != &"":
		text = binding+" · Scan "+_scene.research.definition(_scene.submarine.scanner.candidate_id()).title
	elif _scene.submarine.scanner._feedback_seconds > 0.0 and not state.text.begins_with("SCANNER"):
		text = state.text.get_slice(" · ",0)
	caption.text = text
	visible = not text.is_empty() and _scene.submarine.is_physics_processing()
	var viewport_size: Vector2 = get_viewport_rect().size
	size = Vector2(minf(480.0,viewport_size.x-48.0),get_combined_minimum_size().y)
	position = Vector2((viewport_size.x-size.x)*0.5,(_scene.hud.get_node("%InstrumentDeck") as Control).get_global_rect().position.y-get_combined_minimum_size().y-42.0)
