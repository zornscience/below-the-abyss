class_name UiAccessibility
extends Node
## Scene-owned presentation policy. Reflows on preferences/resize/content minima only.
const SCALE: Dictionary = UiTypography.SCALE
var _scene: ShelfPrototype
var _preferences: Dictionary = SettingsStore.default_accessibility()
var _queued: bool = false
var _fit_queued: bool = false
var _feedback: Control
var _guide_offsets: Vector2
var _threat_offsets: Rect2


func setup(scene: ShelfPrototype) -> void:
	_scene = scene
	_feedback = scene.hud.get_node("Bottom/Feedback") as Control
	var guide: Control = scene.get_node("UI/RouteGuide") as Control
	_guide_offsets = Vector2(guide.offset_top, guide.offset_bottom)
	var threat: Control = scene.hud.get_node("%ThreatIndicator") as Control
	_threat_offsets = Rect2(threat.offset_left, threat.offset_top, threat.offset_right - threat.offset_left, threat.offset_bottom - threat.offset_top)
	scene.settings.settings_changed.connect(queue_apply)
	scene.get_viewport().size_changed.connect(queue_apply)
	get_tree().node_added.connect(_node_added)
	(scene.get_node("UI/RouteGuide") as Control).minimum_size_changed.connect(queue_fit)
	(scene.hud.get_node("%InstrumentDeck") as Control).minimum_size_changed.connect(queue_fit)
	(scene.hud.get_node("%DepthPanel") as Control).minimum_size_changed.connect(queue_fit)
	threat.minimum_size_changed.connect(queue_fit)
	apply()


func queue_apply() -> void:
	if not _queued:
		_queued = true
		apply.call_deferred()


func queue_fit() -> void:
	if not _fit_queued:
		_fit_queued = true
		_fit_hud.call_deferred()


func _node_added(node: Node) -> void:
	if is_instance_valid(_scene) and _scene.is_ancestor_of(node):
		_apply_added.call_deferred(weakref(node))


func _apply_added(reference: WeakRef) -> void:
	var node: Node = reference.get_ref() as Node
	if is_instance_valid(node) and node.is_inside_tree():
		_apply_node(node)


func _interface(node: Node) -> bool:
	var ancestor: Node = node
	while ancestor != null and ancestor != _scene:
		if ancestor is CanvasLayer:
			return true
		ancestor = ancestor.get_parent()
	return false


func tight_hud() -> bool:
	return _preferences.ui_scale == "large" and _scene.get_viewport().get_visible_rect().size.x < 1100.0


func apply() -> void:
	_queued = false
	if not is_instance_valid(_scene):
		return
	_preferences = _scene.settings.snapshot().accessibility
	var focus: Control = _scene.get_viewport().gui_get_focus_owner()
	_walk(_scene)
	for screen: Control in [_scene.route_menu, _scene.station_menu, _scene.exploration_map, _scene.research_log, _scene.expedition_log]:
		_wrap_screen(screen)
		if screen!=_scene.route_menu and screen!=_scene.exploration_map: UiDialogLayout.fit_screen(screen,Vector2(940,580))
	var threat_content: Control = _scene.hud.get_node("%ThreatIndicator").get_node("Content") as Control
	if tight_hud():
		threat_content.add_theme_constant_override("separation", 1)
	else:
		threat_content.remove_theme_constant_override("separation")
	var guide_content: Control = _scene.get_node("UI/RouteGuide/Content") as Control
	if tight_hud():
		guide_content.add_theme_constant_override("separation", 2)
	else:
		guide_content.remove_theme_constant_override("separation")
	_scene.hud.large_interface = _preferences.ui_scale == "large"
	_scene.hud.set_accessibility_compact(tight_hud())
	_scene._refresh_scan_status()
	_scene._refresh_mission_status()
	if is_instance_valid(focus) and focus.is_visible_in_tree():
		focus.grab_focus.call_deferred()
	queue_fit()


func _walk(node: Node) -> void:
	_apply_node(node)
	for child: Node in node.get_children():
		_walk(child)


func _apply_node(node: Node) -> void:
	if node is Control and _interface(node):
		node.set_meta("typography_scale",String(_preferences.ui_scale))
		node.set_meta("typography_high_contrast",bool(_preferences.high_contrast))
		_apply_control(node as Control)
		if node is ExplorationMapCanvas or node is ResearchTreeIllustration:
			node.queue_redraw()
		if node.has_meta("dialog_size"): UiDialogLayout.fit_panel(node as Control)
		if node is AccessibilityPanel or node is AudioSettingsPanel or node is MechanicsHelp or node is PlaytestPanel or node is InputTestMenu:
			UiDialogLayout.fit_screen(node as Control)
	elif node is Label and node.has_meta("typography_role"):
		UiTypography.apply(node,String(_preferences.ui_scale))
	if node is SonarPulse:
		(node as SonarPulse).reduced_flashing = bool(_preferences.reduced_flashing)
	if node is SonarRevealTarget:
		(node as SonarRevealTarget).reduced_flashing = bool(_preferences.reduced_flashing)
		node.queue_redraw()
	var script: Script = node.get_script() as Script
	if script != null and script.resource_path.ends_with("/shelf_motes.gd"):
		(node as CanvasItem).visible = not bool(_preferences.reduced_particles)
		node.set_process(not bool(_preferences.reduced_motion) and not bool(_preferences.reduced_particles))
	if script != null and script.resource_path.ends_with("/submarine_illustration.gd"):
		node.set("reduced_motion", bool(_preferences.reduced_motion))
	if node is SunlitDressing: node.apply_preferences(_preferences)
	if node is CreaturePaint: node.reduced_motion = bool(_preferences.reduced_motion)
	if node is TorpedoTrail: node.reduced = bool(_preferences.reduced_particles) or bool(_preferences.reduced_motion)
	if node is BlastEffect:
		node.reduced_effects = bool(_preferences.reduced_flashing) or bool(_preferences.reduced_motion) or bool(_preferences.reduced_particles)
		if node._lens!=null: node._lens.visible = not node.reduced_effects
	if node is Parallax2D:
		if not node.has_meta("a11y_scroll_scale"):
			node.set_meta("a11y_scroll_scale", (node as Parallax2D).scroll_scale)
		(node as Parallax2D).scroll_scale = Vector2.ZERO if _preferences.reduced_motion else node.get_meta("a11y_scroll_scale") as Vector2


func _apply_control(control: Control) -> void:
	if control is Label or control is BaseButton:
		UiTypography.apply(control,String(_preferences.ui_scale))
		if not control.has_meta("a11y_color"):
			control.set_meta("a11y_color", [control.has_theme_color_override("font_color"), control.get_theme_color("font_color")])
		var color: Array = control.get_meta("a11y_color")
		if _preferences.high_contrast:
			control.add_theme_color_override("font_color", Color.WHITE)
		elif bool(color[0]):
			control.add_theme_color_override("font_color", color[1])
		else:
			control.remove_theme_color_override("font_color")
	if control is Button:
		if not control.has_meta("a11y_focus"):
			control.set_meta("a11y_focus", [control.has_theme_stylebox_override("focus"), control.get_theme_stylebox("focus")])
		var original_focus: Array = control.get_meta("a11y_focus")
		if _preferences.high_contrast:
			var focus: StyleBoxFlat = StyleBoxFlat.new()
			focus.draw_center = false
			focus.border_color = Color("d9e0a6")
			focus.set_border_width_all(4)
			control.add_theme_stylebox_override("focus", focus)
		elif bool(original_focus[0]):
			control.add_theme_stylebox_override("focus", original_focus[1])
		else:
			control.remove_theme_stylebox_override("focus")
	if control is PanelContainer or control is Button:
		var key: String = "panel" if control is PanelContainer else "normal"
		if not control.has_meta("a11y_style"):
			control.set_meta("a11y_style", [control.has_theme_stylebox_override(key), control.get_theme_stylebox(key)])
		var original: Array = control.get_meta("a11y_style")
		var compact_panel: bool = tight_hud() and control is PanelContainer and (
			_scene.hud.is_ancestor_of(control) or control == _scene.get_node("UI/RouteGuide"))
		if (_preferences.high_contrast or compact_panel) and original[1] is StyleBoxFlat:
			var style: StyleBoxFlat = (original[1] as StyleBoxFlat).duplicate() as StyleBoxFlat
			if _preferences.high_contrast:
				style.bg_color = Color("030c12")
				style.border_color = Color("a9c5cb")
				style.set_border_width_all(2)
			if compact_panel:
				style.content_margin_top = 3.0 if control in [_scene.get_node("UI/RouteGuide"), _scene.hud.get_node("%ThreatIndicator")] else 6.0
				style.content_margin_bottom = style.content_margin_top
				style.content_margin_left = 10.0
				style.content_margin_right = 10.0
			control.add_theme_stylebox_override(key, style)
		elif bool(original[0]):
			control.add_theme_stylebox_override(key, original[1])
		else:
			control.remove_theme_stylebox_override(key)


func _wrap_screen(screen: Control) -> void:
	var large: bool = screen!=_scene.exploration_map or _preferences.ui_scale == "large"
	var parent: Node = screen.get_node_or_null("Margin")
	var content: Control
	if screen == _scene.route_menu:
		parent = screen.get_node("Center")
		content = parent.get_node_or_null("Panel") as Control
	else:
		content = parent.get_node_or_null("Content") as Control if parent != null else null
	if parent == null:
		return
	var scroll: ScrollContainer = parent.get_node_or_null("AccessibleScroll") as ScrollContainer
	if large:
		if scroll == null and content != null:
			scroll = ScrollContainer.new()
			scroll.name = "AccessibleScroll"
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.follow_focus = true
			scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			parent.add_child(scroll)
			content.reparent(scroll)
			content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if scroll != null and screen == _scene.route_menu:
			scroll.custom_minimum_size = UiDialogLayout.bounds(_scene.get_viewport().get_visible_rect().size,Vector2(760,540)).size-Vector2(36,32)
	elif scroll != null:
		var child: Node = scroll.get_child(0)
		child.reparent(parent)
		parent.remove_child(scroll)
		scroll.queue_free()


func _fit_hud() -> void:
	_fit_queued = false
	if not is_instance_valid(_scene):
		return
	var guide: Control = _scene.get_node("UI/RouteGuide") as Control
	var threat: Control = _scene.hud.get_node("%ThreatIndicator") as Control
	if _scene.hud.quiet:
		_scene.hud.compact_reflow()
		guide.hide()
		_scene._layout_tutorial()
		return
	if _preferences.ui_scale != "large":
		threat.offset_left = _threat_offsets.position.x
		threat.offset_top = _threat_offsets.position.y
		threat.offset_right = _threat_offsets.end.x
		threat.offset_bottom = _threat_offsets.end.y
		if _feedback.get_parent() == _scene.hud:
			_feedback.reparent(_scene.hud.get_node("Bottom"))
			_feedback.layout_mode = 2
			_scene.hud.get_node("Bottom").move_child(_feedback, 0)
		guide.offset_top = _guide_offsets.x
		guide.offset_bottom = _guide_offsets.y
		return
	var depth: Control = _scene.hud.get_node("%DepthPanel") as Control
	threat.offset_left = depth.get_global_rect().position.x - _scene.get_viewport().get_visible_rect().size.x
	threat.offset_right = -24.0
	threat.offset_top = depth.get_global_rect().end.y + 8.0
	threat.offset_bottom = threat.offset_top + threat.get_combined_minimum_size().y
	var deck: Control = _scene.hud.get_node("%InstrumentDeck") as Control
	guide.offset_bottom = deck.get_global_rect().position.y - _scene.get_viewport().get_visible_rect().size.y - 8.0
	guide.offset_top = guide.offset_bottom - guide.get_combined_minimum_size().y
	if _feedback.get_parent() != _scene.hud:
		_feedback.reparent(_scene.hud)
		_feedback.layout_mode = 0
	_feedback.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var feedback_gap: float = 2.0 if tight_hud() else 8.0
	_feedback.position = Vector2(24, guide.get_global_rect().position.y - maxf(30.0, _feedback.get_combined_minimum_size().y) - feedback_gap)
	_feedback.size = Vector2(_scene.get_viewport().get_visible_rect().size.x - 48.0, maxf(30.0, _feedback.get_combined_minimum_size().y))


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_node_added):
		get_tree().node_added.disconnect(_node_added)
	if is_instance_valid(_scene):
		if _scene.settings.settings_changed.is_connected(queue_apply):
			_scene.settings.settings_changed.disconnect(queue_apply)
		if _scene.get_viewport().size_changed.is_connected(queue_apply):
			_scene.get_viewport().size_changed.disconnect(queue_apply)
