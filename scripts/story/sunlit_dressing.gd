class_name SunlitDressing
extends Node2D
## Original static kelp/reef silhouettes. Decorative geometry has no collision.
func _draw() -> void:
	for x: int in [420,1100,2120,2920,3650]:
		draw_colored_polygon(PackedVector2Array([Vector2(x-60,180),Vector2(x+45,180),Vector2(x+260,770),Vector2(x-160,770)]),Color(0.42,0.69,0.58,0.035))
	var roots: Array[Vector2] = [Vector2(800,790),Vector2(1120,680),Vector2(1490,630),Vector2(1940,630),Vector2(2300,650),Vector2(2680,670),Vector2(3200,790),Vector2(3740,780)]
	for index: int in range(roots.size()):
		var origin: Vector2 = roots[index]
		for branch: int in range(3):
			var height: float = 65+float((index*23+branch*31)%70)
			var tip: Vector2 = origin+Vector2((branch-1)*23,-height)
			draw_line(origin,tip,Color("326751"),3,true)
			for leaf: int in range(4):
				var center: Vector2 = origin.lerp(tip,0.25+leaf*0.19)
				var side: float = -1.0 if (leaf+branch)%2==0 else 1.0
				draw_colored_polygon(PackedVector2Array([center,center+Vector2(side*23,-24),center+Vector2(side*8,4)]),Color("4f8970") if branch%2==0 else Color("396d60"))
	for x: int in [980,2250,3180,3820]:
		draw_colored_polygon(PackedVector2Array([Vector2(x-45,797),Vector2(x-32,776),Vector2(x-10,781),Vector2(x+14,756),Vector2(x+42,783),Vector2(x+58,797)]),Color("426d72"))
