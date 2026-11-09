class_name DepthGateProfile
extends Resource
@export var gate_rank: int = 2
@export var depth_m: float = 1120.0
@export var floor_y: float = 4560.0
@export var approach: Vector2 = Vector2(30000,3100)
@export var exit: Vector2 = Vector2(33100,3100)
@export var lower_left: Vector2 = Vector2(30000,4480)
@export var lower_right: Vector2 = Vector2(33100,4480)
func crossing() -> PackedVector2Array:
	return PackedVector2Array([approach,lower_left,lower_right,exit])
