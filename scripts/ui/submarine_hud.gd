class_name SubmarineHud
extends Control
## Reusable signal consumer; never writes to the vessel or its configuration.

const FEEDBACK_SECONDS: float = 2.5
var _resources: SubmarineResourceSystem
var _hull: SubmarineHullSystem
var _damage: SubmarineDamageSystem
var _sonar: SonarEmitter
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
	(%IdentityDetail as Label).visible = size.x >= 1100.0


func _listen(event: Signal, callback: Callable) -> void:
	event.connect(callback)
	_connections.append(event)
	_callbacks.append(callback)


func clear_sources() -> void:
	bind_sonar(null)
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
		label.text = "SONAR / %s · COST %.1f\nLAST PING / ECHOES %d" % [
			_sonar.status_text(), _sonar.battery_cost(), _sonar.echo_count()]


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
	(%SafeDepth as Label).text = "SAFE OPERATING DEPTH   %.1f m" % maximum


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
	_refresh_pressure_detail()


func _refresh_pressure_detail() -> void:
	var detail: Label = %PressureDetail
	if _damage.warning_state != SubmarineDamageSystem.WarningState.EXCEEDED:
		detail.text = "Prepare to ascend" if _damage.warning_state == SubmarineDamageSystem.WarningState.APPROACHING else "Pressure within hull rating"
	elif _damage.pressure_damage_per_second == 0.0:
		detail.text = "ASCEND / Pressure damage disabled by profile"
	elif _damage.grace_remaining_seconds > 0.0:
		detail.text = "ASCEND / Hull damage in %.1f s" % _damage.grace_remaining_seconds
	else:
		detail.text = "ASCEND / PRESSURE DAMAGE ACTIVE"


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
	_impact_remaining = maxf(0.0, _impact_remaining - delta)
	_pressure_remaining = maxf(0.0, _pressure_remaining - delta)
	if _impact_remaining == 0.0:
		(%ImpactFeedback as Label).text = ""
	if _pressure_remaining == 0.0:
		(%PressureFeedback as Label).text = ""
