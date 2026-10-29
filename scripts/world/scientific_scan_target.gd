class_name ScientificScanTarget
extends Node2D
## Non-colliding placeholder; no secrets shown before the associated discovery.

@export var target_id: StringName
var scan_enabled: bool = true
var _completed: bool = false
var _known: bool = false
var _classification: String = ""


func present(known: bool, category: String, completed: bool = false) -> void:
	_completed = completed
	_known = known
	_classification = category
	queue_redraw()


func _draw() -> void:
	# The authored specimen supplies its own art. Scan prompts/progress belong in the HUD.
	pass
