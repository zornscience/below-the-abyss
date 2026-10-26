@tool
class_name GrayboxRock
extends StaticBody2D
## One authored outline supplies both the visible silhouette and solid boundary.

@export var outline: PackedVector2Array = PackedVector2Array():
	set(value):
		outline = value
		if is_node_ready():
			_apply_outline()
@export var fill: Color = Color("435661"):
	set(value):
		fill = value
		if is_node_ready():
			_apply_outline()


func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	_apply_outline()


func _apply_outline() -> void:
	($Silhouette as Polygon2D).polygon = outline
	($Silhouette as Polygon2D).color = fill
	($Boundary as CollisionPolygon2D).polygon = outline
	queue_redraw()


func _draw() -> void:
	if outline.size() < 3:
		return
	var closed: PackedVector2Array = outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, Color(0.23, 0.44, 0.47, 0.8), 2.0, true)
	# Restrained mineral dots stay strictly inside the authored solid polygon.
	var minimum: Vector2 = outline[0]
	var maximum: Vector2 = outline[0]
	for point: Vector2 in outline:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	for index: int in range(60):
		var at: Vector2 = minimum + (maximum - minimum) * Vector2(fposmod(index * 0.618, 1.0), fposmod(index * 0.381, 1.0))
		if Geometry2D.is_point_in_polygon(at, outline):
			draw_line(at, at + Vector2(7, -2), Color(0.29, 0.53, 0.54, 0.25), 1.0, true)
