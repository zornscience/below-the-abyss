class_name BenthicGarden
extends Node2D
## Decorative rooted growth samples actual collision surfaces; no collision of its own.
var _roots: Array[Vector2] = []
var _queued: bool = false
func _ready() -> void:
	z_index = 2
	refresh()
func refresh() -> void:
	if _queued: return
	_queued = true
	_rebuild.call_deferred()
func _rebuild() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree(): return
	_roots.clear()
	for index: int in range(180):
		var x: float = 900+index*126
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(Vector2(x,900),Vector2(x,1720),1)
		var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): _roots.append(to_local(hit.position))
	_queued = false
	queue_redraw()
func _draw() -> void:
	for index: int in range(_roots.size()):
		var root: Vector2 = _roots[index]
		for leaf: int in range(6):
			var tip: Vector2 = root+Vector2((leaf-2.5)*8,-28-(index+leaf*3)%5*9)
			draw_colored_polygon(PackedVector2Array([root,tip+Vector2(-4,9),tip,tip+Vector2(5,8)]),Color("397a6d").darkened(leaf*0.04))
		for bud: int in range(3):
			draw_circle(root+Vector2(bud*8-6,-9),3+bud,Color("7d9977"))
