class_name LifeSupportWarning
extends Control
## Visible life-support countdown: a screen border plus a text line. Presentation only.
## The text carries the state, so the cue is never colour-only or audio-only.
## Default: the border pulses slowly (0.5 Hz, rising to 1.5 Hz over the last 20 s, hard
## cap 2 Hz) between partial and full opacity, never to zero, so it is not a strobe.
## Reduced flashing: a static, fully opaque border that thickens as time falls.
## High contrast: a brighter red border with a white inner edge.

const BASE_HZ: float = 0.5
const FINAL_HZ: float = 1.5
const MAX_HZ: float = 2.0
const RAMP_SECONDS: float = 20.0
const MIN_ALPHA: float = 0.6
const DEFAULT_WIDTH: float = 10.0
const STATIC_MIN_WIDTH: float = 6.0
const STATIC_MAX_WIDTH: float = 24.0
const HIGH_CONTRAST_EXTRA: float = 4.0
const INNER_WIDTH: float = 2.0
const DEFAULT_COLOR: Color = Color("d01f1f")
const HIGH_CONTRAST_COLOR: Color = Color("ff5050")
const INNER_COLOR: Color = Color.WHITE

var reduced_flashing: bool = false:
	set(value):
		reduced_flashing = value
		_refresh()
var high_contrast: bool = false:
	set(value):
		high_contrast = value
		_refresh()
## Simulation-time inputs, written by the recovery flow.
var remaining: float = 60.0
var grace_seconds: float = 60.0
## True only while the simulation runs, so the pulse freezes with pause and menus.
var animating: bool = false
var pulse_hz: float = BASE_HZ
var border_alpha: float = 1.0
var border_width: float = DEFAULT_WIDTH
var _phase: float = 0.0
var _edges: Array[ColorRect] = []
var _inner: Array[ColorRect] = []
var _panel: PanelContainer
var label: Label
## Optional HUD control (the oxygen gauge). The text sits directly below it, clear of the
## centred depth readout. Without an anchor the text is centred under the top border.
var anchor: Control


static func pulse_rate(seconds_left: float, grace: float) -> float:
	# 0.5 Hz until the last 20 s, then a linear rise to 1.5 Hz at zero, never above 2 Hz.
	var ramp: float = minf(RAMP_SECONDS, grace)
	var rate: float = BASE_HZ
	if ramp > 0.0 and seconds_left < ramp:
		rate = lerpf(BASE_HZ, FINAL_HZ, clampf(1.0 - seconds_left / ramp, 0.0, 1.0))
	return clampf(rate, 0.0, MAX_HZ)


static func countdown_text(seconds_left: float) -> String:
	var whole: int = maxi(0, ceili(seconds_left))
	var critical: bool = seconds_left <= LifeSupportCountdown.CRITICAL_SECONDS
	return "OXYGEN DEPLETED, LIFE SUPPORT %s%d:%02d" % ["CRITICAL " if critical else "", whole / 60, whole % 60]


func _init() -> void:
	name = "LifeSupportWarning"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index: int in range(4):
		var edge: ColorRect = ColorRect.new()
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(edge)
		_edges.append(edge)
	for index: int in range(4):
		var inner: ColorRect = ColorRect.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.color = INNER_COLOR
		add_child(inner)
		_inner.append(inner)
	_panel = PanelContainer.new()
	_panel.name = "LifeSupportText"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.theme = preload("res://resources/balance/instrument_theme.tres")
	add_child(_panel)
	label = Label.new()
	label.name = "LifeSupportLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(label)
	UiTypography.style(label, &"hud")
	hide()


func _ready() -> void:
	resized.connect(_layout)
	_refresh()


func present(seconds_left: float, grace: float) -> void:
	remaining = seconds_left
	grace_seconds = grace
	if not visible:
		_phase = 0.0
		show()
	_refresh()


func dismiss() -> void:
	hide()
	animating = false
	_phase = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	if animating and not reduced_flashing:
		_phase = fmod(_phase + delta * pulse_hz, 1.0)
	_refresh()


func _refresh() -> void:
	if _edges.is_empty():
		return
	pulse_hz = pulse_rate(remaining, grace_seconds)
	label.text = countdown_text(remaining)
	var colour: Color = HIGH_CONTRAST_COLOR if high_contrast else DEFAULT_COLOR
	if reduced_flashing:
		border_alpha = 1.0
		border_width = lerpf(STATIC_MIN_WIDTH, STATIC_MAX_WIDTH, clampf(1.0 - remaining / maxf(grace_seconds, 0.001), 0.0, 1.0))
	else:
		# Cosine from the top: the border starts fully visible and never goes transparent.
		border_alpha = lerpf(MIN_ALPHA, 1.0, 0.5 + 0.5 * cos(TAU * _phase))
		border_width = DEFAULT_WIDTH
	if high_contrast:
		border_width += HIGH_CONTRAST_EXTRA
	colour.a = border_alpha
	for edge: ColorRect in _edges:
		edge.color = colour
	for inner: ColorRect in _inner:
		inner.visible = high_contrast
	_layout()


func _layout() -> void:
	if _edges.is_empty():
		return
	var area: Vector2 = size
	var width: float = border_width
	_place(_edges[0], Rect2(0, 0, area.x, width))
	_place(_edges[1], Rect2(0, area.y - width, area.x, width))
	_place(_edges[2], Rect2(0, width, width, area.y - 2.0 * width))
	_place(_edges[3], Rect2(area.x - width, width, width, area.y - 2.0 * width))
	_place(_inner[0], Rect2(width, width, area.x - 2.0 * width, INNER_WIDTH))
	_place(_inner[1], Rect2(width, area.y - width - INNER_WIDTH, area.x - 2.0 * width, INNER_WIDTH))
	_place(_inner[2], Rect2(width, width, INNER_WIDTH, area.y - 2.0 * width))
	_place(_inner[3], Rect2(area.x - width - INNER_WIDTH, width, INNER_WIDTH, area.y - 2.0 * width))
	_panel.reset_size()
	var text_size: Vector2 = _panel.get_combined_minimum_size()
	var inset: float = width + 8.0 + (INNER_WIDTH if high_contrast else 0.0)
	var at: Vector2 = Vector2((area.x - text_size.x) * 0.5, inset)
	if is_instance_valid(anchor) and anchor.is_visible_in_tree():
		var below: Rect2 = anchor.get_global_rect()
		at = Vector2(maxf(inset, below.position.x), below.end.y + 8.0)
	at.x = clampf(at.x, inset, maxf(inset, area.x - inset - text_size.x))
	at.y = clampf(at.y, inset, maxf(inset, area.y - inset - text_size.y))
	_panel.position = at


func _place(rect: ColorRect, bounds: Rect2) -> void:
	rect.position = bounds.position
	rect.size = Vector2(maxf(0.0, bounds.size.x), maxf(0.0, bounds.size.y))
