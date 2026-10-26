class_name SubmarineController
extends CharacterBody2D
## Omnidirectional submarine motor; collision response is Godot's swept sliding.

signal collision_occurred(normal: Vector2, approach_speed: float)

@export var motion: SubmarineMotion = SubmarineMotion.new()
var depth_region: DepthRegion

@onready var resource_system: SubmarineResourceSystem = $ResourceSystem
@onready var hull_system: SubmarineHullSystem = $HullSystem
@onready var damage_system: SubmarineDamageSystem = $DamageSystem


func _physics_process(delta: float) -> void:
	var thrust: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	resource_system.advance(delta, thrust.length())
	velocity = motion.next_velocity(velocity, thrust, delta)
	var attempted_velocity: Vector2 = velocity
	var collided: bool = move_and_slide()
	var maximum_approach_speed: float = 0.0
	if collided:
		for index: int in range(get_slide_collision_count()):
			var contact: KinematicCollision2D = get_slide_collision(index)
			var relative_velocity: Vector2 = attempted_velocity - contact.get_collider_velocity()
			var approach_speed: float = maxf(0.0, -relative_velocity.dot(contact.get_normal()))
			maximum_approach_speed = maxf(maximum_approach_speed, approach_speed)
			# Floating mode can stop travel without clearing requested velocity.
			# Discard inward momentum, retain the tangential component for sliding.
			if velocity.dot(contact.get_normal()) < 0.0:
				velocity = velocity.slide(contact.get_normal())
			collision_occurred.emit(contact.get_normal(), approach_speed)
	var depth: float = depth_region.depth_at_world(global_position) if depth_region != null else 0.0
	damage_system.advance(delta, depth, hull_system)
	# Aggregate the whole swept step: corner/multiple slide contacts are one hit.
	damage_system.observe_contacts(maximum_approach_speed, collided, hull_system)
