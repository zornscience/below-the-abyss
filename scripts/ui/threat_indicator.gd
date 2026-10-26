class_name ThreatIndicator
extends PanelContainer
## Read-only, focus-free compact warning, driven by encounter signals.

var _source: WeakRef


func bind_source(source: PredatorCreature) -> void:
	var previous: PredatorCreature = _source.get_ref() as PredatorCreature if _source != null else null
	if is_instance_valid(previous) and previous.threat_changed.is_connected(_refresh):
		previous.threat_changed.disconnect(_refresh)
	_source = weakref(source) if source != null else null
	if source != null:
		source.threat_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var source: PredatorCreature = _source.get_ref() as PredatorCreature if _source != null else null
	if source == null:
		hide()
		return
	var value: Dictionary = source.hud_snapshot()
	visible = value.visible
	($Content/Title as Label).text = value.title
	($Content/Hint as Label).text = value.hint


func _process(_delta: float) -> void:
	if _source != null and _source.get_ref() == null:
		bind_source(null)
