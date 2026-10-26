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
