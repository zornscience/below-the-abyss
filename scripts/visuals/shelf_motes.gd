extends Node2D
## Low-rate cosmetic motes; static ridge geometry is cached separately.
var _clock: float = 0.0
var _redraw_time: float = 0.0


func _process(delta: float) -> void:
	_clock += delta
	_redraw_time += delta
	if _redraw_time >= 1.0 / 15.0:
		_redraw_time = 0.0
		queue_redraw()


func _draw() -> void:
	for index: int in range(150):
		var x: float = fposmod(index * 179.23 + sin(_clock * 0.14 + index) * 10.0, 6000.0) - 800.0
		var y: float = fposmod(index * 97.3 - _clock * 1.8, 2100.0)
		draw_circle(Vector2(x, y), 0.8 + (index % 3) * 0.35, Color(0.55, 0.82, 0.8, 0.13))
