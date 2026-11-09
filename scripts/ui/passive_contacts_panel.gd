class_name PassiveContactsPanel
extends PanelContainer
## Read-only passive bearings. No input, world markers, map or discovery state.

const ARROWS: Array[String] = ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
const CLASS_LABELS: Dictionary[StringName, String] = {
	&"mechanical": "MECHANICAL", &"geological": "GEOLOGICAL", &"marine_life": "MARINE LIFE"}
var _source: WeakRef
var _compact: bool = false
var quiet: bool = false
## Production layout hides the panel until a contact exists, so an empty box never competes for attention.
var hide_when_empty: bool = false


func _ready() -> void:
	_ignore_input(self)
	_refresh()


func _ignore_input(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(node as Control).focus_mode = Control.FOCUS_NONE
	for child: Node in node.get_children():
		_ignore_input(child)


func bind_source(source: PassiveReceiver) -> void:
	var previous: PassiveReceiver = _source.get_ref() as PassiveReceiver if _source != null else null
	if is_instance_valid(previous) and previous.contacts_changed.is_connected(_refresh):
		previous.contacts_changed.disconnect(_refresh)
	_source = weakref(source) if source != null else null
	if source != null:
		source.contacts_changed.connect(_refresh)
	_refresh()


func set_compact(value: bool) -> void:
	_compact = value
	_refresh()


func _refresh() -> void:
	var source: PassiveReceiver = _source.get_ref() as PassiveReceiver if _source != null else null
	var contacts: Array[Dictionary] = []
	if source != null:
		contacts = source.contacts_snapshot()
	var status: String = source.status_text() if source != null else "OFFLINE"
	(%PassiveHeader as Label).text = "PASSIVE" if quiet else "PASSIVE / %s" % status
	visible = not (hide_when_empty and contacts.is_empty())
	(%PassiveEmpty as Label).visible = contacts.is_empty()
	(%PassiveEmpty as Label).text = "No recent contacts" if status != "OFFLINE" else "No receiver bound"
	for index: int in range(3):
		var row: Control = get_node("Content/Contact%d" % index) as Control
		row.visible = index < contacts.size()
		if index >= contacts.size():
			continue
		var contact: Dictionary = contacts[index]
		var bearing: float = contact.bearing_degrees
		(row.get_node("Header/Arrow") as Label).text = ARROWS[posmod(int(roundf(bearing / 45.0)), 8)]
		(row.get_node("Header/Caption") as Label).text = "%s  %+04.0f°" % [
			(CLASS_LABELS.get(contact.classification, "UNKNOWN").replace("MECHANICAL","MECH").replace("GEOLOGICAL","GEO").replace("MARINE LIFE","LIFE") if quiet else CLASS_LABELS.get(contact.classification,"UNKNOWN")), bearing]
		if _compact:
			(row.get_node("Header/Caption") as Label).text += " ~%.0f%%" % (contact.signal_strength * 100.0)
		(row.get_node("Strength") as Control).visible = not _compact
		(row.get_node("Header/Expiry") as Label).text = "%.1fs" % contact.remaining_seconds
		(row.get_node("Strength/Bar") as ProgressBar).value = contact.signal_strength * 100.0
		(row.get_node("Strength/Value") as Label).text = "~%.0f%%" % (contact.signal_strength * 100.0)
	if contacts.size() > 3:
		(%PassiveHeader as Label).text = "PASSIVE / %d (3 SHOWN)" % contacts.size()


func _process(_delta: float) -> void:
	if _source != null and _source.get_ref() == null:
		_source = null
		_refresh()
