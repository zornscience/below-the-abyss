class_name SubmarineHud
extends Control
## Reusable signal consumer; never writes to the vessel or its configuration.

const FEEDBACK_SECONDS: float = 2.5
var _resources: SubmarineResourceSystem
var _hull: SubmarineHullSystem
var _damage: SubmarineDamageSystem
var _sonar: SonarEmitter
var large_interface: bool = false
var quiet: bool = false
var _accessibility_compact: bool = false
var _has_sonar: bool = false
var _connections: Array[Signal] = []
var _callbacks: Array[Callable] = []
var _impact_remaining: float = 0.0
var _pressure_remaining: float = 0.0
var _pressure_total: float = 0.0

@onready var hull_gauge: ResourceGauge = %HullGauge
@onready var battery_gauge: ResourceGauge = %BatteryGauge
@onready var oxygen_gauge: ResourceGauge = %OxygenGauge


func _ready() -> void:
	# Decorative children must not steal mouse events or keyboard/gamepad focus.
	_ignore_input(self)
	resized.connect(_layout_changed)
	_layout_changed()
	clear_sources()


func _ignore_input(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(node as Control).focus_mode = Control.FOCUS_NONE
	for child: Node in node.get_children():
		_ignore_input(child)


func _layout_changed() -> void:
	(%IdentityDetail as Label).visible = size.x >= 1100.0 and not quiet
	(%PassiveContacts as PassiveContactsPanel).set_compact(quiet or size.x < 1100.0 or large_interface)
	(identity_container().get_node("Vessel") as Control).visible = not _accessibility_compact and not quiet


func set_accessibility_compact(value: bool) -> void:
	_accessibility_compact = value
	(%ThreatIndicator as ThreatIndicator).set_compact(value)
	(%DepthPanel as Control).custom_minimum_size.x = 0.0 if value else (250.0 if quiet else 390.0)
	for gauge: ResourceGauge in [hull_gauge, battery_gauge, oxygen_gauge]:
		gauge.accessibility_compact = value
		gauge.set_reading(gauge.current_value, gauge.maximum_value)
	_layout_changed()
	if quiet: compact_reflow()
	if is_instance_valid(_damage):
		_maximum_depth_changed(_damage.get_maximum_depth_m())
		_warning_changed(_damage.warning_state)


func _listen(event: Signal, callback: Callable) -> void:
	event.connect(callback)
	_connections.append(event)
	_callbacks.append(callback)


func clear_sources() -> void:
	bind_sonar(null)
	bind_passive(null)
	bind_threat(null)
	for index: int in range(_connections.size()):
		var event: Signal = _connections[index]
		if not event.is_null() and is_instance_valid(event.get_object()) \
			and event.is_connected(_callbacks[index]):
			event.disconnect(_callbacks[index])
	_connections.clear()
	_callbacks.clear()
	_resources = null
	_hull = null
	_damage = null
	_impact_remaining = 0.0
	_pressure_remaining = 0.0
	_pressure_total = 0.0
	if is_node_ready():
		(%InstrumentDeck as Control).hide()
		(%DepthPanel as Control).hide()
		(%ConnectionStatus as Label).show()
		(%ImpactFeedback as Label).text = ""
		(%PressureFeedback as Label).text = ""


func bind_sources(resources: SubmarineResourceSystem, hull: SubmarineHullSystem,
		damage: SubmarineDamageSystem) -> Error:
	if not is_node_ready() or not is_instance_valid(resources) \
		or not is_instance_valid(hull) or not is_instance_valid(damage):
		return ERR_INVALID_PARAMETER
	clear_sources()
	_resources = resources
	_hull = hull
	_damage = damage
	_listen(resources.battery_changed, _battery_changed)
	_listen(resources.oxygen_changed, _oxygen_changed)
	_listen(hull.hull_changed, _hull_changed)
	_listen(damage.depth_changed, _depth_changed)
	_listen(damage.maximum_depth_changed, _maximum_depth_changed)
	_listen(damage.warning_changed, _warning_changed)
	_listen(damage.collision_damage_applied, _impact_applied)
	_listen(damage.pressure_damage_applied, _pressure_applied)
	# Signals may have fired before the HUD existed: take an explicit initial snapshot.
	_battery_changed(resources.battery, resources.max_battery)
	_oxygen_changed(resources.oxygen, resources.max_oxygen)
	_hull_changed(hull.hull, hull.max_hull)
	_depth_changed(damage.depth_m, damage.get_maximum_depth_m())
	_warning_changed(damage.warning_state)
	(%InstrumentDeck as Control).show()
	(%DepthPanel as Control).show()
	(%ConnectionStatus as Label).hide()
	return OK


func bind_sonar(sonar: SonarEmitter) -> void:
	if is_instance_valid(_sonar) and _sonar.state_changed.is_connected(_refresh_sonar):
		_sonar.state_changed.disconnect(_refresh_sonar)
	_sonar = sonar
	_has_sonar = is_instance_valid(sonar)
	if is_instance_valid(_sonar):
		_sonar.state_changed.connect(_refresh_sonar)
	_refresh_sonar()


func _refresh_sonar() -> void:
	var label: Label = %Sonar
	if not is_instance_valid(_sonar):
		label.text = "SONAR / OFFLINE"
	else:
		label.text = "SONAR / %s · COST %.1f\nRANGE %.0f u · ECHOES %d" % [
			_sonar.status_text(), _sonar.battery_cost(), _sonar.maximum_radius(), _sonar.echo_count()]
		if quiet: label.text = "SONAR %s · %.0f power" % [_sonar.status_text(),_sonar.battery_cost()]


func bind_passive(receiver: PassiveReceiver) -> void:
	(%PassiveContacts as PassiveContactsPanel).bind_source(receiver)


func bind_threat(source: PredatorCreature) -> void:
	(%ThreatIndicator as ThreatIndicator).bind_source(source)

func _battery_changed(current: float, maximum: float) -> void:
	battery_gauge.set_reading(current, maximum)


func _oxygen_changed(current: float, maximum: float) -> void:
	oxygen_gauge.set_reading(current, maximum)


func _hull_changed(current: float, maximum: float) -> void:
	hull_gauge.set_reading(current, maximum)


func _depth_changed(depth: float, maximum: float) -> void:
	(%DepthValue as Label).text = "%.1f m" % depth
	_maximum_depth_changed(maximum)


func _maximum_depth_changed(maximum: float) -> void:
	(%SafeDepth as Label).text = ("RATED %.0f m" if quiet else ("SAFE LIMIT  %.1f m" if _accessibility_compact else "SAFE OPERATING DEPTH   %.1f m")) % maximum


func _warning_changed(state: int) -> void:
	var label: Label = %WarningState
	match state:
		SubmarineDamageSystem.WarningState.SAFE:
			label.text = "SAFE  /  WITHIN OPERATING RANGE"
			label.modulate = Color("85d8cc")
		SubmarineDamageSystem.WarningState.APPROACHING:
			label.text = "CAUTION  /  APPROACHING LIMIT"
			label.modulate = Color("f4d58a")
		SubmarineDamageSystem.WarningState.EXCEEDED:
			label.text = "DANGER  /  DEPTH LIMIT EXCEEDED"
			label.modulate = Color("ffb49e")
	if _accessibility_compact:
		label.text = ["SAFE / WITHIN RANGE", "CAUTION / NEAR LIMIT", "DANGER / ASCEND"][state]
	if quiet:
		label.text = ["SAFE", "! CAUTION", "! DANGER · ASCEND"][state]
	_refresh_pressure_detail()


func _refresh_pressure_detail() -> void:
	var detail: Label = %PressureDetail
	detail.visible = not quiet or _damage.warning_state != SubmarineDamageSystem.WarningState.SAFE
	if _damage.warning_state != SubmarineDamageSystem.WarningState.EXCEEDED:
		detail.text = "Prepare to ascend" if _damage.warning_state == SubmarineDamageSystem.WarningState.APPROACHING else "Pressure within hull rating"
	elif _damage.pressure_damage_per_second == 0.0:
		detail.text = "ASCEND / Pressure damage disabled by profile"
	elif _damage.grace_remaining_seconds > 0.0:
		detail.text = "ASCEND / Hull damage in %.1f s" % _damage.grace_remaining_seconds
	else:
		detail.text = "ASCEND / DAMAGE ACTIVE" if _accessibility_compact else "ASCEND / PRESSURE DAMAGE ACTIVE"


func _impact_applied(amount: float, _approach_speed: float) -> void:
	_impact_remaining = FEEDBACK_SECONDS
	(%ImpactFeedback as Label).text = "IMPACT  /  Hull −%.1f" % amount


func _pressure_applied(amount: float) -> void:
	if _pressure_remaining <= 0.0:
		_pressure_total = 0.0
	_pressure_total += amount
	_pressure_remaining = FEEDBACK_SECONDS
	(%PressureFeedback as Label).text = "PRESSURE  /  Hull −%.1f" % _pressure_total


func _process(delta: float) -> void:
	if _has_sonar and not is_instance_valid(_sonar):
		bind_sonar(null)
	if not _connections.is_empty():
		if not is_instance_valid(_damage) or not is_instance_valid(_resources) or not is_instance_valid(_hull):
			clear_sources()
		else:
			# Grace has no change signal. Only this presentation detail is sampled;
			# the simulation's clock remains authoritative while paused in menus.
			_refresh_pressure_detail()
	if quiet: compact_reflow()
	_impact_remaining = maxf(0.0, _impact_remaining - delta)
	_pressure_remaining = maxf(0.0, _pressure_remaining - delta)
	if _impact_remaining == 0.0:
		(%ImpactFeedback as Label).text = ""
	if _pressure_remaining == 0.0:
		(%PressureFeedback as Label).text = ""


func set_quiet_layout(value: bool) -> void:
	quiet = value
	if not value: return
	var old: Control = %InstrumentDeck
	var deck: VBoxContainer = VBoxContainer.new()
	var scene_owner: Node = old.owner
	old.unique_name_in_owner = false
	old.name = "RetiredDeck"
	deck.name = "InstrumentDeck"
	add_child(deck)
	deck.owner = scene_owner
	deck.unique_name_in_owner = true
	for child: Node in old.get_children(): child.reparent(deck)
	old.queue_free()
	deck.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# Stack three compact readings without a full-width deck.
	for gauge: ResourceGauge in [hull_gauge,battery_gauge,oxygen_gauge]: gauge.make_compact()
	var identity: Control = get_node("Top/Identity") as Control
	identity.reparent(self)
	identity.name = "SecondaryInstruments"
	(%DepthPanel as Control).reparent(self)
	(%PassiveContacts as PassiveContactsPanel).quiet = true
	(%PassiveContacts as Control).reparent(self)
	(%PassiveContacts as PassiveContactsPanel).set_compact(true)
	(get_node("Bottom/Feedback") as Control).reparent(self)
	for label: Label in [%ImpactFeedback,%PressureFeedback]: label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(get_node("Top") as Control).hide()
	(get_node("Bottom") as Control).hide()
	(%SettingsHint as Control).hide()
	(%IdentityDetail as Control).hide()
	(get_node("SecondaryInstruments/Vessel") as Control).hide()
	(%DepthPanel as Control).get_node("Content/DepthHeader/Caption").hide()
	(%DepthPanel as Control).get_node("Content/Rule").hide()
	((%DepthPanel as Control).get_node("Content") as VBoxContainer).add_theme_constant_override("separation",4)
	var depth_style: StyleBoxFlat = ((%DepthPanel as Control).get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	depth_style.content_margin_top = 8
	depth_style.content_margin_bottom = 8
	(%DepthPanel as Control).add_theme_stylebox_override("panel",depth_style)
	(%DepthPanel as Control).set_meta("a11y_style",[true,depth_style])
	(%DepthValue as Label).set_meta("typography_role",&"measurement")
	UiTypography.style(%DepthValue,&"measurement")
	_refresh_sonar()
	_ignore_input(self)
	compact_reflow()

func identity_container() -> Control:
	return get_node("SecondaryInstruments") as Control if quiet else get_node("Top/Identity") as Control

func compact_reflow() -> void:
	if not quiet or not is_node_ready(): return
	var width: float = size.x
	var left_width: float = minf(280.0,width*0.32-8)
	var right_width: float = minf(340.0,width*0.34)
	var deck: Control = %InstrumentDeck
	deck.position = Vector2(16,16)
	deck.size = Vector2(left_width,deck.get_combined_minimum_size().y)
	var depth: Control = %DepthPanel
	depth.custom_minimum_size.x = 0
	depth.size = Vector2(minf(280,width*0.30-16),depth.get_combined_minimum_size().y)
	depth.position = Vector2((width-depth.size.x)*0.5,16)
	var identity: Control = identity_container()
	identity.position = Vector2(16,size.y-identity.get_combined_minimum_size().y-16)
	identity.size = Vector2(minf(380,width*0.46),identity.get_combined_minimum_size().y)
	var passive: Control = %PassiveContacts
	passive.custom_minimum_size.x = 0
	passive.size = Vector2(right_width,passive.get_combined_minimum_size().y)
	passive.position = Vector2(width-right_width-16,size.y-passive.size.y-16)
	var threat: Control = %ThreatIndicator
	threat.set_anchors_preset(Control.PRESET_TOP_LEFT)
	threat.size = Vector2(right_width,threat.get_combined_minimum_size().y)
	threat.position = Vector2(passive.position.x,passive.position.y-threat.size.y-8)
	var feedback: Control = get_node("Feedback") as Control
	feedback.size = Vector2(left_width,feedback.get_combined_minimum_size().y)
	feedback.position = Vector2(16,deck.get_global_rect().end.y+8)
