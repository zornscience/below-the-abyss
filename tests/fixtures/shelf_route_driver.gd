class_name ShelfRouteDriver
extends RefCounted
## Test-only steering through real input actions, never vessel position/velocity writes.

const OUTBOUND: Array[String] = ["UpperGate", "Cave", "EastChamber", "TwinSpires"]
const RETURN: Array[String] = ["ReturnTurn", "LowerEast", "LowerWest", "BaseRise"]


static func steer(position: Vector2, target: Vector2) -> void:
	var desired: Vector2 = ((target - position) * 2.5).limit_length(185.0) / 240.0
	# Encode the existing radial Input.get_vector dead zone so a requested small
	# velocity remains controllable while approaching a waypoint.
	var deadzone: float = InputMap.action_get_deadzone("move_left")
	var encoded: Vector2 = Vector2.ZERO
	if not desired.is_zero_approx():
		encoded = desired.normalized() * lerpf(deadzone, 1.0, desired.length())
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
	if encoded.x < 0.0:
		Input.action_press("move_left", -encoded.x)
	elif encoded.x > 0.0:
		Input.action_press("move_right", encoded.x)
	if encoded.y < 0.0:
		Input.action_press("move_up", -encoded.y)
	elif encoded.y > 0.0:
		Input.action_press("move_down", encoded.y)


static func release() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
