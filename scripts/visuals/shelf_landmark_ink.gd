extends Node2D
## Authored surface paint and organic filigree. No interactables or collisions.


func _draw() -> void:
	# Station platform/post retain their exact solid silhouettes; paint stays inside.
	for x: int in range(230, 650, 35):
		draw_line(Vector2(x, 695), Vector2(x - 12, 722), Color("b5a779"), 3.0, true)
	for y: int in range(420, 680, 38):
		draw_circle(Vector2(194, y), 2.0, Color("b5a779"))
	# Recognizable paired mineral seams follow the existing spires' solid faces.
	for origin: Vector2 in [Vector2(3465, 860), Vector2(3715, 845)]:
		draw_polyline(PackedVector2Array([origin, origin + Vector2(-10, 100), origin + Vector2(10, 165), origin + Vector2(0, 245)]), Color(0.3, 0.7, 0.65, 0.6), 2.0, true)
	# Fine organic surface marks are nonsolid, like sea fans, not extra walls.
	for origin: Vector2 in [Vector2(830, 1120), Vector2(2480, 1120), Vector2(3370, 1120), Vector2(3850, 1120)]:
		for branch: int in range(7):
			var tip: Vector2 = origin + Vector2((branch - 3) * 9, -22 - (3 - absi(branch - 3)) * 8)
			draw_line(origin, tip, Color(0.22, 0.52, 0.5, 0.65), 1.5, true)
			draw_circle(tip, 1.8, Color(0.5, 0.8, 0.69, 0.65))
