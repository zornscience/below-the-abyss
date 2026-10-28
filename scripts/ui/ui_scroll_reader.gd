class_name UiScrollReader
extends ScrollContainer
## A focusable reading surface: wheel/scrollbar, Page keys or held D-pad. No extra buttons.
var _held: int = 0
var _repeat: float = 0.0
var _outline: StyleBoxFlat

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	follow_focus = true
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
	Input.joy_connection_changed.connect(_device_changed)
	_outline = StyleBoxFlat.new()
	_outline.draw_center = false
	_outline.border_color = Color("d9e0a6")
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _draw() -> void:
	if has_focus() and _outline!=null:
		_outline.set_border_width_all(3 if get_meta("typography_high_contrast",false) else 1)
		draw_style_box(_outline,Rect2(Vector2.ZERO,size))

func _device_changed(_device: int,connected: bool) -> void:
	if not connected: _held = 0

func handle_reading_input(event: InputEvent) -> bool:
	var direction: int = 0
	if event.is_action("ui_up"): direction = -1
	elif event.is_action("ui_down"): direction = 1
	elif event is InputEventKey and event.keycode in [KEY_PAGEUP,KEY_PAGEDOWN]:
		if event.pressed: scroll_vertical += int(size.y*0.8)*(-1 if event.keycode==KEY_PAGEUP else 1)
		return true
	if direction==0: return false
	if event.is_pressed():
		if not event.is_echo():
			_held = direction
			_repeat = 0.35
			scroll_vertical += direction*48
	elif _held==direction: _held = 0
	return true

func _gui_input(event: InputEvent) -> void:
	if has_focus() and handle_reading_input(event): accept_event()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not has_focus():
		_held = 0
		return
	if _held==0: return
	_repeat -= delta
	while _repeat<=0:
		scroll_vertical += _held*48
		_repeat += 0.09

static func link(controls: Array[Control],reader: ScrollContainer) -> void:
	for index: int in range(controls.size()):
		var control: Control = controls[index]
		for property: String in ["focus_next","focus_neighbor_right"]: control.set(property,control.get_path_to(controls[(index+1)%controls.size()]))
		for property: String in ["focus_previous","focus_neighbor_left"]: control.set(property,control.get_path_to(controls[posmod(index-1,controls.size())]))
		control.focus_neighbor_top = NodePath(".") if control==reader else control.focus_previous
		control.focus_neighbor_bottom = NodePath(".") if control==reader else control.focus_next
