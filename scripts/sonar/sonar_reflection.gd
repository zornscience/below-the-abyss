class_name SonarReflection
extends Node2D
## Cosmetic return only. The outbound pulse remains the discovery/dispatcher authority.
var origin: Vector2
var receiver: WeakRef
var speed: float = 600.0
var elapsed: float = 0.0
var lifetime: float = 1.0
var reduced: bool = false

func configure(at: Vector2,to: Node2D,travel_speed: float,quiet: bool) -> void:
	origin = at
	receiver = weakref(to)
	speed = travel_speed
	reduced = quiet
	lifetime = 0.4 if quiet else clampf(at.distance_to(to.global_position)/speed*2+0.5,0.4,6.0)
	global_position = at
	z_index = 5

func advance(delta: float) -> void:
	var destination: Node2D = receiver.get_ref() as Node2D if receiver!=null else null
	if not is_instance_valid(destination) or destination.is_queued_for_deletion():
		queue_free()
		return
	elapsed = minf(lifetime,elapsed+delta)
	if not reduced:
		var at: Vector2 = destination.global_position
		global_position = origin.move_toward(at,speed*elapsed)
		rotation = (at-origin).angle()
		if global_position.is_equal_approx(at): queue_free()
	if elapsed>=lifetime: queue_free()
	queue_redraw()

func _draw() -> void:
	var alpha: float = clampf((lifetime-elapsed)/0.3,0,1)*(0.25 if reduced else 0.65)
	draw_arc(Vector2.ZERO,12,-PI*0.6,PI*0.6,24,Color(0.55,0.94,0.88,alpha),2,true)
	if not reduced: draw_line(Vector2(-18,0),Vector2(-5,0),Color(0.55,0.94,0.88,alpha*0.3),2,true)
