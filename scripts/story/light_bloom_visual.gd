class_name LightBloomVisual
extends Node2D
## Geometric plankton; arrival is presentation only and never changes story state.
const ARRIVAL_SECONDS: float = 3.2
const PARTICLES: int = 96
var collected: bool = false
var observed: bool = false
var specimen_view: bool = false
var reaction: float = 0.0
var arrival_started: bool = false
var arrival_elapsed: float = 0.0
var arrival_center: Vector2 = Vector2.ZERO
var reduced_effects: bool = false:
	set(value):
		reduced_effects = value
		if value:
			reaction = 0.0
			arrival_center = Vector2.ZERO
			if arrival_started: arrival_elapsed = ARRIVAL_SECONDS
		queue_redraw()
func set_outcome(is_collected: bool, is_observed: bool, animate: bool = false) -> void:
	collected = is_collected
	observed = is_observed
	reaction = 1.4 if animate and not reduced_effects else 0.0
	if collected or observed:
		arrival_started = true
		arrival_elapsed = ARRIVAL_SECONDS
		arrival_center = Vector2.ZERO
	queue_redraw()
func advance_arrival(delta: float, vessel_position: Vector2, simulating: bool) -> void:
	if not simulating or collected or observed or not is_finite(delta) or delta<0.0: return
	if not arrival_started:
		if global_position.distance_to(vessel_position)>180.0: return
		arrival_started = true
		arrival_elapsed = ARRIVAL_SECONDS if reduced_effects else 0.0
	if arrival_elapsed>=ARRIVAL_SECONDS: return
	arrival_elapsed = minf(ARRIVAL_SECONDS,arrival_elapsed+delta)
	var scatter: float = clampf((arrival_elapsed-2.0)/1.2,0.0,1.0)
	arrival_center = to_local(vessel_position)*(1.0-scatter)
	queue_redraw()
func arrival_active() -> bool:
	return arrival_started and arrival_elapsed<ARRIVAL_SECONDS and not reduced_effects
func plankton_visible() -> bool:
	return not collected
func _process(delta: float) -> void:
	if reaction>0.0:
		reaction = maxf(0.0,reaction-delta)
		queue_redraw()
func _draw() -> void:
	if collected and specimen_view:
		# The vial appears only in the dialogue illustration, never as seabed debris.
		draw_style_box(_vial(),Rect2(-15,-46,30,58))
		draw_line(Vector2(-12,-50),Vector2(12,-50),Color("a6c3c5"),4,true)
		for index: int in range(12): draw_circle(Vector2(sin(index*2.4)*9,-7-index*2),1.2,Color("526b70"))
		return
	if collected and reaction<=0.0: return
	var scatter: float = clampf((arrival_elapsed-2.0)/1.2,0.0,1.0) if arrival_active() else 0.0
	var center: Vector2 = arrival_center if arrival_active() else Vector2.ZERO
	var tone: Color = Color("dce7b3") if observed else Color("9ee3dd")
	var fade: float = 1.0
	if collected:
		scatter = 1.0-reaction/1.4
		fade = reaction/1.4
		tone = Color("6c9797")
	for index: int in range(PARTICLES):
		var fraction: float = float(index)/float(PARTICLES-1)
		var angle: float = fraction*TAU*1.85
		var radius: float = 7.0+fraction*55.0
		var point: Vector2 = Vector2.from_angle(angle)*Vector2(radius,radius*0.48)
		point += Vector2.from_angle(index*2.39996)*scatter*24.0
		point += center
		var size: float = 1.0+float(index%3)*0.35
		draw_circle(point,size*3.0,Color(tone,0.09*fade))
		draw_circle(point,size,Color(tone,0.85*fade))
func _vial() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("152d36")
	style.border_color = Color("7f9fa5")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style
