class_name ScientificDiscoveryPopup
extends PanelContainer
## Low-priority, bounded, simulation-time notification. Never takes focus or input.
var game: ShelfPrototype
var image: TextureRect
var caption: Label
var description: Label
var remaining: float = 0.0
var current_id: StringName
var _queue: Array[Dictionary] = []

func setup(scene: ShelfPrototype) -> void:
	game = scene
	theme = preload("res://resources/balance/instrument_theme.tres")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	var column: VBoxContainer = VBoxContainer.new()
	add_child(column)
	var row: HBoxContainer = HBoxContainer.new()
	column.add_child(row)
	image = TextureRect.new()
	image.custom_minimum_size = Vector2(76,64)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(image)
	caption = Label.new()
	UiTypography.style(caption,&"hud")
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	description = Label.new()
	UiTypography.style(description,&"body")
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 3
	column.add_child(description)
	for node: Control in [column,row,image,caption,description]: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

func show_record(id: StringName,award: int = 0) -> void:
	if not game.research.is_completed(id): return
	for record: Dictionary in _queue:
		if record.id==id: return
	if current_id==id and remaining>0: return
	if _queue.size()>=4: _queue.pop_front()
	_queue.append({"id":id,"award":award})

func _next() -> void:
	var record: Dictionary = _queue.pop_front()
	var entry: ScanDefinition = game.research.definition(record.id)
	current_id = record.id
	remaining = 8.0
	var texture: Texture2D = entry.subject_texture
	if texture!=null and entry.subject_region.has_area():
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = entry.subject_region
		texture = atlas
	image.texture = texture
	image.visible = texture!=null
	caption.text = entry.title+"\n"+entry.classification.to_upper()+" · "+("+%d RESEARCH XP" % record.award if record.award>0 else "ALREADY ARCHIVED · no XP")
	description.text = entry.description.get_slice(".",0)+". Full record: Map → Research."

func dismiss() -> void:
	remaining = 0
	hide()

func _process(delta: float) -> void:
	if game==null: return
	var blocked: bool = not game.chapter.active or not game.submarine.is_physics_processing() or game.revision.ui.modal() \
		or game.submarine.damage_system.warning_state==SubmarineDamageSystem.WarningState.EXCEEDED \
		or game.revision.ui.notifications.panel.visible or game.tutorial_card.visible
	if blocked:
		hide()
		return
	if remaining<=0 and not _queue.is_empty(): _next()
	remaining = maxf(0,remaining-delta)
	visible = remaining>0
	if not visible: return
	var viewport: Vector2 = get_viewport_rect().size
	size = Vector2(minf(360,viewport.x*0.43),0)
	var lower: float = viewport.y-84
	if game.revision.ui.notifications.badge.visible: lower = minf(lower,game.revision.ui.notifications.badge.get_global_rect().position.y-8)
	position = Vector2(16,lower-size.y)
