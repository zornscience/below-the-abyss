extends Node2D
## Original deterministic illustration; no terrain, discovery or physics queries.

@export var near_layer: bool = false


func _draw() -> void:
	# Distant ridges deliberately read as low-contrast negative space, not walls.
	for layer: int in range(1 if near_layer else 3):
		var ridge: PackedVector2Array = PackedVector2Array()
		ridge.append(Vector2(-4000, 2600))
		for step: int in range(101):
			var x: float = -4000.0 + step * 140.0
			var y: float = (1050.0 if near_layer else 720.0) + layer * 170.0 + sin(step * 1.7 + layer) * 110.0
			ridge.append(Vector2(x, y))
		ridge.append(Vector2(10000, 2600))
		draw_colored_polygon(ridge, Color(0.035 + layer * 0.009, 0.12 + layer * 0.012, 0.16 + layer * 0.014, 0.25))
	if near_layer:
		return
	# Broad, faint shafts are geometry, not full-screen lighting/postprocessing.
	for index: int in range(16):
		var x: float = index * 420.0 - 1000.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, -1000), Vector2(x + 70, -1000), Vector2(x + 650, 1500), Vector2(x + 360, 1500)]), Color(0.3, 0.65, 0.68, 0.018))
