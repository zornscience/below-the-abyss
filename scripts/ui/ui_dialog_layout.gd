class_name UiDialogLayout
extends RefCounted
## Presentation-only bounds. Domain coordinators retain all pause/focus/close rules.


static func bounds(viewport: Vector2,maximum: Vector2) -> Rect2:
	var dimensions: Vector2 = Vector2(minf(maximum.x,viewport.x-48),minf(maximum.y,viewport.y-64))
	return Rect2((viewport-dimensions)*0.5,dimensions)


static func bind_panel(panel: PanelContainer,maximum: Vector2) -> void:
	panel.set_meta("dialog_size",maximum)
	var shade: ColorRect = ColorRect.new()
	shade.name = "DialogShade"
	shade.color = Color(0.008,0.02,0.03,0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.get_parent().add_child(shade)
	panel.get_parent().move_child(shade,panel.get_index())
	shade.visible = panel.visible
	var shade_ref: WeakRef = weakref(shade)
	var panel_ref: WeakRef = weakref(panel)
	panel.visibility_changed.connect(func() -> void:
		var item: ColorRect = shade_ref.get_ref() as ColorRect
		var source: Control = panel_ref.get_ref() as Control
		if item!=null and source!=null: item.visible = source.visible)
	# UiAccessibility owns viewport reflow for tagged panels; no global callback.
	fit_panel(panel)


static func fit_panel(panel: Control) -> void:
	if not is_instance_valid(panel) or not panel.is_inside_tree(): return
	var rect: Rect2 = bounds(panel.get_viewport_rect().size,panel.get_meta("dialog_size") as Vector2)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = rect.position
	panel.size = rect.size


static func fit_screen(screen: Control,maximum: Vector2 = Vector2(860,560)) -> void:
	var margin: Control = screen.get_node_or_null("Margin") as Control
	if margin==null: return
	var rect: Rect2 = bounds(screen.get_viewport_rect().size,maximum)
	var background: ColorRect = screen.get_node_or_null("Backdrop") as ColorRect
	if background==null:
		for child: Node in screen.get_children():
			if child is ColorRect: background = child as ColorRect; break
	if background!=null: background.color = Color(0.008,0.02,0.03,0.55)
	var frame: Panel = screen.get_node_or_null("DialogFrame") as Panel
	if frame==null:
		frame = Panel.new()
		frame.name = "DialogFrame"
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(frame)
		screen.move_child(frame,1 if background!=null else 0)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("081923")
		style.border_color = Color("3b7078")
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		frame.add_theme_stylebox_override("panel",style)
	frame.position = rect.position
	frame.size = rect.size
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.position = rect.position+Vector2(18,18)
	margin.size = rect.size-Vector2(36,36)
